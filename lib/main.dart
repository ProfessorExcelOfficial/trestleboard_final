import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme/app_theme.dart';
import 'screen/intro_screen.dart';
import 'screen/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://elbimcshhoqvohczvjbe.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVsYmltY3NoaG9xdm9oY3p2amJlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEyNTE1MjcsImV4cCI6MjA4NjgyNzUyN30.SJBJykKMjWpgaGJu_7P_85cd4TqadN82W7SDqoyjnk4',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      detectSessionInUri: true,
    ),
  );

  runApp(const TrestleBoardApp());
}

class TrestleBoardApp extends StatelessWidget {
  const TrestleBoardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Trestle Board",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,

      // App entry point
      home: const AppEntry(),
    );
  }
}

class AppEntry extends StatelessWidget {
  const AppEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;

        if (session != null) {
          return const AuthGate();
        }

        return const IntroScreen();
      },
    );
  }
}
