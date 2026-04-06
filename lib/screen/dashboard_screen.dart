import 'dart:async';
import 'dart:math';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'member_profile_screen.dart';
import 'brethren_screen.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:typed_data';
import 'login_screen.dart';

class FeedController extends ChangeNotifier {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> posts = [];

  Map<String, int> likeCounts = {};
  Map<String, int> commentCounts = {};
  Set<String> likedPostIds = {};
  Set<String> pendingLikes = {};

  bool isLoading = false;
  bool hasMore = true;
  int offset = 0;
  final int limit = 10;

  RealtimeChannel? _channel;

  Future<void> loadInitial() async {
    offset = 0;
    posts.clear();
    hasMore = true;
    await loadMore();
  }

  Future<void> loadMore() async {
    if (isLoading || !hasMore) return;

    isLoading = true;
    notifyListeners();

    try {
      final data = await supabase.rpc('get_dashboard_data', params: {
        'p_limit': limit,
        'p_offset': offset,
      });

      final newPosts = List<Map<String, dynamic>>.from(data['feed'] ?? []);

      for (var p in newPosts) {
        final id = p['id'];
        likeCounts[id] = p['likes_count'] ?? 0;
        commentCounts[id] = p['comments_count'] ?? 0;
        if (p['is_liked'] == true) likedPostIds.add(id);
      }

      for (var p in newPosts) {
        if (!posts.any((e) => e['id'] == p['id'])) {
          posts.add(p);
        }
      }

      offset += newPosts.length;
      if (newPosts.length < limit) hasMore = false;
    } catch (e) {
      print("LOAD ERROR: $e");
    }

    isLoading = false;
    notifyListeners();
  }

  void subscribeRealtime() {
    _channel = supabase.channel('feed-realtime');

    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'posts',
      callback: (payload) async {
        final id = payload.newRecord['id'];
        if (posts.any((p) => p['id'] == id)) return;

        final data = await supabase.rpc('get_dashboard_data', params: {
          'p_limit': 1,
          'p_offset': 0,
        });

        final feed = List<Map<String, dynamic>>.from(data['feed'] ?? []);
        if (feed.isNotEmpty) {
          final post = feed.first;
          posts.insert(0, post);
          likeCounts[post['id']] = post['likes_count'] ?? 0;
          commentCounts[post['id']] = post['comments_count'] ?? 0;
          if (post['is_liked'] == true) likedPostIds.add(post['id']);
          notifyListeners();
        }
      },
    );

