import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemberEditWorkScreen extends StatefulWidget {
  final String brethrenId;
  final String? occupation;
  final String? company;
  final String? workAddress;
  final String? workPhone;

  const MemberEditWorkScreen({
    super.key,
    required this.brethrenId,
    this.occupation,
    this.company,
    this.workAddress,
    this.workPhone,
  });

  @override
  State<MemberEditWorkScreen> createState() => _MemberEditWorkScreenState();
}

class _MemberEditWorkScreenState extends State<MemberEditWorkScreen> {
  final supabase = Supabase.instance.client;

  final companyController = TextEditingController();
  final addressController = TextEditingController();
  final phoneController = TextEditingController();

  List<Map<String, dynamic>> occupations = [];
  int? selectedOccupationId;

  bool loadingOccupations = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();

    companyController.text = widget.company ?? "";
    addressController.text = widget.workAddress ?? "";
    phoneController.text = widget.workPhone ?? "";

    loadOccupations();
  }

  Future<void> loadOccupations() async {
    try {
      final data = await supabase
          .from('occupation_list')
          .select('id, occupation')
          .order('occupation', ascending: true);

      occupations = List<Map<String, dynamic>>.from(data);

      if (widget.occupation != null) {
        final match = occupations.firstWhere(
          (o) => o['occupation'] == widget.occupation,
          orElse: () => {},
        );

        if (match.isNotEmpty) {
          selectedOccupationId = match['id'];
        }
      }
    } catch (e) {
      debugPrint("Load occupations error: $e");
    }

    setState(() {
      loadingOccupations = false;
    });
  }

  Future<void> saveWork() async {
    setState(() => saving = true);

    try {
      final user = supabase.auth.currentUser;

      final existing = await supabase
          .from('brethren_work')
          .select('id')
          .eq('brethren_id', widget.brethrenId)
          .maybeSingle();

      final data = {
        "occupation_id": selectedOccupationId,
        "company_name": companyController.text.trim(),
        "work_address": addressController.text.trim(),
        "work_phone": phoneController.text.trim(),
        "brethren_id": widget.brethrenId,
        "updated_by": user?.id
      };

      if (existing == null) {
        await supabase.from('brethren_work').insert(data);
      } else {
        await supabase
            .from('brethren_work')
            .update(data)
            .eq('brethren_id', widget.brethrenId);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Save work error: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to save work information")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Widget textField(String label, TextEditingController controller) {
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

  Widget occupationDropdown() {
    if (loadingOccupations) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 14),
        child: LinearProgressIndicator(),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<int>(
        value: selectedOccupationId,
        decoration: const InputDecoration(
          labelText: "Occupation",
          border: OutlineInputBorder(),
        ),
        items: occupations
            .map(
              (o) => DropdownMenuItem<int>(
                value: o['id'],
                child: Text(o['occupation']),
              ),
            )
            .toList(),
        onChanged: (value) {
          setState(() {
            selectedOccupationId = value;
          });
        },
      ),
    );
  }

  @override
  void dispose() {
    companyController.dispose();
    addressController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Update Work")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            occupationDropdown(),
            textField("Company", companyController),
            textField("Work Address", addressController),
            textField("Work Phone", phoneController),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: saving ? null : saveWork,
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
