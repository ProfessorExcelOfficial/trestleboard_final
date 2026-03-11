import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';
import 'admin_lodge_requests_screen.dart';
import 'admin_member_list_screen.dart';
import 'member_passcodes_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;

  int pendingLodges = 0;
  int pendingMembers = 0;
  int passcodes = 0;

  RealtimeChannel? subscription;

  @override
  void initState() {
    super.initState();
    loadDashboardData();
    subscribeRealtime();
  }

  @override
  void dispose() {
    subscription?.unsubscribe();
    super.dispose();
  }

  // ----------------------------------------------------------
  // LOAD DASHBOARD DATA
  // ----------------------------------------------------------

  Future<void> loadDashboardData() async {
    setState(() => isLoading = true);

    try {
      final lodges = await supabase
          .from('req_lodges')
          .select('id')
          .eq('status', 'PENDING');

      final members = await supabase
          .from('req_members')
          .select('id')
          .eq('status', 'PENDING');

      final pass = await supabase.from('member_passcodes').select('id');

      if (!mounted) return;

      setState(() {
        pendingLodges = lodges.length;
        pendingMembers = members.length;
        passcodes = pass.length;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Dashboard load error: $e");
      setState(() => isLoading = false);
    }
  }

  // ----------------------------------------------------------
  // REALTIME
  // ----------------------------------------------------------

  void subscribeRealtime() {
    subscription = supabase
        .channel('admin-dashboard')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'req_lodges',
          callback: (_) => loadDashboardData(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'req_members',
          callback: (_) => loadDashboardData(),
        )
        .subscribe();
  }

  // ----------------------------------------------------------
  // UI
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Console"),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await supabase.auth.signOut();

              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadDashboardData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // =====================================
            // SESSION PANEL
            // =====================================

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "ACTIVE SESSION",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text("User ID: ${user?.id ?? '-'}"),
                  Text("Email: ${user?.email ?? '-'}"),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // =====================================
            // ADMIN OVERVIEW
            // =====================================

            const Text(
              "Overview",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                _statCard(
                  "Pending Lodges",
                  pendingLodges.toString(),
                  Icons.account_balance,
                  Colors.orange,
                ),
                const SizedBox(width: 12),
                _statCard(
                  "Pending Members",
                  pendingMembers.toString(),
                  Icons.group_add,
                  Colors.blue,
                ),
                const SizedBox(width: 12),
                _statCard(
                  "Passcodes",
                  passcodes.toString(),
                  Icons.vpn_key,
                  Colors.green,
                ),
              ],
            ),

            const SizedBox(height: 30),

            const Text(
              "Administration",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            // =====================================
            // ADMIN GRID
            // =====================================

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1,
              children: [
                _adminTile(
                  context,
                  title: "Lodge Registration",
                  icon: Icons.account_balance,
                  count: pendingLodges,
                  screen: const AdminLodgeRequestsScreen(),
                ),
                _adminTile(
                  context,
                  title: "Member Registration",
                  icon: Icons.group_add,
                  count: pendingMembers,
                  screen: const AdminMemberListScreen(),
                ),
                _adminTile(
                  context,
                  title: "Member Passcodes",
                  icon: Icons.vpn_key,
                  count: passcodes,
                  screen: const MemberPasscodesScreen(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // ADMIN TILE
  // ----------------------------------------------------------

  Widget _adminTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required int count,
    required Widget screen,
  }) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => screen),
          );
        },
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.blueGrey.shade50,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 44,
                    color: Colors.blueGrey.shade700,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (count > 0)
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // STAT CARD
  // ----------------------------------------------------------

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: color.withOpacity(.1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
