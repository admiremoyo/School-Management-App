import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../data/local/app_database.dart';

class TeachersPage extends StatefulWidget {
  final AppDatabase db;
  const TeachersPage({super.key, required this.db});

  @override
  State<TeachersPage> createState() => _TeachersPageState();
}

class _TeachersPageState extends State<TeachersPage> {
  late Stream<List<Teacher>> _teachersStream;

  @override
  void initState() {
    super.initState();
    _teachersStream = widget.db.select(widget.db.teachers).watch();
  }

  void _showAddTeacherDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Teacher', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone (Optional)', border: OutlineInputBorder()),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              await widget.db.into(widget.db.teachers).insert(
                TeachersCompanion.insert(
                  id: const Uuid().v4(),
                  schoolId: widget.db.schoolId,
                  name: nameController.text.trim(),
                  phone: drift.Value(phoneController.text.trim()),
                ),
              );
              if (mounted) Navigator.pop(context, true);
            },
            child: const Text('ADD'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Teachers', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTeacherDialog,
        backgroundColor: const Color(0xFF488B80),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<List<Teacher>>(
        stream: _teachersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final teachers = snapshot.data ?? [];
          if (teachers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No teachers found', style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: teachers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final teacher = teachers[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
                  ],
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFE27396).withOpacity(0.1),
                    child: Text(teacher.name[0], style: const TextStyle(color: Color(0xFFE27396), fontWeight: FontWeight.bold)),
                  ),
                  title: Text(teacher.name, style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                  subtitle: Text(teacher.phone ?? 'No phone added', style: GoogleFonts.outfit(fontSize: 13)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
