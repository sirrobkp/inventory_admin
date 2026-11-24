import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// ------------------------------------------------------------------ Firestore security rules
/// Paste into Firebase Console > Firestore Database > Rules > Publish.
/// Subscribers (anonymous users) can only register themselves as a 14-day trial and send a heartbeat;
/// only admins (documents in /admins/{uid}) can change status, paidUntil, notes, payments or settings.
const firestoreRules = r'''rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isAdmin() {
      return request.auth != null && exists(/databases/$(database)/documents/admins/$(request.auth.uid));
    }

    match /admins/{uid} {
      allow read: if request.auth != null && request.auth.uid == uid;
      allow write: if false;
    }

    match /config/{doc} {
      allow read: if request.auth != null;
      allow write: if isAdmin();
    }

    match /installations/{id} {
      allow read: if request.auth != null && (request.auth.uid == id || isAdmin());
      allow create: if request.auth != null && request.auth.uid == id
        && request.resource.data.status == 'trial'
        && request.resource.data.paidUntil is timestamp
        && request.resource.data.paidUntil <= request.time + duration.value(15, 'd')
        && request.resource.data.keys().hasOnly(['uid', 'createdAt', 'status', 'paidUntil', 'businessName', 'tin', 'platform', 'osVersion', 'appVersion', 'lastSeen', 'fiscalMode', 'statMonthRevenue', 'statTodaySales', 'statPending', 'statLowStock', 'statProducts']);
      allow update: if isAdmin() || (request.auth != null && request.auth.uid == id
        && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['businessName', 'tin', 'platform', 'osVersion', 'appVersion', 'lastSeen', 'fiscalMode', 'statMonthRevenue', 'statTodaySales', 'statPending', 'statLowStock', 'statProducts']));
      allow delete: if isAdmin();

      match /payments/{pid} {
        allow read: if request.auth != null && (request.auth.uid == id || isAdmin());
        allow write: if isAdmin();
      }
    }

    match /{path=**}/payments/{pid} {
      allow read: if isAdmin();
    }
  }
}''';

class ApiError implements Exception {
  ApiError(this.message);
  final String message;
  @override
  String toString() => message;
}

// ------------------------------------------------------------------ models
DateTime addMonths(DateTime d, int m) {
  final y = d.year + (d.month - 1 + m) ~/ 12;
  final mo = (d.month - 1 + m) % 12 + 1;
  final last = DateTime.utc(y, mo + 1, 0).day;
  return DateTime.utc(y, mo, d.day > last ? last : d.day, d.hour, d.minute, d.second);
}

class AppConfig {
  AppConfig({this.monthlyPrice = 50000, this.trialDays = 14, this.graceDays = 3, this.maxOfflineDays = 14, this.paymentInstructions = '', this.supportContact = ''});
  int monthlyPrice, trialDays, graceDays, maxOfflineDays;
  String paymentInstructions, supportContact;
}

class Install {
  Install(this.id, this.f);
  final String id;
  final Map<String, dynamic> f;

  String s(String k) => (f[k] as String?) ?? '';
  double d(String k) => ((f[k] as num?) ?? 0).toDouble();
  int n(String k) => ((f[k] as num?) ?? 0).toInt();
  DateTime? t(String k) => f[k] as DateTime?;

  String get status => s('status').isEmpty ? 'trial' : s('status');
  DateTime? get paidUntil => t('paidUntil');
  DateTime? get lastSeen => t('lastSeen');
  DateTime? get createdAt => t('createdAt');
  DateTime? get lastPaymentAt => t('lastPaymentAt');
  String get title => s('label').isNotEmpty ? s('label') : (s('businessName').isNotEmpty ? s('businessName') : 'Unnamed ${id.substring(0, id.length < 6 ? id.length : 6)}');
  bool online(DateTime now) => lastSeen != null && now.difference(lastSeen!).inMinutes <= 45;

  /// suspended | expired | grace | expiring | trial | active
  String state(DateTime now, int graceDays) {
    if (status == 'suspended') return 'suspended';
    final p = paidUntil;
    if (p == null) return 'expired';
    if (now.isBefore(p)) {
      final days = (p.difference(now).inHours / 24).ceil();
      if (status == 'trial') return days <= 3 ? 'expiring' : 'trial';
      return days <= 7 ? 'expiring' : 'active';
    }
    return now.isBefore(p.add(Duration(days: graceDays))) ? 'grace' : 'expired';
  }

  /// A paying subscriber (not a trial) that is currently entitled to use the app.
  bool paying(DateTime now, int graceDays) => status == 'active' && paidUntil != null && now.isBefore(paidUntil!.add(Duration(days: graceDays)));
}

