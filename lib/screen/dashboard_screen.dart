import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

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
  List<File> selectedPhotos = [];

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  // ----------------------------------------------------------
  // PROPER NAME FORMATTER
  // ----------------------------------------------------------

  String toProperCase(String name) {
    if (name.isEmpty) return "";

    return name.split(" ").map((word) {
      if (word.isEmpty) return "";
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(" ");
  }

  // ----------------------------------------------------------
  // LOAD DASHBOARD
  // ----------------------------------------------------------

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

  // ----------------------------------------------------------
  // LOGOUT
  // ----------------------------------------------------------

  Future<void> _logout() async {
    await supabase.auth.signOut();
  }

  // ----------------------------------------------------------
  // POST COMPOSER
  // ----------------------------------------------------------

  void _openComposer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Create Post",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.photo),
                          label: const Text("Add Photos"),
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
              );
            },
          ),
        );
      },
    );
  }

  // ----------------------------------------------------------
  // UI
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final firstName = member?['first_name'] ?? '';
    final lodgeName =
        "${member?['lodge_name'] ?? ''} No. ${member?['lodge_number'] ?? ''}";
    final role = member?['role'] ?? 'Member';

    final position = role == "Member" ? "Master Mason" : role;

    return Scaffold(
      // ------------------------------------------------------
      // APP BAR
      // ------------------------------------------------------

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
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
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

      // ------------------------------------------------------
      // BODY
      // ------------------------------------------------------

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
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
                                fontSize: 18, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            lodgeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(position),
                        ],
                      ),
                    )
                  ],
                ),

                const SizedBox(height: 20),

                /// NEXT MEETING

                Card(
                  child: ListTile(
                    leading: const Icon(Icons.event),
                    title: const Text("Next Stated Meeting"),
                    subtitle: const Text("July 15 • 7:00 PM"),
                  ),
                ),

                const SizedBox(height: 20),

                /// CREATE POST

                Card(
                  child: ListTile(
                    leading: const CircleAvatar(),
                    title: const Text("What's happening in the lodge?"),
                    onTap: _openComposer,
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  "Lodge Feed",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),

                const SizedBox(height: 10),

                if (feedLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  ...feedPosts.map((post) {
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
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundImage: post['profile_photo_url'] !=
                                          null
                                      ? NetworkImage(post['profile_photo_url'])
                                      : null,
                                  child: post['profile_photo_url'] == null
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Bro. $firstName $lastName",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        role == "Member"
                                            ? "Master Mason"
                                            : role,
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (post['content'] != null) Text(post['content']),
                            const SizedBox(height: 10),
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
                          ],
                        ),
                      ),
                    );
                  })
              ],
            ),

      // ------------------------------------------------------
      // BOTTOM MENU
      // ------------------------------------------------------

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
