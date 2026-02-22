import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../../data/local/app_database.dart';

class TodayCollectionsPage extends StatefulWidget {
  final AppDatabase db;
  const TodayCollectionsPage({super.key, required this.db});

  @override
  State<TodayCollectionsPage> createState() => _TodayCollectionsPageState();
}

class _TodayCollectionsPageState extends State<TodayCollectionsPage> {
  late Stream<List<Map<String, dynamic>>> _todayStream;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

    _todayStream = (widget.db.select(widget.db.feePayments).join([
      drift.innerJoin(widget.db.students, widget.db.students.id.equalsExp(widget.db.feePayments.studentId)),
    ])..where(widget.db.feePayments.paymentDate.isBetweenValues(startOfDay, endOfDay)))
    .watch().map((rows) {
      return rows.map((row) {
        final payment = row.readTable(widget.db.feePayments);
        final student = row.readTable(widget.db.students);
        return {
          'payment': payment,
          'studentName': student.name,
        };
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("Today's Collections", style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _todayStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final payments = snapshot.data ?? [];
          
          final Map<String, double> grouped = {};
          for (var p in payments) {
            final method = (p['payment'] as FeePayment).paymentMethod ?? 'Cash';
            grouped[method] = (grouped[method] ?? 0) + (p['payment'] as FeePayment).amount;
          }

          if (payments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payment_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No collections recorded today', style: GoogleFonts.outfit(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Methods Breakdown', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ...grouped.entries.map((e) => _buildMethodTile(e.key, e.value)).toList(),
              const SizedBox(height: 32),
              Text('Detailed Log', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ...payments.map((p) => _buildPaymentLogTile(p)).toList(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMethodTile(String method, double amount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF488B80).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.wallet_rounded, color: Color(0xFF488B80), size: 20),
              ),
              const SizedBox(width: 16),
              Text(method, style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            ],
          ),
          Text('\$${amount.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildPaymentLogTile(Map<String, dynamic> item) {
    final payment = item['payment'] as FeePayment;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.02)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['studentName'], style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                Text(payment.paymentMethod ?? 'Cash', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Text('\$${payment.amount.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: const Color(0xFF488B80))),
        ],
      ),
    );
  }
}
