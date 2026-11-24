import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'icons.dart';
import 'installs_screen.dart';
import 'responsive.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminState>();
    final attention = s.installs.where((i) => const ['expiring', 'grace', 'expired'].contains(s.stateOf(i))).toList()
      ..sort((a, b) => (a.paidUntil ?? DateTime(2000)).compareTo(b.paidUntil ?? DateTime(2000)));
    final online = s.installs.where((i) => i.online(DateTime.now())).length;

    final left = <Widget>[
      if (s.error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Glass(radius: 18, padding: const EdgeInsets.all(12), color: const Color(0x1AFFC85A), child: Text(s.error!, style: t(11, w: FontWeight.w600, c: K.amber)))),
      Glass(
        radius: 30,
        padding: const EdgeInsets.all(20),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1B2E27), Color(0xFF13201C), Color(0xFF17271D)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: K.lime, shape: BoxShape.circle, boxShadow: [BoxShadow(color: K.lime, blurRadius: 10)])),
            const SizedBox(width: 8),
            Text('MONTHLY RECURRING REVENUE', style: t(10, w: FontWeight.w800, c: const Color(0xFF91A099), ls: 1.8)),
          ]),
          const SizedBox(height: 12),
          Text(money(s.mrr), style: t(29, w: FontWeight.w800, ls: -1.6)),
          const SizedBox(height: 4),
          Text('${s.payingCount} paying x ${money(s.config.monthlyPrice)}  -  $online online now', style: t(12, w: FontWeight.w600, c: const Color(0xFF8C9C95))),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _Mini('Collected this month', money(s.revenueThisMonth))),
            const SizedBox(width: 10),
            Expanded(child: _Mini('Collected all time', money(s.revenueAllTime))),
          ]),
        ]),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: MetricCard(label: 'Active', value: '${s.count('active')}', note: 'paid subscribers', icon: Ic.checkCircle, accent: true)),
        const SizedBox(width: 12),
        Expanded(child: MetricCard(label: 'On trial', value: '${s.count('trial')}', note: 'free trial', icon: Ic.clock)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: MetricCard(label: 'Expiring soon', value: '${s.count('expiring') + s.count('grace')}', note: 'needs renewal', icon: Ic.warn)),
        const SizedBox(width: 12),
        Expanded(child: MetricCard(label: 'Locked out', value: '${s.count('expired') + s.count('suspended')}', note: 'expired or off', icon: Ic.power)),
      ]),
      const SizedBox(height: 14),
    ];

    final right = <Widget>[
      _RevenueChart(data: s.revenueByMonth(6)),
      const SizedBox(height: 12),
      const SectionTitle('Needs attention'),
      Glass(
        padding: EdgeInsets.zero,
        child: attention.isEmpty
            ? const Empty('Nobody is about to expire.')
            : Column(children: [
                for (var k = 0; k < attention.length && k < 8; k++)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => showSheet(context, InstallSheet(id: attention[k].id)),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(border: k < attention.length - 1 && k < 7 ? const Border(bottom: BorderSide(color: Color(0x0FFFFFFF))) : null),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(attention[k].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t(12)), const SizedBox(height: 4), Text(attention[k].paidUntil == null ? '' : 'until ${DateFormat('d MMM yyyy').format(attention[k].paidUntil!)}', style: t(10, w: FontWeight.w500, c: K.muted))])),
                        Badge2(stateLabel(s.stateOf(attention[k])), color: stateColor(s.stateOf(attention[k]))),
                      ]),
                    ),
                  ),
              ]),
      ),
    ];

    return ListView(padding: EdgeInsets.only(bottom: bottomPad(context)), children: [
      Header(title: 'Subscriptions', subtitle: 'Overview', actions: [IconBtn(Ic.refresh, onTap: () => s.reload())]),
      if (s.loading) const Padding(padding: EdgeInsets.symmetric(horizontal: 28), child: LinearProgressIndicator(color: K.lime, backgroundColor: Color(0x12FFFFFF), minHeight: 2)),
      Padding(padding: EdgeInsets.symmetric(horizontal: hPad(context)), child: twoPane(context, left: left, right: right)),
    ]);
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: K.glass2, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label.toUpperCase(), style: t(9, w: FontWeight.w800, c: K.muted, ls: 1.2)), const SizedBox(height: 4), FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: t(14, w: FontWeight.w800)))]),
      );
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.data});
  final List<(DateTime, int)> data;
  @override
  Widget build(BuildContext context) {
    final maxV = data.fold<int>(0, (a, e) => e.$2 > a ? e.$2 : a);
    final total = data.fold<int>(0, (a, e) => a + e.$2);
    return Glass(
      radius: 26,
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('REVENUE - LAST 6 MONTHS', style: t(10, w: FontWeight.w800, c: const Color(0xFF82918B), ls: 1.8)),
        const SizedBox(height: 6),
        Text(money(total), style: t(20, w: FontWeight.w800, ls: -0.8)),
        const SizedBox(height: 18),
        SizedBox(
          height: 96,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < data.length; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: maxV == 0 ? .04 : (data[i].$2 / maxV).clamp(.04, 1.0)),
                    duration: Duration(milliseconds: 450 + i * 50),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => Align(alignment: Alignment.bottomCenter, child: FractionallySizedBox(heightFactor: v, child: Container(decoration: BoxDecoration(color: i == data.length - 1 ? K.lime : const Color(0x17FFFFFF), borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))))),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        Row(children: [for (final d in data) Expanded(child: Center(child: Text(DateFormat('MMM').format(d.$1).toUpperCase(), style: t(9, w: FontWeight.w600, c: const Color(0xFF61716A)))))]),
      ]),
    );
  }
}
