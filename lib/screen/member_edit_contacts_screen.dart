import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemberEditContactsScreen extends StatefulWidget {
  final String brethrenId;
  final String? mobile;
  final String? emergencyName;
  final String? emergencyPhone;

  const MemberEditContactsScreen({
    super.key,
    required this.brethrenId,
    this.mobile,
    this.emergencyName,
    this.emergencyPhone,
  });

  @override
  State<MemberEditContactsScreen> createState() =>
      _MemberEditContactsScreenState();
}

class _MemberEditContactsScreenState extends State<MemberEditContactsScreen> {
  final supabase = Supabase.instance.client;

  final mobileController = TextEditingController();
  final emergencyNameController = TextEditingController();
  final emergencyPhoneController = TextEditingController();

  bool saving = false;

  @override
  void initState() {
    super.initState();
    mobileController.text = widget.mobile ?? "";
    emergencyNameController.text = widget.emergencyName ?? "";
    emergencyPhoneController.text = widget.emergencyPhone ?? "";
  }

  Future<void> saveContacts() async {
    setState(() => saving = true);

    try {
      /// MOBILE
      final mobileExisting = await supabase
          .from('brethren_contact_numbers')
          .select('id')
          .eq('brethren_id', widget.brethrenId)
          .eq('label', 'MOBILE')
          .maybeSingle();

      if (mobileExisting == null) {
        await supabase.from('brethren_contact_numbers').insert({
          "brethren_id": widget.brethrenId,
          "contact_number": mobileController.text.trim(),
          "label": "MOBILE",
          "is_primary": true,
          "visibility": "PRIVATE"
        });
      } else {
        await supabase
            .from('brethren_contact_numbers')
            .update({
              "contact_number": mobileController.text.trim(),
            })
            .eq('brethren_id', widget.brethrenId)
            .eq('label', 'MOBILE');
      }

      /// EMERGENCY CONTACT
      final emergencyExisting = await supabase
          .from('brethren_contact_numbers')
          .select('id')
          .eq('brethren_id', widget.brethrenId)
          .eq('label', 'EMERGENCY')
          .maybeSingle();

      if (emergencyExisting == null) {
        await supabase.from('brethren_contact_numbers').insert({
          "brethren_id": widget.brethrenId,
          "contact_name": emergencyNameController.text.trim(),
          "contact_number": emergencyPhoneController.text.trim(),
          "label": "EMERGENCY",
          "visibility": "PRIVATE"
        });
      } else {
        await supabase
            .from('brethren_contact_numbers')
            .update({
              "contact_name": emergencyNameController.text.trim(),
              "contact_number": emergencyPhoneController.text.trim(),
            })
            .eq('brethren_id', widget.brethrenId)
            .eq('label', 'EMERGENCY');
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Save contacts error: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to save contacts")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Widget field(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    mobileController.dispose();
    emergencyNameController.dispose();
    emergencyPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Update Contacts")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            field("Mobile Number", mobileController),
            field("Emergency Contact Name", emergencyNameController),
            field("Emergency Phone", emergencyPhoneController),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: saving ? null : saveContacts,
              child: saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Save"),
            )
          ],
        ),
      ),
    );
  }
}
