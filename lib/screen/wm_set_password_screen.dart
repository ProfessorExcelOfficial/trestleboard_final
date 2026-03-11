import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WmSetPasswordScreen extends StatefulWidget {
  final String email;

  const WmSetPasswordScreen({super.key, required this.email});

  @override
  State<WmSetPasswordScreen> createState() => _WmSetPasswordScreenState();
}

class _WmSetPasswordScreenState extends State<WmSetPasswordScreen> {
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();

  bool isLoading = false;

  Future<void> _activateAccount() async {
    final password = passwordController.text.trim();
    final confirm = confirmController.text.trim();

    if (password.isEmpty || confirm.isEmpty) {
      _showError("All fields are required.");
      return;
    }

    if (password != confirm) {
      _showError("Passwords do not match.");
      return;
    }

    try {
      setState(() => isLoading = true);

      final supabase = Supabase.instance.client;

      // 1️⃣ Create Auth User
      final response = await supabase.auth.signUp(
        email: widget.email,
        password: password,
      );

      if (response.user == null) {
        _showError("Account creation failed.");
        return;
      }

      final userId = response.user!.id;

      // 2️⃣ Bind user_profiles
      await supabase.from('user_profiles').update({
        'id': userId,
        'invite_status': 'VERIFIED',
      }).eq('email', widget.email);

      // 3️⃣ Attach lodge
      await supabase.from('lodges').update({
        'wm_user_id': userId,
      }).eq('wm_email', widget.email);

      if (!mounted) return;

      // 4️⃣ Return to root (IntroScreen will route properly)
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      _showError("Activation failed: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
      appBar: AppBar(title: const Text("Set Your Password")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Activate Worshipful Master Account",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text("Email: ${widget.email}"),
            const SizedBox(height: 32),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Confirm Password",
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _activateAccount,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Activate Account"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
