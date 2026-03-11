import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminMemberReqScreen extends StatefulWidget {
  const AdminMemberReqScreen({super.key});

  @override
  State<AdminMemberReqScreen> createState() => _AdminMemberReqScreenState();
}

class _AdminMemberReqScreenState extends State<AdminMemberReqScreen> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  final lodgeNoController = TextEditingController();
  final firstNameController = TextEditingController();
  final middleNameController = TextEditingController();
  final familyNameController = TextEditingController();
  final suffixController = TextEditingController();
  final emailController = TextEditingController();
  final birthdayController = TextEditingController();

  bool isSubmitting = false;
  bool isSearching = false;

  Map<String, dynamic>? selectedLodge;

  // ----------------------------------------------------------
  // Normalize names
  // ----------------------------------------------------------

  String normalize(String value) {
    if (value.trim().isEmpty) return '';
    final text = value.trim();
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  // ----------------------------------------------------------
  // Dialog Helpers
  // ----------------------------------------------------------

  Future<void> showErrorDialog(String title, String message) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }

  Future<void> showSuccessDialog() async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Request Submitted"),
        content: const Text(
          "The membership request has been successfully submitted and will be reviewed by lodge officers.",
        ),
        actions: [
          TextButton(
            child: const Text("OK"),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
          )
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // Fetch Lodge
  // ----------------------------------------------------------

  Future<void> _fetchLodge() async {
    final lodgeNo = lodgeNoController.text.trim();

    if (lodgeNo.isEmpty) {
      await showErrorDialog("Missing Lodge Number", "Enter a lodge number.");
      return;
    }

    final lodgeNumber = int.tryParse(lodgeNo);

    if (lodgeNumber == null) {
      await showErrorDialog("Invalid Lodge Number", "Enter a valid number.");
      return;
    }

    setState(() {
      isSearching = true;
      selectedLodge = null;
    });

    try {
      final lodge = await supabase
          .from('lodges')
          .select('id, lodge_number, lodge_name, status')
          .eq('lodge_number', lodgeNumber)
          .eq('status', 'ACTIVE')
          .maybeSingle();

      if (!mounted) return;

      if (lodge == null) {
        await showErrorDialog(
          "Lodge Not Found",
          "The lodge number does not exist or is inactive.",
        );
      }

      setState(() {
        selectedLodge = lodge;
      });
    } catch (e) {
      await showErrorDialog(
        "System Error",
        "Unable to retrieve lodge information.",
      );
    }

    if (mounted) {
      setState(() => isSearching = false);
    }
  }

  // ----------------------------------------------------------
  // Submit Request
  // ----------------------------------------------------------

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedLodge == null) {
      await showErrorDialog(
        "Lodge Required",
        "Please search and select a valid lodge first.",
      );
      return;
    }

    setState(() => isSubmitting = true);

    final email = emailController.text.trim().toLowerCase();

    try {
      // ------------------------------------------------------
      // Prevent duplicate pending requests
      // ------------------------------------------------------

      final existing = await supabase
          .from('req_members')
          .select('id')
          .eq('email', email)
          .eq('status', 'PENDING')
          .maybeSingle();

      if (existing != null) {
        await showErrorDialog(
          "Account Already Exists",
          "This email already has a pending membership request.",
        );
        setState(() => isSubmitting = false);
        return;
      }

      // ------------------------------------------------------
      // Find or Create Brethren
      // ------------------------------------------------------

      final brethrenId = await supabase.rpc(
        'find_or_create_brethren',
        params: {
          'p_first_name': normalize(firstNameController.text),
          'p_middle_name': normalize(middleNameController.text),
          'p_family_name': normalize(familyNameController.text),
          'p_suffix': suffixController.text.trim(),
          'p_birthday': birthdayController.text,
        },
      );

      // ------------------------------------------------------
      // Insert Request
      // ------------------------------------------------------

      await supabase.from('req_members').insert({
        'lodge_id': selectedLodge!['id'],
        'brethren_id': brethrenId,
        'first_name': normalize(firstNameController.text),
        'middle_name': normalize(middleNameController.text),
        'family_name': normalize(familyNameController.text),
        'suffix': suffixController.text.trim(),
        'birthday': birthdayController.text,
        'email': email,
        'status': 'PENDING',
        'created_by': supabase.auth.currentUser!.id,
      });

      await showSuccessDialog();
    } catch (e, stack) {
      debugPrint("REQUEST ERROR: $e");
      debugPrint(stack.toString());

      await showErrorDialog(
        "System Error",
        "Error: $e",
      );
    }

    if (mounted) {
      setState(() => isSubmitting = false);
    }
  }

  @override
  void dispose() {
    lodgeNoController.dispose();
    firstNameController.dispose();
    middleNameController.dispose();
    familyNameController.dispose();
    suffixController.dispose();
    emailController.dispose();
    birthdayController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------
  // UI
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("New Member Request"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              /// Lodge Search
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: lodgeNoController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Lodge Number",
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? "Required" : null,
                      onChanged: (_) {
                        selectedLodge = null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: isSearching ? null : _fetchLodge,
                    child: isSearching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text("Search"),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              if (selectedLodge != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Text(
                    "✓ ${selectedLodge!['lodge_name']} (#${selectedLodge!['lodge_number']})",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),

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
                controller: familyNameController,
                decoration: const InputDecoration(labelText: "Family Name"),
                validator: (v) => v == null || v.isEmpty ? "Required" : null,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: birthdayController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "Birthday",
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                validator: (v) => v == null || v.isEmpty ? "Required" : null,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime(1990),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );

                  if (date != null) {
                    birthdayController.text =
                        date.toIso8601String().split('T').first;
                  }
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: suffixController,
                decoration: const InputDecoration(labelText: "Suffix"),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: "Email"),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return "Required";
                  if (!RegExp(r'\S+@\S+\.\S+').hasMatch(v)) {
                    return "Invalid email";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : _submit,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text("Create Member Request"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
