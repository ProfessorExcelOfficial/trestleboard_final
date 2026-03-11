import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'lodge_registration_screen.dart';

class AdminLodgeRequestsScreen extends StatefulWidget {
  const AdminLodgeRequestsScreen({super.key});

  @override
  State<AdminLodgeRequestsScreen> createState() =>
      _AdminLodgeRequestsScreenState();
}

class _AdminLodgeRequestsScreenState extends State<AdminLodgeRequestsScreen> {
  final supabase = Supabase.instance.client;

  List<dynamic> requests = [];
  bool loading = true;
  String selectedStatus = "PENDING";

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  // ----------------------------------------------------------
  // LOAD LODGE REQUESTS
  // ----------------------------------------------------------
  Future<void> _loadRequests() async {
    setState(() => loading = true);

    try {
      var query = supabase.from('req_lodges').select();

      if (selectedStatus != "ALL") {
        query = query.eq('status', selectedStatus);
      }

      final result = await query.order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        requests = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      _showSnack("Error loading requests: $e");
    }
  }

  // ----------------------------------------------------------
  // APPROVE LODGE (Option B)
  // ----------------------------------------------------------
  Future<void> _approve(dynamic r) async {
    try {
      final lodgeNumber = r['lodge_number'];

      // 1️⃣ Check if lodge already exists in production table
      final existing = await supabase
          .from('lodges')
          .select('id')
          .eq('lodge_number', lodgeNumber)
          .maybeSingle();

      if (existing != null) {
        _showSnack("Lodge already exists in active lodges.");
        return;
      }

      // 2️⃣ Insert into lodges table
      await supabase.from('lodges').insert({
        'lodge_number': lodgeNumber,
        'lodge_name': r['lodge_name'],
        'city': r['city'],
        'province': r['province'],
        'email': r['email'],
        'status': 'ACTIVE',
      });

      // 3️⃣ Mark request as approved
      await supabase.from('req_lodges').update({
        'status': 'APPROVED',
        'approved_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', r['id']);

      await _loadRequests();

      if (!mounted) return;
      _showSnack("Lodge approved and activated.");
    } catch (e) {
      if (!mounted) return;
      _showSnack("Error approving lodge: $e");
    }
  }

  // ----------------------------------------------------------
  // REJECT LODGE
  // ----------------------------------------------------------
  Future<void> _reject(dynamic r) async {
    try {
      await supabase.from('req_lodges').update({
        'status': 'REJECTED',
      }).eq('id', r['id']);

      await _loadRequests();

      if (!mounted) return;
      _showSnack("Lodge rejected.");
    } catch (e) {
      if (!mounted) return;
      _showSnack("Error rejecting: $e");
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ----------------------------------------------------------
  // STATUS COLOR
  // ----------------------------------------------------------
  Color _statusColor(String status) {
    switch (status) {
      case "PENDING":
        return Colors.orange;
      case "APPROVED":
        return Colors.green;
      case "REJECTED":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // ----------------------------------------------------------
  // UI
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lodge Registration"),
      ),
      body: Column(
        children: [
          // FILTER
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<String>(
              initialValue: selectedStatus,
              items: const [
                DropdownMenuItem(value: "ALL", child: Text("All")),
                DropdownMenuItem(value: "PENDING", child: Text("Pending")),
                DropdownMenuItem(value: "APPROVED", child: Text("Approved")),
                DropdownMenuItem(value: "REJECTED", child: Text("Rejected")),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => selectedStatus = value);
                _loadRequests();
              },
              decoration: const InputDecoration(
                labelText: "Filter by Status",
                border: OutlineInputBorder(),
              ),
            ),
          ),

          // LIST
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : requests.isEmpty
                    ? const Center(
                        child: Text(
                          "No lodge requests found.",
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: requests.length,
                        itemBuilder: (_, i) {
                          final r = requests[i];

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: ListTile(
                              title: Text(
                                "${r['lodge_name']} (No. ${r['lodge_number']})",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text("${r['city']}, ${r['province']}"),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _statusColor(r['status'])
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  r['status'],
                                  style: TextStyle(
                                    color: _statusColor(r['status']),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              onTap: () => _showActions(r),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const LodgeRegistrationScreen(),
            ),
          );
          _loadRequests();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  // ----------------------------------------------------------
  // ACTION SHEET
  // ----------------------------------------------------------
  void _showActions(dynamic r) {
    if (r['status'] != "PENDING") return;

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.check, color: Colors.green),
              title: const Text("Approve"),
              onTap: () {
                Navigator.pop(context);
                _approve(r);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close, color: Colors.red),
              title: const Text("Reject"),
              onTap: () {
                Navigator.pop(context);
                _reject(r);
              },
            ),
          ],
        ),
      ),
    );
  }
}
