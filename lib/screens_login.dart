import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'icons.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

const setupSteps = '''1. In the Firebase console create (or open) your project and add a Firestore Database.
2. Authentication > Sign-in method: enable Email/Password AND Anonymous (subscribers' apps use Anonymous).
3. Authentication > Users: add your admin email + password and copy that user's UID.
4. Firestore > Data: create collection "admins" with a document whose ID is that UID (any field, e.g. role = "owner").
5. Firestore > Rules: paste the rules (button below) and Publish.
6. Project settings > General: copy the Project ID and the Web API key.
7. In your Kibo Trade source, set the same Project ID and Web API key in lib/license_config.dart, then build the POS app.''';

void showSetup(BuildContext context) => showSheet(
      context,
      Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Setup help', style: t(18, w: FontWeight.w800)),
        const SizedBox(height: 12),
        Text(setupSteps, style: t(12, w: FontWeight.w500, c: K.muted, h: 1.6)),
        const SizedBox(height: 14),
        LimeButton('Copy Firestore security rules', icon: Ic.copy, outline: true, onTap: () async {
          await Clipboard.setData(const ClipboardData(text: firestoreRules));
          if (context.mounted) toast(context, 'Rules copied - paste them in Firestore > Rules > Publish');
        }),
      ]),
    );

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final AdminState s = context.read<AdminState>();
  late final project = TextEditingController(text: s.project);
  late final key = TextEditingController(text: s.apiKey);
  late final email = TextEditingController(text: s.email);
  final password = TextEditingController();
  bool busy = false;
  String error = '';

  Future<void> _go() async {
    if (project.text.trim().isEmpty || key.text.trim().isEmpty || email.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => error = 'Fill in all four fields');
      return;
    }
    setState(() { busy = true; error = ''; });
    final e = await s.signIn(project.text, key.text, email.text, password.text);
    if (mounted) setState(() { busy = false; error = e ?? ''; });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [K.bg2, K.bg])),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(24), children: [
                  const Align(alignment: Alignment.centerLeft, child: LogoMark()),
                  const SizedBox(height: 18),
                  Text('Kibo Admin', style: t(26, w: FontWeight.w800, ls: -1)),
                  const SizedBox(height: 6),
                  Text('Manage subscriptions and monitor every Kibo Trade installation.', style: t(12, w: FontWeight.w500, c: K.muted, h: 1.5)),
                  const SizedBox(height: 22),
                  for (final f in [(project, 'Firebase project ID', false), (key, 'Web API key', false), (email, 'Admin email', false), (password, 'Password', true)])
                    Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: f.$1, obscureText: f.$3, autocorrect: false, enableSuggestions: false, onSubmitted: (_) => _go(), style: t(13, w: FontWeight.w500), decoration: dec(f.$2))),
                  if (error.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(error, style: t(11, w: FontWeight.w600, c: K.danger, h: 1.4))),
                  LimeButton('Sign in', icon: Ic.check, busy: busy, onTap: _go),
                  const SizedBox(height: 14),
                  Center(child: MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(onTap: () => showSetup(context), child: Text('First time? Setup help', style: t(12, c: K.lime))))),
                ]),
              ),
            ),
          ),
        ),
      );
}
