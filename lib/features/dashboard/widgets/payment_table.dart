import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class PaymentTable extends StatelessWidget {
  final List<Map<String, dynamic>> payments;

  const PaymentTable({super.key, required this.payments});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF6366F1), size: 20),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Finance Overview',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  'View all',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6366F1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
              4: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                children: [
                  _buildHeaderCell('Period'),
                  _buildHeaderCell('Opening'),
                  _buildHeaderCell('Collected'),
                  _buildHeaderCell('Spent'),
                  _buildHeaderCell('Balance'),
                ],
              ),
              ...payments.map((p) => TableRow(
                children: [
                  _buildCell(p['date'] ?? '', isGray: false),
                  _buildCell(p['opening'] ?? '0'),
                  _buildCell(p['collection'] ?? '0', isPositive: true),
                  _buildCell(p['expenses'] ?? '0', isNegative: true),
                  _buildCell(p['closing'] ?? '0', isBold: true),
                ],
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF94A3B8),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCell(String text, {bool isGray = true, bool isPositive = false, bool isNegative = false, bool isBold = false}) {
    Color textColor = const Color(0xFF1E293B);
    if (isGray && !isPositive && !isNegative) textColor = const Color(0xFF64748B);
    if (isPositive) textColor = const Color(0xFF10B981);
    if (isNegative) textColor = const Color(0xFFEF4444);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}
