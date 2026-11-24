import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'icons.dart';
import 'responsive.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

Color stateColor(String s) => switch (s) {
      'active' => K.lime,
      'trial' => const Color(0xFF67E8F9),
      'expiring' => K.amber,
      'grace' => K.amber,
      'expired' => K.danger,
      _ => K.muted,
    };

String stateLabel(String s) => switch (s) { 'active' => 'Active', 'trial' => 'Trial', 'expiring' => 'Expiring soon', 'grace' => 'Grace period', 'expired' => 'Expired', _ => 'Switched off' };

String ago(DateTime? d) {
  if (d == null) return 'never';
  final m = DateTime.now().difference(d).inMinutes;
  if (m < 2) return 'just now';
  if (m < 60) return '$m min ago';
  if (m < 60 * 24) return '${m ~/ 60} h ago';
  return '${m ~/ (60 * 24)} d ago';
}

final _dateFmt = DateFormat('d MMM yyyy');

class InstallsScreen extends StatefulWidget {
  const InstallsScreen({super.key});
  @override
  State<InstallsScreen> createState() => _InstallsScreenState();
}

class _InstallsScreenState extends State<InstallsScreen> {
  String filter = 'all';
  final _q = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminState>();
    final q = _q.text.toLowerCase();
    final now = DateTime.now();
    final list = s.installs.where((i) {
      final st = s.stateOf(i);
      final okFilter = filter == 'all' || st == filter || (filter == 'expired' && st == 'grace');
      return okFilter && (q.isEmpty || i.title.toLowerCase().contains(q) || i.s('tin').toLowerCase().contains(q) || i.id.toLowerCase().contains(q));
    }).toList()
      ..sort((a, b) => (b.lastSeen ?? DateTime(2000)).compareTo(a.lastSeen ?? DateTime(2000)));
    final wide = isWide(context);

    Widget tile(Install i) {
      final st = s.stateOf(i);
      return Glass(
        radius: 22,
        padding: const EdgeInsets.all(14),
        onTap: () => showSheet(context, InstallSheet(id: i.id)),
        child: Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: i.online(now) ? K.lime : const Color(0xFF3B4A44), shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(i.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t(13)),
              const SizedBox(height: 4),
              Text('${i.s('platform')}  -  v${i.s('appVersion')}  -  seen ${ago(i.lastSeen)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: t(10, w: FontWeight.w500, c: K.muted)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Badge2(stateLabel(st), color: stateColor(st)),
            const SizedBox(height: 6),
            Text(i.paidUntil == null ? '-' : 'until ${_dateFmt.format(i.paidUntil!)}', style: t(9, w: FontWeight.w500, c: K.dim)),
          ]),
        ]),
      );
    }

    return ListView(padding: EdgeInsets.only(bottom: bottomPad(context)), children: [
      Header(title: 'Installations', subtitle: '${s.installs.length} registered', actions: [IconBtn(Ic.refresh, onTap: () => s.reload())]),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: hPad(context)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: _q, onChanged: (_) => setState(() {}), style: t(12, w: FontWeight.w500), decoration: dec(null, hint: 'Search name, TIN or ID', prefix: const Icon(Ic.search, size: 18, color: Color(0xFF778780)))),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final f in const ['all', 'active', 'trial', 'expiring', 'expired', 'suspended']) Chip2(f == 'all' ? 'All' : stateLabel(f), selected: filter == f, onTap: () => setState(() => filter = f))]),
          const SizedBox(height: 14),
          if (s.error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(s.error!, style: t(11, w: FontWeight.w600, c: K.amber))),
          if (list.isEmpty) Empty(s.installs.isEmpty ? 'No installations yet.\nThey appear here as soon as a Kibo Trade app with your Firebase project opens.' : 'Nothing matches.'),
          if (!wide) for (final i in list) Padding(padding: const EdgeInsets.only(bottom: 10), child: tile(i)),
          if (wide) GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 520, mainAxisExtent: 84, crossAxisSpacing: 12, mainAxisSpacing: 10), itemCount: list.length, itemBuilder: (_, i) => tile(list[i])),
        ]),
      ),
    ]);
  }
}

