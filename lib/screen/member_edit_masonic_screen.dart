import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/member_profile.dart';

class MemberEditMasonicScreen extends StatefulWidget {
  final MemberProfile profile;

  const MemberEditMasonicScreen({
    super.key,
    required this.profile,
  });

  @override
  State<MemberEditMasonicScreen> createState() =>
      _MemberEditMasonicScreenState();
}

class _MemberEditMasonicScreenState extends State<MemberEditMasonicScreen> {
  final supabase = Supabase.instance.client;

  DateTime? enteredApprentice;
  DateTime? fellowcraft;
  DateTime? masterMason;

  final reasonController = TextEditingController();

  bool saving = false;

  @override
  void initState() {
    super.initState();

    enteredApprentice = widget.profile.enteredApprentice;
    fellowcraft = widget.profile.fellowcraft;
    masterMason = widget.profile.masterMason;
  }

  String formatDate(DateTime? date) {
    if (date == null) return "Select Date";
    return DateFormat('MMM d, yyyy').format(date);
  }

  Future<void> pickDate({
    required DateTime? current,
    required Function(DateTime) onSelected,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(2000),
      firstDate: DateTime(1800),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      onSelected(picked);
    }
  }

  Future<void> submitCorrection() async {
    setState(() {
      saving = true;
    });

    try {
      final user = supabase.auth.currentUser;

      final List<Map<String, dynamic>> requests = [];

      if (enteredApprentice != widget.profile.enteredApprentice) {
        requests.add({
          "brethren_id": widget.profile.brethrenId,
          "requested_by": user!.id,
          "field_name": "entered_apprentice",
          "old_value": widget.profile.enteredApprentice?.toIso8601String(),
          "new_value": enteredApprentice?.toIso8601String(),
          "reason": reasonController.text
        });
      }

      if (fellowcraft != widget.profile.fellowcraft) {
        requests.add({
          "brethren_id": widget.profile.brethrenId,
          "requested_by": user!.id,
          "field_name": "fellowcraft",
          "old_value": widget.profile.fellowcraft?.toIso8601String(),
          "new_value": fellowcraft?.toIso8601String(),
          "reason": reasonController.text
        });
      }

      if (masterMason != widget.profile.masterMason) {
        requests.add({
          "brethren_id": widget.profile.brethrenId,
          "requested_by": user!.id,
          "field_name": "master_mason",
          "old_value": widget.profile.masterMason?.toIso8601String(),
          "new_value": masterMason?.toIso8601String(),
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

  Widget dateTile({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        fieldLabel(label),
        ListTile(
          title: Text(formatDate(value)),
          trailing: const Icon(Icons.calendar_today),
          onTap: onTap,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Update Masonic Record"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          sectionCard([
            dateTile(
              label: "Entered Apprentice",
              value: enteredApprentice,
              onTap: () {
                pickDate(
                  current: enteredApprentice,
                  onSelected: (d) {
                    setState(() {
                      enteredApprentice = d;
                    });
                  },
                );
              },
            ),
            dateTile(
              label: "Fellowcraft",
              value: fellowcraft,
              onTap: () {
                pickDate(
                  current: fellowcraft,
                  onSelected: (d) {
                    setState(() {
                      fellowcraft = d;
                    });
                  },
                );
              },
            ),
            dateTile(
              label: "Master Mason",
              value: masterMason,
              onTap: () {
                pickDate(
                  current: masterMason,
                  onSelected: (d) {
                    setState(() {
                      masterMason = d;
                    });
                  },
                );
              },
            ),
            fieldLabel("Reason for Correction"),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: "Explain the reason for this correction",
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
