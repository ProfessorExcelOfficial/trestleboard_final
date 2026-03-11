import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard_screen.dart';

class MemberProfileScreen extends StatefulWidget {
  const MemberProfileScreen({super.key});

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  final supabase = Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();

  final firstNameController = TextEditingController();
  final middleNameController = TextEditingController();
  final familyNameController = TextEditingController();
  final emailController = TextEditingController();

  String? selectedSuffix;

  bool loading = false;

  static const List<String> suffixOptions = [
    'Jr.',
    'Sr.',
    'II',
    'III',
    'IV',
    'V',
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  void _loadExistingData() {
    final user = supabase.auth.currentUser;
    if (user != null) {
      emailController.text = user.email ?? '';
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => loading = true);

    try {
      await supabase.from('user_profiles').update({
        'first_name': firstNameController.text.trim(),
        'middle_name': middleNameController.text.trim(),
        'family_name': familyNameController.text.trim(),
        'suffix': selectedSuffix,
        'email': emailController.text.trim(),

        // ============================
        // LIFECYCLE TRANSITION
        // ============================
        'profile_completed': true,
        'invite_status': 'ACTIVE',
        'status': 'ACTIVE',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  void dispose() {
    firstNameController.dispose();
    middleNameController.dispose();
    familyNameController.dispose();
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Complete Your Profile"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Welcome to Trestle Board",
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Please complete your profile to continue.",
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: middleNameController,
                decoration: const InputDecoration(
                  labelText: 'Middle Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: familyNameController,
                decoration: const InputDecoration(
                  labelText: 'Family Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: selectedSuffix,
                decoration: const InputDecoration(
                  labelText: 'Suffix (Optional)',
                  border: OutlineInputBorder(),
                ),
                items: suffixOptions
                    .map(
                      (suffix) =>
                          DropdownMenuItem(value: suffix, child: Text(suffix)),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedSuffix = value;
                  });
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 40),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: loading ? null : _saveProfile,
                  child: loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text("Save and Continue"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