// ======================================================================== detail sheet
class InstallSheet extends StatelessWidget {
  const InstallSheet({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminState>();
    final i = s.byId(id);
    if (i == null) return const Empty('This installation no longer exists.');
    final st = s.stateOf(i);
    final now = DateTime.now();
    final pays = s.payments.where((p) => p.installId == id).toList();
    Widget kv(String k, String v) => Padding(padding: const EdgeInsets.only(bottom: 7), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 130, child: Text(k, style: t(11, w: FontWeight.w500, c: K.muted))), Expanded(child: Text(v.isEmpty ? '-' : v, style: t(11)))]));
    Future<void> act(Future<String?> f, String ok) async {
      final e = await f;
      if (context.mounted) toast(context, e ?? ok);
    }

    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(i.title, style: t(18, w: FontWeight.w800))), Badge2(stateLabel(st), color: stateColor(st))]),
      const SizedBox(height: 4),
      Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: i.online(now) ? K.lime : const Color(0xFF3B4A44), shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(i.online(now) ? 'Online now' : 'Last seen ${ago(i.lastSeen)}', style: t(11, w: FontWeight.w500, c: K.muted)),
      ]),
      const SizedBox(height: 14),
      kv('Paid until', i.paidUntil == null ? '' : DateFormat('d MMM yyyy HH:mm').format(i.paidUntil!)),
      kv('Status', i.status),
      kv('Business', i.s('businessName')),
      kv('TIN', i.s('tin')),
      kv('Device', '${i.s('platform')}  ${i.s('osVersion')}'),
      kv('App version', i.s('appVersion')),
      kv('Fiscal mode', i.s('fiscalMode')),
      kv('First seen', i.createdAt == null ? '' : _dateFmt.format(i.createdAt!)),
      kv('Last payment', i.lastPaymentAt == null ? '' : _dateFmt.format(i.lastPaymentAt!)),
      GestureDetector(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: i.id));
          if (context.mounted) toast(context, 'Installation ID copied');
        },
        child: kv('Installation ID', '${i.id}  (tap to copy)'),
      ),
      if (i.s('notes').isNotEmpty) kv('Notes', i.s('notes')),
      if (i.s('adminMessage').isNotEmpty) kv('Message to user', i.s('adminMessage')),
      const SizedBox(height: 6),
      Text('USAGE', style: t(10, w: FontWeight.w800, c: K.muted, ls: 1.6)),
      const SizedBox(height: 8),
      kv('Revenue this month', money(i.d('statMonthRevenue'))),
      kv('Sales today', '${i.n('statTodaySales')}'),
      kv('Waiting for TRA', '${i.n('statPending')}'),
      kv('Low-stock items', '${i.n('statLowStock')}'),
      kv('Products', '${i.n('statProducts')}'),
      if (pays.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text('PAYMENTS', style: t(10, w: FontWeight.w800, c: K.muted, ls: 1.6)),
        const SizedBox(height: 8),
        for (final p in pays.take(6)) Padding(padding: const EdgeInsets.only(bottom: 5), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${_dateFmt.format(p.paidAt)}  -  ${p.months} mo  -  ${p.method}${p.reference.isEmpty ? '' : '  ${p.reference}'}', style: t(11, w: FontWeight.w500, c: K.muted)), Text(money(p.amount), style: t(11))])),
      ],
      const SizedBox(height: 16),
      LimeButton('Record payment', icon: Ic.wallet, onTap: () => showSheet(context, PaymentSheet(id: id))),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: i.status == 'suspended'
              ? LimeButton('Activate', icon: Ic.power, outline: true, onTap: () => act(s.setStatus(i, (i.lastPaymentAt != null) ? 'active' : 'trial'), 'Activated'))
              : LimeButton('Deactivate', icon: Ic.power, outline: true, onTap: () => act(s.setStatus(i, 'suspended'), 'Switched off - the app locks at its next check')),
        ),
        const SizedBox(width: 10),
        Expanded(child: LimeButton('Extend days', icon: Ic.clock, outline: true, onTap: () => showSheet(context, _ExtendSheet(id: id)))),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: LimeButton('Edit notes / message', icon: Ic.pencil, outline: true, onTap: () => showSheet(context, _EditSheet(id: id)))),
        const SizedBox(width: 10),
        Expanded(
          child: LimeButton('Delete', icon: Ic.trash, outline: true, onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: Text('Delete installation?', style: t(16, w: FontWeight.w800)),
                content: Text('This removes ${i.title} and its payment history from the server. If the app is still in use it will register again as a new trial.', style: t(12, w: FontWeight.w500, c: K.muted, h: 1.5)),
                actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Cancel', style: t(12, c: K.muted))), TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Delete', style: t(12, c: K.danger)))],
              ),
            );
            if (ok == true) {
              final e = await s.delete(i);
              if (context.mounted) {
                toast(context, e ?? 'Deleted');
                if (e == null) Navigator.pop(context);
              }
            }
          }),
        ),
      ]),
    ]);
  }
}

