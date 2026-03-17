import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'member_profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? member;
  List<Map<String, dynamic>> feedPosts = [];

  bool loading = true;
  bool feedLoading = true;

  final TextEditingController postController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  int _selectedIndex = 0;

  int page = 0;
  final int limit = 10;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  /// ----------------------------------------------------------
  /// NAME FORMATTER
  /// ----------------------------------------------------------

  String toProperCase(String name) {
    if (name.isEmpty) return "";
    return name.split(" ").map((word) {
      if (word.isEmpty) return "";
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(" ");
  }

  /// ----------------------------------------------------------
  /// TIME AGO FORMAT
  /// ----------------------------------------------------------

  String timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);

    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m";
    if (diff.inHours < 24) return "${diff.inHours}h";
    if (diff.inDays < 7) return "${diff.inDays}d";

    return "${date.month}/${date.day}/${date.year}";
  }

  /// ----------------------------------------------------------
  /// LOAD DASHBOARD
  /// ----------------------------------------------------------

  Future<void> _loadDashboard() async {
    try {
      final data = await supabase.rpc('get_dashboard_data');

      setState(() {
        member = Map<String, dynamic>.from(data['member'] ?? {});
        feedPosts = List<Map<String, dynamic>>.from(data['feed'] ?? []);
        loading = false;
        feedLoading = false;
      });
    } catch (e) {
      debugPrint("Dashboard load error: $e");

      if (!mounted) return;

      setState(() {
        loading = false;
        feedLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  /// ----------------------------------------------------------
  /// LOGOUT
  /// ----------------------------------------------------------

  Future<void> _logout() async {
    await supabase.auth.signOut();
  }

  /// ----------------------------------------------------------
  /// POST COMPOSER
  /// ----------------------------------------------------------

  void _openComposer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Create Post",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: postController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: "What's happening in the lodge?",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.photo),
                      label: const Text("Add Photo"),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () {},
                      child: const Text("Post"),
                    )
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  /// ----------------------------------------------------------
  /// TODAY PANEL
  /// ----------------------------------------------------------

  Widget _todayPanel() {
    return Card(
      child: Column(
        children: const [
          ListTile(
            leading: Icon(Icons.cake),
            title: Text("Today's Birthdays"),
            subtitle: Text("No birthdays today"),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.event),
            title: Text("Upcoming Event"),
            subtitle: Text("Stated Meeting • July 15"),
          ),
        ],
      ),
    );
  }

  /// ----------------------------------------------------------
  /// FEED CARD
  /// ----------------------------------------------------------

  Widget _feedCard(Map post) {
    final firstName = toProperCase(post['first_name'] ?? '');
    final lastName = post['family_name'] ?? '';
    final role = post['role'] ?? 'Member';

    final photos = post['photos'] ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// HEADER
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: post['profile_photo_url'] != null
                      ? NetworkImage(post['profile_photo_url'])
                      : null,
                  child: post['profile_photo_url'] == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Bro. $firstName $lastName",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        role == "Member" ? "Master Mason" : role,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      if (post['created_at'] != null)
                        Text(
                          timeAgo(DateTime.parse(post['created_at'])),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                )
              ],
            ),

            const SizedBox(height: 10),

            /// CONTENT
            if (post['content'] != null) Text(post['content']),

            const SizedBox(height: 10),

            /// PHOTOS
            if (photos.isNotEmpty)
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length,
                  itemBuilder: (_, index) {
                    return Container(
                      margin: const EdgeInsets.only(right: 10),
                      child: Image.network(
                        photos[index],
                        width: 200,
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
              ),

            const Divider(),

            /// REACTIONS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.thumb_up_alt_outlined),
                  label: const Text("Like"),
                ),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.comment_outlined),
                  label: const Text("Comment"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  /// ----------------------------------------------------------
  /// HOME CONTENT
  /// ----------------------------------------------------------

  Widget _homeContent() {
    final firstName = member?['first_name'] ?? '';
    final lodgeName =
        "${member?['lodge_name'] ?? ''} No. ${member?['lodge_number'] ?? ''}";

    final role = member?['role'] ?? 'Member';
    final position = role == "Member" ? "Master Mason" : role;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        /// MEMBER HEADER
        Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: member?['profile_photo_url'] != null
                  ? NetworkImage(member!['profile_photo_url'])
                  : null,
              child: member?['profile_photo_url'] == null
                  ? const Icon(Icons.person)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Bro. ${toProperCase(firstName)}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(lodgeName),
                  Text(position),
                ],
              ),
            )
          ],
        ),

        const SizedBox(height: 20),

        /// TODAY PANEL
        _todayPanel(),

        const SizedBox(height: 20),

        const Text(
          "Lodge Feed",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),

        const SizedBox(height: 10),

        if (feedLoading)
          const Center(child: CircularProgressIndicator())
        else
          ...feedPosts.map((post) => _feedCard(post)),
      ],
    );
  }

  /// ----------------------------------------------------------
  /// BODY SWITCH
  /// ----------------------------------------------------------

  Widget _getBody() {
    switch (_selectedIndex) {
      case 0:
        return loading
            ? const Center(child: CircularProgressIndicator())
            : _homeContent();

      case 4:
        return const MemberProfileScreen();

      default:
        return const Center(
          child: Text("Coming Soon"),
        );
    }
  }

  /// ----------------------------------------------------------
  /// BUILD
  /// ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2D62),
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 8),
            Image.asset(
              "assets/images/logo.png",
              height: 32,
              color: Colors.white,
              colorBlendMode: BlendMode.srcIn,
            ),
            const SizedBox(width: 10),
            const Text(
              "Trestle Board",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cake),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),

      body: _getBody(),

      /// FLOATING POST BUTTON
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF0D2D62),
              onPressed: _openComposer,
              child: const Icon(Icons.add),
            )
          : null,

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: "Brethren",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: "Events",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: "Trestle",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}
