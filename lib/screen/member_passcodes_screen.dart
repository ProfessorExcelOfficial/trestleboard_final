import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemberPasscodesScreen extends StatefulWidget {
  const MemberPasscodesScreen({super.key});

  @override
  State<MemberPasscodesScreen> createState() => _MemberPasscodesScreenState();
}

class _MemberPasscodesScreenState extends State<MemberPasscodesScreen> {
  final supabase = Supabase.instance.client;

  List members = [];
  List filteredMembers = [];

  Map<String, dynamic> codeMap = {};

  bool loading = true;

  final searchController = TextEditingController();

  String? lastGeneratedCode;
  String? lastGeneratedMember;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  // ----------------------------------------------------------
  // LOAD DATA
  // ----------------------------------------------------------

  Future<void> loadData() async {
    setState(() => loading = true);

    try {
      final memberData = await supabase.from('members').select('''
            id,
            email,
            brethren:list_brethren (
              first_name,
              middle_name,
              family_name,
              suffix
            )
          ''').filter('user_id', 'is', null);

      final codes = await supabase.from('enrollment_codes').select('*');

      Map<String, dynamic> map = {};

      for (var c in codes) {
        map[c['member_id']] = c;
      }

      setState(() {
        members = memberData;
        filteredMembers = memberData;
        codeMap = map;
        loading = false;
      });
    } catch (e) {
      debugPrint(e.toString());
      setState(() => loading = false);
    }
  }

  // ----------------------------------------------------------
  // SEARCH FILTER
  // ----------------------------------------------------------

  void filterMembers(String query) {
    query = query.toLowerCase();

    final results = members.where((m) {
      final name = buildName(m).toLowerCase();
      final email = (m['email'] ?? "").toLowerCase();

      return name.contains(query) || email.contains(query);
    }).toList();

    setState(() {
      filteredMembers = results;
    });
  }

  // ----------------------------------------------------------
  // BUILD NAME
  // ----------------------------------------------------------

  String buildName(dynamic m) {
    final b = m['brethren'];

    if (b == null) return "Unknown";

    return [b['first_name'], b['middle_name'], b['family_name'], b['suffix']]
        .where((e) => e != null && e.toString().isNotEmpty)
        .join(" ");
  }

  // ----------------------------------------------------------
  // STATUS
  // ----------------------------------------------------------

  String codeStatus(dynamic code) {
    if (code == null) return "NONE";

    if (code['revoked'] == true) return "REVOKED";

    if (code['used_at'] != null) return "USED";

    final expiry = DateTime.parse(code['expires_at']);

    if (expiry.isBefore(DateTime.now())) return "EXPIRED";

    return "ACTIVE";
  }

  Color statusColor(String status) {
    switch (status) {
      case "ACTIVE":
        return Colors.green;

      case "USED":
        return Colors.blue;

      case "EXPIRED":
        return Colors.orange;

      case "REVOKED":
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  // ----------------------------------------------------------
  // GENERATE CODE
  // ----------------------------------------------------------

  Future<void> generateCode(dynamic m) async {
    try {
      final code = await supabase.rpc(
        'generate_member_passcode',
        params: {'p_member_id': m['id']},
      );

      lastGeneratedCode = code;
      lastGeneratedMember = m['id'];

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Enrollment Code"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Share this code with the member."),
              const SizedBox(height: 16),
              SelectableText(
                code,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));

                if (!mounted) return;

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Passcode copied to clipboard"),
                  ),
                );
              },
              child: const Text("Copy"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        ),
      );

      loadData();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // ----------------------------------------------------------
  // RESEND
  // ----------------------------------------------------------

  Future<void> resendCode(dynamic m) async {
    if (lastGeneratedMember != m['id'] || lastGeneratedCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Code cannot be retrieved. Generate a new one."),
        ),
      );
      return;
    }

    await Clipboard.setData(
      ClipboardData(text: lastGeneratedCode!),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Passcode copied")),
    );
  }

  // ----------------------------------------------------------
  // REVOKE
  // ----------------------------------------------------------

  Future<void> revokeCode(dynamic m) async {
    final confirm = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Revoke Passcode"),
        content: const Text(
            "Are you sure you want to revoke this member's enrollment code?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Revoke"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.rpc(
        'revoke_enrollment_code',
        params: {'p_member_id': m['id']},
      );

      loadData();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // ----------------------------------------------------------
  // MEMBER TILE
  // ----------------------------------------------------------

  Widget memberTile(dynamic m) {
    final name = buildName(m);

    final code = codeMap[m['id']];
    final status = codeStatus(code);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text(name),
        subtitle: Text(m['email'] ?? ''),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor(status).withOpacity(.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor(status),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            if (status == "ACTIVE") ...[
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () => resendCode(m),
              ),
              IconButton(
                icon: const Icon(Icons.block, color: Colors.red),
                onPressed: () => revokeCode(m),
              ),
            ],
            if (status != "ACTIVE")
              ElevatedButton(
                onPressed: () => generateCode(m),
                child: const Text("Generate"),
              ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // UI
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Member Passcodes"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadData,
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: "Search member...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: filterMembers,
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: filteredMembers.length,
                    itemBuilder: (_, i) => memberTile(filteredMembers[i]),
                  ),
          ),
        ],
      ),
    );
  }
}
