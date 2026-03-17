import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BrethrenScreen extends StatefulWidget {
  const BrethrenScreen({super.key});

  @override
  State<BrethrenScreen> createState() => _BrethrenScreenState();
}

class _BrethrenScreenState extends State<BrethrenScreen> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<Map<String, dynamic>> _brethren = [];
  List<Map<String, dynamic>> _filteredBrethren = [];
  Map<String, dynamic> _memberRoles = {}; // brethren_id → role

  String? _error;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBrethren();
    _searchController.addListener(_filterBrethren);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// ----------------------------------------------------------
  /// LOAD DATA
  /// ----------------------------------------------------------

  Future<void> _loadBrethren() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        setState(() {
          _error = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      /// 1. Get user's lodge_id
      final memberRes = await supabase
          .from('members')
          .select('lodge_id')
          .eq('user_id', user.id)
          .single();

      final lodgeId = memberRes['lodge_id'];

      /// 2. Get affiliations
      final affRes = await supabase
          .from('brethren_affiliations')
          .select('brethren_id')
          .eq('lodge_id', lodgeId)
          .eq('status', 'ACTIVE');

      final brethrenIds = List<String>.from(
        affRes.map((e) => e['brethren_id']),
      );

      if (brethrenIds.isEmpty) {
        setState(() {
          _brethren = [];
          _filteredBrethren = [];
          _isLoading = false;
        });
        return;
      }

      /// 3. Get brethren details
      final brethrenRes = await supabase
          .from('list_brethren')
          .select()
          .inFilter('id', brethrenIds)
          .order('family_name', ascending: true);

      /// 4. Get members (for role + account indicator)
      final membersRes = await supabase
          .from('members')
          .select('brethren_id, role')
          .eq('lodge_id', lodgeId);

      final Map<String, dynamic> roleMap = {
        for (var m in membersRes) m['brethren_id'] as String: m['role']
      };

      setState(() {
        _brethren = List<Map<String, dynamic>>.from(brethrenRes);
        _filteredBrethren = _brethren;
        _memberRoles = roleMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// ----------------------------------------------------------
  /// SEARCH FILTER
  /// ----------------------------------------------------------

  void _filterBrethren() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredBrethren = _brethren.where((b) {
        final name = _fullName(b).toLowerCase();
        return name.contains(query);
      }).toList();
    });
  }

  /// ----------------------------------------------------------
  /// HELPERS
  /// ----------------------------------------------------------

  String _fullName(Map<String, dynamic> b) {
    final first = b['first_name'] ?? '';
    final middle = b['middle_name'] ?? '';
    final last = b['family_name'] ?? '';
    final suffix = b['suffix'] ?? '';

    return [
      first,
      if (middle.isNotEmpty) middle,
      last,
      if (suffix.isNotEmpty) suffix,
    ].join(' ');
  }

  Widget _avatar(String? url) {
    if (url == null || url.isEmpty) {
      return const CircleAvatar(child: Icon(Icons.person));
    }

    return CircleAvatar(
      backgroundImage: NetworkImage(url),
    );
  }

  Widget _roleBadge(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        role,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  /// ----------------------------------------------------------
  /// BUILD
  /// ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }

    return Column(
      children: [
        /// 🔍 SEARCH BAR
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Search brethren...",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        /// LIST
        Expanded(
          child: _filteredBrethren.isEmpty
              ? const Center(child: Text('No members found'))
              : RefreshIndicator(
                  onRefresh: _loadBrethren,
                  child: ListView.builder(
                    itemCount: _filteredBrethren.length,
                    itemBuilder: (context, index) {
                      final b = _filteredBrethren[index];
                      final role = _memberRoles[b['id']];

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: _avatar(b['profile_photo_url']),
                          title: Text(_fullName(b)),
                          subtitle: role != null
                              ? _roleBadge(role)
                              : const Text("No account"),
                          trailing: role != null
                              ? const Icon(Icons.verified, color: Colors.green)
                              : null,
                          onTap: () {
                            // future: open profile
                          },
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
