import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

class PasswordChangeScreen extends StatefulWidget {
  final String email;
  final String memberId;

  const PasswordChangeScreen({
    super.key,
    required this.email,
    required this.memberId,
  });

  @override
  State<PasswordChangeScreen> createState() => _PasswordChangeScreenState();
}

class _PasswordChangeScreenState extends State<PasswordChangeScreen> {
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirm = true;

  bool _isValidPassword(String password) {
    final hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    final hasMinLength = password.length >= 8;

    return hasUppercase && hasNumber && hasMinLength;
  }

  Future<void> _createAccount() async {
    if (isLoading) return;

    final password = passwordController.text.trim();
    final confirm = confirmController.text.trim();

    if (password.isEmpty || confirm.isEmpty) {
      _showError("Please enter your password.");
      return;
    }

    if (!_isValidPassword(password)) {
      _showError(
        "Password must be at least 8 characters and include one uppercase letter and one number.",
      );
      return;
    }

    if (password != confirm) {
      _showError("Passwords do not match.");
      return;
    }

    try {
      setState(() => isLoading = true);

      final supabase = Supabase.instance.client;

      final response = await supabase.auth.signUp(
        email: widget.email,
        password: password,
      );

      final user = response.user;

      if (user == null) {
        _showError("Account creation failed.");
        return;
      }

      //------------------------------------------------
      // Link member
      //------------------------------------------------

      await supabase
          .from('members')
          .update({'user_id': user.id})
          .eq('id', widget.memberId)
          .filter('user_id', 'is', null);

      //------------------------------------------------

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Account created successfully. Please log in."),
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      print("REGISTRATION ERROR:");
      print(e);

      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  void dispose() {
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Password")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Text(
                widget.email,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: "Password",
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: confirmController,
                obscureText: obscureConfirm,
                decoration: InputDecoration(
                  labelText: "Confirm Password",
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirm ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        obscureConfirm = !obscureConfirm;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _createAccount,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Create Account"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
