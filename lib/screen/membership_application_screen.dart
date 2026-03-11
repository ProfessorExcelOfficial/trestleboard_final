import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MembershipApplicationScreen extends StatefulWidget {
  final String email;

  const MembershipApplicationScreen({super.key, required this.email});

  @override
  State<MembershipApplicationScreen> createState() =>
      _MembershipApplicationScreenState();
}

class _MembershipApplicationScreenState
    extends State<MembershipApplicationScreen> {
  final _formKey = GlobalKey<FormState>();

  final firstNameController = TextEditingController();
  final middleNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final suffixController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  int? selectedLodgeId;
  List<Map<String, dynamic>> lodges = [];

  File? selfieFile;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchActiveLodges();
  }

  Future<void> _fetchActiveLodges() async {
    final supabase = Supabase.instance.client;

    final response = await supabase
        .from('lodges')
        .select('id, lodge_name, lodge_number')
        .eq('status', 'ACTIVE');

    setState(() {
      lodges = List<Map<String, dynamic>>.from(response);
    });
  }

  Future<void> _pickSelfie() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);

    if (picked != null) {
      setState(() {
        selfieFile = File(picked.path);
      });
    }
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    if (selfieFile == null) {
      _showError("Selfie is required.");
      return;
    }

    final password = passwordController.text.trim();
    final confirm = confirmPasswordController.text.trim();

    if (password != confirm) {
      _showError("Passwords do not match.");
      return;
    }

    try {
      setState(() => isLoading = true);

      final supabase = Supabase.instance.client;

      // 1️⃣ Create Auth User
      final authRes = await supabase.auth.signUp(
        email: widget.email,
        password: password,
      );

      if (authRes.user == null) {
        _showError("Signup failed.");
        return;
      }

      final userId = authRes.user!.id;

      // 2️⃣ Upload Selfie
      final fileName = '$userId.jpg';

      await supabase.storage
          .from('member-selfies')
          .upload(fileName, selfieFile!);

      final publicUrl =
          supabase.storage.from('member-selfies').getPublicUrl(fileName);

      // 3️⃣ Insert Membership Request
      await supabase.from('membership_requests').insert({
        'user_id': userId,
        'lodge_id': selectedLodgeId,
        'first_name': firstNameController.text.trim(),
        'middle_name': middleNameController.text.trim(),
        'last_name': lastNameController.text.trim(),
        'suffix': suffixController.text.trim(),
        'selfie_url': publicUrl,
        'status': 'PENDING',
      });

      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      _showError("Application failed: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    firstNameController.dispose();
    middleNameController.dispose();
    lastNameController.dispose();
    suffixController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Membership Application")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                Text("Email: ${widget.email}"),
                const SizedBox(height: 24),
                TextFormField(
                  controller: firstNameController,
                  decoration: const InputDecoration(labelText: "First Name"),
                  validator: (v) => v == null || v.isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: middleNameController,
                  decoration: const InputDecoration(labelText: "Middle Name"),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: lastNameController,
                  decoration: const InputDecoration(labelText: "Family Name"),
                  validator: (v) => v == null || v.isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: suffixController,
                  decoration: const InputDecoration(labelText: "Suffix"),
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<int>(
                  initialValue: selectedLodgeId,
                  decoration: const InputDecoration(
                    labelText: "Select Lodge",
                  ),
                  items: lodges
                      .map(
                        (l) => DropdownMenuItem<int>(
                          value: l['id'],
                          child: Text(
                            "${l['lodge_name']} No. ${l['lodge_number']}",
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedLodgeId = value;
                    });
                  },
                  validator: (v) => v == null ? "Please select a lodge" : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _pickSelfie,
                  child: const Text("Take Selfie"),
                ),
                if (selfieFile != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Image.file(selfieFile!, height: 120),
                  ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Password"),
                  validator: (v) => v == null || v.isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: "Confirm Password"),
                  validator: (v) => v == null || v.isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submitApplication,
                    child: isLoading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : const Text("Submit Application"),
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
