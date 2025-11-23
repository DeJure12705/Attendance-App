import 'package:flutter/material.dart';
import 'package:attendanceapp/services/auth_service.dart';
import 'package:attendanceapp/model/user.dart';
import 'package:attendanceapp/config/cloudinary_config.dart';
import 'package:attendanceapp/login_page.dart';
import 'terms_conditions_screen.dart';
import 'pending_verification_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';

class CompleteCredentialsScreen extends StatefulWidget {
  final String? forcedRole; // 'student' or 'teacher' to lock the role
  const CompleteCredentialsScreen({super.key, this.forcedRole});
  @override
  State<CompleteCredentialsScreen> createState() =>
      _CompleteCredentialsScreenState();
}

class _CompleteCredentialsScreenState extends State<CompleteCredentialsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _addressController = TextEditingController();
  DateTime? _birthDate;
  XFile? _profileImage;
  XFile? _idImage;
  String _role = 'student';
  bool _loading = false;
  bool _uploadingProfile = false;
  bool _uploadingId = false;
  String? _error;
  String? _uploadProgress;
  // Additional safety and academic fields
  final _studentPhoneController = TextEditingController(); // optional
  final _parentPhoneController =
      TextEditingController(); // required for students
  final _guardianNameController =
      TextEditingController(); // required for students
  final _sectionController = TextEditingController(); // required for students
  // Teacher-specific fields
  final _teacherPhoneController = TextEditingController();
  final _teacherSectionController = TextEditingController();
  final _teacherAdviserController = TextEditingController();
  // Adviser teacher selection (for students)
  List<Map<String, String>> _teachers = [];
  String? _selectedTeacherUid;
  String? _selectedTeacherName;
  bool _loadingTeachers = false;

  @override
  void initState() {
    super.initState();
    // Lock role if provided by the caller and pre-load teacher list when needed
    _role = widget.forcedRole ?? _role;
    if (_role == 'student') _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    setState(() => _loadingTeachers = true);
    try {
      final q = await FirebaseFirestore.instance
          .collection('Users')
          .where('role', isEqualTo: 'teacher')
          .where('status', isEqualTo: 'approved')
          .get();
      _teachers = q.docs.map((d) {
        final data = d.data();
        final displayName = (data['fullName'] ?? data['email'] ?? 'Teacher')
            .toString();
        return {'uid': d.id, 'name': displayName};
      }).toList();
    } catch (e) {
      _error ??= 'Failed to load adviser list: ${e.toString()}';
    }
    if (mounted) setState(() => _loadingTeachers = false);
  }

  @override
  void dispose() {
    _idController.dispose();
    _fullNameController.dispose();
    _addressController.dispose();
    _studentPhoneController.dispose();
    _parentPhoneController.dispose();
    _guardianNameController.dispose();
    _sectionController.dispose();
    _teacherPhoneController.dispose();
    _teacherSectionController.dispose();
    _teacherAdviserController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _uploadProgress = null;
    });
    final enteredId = _idController.text.trim();
    final studentId = _role == 'student' ? enteredId : null;
    final teacherId = _role == 'teacher' ? enteredId : null;
    String? err;
    try {
      if (User.uid.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Not signed in (uid empty)';
        });
        return;
      }
      // Upload images first (required for both roles)
      String? profileUrl;
      String? idUrl;

      // Validate configuration before attempting upload
      if (CloudinaryConfig.uploadPreset.contains(' ')) {
        setState(() {
          _error =
              'Configuration error: Upload preset name cannot contain spaces. '
              'Update cloudinary_config.dart';
          _loading = false;
        });
        return;
      }

      // Initialize Cloudinary with config
      final cloudinary = CloudinaryPublic(
        CloudinaryConfig.cloudName,
        CloudinaryConfig.uploadPreset,
        cache: CloudinaryConfig.cache,
      );

      Future<String?> uploadToCloudinary(XFile xfile, String folder) async {
        final file = File(xfile.path);
        if (!file.existsSync()) throw Exception('Local file missing ($folder)');

        try {
          final response = await cloudinary.uploadFile(
            CloudinaryFile.fromFile(
              file.path,
              folder: folder,
              resourceType: CloudinaryResourceType.Image,
            ),
          );

          if (response.secureUrl.isEmpty) {
            throw Exception('Upload succeeded but no URL returned');
          }

          return response.secureUrl;
        } on CloudinaryException catch (e) {
          // Cloudinary-specific errors
          if (e.message?.contains('Invalid upload preset') ?? false) {
            throw Exception(
              'Preset "attendance_app" not found in Cloudinary. '
              'Create it at: console.cloudinary.com → Settings → Upload',
            );
          } else if (e.message?.contains('401') ?? false) {
            throw Exception('Wrong cloud name. Check cloudinary_config.dart');
          } else if (e.message?.contains('400') ?? false) {
            throw Exception(
              'Upload preset error. Go to console.cloudinary.com → Settings → Upload → '
              'Create preset named "attendance_app" (no spaces, Unsigned mode)',
            );
          }
          throw Exception('Cloudinary error: ${e.message ?? e.toString()}');
        } catch (e) {
          // Generic errors
          final errorMsg = e.toString();
          if (errorMsg.contains('400')) {
            throw Exception(
              'Upload preset invalid. Remove spaces from preset name',
            );
          } else if (errorMsg.contains('SocketException')) {
            throw Exception('No internet connection');
          }
          throw Exception('Upload failed: $errorMsg');
        }
      }

      if (_profileImage != null) {
        setState(() => _uploadProgress = 'Uploading profile picture...');
        try {
          profileUrl = await uploadToCloudinary(
            _profileImage!,
            'profilePictures',
          );
        } catch (e) {
          setState(() {
            _error = 'Profile upload failed: ${e.toString()}';
            _loading = false;
          });
          return;
        }
      }
      if (_idImage != null) {
        setState(() => _uploadProgress = 'Uploading ID screenshot...');
        try {
          idUrl = await uploadToCloudinary(_idImage!, 'idScreenshots');
        } catch (e) {
          setState(() {
            _error = 'ID upload failed: ${e.toString()}';
            _loading = false;
          });
          return;
        }
      }
      setState(() => _uploadProgress = 'Saving profile data...');
      try {
        err = await AuthService()
            .completeCredentials(
              role: _role,
              studentId: studentId,
              teacherId: teacherId,
            )
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                return 'Timeout saving profile. Check internet connection.';
              },
            );
      } catch (e) {
        err = 'Failed to save profile: ${e.toString()}';
      }

      if (err == null && (_role == 'student' || _role == 'teacher')) {
        if (!mounted) return;
        setState(() => _uploadProgress = 'Saving additional data...');
        try {
          final data = <String, dynamic>{
            'fullName': _fullNameController.text.trim(),
            'address': _addressController.text.trim(),
            'birthdate': _birthDate != null
                ? Timestamp.fromDate(_birthDate!)
                : null,
            if (profileUrl != null) 'profilePictureUrl': profileUrl,
            if (idUrl != null) 'idScreenshotUrl': idUrl,
            if (studentId != null && studentId.isNotEmpty)
              'studentId': studentId,
            if (teacherId != null && teacherId.isNotEmpty)
              'teacherId': teacherId,
            if (_role == 'student')
              'studentContactPhone': _studentPhoneController.text.trim(),
            if (_role == 'student')
              'parentPhone': _parentPhoneController.text.trim(),
            if (_role == 'student')
              'guardianName': _guardianNameController.text.trim(),
            if (_role == 'student') 'section': _sectionController.text.trim(),
            if (_role == 'student') 'adviserTeacherUid': _selectedTeacherUid,
            if (_role == 'student') 'adviserTeacherName': _selectedTeacherName,
            'acceptedTerms': true,
            'acceptedTermsAt': FieldValue.serverTimestamp(),
          }..removeWhere((k, v) => v == null);

          // Debug: Log URLs being saved
          print('=== SAVING TO FIRESTORE ===');
          print('Profile URL: $profileUrl');
          print('ID URL: $idUrl');
          print('User ID: ${User.uid}');
          print('Data: $data');
          print('==========================');

          await FirebaseFirestore.instance
              .collection('Users')
              .doc(User.uid)
              .set(data, SetOptions(merge: true))
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  throw TimeoutException('Firestore write timed out');
                },
              );

          print('✅ Data saved successfully to Firestore');

          // Success! Navigate to pending verification screen
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const PendingVerificationScreen(),
            ),
          );
          return;
        } catch (e) {
          print('❌ Error saving to Firestore: $e');
          err = 'Failed to save additional data: ${e.toString()}';
        }
      }
    } catch (e) {
      print('❌ Exception in submit: $e');
      err = 'Failed to complete profile: ${e.toString()}';
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = err;
      _uploadProgress = null;
    });
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = DateTime(now.year - 18, now.month, now.day);
    final first = DateTime(now.year - 80);
    final last = DateTime(now.year - 5);
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _pickImage(bool isProfile) async {
    // Show options: Camera or Gallery
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Select ${isProfile ? "Profile Picture" : "ID Screenshot"}',
          style: const TextStyle(fontFamily: 'NexaBold'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    if (isProfile) {
      setState(() => _uploadingProfile = true);
    } else {
      setState(() => _uploadingId = true);
    }

    try {
      final picker = ImagePicker();
      final img = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (img != null) {
        // Validate image size (max 5MB)
        final file = File(img.path);
        final fileSize = await file.length();
        if (fileSize > 5 * 1024 * 1024) {
          if (!mounted) return;
          setState(() {
            _error = 'Image too large. Please select an image under 5MB.';
            if (isProfile) {
              _uploadingProfile = false;
            } else {
              _uploadingId = false;
            }
          });
          return;
        }

        setState(() {
          _error = null;
          if (isProfile) {
            _profileImage = img;
            _uploadingProfile = false;
          } else {
            _idImage = img;
            _uploadingId = false;
          }
        });
      } else {
        setState(() {
          if (isProfile) {
            _uploadingProfile = false;
          } else {
            _uploadingId = false;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to pick image: ${e.toString()}';
        if (isProfile) {
          _uploadingProfile = false;
        } else {
          _uploadingId = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Change account',
          onPressed: () async {
            await AuthService().signOut();
            if (!mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginPage()),
              (route) => false,
            );
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 32,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Complete Profile',
                        style: TextStyle(fontFamily: 'NexaBold', fontSize: 26),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Signed in as ${User.email}',
                        style: const TextStyle(fontFamily: 'NexaRegular'),
                      ),
                      const SizedBox(height: 20),
                      if (widget.forcedRole == null)
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'student',
                              label: Text('Student'),
                            ),
                            ButtonSegment(
                              value: 'teacher',
                              label: Text('Teacher'),
                            ),
                          ],
                          selected: {_role},
                          onSelectionChanged: (s) async {
                            setState(() => _role = s.first);
                            if (_role == 'student' && _teachers.isEmpty) {
                              await _loadTeachers();
                            }
                          },
                        ),
                      if (_role == 'student' || _role == 'teacher') ...[
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _idController,
                          decoration: InputDecoration(
                            labelText: _role == 'student'
                                ? 'Student ID'
                                : 'Teacher ID',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if ((_role == 'student' || _role == 'teacher') &&
                                (v == null || v.trim().isEmpty)) {
                              return _role == 'student'
                                  ? 'Student ID required'
                                  : 'Teacher ID required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _fullNameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if ((_role == 'student' || _role == 'teacher') &&
                                (v == null || v.trim().isEmpty)) {
                              return 'Full Name required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _addressController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Address',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if ((_role == 'student' || _role == 'teacher') &&
                                (v == null || v.trim().isEmpty)) {
                              return 'Address required';
                            }
                            return null;
                          },
                        ),
                        if (_role == 'teacher') ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _teacherPhoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Contact Number',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if (_role == 'teacher' &&
                                  (v == null || v.trim().isEmpty)) {
                                return 'Contact number required';
                              }
                              if (v != null && v.trim().isNotEmpty) {
                                final reg = RegExp(r'^[0-9+\-() ]{7,}$');
                                if (!reg.hasMatch(v.trim())) {
                                  return 'Invalid phone format';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _teacherSectionController,
                            decoration: const InputDecoration(
                              labelText: 'Section / Advisory',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if (_role == 'teacher' &&
                                  (v == null || v.trim().isEmpty)) {
                                return 'Section required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _teacherAdviserController,
                            decoration: const InputDecoration(
                              labelText: 'Adviser',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if (_role == 'teacher' &&
                                  (v == null || v.trim().isEmpty)) {
                                return 'Adviser required';
                              }
                              return null;
                            },
                          ),
                        ],
                        if (_role == 'student') ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _studentPhoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Student Contact Number (Optional)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if (v != null && v.trim().isNotEmpty) {
                                final reg = RegExp(r'^[0-9+\-() ]{7,}$');
                                if (!reg.hasMatch(v.trim())) {
                                  return 'Invalid phone format';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _parentPhoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Parent Phone Number',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if (_role == 'student' &&
                                  (v == null || v.trim().isEmpty)) {
                                return 'Parent phone required';
                              }
                              if (v != null && v.trim().isNotEmpty) {
                                final reg = RegExp(r'^[0-9+\-() ]{7,}$');
                                if (!reg.hasMatch(v.trim())) {
                                  return 'Invalid phone format';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _guardianNameController,
                            decoration: const InputDecoration(
                              labelText: 'Guardian / Parent Name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if (_role == 'student' &&
                                  (v == null || v.trim().isEmpty)) {
                                return 'Guardian name required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _sectionController,
                            decoration: const InputDecoration(
                              labelText: 'Section / Class',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if (_role == 'student' &&
                                  (v == null || v.trim().isEmpty)) {
                                return 'Section required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Adviser / Teacher',
                              border: OutlineInputBorder(),
                            ),
                            items: _teachers
                                .map(
                                  (t) => DropdownMenuItem<String>(
                                    value: t['uid'],
                                    child: Text(t['name'] ?? 'Teacher'),
                                  ),
                                )
                                .toList(),
                            value: _selectedTeacherUid,
                            onChanged: (val) {
                              setState(() {
                                _selectedTeacherUid = val;
                                _selectedTeacherName = _teachers.firstWhere(
                                  (e) => e['uid'] == val,
                                  orElse: () => {'uid': val ?? '', 'name': ''},
                                )['name'];
                              });
                            },
                            validator: (v) {
                              if (_role == 'student' &&
                                  (v == null || v.isEmpty)) {
                                return 'Adviser required';
                              }
                              return null;
                            },
                            hint: _loadingTeachers
                                ? const Text('Loading teachers...')
                                : const Text('Select adviser teacher'),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _pickBirthDate,
                                child: Text(
                                  _birthDate == null
                                      ? 'Select Birthdate'
                                      : 'Birthdate: ${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    fontFamily: 'NexaRegular',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Stack(
                                    children: [
                                      GestureDetector(
                                        onTap: _uploadingProfile
                                            ? null
                                            : () => _pickImage(true),
                                        child: CircleAvatar(
                                          radius: 42,
                                          backgroundColor: Colors.grey[200],
                                          backgroundImage: _profileImage != null
                                              ? FileImage(
                                                  File(_profileImage!.path),
                                                )
                                              : null,
                                          child: _uploadingProfile
                                              ? const CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                )
                                              : _profileImage == null
                                              ? const Icon(
                                                  Icons.camera_alt,
                                                  color: Colors.black54,
                                                )
                                              : null,
                                        ),
                                      ),
                                      if (_profileImage != null &&
                                          !_uploadingProfile)
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: GestureDetector(
                                            onTap: () => setState(
                                              () => _profileImage = null,
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                size: 16,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Profile Picture',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  if (_profileImage != null)
                                    const Text(
                                      '✓ Selected',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.green,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                children: [
                                  Stack(
                                    children: [
                                      GestureDetector(
                                        onTap: _uploadingId
                                            ? null
                                            : () => _pickImage(false),
                                        child: Container(
                                          height: 84,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            image: _idImage != null
                                                ? DecorationImage(
                                                    fit: BoxFit.cover,
                                                    image: FileImage(
                                                      File(_idImage!.path),
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          alignment: Alignment.center,
                                          child: _uploadingId
                                              ? const CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                )
                                              : _idImage == null
                                              ? const Icon(
                                                  Icons.badge_outlined,
                                                  color: Colors.black54,
                                                )
                                              : null,
                                        ),
                                      ),
                                      if (_idImage != null && !_uploadingId)
                                        Positioned(
                                          right: 4,
                                          top: 4,
                                          child: GestureDetector(
                                            onTap: () =>
                                                setState(() => _idImage = null),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                size: 16,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'ID Screenshot',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  if (_idImage != null)
                                    const Text(
                                      '✓ Selected',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.green,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.info_outline, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _role == 'student'
                                    ? 'Student credentials required for verification.'
                                    : 'Teacher credentials required for verification.',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                      const SizedBox(height: 24),
                      if (_uploadProgress != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _uploadProgress!,
                                style: const TextStyle(
                                  fontFamily: 'NexaRegular',
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _loading
                              ? null
                              : () {
                                  if (_role == 'student' ||
                                      _role == 'teacher') {
                                    if (_birthDate == null) {
                                      setState(
                                        () => _error = 'Birthdate required',
                                      );
                                      return;
                                    }
                                    if (_profileImage == null) {
                                      setState(
                                        () =>
                                            _error = 'Profile picture required',
                                      );
                                      return;
                                    }
                                    if (_idImage == null) {
                                      setState(
                                        () => _error = 'ID screenshot required',
                                      );
                                      return;
                                    }
                                    if (_role == 'student') {
                                      if (_parentPhoneController.text
                                          .trim()
                                          .isEmpty) {
                                        setState(
                                          () =>
                                              _error = 'Parent phone required',
                                        );
                                        return;
                                      }
                                      if (_guardianNameController.text
                                          .trim()
                                          .isEmpty) {
                                        setState(
                                          () =>
                                              _error = 'Guardian name required',
                                        );
                                        return;
                                      }
                                      if (_sectionController.text
                                          .trim()
                                          .isEmpty) {
                                        setState(
                                          () => _error = 'Section required',
                                        );
                                        return;
                                      }
                                      if (_selectedTeacherUid == null) {
                                        setState(
                                          () => _error = 'Adviser required',
                                        );
                                        return;
                                      }
                                    }
                                    if (_role == 'teacher') {
                                      if (_teacherPhoneController.text
                                          .trim()
                                          .isEmpty) {
                                        setState(
                                          () => _error =
                                              'Contact number required',
                                        );
                                        return;
                                      }
                                      if (_teacherSectionController.text
                                          .trim()
                                          .isEmpty) {
                                        setState(
                                          () => _error = 'Section required',
                                        );
                                        return;
                                      }
                                      if (_teacherAdviserController.text
                                          .trim()
                                          .isEmpty) {
                                        setState(
                                          () => _error = 'Adviser required',
                                        );
                                        return;
                                      }
                                    }
                                  }
                                  _submit();
                                },
                          child: _loading
                              ? const SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                  ),
                                )
                              : const Text(
                                  'Submit',
                                  style: TextStyle(fontFamily: 'NexaBold'),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TermsConditionsScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'View Terms & Conditions',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      const Text(
                        'After submission your account enters pending approval.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'NexaRegular',
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
