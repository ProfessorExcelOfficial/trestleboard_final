import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'admin_screen.dart';
import 'member_profile_screen.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final supabase = Supabase.instance.client;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  StreamSubscription<AuthState>? _authSubscription;

  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();

    print("IntroScreen initialized");

    /// Listen to auth state changes
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) async {
      print("Auth event: ${data.event}");

      if (_isNavigating) return;

      if (data.event == AuthChangeEvent.signedIn) {
        await _routeUser();
      }

      if (data.event == AuthChangeEvent.signedOut) {
        await _navigateToLogin();
      }
    });

    /// Cold start session check
    Future.delayed(const Duration(milliseconds: 900), () async {
      if (_isNavigating) return;

      final session = supabase.auth.currentSession;

      if (session == null) {
        print("No session → navigating to Login");
        await _navigateToLogin();
      } else {
        print("Session found → routing user");
        await _routeUser();
      }
    });
  }

  /// Handle resume (deep links / auth return)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      print("App resumed → checking session again");

      _isNavigating = false;
      await _routeUser();
    }
  }

  // ==========================================================
  // CENTRAL ROUTING
  // ==========================================================
  Future<void> _routeUser() async {
    if (_isNavigating) return;
    _isNavigating = true;

    print("======== ROUTE USER ========");

    final session = supabase.auth.currentSession;

    if (!mounted) return;

    if (session == null) {
      await _navigateToLogin();
      return;
    }

    try {
      final profile = await supabase
          .from('user_profiles')
          .select('role, profile_completed, invite_status')
          .eq('id', session.user.id)
          .maybeSingle();

      if (profile == null) {
        print("Profile not found → forcing logout");

        await supabase.auth.signOut();
        await _navigateToLogin();
        return;
      }

      final String role = profile['role'] ?? 'Member';
      final bool completed = profile['profile_completed'] ?? false;
      final String inviteStatus = profile['invite_status'] ?? 'ACTIVE';

      print("ROLE: $role");
      print("COMPLETED: $completed");

      /// Auto verify invite lifecycle
      if ((inviteStatus == 'INVITED' || inviteStatus == 'RESENT') &&
          completed == false) {
        await supabase.from('user_profiles').update({
          'invite_status': 'VERIFIED',
        }).eq('id', session.user.id);
      }

      await _animationController.reverse();

      if (!mounted) return;

      if (role == 'Admin') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AdminScreen()),
          (route) => false,
        );
      } else {
        if (!completed) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MemberProfileScreen()),
            (route) => false,
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      print("Routing error: $e");

      await supabase.auth.signOut();
      await _navigateToLogin();
    }
  }

  Future<void> _navigateToLogin() async {
    if (_isNavigating) return;
    _isNavigating = true;

    await _animationController.reverse();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    _authSubscription?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              children: [
                /// CENTER AREA
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          width: 150,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Trestle Board",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A2A66),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                /// BOTTOM BRANDING
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    children: [
                      const Text(
                        "Powered by",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Image.asset(
                        'assets/images/profex.png',
                        width: 180,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
