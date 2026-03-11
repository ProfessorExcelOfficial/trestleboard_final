import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'password_change_screen.dart';

class SignupEmailScreen extends StatefulWidget {
  const SignupEmailScreen({super.key});

  @override
  State<SignupEmailScreen> createState() => _SignupEmailScreenState();
}

class _SignupEmailScreenState extends State<SignupEmailScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController codeController = TextEditingController();

  bool isLoading = false;

  int failedAttempts = 0;
  DateTime? cooldownUntil;

  static const int maxAttempts = 5;
  static const int cooldownSeconds = 10;

  final supabase = Supabase.instance.client;

  Future<void> _handleNext() async {
    if (isLoading) return;

    // ------------------------------
    // Cooldown protection
    // ------------------------------
    if (cooldownUntil != null && DateTime.now().isBefore(cooldownUntil!)) {
      final remaining = cooldownUntil!.difference(DateTime.now()).inSeconds;
      _showError("Please wait $remaining seconds before trying again.");
      return;
    }

    final email = emailController.text.trim().toLowerCase();
    final code = codeController.text.trim().toUpperCase();

    if (email.isEmpty || code.isEmpty) {
      _showError("Email and enrollment code are required.");
      return;
    }

    if (code.length != 8) {
      _showError("Enrollment code must be 8 characters.");
      return;
    }

    try {
      setState(() => isLoading = true);

      // ------------------------------
      // Call RPC to verify passcode
      // ------------------------------
      final memberId = await supabase.rpc(
        'verify_member_passcode',
        params: {
          'p_email': email,
          'p_code': code,
        },
      );

      if (memberId == null) {
        _handleFailure("Invalid enrollment code.");
        return;
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PasswordChangeScreen(
            email: email,
            memberId: memberId,
          ),
        ),
      );
    } catch (e) {
      _handleFailure("Invalid or expired enrollment code.");
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // ------------------------------
  // Failure handling + cooldown
  // ------------------------------
  void _handleFailure(String message) {
    failedAttempts++;

    if (failedAttempts >= maxAttempts) {
      cooldownUntil =
          DateTime.now().add(const Duration(seconds: cooldownSeconds));
      failedAttempts = 0;
    }

    _showError(message);
  }

  void _showError(String msg) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sign Up")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              const Text(
                "Enter the email and enrollment code provided by your lodge.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),

              const SizedBox(height: 40),

              // ------------------------------
              // Email field
              // ------------------------------
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              // ------------------------------
              // Code field
              // ------------------------------
              TextField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: "Enrollment Code",
                  hintText: "Enter 8-character code",
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  final upper = value.toUpperCase();
                  codeController.value = codeController.value.copyWith(
                    text: upper,
                    selection: TextSelection.collapsed(offset: upper.length),
                  );
                },
              ),

              const SizedBox(height: 40),

              // ------------------------------
              // Verify button
              // ------------------------------
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _handleNext,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Verify & Continue"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