class Payment {
  Payment(this.id, this.installId, this.f);
  final String id, installId;
  final Map<String, dynamic> f;
  int get amount => ((f['amount'] as num?) ?? 0).toInt();
  int get months => ((f['months'] as num?) ?? 1).toInt();
  String get method => (f['method'] as String?) ?? '';
  String get reference => (f['reference'] as String?) ?? '';
  DateTime get paidAt => (f['paidAt'] as DateTime?) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

// ------------------------------------------------------------------ Firestore value (de)coding
dynamic _dec(Map v) {
  if (v.containsKey('stringValue')) return v['stringValue'];
  if (v.containsKey('integerValue')) return int.parse('${v['integerValue']}');
  if (v.containsKey('doubleValue')) return (v['doubleValue'] as num).toDouble();
  if (v.containsKey('booleanValue')) return v['booleanValue'];
  if (v.containsKey('timestampValue')) return DateTime.parse(v['timestampValue'] as String).toLocal();
  if (v.containsKey('mapValue')) return {for (final e in ((v['mapValue'] as Map)['fields'] as Map? ?? const {}).entries) e.key: _dec(e.value as Map)};
  if (v.containsKey('arrayValue')) return [for (final e in ((v['arrayValue'] as Map)['values'] as List? ?? const [])) _dec(e as Map)];
  return null;
}

Map<String, dynamic> _fields(Map doc) => {for (final e in ((doc['fields'] as Map?) ?? const {}).entries) e.key as String: _dec(e.value as Map)};
String _idOf(Map doc) => (doc['name'] as String).split('/').last;

Map<String, dynamic> _enc(Object? v) {
  if (v is String) return {'stringValue': v};
  if (v is bool) return {'booleanValue': v};
  if (v is int) return {'integerValue': '$v'};
  if (v is double) return {'doubleValue': v};
  if (v is DateTime) return {'timestampValue': v.toUtc().toIso8601String()};
  return {'nullValue': null};
}

// ------------------------------------------------------------------ API
class Api {
  Api({required this.project, required this.apiKey});
  final String project, apiKey;
  String? _token, _refresh, _uid;
  DateTime _exp = DateTime(2000);

  String? get refreshToken => _refresh;
  String get _db => 'projects/$project/databases/(default)/documents';
  Map<String, String> get _h => {'Authorization': 'Bearer $_token', 'Content-Type': 'application/json'};

  String _msg(String m) {
    if (m.contains('EMAIL_NOT_FOUND') || m.contains('INVALID_PASSWORD') || m.contains('INVALID_LOGIN_CREDENTIALS')) return 'Wrong email or password';
    if (m.contains('API key not valid')) return 'The Web API key is not valid';
    if (m.contains('PERMISSION_DENIED') || m.contains('Missing or insufficient permissions')) return 'Permission denied: this user is not an admin, or the security rules are not published';
    if (m.contains('OPERATION_NOT_ALLOWED')) return 'Enable Email/Password sign-in in Firebase Authentication';
    return m;
  }

  void _take(Map<String, dynamic> j, {bool refreshStyle = false}) {
    _token = (refreshStyle ? j['id_token'] : j['idToken']) as String;
    _refresh = (refreshStyle ? j['refresh_token'] : j['refreshToken']) as String;
    _uid = (refreshStyle ? j['user_id'] : j['localId']) as String;
    _exp = DateTime.now().add(Duration(seconds: (int.tryParse('${refreshStyle ? j['expires_in'] : j['expiresIn']}') ?? 3600) - 120));
  }

