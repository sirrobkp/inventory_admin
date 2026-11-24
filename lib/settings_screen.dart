import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'icons.dart';
import 'responsive.dart';
import 'screens_login.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final AdminState s = context.read<AdminState>();
  late final price = TextEditingController(text: '${s.config.monthlyPrice}');
  late final trial = TextEditingController(text: '${s.config.trialDays}');
  late final grace = TextEditingController(text: '${s.config.graceDays}');
  late final offline = TextEditingController(text: '${s.config.maxOfflineDays}');
  late final instr = TextEditingController(text: s.config.paymentInstructions);
  late final support = TextEditingController(text: s.config.supportContact);
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    Widget numField(TextEditingController c, String l) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: c, keyboardType: TextInputType.number, style: t(13, w: FontWeight.w500), decoration: dec(l)));
    return ListView(padding: EdgeInsets.only(bottom: bottomPad(context)), children: [
      const Header(title: 'Settings', subtitle: 'Subscription terms'),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: hPad(context)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('These apply to every subscriber and are read by their apps.', style: t(11, w: FontWeight.w500, c: K.muted, h: 1.5)),
          const SizedBox(height: 14),
          numField(price, 'Monthly price (TZS)'),
          Row(children: [Expanded(child: numField(trial, 'Free trial (days)')), const SizedBox(width: 10), Expanded(child: numField(grace, 'Grace after expiry (days)'))]),
          numField(offline, 'Max days a phone may stay offline before it must re-verify'),
          Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: instr, minLines: 3, maxLines: 6, style: t(13, w: FontWeight.w500), decoration: dec('How to pay (shown on the lock screen)  e.g. M-Pesa 0712 000 000, name'))),
          Padding(padding: const EdgeInsets.only(bottom: 16), child: TextField(controller: support, style: t(13, w: FontWeight.w500), decoration: dec('Support contact (phone / WhatsApp)'))),
          LimeButton('Save terms', icon: Ic.check, busy: busy, onTap: () async {
            setState(() => busy = true);
            final e = await s.saveConfig(AppConfig(
              monthlyPrice: int.tryParse(price.text) ?? 50000,
              trialDays: (int.tryParse(trial.text) ?? 14).clamp(0, 15).toInt(),
              graceDays: int.tryParse(grace.text) ?? 3,
              maxOfflineDays: int.tryParse(offline.text) ?? 14,
              paymentInstructions: instr.text.trim(),
              supportContact: support.text.trim(),
            ));
            if (mounted) {
              setState(() => busy = false);
              toast(context, e ?? 'Saved');
            }
          }),
          const SizedBox(height: 6),
          Text('Trial length is capped at 15 days by the security rules.', style: t(10, w: FontWeight.w500, c: K.dim)),
          const SizedBox(height: 24),
          Text('CONNECTED PROJECT', style: t(10, w: FontWeight.w800, c: K.muted, ls: 1.6)),
          const SizedBox(height: 8),
          Text('${s.project}\n${s.email}', style: mono(11, c: K.muted)),
          const SizedBox(height: 14),
          LimeButton('Setup help & security rules', icon: Ic.copy, outline: true, onTap: () => showSetup(context)),
          const SizedBox(height: 10),
          LimeButton('Sign out', icon: Ic.logout, outline: true, onTap: () => s.signOut()),
        ]),
      ),
    ]);
  }
}
