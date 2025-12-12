import 'package:flutter/material.dart';
import 'package:attendanceapp/services/auth_service.dart';
import 'package:attendanceapp/login_page.dart';
import 'package:attendanceapp/model/user.dart';
import 'package:attendanceapp/verification_screen.dart';
import 'package:attendanceapp/unified_event_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:attendanceapp/main.dart';

class TeacherHome extends StatefulWidget {
  const TeacherHome({super.key});

  @override
  State<TeacherHome> createState() => _TeacherHomeState();
}

class _TeacherHomeState extends State<TeacherHome> {
  int _currentIndex = 0;
  final Color _primary = const Color.fromARGB(252, 47, 145, 42);
  String? _teacherName;
  bool _loadingName = true;
  List<Map<String, dynamic>> _attendanceRecords = [];
  bool _loadingAttendance = true;

  // Additional teacher profile fields
  String? _teacherAddress;
  String? _teacherContact;
  String? _teacherAdvisory;
  String? _teacherProfileUrl;
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadTeacherData();
  }

  /// Loads teacher profile data from Firestore Users collection.
  /// Fetches: fullName, address, contactNumber, and advisory/section.
  Future<void> _loadTeacherData() async {
    try {
      final userSnap = await FirebaseFirestore.instance
          .collection('Users')
          .doc(User.uid)
          .get();

      if (userSnap.exists) {
        final data = userSnap.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            // Fetch teacher's full name for dashboard greeting
            _teacherName = data['fullName']?.toString();
            // Fetch home address
            _teacherAddress = data['address']?.toString();
            // Fetch contact number
            _teacherContact = data['contactNumber']?.toString();
            // Fetch designated advisory or section
            _teacherAdvisory =
                (data['advisory'] ??
                        data['adviserTeacherAdvisory'] ??
                        data['teacherSection'] ??
                        data['section'])
                    ?.toString();
            // Fetch profile photo URL if available
            _teacherProfileUrl = data['profilePictureUrl']?.toString();
            _loadingName = false;
            _loadingProfile = false;
          });
          // Load attendance only after advisory is known so we can filter properly
          await _loadAttendanceRecords();
        }
      } else {
        if (mounted) {
          setState(() {
            _loadingName = false;
            _loadingProfile = false;
          });
        }
        await _loadAttendanceRecords();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingName = false);
      }
    }
  }

  /// Loads attendance records from Firestore.
  /// Queries the 'AttendanceRecords' collection and orders by date descending.
  /// Each record contains: studentName, date, status (Present/Late/Absent), and timestamp.
  Future<void> _loadAttendanceRecords() async {
    final advisoryValue = _teacherAdvisory?.trim() ?? '';
    final teacherUid = User.uid.trim();

    // Do nothing until we at least know advisory or teacher UID
    if (advisoryValue.isEmpty && teacherUid.isEmpty) {
      if (mounted) {
        setState(() {
          _attendanceRecords = [];
          _loadingAttendance = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _loadingAttendance = true);
    }

    try {
      final coll = FirebaseFirestore.instance.collection('AttendanceRecords');
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> records = [];

      // Primary queries based on advisory/section
      if (advisoryValue.isNotEmpty) {
        final advisorySnap = await coll
            .where('advisory', isEqualTo: advisoryValue)
            .get();
        records.addAll(advisorySnap.docs);

        final sectionSnap = await coll
            .where('section', isEqualTo: advisoryValue)
            .get();
        records.addAll(sectionSnap.docs);
      }

      // Fallback: any records tied to this teacher UID
      if (teacherUid.isNotEmpty) {
        final teacherSnap = await coll
            .where('adviserTeacherUid', isEqualTo: teacherUid)
            .get();
        records.addAll(teacherSnap.docs);
      }

      // Build roster of student IDs by advisory/section or adviser UID to query by studentId
      final rosterIdsString = <String>{};
      final rosterIdsInt = <int>{};
      final List<Future<QuerySnapshot<Map<String, dynamic>>>> rosterFutures =
          [];

      if (advisoryValue.isNotEmpty) {
        rosterFutures.add(
          FirebaseFirestore.instance
              .collection('Student')
              .where('section', isEqualTo: advisoryValue)
              .get(),
        );
        rosterFutures.add(
          FirebaseFirestore.instance
              .collection('Student')
              .where('advisory', isEqualTo: advisoryValue)
              .get(),
        );
      }

      if (teacherUid.isNotEmpty) {
        rosterFutures.add(
          FirebaseFirestore.instance
              .collection('Student')
              .where('adviserTeacherUid', isEqualTo: teacherUid)
              .get(),
        );
      }

      final rosterSnaps = await Future.wait(rosterFutures);
      for (final snap in rosterSnaps) {
        for (final doc in snap.docs) {
          final data = doc.data();
          final raw = (data['id'] ?? data['studentId'] ?? '').toString().trim();
          if (raw.isEmpty) {
            continue;
          }
          rosterIdsString.add(raw);
          final maybeInt = int.tryParse(raw);
          if (maybeInt != null) {
            rosterIdsInt.add(maybeInt);
          }
        }
      }

      // Query AttendanceRecords by studentId for both string and int representations
      const chunkSize = 10; // Firestore whereIn limit
      final idChunksString = rosterIdsString.toList();
      for (var i = 0; i < idChunksString.length; i += chunkSize) {
        final end = (i + chunkSize) > idChunksString.length
            ? idChunksString.length
            : i + chunkSize;
        final slice = idChunksString.sublist(i, end);
        if (slice.isEmpty) continue;
        final snap = await coll.where('studentId', whereIn: slice).get();
        records.addAll(snap.docs);
      }

      final idChunksInt = rosterIdsInt.toList();
      for (var i = 0; i < idChunksInt.length; i += chunkSize) {
        final end = (i + chunkSize) > idChunksInt.length
            ? idChunksInt.length
            : i + chunkSize;
        final slice = idChunksInt.sublist(i, end);
        if (slice.isEmpty) continue;
        final snap = await coll.where('studentId', whereIn: slice).get();
        records.addAll(snap.docs);
      }

      // If still empty, attempt broad fallbacks by advisory/section again
      if (records.isEmpty && advisoryValue.isNotEmpty) {
        final fallback = await coll
            .where('section', isEqualTo: advisoryValue)
            .get();
        records.addAll(fallback.docs);
      }
      if (records.isEmpty && teacherUid.isNotEmpty) {
        final fallback = await coll
            .where('adviserTeacherUid', isEqualTo: teacherUid)
            .get();
        records.addAll(fallback.docs);
      }

      // Debug logging
      print('=== TEACHER ATTENDANCE LOG DEBUG ===');
      print('Teacher UID: $teacherUid');
      print('Advisory: $advisoryValue');
      print('Roster IDs (string): ${rosterIdsString.length}');
      print('Roster IDs (int): ${rosterIdsInt.length}');
      print('Total records fetched: ${records.length}');
      if (records.isNotEmpty) {
        print('Sample record: ${records.first.data()}');
      } else {
        // If still empty, fetch ALL AttendanceRecords to see what exists
        print('No records found. Fetching ALL records for diagnosis...');
        final allRecords = await coll.limit(10).get();
        print(
          'Total records in AttendanceRecords collection: ${allRecords.size}',
        );
        if (allRecords.docs.isNotEmpty) {
          print(
            'Sample record from collection: ${allRecords.docs.first.data()}',
          );
          records.addAll(allRecords.docs);
        }
      }
      print('===================================');

      if (mounted) {
        setState(() {
          // Map Firestore documents to a list of attendance record maps
          // Each record carries student name, date, status, timestamp (if present), and advisory for UI
          final seen = <String>{};
          _attendanceRecords = records
              .where((doc) {
                final first = !seen.contains(doc.id);
                if (first) seen.add(doc.id);
                return first;
              })
              .map((doc) {
                final data = doc.data();
                return {
                  'id': doc.id,
                  'studentName': data['studentName'] ?? 'Unknown Student',
                  'date': data['date'], // Firestore Timestamp
                  'status': data['status'] ?? 'Absent',
                  'timestamp': data['timestamp'], // Can be null for Absent
                  'checkInTime': data['checkInTime'], // Check-in timestamp
                  'checkOutTime': data['checkOutTime'], // Check-out timestamp
                  'advisory': data['advisory'] ?? data['section'],
                };
              })
              .toList();

          // Sort client-side by date descending to avoid index issues
          _attendanceRecords.sort((a, b) {
            final ad = a['date'];
            final bd = b['date'];
            if (ad is Timestamp && bd is Timestamp) {
              return bd.compareTo(ad);
            }
            return 0;
          });
          _loadingAttendance = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingAttendance = false);
      }
    }
  }

  // --- RETAINED LOGIC: Logout Function ---
  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out', style: TextStyle(fontFamily: 'NexaBold')),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(fontFamily: 'NexaRegular'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'NexaBold',
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Sign Out',
              style: TextStyle(
                fontFamily: 'NexaBold',
                color: Theme.of(ctx).colorScheme.onError,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await AuthService().signOut(
        themeService: ThemeServiceProvider.of(context),
      );
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Defined screens for the bottom navigation
    final List<Widget> screens = [
      _buildDashboard(),
      _buildProfileView(),
      _buildSettingsView(),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _primary,
        centerTitle: true,
        title: Text(
          _currentIndex == 0
              ? 'Dashboard'
              : _currentIndex == 1
              ? 'My Profile'
              : 'Settings',
          style: TextStyle(
            fontFamily: 'NexaBold',
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 22,
          ),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Toggle Theme',
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () {
              ThemeServiceProvider.of(context).toggleTheme();
            },
          ),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: _primary,
          unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
          selectedLabelStyle: const TextStyle(fontFamily: 'NexaBold'),
          unselectedLabelStyle: const TextStyle(fontFamily: 'NexaRegular'),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: DASHBOARD ---
  Widget _buildDashboard() {
    // Using LayoutBuilder to make grid responsive (Web vs Mobile)
    return LayoutBuilder(
      builder: (context, constraints) {
        // If width > 600 (Web/Tablet), use 3 columns, else 2 columns
        int crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header Card
              Container(
                padding: const EdgeInsets.all(24),
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primary, _primary.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: TextStyle(
                        fontFamily: 'NexaRegular',
                        color: Theme.of(
                          context,
                        ).colorScheme.onPrimary.withOpacity(0.8),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _loadingName ? 'Teacher' : (_teacherName ?? 'Teacher'),
                      style: TextStyle(
                        fontFamily: 'NexaBold',
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 28,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.onPrimary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        User.email,
                        style: TextStyle(
                          fontFamily: 'NexaRegular',
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontFamily: 'NexaBold',
                  fontSize: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),

              // Action Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                // Adjust ratio slightly for Web to keep cards from getting huge
                childAspectRatio: constraints.maxWidth > 600 ? 1.5 : 1.1,
                children: [
                  // RETAINED LOGIC: Navigate to UnifiedEventScreen
                  _buildActionCard(
                    title: 'Manage',
                    icon: Icons.calendar_month_rounded,
                    color: Colors.blueAccent,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const UnifiedEventScreen(),
                        ),
                      );
                    },
                  ),
                  // RETAINED LOGIC: Navigate to VerificationScreen
                  _buildActionCard(
                    title: 'Verify',
                    icon: Icons.verified_user_rounded,
                    color: Colors.orangeAccent,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => VerificationScreen(
                            onlyStudents: true,
                            teacherAdvisory: _teacherAdvisory,
                            userRole: 'teacher',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 30),
              // Attendance Log Section
              buildAttendanceLogSection(),
            ],
          ),
        );
      },
    );
  }

  /// Builds the Attendance Log section with scrollable list of records.
  /// Displays student name, date (formatted as MM/DD/YYYY), status badge, and timestamp icon.
  /// Shows loading spinner while fetching data, and empty state when no records exist.
  /// This widget is reusable across teacher dashboard contexts.
  Widget buildAttendanceLogSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Text(
          'Attendance Log',
          style: TextStyle(
            fontFamily: 'NexaBold',
            fontSize: 20,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        // Attendance Records Container
        Container(
          constraints: const BoxConstraints(maxHeight: 400),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _loadingAttendance
              // Loading: show spinner while Firestore query runs
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                )
              // Empty state: no records match this teacher advisory
              : _attendanceRecords.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text(
                      'No attendance records yet',
                      style: TextStyle(
                        fontFamily: 'NexaRegular',
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              // Data: scrollable list of attendance rows
              : ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: _attendanceRecords.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final record = _attendanceRecords[index];
                    return _buildAttendanceRecordRow(record);
                  },
                ),
        ),
      ],
    );
  }

  /// Builds a single attendance record row.
  /// Left side: student name, formatted date, and status badge.
  /// Right side: green checkmark icon if timestamp exists (Present/Late).
  Widget _buildAttendanceRecordRow(Map<String, dynamic> record) {
    // Extract data from record
    final String studentName = record['studentName'];
    final dynamic dateField = record['date'];
    final String status = record['status'];
    final dynamic timestampField = record['timestamp'];
    final dynamic checkInTimeField = record['checkInTime'];
    final dynamic checkOutTimeField = record['checkOutTime'];

    // Convert Firestore Timestamp to DateTime and format as MM/DD/YYYY
    String formattedDate = 'N/A';
    if (dateField != null && dateField is Timestamp) {
      final DateTime dateTime = dateField.toDate();
      formattedDate =
          '${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')}/${dateTime.year}';
    }

    // Format check-in time
    String checkInTimeStr = 'N/A';
    if (checkInTimeField != null && checkInTimeField is Timestamp) {
      final DateTime checkInDateTime = checkInTimeField.toDate();
      checkInTimeStr = DateFormat('hh:mm a').format(checkInDateTime);
    }

    // Format check-out time
    String checkOutTimeStr = 'N/A';
    if (checkOutTimeField != null && checkOutTimeField is Timestamp) {
      final DateTime checkOutDateTime = checkOutTimeField.toDate();
      checkOutTimeStr = DateFormat('hh:mm a').format(checkOutDateTime);
    }

    // Determine if timestamp exists (Present or Late records have timestamps)
    final bool hasTimestamp = timestampField != null;

    // Choose status badge color based on status
    Color statusColor;
    switch (status) {
      case 'Present':
        statusColor = Colors.green;
        break;
      case 'Late':
        statusColor = Colors.orange;
        break;
      case 'Absent':
      default:
        statusColor = Colors.red;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Left Side: Student info and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Student Name
                Text(
                  studentName,
                  style: TextStyle(
                    fontFamily: 'NexaBold',
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                // Date
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontFamily: 'NexaRegular',
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                // Check-in and Check-out times
                Row(
                  children: [
                    Icon(
                      Icons.login,
                      size: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      checkInTimeStr,
                      style: TextStyle(
                        fontFamily: 'NexaRegular',
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.logout,
                      size: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      checkOutTimeStr,
                      style: TextStyle(
                        fontFamily: 'NexaRegular',
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontFamily: 'NexaBold',
                      fontSize: 11,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Right Side: Checkmark icon if timestamp exists
          if (hasTimestamp)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 24,
              ),
            ),
        ],
      ),
    );
  }

  // --- TAB 2: PROFILE ---
  /// Builds the teacher profile view displaying personal details.
  /// Shows: full name, email, role, teacher ID, contact number, address, and advisory section.
  /// All data is fetched from Firestore Users collection via _loadTeacherData().
  Widget _buildProfileView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _loadingProfile
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Profile Avatar
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _primary, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      // Show latest uploaded profile picture, fallback to app icon
                      backgroundImage:
                          (_teacherProfileUrl != null &&
                              _teacherProfileUrl!.trim().isNotEmpty)
                          ? NetworkImage(_teacherProfileUrl!.trim())
                                as ImageProvider
                          : const AssetImage('assets/icons/atan.png'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Profile Information Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Full Name - fetched from Firestore 'fullName' field
                          _buildProfileRow(
                            Icons.person,
                            'Full Name',
                            _teacherName ?? 'N/A',
                          ),
                          const Divider(height: 30),
                          // Email - from User model
                          _buildProfileRow(Icons.email, 'Email', User.email),
                          const Divider(height: 30),
                          // Role - from User model
                          _buildProfileRow(
                            Icons.badge,
                            'Role',
                            User.role.toUpperCase(),
                          ),
                          const Divider(height: 30),
                          // Teacher ID - from User model (studentId field)
                          _buildProfileRow(
                            Icons.numbers,
                            'Teacher ID',
                            User.studentId.isNotEmpty ? User.studentId : 'N/A',
                          ),
                          const Divider(height: 30),
                          // Contact Number - fetched from Firestore 'contactNumber' field
                          _buildProfileRow(
                            Icons.phone,
                            'Contact Number',
                            _teacherContact ?? 'N/A',
                          ),
                          const Divider(height: 30),
                          // Home Address - fetched from Firestore 'address' field
                          _buildProfileRow(
                            Icons.home,
                            'Home Address',
                            _teacherAddress ?? 'N/A',
                          ),
                          const Divider(height: 30),
                          // Advisory/Section - fetched from Firestore 'advisory' field
                          _buildProfileRow(
                            Icons.class_,
                            'Advisory Section',
                            _teacherAdvisory ?? 'Not Assigned',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // --- TAB 3: SETTINGS ---
  Widget _buildSettingsView() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSettingsTile(
          icon: Icons.notifications_none_rounded,
          title: 'Notifications',
          subtitle: 'Configure alert preferences',
          onTap: () {
            // Placeholder for future feature
          },
        ),
        _buildSettingsTile(
          icon: Icons.security_rounded,
          title: 'Privacy & Security',
          subtitle: 'Manage account security',
          onTap: () {
            // Placeholder for future feature
          },
        ),
        _buildSettingsTile(
          icon: Icons.help_outline_rounded,
          title: 'Help & Support',
          subtitle: 'FAQs and support contact',
          onTap: () {
            // Placeholder for future feature
          },
        ),
        const SizedBox(height: 20),
        // Logout Card
        Card(
          color: Colors.red[50],
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text(
              'Sign Out',
              style: TextStyle(fontFamily: 'NexaBold', color: Colors.redAccent),
            ),
            onTap: _handleLogout,
          ),
        ),
      ],
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            // Subtle gradient overlay
            gradient: LinearGradient(
              colors: [Colors.white, color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'NexaBold',
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
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
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'NexaBold',
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.grey[800]),
        ),
        title: Text(title, style: const TextStyle(fontFamily: 'NexaBold')),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontFamily: 'NexaRegular',
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: Colors.grey,
        ),
        onTap: onTap,
      ),
    );
  }
}
