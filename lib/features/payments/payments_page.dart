import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/local/app_database.dart';
import '../../data/services/payment_service.dart';
import '../payments/receipt_details_page.dart';

class PaymentsPage extends StatefulWidget {
  final AppDatabase db;
  const PaymentsPage({super.key, required this.db});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _searchController = TextEditingController();
  final DateFormat _shortDate = DateFormat('dd MMM');

  String? _selectedStudentId;
  String _selectedMethod = 'Cash';
  DateTime _selectedDate = DateTime.now();

  String _methodFilter = 'All';
  String _classFilter = 'All';
  DateTimeRange? _dateRange;

  List<Student> _students = [];
  List<SchoolClass> _classes = [];
  List<Map<String, dynamic>> _paymentsWithMeta = [];
  bool _loading = true;
  double _totalOutstanding = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final students = await widget.db.select(widget.db.students).get();
    final classes = await widget.db.select(widget.db.classes).get();

    final query = widget.db.select(widget.db.feePayments).join([
      drift.innerJoin(
        widget.db.students,
        widget.db.students.id.equalsExp(widget.db.feePayments.studentId),
      ),
      drift.leftOuterJoin(
        widget.db.classes,
        widget.db.classes.id.equalsExp(widget.db.students.classId),
      ),
    ]);

    final results = await query.get();
    final payments = results.map((row) {
      final payment = row.readTable(widget.db.feePayments);
      final student = row.readTable(widget.db.students);
      final schoolClass = row.readTableOrNull(widget.db.classes);
      return {
        'payment': payment,
        'studentName': student.name,
        'className': schoolClass?.name ?? 'No Class',
        'classId': schoolClass?.id,
      };
    }).toList();

    payments.sort(
      (a, b) => (b['payment'] as FeePayment)
          .paymentDate
          .compareTo((a['payment'] as FeePayment).paymentDate),
    );

    final classFeeMap = {for (final c in classes) c.id: c.baseFee};
    final paidByStudent = <String, double>{};
    for (final row in payments) {
      final p = row['payment'] as FeePayment;
      if (p.status != 'VOIDED') {
        paidByStudent[p.studentId] = (paidByStudent[p.studentId] ?? 0) + p.amount;
      }
    }

    double outstanding = 0;
    for (final s in students) {
      final baseFee = (classFeeMap[s.classId] ?? 500).toDouble();
      final paid = paidByStudent[s.id] ?? 0;
      final balance = baseFee - paid;
      if (balance > 0) {
        outstanding += balance;
      }
    }

