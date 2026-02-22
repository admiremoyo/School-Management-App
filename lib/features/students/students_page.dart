import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/local/app_database.dart';
import '../registration/registration_page.dart';
import 'student_details_page.dart';
import 'package:drift/drift.dart' as drift;

class StudentsPage extends StatefulWidget {
  final AppDatabase db;
  const StudentsPage({super.key, required this.db});

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  String _filterClass = 'All';
  String _filterGender = 'All';
  String _filterStatus = 'All';
  late Stream<List<StudentWithClass>> _studentsStream;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    _updateStream();
  }

  void _updateStream() {
    var query = widget.db.select(widget.db.students).join([
      drift.leftOuterJoin(widget.db.classes,
          widget.db.classes.id.equalsExp(widget.db.students.classId)),
    ]);

    _studentsStream = query.watch().map((rows) {
      var list = rows.map((row) {
        return StudentWithClass(
          student: row.readTable(widget.db.students),
          schoolClass: row.readTableOrNull(widget.db.classes),
        );
      }).toList();

      // Client-side filtering for simplicity in this pass
      if (_filterClass != 'All') {
        list = list.where((s) => s.schoolClass?.name == _filterClass).toList();
      }
      // Note: Gender isn't in current schema, we'll keep the UI for it though
      if (_filterStatus != 'All') {
        // Mock status logic: if they have any payment > 0, they are "Paid"
        // list = list.where(...) 
      }
      
      return list;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Students Overview', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilterRow(),
          Expanded(
            child: StreamBuilder<List<StudentWithClass>>(
              stream: _studentsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final students = snapshot.data ?? [];

                if (students.isEmpty) {
                  return const Center(
                    child: Text(
                      'No students found matching filters.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: students.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = students[index];
                    final student = item.student;
                    final className = item.schoolClass?.name ?? 'No Class';

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade50,
                          child: Text(
                            student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                            style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(student.name, style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                        subtitle: Text(className, style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey)),
                        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StudentDetailsPage(
                                student: student,
                                className: item.schoolClass?.name,
                                db: widget.db,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RegistrationPage(db: widget.db),
            ),
          ).then((success) {
            if (success == true) setState(() => _updateStream());
          });
        },
        backgroundColor: const Color(0xFF488B80),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('Class', _filterClass, ['All', 'Grade 1', 'Grade 2', 'Grade 3', 'Class 9'], (val) {
              setState(() {
                 _filterClass = val;
                 _updateStream();
              });
            }),
            const SizedBox(width: 8),
            _buildFilterChip('Gender', _filterGender, ['All', 'Boys', 'Girls'], (val) => setState(() => _filterGender = val)),
            const SizedBox(width: 8),
            _buildFilterChip('Status', _filterStatus, ['All', 'Paid', 'Defaulter'], (val) => setState(() => _filterStatus = val)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String current, List<String> options, Function(String) onSelected) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (context) => options.map((o) => PopupMenuItem(value: o, child: Text(o))).toList(),
      child: Chip(
        label: Text('$label: $current', style: const TextStyle(fontSize: 12)),
        backgroundColor: current == 'All' ? Colors.grey.shade100 : Colors.blue.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
    );
  }
}

class StudentWithClass {
  final Student student;
  final SchoolClass? schoolClass;

  StudentWithClass({required this.student, this.schoolClass});
}