    _channel!.subscribe();
  }

  void disposeRealtime() => _channel?.unsubscribe();

  Future<void> toggleLike(String postId) async {
    final isLiked = likedPostIds.contains(postId);
    pendingLikes.add(postId);

    if (isLiked) {
      likedPostIds.remove(postId);
      likeCounts[postId] = max(0, (likeCounts[postId] ?? 1) - 1);
    } else {
      likedPostIds.add(postId);
      likeCounts[postId] = (likeCounts[postId] ?? 0) + 1;
    }

    notifyListeners();

    try {
      await supabase.rpc('toggle_like', params: {'p_post_id': postId});
    } catch (_) {
      await loadInitial();
    } finally {
      pendingLikes.remove(postId);
    }
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final supabase = Supabase.instance.client;
  late FeedController feed;

  Map<String, dynamic>? member;
  bool loading = true;

  final TextEditingController postController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<XFile> selectedImages = [];
  bool isPosting = false;

  final FocusNode _modalFocusNode = FocusNode();

  final Map<String, TextEditingController> _commentControllers = {};
  final Set<String> _expandedComments = {};

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    feed = FeedController();
    _init();

    // 🔥 FORCE REFRESH AFTER START
    Future.delayed(const Duration(seconds: 1), () {
      feed.loadInitial();
    });
  }

  Future<void> _logout() async {
    try {
      await supabase.auth.signOut();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) => const LoginScreen()), // replace if needed
        (route) => false,
      );
    } catch (e) {
      debugPrint("Logout error: $e");
    }
  }

  Future<void> _init() async {
    await _loadMember();
    await feed.loadInitial();
    feed.subscribeRealtime();
    setState(() => loading = false);
  }

  Future<void> _loadMember() async {
    final data = await supabase
        .rpc('get_dashboard_data', params: {'p_limit': 1, 'p_offset': 0});
    member = Map<String, dynamic>.from(data['member'] ?? {});
  }

  String toProperCase(String name) {
    if (name.isEmpty) return "";
    return name
        .split(" ")
        .map((w) => w.isEmpty
            ? ""
            : "${w[0].toUpperCase()}${w.substring(1).toLowerCase()}")
        .join(" ");
  }

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage();

    if (images.isNotEmpty) {
      setState(() {
        selectedImages = [...selectedImages, ...images];

        /// limit to 5 images
        if (selectedImages.length > 5) {
          selectedImages = selectedImages.take(5).toList();
        }
      });
    }
  }

  Future<void> _createPost() async {
    final content = postController.text.trim();

    if (content.isEmpty && selectedImages.isEmpty) return;

    try {
      /// 1. CREATE POST
      final postId = await supabase.rpc(
        'create_post',
        params: {'p_content': content},
      );

      print("POST ID: $postId");

      /// 2. UPLOAD IMAGES (IF ANY)
      for (final img in selectedImages) {
        try {
          await Future.delayed(const Duration(milliseconds: 10)); // Fix 2

          print("---- START IMAGE ----");

          final file = File(img.path);

          print("ORIGINAL SIZE: ${(await file.length()) / (1024 * 1024)} MB");

          // ✅ FIX 1: isolate compression
          final compressedBytes = await _compressImage(file);

          print(
              "COMPRESSED SIZE: ${compressedBytes.length / (1024 * 1024)} MB");

          final bytes = Uint8List.fromList(compressedBytes);

          final sizeMB = bytes.length / (1024 * 1024);
          print("IMAGE SIZE: ${sizeMB.toStringAsFixed(2)} MB");

          if (sizeMB > 5) {
            print("❌ Skipping large image (>5MB)");
            continue;
          }

          final path =
              'posts/$postId/${DateTime.now().millisecondsSinceEpoch}.jpg';

          await supabase.storage
              .from('post-photos')
              .uploadBinary(
                path,
                bytes,
                fileOptions: const FileOptions(contentType: 'image/jpeg'),
              )
              .timeout(const Duration(seconds: 15));

          print("UPLOAD SUCCESS");

          final url = supabase.storage.from('post-photos').getPublicUrl(path);

          // ✅ FIX 5: debug URL
          print("FINAL URL: $url");

          await supabase.from('post_photos').insert({
            'post_id': postId,
            'image_url': url,
          });

          print("DB INSERT SUCCESS");
        } catch (e, stack) {
          print("❌ IMAGE ERROR: $e");
          print("STACK TRACE: $stack");
        }
      }

      /// ✅ FIX 3: NO FULL RELOAD — insert temporary post
      feed.posts.insert(0, {
        'id': postId,
        'content': content,
        'photos': [],
        'likes_count': 0,
        'comments_count': 0,
        'first_name': member?['first_name'] ?? '',
        'family_name': member?['family_name'] ?? '',
        'profile_photo_url': member?['profile_photo_url'] ?? '',
        'user_id': supabase.auth.currentUser?.id,
      });

      feed.notifyListeners();
    } catch (e, stack) {
      debugPrint("CREATE POST ERROR: $e");
      debugPrint("STACK TRACE: $stack");
    }
  }

  //DELET POST
  Future<void> _deletePost(String postId) async {
    try {
      await supabase.rpc('delete_post', params: {
        'p_post_id': postId,
      });

      /// refresh feed
      await feed.loadInitial();
    } catch (e) {
      print("DELETE ERROR: $e");
    }
  }

  /// 🔥 UPDATED MODAL ONLY
  /// ONLY MODIFIED PARTS:
  /// - _openComposerModal()
  /// - ElevatedButton logic

  void _openComposerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        Future.delayed(const Duration(milliseconds: 100), () {
          FocusScope.of(context).requestFocus(_modalFocusNode);
        });

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// TEXT INPUT
                  TextField(
                    controller: postController,
                    focusNode: _modalFocusNode,
                    maxLines: null,
                    onChanged: (_) => setModalState(() {}),
                    decoration: const InputDecoration(
                      hintText: "What's on your mind, Brother?",
                      border: InputBorder.none,
                    ),
                  ),

                  const SizedBox(height: 12),

                  /// IMAGE PREVIEW
                  if (selectedImages.isNotEmpty)
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: selectedImages.length,
                        itemBuilder: (_, i) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(selectedImages[i].path),
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  ),
                                ),

                                /// ❌ DELETE BUTTON
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        selectedImages.removeAt(i);
                                      });
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close,
                                          size: 16, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 12),

                  /// ACTION ROW
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      /// ADD PHOTO
                      TextButton.icon(
                        onPressed: () async {
                          await _pickImages();
                          setModalState(() {});
                        },
                        icon: const Icon(Icons.photo),
                        label: const Text("Add Photo"),
                      ),

                      /// POST BUTTON
                      ElevatedButton(
                        onPressed: (isPosting ||
                                (postController.text.trim().isEmpty &&
                                    selectedImages.isEmpty))
                            ? null
                            : () async {
                                setModalState(() => isPosting = true);

                                await _createPost();

                                /// ✅ RESET STATE
                                postController.clear();
                                selectedImages.clear();

                                /// ✅ CLOSE MODAL
                                if (context.mounted) Navigator.pop(context);

                                setState(() {});
                              },
                        child: isPosting
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text("Post"),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      /// ✅ CLEAR DRAFT WHEN MODAL CLOSES
      postController.clear();
      selectedImages.clear();
      isPosting = false;
      setState(() {});
    });
  }

  Future<List<int>> _compressImage(File file) async {
    final result = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      quality: 70, // 🔥 balance quality vs size
      minWidth: 1080,
      minHeight: 1080,
    );

    if (result == null) {
      throw Exception("Image compression failed");
    }

    return result;
  }
  // EVERYTHING ELSE UNCHANGED BELOW...

  Widget _composerCard() {
    final firstName = toProperCase(member?['first_name'] ?? '');

    return GestureDetector(
      onTap: _openComposerModal,
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            "What's on your mind, Brother $firstName?",
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoGrid(List photos) {
    final count = photos.length;

    if (count == 1) {
      return Image.network(
        photos[0],
        width: double.infinity,
        height: 250,
        fit: BoxFit.cover,
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count > 4 ? 4 : count,
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
      itemBuilder: (_, i) => Image.network(photos[i], fit: BoxFit.cover),
    );
  }

  Widget _feedCard(Map post) {
    final id = post['id'];

    final isLiked = feed.likedPostIds.contains(id);
    final likeCount = feed.likeCounts[id] ?? 0;
    final commentCount = feed.commentCounts[id] ?? 0;

    final profileUrl = (post['profile_photo_url'] ?? '').toString();
    final displayName =
        "${post['first_name'] ?? ''} ${post['family_name'] ?? ''}".trim();

    print("POST USER: ${post['user_id']}");
    print("CURRENT USER: ${supabase.auth.currentUser?.id}");
    print("PHOTOS RAW: ${post['photos']}");

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: profileUrl.isNotEmpty
                          ? NetworkImage(profileUrl)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),

                /// 🔥 SHOW DELETE ONLY IF OWNER
                if (post['user_id'] == supabase.auth.currentUser?.id)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deletePost(post['id']);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (post['content'] != null) Text(post['content']),
            if (post['photos'] != null && post['photos'].isNotEmpty)
              _buildPhotoGrid(
                (post['photos'] as List)
                    .where((e) => e != null)
                    .map((e) => e.toString())
                    .toList(),
              ),
            const Divider(),
            Text("$likeCount likes • $commentCount comments"),
          ],
        ),
      ),
    );
  }

  Widget _homeContent() {
    final firstName = toProperCase(member?['first_name'] ?? '');
    final lodge =
        "${member?['lodge_name'] ?? ''} No. ${member?['lodge_number'] ?? ''}";
    final profileUrl = (member?['profile_photo_url'] ?? '').toString();

    return AnimatedBuilder(
      animation: feed,
      builder: (_, __) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: feed.posts.length + 2,
          itemBuilder: (_, i) {
            if (i == 0) {
              return Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage:
                        profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Bro. $firstName"),
                      Text(lodge),
                    ],
                  )
                ],
              );
            }

            if (i == 1) return _composerCard();

            return _feedCard(feed.posts[i - 2]);
          },
        );
      },
    );
  }

  Widget _getBody() {
    if (_selectedIndex == 0) {
      return loading
          ? const Center(child: CircularProgressIndicator())
          : _homeContent();
    }
    if (_selectedIndex == 1) return const BrethrenScreen();
    if (_selectedIndex == 4) return const MemberProfileScreen();
    return const Center(child: Text("Coming Soon"));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Trestle Board"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _getBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: "Brethren"),
          BottomNavigationBarItem(icon: Icon(Icons.event), label: "Events"),
          BottomNavigationBarItem(
              icon: Icon(Icons.menu_book), label: "Trestle"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
