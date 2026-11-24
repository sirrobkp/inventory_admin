import 'package:flutter/material.dart';

import 'theme.dart';

bool isWide(BuildContext c) => MediaQuery.of(c).size.width >= 900;
double bottomPad(BuildContext c) => isWide(c) ? 32 : 130;
double hPad(BuildContext c) => isWide(c) ? 28 : 20;

/// Phone: one column. Wide: two columns side by side.
Widget twoPane(BuildContext c, {required List<Widget> left, required List<Widget> right, int leftFlex = 6, int rightFlex = 5, double gap = 24}) {
  if (!isWide(c)) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [...left, ...right]);
  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Expanded(flex: leftFlex, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: left)),
    SizedBox(width: gap),
    Expanded(flex: rightFlex, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: right)),
  ]);
}

Route<T> pageRoute<T>(Widget page) => MaterialPageRoute<T>(builder: (c) => WidePage(child: page));

class WidePage extends StatelessWidget {
  const WidePage({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width < 900) return child;
    return ColoredBox(color: K.bg, child: Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820), child: child)));
  }
}
