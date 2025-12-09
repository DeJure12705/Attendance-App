import 'package:flutter/material.dart';
import 'package:attendanceapp/services/auth_service.dart';
import 'package:attendanceapp/login_page.dart';
import 'package:attendanceapp/model/user.dart';
import 'package:attendanceapp/verification_screen.dart';
import 'package:attendanceapp/unified_event_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

<<<<<<< HEAD
=======
// Teacher dashboard home screen.
// Shows a personalized welcome, date/time, email, and quick actions
// like verifying accounts and managing events.
>>>>>>> main
class TeacherHome extends StatefulWidget {
  const TeacherHome({super.key});

  @override
  State<TeacherHome> createState() => _TeacherHomeState();
}

class _TeacherHomeState extends State<TeacherHome> {
<<<<<<< HEAD
  int _currentIndex = 0;
  final Color _primary = const Color.fromARGB(252, 47, 145, 42);

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
            child: const Text(
              'Cancel',
              style: TextStyle(fontFamily: 'NexaBold', color: Colors.grey),
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
            child: const Text(
              'Sign Out',
              style: TextStyle(fontFamily: 'NexaBold', color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await AuthService().signOut();
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
      backgroundColor: Colors.grey[100],
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
          style: const TextStyle(
            fontFamily: 'NexaBold',
            color: Colors.white,
            fontSize: 22,
          ),
        ),
        automaticallyImplyLeading: false, // Hides back button
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: _primary,
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(fontFamily: 'NexaBold'),
          unselectedLabelStyle: const TextStyle(fontFamily: 'NexaRegular'),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
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
                    const Text(
                      'Welcome back,',
                      style: TextStyle(
                        fontFamily: 'NexaRegular',
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Teacher',
                      style: TextStyle(
                        fontFamily: 'NexaBold',
                        color: Colors.white,
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
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        User.email,
                        style: const TextStyle(
                          fontFamily: 'NexaRegular',
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontFamily: 'NexaBold',
                  fontSize: 20,
                  color: Colors.black87,
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
                    title: 'Manage\nEvents',
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
                    title: 'Verify\nAccounts',
                    icon: Icons.verified_user_rounded,
                    color: Colors.orangeAccent,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const VerificationScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- TAB 2: PROFILE ---
  Widget _buildProfileView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _primary, width: 2),
              ),
              child: const CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white,
                backgroundImage: AssetImage('assets/icons/atan.png'),
              ),
=======
  // Holds teacher's display name fetched from Firestore `Users/{uid}`.
  String? _teacherName;
  // Whether the name is currently being loaded; controls header placeholder.
  bool _loadingName = true;

  @override
  void initState() {
    super.initState();
    _loadTeacherData();
  }

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
            _teacherName = data['fullName']?.toString();
            // Fetch teacher profile data on screen load.
            _loadingName = false;
          });
        }
      } else {
        if (mounted) {
          // Read the Firestore `Users` document for the current authenticated user.
          setState(() => _loadingName = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingName = false);
      }
    }
  }
  // Prefer fullName; fall back is handled in the UI.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          // No user doc; continue without a name.
          'Teacher Dashboard',
          style: TextStyle(fontFamily: 'NexaBold'),
        ),
        actions: [
          IconButton(
            // Swallow errors but stop loading to avoid spinner.
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sign Out'),
                    ),
                  ],
                  // Confirm with the user before signing out.
                ),
              );
              if (confirm == true) {
                await AuthService().signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
                  );
                }
              }
            },
          ),
          IconButton(
            tooltip: 'Manage Events',
            icon: const Icon(Icons.event),
            onPressed: () {
              Navigator.of(context).push(
                // Invalidate session and return to login.
                MaterialPageRoute(builder: (_) => const UnifiedEventScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header with welcome and date/time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Navigate to unified event management screen.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome',
                      style: TextStyle(
                        color: Colors.black54,
                        fontFamily: 'NexaRegular',
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _loadingName ? 'Teacher' : (_teacherName ?? 'Teacher'),
                      style: const TextStyle(
                        fontFamily: 'NexaBold',
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
                // Date & Time
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      DateFormat('dd MMM yyyy').format(DateTime.now()),
                      style: TextStyle(
                        fontFamily: 'NexaRegular',
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    StreamBuilder(
                      stream: Stream.periodic(const Duration(seconds: 1)),
                      builder: (context, snapshot) {
                        return Text(
                          DateFormat('hh:mm:ss a').format(DateTime.now()),
                          style: TextStyle(
                            fontFamily: 'NexaRegular',
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
            Text(
              // Rebuild every second to show current time.
              'Email: ${User.email}',
              style: const TextStyle(fontFamily: 'NexaRegular'),
>>>>>>> main
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildProfileRow(Icons.email, 'Email', User.email),
                    const Divider(height: 30),
                    _buildProfileRow(
                      Icons.badge,
                      'Role',
                      User.role.toUpperCase(),
                    ),
                    const Divider(height: 30),
                    _buildProfileRow(
                      Icons.numbers,
                      'Teacher ID',
                      User.studentId.isNotEmpty ? User.studentId : 'N/A',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    // Shortcut to verification workflow.
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
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'NexaBold',
                  fontSize: 16,
                  color: Colors.black87,
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
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'NexaBold',
                  fontSize: 16,
                  color: Colors.black87,
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
