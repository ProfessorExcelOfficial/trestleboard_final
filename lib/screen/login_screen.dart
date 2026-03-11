import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

// Screens
import 'signup_email_screen.dart';
import 'dashboard_screen.dart';
import 'admin_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool isLoading = false;
  bool obscurePassword = true;
  bool rememberMe = false;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ==========================================================
  // Load Remembered Email
  // ==========================================================
  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberedEmail = prefs.getString('remembered_email');

    if (rememberedEmail != null) {
      setState(() {
        emailController.text = rememberedEmail;
        rememberMe = true;
      });
    }
  }

  // ==========================================================
  // Clean Login Logic (Using get_user_role RPC)
  // ==========================================================
  Future<void> _loginWithEmail() async {
    FocusScope.of(context).unfocus();

    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError("Email and password are required.");
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;

      if (user == null) {
        _showError("Authentication failed.");
        return;
      }

      // ------------------------------------------------------
      // Remember Email
      // ------------------------------------------------------
      final prefs = await SharedPreferences.getInstance();

      if (rememberMe) {
        await prefs.setString('remembered_email', email);
      } else {
        await prefs.remove('remembered_email');
      }

      // ------------------------------------------------------
      // Link Auth User to Member Record
      // ------------------------------------------------------
      await supabase.rpc('link_member_account');

      // ------------------------------------------------------
      // GET USER ROLE (Single RPC)
      // ------------------------------------------------------
      final result = await supabase.rpc('get_user_role');

      final role = result['role'];

      if (!mounted) return;

      // ------------------------------------------------------
      // ROUTE USER BASED ON ROLE
      // ------------------------------------------------------

      if (role == 'GlobalAdmin') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AdminScreen()),
          (route) => false,
        );
        return;
      }

      if (role == 'None') {
        await supabase.auth.signOut();
        _showError("Member record not found. Contact administrator.");
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError("Unexpected error occurred.");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ==========================================================
  // Error Snackbar
  // ==========================================================
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  // ==========================================================
  // UI
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.lightTheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        const SizedBox(height: 80),
                        Text(
                          "TRESTLE BOARD",
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 50),
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: "Email",
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          decoration: InputDecoration(
                            labelText: "Password",
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  obscurePassword = !obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Checkbox(
                              value: rememberMe,
                              onChanged: (value) {
                                setState(() {
                                  rememberMe = value ?? false;
                                });
                              },
                            ),
                            const Text("Remember Me"),
                          ],
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _loginWithEmail,
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text("Login"),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SignupEmailScreen(),
                              ),
                            );
                          },
                          child: const Text("Signup"),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
