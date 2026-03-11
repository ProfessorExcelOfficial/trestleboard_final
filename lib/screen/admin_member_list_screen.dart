import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_member_req_screen.dart';

class AdminMemberListScreen extends StatefulWidget {
  const AdminMemberListScreen({super.key});

  @override
  State<AdminMemberListScreen> createState() => _AdminMemberListScreenState();
}

class _AdminMemberListScreenState extends State<AdminMemberListScreen> {
  final supabase = Supabase.instance.client;

  List<dynamic> members = [];
  bool loading = true;
  String selectedStatus = "PENDING";

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  // ----------------------------------------------------------
  // LOAD MEMBER REQUESTS
  // ----------------------------------------------------------

  Future<void> _loadMembers() async {
    setState(() => loading = true);

    try {
      var query = supabase.from('req_members').select('''
        id,
        lodge_id,
        first_name,
        middle_name,
        family_name,
        suffix,
        birthday,
        email,
        status,
        created_at
      ''');

      if (selectedStatus != "ALL") {
        query = query.eq('status', selectedStatus);
      }

      final result = await query.order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        members = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      _showSnack("Error loading members: $e");
    }
  }

  // ----------------------------------------------------------
  // APPROVE MEMBER
  // ----------------------------------------------------------

  Future<void> _approve(dynamic m) async {
    try {
      print("REQ ID VALUE: ${m['id']}");
      print("REQ ID TYPE: ${m['id'].runtimeType}");

      await supabase.rpc(
        'approve_member_request',
        params: {'req_id': m['id']},
      );

      await _loadMembers();

      if (!mounted) return;

      _showSnack("Member approved and enrolled.");
    } catch (e) {
      _showSnack("Error approving member: $e");
    }
  }

  // ----------------------------------------------------------
  // REJECT MEMBER
  // ----------------------------------------------------------

  Future<void> _reject(dynamic m) async {
    try {
      if (m['status'] != 'PENDING') {
        _showSnack("Request already processed.");
        return;
      }

      final updated = await supabase
          .from('req_members')
          .update({'status': 'REJECTED'})
          .eq('id', m['id'])
          .select();

      if (updated.isEmpty) {
        throw Exception("Request update failed.");
      }

      await _loadMembers();

      if (!mounted) return;

      _showSnack("Member request rejected.");
    } catch (e) {
      _showSnack("Error rejecting member: $e");
    }
  }

  // ----------------------------------------------------------
  // ACTION SHEET
  // ----------------------------------------------------------

  void _showActions(dynamic m) {
    if (m['status'] != "PENDING") return;

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
                _approve(m);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close, color: Colors.red),
              title: const Text("Reject"),
              onTap: () {
                Navigator.pop(context);
                _reject(m);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case "PENDING":
        return Colors.orange;
      case "ENROLLED":
        return Colors.green;
      case "REJECTED":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // ----------------------------------------------------------
  // BUILD FULL NAME
  // ----------------------------------------------------------

  String buildFullName(dynamic m) {
    return [m['first_name'], m['middle_name'], m['family_name'], m['suffix']]
        .where((e) => e != null && e.toString().trim().isNotEmpty)
        .join(' ');
  }

  // ----------------------------------------------------------
  // FORMAT DATE
  // ----------------------------------------------------------

  String formatDate(String? date) {
    if (date == null) return "-";
    final d = DateTime.parse(date);
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  }

  // ----------------------------------------------------------
  // UI
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Member Requests"),
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
                DropdownMenuItem(value: "ENROLLED", child: Text("Enrolled")),
                DropdownMenuItem(value: "REJECTED", child: Text("Rejected")),
              ],
              onChanged: (value) {
                if (value == null) return;

                setState(() => selectedStatus = value);

                _loadMembers();
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
                : members.isEmpty
                    ? const Center(
                        child: Text(
                          "No member requests found.",
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: members.length,
                        itemBuilder: (_, i) {
                          final m = members[i];
                          final fullName = buildFullName(m);

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: ListTile(
                              onTap: () => _showActions(m),
                              title: Text(
                                fullName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m['email'] ?? ''),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Birthday: ${formatDate(m['birthday'])}",
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    "Requested: ${formatDate(m['created_at'])}",
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _statusColor(m['status'])
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  m['status'],
                                  style: TextStyle(
                                    color: _statusColor(m['status']),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),

      // ADD REQUEST BUTTON
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminMemberReqScreen(),
            ),
          );

          _loadMembers();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
