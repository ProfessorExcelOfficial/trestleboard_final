import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:intl/intl.dart';
import 'package:auto_size_text/auto_size_text.dart';

import '../models/member_profile.dart';
import '../screen/member_edit_work_screen.dart';
import '../screen/member_edit_contacts_screen.dart';
import '../screen/member_edit_identity_screen.dart';
import '../screen/member_edit_masonic_screen.dart';

class MemberProfileScreen extends StatefulWidget {
  const MemberProfileScreen({super.key});

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  final supabase = Supabase.instance.client;
  final ImagePicker picker = ImagePicker();

  MemberProfile? profile;

  bool loading = true;
  bool uploadingPhoto = false;

  String photoVersion = "";

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        setState(() => loading = false);
        return;
      }

      final member = await supabase
          .from('members')
          .select('brethren_id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (member == null) {
        setState(() => loading = false);
        return;
      }

      final brethrenId = member['brethren_id'];

      final data = await supabase
          .from('view_member_profile')
          .select()
          .eq('brethren_id', brethrenId)
          .maybeSingle();

      if (data != null) {
        profile = MemberProfile.fromJson(data);
      }

      setState(() => loading = false);
    } catch (e) {
      debugPrint("Profile load error: $e");
      setState(() => loading = false);
    }
  }

  Future<File> compressImage(File file) async {
    final targetPath = "${file.path}_compressed.jpg";

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 75,
    );

    return result == null ? file : File(result.path);
  }

  Future<void> changePhoto() async {
    try {
      final user = supabase.auth.currentUser;

      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() => uploadingPhoto = true);

      File imageFile = File(picked.path);
      imageFile = await compressImage(imageFile);

      final path = "profiles/${user!.id}.jpg";

      await supabase.storage.from('profile_photos').upload(
            path,
            imageFile,
            fileOptions: const FileOptions(upsert: true),
          );

      final imageUrl =
          supabase.storage.from('profile_photos').getPublicUrl(path);

      await supabase.from('list_brethren').update(
          {'profile_photo_url': imageUrl}).eq('id', profile!.brethrenId);

      setState(() {
        uploadingPhoto = false;
        photoVersion = DateTime.now().millisecondsSinceEpoch.toString();
      });

      loadProfile();
    } catch (e) {
      debugPrint("PHOTO UPLOAD ERROR: $e");

      setState(() => uploadingPhoto = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
    }
  }

  // =========================
  // 🔥 BUSINESS LOGIC
  // =========================

  String getDisplayRank(MemberProfile p) {
    if (p.role.trim().isNotEmpty && p.role.toLowerCase() != "member") {
      return p.role;
    }
    return "Master Mason";
  }

  String formatStatus(String status) {
    if (status.isEmpty) return "";
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }

  String resolvePendingValue({
    required String? current,
    required String? requested,
    required bool isPending,
    String fallback = "Not recorded",
  }) {
    if (isPending && requested != null) {
      return "${current ?? fallback} → $requested";
    }
    return current ?? fallback;
  }

  // =========================

  String formatDate(DateTime? date) {
    if (date == null) return "Not recorded";
    return DateFormat('MMM d, yyyy').format(date);
  }

  String formatRequestedDate(String? value) {
    if (value == null) return "";
    return DateFormat('MMM d, yyyy').format(DateTime.parse(value));
  }

  String yearsInMasonry(DateTime? mmDate) {
    if (mmDate == null) return "Not yet raised";

    final now = DateTime.now();
    int years = now.year - mmDate.year;

    if (now.month < mmDate.month ||
        (now.month == mmDate.month && now.day < mmDate.day)) {
      years--;
    }

    return "$years years";
  }

  Widget subtleBadge(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey,
      ),
    );
  }

  Widget pendingBadge() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            "Pending",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.orange,
            ),
          ),
        ),
        const SizedBox(width: 4),
        const Tooltip(
          message:
              "Waiting for approval from the Secretary or the Three Lights",
          child: Icon(Icons.info_outline, size: 16, color: Colors.orange),
        ),
      ],
    );
  }

  Widget infoRow(String label, String value, {bool pending = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value.isEmpty ? "Not recorded" : value,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                if (pending) pendingBadge(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSection({
    required String title,
    String? actionLabel,
    VoidCallback? onAction,
    required List<Widget> rows,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, letterSpacing: 1)),
              if (actionLabel != null && onAction != null)
                GestureDetector(
                  onTap: onAction,
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                        color: Color(0xFF0D2D62), fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(children: rows),
        ),
      ],
    );
  }

  Widget headerCard(MemberProfile p) {
    final rank = getDisplayRank(p);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                GestureDetector(
                  onTap: changePhoto,
                  child: CircleAvatar(
                    radius: 55,
                    backgroundImage: p.profilePhotoUrl != null
                        ? NetworkImage("${p.profilePhotoUrl}?v=$photoVersion")
                        : null,
                    child: p.profilePhotoUrl == null
                        ? const Icon(Icons.person, size: 50)
                        : null,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D2D62),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt,
                        color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AutoSizeText(
              p.displayName,
              maxLines: 1,
              minFontSize: 14,
              maxFontSize: 22,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            if (p.lodgeName != null)
              Text(
                "${p.lodgeName} No. ${p.lodgeNumber}",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0D2D62),
                ),
              ),
            if (p.city != null && p.province != null)
              Text(
                "${p.city}, ${p.province}",
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                subtleBadge(formatStatus(p.membershipStatus)),
                const Text("•", style: TextStyle(color: Colors.grey)),
                subtleBadge(rank),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (profile == null) {
      return const Center(child: Text("Profile not found"));
    }

    final p = profile!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        headerCard(p),
        buildSection(
          title: "IDENTITY",
          actionLabel: "Edit",
          onAction: () async {
            final updated = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MemberEditIdentityScreen(profile: p),
              ),
            );
            if (updated == true) loadProfile();
          },
          rows: [
            infoRow(
              "Birthday",
              resolvePendingValue(
                current: p.birthday != null ? formatDate(p.birthday) : null,
                requested: p.birthdayRequested != null
                    ? formatRequestedDate(p.birthdayRequested)
                    : null,
                isPending: p.birthdayPending,
              ),
              pending: p.birthdayPending,
            ),
            infoRow(
              "Blood Type",
              resolvePendingValue(
                current: p.bloodType,
                requested: p.bloodTypeRequested,
                isPending: p.bloodTypePending,
              ),
              pending: p.bloodTypePending,
            ),
          ],
        ),
        buildSection(
          title: "MASONIC RECORD",
          actionLabel: "Edit",
          onAction: () async {
            final updated = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MemberEditMasonicScreen(profile: p),
              ),
            );
            if (updated == true) loadProfile();
          },
          rows: [
            infoRow(
              "Entered Apprentice",
              resolvePendingValue(
                current: formatDate(p.enteredApprentice),
                requested: p.enteredApprenticeRequested != null
                    ? formatRequestedDate(p.enteredApprenticeRequested)
                    : null,
                isPending: p.enteredApprenticePending,
              ),
              pending: p.enteredApprenticePending,
            ),
            infoRow(
              "Fellowcraft",
              resolvePendingValue(
                current: formatDate(p.fellowcraft),
                requested: p.fellowcraftRequested != null
                    ? formatRequestedDate(p.fellowcraftRequested)
                    : null,
                isPending: p.fellowcraftPending,
              ),
              pending: p.fellowcraftPending,
            ),
            infoRow(
              "Master Mason",
              resolvePendingValue(
                current: formatDate(p.masterMason),
                requested: p.masterMasonRequested != null
                    ? formatRequestedDate(p.masterMasonRequested)
                    : null,
                isPending: p.masterMasonPending,
              ),
              pending: p.masterMasonPending,
            ),
            infoRow("Years in Masonry", yearsInMasonry(p.masterMason)),
          ],
        ),
        buildSection(
          title: "WORK",
          actionLabel: "Edit",
          onAction: () async {
            final updated = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MemberEditWorkScreen(
                  brethrenId: p.brethrenId,
                  occupation: p.occupation,
                  company: p.company,
                  workAddress: p.workAddress,
                  workPhone: p.workPhone,
                ),
              ),
            );
            if (updated == true) loadProfile();
          },
          rows: [
            infoRow("Occupation", p.occupation ?? ""),
            infoRow("Company", p.company ?? ""),
            infoRow("Work Address", p.workAddress ?? ""),
            infoRow("Work Phone", p.workPhone ?? ""),
          ],
        ),
        buildSection(
          title: "CONTACTS",
          actionLabel: "Edit",
          onAction: () async {
            final updated = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MemberEditContactsScreen(
                  brethrenId: p.brethrenId,
                  mobile: p.mobile,
                  emergencyName: p.emergencyContactName,
                  emergencyPhone: p.emergencyContactNumber,
                ),
              ),
            );
            if (updated == true) loadProfile();
          },
          rows: [
            infoRow("Mobile", p.mobile ?? ""),
            infoRow("Emergency Contact", p.emergencyContactName ?? ""),
            infoRow("Emergency Phone", p.emergencyContactNumber ?? ""),
          ],
        ),
      ],
    );
  }
}
