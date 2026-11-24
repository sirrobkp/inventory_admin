import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'icons.dart';
import 'installs_screen.dart';
import 'responsive.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminState>();
    final wide = isWide(context);
    Widget tile(int k) {
      final p = s.payments[k];
      final inst = s.byId(p.installId);
      return Glass(
        radius: 20,
        padding: const EdgeInsets.all(14),
        onTap: inst == null ? null : () => showSheet(context, InstallSheet(id: inst.id)),
        child: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0x1AC9FF55), borderRadius: BorderRadius.circular(14)), child: const Icon(Ic.wallet, size: 17, color: K.lime)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(inst?.title ?? 'Removed installation', maxLines: 1, overflow: TextOverflow.ellipsis, style: t(13)),
            const SizedBox(height: 4),
            Text('${DateFormat('d MMM yyyy HH:mm').format(p.paidAt)}  -  ${p.months} month${p.months == 1 ? '' : 's'}  -  ${p.method}${p.reference.isEmpty ? '' : '  ${p.reference}'}', maxLines: 2, overflow: TextOverflow.ellipsis, style: t(10, w: FontWeight.w500, c: K.muted, h: 1.3)),
          ])),
          Text(money(p.amount), style: t(13, w: FontWeight.w800, c: K.lime)),
        ]),
      );
    }

    return ListView(padding: EdgeInsets.only(bottom: bottomPad(context)), children: [
      Header(title: 'Payments', subtitle: '${s.payments.length} recorded', actions: [IconBtn(Ic.refresh, onTap: () => s.reload())]),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: hPad(context)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: MetricCard(label: 'This month', value: compact(s.revenueThisMonth), note: DateFormat('MMMM yyyy').format(DateTime.now()), icon: Ic.wallet, accent: true)),
            const SizedBox(width: 12),
            Expanded(child: MetricCard(label: 'All time', value: compact(s.revenueAllTime), note: '${s.payments.length} payments', icon: Ic.chart)),
          ]),
          const SizedBox(height: 16),
          if (s.payments.isEmpty) const Empty('No payments yet.\nOpen an installation and tap "Record payment" after you receive the money.'),
          if (!wide) for (var k = 0; k < s.payments.length; k++) Padding(padding: const EdgeInsets.only(bottom: 10), child: tile(k)),
          if (wide) GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 560, mainAxisExtent: 82, crossAxisSpacing: 12, mainAxisSpacing: 10), itemCount: s.payments.length, itemBuilder: (_, k) => tile(k)),
        ]),
      ),
    ]);
  }
}
