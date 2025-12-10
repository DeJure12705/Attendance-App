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

/// UNIFIED REGISTRATION FLOW - Profile Completion Screen
///
/// This screen serves as the second step in the registration process for:
/// 1. Google Sign-In users (always redirected here from register_page.dart)
/// 2. Email/Password users with 'incomplete' status
///
/// PURPOSE:
/// - Collects comprehensive profile information (name, address, birthdate, etc.)
/// - Uploads profile picture and ID screenshot to Cloudinary
/// - Saves all data to Firestore under the user's document
/// - Enforces role-specific required fields (student vs teacher)
///
/// DATA FLOW:
/// register_page.dart → complete_credentials_screen.dart → pending_verification_screen.dart
///
/// ROLE LOCKING:
/// - forcedRole parameter prevents users from changing their selected role
/// - Passed from register_page.dart after Google Sign-In or email registration
///
/// VALIDATION & STORAGE:
/// - Form validation ensures all required fields are filled
/// - Pre-submission checks verify images and role-specific fields
/// - Firestore merge operation preserves existing user data (email, role, uid)
/// - Cloudinary stores images with secure URLs saved to Firestore
///
/// NAVIGATION:
/// - Success: Routes to PendingVerificationScreen (awaiting admin approval)
/// - Logout: Returns to LoginPage with account sign-out
class CompleteCredentialsScreen extends StatefulWidget {
  /// Role forced from previous screen (prevents role switching during registration)
  /// - 'student': Lock to student role with student-specific fields
  /// - 'teacher': Lock to teacher role with teacher-specific fields
  /// - null: Allow role selection (legacy support)
  final String? forcedRole;

  const CompleteCredentialsScreen({super.key, this.forcedRole});

  @override
  State<CompleteCredentialsScreen> createState() =>
      _CompleteCredentialsScreenState();
}

class _CompleteCredentialsScreenState extends State<CompleteCredentialsScreen> {
  // === FORM CONTROLLERS ===
  // Core fields required for all users
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController(); // Student ID or Teacher ID
  final _fullNameController = TextEditingController(); // Full legal name
  final _addressController = TextEditingController(); // Home address

  // === STATE VARIABLES ===
  DateTime? _birthDate; // Date of birth (required)
  XFile? _profileImage; // Profile picture (required, uploaded to Cloudinary)
  XFile?
  _idImage; // ID screenshot for verification (required, uploaded to Cloudinary)
  String _role = 'student'; // Default role, locked if forcedRole is provided
  bool _loading = false; // Main submission loading state
  bool _uploadingProfile = false; // Profile image picker loading state
  bool _uploadingId = false; // ID image picker loading state
  String? _error; // Error message display
  String? _uploadProgress; // Current upload step message

  // === STUDENT-SPECIFIC FIELDS ===
  // Safety and emergency contact information
  final _studentPhoneController =
      TextEditingController(); // Student's own phone (optional)
  final _parentPhoneController =
      TextEditingController(); // Parent/guardian phone (required)
  final _guardianNameController =
      TextEditingController(); // Parent/guardian full name (required)
  final _sectionController =
      TextEditingController(); // Academic section/class (auto-set from adviser)
  String? _selectedTeacherAdvisory; // Advisory linked to selected teacher

  // === TEACHER-SPECIFIC FIELDS ===
  // Professional and contact information
  final _teacherPhoneController =
      TextEditingController(); // Teacher contact number (required)
  final _teacherSectionController =
      TextEditingController(); // Section teacher handles (required)
  final _teacherAdviserController =
      TextEditingController(); // Department adviser name (required)
  // Teacher Advisory Section field - stores the class/section the teacher advises
  final _teacherAdvisoryController =
      TextEditingController(); // Advisory section the teacher manages (required)

  // === STUDENT ADVISER SELECTION ===
  // Dropdown data for selecting assigned teacher/adviser
  List<Map<String, String?>> _teachers =
      []; // List of approved teachers fetched from Firestore (with advisory)
  String? _selectedTeacherUid; // Selected teacher's Firebase UID
  String? _selectedTeacherName; // Selected teacher's display name
  bool _loadingTeachers = false; // Loading state for teacher list fetch

  @override
  void initState() {
    super.initState();

    // === ROLE LOCKING FOR UNIFIED REGISTRATION ===
    // If forcedRole is provided (from register_page.dart), lock the role selector
    // This prevents users from changing their role mid-registration
    _role = widget.forcedRole ?? _role;

    // Pre-load teacher list for student role (used in adviser dropdown)
    if (_role == 'student') _loadTeachers();
  }

