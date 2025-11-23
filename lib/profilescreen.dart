import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:attendanceapp/model/user.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

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
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked != null) {
      setState(() {
        _pickedImage = File(picked.path);
        _dirty = true;
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_pickedImage == null || _studentDocId == null) return _photoUrl;
    try {
      final ref = FirebaseStorage.instance.ref(
        'profilePictures/$_studentDocId.jpg',
      );
      await ref.putFile(_pickedImage!);
      return await ref.getDownloadURL();
    } catch (_) {
      return _photoUrl;
    }
  }

  Future<void> _saveProfile() async {
    if (_studentDocId == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final newUrl = await _uploadImage();
    final update = {
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'photoUrl': newUrl ?? (_photoUrl ?? ''),
    };
    try {
      await FirebaseFirestore.instance
          .collection('Student')
          .doc(_studentDocId)
          .set(update, SetOptions(merge: true));
      if (mounted) {
        setState(() {
          _photoUrl = newUrl;
          _saving = false;
          _dirty = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile saved')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to save profile')));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _primary,
        title: const Text('Profile', style: TextStyle(fontFamily: 'NexaBold')),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (_dirty)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Unsaved changes',
                          style: TextStyle(
                            fontFamily: 'NexaRegular',
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 62,
                            backgroundColor: Colors.white,
                            child: CircleAvatar(
                              radius: 58,
                              backgroundColor: Colors.grey.shade300,
                              backgroundImage: _pickedImage != null
                                  ? FileImage(_pickedImage!)
                                  : (_photoUrl != null && _photoUrl!.isNotEmpty)
                                  ? NetworkImage(_photoUrl!)
                                  : null,
                              child:
                                  (_photoUrl == null || _photoUrl!.isEmpty) &&
                                      _pickedImage == null
                                  ? const Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.white70,
                                    )
                                  : null,
                            ),
                          ),
                          if (_saving)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(62),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    height: 40,
                                    width: 40,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 4,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Row(
                              children: [
                                if (_photoUrl != null || _pickedImage != null)
                                  InkWell(
                                    onTap: _removePhoto,
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 6),
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                InkWell(
                                  onTap: _saving ? null : _pickImage,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _primary,
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    _buildField(
                      'Name',
                      _nameController,
                      TextInputType.name,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Name required'
                          : null,
                    ),
                    _buildField(
                      'Email',
                      _emailController,
                      TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return null; // optional
                        }
                        final reg = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                        return reg.hasMatch(v.trim()) ? null : 'Invalid email';
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _saving ? null : _saveProfile,
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save',
                                style: TextStyle(fontFamily: 'NexaBold'),
                              ),
                      ),
                    ),
                    if (_studentDocId == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'Student document not found',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontFamily: 'NexaRegular',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    TextInputType type, {
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'NexaBold',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: type,
            validator: validator,
            onChanged: (_) => setState(() => _dirty = true),
            style: const TextStyle(fontFamily: 'NexaRegular'),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
