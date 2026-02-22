import 'package:flutter/material.dart';
import '../../data/local/app_database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

class PaymentsPage extends StatefulWidget {
  final AppDatabase db;
  const PaymentsPage({super.key, required this.db});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

enum PaymentFilter { all, day, week, month, term }

class _PaymentsPageState extends State<PaymentsPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String? _selectedStudentId;
  String _selectedMethod = 'Cash';
  DateTime _selectedDate = DateTime.now();
  PaymentFilter _selectedFilter = PaymentFilter.all;

  List<Student> _students = [];
  List<Map<String, dynamic>> _paymentsWithNames = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  List<Map<String, dynamic>> get _filteredPayments {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    return _paymentsWithNames.where((item) {
      final payment = item['payment'] as FeePayment;
      final pDate = payment.paymentDate;

      switch (_selectedFilter) {
        case PaymentFilter.all:
          return true;
        case PaymentFilter.day:
          return pDate.year == today.year && pDate.month == today.month && pDate.day == today.day;
        case PaymentFilter.week:
          final weekStart = today.subtract(Duration(days: today.weekday - 1));
          return pDate.isAfter(weekStart.subtract(const Duration(seconds: 1)));
        case PaymentFilter.month:
          return pDate.year == today.year && pDate.month == today.month;
        case PaymentFilter.term:
          // Term 1: Jan - Apr (1-4)
          // Term 2: May - Aug (5-8)
          // Term 3: Sep - Dec (9-12)
          final int currentTerm = ((today.month - 1) ~/ 4) + 1;
          final int paymentTerm = ((pDate.month - 1) ~/ 4) + 1;
          return pDate.year == today.year && paymentTerm == currentTerm;
      }
    }).toList();
  }

  Future<void> _loadData() async {
    // Load students for dropdown
    final students = await widget.db.select(widget.db.students).get();
    
    // Load payments joined with students
    final query = widget.db.select(widget.db.feePayments).join([
      drift.innerJoin(widget.db.students, widget.db.students.id.equalsExp(widget.db.feePayments.studentId))
    ]);
    
    final results = await query.get();
    
    final paymentsWithNames = results.map((row) {
      final payment = row.readTable(widget.db.feePayments);
      final student = row.readTable(widget.db.students);
      return {
        'payment': payment,
        'studentName': student.name,
      };
    }).toList();

    // Sort by date descending
    paymentsWithNames.sort((a, b) => 
      (b['payment'] as FeePayment).paymentDate.compareTo((a['payment'] as FeePayment).paymentDate));

    if (mounted) {
      setState(() {
        _students = students;
        _paymentsWithNames = paymentsWithNames;
        if (_students.isNotEmpty && _selectedStudentId == null) {
          _selectedStudentId = _students.first.id;
        }
      });
    }
  }

  Future<void> _recordPayment() async {
    if (!_formKey.currentState!.validate() || _selectedStudentId == null) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a student and enter amount')),
      );
      return;
    }

    final uuid = const Uuid();
    final student = _students.firstWhere((s) => s.id == _selectedStudentId);

    try {
      await widget.db.into(widget.db.feePayments).insert(
        FeePaymentsCompanion.insert(
          id: uuid.v4(),
          schoolId: student.schoolId,
          studentId: student.id,
          amount: double.parse(_amountController.text),
          paymentDate: _selectedDate,
          paymentMethod: drift.Value(_selectedMethod),
          syncStatus: const drift.Value('PENDING'),
        )
      );

      _amountController.clear();
      if (mounted) {
        Navigator.pop(context, true);
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment recorded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error recording payment: $e')),
        );
      }
    }
  }

  void _showRecordPaymentDialog() {
    if (_students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students registered yet. Please register students first.')),
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
                      items: _students.map((s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(s.name),
                      )).toList(),
                      onChanged: (val) => setDialogState(() => _selectedStudentId = val),
                      validator: (val) => val == null ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(labelText: 'Amount (\$)'),
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Required';
                        if (double.tryParse(val) == null) return 'Invalid number';
                        return null;
                      },
                    ),
                    DropdownButtonFormField<String>(
                      value: _selectedMethod,
                      decoration: const InputDecoration(labelText: 'Method'),
                      items: ['Cash', 'Ecocash', 'Bank Transfer'].map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(m),
                      )).toList(),
                      onChanged: (val) => setDialogState(() => _selectedMethod = val!),
                    ),
                    ListTile(
                      title: Text('Date: ${_selectedDate.toLocal()}'.split(' ')[0]),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setDialogState(() => _selectedDate = picked);
                      },
                    ),
                  ],
                ),
              );
            }
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _recordPayment,
            child: const Text('Record'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredPayments;
    final total = filtered.fold<double>(0, (sum, item) => sum + (item['payment'] as FeePayment).amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fee Payments'),
        actions: [
          PopupMenuButton<PaymentFilter>(
            icon: const Icon(Icons.filter_list),
            onSelected: (filter) => setState(() => _selectedFilter = filter),
            itemBuilder: (context) => [
              const PopupMenuItem(value: PaymentFilter.all, child: Text('All Time')),
              const PopupMenuItem(value: PaymentFilter.day, child: Text('Today')),
              const PopupMenuItem(value: PaymentFilter.week, child: Text('This Week')),
              const PopupMenuItem(value: PaymentFilter.month, child: Text('This Month')),
              const PopupMenuItem(value: PaymentFilter.term, child: Text('This Term')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showRecordPaymentDialog,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filtering: ${_selectedFilter.name.toUpperCase()}',
                  style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Total: \$${total.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(child: Text('No payments found for this period.'))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final payment = item['payment'] as FeePayment;
                      final studentName = item['studentName'] as String;
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade100,
                          child: const Icon(Icons.attach_money, color: Colors.green),
                        ),
                        title: Text(studentName),
                        subtitle: Text('${payment.paymentMethod ?? 'Cash'} - ${payment.paymentDate.toString().split(' ')[0]}'),
                        trailing: Text(
                          '\$${payment.amount.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
