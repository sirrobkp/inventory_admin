import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'icons.dart';
import 'installs_screen.dart';
import 'overview_screen.dart';
import 'payments_screen.dart';
import 'responsive.dart';
import 'settings_screen.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

const _tabs = [
  (Ic.chart, 'Overview'),
  (Ic.phone, 'Installations'),
  (Ic.wallet, 'Payments'),
  (Ic.settings, 'Settings'),
];

class AdminShell extends StatelessWidget {
  const AdminShell({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminState>();
    const pages = [OverviewScreen(), InstallsScreen(), PaymentsScreen(), SettingsScreen()];
    final wide = isWide(context);
    final page = AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: KeyedSubtree(key: ValueKey(s.tab), child: pages[s.tab]));
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [K.bg2, K.bg])),
        child: wide
            ? Row(children: [
                const _Sidebar(),
                Expanded(child: SafeArea(child: Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1300), child: page)))),
              ])
            : Stack(children: [
                SafeArea(bottom: false, child: page),
                Positioned(left: 14, right: 14, bottom: 16 + MediaQuery.of(context).padding.bottom, child: _BottomNav(active: s.tab, onChange: s.setTab)),
              ]),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar();
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AdminState>();
    return Container(
      width: 236,
      padding: const EdgeInsets.fromLTRB(16, 26, 16, 18),
      decoration: const BoxDecoration(color: Color(0x73081210), border: Border(right: BorderSide(color: K.border))),
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(children: [const LogoMark(), const SizedBox(width: 12), Expanded(child: Text('Kibo Admin', style: t(15, w: FontWeight.w800, ls: -0.4)))]),
          ),
          const SizedBox(height: 30),
          for (var i = 0; i < _tabs.length; i++) _SideItem(icon: _tabs[i].$1, label: _tabs[i].$2, selected: s.tab == i, onTap: () => s.setTab(i)),
          const Spacer(),
          Glass(
            radius: 18,
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${s.installs.length} installations', style: t(11)),
              const SizedBox(height: 4),
              Text(s.error ?? 'Updates every minute', style: t(10, w: FontWeight.w500, c: s.error == null ? K.muted : K.amber, h: 1.4)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _SideItem extends StatefulWidget {
  const _SideItem({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  State<_SideItem> createState() => _SideItemState();
}

class _SideItemState extends State<_SideItem> {
  bool hover = false;
  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(color: sel ? K.lime : (hover ? K.glass2 : Colors.transparent), borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Icon(widget.icon, size: 19, color: sel ? K.ink : const Color(0xFF9AA9A2)),
            const SizedBox(width: 12),
            Expanded(child: Text(widget.label, style: t(13, c: sel ? K.ink : const Color(0xFFC3CEC8)))),
          ]),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.active, required this.onChange});
  final int active;
  final ValueChanged<int> onChange;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xE6192620),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: const Color(0x1AFFFFFF)),
          boxShadow: const [BoxShadow(color: Color(0x8C000000), blurRadius: 40, offset: Offset(0, 20))],
        ),
        child: Row(children: [
          for (var i = 0; i < _tabs.length; i++)
            Expanded(
              flex: active == i ? 2 : 1,
              child: GestureDetector(
                onTap: () => onChange(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 56,
                  decoration: BoxDecoration(color: active == i ? K.lime : Colors.transparent, borderRadius: BorderRadius.circular(19)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(_tabs[i].$1, size: 19, color: active == i ? K.ink : const Color(0xFF75857D)),
                    if (active == i) ...[const SizedBox(width: 8), Flexible(child: Text(_tabs[i].$2, overflow: TextOverflow.ellipsis, style: t(10, w: FontWeight.w800, c: K.ink)))],
                  ]),
                ),
              ),
            ),
        ]),
      );
}
