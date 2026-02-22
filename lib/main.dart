import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'data/local/app_database.dart';
import 'data/remote/supabase_service.dart';
import 'data/sync/sync_service.dart';
import 'features/payments/payments_page.dart';
import 'features/students/students_page.dart';
import 'features/students/student_details_page.dart';
import 'features/auth/login_page.dart';
import 'features/dashboard/modern_dashboard_page.dart';
import 'core/utils/error_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Global Flutter Error Handling (replaces the "Red Screen of Death")
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return CustomErrorWidget(errorMessage: details.exceptionAsString());
  };

  try {
    // Initialize Supabase
    await Supabase.initialize(
      url: 'https://cnsvtkjfqlyhisviczop.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNuc3Z0a2pmcWx5aGlzdmljem9wIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA2Njg2OTUsImV4cCI6MjA4NjI0NDY5NX0.AfrR8rUhG2R5ETrLqNs2_C0uvS9uZL4hVeaAMv3ReBk',
    );
  } catch (e) {
    debugPrint('Supabase initialization failed: $e');
    // We catch this so the app doesn't crash on startup if there's no internet.
    // The app will still function in offline mode using the local SQLite DB.
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'School Management System',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: SupabaseService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session;
        if (session != null) {
          final schoolId = session.user.userMetadata?['school_id'] as String? ?? session.user.id;
          final role = session.user.userMetadata?['role'] as String? ?? 'admin';
          debugPrint('🔑 AuthGate: UserID=${session.user.id}, Role=$role, SchoolID=$schoolId');
          return ModernDashboardPage(
            userId: session.user.id,
            schoolId: schoolId,
            role: role,
          );
        } else {
          return const LoginPage();
        }
      },
    );
  }
}

class CustomErrorWidget extends StatelessWidget {
  final String errorMessage;
  const CustomErrorWidget({super.key, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 80),
                const SizedBox(height: 24),
                const Text(
                  'Something went wrong',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'The application encountered an unexpected error. This is often due to missing cloud configuration or a temporary glitch.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    // In a real app, this could restart the app or navigate to home
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  final String userId;
  final String schoolId;
  final String role;
  const DashboardPage({
    super.key, 
    required this.userId, 
    required this.schoolId,
    required this.role,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  AppDatabase? _db;
  bool _isSyncing = false;
  bool _isInitializing = true;
  String? _error;
  String? _currentRole;
  Student? _studentProfile;

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
          _error = 'User session not found. Please log in again.';
          _isInitializing = false;
        });
        return;
      }

      // 1. Verify/Repair Metadata (School ID & Role)
      String effectiveSchoolId = user.userMetadata?['school_id'] as String? ?? '';
      String effectiveRole = user.userMetadata?['role'] as String? ?? 'admin';
      bool needsUpdate = false;
      Map<String, dynamic> updatedData = Map.from(user.userMetadata ?? {});
      
      // Auto-Link Logic for Students
      if (effectiveRole == 'student' && effectiveSchoolId.isEmpty) {
        debugPrint('🔍 Student without School ID detected. Attempting Auto-Link via email: ${user.email}');
        try {
          final studentResponse = await client
              .from('students')
              .select('id, school_id')
              .eq('email', user.email as String)
              .maybeSingle();

          if (studentResponse != null) {
            effectiveSchoolId = studentResponse['school_id'] as String;
            updatedData['school_id'] = effectiveSchoolId;
            needsUpdate = true;
            debugPrint('✅ Auto-Link Found! School ID: $effectiveSchoolId');

            // Update the record in Supabase to link this userId
            await client
                .from('students')
                .update({'user_id': user.id})
                .eq('id', studentResponse['id']);
          } else {
            debugPrint('⚠️ No pre-registered student record found for ${user.email}.');
          }
        } catch (e) {
          debugPrint('❌ Auto-Link error: $e');
        }
      }

      if (effectiveSchoolId.isEmpty && effectiveRole == 'admin') {
        debugPrint('🛠️ School ID missing for Admin. Generating new ID...');
        effectiveSchoolId = const Uuid().v4();
        updatedData['school_id'] = effectiveSchoolId;
        needsUpdate = true;
      }

      if (effectiveRole.isEmpty) {
        effectiveRole = 'admin';
        updatedData['role'] = effectiveRole;
        needsUpdate = true;
      }

      if (needsUpdate) {
        await client.auth.updateUser(UserAttributes(data: updatedData));
        await client.auth.refreshSession();
        debugPrint('✅ Metadata updated: Role=$effectiveRole, School=$effectiveSchoolId');
      }

      // 2. Initialize Database
      final database = AppDatabase(widget.userId, effectiveSchoolId);
      Student? profile;
      
      if (effectiveRole == 'student') {
        profile = await (database.select(database.students)
              ..where((t) => t.userId.equals(widget.userId)))
            .getSingleOrNull();
      }

      setState(() {
        _currentRole = effectiveRole;
        _db = database;
        _studentProfile = profile;
        _isInitializing = false;
      });
    } catch (e) {
      debugPrint('❌ Initialization error: $e');
      setState(() {
        _error = 'Failed to initialize system: $e';
        _isInitializing = false;
      });
    }
  }

  @override
  void dispose() {
    _db?.close();
    super.dispose();
  }

  Future<void> _handleSync() async {
    if (_db == null) return;
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
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final friendlyMessage = ErrorHandler.getMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $friendlyMessage. Your data is still safe locally.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Verifying account setup...', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isInitializing = true;
                      _error = null;
                    });
                    _initialize();
                  },
                  child: const Text('Retry'),
                ),
                TextButton(
                  onPressed: () => SupabaseService().signOut(),
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isAdmin = _currentRole == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? 'Admin Dashboard' : 'Student Portal'),
        backgroundColor: isAdmin ? Colors.blue.shade700 : Colors.indigo.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _isSyncing ? null : _handleSync,
            icon: _isSyncing 
              ? const SizedBox(
                  width: 20, 
                  height: 20, 
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                )
              : const Icon(Icons.sync),
          ),
          IconButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('CANCEL'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('SIGN OUT', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await SupabaseService().signOut();
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: isAdmin 
          ? [
              _buildMenuCard(context, 'Students', Icons.person, Colors.orange),
              _buildMenuCard(context, 'Fees', Icons.payments, Colors.red),
            ]
          : [
              _buildMenuCard(context, 'My Results', Icons.grade, Colors.green),
              _buildMenuCard(context, 'Fee Balance', Icons.account_balance_wallet, Colors.teal),
              _buildMenuCard(context, 'My Profile', Icons.badge, Colors.purple),
            ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          if (_db == null) return;
          if (title == 'Students') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => StudentsPage(db: _db!)),
            );
          } else if (title == 'Fees') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PaymentsPage(db: _db!)),
            );
          } else if (title == 'My Profile' || title == 'Fee Balance' || title == 'My Results') {
            if (_studentProfile == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Student profile not found. Please contact Admin.')),
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StudentDetailsPage(
                  student: _studentProfile!,
                  db: _db!,
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Opening $title module...')),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