  /// Loads list of approved teachers from Firestore for student adviser dropdown.
  /// Only fetches teachers with status='approved' to ensure valid adviser assignment.
  /// Called automatically when role is 'student' in initState.
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
        final advisory = data['advisory']?.toString();
        return {'uid': d.id, 'name': displayName, 'advisory': advisory};
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
    _teacherAdvisoryController.dispose();
    super.dispose();
  }

  /// UNIFIED REGISTRATION - Main submission handler
  ///
  /// PROCESS FLOW:
  /// 1. Validate all form fields (TextFormField validators)
  /// 2. Upload profile picture to Cloudinary → get secure URL
  /// 3. Upload ID screenshot to Cloudinary → get secure URL
  /// 4. Call AuthService.completeCredentials (updates User model and Firestore role/status)
  /// 5. Save comprehensive profile data to Firestore (merge with existing user document)
  /// 6. Navigate to PendingVerificationScreen (awaiting admin approval)
  ///
  /// DATA SAVED TO FIRESTORE:
  /// - Core: fullName, address, birthdate, profilePictureUrl, idScreenshotUrl
  /// - Student: studentId, studentContactPhone, parentPhone, guardianName, section, adviserTeacherUid/Name
  /// - Teacher: teacherId, contactNumber, advisory (section managed by teacher)
  /// - Compliance: acceptedTerms, acceptedTermsAt timestamp
  ///
  /// ERROR HANDLING:
  /// - Network errors during image upload
  /// - Cloudinary configuration errors (preset, cloud name)
  /// - Firestore write failures
  /// - Timeout scenarios (30s auth, 10s Firestore)
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

      // Helper: upload a picked image to Cloudinary, returning the secure URL.
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
          // === FIRESTORE DATA STRUCTURE ===
          // Comprehensive user profile data saved to Users/{uid} collection
          // Uses SetOptions(merge: true) to preserve existing fields (email, role, uid, status)
          final data =
              <String, dynamic>{
                // --- CORE FIELDS (All Users) ---
                'fullName': _fullNameController.text.trim(), // Full legal name
                'address': _addressController.text
                    .trim(), // Residential address
                'birthdate': _birthDate != null
                    ? Timestamp.fromDate(_birthDate!)
                    : null, // Date of birth
                // Cloudinary image URLs (secure HTTPS links)
                if (profileUrl != null) 'profilePictureUrl': profileUrl,
                if (idUrl != null) 'idScreenshotUrl': idUrl,

                // --- ROLE IDENTIFIERS ---
                // Student ID or Teacher ID (mutually exclusive based on role)
                if (studentId != null && studentId.isNotEmpty)
                  'studentId': studentId,
                if (teacherId != null && teacherId.isNotEmpty)
                  'teacherId': teacherId,

                // --- STUDENT-SPECIFIC FIELDS ---
                if (_role == 'student')
                  'studentContactPhone': _studentPhoneController.text
                      .trim(), // Optional student phone
                if (_role == 'student')
                  'parentPhone': _parentPhoneController.text
                      .trim(), // Required parent/guardian phone
                if (_role == 'student')
                  'guardianName': _guardianNameController.text
                      .trim(), // Required guardian name
                if (_role == 'student')
                  'section': _sectionController.text
                      .trim(), // Academic section/class
                if (_role == 'student')
                  'adviserTeacherUid':
                      _selectedTeacherUid, // Assigned teacher UID
                if (_role == 'student')
                  'adviserTeacherName':
                      _selectedTeacherName, // Assigned teacher name
                // --- TEACHER-SPECIFIC FIELDS ---
                // Advisory section: which class/section the teacher advises (displayed in profile)
                if (_role == 'teacher')
                  'advisory': _teacherAdvisoryController.text.trim(),
                // Contact number: teacher's phone for school communication
                if (_role == 'teacher')
                  'contactNumber': _teacherPhoneController.text.trim(),

                // --- COMPLIANCE TRACKING ---
                'acceptedTerms': true, // Terms & conditions acceptance flag
                'acceptedTermsAt':
                    FieldValue.serverTimestamp(), // Acceptance timestamp
              }..removeWhere(
                (k, v) => v == null,
              ); // Remove null values to keep document clean

          // === DEBUG LOGGING ===
          // Console output for development/troubleshooting
          print('=== SAVING TO FIRESTORE ===');
          print('Profile URL: $profileUrl');
          print('ID URL: $idUrl');
          print('User ID: ${User.uid}');
          print('Data: $data');
          print('==========================');

          // === FIRESTORE WRITE OPERATION ===
          // Merge operation preserves existing fields from register_page.dart (email, uid, role, status)
          // and adds comprehensive profile data collected in this screen
          await FirebaseFirestore.instance
              .collection('Users')
              .doc(User.uid)
              .set(
                data,
                SetOptions(merge: true),
              ) // merge: true prevents overwriting existing data
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  throw TimeoutException('Firestore write timed out');
                },
              );

          print('✅ Data saved successfully to Firestore');

          // === UNIFIED REGISTRATION COMPLETE ===
          // User profile is now complete with all required information
          // Navigate to PendingVerificationScreen where user awaits admin approval
          // Admin will review profile picture, ID screenshot, and all submitted data
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

  // Show native date picker and store birth date.
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

  // Pick an image for profile or ID, validate size, and store in state.
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
            final nav = Navigator.of(context);
            await AuthService().signOut();
            if (!mounted) return;
            nav.pushAndRemoveUntil(
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
                      // === HEADER SECTION ===
                      const Text(
                        'Complete Profile',
                        style: TextStyle(fontFamily: 'NexaBold', fontSize: 26),
                      ),
                      const SizedBox(height: 12),
                      // Display current logged-in email (from Google or email/password)
                      Text(
                        'Signed in as ${User.email}',
                        style: const TextStyle(fontFamily: 'NexaRegular'),
                      ),
                      const SizedBox(height: 20),

                      // === ROLE SELECTOR (CONDITIONAL) ===
                      // Hidden if forcedRole is provided from register_page.dart
                      // This ensures Google Sign-In users cannot change their pre-selected role
                      // For legacy/incomplete users, role selector is shown
                      if (widget.forcedRole == null)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SegmentedButton<String>(
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
                              // Load teacher list when switching to student role
                              if (_role == 'student' && _teachers.isEmpty) {
                                await _loadTeachers();
                              }
                            },
                          ),
                        ),

                      // === ROLE-SPECIFIC FORM FIELDS ===
                      // Fields displayed only for student or teacher roles
                      if (_role == 'student' || _role == 'teacher') ...[
                        const SizedBox(height: 20),
                        // ID field: Student ID or Teacher ID (required)
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
                          // Advisory Section field for teachers
                          // This stores which class/section the teacher is advising (e.g., "Grade 10-A")
                          // Displayed in teacher profile and used for student-teacher association
                          TextFormField(
                            controller: _teacherAdvisoryController,
                            decoration: const InputDecoration(
                              labelText: 'Advisory Section',
                              hintText: 'e.g., Grade 10-A',
                              border: OutlineInputBorder(),
                            ),
                            // Validation: Advisory Section is required for all teachers
                            validator: (v) {
                              if (_role == 'teacher' &&
                                  (v == null || v.trim().isEmpty)) {
                                return 'Advisory Section required';
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
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Adviser / Teacher',
                              border: OutlineInputBorder(),
                            ),
                            items: _teachers.map((t) {
                              final advisory = t['advisory'];
                              final name = t['name'] ?? 'Teacher';
                              final subtitle =
                                  (advisory != null && advisory.isNotEmpty)
                                  ? ' - $advisory'
                                  : '';
                              return DropdownMenuItem<String>(
                                value: t['uid'],
                                child: Text('$name$subtitle'),
                              );
                            }).toList(),
                            initialValue: _selectedTeacherUid,
                            onChanged: (val) {
                              setState(() {
                                _selectedTeacherUid = val;
                                final match = _teachers.firstWhere(
                                  (e) => e['uid'] == val,
                                  orElse: () => {
                                    'uid': val ?? '',
                                    'name': '',
                                    'advisory': '',
                                  },
                                );
                                _selectedTeacherName = match['name'] ?? '';
                                final advisory = (match['advisory'] ?? '')
                                    .trim();
                                _selectedTeacherAdvisory = advisory.isEmpty
                                    ? null
                                    : advisory;
                                _sectionController.text = advisory;
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
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Section / Class',
                              border: OutlineInputBorder(),
                            ),
                            initialValue: _selectedTeacherAdvisory,
                            items:
                                (_selectedTeacherAdvisory != null &&
                                    _selectedTeacherAdvisory!.isNotEmpty)
                                ? [
                                    DropdownMenuItem<String>(
                                      value: _selectedTeacherAdvisory,
                                      child: Text(_selectedTeacherAdvisory!),
                                    ),
                                  ]
                                : <DropdownMenuItem<String>>[],
                            onChanged: (val) {
                              setState(() {
                                _selectedTeacherAdvisory = val;
                                _sectionController.text = val ?? '';
                              });
                            },
                            validator: (v) {
                              if (_role == 'student' &&
                                  (_selectedTeacherAdvisory == null ||
                                      _selectedTeacherAdvisory!
                                          .trim()
                                          .isEmpty)) {
                                return 'Section required (choose adviser with advisory)';
                              }
                              return null;
                            },
                            hint: const Text('Select adviser to load section'),
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
                                      final sectionValue = _sectionController
                                          .text
                                          .trim();
                                      if (sectionValue.isEmpty ||
                                          _selectedTeacherAdvisory == null ||
                                          _selectedTeacherAdvisory!
                                              .trim()
                                              .isEmpty) {
                                        setState(
                                          () => _error =
                                              'Section required (choose adviser with advisory)',
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
                                      // Validate Advisory Section before submission
                                      if (_teacherAdvisoryController.text
                                          .trim()
                                          .isEmpty) {
                                        setState(
                                          () => _error =
                                              'Advisory Section required',
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
