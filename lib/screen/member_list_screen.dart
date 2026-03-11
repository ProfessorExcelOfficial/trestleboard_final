import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemberListScreen extends StatefulWidget {
  const MemberListScreen({super.key});

  @override
  State<MemberListScreen> createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen> {
  final supabase = Supabase.instance.client;

  List members = [];
  List filteredMembers = [];

  bool loading = true;

  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  // ---------------------------------------------------------
  // LOAD MEMBERS
  // ---------------------------------------------------------

  Future<void> _loadMembers() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) return;

      // find lodge of logged in user
      final myMember = await supabase
          .from('members')
          .select('lodge_id')
          .eq('user_id', user.id)
          .single();

      final lodgeId = myMember['lodge_id'];

      // fetch all lodge members
      final data = await supabase.from('members').select('''
            id,
            role,
            list_brethren(
              first_name,
              middle_name,
              family_name,
              suffix,
              profile_photo_url
            )
          ''').eq('lodge_id', lodgeId).order('role');

      setState(() {
        members = data;
        filteredMembers = data;
        loading = false;
      });
    } catch (e) {
      debugPrint("Member load error: $e");
    }
  }

  // ---------------------------------------------------------
  // SEARCH FILTER
  // ---------------------------------------------------------

  void _filterMembers(String query) {
    query = query.toLowerCase();

    final results = members.where((m) {
      final b = m['list_brethren'];

      final name =
          "${b?['first_name'] ?? ''} ${b?['family_name'] ?? ''}".toLowerCase();

      return name.contains(query);
    }).toList();

    setState(() {
      filteredMembers = results;
    });
  }

  // ---------------------------------------------------------
  // BUILD NAME
  // ---------------------------------------------------------

  String _buildName(dynamic b) {
    return [b['first_name'], b['middle_name'], b['family_name'], b['suffix']]
        .where((e) => e != null && e.toString().isNotEmpty)
        .join(" ");
  }

  // ---------------------------------------------------------
  // ROLE DISPLAY
  // ---------------------------------------------------------

  String _displayRole(String role) {
    if (role == "Member") return "Master Mason";
    return role;
  }

  // ---------------------------------------------------------
  // MEMBER TILE
  // ---------------------------------------------------------

  Widget _memberTile(dynamic m) {
    final b = m['list_brethren'];

    final name = _buildName(b);
    final role = _displayRole(m['role']);

    final photo = b?['profile_photo_url'];

    return ListTile(
      leading: CircleAvatar(
        radius: 22,
        backgroundImage: photo != null ? NetworkImage(photo) : null,
        child: photo == null ? const Icon(Icons.person) : null,
      ),
      title: Text(
        "Bro. $name",
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(role),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        // future: open member profile
      },
    );
  }

  // ---------------------------------------------------------
  // UI
  // ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Members"),
      ),
      body: Column(
        children: [
          // -------------------------
          // SEARCH
          // -------------------------

          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: "Search member...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filterMembers,
            ),
          ),

          // -------------------------
          // MEMBER LIST
          // -------------------------

          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: filteredMembers.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => _memberTile(filteredMembers[i]),
                  ),
          ),
        ],
      ),
    );
  }
}
