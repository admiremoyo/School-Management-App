import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../../data/local/app_database.dart';

class FeesSummaryPage extends StatefulWidget {
  final AppDatabase db;
  const FeesSummaryPage({super.key, required this.db});

  @override
  State<FeesSummaryPage> createState() => _FeesSummaryPageState();
}

class _FeesSummaryPageState extends State<FeesSummaryPage> {
  late Stream<List<Map<String, dynamic>>> _feesStream;

  @override
  void initState() {
    super.initState();
    _feesStream = widget.db.select(widget.db.feePayments).join([
      drift.innerJoin(widget.db.students, widget.db.students.id.equalsExp(widget.db.feePayments.studentId)),
    ]).watch().map((rows) {
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
        title: Text('Fees Summary', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _feesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final payments = snapshot.data ?? [];
          final total = payments.fold<double>(0, (sum, p) => sum + (p['payment'] as FeePayment).amount);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildSummaryCard('Total Collected', '\$${NumberFormat('#,##0').format(total)}', const Color(0xFF488B80)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildSummaryCard('Outstanding', '\$1,980', const Color(0xFFF97316))),
                          const SizedBox(width: 16),
                          Expanded(child: _buildSummaryCard('Defaulters', '18', const Color(0xFFEF4444))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Recent Payments',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = payments[index];
                      final payment = item['payment'] as FeePayment;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFF488B80).withOpacity(0.1),
                              child: const Icon(Icons.payments_rounded, color: Color(0xFF488B80), size: 18),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['studentName'], style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                                  Text(DateFormat('MMM dd, yyyy').format(payment.paymentDate), style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                            Text(
                              '\$${payment.amount.toStringAsFixed(2)}',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: payments.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
