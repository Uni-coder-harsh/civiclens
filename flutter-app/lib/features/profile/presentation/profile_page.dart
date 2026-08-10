import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/auth/auth_session.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../../../shared/ticket.dart';

class HomeProfilePage extends ConsumerWidget {
  const HomeProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: CustomScrollView(
        slivers: [
          // ── Header / Avatar Section ──
          SliverAppBar(
            backgroundColor: const Color(0xFF0F172A),
            surfaceTintColor: Colors.transparent,
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
                      ),
                    ),
                  ),
                  // Decorative glow circle
                  Positioned(
                    top: -30,
                    right: -30,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  // Avatar + Name
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: session.avatarUrl == null
                                ? const LinearGradient(
                                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                  )
                                : null,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: session.avatarUrl != null && session.avatarUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: session.avatarUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                    errorWidget: (context, url, error) => Center(
                                      child: Text(
                                        session.displayName?.isNotEmpty == true
                                            ? session.displayName!.substring(0, 1).toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      session.isGuest
                                          ? 'G'
                                          : (session.displayName?.isNotEmpty == true
                                              ? session.displayName!.substring(0, 1).toUpperCase()
                                              : 'U'),
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              session.displayName ?? (session.isGuest ? 'Guest User' : 'User'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                fontFamily: 'Inter',
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: _roleColor(session.role).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _roleColor(session.role).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                session.role.name.toUpperCase(),
                                style: TextStyle(
                                  color: _roleColor(session.role),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Inter',
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Profile Body ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Account Details Card ──
                _AccountDetailsCard(session: session),

                const SizedBox(height: 24),

                // ── Sign Out Button ──
                GestureDetector(
                  onTap: () {
                    ref.read(authControllerProvider.notifier).signOut();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Sign Out of Account',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.citizen:
        return const Color(0xFF0D9488);
      case UserRole.officer:
        return const Color(0xFF818CF8);
      case UserRole.contractor:
        return const Color(0xFFF59E0B);
      case UserRole.admin:
        return const Color(0xFFEF4444);
    }
  }
}

class _AccountDetailsCard extends StatelessWidget {
  final AuthSession session;

  const _AccountDetailsCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ACCOUNT DETAILS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  fontFamily: 'Inter',
                  letterSpacing: 1.5,
                ),
              ),
              if (!session.isGuest)
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.edit_rounded, color: Color(0xFF818CF8), size: 20),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => _EditProfileDialog(session: session),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          _AccountInfoRow(
            icon: Icons.person_rounded,
            label: 'Full Name',
            value: session.displayName ?? 'Citizen Reporter',
          ),
          const Divider(color: Color(0xFF334155), height: 32),
          _AccountInfoRow(
            icon: Icons.email_rounded,
            label: 'Email Address',
            value: session.email ?? 'Not provided',
          ),
          const Divider(color: Color(0xFF334155), height: 32),
          _AccountInfoRow(
            icon: Icons.phone_rounded,
            label: 'Phone Number',
            value: session.phoneNumber != null && session.phoneNumber!.isNotEmpty
                ? '+91 ${session.phoneNumber}'
                : 'Not linked',
          ),
          const Divider(color: Color(0xFF334155), height: 32),
          _AccountInfoRow(
            icon: Icons.verified_user_rounded,
            label: 'Verification Status',
            value: session.isGuest
                ? 'Guest Access Only'
                : 'Verified Contributor (Active)',
            valueColor: session.isGuest ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }
}

class _AccountInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _AccountInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF94A3B8), size: 20),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EditProfileDialog extends ConsumerStatefulWidget {
  final AuthSession session;

  const _EditProfileDialog({required this.session});

  @override
  ConsumerState<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<_EditProfileDialog> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  String? _avatarUrl;
  bool _isLoading = false;
  String? _uploadError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.session.displayName);
    _emailController = TextEditingController(text: widget.session.email);
    _phoneController = TextEditingController(text: widget.session.phoneNumber);
    _avatarUrl = widget.session.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Colors.white),
              title: const Text('Take Photo', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Colors.white),
              title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    setState(() {
      _isLoading = true;
      _uploadError = null;
    });

    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: source,
        imageQuality: 100,
      );

      if (file == null) {
        setState(() => _isLoading = false);
        return;
      }

      final path = file.path;
      final extension = path.split('.').last.toLowerCase();
      final allowed = ['jpg', 'jpeg', 'png', 'webp'];
      if (!allowed.contains(extension)) {
        throw Exception("Only JPG, PNG, and WEBP files are allowed.");
      }

      final originalFile = File(path);
      final size = await originalFile.length();
      if (size > 10 * 1024 * 1024) {
        throw Exception("Original file size exceeds 10MB limit.");
      }

      // Optimize/compress image before uploading
      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/compressed_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      String uploadPath = path;
      try {
        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          path,
          targetPath,
          quality: 80,
          minWidth: 800,
          minHeight: 800,
          format: CompressFormat.jpeg,
        );
        if (compressedFile != null) {
          uploadPath = compressedFile.path;
          final optimizedSize = await File(uploadPath).length();
          if (optimizedSize > 5 * 1024 * 1024) {
            throw Exception("Optimized file size exceeds 5MB limit.");
          }
        }
      } catch (compressErr) {
        debugPrint("Local compression failed: $compressErr");
      }

      // Upload file directly to Supabase S3
      final url = await ref.read(authControllerProvider.notifier).uploadAvatar(uploadPath);
      setState(() {
        _avatarUrl = url;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _uploadError = e.toString().replaceAll("Exception: ", "");
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authControllerProvider.notifier).updateProfile(
            displayName: _nameController.text.trim(),
            email: _emailController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
            avatarUrl: _avatarUrl,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _uploadError = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Edit Profile',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              // Avatar picker with Edit overlay
              GestureDetector(
                onTap: _isLoading ? null : _pickAndUploadAvatar,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF334155),
                        border: Border.all(color: const Color(0xFF4F46E5), width: 2),
                      ),
                      child: ClipOval(
                        child: _avatarUrl != null
                            ? CachedNetworkImage(
                                imageUrl: _avatarUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.person_rounded, size: 40, color: Color(0xFF94A3B8)),
                      ),
                    ),
                    if (_isLoading)
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.4),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    else
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF4F46E5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (_uploadError != null) ...[
                Text(
                  _uploadError!,
                  style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
              ],

              // Full name field
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontFamily: 'Inter'),
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  labelStyle: const TextStyle(color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFF0F172A).withValues(alpha: 0.3),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF4F46E5)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Email field
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white, fontFamily: 'Inter'),
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  labelStyle: const TextStyle(color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFF0F172A).withValues(alpha: 0.3),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF4F46E5)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Phone number field
              TextField(
                controller: _phoneController,
                style: const TextStyle(color: Colors.white, fontFamily: 'Inter'),
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  labelStyle: const TextStyle(color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFF0F172A).withValues(alpha: 0.3),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF4F46E5)),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
