import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../data/local/app_database.dart';
import '../../data/remote/supabase_service.dart';
import '../../data/sync/sync_service.dart';
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/modern_stat_card.dart';
import 'widgets/dashboard_section_cards.dart';
import 'widgets/placeholder_page.dart';
import '../notifications/notifications_page.dart';
import '../notifications/services/fee_reminder_service.dart';
import '../teachers/teachers_page.dart';
import '../fees/fees_summary_page.dart';
import '../fees/today_collections_page.dart';
import '../registration/registration_page.dart';
import '../students/students_page.dart';
import '../payments/payments_page.dart';

class ModernDashboardPage extends StatefulWidget {
  final String userId;
  final String schoolId;
  final String role;

  const ModernDashboardPage({
    super.key,
    required this.userId,
    required this.schoolId,
    required this.role,
  });

  @override
  State<ModernDashboardPage> createState() => _ModernDashboardPageState();
}

class _ModernDashboardPageState extends State<ModernDashboardPage> {
  AppDatabase? _db;
  bool _isInitializing = true;
  bool _isSyncing = false;
  String? _error;
  int _bottomNavIndex = 0;
  String _selectedClass = 'Class 9';
  
  int _teacherCount = 0;
  int _studentCount = 0;
  double _totalRevenue = 0;
  int _unreadNotifications = 0;
  FeeReminderService? _reminderService;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      
      if (user == null) {
        setState(() {
          _error = 'User session not found.';
          _isInitializing = false;
        });
        return;
      }

      String schoolId = user.userMetadata?['school_id'] as String? ?? '';
      final database = AppDatabase(widget.userId, schoolId);
      
      final teachers = await database.select(database.teachers).get();
      final students = await database.select(database.students).get();
      final feePayments = await database.select(database.feePayments).get();
      
      double revenue = 0;
      for (var p in feePayments) revenue += p.amount;

      final reminderService = FeeReminderService(database);
      
      // Listen to unread notifications
      reminderService.watchUnreadCount().listen((count) {
        if (mounted) setState(() => _unreadNotifications = count);
      });

      setState(() {
        _db = database;
        _teacherCount = teachers.length;
        _studentCount = students.length;
        _totalRevenue = revenue;
        _reminderService = reminderService;
        _isInitializing = false;
      });
      
