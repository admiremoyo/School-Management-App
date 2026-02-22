import 'package:flutter/material.dart';
import '../../data/local/app_database.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../registration/registration_page.dart';

class StudentDetailsPage extends StatefulWidget {
  final Student student;
  final String? className;
  final AppDatabase db;

  const StudentDetailsPage({
    super.key,
    required this.student,
    this.className,
    required this.db,
  });

  @override
  State<StudentDetailsPage> createState() => _StudentDetailsPageState();
}

class _StudentDetailsPageState extends State<StudentDetailsPage> {
  late Student _currentStudent;
  late String? _currentClassName;

  @override
  void initState() {
    super.initState();
    _currentStudent = widget.student;
    _currentClassName = widget.className;
  }

  Future<void> _refreshStudent() async {
    final updatedStudent = await (widget.db.select(widget.db.students)
          ..where((t) => t.id.equals(_currentStudent.id)))
        .getSingle();
    
    final updatedClass = await (widget.db.select(widget.db.classes)
          ..where((t) => t.id.equals(updatedStudent.classId)))
        .getSingleOrNull();

    setState(() {
      _currentStudent = updatedStudent;
      _currentClassName = updatedClass?.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.db.userId == widget.student.userId ? 'My Profile' : 'Student Details'),
        backgroundColor: widget.db.userId == widget.student.userId ? Colors.indigo.shade700 : Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (widget.db.userId != widget.student.userId)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RegistrationPage(
                    db: widget.db,
                    student: _currentStudent,
                    initialClassName: _currentClassName,
                  ),
                ),
              );
              if (result == true) {
                _refreshStudent();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              child: Icon(Icons.person, size: 50),
            ),
            const SizedBox(height: 16),
            Text(
              _currentStudent.name,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            if (_currentClassName != null) ...[
              const SizedBox(height: 8),
              Chip(
                label: Text(
                  _currentClassName!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.blue.shade100,
              ),
            ],
            const SizedBox(height: 24),
            _buildDetailCard(
              context,
              'Personal Information',
              [
                _buildDetailRow(
                    Icons.cake, 'Date of Birth', DateFormat.yMMMd().format(_currentStudent.dateOfBirth)),
                _buildDetailRow(
                    Icons.phone, 'Guardian Contact', _currentStudent.guardianContact ?? 'N/A'),
                _buildDetailRow(
                    Icons.sync, 'Sync Status', _currentStudent.syncStatus),
                _buildDetailRow(
                  Icons.access_time,
                  'Created At',
                  DateFormat.yMMMd().add_jm().format(_currentStudent.createdAt),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildPaymentHistory(),
            const SizedBox(height: 24),
            _buildExamMarks(),
          ],
        ),
      ),
    );
  }

  Widget _buildExamMarks() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: (widget.db.select(widget.db.examMarks).join([
        drift.leftOuterJoin(widget.db.subjects, widget.db.subjects.id.equalsExp(widget.db.examMarks.subjectId)),
      ])..where(widget.db.examMarks.studentId.equals(_currentStudent.id))
        ..orderBy([drift.OrderingTerm.desc(widget.db.examMarks.term)]))
      .watch().map((rows) => rows.map((row) => {
        'mark': row.readTable(widget.db.examMarks),
        'subject': row.readTableOrNull(widget.db.subjects),
      }).toList()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final items = snapshot.data ?? [];

        return _buildDetailCard(
          context,
          'Exam Marks',
          items.isEmpty
              ? [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(
                      child: Text(
                        'No marks recorded yet.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                ]
              : items.map((item) {
                  final mark = item['mark'] as ExamMark;
                  final subject = item['subject'] as Subject?;
                  return _buildDetailRow(
                    Icons.grade_outlined,
                    '${subject?.name ?? 'Unknown Subject'} - Term ${mark.term}',
                    '${mark.score}/100',
                  );
                }).toList(),
        );
      },
    );
  }

  Widget _buildPaymentHistory() {
    return StreamBuilder<List<FeePayment>>(
      stream: (widget.db.select(widget.db.feePayments)
            ..where((t) => t.studentId.equals(_currentStudent.id))
            ..orderBy([(t) => drift.OrderingTerm.desc(t.paymentDate)]))
          .watch(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final payments = snapshot.data ?? [];

        return _buildDetailCard(
          context,
          'Payment History',
          payments.isEmpty
              ? [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(
                      child: Text(
                        'No payments recorded yet.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                ]
              : payments.map((p) {
                  return _buildDetailRow(
                    Icons.payments_outlined,
                    DateFormat.yMMMd().format(p.paymentDate),
                    '\$${p.amount.toStringAsFixed(2)}',
                  );
                }).toList(),
        );
      },
    );
  }

  Widget _buildDetailCard(BuildContext context, String title, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