// ======================================================================== payment
class PaymentSheet extends StatefulWidget {
  const PaymentSheet({super.key, required this.id});
  final String id;
  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  int months = 1;
  String method = 'M-Pesa';
  late final amount = TextEditingController(text: '${context.read<AdminState>().config.monthlyPrice}');
  final ref = TextEditingController();
  bool busy = false;

  void _setMonths(int m) {
    final price = context.read<AdminState>().config.monthlyPrice;
    setState(() { months = m; amount.text = '${price * m}'; });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminState>();
    final i = s.byId(widget.id);
    if (i == null) return const SizedBox();
    final now = DateTime.now().toUtc();
    final cur = i.paidUntil?.toUtc();
    final base = (cur != null && cur.isAfter(now) && i.status != 'trial') ? cur : now;
    final until = addMonths(base, months);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Record payment', style: t(18, w: FontWeight.w800)),
      Text(i.title, style: t(11, w: FontWeight.w500, c: K.muted)),
      const SizedBox(height: 14),
      Text('MONTHS', style: t(10, w: FontWeight.w800, c: K.muted, ls: 1.6)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [for (final m in const [1, 2, 3, 6, 12]) Chip2('$m', selected: months == m, onTap: () => _setMonths(m))]),
      const SizedBox(height: 14),
      TextField(controller: amount, keyboardType: TextInputType.number, style: t(13, w: FontWeight.w500), decoration: dec('Amount received (TZS)')),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [for (final m in const ['M-Pesa', 'Tigo Pesa', 'Airtel Money', 'HaloPesa', 'Bank', 'Cash']) Chip2(m, selected: method == m, onTap: () => setState(() => method = m))]),
      const SizedBox(height: 12),
      TextField(controller: ref, style: t(13, w: FontWeight.w500), decoration: dec('Transaction reference')),
      const SizedBox(height: 12),
      Text('New expiry: ${DateFormat('d MMM yyyy').format(until.toLocal())}', style: t(12, c: K.lime)),
      const SizedBox(height: 14),
      LimeButton('Save payment & activate', icon: Ic.check, busy: busy, onTap: () async {
        final a = int.tryParse(amount.text.replaceAll(',', ''));
        if (a == null || a <= 0) return toast(context, 'Enter the amount');
        setState(() => busy = true);
        final e = await s.pay(i, a, months, method, ref.text.trim());
        if (context.mounted) {
          setState(() => busy = false);
          toast(context, e ?? 'Payment recorded - subscription extended');
          if (e == null) Navigator.pop(context);
        }
      }),
    ]);
  }
}

class _ExtendSheet extends StatelessWidget {
  const _ExtendSheet({required this.id});
  final String id;
  @override
  Widget build(BuildContext context) {
    final s = context.read<AdminState>();
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Extend without a payment', style: t(18, w: FontWeight.w800)),
      const SizedBox(height: 6),
      Text('Adds free days (a courtesy or an extended trial). It does not record revenue.', style: t(11, w: FontWeight.w500, c: K.muted, h: 1.4)),
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final d in const [3, 7, 14, 30])
          Chip2('+$d days', onTap: () async {
            final i = s.byId(id);
            if (i == null) return;
            final e = await s.extend(i, d);
            if (context.mounted) {
              toast(context, e ?? 'Extended by $d days');
              Navigator.pop(context);
            }
          }),
      ]),
    ]);
  }
}

class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.id});
  final String id;
  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final Install i = context.read<AdminState>().byId(widget.id)!;
  late final label = TextEditingController(text: i.s('label'));
  late final notes = TextEditingController(text: i.s('notes'));
  late final msg = TextEditingController(text: i.s('adminMessage'));

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Notes & message', style: t(18, w: FontWeight.w800)),
        const SizedBox(height: 14),
        TextField(controller: label, style: t(13, w: FontWeight.w500), decoration: dec('Display name (optional)')),
        const SizedBox(height: 12),
        TextField(controller: notes, minLines: 2, maxLines: 4, style: t(13, w: FontWeight.w500), decoration: dec('Private notes (phone number, location...)')),
        const SizedBox(height: 12),
        TextField(controller: msg, minLines: 2, maxLines: 3, style: t(13, w: FontWeight.w500), decoration: dec('Message shown inside the customer\'s app')),
        const SizedBox(height: 16),
        LimeButton('Save', icon: Ic.check, onTap: () async {
          final e = await context.read<AdminState>().saveInfo(i, label.text.trim(), notes.text.trim(), msg.text.trim());
          if (context.mounted) {
            toast(context, e ?? 'Saved');
            if (e == null) Navigator.pop(context);
          }
        }),
      ]);
}