    if (!mounted) return;
    setState(() {
      _students = students;
      _classes = classes;
      _paymentsWithMeta = payments;
      _totalOutstanding = outstanding;
      _loading = false;
      _selectedStudentId ??= students.isNotEmpty ? students.first.id : null;
    });
  }

  List<Map<String, dynamic>> get _filteredPayments {
    final term = _searchController.text.trim().toLowerCase();

    return _paymentsWithMeta.where((item) {
      final payment = item['payment'] as FeePayment;
      final className = (item['className'] as String).toLowerCase();
      final receipt = payment.receiptNumber.toLowerCase();

      if (term.isNotEmpty) {
        final studentName = (item['studentName'] as String).toLowerCase();
        final match =
            receipt.contains(term) || studentName.contains(term) || className.contains(term);
        if (!match) return false;
      }

      if (_methodFilter != 'All' &&
          (payment.paymentMethod ?? 'Cash').toLowerCase() != _methodFilter.toLowerCase()) {
        return false;
      }

      if (_classFilter != 'All' && (item['className'] as String) != _classFilter) {
        return false;
      }

      if (_dateRange != null) {
        final start = DateTime(
          _dateRange!.start.year,
          _dateRange!.start.month,
          _dateRange!.start.day,
        );
        final end = DateTime(
          _dateRange!.end.year,
          _dateRange!.end.month,
          _dateRange!.end.day,
          23,
          59,
          59,
        );
        if (payment.paymentDate.isBefore(start) || payment.paymentDate.isAfter(end)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  ({double amount, int count}) _rangeStats(DateTime start, DateTime end) {
    var amount = 0.0;
    var count = 0;
    for (final row in _paymentsWithMeta) {
      final payment = row['payment'] as FeePayment;
      if (payment.status == 'VOIDED') continue;
      if (!payment.paymentDate.isBefore(start) && !payment.paymentDate.isAfter(end)) {
        amount += payment.amount;
        count += 1;
      }
    }
    return (amount: amount, count: count);
  }

  Future<void> _recordPayment() async {
    if (!_formKey.currentState!.validate() || _selectedStudentId == null) return;

    try {
      final created = await PaymentService(widget.db).recordPayment(
        studentId: _selectedStudentId!,
        amount: double.parse(_amountController.text),
        paymentDate: _selectedDate,
        paymentMethod: _selectedMethod,
        recordedBy: widget.db.userId,
      );

      if (!mounted) return;
      Navigator.pop(context);
      _amountController.clear();
      _selectedDate = DateTime.now();

      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment recorded. Receipt: ${created.receiptNumber}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error recording payment: $e')),
      );
    }
  }

  void _showRecordPaymentDialog() {
    if (_students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students registered yet.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Fee Payment'),
        content: Form(
          key: _formKey,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedStudentId,
                      decoration: const InputDecoration(labelText: 'Student'),
                      items: _students
                          .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                          .toList(),
                      onChanged: (value) => setDialogState(() => _selectedStudentId = value),
                      validator: (value) => value == null ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(labelText: 'Amount (\$)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Required';
                        final amount = double.tryParse(value);
                        if (amount == null || amount <= 0) return 'Enter a valid amount';
                        return null;
                      },
                    ),
                    DropdownButtonFormField<String>(
                      value: _selectedMethod,
                      decoration: const InputDecoration(labelText: 'Payment Method'),
                      items: const ['Cash', 'EcoCash', 'Bank']
                          .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (value) => setDialogState(() => _selectedMethod = value ?? 'Cash'),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Payment Date: ${DateFormat.yMMMd().format(_selectedDate)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => _selectedDate = picked);
                        }
                      },
                    ),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Receipt number will be generated automatically.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(onPressed: _recordPayment, child: const Text('Record')),
        ],
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    final today = _rangeStats(todayStart, todayEnd);
    final week = _rangeStats(weekStart, todayEnd);
    final month = _rangeStats(monthStart, todayEnd);
    final filtered = _filteredPayments;

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Payments')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showRecordPaymentDialog,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _metricCard(
                        title: 'Today',
                        value:
                            '\$${today.amount.toStringAsFixed(2)} (${today.count} receipts)',
                        color: const Color(0xFF0F766E),
                      ),
                      _metricCard(
                        title: 'This Week',
                        value:
                            '\$${week.amount.toStringAsFixed(2)} (${week.count} receipts)',
                        color: const Color(0xFF1D4ED8),
                      ),
                      _metricCard(
                        title: 'This Month',
                        value:
                            '\$${month.amount.toStringAsFixed(2)} (${month.count} receipts)',
                        color: const Color(0xFFB45309),
                      ),
                      _metricCard(
                        title: 'Total Outstanding',
                        value: '\$${_totalOutstanding.toStringAsFixed(2)}',
                        color: const Color(0xFFB91C1C),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              labelText: 'Search receipt number / student / class',
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _methodFilter,
                                  decoration: const InputDecoration(labelText: 'Method'),
                                  items: const ['All', 'Cash', 'EcoCash', 'Bank']
                                      .map(
                                        (m) => DropdownMenuItem(
                                          value: m,
                                          child: Text(m),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) =>
                                      setState(() => _methodFilter = value ?? 'All'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _classFilter,
                                  decoration: const InputDecoration(labelText: 'Class'),
                                  items: [
                                    const DropdownMenuItem(value: 'All', child: Text('All')),
                                    ..._classes.map(
                                      (c) => DropdownMenuItem(value: c.name, child: Text(c.name)),
                                    ),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => _classFilter = value ?? 'All'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _pickDateRange,
                                  icon: const Icon(Icons.date_range),
                                  label: Text(
                                    _dateRange == null
                                        ? 'Filter by Date Range'
                                        : '${_shortDate.format(_dateRange!.start)} - ${_shortDate.format(_dateRange!.end)}',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _methodFilter = 'All';
                                    _classFilter = 'All';
                                    _dateRange = null;
                                    _searchController.clear();
                                  });
                                },
                                child: const Text('Reset'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Payment History (${filtered.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (filtered.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No payments found for selected filters.'),
                      ),
                    )
                  else
                    Card(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Receipt No')),
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Method')),
                            DataColumn(label: Text('Class')),
                            DataColumn(label: Text('Student')),
                            DataColumn(label: Text('Amount')),
                            DataColumn(label: Text('Status')),
                          ],
                          rows: filtered.map((item) {
                            final payment = item['payment'] as FeePayment;
                            final studentName = item['studentName'] as String;
                            final className = item['className'] as String;
                            final receiptNo = payment.receiptNumber;

                            return DataRow(
                              cells: [
                                DataCell(
                                  InkWell(
                                    onTap: () async {
                                      final changed = await Navigator.push<bool>(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ReceiptDetailsPage(
                                            db: widget.db,
                                            payment: payment,
                                            studentName: studentName,
                                            className: className,
                                            canVoid: true,
                                          ),
                                        ),
                                      );
                                      if (changed == true) {
                                        _loadData();
                                      }
                                    },
                                    child: Text(
                                      receiptNo,
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(Text(DateFormat.yMMMd().format(payment.paymentDate))),
                                DataCell(Text(payment.paymentMethod ?? 'Cash')),
                                DataCell(Text(className)),
                                DataCell(Text(studentName)),
                                DataCell(Text('\$${payment.amount.toStringAsFixed(2)}')),
                                DataCell(
                                  Text(
                                    payment.status,
                                    style: TextStyle(
                                      color: payment.status == 'VOIDED'
                                          ? Colors.red
                                          : Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      width: 230,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
