import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:attendanceapp/services/auth_service.dart';
import 'package:attendanceapp/login_page.dart';
import 'package:attendanceapp/verification_screen.dart';
import 'package:attendanceapp/unified_event_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:attendanceapp/main.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  int _selectedIndex = 0;

  // --- 1. CORE COLOR PALETTE ---
  final Color colPurple = const Color(0xFF6C63FF);
  final Color colTeal = const Color(0xFF00BFA5);
  final Color colOrange = const Color(0xFFFF7675);
  final Color colBlue = const Color(0xFF0984E3);
  final Color colDark = const Color(0xFF2D3436);
  final Color colSuccess = const Color(0xFF28a745);

  // Statistics State
  int _totalUsers = 0;
  int _totalStudents = 0;
  int _totalTeachers = 0;
  int _totalEvents = 0;
  int _activeQrCodes = 0;
  int _pendingVerifications = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    if (_selectedIndex == 0) setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _db.collection('Users').count().get(),
        _db
            .collection('Users')
            .where('role', isEqualTo: 'student')
            .count()
            .get(),
        _db
            .collection('Users')
            .where('role', isEqualTo: 'teacher')
            .count()
            .get(),
        _db.collection('Events').count().get(),
        _db
            .collection('Users')
            .where('status', isEqualTo: 'pending')
            .count()
            .get(),
        _db.collectionGroup('activeTokens').count().get(),
      ]);

      if (mounted) {
        setState(() {
          _totalUsers = results[0].count ?? 0;
          _totalStudents = results[1].count ?? 0;
          _totalTeachers = results[2].count ?? 0;
          _totalEvents = results[3].count ?? 0;
          _pendingVerifications = results[4].count ?? 0;
          _activeQrCodes = results[5].count ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching stats: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0) {
      _fetchStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: _selectedIndex == 0
          ? _buildDashboard(context)
          : const UsersListView(),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          selectedItemColor: colSuccess,
          unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
          selectedLabelStyle: const TextStyle(
            fontFamily: 'NexaBold',
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'NexaRegular',
            fontSize: 12,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_alt_rounded),
              label: 'Users',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    String dateStr = DateFormat('MMMM d, yyyy').format(DateTime.now());

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: colSuccess));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;

        // --- RESPONSIVE LOGIC ---
        int crossAxisCount;
        double childAspectRatio;
        double sidePadding;

        if (screenWidth > 1100) {
          // PC
          crossAxisCount = 4;
          childAspectRatio = 1.4;
          sidePadding = 30.0;
        } else if (screenWidth > 600) {
          // Tablet
          crossAxisCount = 3;
          childAspectRatio = 1.2;
          sidePadding = 24.0;
        } else {
          // Mobile (Poco X7 Pro, etc.)
          crossAxisCount = 2;
          // TALLER ASPECT RATIO to prevent overflow
          childAspectRatio = 0.95;
          sidePadding = 16.0;
        }

        return RefreshIndicator(
          color: colSuccess,
          onRefresh: _fetchStats,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                floating: true,
                pinned: true,
                expandedHeight: 80.0,
                backgroundColor: colSuccess,
                elevation: 1,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: EdgeInsets.only(left: sidePadding, bottom: 16),
                  title: Text(
                    'Admin Dashboard',
                    style: TextStyle(
                      fontFamily: 'NexaBold',
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 22,
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(sidePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateStr.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'NexaBold',
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontFamily: 'NexaRegular',
                            fontSize: 24,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          children: [
                            TextSpan(text: 'Hello, '),
                            TextSpan(
                              text: 'Admin',
                              style: TextStyle(fontFamily: 'NexaBold'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: SizedBox(
                  height: 130,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(
                      horizontal: sidePadding,
                      vertical: 10,
                    ),
                    children: [
                      _QuickActionChip(
                        label: 'Verify\nAccounts',
                        icon: Icons.verified_user,
                        color: colTeal,
                        badgeCount: _pendingVerifications,
                        onTap: () => Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (_) => const VerificationScreen(
                                  onlyStudents: false, // Admin sees all users
                                  userRole: 'admin', // Admin has full control
                                ),
                              ),
                            )
                            .then((_) => _fetchStats()),
                      ),
                      const SizedBox(width: 12),
                      _QuickActionChip(
                        label: 'Manage\nEvents',
                        icon: Icons.event,
                        color: colPurple,
                        onTap: () => Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (_) => const UnifiedEventScreen(),
                              ),
                            )
                            .then((_) => _fetchStats()),
                      ),
                      const SizedBox(width: 12),
                      _QuickActionChip(
                        label: 'App\nSettings',
                        icon: Icons.settings,
                        color: colDark,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverPadding(
                padding: EdgeInsets.all(sidePadding),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: childAspectRatio,
                  ),
                  delegate: SliverChildListDelegate([
                    _TransparentStatCard(
                      title: 'Total Users',
                      count: _totalUsers,
                      icon: Icons.people_alt,
                      themeColor: colPurple,
                    ),
                    _TransparentStatCard(
                      title: 'Students',
                      count: _totalStudents,
                      icon: Icons.school,
                      themeColor: colBlue,
                    ),
                    _TransparentStatCard(
                      title: 'Teachers',
                      count: _totalTeachers,
                      icon: Icons.person_pin,
                      themeColor: colDark,
                    ),
                    _TransparentStatCard(
                      title: 'Total Events',
                      count: _totalEvents,
                      icon: Icons.event_available,
                      themeColor: colPurple,
                      onSeeAll: () => Navigator.of(context)
                          .push(
                            MaterialPageRoute(
                              builder: (_) => const UnifiedEventScreen(),
                            ),
                          )
                          .then((_) => _fetchStats()),
                    ),
                    _TransparentStatCard(
                      title: 'Pending',
                      count: _pendingVerifications,
                      icon: Icons.hourglass_top,
                      themeColor: colTeal,
                      isAlert: _pendingVerifications > 0,
                    ),
                    _TransparentStatCard(
                      title: 'Active QRs',
                      count: _activeQrCodes,
                      icon: Icons.qr_code_2,
                      themeColor: colBlue,
                    ),
                  ]),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        );
      },
    );
  }
}

// ... SettingsScreen and UsersListView remain unchanged ...
// Just ensure you include them when pasting the file.

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    const colSuccess = Color(0xFF28a745);
    final themeService = ThemeServiceProvider.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          'App Settings',
          style: TextStyle(
            fontFamily: 'NexaBold',
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        backgroundColor: colSuccess,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(title: 'ACCOUNT'),
                const SizedBox(height: 10),
                _SettingsGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.email_outlined,
                      color: Colors.blue,
                      title: 'Email',
                      subtitle:
                          fb.FirebaseAuth.instance.currentUser?.email ??
                          'Unknown',
                    ),
                    const Divider(height: 1),
                    _SettingsTile(
                      icon: Icons.security,
                      color: Colors.purple,
                      title: 'Role',
                      subtitle: 'Administrator',
                    ),
                    const Divider(height: 1),
                    _SettingsTile(
                      icon: Icons.lock_reset,
                      color: Colors.orange,
                      title: 'Change Password',
                      subtitle: 'Update your security credentials',
                      onTap: () {
                        _showChangePasswordDialog(context);
                      },
                      showArrow: true,
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                _SectionHeader(title: 'PREFERENCES'),
                const SizedBox(height: 10),
                _SettingsGroup(
                  children: [
                    SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_outlined,
                          color: Colors.indigo,
                        ),
                      ),
                      title: const Text(
                        'Notifications',
                        style: TextStyle(fontFamily: 'NexaBold', fontSize: 14),
                      ),
                      subtitle: Text(
                        'Receive alerts for pending users',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      value: _notificationsEnabled,
                      activeThumbColor: colSuccess,
                      onChanged: (val) {
                        setState(() {
                          _notificationsEnabled = val;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              val
                                  ? 'Notifications enabled'
                                  : 'Notifications disabled',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.dark_mode_outlined,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      title: const Text(
                        'Dark Mode',
                        style: TextStyle(fontFamily: 'NexaBold', fontSize: 14),
                      ),
                      value: isDarkMode,
                      activeThumbColor: colSuccess,
                      onChanged: (val) {
                        themeService.toggleTheme();
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                _SectionHeader(title: 'GENERAL'),
                const SizedBox(height: 10),
                _SettingsGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.help_outline,
                      color: Colors.teal,
                      title: 'Help & Support',
                      onTap: () {
                        _showHelpDialog(context);
                      },
                      showArrow: true,
                    ),
                    const Divider(height: 1),
                    _SettingsTile(
                      icon: Icons.info_outline,
                      color: Colors.blueGrey,
                      title: 'About App',
                      subtitle: 'Version 1.0.0',
                      onTap: () {
                        showAboutDialog(
                          context: context,
                          applicationName: 'Attendance System',
                          applicationVersion: '1.0.0',
                          children: [
                            const Text(
                              'Efficient attendance tracking for schools.',
                            ),
                          ],
                        );
                      },
                      showArrow: true,
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7675),
                      foregroundColor: Theme.of(context).colorScheme.onError,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.logout),
                    label: const Text(
                      'Sign Out',
                      style: TextStyle(fontFamily: 'NexaBold', fontSize: 16),
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Sign Out'),
                          content: const Text(
                            'Are you sure you want to sign out?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(
                                'Sign Out',
                                style: TextStyle(
                                  color: Theme.of(ctx).colorScheme.onError,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await AuthService().signOut(
                          themeService: ThemeServiceProvider.of(context),
                        );
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                            (route) => false,
                          );
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            'Change Password',
            style: TextStyle(fontFamily: 'NexaBold'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final currentPassword = currentPasswordController.text
                          .trim();
                      final newPassword = newPasswordController.text.trim();
                      final confirmPassword = confirmPasswordController.text
                          .trim();

                      if (currentPassword.isEmpty ||
                          newPassword.isEmpty ||
                          confirmPassword.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please fill in all fields'),
                          ),
                        );
                        return;
                      }

                      if (newPassword != confirmPassword) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('New passwords do not match'),
                          ),
                        );
                        return;
                      }

                      if (newPassword.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Password must be at least 6 characters',
                            ),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isLoading = true);

                      try {
                        final user = fb.FirebaseAuth.instance.currentUser;
                        if (user == null || user.email == null) {
                          throw Exception('User not found');
                        }

                        // Re-authenticate user with current password
                        final credential = fb.EmailAuthProvider.credential(
                          email: user.email!,
                          password: currentPassword,
                        );

                        await user.reauthenticateWithCredential(credential);

                        // Update password
                        await user.updatePassword(newPassword);

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password updated successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } on fb.FirebaseAuthException catch (e) {
                        setDialogState(() => isLoading = false);
                        String message = 'Failed to change password';
                        if (e.code == 'wrong-password') {
                          message = 'Current password is incorrect';
                        } else if (e.code == 'weak-password') {
                          message = 'New password is too weak';
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(message)));
                        }
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: ${e.toString()}')),
                          );
                        }
                      }
                    },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Help & Support',
          style: TextStyle(fontFamily: 'NexaBold'),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Need assistance? Here are some helpful resources:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildHelpItem(
                Icons.description_outlined,
                'User Guide',
                'Learn how to use the attendance system effectively',
              ),
              const SizedBox(height: 12),
              _buildHelpItem(
                Icons.contact_support_outlined,
                'Contact Support',
                'Email: support@attendance.app\nPhone: 09512297022',
              ),
              const SizedBox(height: 12),
              _buildHelpItem(
                Icons.bug_report_outlined,
                'Report a Bug',
                'Found an issue? Let us know so we can fix it',
              ),
              const SizedBox(height: 12),
              _buildHelpItem(
                Icons.feedback_outlined,
                'Send Feedback',
                'Share your suggestions for improvement',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF28a745)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontFamily: 'NexaBold', fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- USERS LIST VIEW ---