      // Auto-sync on startup
      _handleSync();
    } catch (e) {
      setState(() {
        _error = 'Initialization error: $e';
        _isInitializing = false;
      });
    }
  }

  @override
  void dispose() {
    _db?.close();
    super.dispose();
  }

  void _navigateTo(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page)).then((_) {
      // Re-initialize data and potentially sync after returning
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (_db == null) return;
    final teachers = await _db!.select(_db!.teachers).get();
    final students = await _db!.select(_db!.students).get();
    final feePayments = await _db!.select(_db!.feePayments).get();
    
    double revenue = 0;
    for (var p in feePayments) revenue += p.amount;

    if (mounted) {
      setState(() {
        _teacherCount = teachers.length;
        _studentCount = students.length;
        _totalRevenue = revenue;
      });
    }
  }

  Future<void> _handleSync() async {
    if (_db == null || _isSyncing) return;
    setState(() => _isSyncing = true);
    
    try {
      final syncService = SyncService(
        db: _db!,
        supabase: SupabaseService(),
      );
      await syncService.syncAll();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync completed successfully'),
            backgroundColor: Color(0xFF488B80),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e. Your data is still safe locally.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _handleQuickAction(String action) async {
    if (_db == null) return;
    switch (action) {
      case 'Add Student':
        Navigator.push(context, MaterialPageRoute(builder: (context) => RegistrationPage(db: _db!))).then((success) {
          if (success == true) {
             _loadData();
             _handleSync(); 
          }
        });
        break;
      case '+ Add Teacher':
        Navigator.push(context, MaterialPageRoute(builder: (context) => TeachersPage(db: _db!))).then((_) {
          _loadData();
          _handleSync();
        });
        break;
      case 'Record Payment':
        Navigator.push(context, MaterialPageRoute(builder: (context) => PaymentsPage(db: _db!))).then((_) {
          _loadData();
          _handleSync();
        });
        break;
      case 'Generate Invoice':
        _navigateTo(const PlaceholderPage(title: 'Invoice Generation'));
        break;
      case 'Send Fee Reminder':
        if (_reminderService != null) {
          final count = await _reminderService!.generateReminders();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Generated $count fee reminders for defaulters.')),
            );
            _handleSync(); // Sync notifications
          }
        }
        break;
      case 'Send Announcement':
        _navigateTo(const PlaceholderPage(title: 'Announcements'));
        break;
    }
  }

  void _handleBottomNav(int index) {
    if (_db == null) return;
    setState(() => _bottomNavIndex = index);
    switch (index) {
      case 0: break; // Home
      case 1: _navigateTo(StudentsPage(db: _db!)); break;
      case 2: _navigateTo(PaymentsPage(db: _db!)); break;
      case 3: _navigateTo(const PlaceholderPage(title: 'Settings')); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) return Scaffold(body: Center(child: Text(_error!)));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      bottomNavigationBar: _buildBottomNav(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            DashboardHeader(
              schoolName: "St Mary's High School",
              academicYear: "2026",
              term: "Term 1",
              unreadCount: _unreadNotifications,
              isSyncing: _isSyncing,
              onSyncTap: _handleSync,
              onNotificationTap: () {
                if (_db != null) _navigateTo(NotificationsPage(db: _db!));
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  _buildMainActions(),
                  const SizedBox(height: 24),
                  _buildStatCardsGrid(),
                  const SizedBox(height: 24),
                  QuickActionsGrid(onActionTap: _handleQuickAction),
                  const SizedBox(height: 24),
                  StudentOverviewCard(
                    total: _studentCount > 0 ? _studentCount : 1240,
                    boys: 580,
                    girls: 660,
                    defaulters: 18,
                    currentClass: _selectedClass,
                    onClassTap: () {
                      // Simple class toggle for demo
                      setState(() => _selectedClass = _selectedClass == 'Class 9' ? 'Grade 1' : 'Class 9');
                    },
                    onViewClassList: () {
                       if (_db != null) _navigateTo(StudentsPage(db: _db!));
                    },
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainActions() {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: 'Add Student',
            icon: Icons.add_rounded,
            color: const Color(0xFF488B80),
            onTap: () {
              if (_db != null) _navigateTo(RegistrationPage(db: _db!));
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _ActionButton(
            label: 'Record Payment',
            icon: Icons.add_rounded,
            color: const Color(0xFF5B7DB1),
            onTap: () {
              if (_db != null) _navigateTo(PaymentsPage(db: _db!));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatCardsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 0.9,
      children: [
        ModernStatCard(
          title: 'Students',
          value: NumberFormat('#,##0').format(_studentCount > 0 ? _studentCount : 1240),
          icon: Icons.people_alt_rounded,
          iconColor: const Color(0xFF488B80),
          trend: '+12 this month',
          onTap: () => _db != null ? _navigateTo(StudentsPage(db: _db!)) : null,
        ),
        ModernStatCard(
          title: 'Teachers',
          value: _teacherCount > 0 ? _teacherCount.toString() : '45',
          icon: Icons.school_rounded,
          iconColor: const Color(0xFFE27396),
          trend: '+2 this month',
          onTap: () => _db != null ? _navigateTo(TeachersPage(db: _db!)) : null,
        ),
        ModernStatCard(
          title: 'Fees Summary',
          value: '\$${NumberFormat('#,##0').format(_totalRevenue > 0 ? _totalRevenue : 4320)}',
          icon: Icons.account_balance_wallet_rounded,
          iconColor: const Color(0xFF5B7DB1),
          subtext: r'$1,980',
          actionLabel: 'View Payments',
          onActionTap: () => _db != null ? _navigateTo(FeesSummaryPage(db: _db!)) : null,
          onTap: () => _db != null ? _navigateTo(FeesSummaryPage(db: _db!)) : null,
        ),
        ModernStatCard(
          title: "Today's Collections",
          value: r'$980',
          icon: Icons.payments_rounded,
          iconColor: const Color(0xFF488B80),
          actionLabel: 'View Payments',
          onActionTap: () => _db != null ? _navigateTo(TodayCollectionsPage(db: _db!)) : null,
          onTap: () => _db != null ? _navigateTo(TodayCollectionsPage(db: _db!)) : null,
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black.withOpacity(0.05))),
      ),
      child: BottomNavigationBar(
        currentIndex: _bottomNavIndex,
        onTap: _handleBottomNav,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF488B80),
        unselectedItemColor: const Color(0xFF94A3B8),
        selectedLabelStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500),
        elevation: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Students'),
          BottomNavigationBarItem(icon: Icon(Icons.monetization_on_rounded), label: 'Fees'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
