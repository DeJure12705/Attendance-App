import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:attendanceapp/model/user.dart';
import 'package:attendanceapp/services/auth_service.dart';
import 'package:attendanceapp/services/theme_service.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:attendanceapp/config/cloudinary_config.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;

  String? _photoUrl;
  File? _pickedImage;
  String? _studentDocId;

  Color get _primary => const Color.fromARGB(252, 47, 145, 42);

  @override
  void initState() {
    super.initState();
    _initializeProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _initializeProfile() async {
    try {
      if (User.id.trim().isEmpty) {
        final query = await FirebaseFirestore.instance
            .collection('Student')
            .where('id', isEqualTo: User.studentId.trim())
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          _studentDocId = query.docs.first.id;
          User.id = _studentDocId!;
        }
      } else {
        _studentDocId = User.id.trim();
      }
      if (_studentDocId != null) {
        final snap = await FirebaseFirestore.instance
            .collection('Student')
            .doc(_studentDocId)
            .get();
        if (snap.exists) {
          final data = snap.data() as Map<String, dynamic>;
          _nameController.text = (data['name'] ?? '').toString();
          _emailController.text = (data['email'] ?? '').toString();
          _photoUrl = data['photoUrl']?.toString();
        }
      }
      // Fallback: if student doc has no photoUrl, try Users doc which may store 'profilePictureUrl' or 'photoUrl'
      if (_photoUrl == null || _photoUrl!.isEmpty) {
        final userSnap = await FirebaseFirestore.instance
            .collection('Users')
            .doc(User.uid)
            .get();
        if (userSnap.exists) {
          final uData = userSnap.data() as Map<String, dynamic>;
          final fromUsers = (uData['photoUrl'] ?? uData['profilePictureUrl']);
          if (fromUsers != null && fromUsers.toString().isNotEmpty) {
            _photoUrl = fromUsers.toString();
          }
          // If name/email empty in student doc but present in Users, hydrate fields
          if (_nameController.text.trim().isEmpty &&
              (uData['fullName'] != null)) {
            _nameController.text = uData['fullName'].toString();
          }
          if (_emailController.text.trim().isEmpty &&
              (uData['email'] != null)) {
            _emailController.text = uData['email'].toString();
          }
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Choose Profile Picture',
              style: TextStyle(fontFamily: 'NexaBold', fontSize: 18),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.camera_alt_rounded, color: _primary),
              ),
              title: const Text(
                'Camera',
                style: TextStyle(fontFamily: 'NexaBold'),
              ),
              subtitle: const Text(
                'Take a new photo',
                style: TextStyle(fontFamily: 'NexaRegular'),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.photo_library_rounded, color: _primary),
              ),
              title: const Text(
                'Gallery',
                style: TextStyle(fontFamily: 'NexaBold'),
              ),
              subtitle: const Text(
                'Choose from gallery',
                style: TextStyle(fontFamily: 'NexaRegular'),
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            if (_photoUrl != null || _pickedImage != null)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete_rounded, color: Colors.red),
                ),
                title: const Text(
                  'Remove Photo',
                  style: TextStyle(fontFamily: 'NexaBold', color: Colors.red),
                ),
                subtitle: const Text(
                  'Delete profile picture',
                  style: TextStyle(fontFamily: 'NexaRegular'),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _removePhoto();
                },
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );

    if (source != null) {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 70,
      );
      if (picked != null) {
        setState(() {
          _pickedImage = File(picked.path);
          _dirty = true;
        });
      }
    }
  }

  void _removePhoto() {
    if (_saving) return;
    setState(() {
      _pickedImage = null;
      _photoUrl = null;
      _dirty = true;
    });
  }

  Future<String?> _uploadImage() async {
    if (_pickedImage == null) return _photoUrl;

    try {
      // Validate file size (5MB limit)
      final fileSize = await _pickedImage!.length();
      if (fileSize > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Image too large. Please select an image under 5MB.',
              ),
            ),
          );
        }
        return _photoUrl;
      }

      // Initialize Cloudinary
      final cloudinary = CloudinaryPublic(
        CloudinaryConfig.cloudName,
        CloudinaryConfig.uploadPreset,
        cache: CloudinaryConfig.cache,
      );

      // Upload to Cloudinary with folder organization
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          _pickedImage!.path,
          folder: 'profile_pictures',
          resourceType: CloudinaryResourceType.Image,
        ),
      );

      return response.secureUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: ${e.toString()}')),
        );
      }
      return _photoUrl;
    }
  }

  Future<void> _saveProfile() async {
    if (_studentDocId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student profile not found. Please try again.'),
          ),
        );
      }
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    try {
      // Upload image first if there's a new one
      String? newUrl = _photoUrl;
      if (_pickedImage != null) {
        newUrl = await _uploadImage();
        if (newUrl == null || newUrl == _photoUrl) {
          // Upload failed but we got the old URL, or upload failed
          if (_pickedImage != null && newUrl == null) {
            throw Exception('Image upload failed');
          }
        }
      }

      // Prepare update data (student collection)
      final studentUpdate = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        if (newUrl != null && newUrl.isNotEmpty) 'photoUrl': newUrl,
      };

      // Prepare Users doc update for cross-compatibility with profile completion screen
      final usersUpdate = {
        if (newUrl != null && newUrl.isNotEmpty) 'photoUrl': newUrl,
        if (newUrl != null && newUrl.isNotEmpty) 'profilePictureUrl': newUrl,
        // Keep existing fullName if set here and not empty
        if (_nameController.text.trim().isNotEmpty)
          'fullName': _nameController.text.trim(),
      };

      final batch = FirebaseFirestore.instance.batch();
      batch.set(
        FirebaseFirestore.instance.collection('Student').doc(_studentDocId),
        studentUpdate,
        SetOptions(merge: true),
      );
      batch.set(
        FirebaseFirestore.instance.collection('Users').doc(User.uid),
        usersUpdate,
        SetOptions(merge: true),
      );
      await batch.commit();

      if (mounted) {
        setState(() {
          _photoUrl = newUrl;
          _pickedImage = null;
          _saving = false;
          _dirty = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Modern App Bar with gradient
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  backgroundColor: _primary,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_primary, _primary.withOpacity(0.7)],
                        ),
                      ),
                      child: SafeArea(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 60),
                            // Profile Picture
                            Hero(
                              tag: 'profile_avatar',
                              child: Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimary,
                                        width: 4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Theme.of(
                                            context,
                                          ).shadowColor.withOpacity(0.2),
                                          blurRadius: 15,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: CircleAvatar(
                                      radius: 50,
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      backgroundImage: _pickedImage != null
                                          ? FileImage(_pickedImage!)
                                          : (_photoUrl != null &&
                                                _photoUrl!.isNotEmpty)
                                          ? NetworkImage(_photoUrl!)
                                          : null,
                                      child:
                                          (_photoUrl == null ||
                                                  _photoUrl!.isEmpty) &&
                                              _pickedImage == null
                                          ? Icon(
                                              Icons.person_rounded,
                                              size: 50,
                                              color: _primary.withOpacity(0.5),
                                            )
                                          : null,
                                    ),
                                  ),
                                  if (_saving)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).shadowColor.withOpacity(0.38),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onPrimary,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: _saving ? null : _pickImage,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.surface,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Theme.of(
                                                context,
                                              ).shadowColor.withOpacity(0.2),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.camera_alt_rounded,
                                          color: _primary,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // User Info Card
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: _primary,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'User Information',
                                        style: TextStyle(
                                          fontFamily: 'NexaBold',
                                          fontSize: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  // Role Badge
                                  _buildInfoRow(
                                    Icons.badge_rounded,
                                    'Role',
                                    User.role.isNotEmpty
                                        ? User.role[0].toUpperCase() +
                                              User.role.substring(1)
                                        : 'N/A',
                                  ),
                                  if (User.studentId.isNotEmpty) ...[
                                    const Divider(height: 24),
                                    _buildInfoRow(
                                      Icons.numbers_rounded,
                                      'Student ID',
                                      User.studentId,
                                    ),
                                  ],
                                  const Divider(height: 24),
                                  _buildInfoRow(
                                    Icons.email_outlined,
                                    'Account Email',
                                    User.email.isNotEmpty ? User.email : 'N/A',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Edit Profile Card
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.edit_rounded,
                                        color: _primary,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Edit Profile',
                                        style: TextStyle(
                                          fontFamily: 'NexaBold',
                                          fontSize: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_dirty) ...[
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.orange.shade200,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.warning_amber_rounded,
                                            color: Colors.orange.shade700,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'You have unsaved changes',
                                              style: TextStyle(
                                                fontFamily: 'NexaRegular',
                                                color: Colors.orange.shade700,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 20),
                                  _buildModernField(
                                    'Full Name',
                                    _nameController,
                                    Icons.person_outline_rounded,
                                    TextInputType.name,
                                    validator: (v) =>
                                        v == null || v.trim().isEmpty
                                        ? 'Name is required'
                                        : null,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildModernField(
                                    'Email Address',
                                    _emailController,
                                    Icons.email_outlined,
                                    TextInputType.emailAddress,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return null; // optional
                                      }
                                      final reg = RegExp(
                                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                      );
                                      return reg.hasMatch(v.trim())
                                          ? null
                                          : 'Invalid email format';
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 54,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _primary,
                                        foregroundColor: Theme.of(
                                          context,
                                        ).colorScheme.onPrimary,
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      onPressed: _saving ? null : _saveProfile,
                                      icon: _saving
                                          ? SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onPrimary,
                                              ),
                                            )
                                          : const Icon(Icons.save_rounded),
                                      label: Text(
                                        _saving ? 'Saving...' : 'Save Changes',
                                        style: const TextStyle(
                                          fontFamily: 'NexaBold',
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Sign Out Card
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: InkWell(
                              onTap: _signOut,
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.logout_rounded,
                                      color: Colors.red.shade400,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 16),
                                    const Text(
                                      'Sign Out',
                                      style: TextStyle(
                                        fontFamily: 'NexaBold',
                                        fontSize: 16,
                                        color: Colors.red,
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: Colors.red.shade300,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (_studentDocId == null)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline_rounded,
                                      color: Colors.red.shade700,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Student document not found',
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontFamily: 'NexaRegular',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _primary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'NexaRegular',
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontFamily: 'NexaBold', fontSize: 16),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernField(
    String label,
    TextEditingController controller,
    IconData icon,
    TextInputType type, {
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'NexaBold',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: type,
          validator: validator,
          onChanged: (_) => setState(() => _dirty = true),
          style: const TextStyle(fontFamily: 'NexaRegular', fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            prefixIcon: Icon(icon, color: _primary.withOpacity(0.7)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade300),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out', style: TextStyle(fontFamily: 'NexaBold')),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(fontFamily: 'NexaRegular'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'NexaBold',
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Theme.of(context).colorScheme.onError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Sign Out',
              style: TextStyle(fontFamily: 'NexaBold'),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await AuthService().signOut();
    }
  }
}
