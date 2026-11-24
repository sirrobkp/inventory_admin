import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens_login.dart';
import 'screens_shell.dart';
import 'state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light, systemNavigationBarColor: K.bg));
  final state = AdminState();
  await state.boot();
  runApp(ChangeNotifierProvider.value(value: state, child: const AdminApp()));
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Kibo Admin',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: Consumer<AdminState>(builder: (_, s, __) => s.signedIn ? const AdminShell() : const LoginScreen()),
      );
}
