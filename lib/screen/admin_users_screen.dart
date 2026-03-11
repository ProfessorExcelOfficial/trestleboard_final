import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final supabase = Supabase.instance.client;

  List<dynamic> users = [];
  bool loading = true;
  bool actionLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  // ==========================================================
  // LOAD ALL WORSHIPFUL MASTERS (MULTI-LODGE)
  // ==========================================================
  Future<void> _loadUsers() async {
    try {
      final result = await supabase
          .from('user_profiles')
          .select('''
          id,
          first_name,
          middle_name,
          family_name,
          email,
          role,
          invite_status,
          profile_completed,
          status,
          invite_resend_count,
          lodge_id
        ''')
          .eq('role', 'Worshipful Master') // <- must match exact DB value
          .order('created_at', ascending: false);

      debugPrint("Fetched WMs: ${result.length}");

      setState(() {
        users = result;
        loading = false;
      });
    } catch (e) {
      debugPrint("Error loading WMs: $e");
      setState(() => loading = false);
    }
  }

  // ==========================================================
  // RESEND INVITE
  // ==========================================================
  Future<void> _resendInvite(String userId) async {
    final confirm = await _confirmDialog(
      "Resend Invitation",
      "Send a new invitation email to this Worshipful Master?",
    );

    if (!confirm) return;

    setState(() => actionLoading = true);

    try {
      final response = await supabase.functions.invoke(
        'admin-resend-wm-invite',
        body: {'wm_user_id': userId},
      );

      if (response.status != 200) {
        throw Exception(response.data?['error'] ?? "Resend failed");
      }

      await _loadUsers();
      _showSuccess("Invitation resent successfully.");
    } catch (e) {
      _showError("Error: $e");
    }

    setState(() => actionLoading = false);
  }

  // ==========================================================
  // UI HELPERS
  // ==========================================================
  Future<bool> _confirmDialog(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                child: const Text("Cancel"),
                onPressed: () => Navigator.pop(context, false),
              ),
              ElevatedButton(
                child: const Text("Confirm"),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // ==========================================================
  // STATUS CHIP BUILDER (HIGH CONTRAST)
  // ==========================================================
  Widget _buildStatusChip(String label, Color color) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: color,
    );
  }

  Color _inviteColor(String inviteStatus) {
    switch (inviteStatus) {
      case 'INVITED':
        return Colors.orange;
      case 'ACCEPTED':
        return Colors.blue;
      case 'EXPIRED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _membershipColor(String status) {
    switch (status) {
      case 'ACTIVE':
        return Colors.green;
      case 'SUSPENDED':
        return Colors.red;
      case 'PENDING':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _lodgeColor(String lodgeStatus) {
    switch (lodgeStatus) {
      case 'ACTIVE':
        return Colors.green;
      case 'SUSPENDED':
        return Colors.red;
      case 'PENDING':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // ==========================================================
  // SUMMARY BAR
  // ==========================================================
  Widget _metricCard(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label),
      ],
    );
  }

  Widget _buildSummaryBar() {
    final total = users.length;

    final pending = users
        .where((u) =>
            u['invite_status'] == 'INVITED' && u['profile_completed'] == false)
        .length;

    final active = users
        .where((u) => u['profile_completed'] == true && u['status'] == 'ACTIVE')
        .length;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _metricCard("Total Lodges", total),
          _metricCard("Pending WM", pending),
          _metricCard("Active WM", active),
        ],
      ),
    );
  }

  // ==========================================================
  // WM CARD
  // ==========================================================
  Widget _buildUserCard(dynamic u) {
    final fullName =
        "${u['first_name'] ?? ''} ${u['middle_name'] ?? ''} ${u['family_name'] ?? ''}"
            .trim();

    final lodgeName = u['lodges']?['name'] ?? "Unknown Lodge";
    final lodgeStatus = u['lodges']?['status'] ?? "PENDING";

    final inviteStatus = u['invite_status'] ?? 'N/A';
    final membershipStatus = u['status'] ?? 'N/A';
    final profileCompleted = u['profile_completed'] ?? false;
    final resendCount = u['invite_resend_count'] ?? 0;

    final needsResend = inviteStatus == 'INVITED' && profileCompleted == false;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lodgeName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text("WM: ${fullName.isEmpty ? 'No Name Yet' : fullName}"),
            Text("Email: ${u['email']}"),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                _buildStatusChip(inviteStatus, _inviteColor(inviteStatus)),
                _buildStatusChip(
                    membershipStatus, _membershipColor(membershipStatus)),
                _buildStatusChip(lodgeStatus, _lodgeColor(lodgeStatus)),
              ],
            ),
            const SizedBox(height: 6),
            Text("Resend Count: $resendCount"),
            if (needsResend)
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => _resendInvite(u['id']),
                  icon: const Icon(Icons.refresh),
                  label: const Text("Resend Invitation"),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Worshipful Master Management")),
      body: Stack(
        children: [
          Column(
            children: [
              _buildSummaryBar(),
              Expanded(
                child: users.isEmpty
                    ? const Center(
                        child: Text("No Worshipful Masters found."),
                      )
                    : ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (_, i) => _buildUserCard(users[i]),
                      ),
              ),
            ],
          ),
          if (actionLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