  Future<void> signIn(String email, String password) async {
    final r = await http
        .post(Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'email': email, 'password': password, 'returnSecureToken': true}))
        .timeout(const Duration(seconds: 30));
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200) throw ApiError(_msg((j['error'] as Map?)?['message'] as String? ?? 'HTTP ${r.statusCode}'));
    _take(j);
  }

  Future<bool> signInWithRefresh(String refresh) async {
    final r = await http
        .post(Uri.parse('https://securetoken.googleapis.com/v1/token?key=$apiKey'), headers: {'Content-Type': 'application/x-www-form-urlencoded'}, body: 'grant_type=refresh_token&refresh_token=${Uri.encodeQueryComponent(refresh)}')
        .timeout(const Duration(seconds: 30));
    if (r.statusCode != 200) return false;
    _take(jsonDecode(r.body) as Map<String, dynamic>, refreshStyle: true);
    return true;
  }

  Future<void> _ensure() async {
    if (_token != null && _exp.isAfter(DateTime.now())) return;
    if (_refresh != null && await signInWithRefresh(_refresh!)) return;
    throw ApiError('Session expired - please sign in again');
  }

  Future<Map<String, dynamic>> _json(http.Response r) async {
    if (r.statusCode >= 200 && r.statusCode < 300) return r.body.isEmpty ? {} : jsonDecode(r.body) as Map<String, dynamic>;
    String m = 'HTTP ${r.statusCode}';
    try {
      m = ((jsonDecode(r.body) as Map)['error'] as Map)['message'] as String;
    } catch (_) {}
    throw ApiError(_msg(m));
  }

  Future<Map<String, dynamic>> _getJson(String path, [String q = '']) async {
    await _ensure();
    return _json(await http.get(Uri.parse('https://firestore.googleapis.com/v1/$_db/$path$q'), headers: _h).timeout(const Duration(seconds: 40)));
  }

  Future<void> _commit(List<Map<String, dynamic>> writes) async {
    await _ensure();
    await _json(await http.post(Uri.parse('https://firestore.googleapis.com/v1/$_db:commit'), headers: _h, body: jsonEncode({'writes': writes})).timeout(const Duration(seconds: 40)));
  }

  /// Is the signed-in user listed in /admins ?
  Future<bool> isAdmin() async {
    await _ensure();
    final r = await http.get(Uri.parse('https://firestore.googleapis.com/v1/$_db/admins/$_uid'), headers: _h).timeout(const Duration(seconds: 30));
    return r.statusCode == 200;
  }

  String get uid => _uid ?? '';

  // ------------------------------------------------------------------ data
  Future<List<Install>> listInstalls() async {
    final out = <Install>[];
    String? token;
    do {
      final j = await _getJson('installations', '?pageSize=300${token == null ? '' : '&pageToken=$token'}');
      for (final d in (j['documents'] as List? ?? const [])) {
        out.add(Install(_idOf(d as Map), _fields(d)));
      }
      token = j['nextPageToken'] as String?;
    } while (token != null);
    return out;
  }

  Future<List<Payment>> listPayments() async {
    await _ensure();
    final r = await http
        .post(Uri.parse('https://firestore.googleapis.com/v1/$_db:runQuery'), headers: _h, body: jsonEncode({'structuredQuery': {'from': [{'collectionId': 'payments', 'allDescendants': true}], 'limit': 1000}}))
        .timeout(const Duration(seconds: 60));
    if (r.statusCode != 200) {
      await _json(r);
    }
    final out = <Payment>[];
    for (final row in (jsonDecode(r.body) as List)) {
      final doc = (row as Map)['document'] as Map?;
      if (doc == null) continue;
      final parts = (doc['name'] as String).split('/');
      out.add(Payment(parts.last, parts[parts.length - 3], _fields(doc)));
    }
    out.sort((a, b) => b.paidAt.compareTo(a.paidAt));
    return out;
  }

  Future<AppConfig> getConfig() async {
    await _ensure();
    final r = await http.get(Uri.parse('https://firestore.googleapis.com/v1/$_db/config/app'), headers: _h).timeout(const Duration(seconds: 30));
    if (r.statusCode == 404) return AppConfig();
    final f = _fields(await _json(r));
    return AppConfig(
      monthlyPrice: (f['monthlyPrice'] as int?) ?? 50000,
      trialDays: (f['trialDays'] as int?) ?? 14,
      graceDays: (f['graceDays'] as int?) ?? 3,
      maxOfflineDays: (f['maxOfflineDays'] as int?) ?? 14,
      paymentInstructions: (f['paymentInstructions'] as String?) ?? '',
      supportContact: (f['supportContact'] as String?) ?? '',
    );
  }

  Future<void> saveConfig(AppConfig c) => _commit([
        {
          'update': {
            'name': '$_db/config/app',
            'fields': {
              'monthlyPrice': _enc(c.monthlyPrice),
              'trialDays': _enc(c.trialDays),
              'graceDays': _enc(c.graceDays),
              'maxOfflineDays': _enc(c.maxOfflineDays),
              'paymentInstructions': _enc(c.paymentInstructions),
              'supportContact': _enc(c.supportContact),
            },
          },
        }
      ]);

  /// Updates only the given fields of an installation. Fields listed in [remove] are deleted.
  Future<void> updateInstall(String id, Map<String, Object?> fields, {List<String> remove = const []}) => _commit([
        {
          'update': {'name': '$_db/installations/$id', 'fields': {for (final e in fields.entries) e.key: _enc(e.value)}},
          'updateMask': {'fieldPaths': [...fields.keys, ...remove]},
          'currentDocument': {'exists': true},
        }
      ]);

  /// Records a payment and extends the subscription: from the current expiry if still running, otherwise from today.
  Future<DateTime> recordPayment(Install i, {required int amount, required int months, required String method, required String reference}) async {
    final now = DateTime.now().toUtc();
    final cur = i.paidUntil?.toUtc();
    final base = (cur != null && cur.isAfter(now) && i.status != 'trial') ? cur : now;
    final until = addMonths(base, months);
    await _commit([
      {
        'update': {
          'name': '$_db/installations/${i.id}/payments/p${now.millisecondsSinceEpoch}',
          'fields': {'installId': _enc(i.id), 'amount': _enc(amount), 'months': _enc(months), 'method': _enc(method), 'reference': _enc(reference), 'paidAt': _enc(now)},
        },
      },
      {
        'update': {'name': '$_db/installations/${i.id}', 'fields': {'status': _enc('active'), 'paidUntil': _enc(until), 'lastPaymentAt': _enc(now)}},
        'updateMask': {'fieldPaths': ['status', 'paidUntil', 'lastPaymentAt']},
        'currentDocument': {'exists': true},
      },
    ]);
    return until;
  }

  Future<void> deleteInstall(String id) async {
    final j = await _getJson('installations/$id/payments', '?pageSize=300');
    final names = [for (final d in (j['documents'] as List? ?? const [])) (d as Map)['name'] as String];
    await _commit([for (final n in names) {'delete': n}, {'delete': '$_db/installations/$id'}]);
  }
}
