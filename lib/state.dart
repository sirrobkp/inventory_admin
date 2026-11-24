import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

class AdminState extends ChangeNotifier {
  Api? api;
  SharedPreferences? _p;
  bool ready = false, signedIn = false, loading = false;
  String? error;
  String project = '', apiKey = '', email = '';
  List<Install> installs = [];
  List<Payment> payments = [];
  AppConfig config = AppConfig();
  int tab = 0;
  Timer? _timer;

  void setTab(int i) {
    tab = i;
    notifyListeners();
  }

  // ---------------------------------------------------------------- session
  Future<void> boot() async {
    _p = await SharedPreferences.getInstance();
    project = _p!.getString('project') ?? '';
    apiKey = _p!.getString('apiKey') ?? '';
    email = _p!.getString('email') ?? '';
    final token = _p!.getString('refresh') ?? '';
    if (project.isNotEmpty && apiKey.isNotEmpty && token.isNotEmpty) {
      api = Api(project: project, apiKey: apiKey);
      try {
        if (await api!.signInWithRefresh(token) && await api!.isAdmin()) {
          signedIn = true;
          _startTimer();
          unawaited(reload());
        }
      } catch (_) {
        // offline at start: the login screen is shown, saved details are pre-filled
      }
    }
    ready = true;
    notifyListeners();
  }

  /// Returns an error message, or null on success.
  Future<String?> signIn(String project, String apiKey, String email, String password) async {
    final a = Api(project: project.trim(), apiKey: apiKey.trim());
    try {
      await a.signIn(email.trim(), password);
      if (!await a.isAdmin()) return 'Signed in, but this user is not an admin. Add a document with this user\'s UID under the "admins" collection (see Setup help).';
    } on ApiError catch (e) {
      return e.message;
    } catch (e) {
      return 'Could not reach Firebase: check the project ID and your connection';
    }
    api = a;
    this.project = project.trim();
    this.apiKey = apiKey.trim();
    this.email = email.trim();
    await _p?.setString('project', this.project);
    await _p?.setString('apiKey', this.apiKey);
    await _p?.setString('email', this.email);
    await _p?.setString('refresh', a.refreshToken ?? '');
    signedIn = true;
    _startTimer();
    notifyListeners();
    unawaited(reload());
    return null;
  }

  Future<void> signOut() async {
    _timer?.cancel();
    await _p?.remove('refresh');
    api = null;
    signedIn = false;
    installs = [];
    payments = [];
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => reload(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------------- data
  Future<void> reload({bool silent = false}) async {
    if (api == null) return;
    if (!silent) {
      loading = true;
      notifyListeners();
    }
    try {
      final r = await Future.wait([api!.listInstalls(), api!.listPayments(), api!.getConfig()]);
      installs = r[0] as List<Install>;
      payments = r[1] as List<Payment>;
      config = r[2] as AppConfig;
      error = null;
      await _p?.setString('refresh', api!.refreshToken ?? '');
    } on ApiError catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Offline or Firebase unreachable';
    }
    loading = false;
    notifyListeners();
  }

  /// Runs an admin action; returns an error message or null.
  Future<String?> run(Future<void> Function() job) async {
    try {
      await job();
      await reload(silent: true);
      return null;
    } on ApiError catch (e) {
      return e.message;
    } catch (_) {
      return 'Offline or Firebase unreachable';
    }
  }

  Future<String?> setStatus(Install i, String status) => run(() => api!.updateInstall(i.id, {'status': status}));

  Future<String?> extend(Install i, int days) => run(() {
        final now = DateTime.now().toUtc();
        final cur = i.paidUntil?.toUtc();
        final base = (cur != null && cur.isAfter(now)) ? cur : now;
        return api!.updateInstall(i.id, {'paidUntil': base.add(Duration(days: days))});
      });

  Future<String?> saveInfo(Install i, String label, String notes, String message) => run(() => api!.updateInstall(i.id, {'label': label, 'notes': notes, 'adminMessage': message}));

  Future<String?> pay(Install i, int amount, int months, String method, String reference) => run(() => api!.recordPayment(i, amount: amount, months: months, method: method, reference: reference));

  Future<String?> delete(Install i) => run(() => api!.deleteInstall(i.id));

  Future<String?> saveConfig(AppConfig c) => run(() => api!.saveConfig(c));

  // ---------------------------------------------------------------- derived
  String stateOf(Install i) => i.state(DateTime.now(), config.graceDays);
  int count(String state) => installs.where((i) => stateOf(i) == state).length;
  int get payingCount => installs.where((i) => i.paying(DateTime.now(), config.graceDays)).length;
  int get mrr => payingCount * config.monthlyPrice;

  int revenueIn(int year, int month) => payments.where((p) => p.paidAt.year == year && p.paidAt.month == month).fold(0, (a, p) => a + p.amount);
  int get revenueThisMonth => revenueIn(DateTime.now().year, DateTime.now().month);
  int get revenueAllTime => payments.fold(0, (a, p) => a + p.amount);

  /// Oldest -> newest, [n] months ending this month.
  List<(DateTime, int)> revenueByMonth(int n) {
    final now = DateTime.now();
    return [for (var k = n - 1; k >= 0; k--) () {
      final d = DateTime(now.year, now.month - k, 1);
      return (d, revenueIn(d.year, d.month));
    }()];
  }

  Install? byId(String id) {
    for (final i in installs) {
      if (i.id == id) return i;
    }
    return null;
  }
}
