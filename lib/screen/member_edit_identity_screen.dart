import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/member_profile.dart';

class MemberEditIdentityScreen extends StatefulWidget {
  final MemberProfile profile;

  const MemberEditIdentityScreen({
    super.key,
    required this.profile,
  });

  @override
  State<MemberEditIdentityScreen> createState() =>
      _MemberEditIdentityScreenState();
}

class _MemberEditIdentityScreenState extends State<MemberEditIdentityScreen> {
  final supabase = Supabase.instance.client;

  DateTime? birthday;
  String? bloodType;

  final reasonController = TextEditingController();

  bool saving = false;

  final bloodTypes = ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"];

  @override
  void initState() {
    super.initState();

    birthday = widget.profile.birthday;
    bloodType = widget.profile.bloodType;
  }

  String formatDate(DateTime? date) {
    if (date == null) return "Select Date";
    return DateFormat('MMM d, yyyy').format(date);
  }

  Future<void> pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: birthday ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        birthday = picked;
      });
    }
  }

  Future<void> submitCorrection() async {
    setState(() {
      saving = true;
    });

    try {
      final user = supabase.auth.currentUser;

      final List<Map<String, dynamic>> requests = [];

      if (birthday != widget.profile.birthday) {
        requests.add({
          "brethren_id": widget.profile.brethrenId,
          "requested_by": user!.id,
          "field_name": "birthday",
          "old_value": widget.profile.birthday?.toIso8601String(),
          "new_value": birthday?.toIso8601String(),
          "reason": reasonController.text
        });
      }

      if (bloodType != widget.profile.bloodType) {
        requests.add({
          "brethren_id": widget.profile.brethrenId,
          "requested_by": user!.id,
          "field_name": "blood_type",
          "old_value": widget.profile.bloodType,
          "new_value": bloodType,
          "reason": reasonController.text
        });
      }

      if (requests.isNotEmpty) {
        for (final r in requests) {
          await supabase
              .from('brethren_correction_requests')
              .delete()
              .eq('brethren_id', widget.profile.brethrenId)
              .eq('field_name', r['field_name'])
              .eq('status', 'PENDING');

          await supabase.from('brethren_correction_requests').insert(r);
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to submit correction")),
      );
    }

    setState(() {
      saving = false;
    });
  }

  Widget sectionCard(List<Widget> children) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Update Identity"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          sectionCard([
            fieldLabel("Birthday"),
            ListTile(
              title: Text(formatDate(birthday)),
              trailing: const Icon(Icons.calendar_today),
              onTap: pickBirthday,
            ),
            fieldLabel("Blood Type"),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButtonFormField<String>(
                value: bloodType,
                items: bloodTypes.map((b) {
                  return DropdownMenuItem(
                    value: b,
                    child: Text(b),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    bloodType = val;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            fieldLabel("Reason for Correction"),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: "Explain why this correction is needed",
                ),
              ),
            ),
            const SizedBox(height: 20),
          ]),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: saving ? null : submitCorrection,
            child: saving
                ? const CircularProgressIndicator()
                : const Text("Submit Correction Request"),
          ),
        ],
      ),
    );
  }
}