class UsersListView extends StatefulWidget {
  const UsersListView({super.key});

  @override
  State<UsersListView> createState() => _UsersListViewState();
}

class _UsersListViewState extends State<UsersListView> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Color colSuccess = const Color(0xFF28a745);

  Future<void> _showAddUserDialog() async {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String role = 'student';
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add User'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Gmail (Required)',
                  ),
                ),
                TextField(
                  controller: passCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Password (Required)',
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'student', child: Text('Student')),
                    DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                  ],
                  onChanged: (val) => setDialogState(() => role = val!),
                ),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 16.0),
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colSuccess,
                  foregroundColor: Theme.of(ctx).colorScheme.onPrimary,
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        final email = emailCtrl.text.trim();
                        final pass = passCtrl.text.trim();

                        if (email.isEmpty || pass.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please fill in both Email and Password.',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        if (!email.toLowerCase().endsWith('@gmail.com')) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Only @gmail.com accounts are allowed.',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        setDialogState(() => isLoading = true);

                        FirebaseApp? secondaryApp;
                        try {
                          try {
                            secondaryApp = Firebase.app('SecondaryApp');
                          } catch (e) {
                            secondaryApp = await Firebase.initializeApp(
                              name: 'SecondaryApp',
                              options: Firebase.app().options,
                            );
                          }

                          fb.UserCredential cred =
                              await fb.FirebaseAuth.instanceFor(
                                app: secondaryApp,
                              ).createUserWithEmailAndPassword(
                                email: email,
                                password: pass,
                              );

                          await _db.collection('Users').doc(cred.user!.uid).set(
                            {
                              'uid': cred.user!.uid,
                              'email': email,
                              'role': role,
                              'status': 'approved',
                              'createdAt': FieldValue.serverTimestamp(),
                              'providers': ['password'],
                            },
                          );

                          if (role == 'student') {
                            await _db.collection('Student').add({
                              'id': '',
                              'email': email,
                            });
                          } else if (role == 'teacher') {
                            await _db.collection('Teacher').add({
                              'id': '',
                              'email': email,
                            });
                          }

                          await secondaryApp.delete();

                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('User added successfully'),
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isLoading = false);
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                child: const Text('Add User'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showEditUserDialog(
    Map<String, dynamic> userData,
    String docId,
  ) async {
    String rawRole = (userData['role'] ?? 'student')
        .toString()
        .toLowerCase()
        .trim();
    String rawStatus = (userData['status'] ?? 'pending')
        .toString()
        .toLowerCase()
        .trim();

    if (rawRole == 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot edit Admin accounts.')),
      );
      return;
    }

    const allowedRoles = ['student', 'teacher', 'admin'];
    const allowedStatuses = ['pending', 'approved', 'rejected'];

    String role = allowedRoles.contains(rawRole) ? rawRole : 'student';
    String status = allowedStatuses.contains(rawStatus) ? rawStatus : 'pending';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "User: ${userData['email']}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: const [
                DropdownMenuItem(value: 'student', child: Text('Student')),
                DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
              ],
              onChanged: (val) => role = val!,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'approved', child: Text('Approved')),
                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
              ],
              onChanged: (val) => status = val!,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _db.collection('Users').doc(docId).update({
                'role': role,
                'status': status,
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('User updated')));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(String docId, String role) async {
    if (role.toLowerCase() == 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete Admin accounts.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text('Are you sure? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(ctx).colorScheme.onError),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _db.collection('Users').doc(docId).delete();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User deleted')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        toolbarHeight: 80.0,
        title: Text(
          'User Management',
          style: TextStyle(
            fontFamily: 'NexaBold',
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 22,
          ),
        ),
        backgroundColor: colSuccess,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddUserDialog,
        backgroundColor: colSuccess,
        child: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.collection('Users').orderBy('role').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return const Center(child: Text('Error loading users'));
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              final users = snapshot.data!.docs;
              if (users.isEmpty)
                return const Center(child: Text('No users found'));

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: users.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final user = users[index];
                  final data = user.data() as Map<String, dynamic>;
                  final email = data['email'] ?? 'No Email';
                  final role = (data['role'] ?? 'User').toString();
                  final status = data['status'] ?? 'unknown';

                  Color roleColor = Colors.grey;
                  if (role.toLowerCase() == 'admin') roleColor = colSuccess;
                  if (role.toLowerCase() == 'teacher')
                    roleColor = const Color(0xFF2D3436);
                  if (role.toLowerCase() == 'student')
                    roleColor = const Color(0xFF0984E3);

                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).shadowColor.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: roleColor.withOpacity(0.1),
                        child: Icon(
                          role.toLowerCase() == 'admin'
                              ? Icons.security
                              : role.toLowerCase() == 'teacher'
                              ? Icons.person_pin
                              : Icons.school,
                          color: roleColor,
                        ),
                      ),
                      title: Text(
                        email,
                        style: const TextStyle(
                          fontFamily: 'NexaBold',
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        'Role: ${role.toUpperCase()} | Status: $status',
                        style: TextStyle(
                          fontFamily: 'NexaRegular',
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit')
                            _showEditUserDialog(data, user.id);
                          if (value == 'delete') _deleteUser(user.id, role);
                        },
                        itemBuilder: (ctx) => [
                          if (role.toLowerCase() != 'admin') ...[
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 18),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ] else
                            const PopupMenuItem(
                              enabled: false,
                              child: Text('Admin (Protected)'),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: 'NexaBold',
        fontSize: 13,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool showArrow;

  const _SettingsTile({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.onTap,
    this.showArrow = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontFamily: 'NexaBold', fontSize: 14),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: showArrow
          ? Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )
          : null,
      onTap: onTap,
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int badgeCount;

  const _QuickActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 100,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 26),
                  const Spacer(),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'NexaBold',
                      fontSize: 12,
                      color: color,
                    ),
                  ),
                ],
              ),
              if (badgeCount > 0)
                Positioned(
                  top: -12,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 22,
                      minHeight: 22,
                    ),
                    child: Center(
                      child: Text(
                        badgeCount > 99 ? '99+' : badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransparentStatCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color themeColor;
  final bool isAlert;
  final VoidCallback? onSeeAll;

  const _TransparentStatCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.themeColor,
    this.isAlert = false,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // --- RESPONSIVE ADJUSTMENTS ---
    // 1. Padding inside card
    final double cardPadding = screenWidth < 400 ? 12.0 : 16.0;

    // 2. Font Size (Scales with width)
    final double countFontSize = screenWidth < 400 ? 24.0 : 28.0;

    return Container(
      decoration: BoxDecoration(
        color: themeColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: themeColor.withOpacity(0.2)),
      ),
      padding: EdgeInsets.all(cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: themeColor, size: 20),
              ),
              if (isAlert)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    "!",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          // Use FittedBox to prevent overflow if number is huge (e.g. 10000)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              count.toString(),
              style: TextStyle(
                fontFamily: 'NexaBold',
                fontSize: countFontSize,
                color: themeColor,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'NexaRegular',
                    fontSize: 14,
                    color: themeColor.withOpacity(0.8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onSeeAll != null)
                GestureDetector(
                  onTap: onSeeAll,
                  child: Icon(Icons.arrow_forward, size: 16, color: themeColor),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
