import 'package:flutter/material.dart';
import '../../data/local/app_database.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../registration/registration_page.dart';
import '../payments/receipt_details_page.dart';

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
  double _currentBaseFee = 500;

  @override
  void initState() {
    super.initState();
    _currentStudent = widget.student;
    _currentClassName = widget.className;
    _loadClassFee();
  }

  Future<void> _loadClassFee() async {
    final schoolClass = await (widget.db.select(widget.db.classes)
          ..where((t) => t.id.equals(_currentStudent.classId)))
        .getSingleOrNull();

    if (!mounted) return;
    setState(() {
      _currentBaseFee = (schoolClass?.baseFee ?? 500).toDouble();
    });
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
      _currentBaseFee = (updatedClass?.baseFee ?? 500).toDouble();
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
        final successfulPayments = payments.where((p) => p.status != 'VOIDED').toList();
        final totalPaid = successfulPayments.fold<double>(0, (sum, p) => sum + p.amount);
        final outstanding = (_currentBaseFee - totalPaid) > 0
            ? (_currentBaseFee - totalPaid)
            : 0.0;
        final status = totalPaid <= 0
            ? 'Unpaid'
            : outstanding > 0
                ? 'Partial'
                : 'Paid';

        return _buildDetailCard(
          context,
          'Payment History',
          [
            _buildFinancialSummaryRow(
              totalFees: _currentBaseFee,
              totalPaid: totalPaid,
              outstanding: outstanding,
              status: status,
            ),
            const Divider(height: 24),
            if (payments.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text('Receipt No', style: TextStyle(fontWeight: FontWeight.w700))),
                    Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.w700))),
                    Expanded(flex: 2, child: Text('Method', style: TextStyle(fontWeight: FontWeight.w700))),
                    Expanded(flex: 2, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
                  ],
                ),
              ),
            if (payments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Text(
                    'No payments recorded yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...payments.map((p) {
                final receipt = p.receiptNumber;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: InkWell(
                          onTap: () async {
                            final changed = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReceiptDetailsPage(
                                  db: widget.db,
                                  payment: p,
                                  studentName: _currentStudent.name,
                                  className: _currentClassName ?? 'No Class',
                                ),
                              ),
                            );
                            if (changed == true) {
                              _refreshStudent();
                            }
                          },
                          child: Text(
                            receipt,
                            style: const TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(DateFormat('dd MMM').format(p.paymentDate)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(p.paymentMethod ?? 'Cash'),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '\$${p.amount.toStringAsFixed(2)}',
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _buildFinancialSummaryRow({
    required double totalFees,
    required double totalPaid,
    required double outstanding,
    required String status,
  }) {
    final warning = outstanding > 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warning ? Colors.orange.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total Fees: \$${totalFees.toStringAsFixed(2)}'),
          Text('Total Paid: \$${totalPaid.toStringAsFixed(2)}'),
          Text(
            'Outstanding: \$${outstanding.toStringAsFixed(2)}${warning ? '  ⚠️' : ''}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: warning ? Colors.orange.shade900 : Colors.green.shade900,
            ),
          ),
          Text('Status: $status'),
        ],
      ),
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
