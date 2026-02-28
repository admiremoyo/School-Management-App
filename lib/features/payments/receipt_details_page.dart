import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/local/app_database.dart';
import '../../data/services/payment_service.dart';

class ReceiptDetailsPage extends StatefulWidget {
  final AppDatabase db;
  final FeePayment payment;
  final String studentName;
  final String className;
  final bool canVoid;

  const ReceiptDetailsPage({
    super.key,
    required this.db,
    required this.payment,
    required this.studentName,
    required this.className,
    this.canVoid = true,
  });

  @override
  State<ReceiptDetailsPage> createState() => _ReceiptDetailsPageState();
}

class _ReceiptDetailsPageState extends State<ReceiptDetailsPage> {
  bool _isBusy = false;

  Future<Uint8List> _buildReceiptPdf() async {
    final doc = pw.Document();
    final amount = NumberFormat.currency(symbol: '\$', decimalDigits: 2)
        .format(widget.payment.amount);
    final paymentDate = DateFormat('dd MMM yyyy').format(widget.payment.paymentDate);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Payment Receipt',
                style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Receipt: ${widget.payment.receiptNumber}'),
              pw.Divider(height: 28),
              _pdfRow('Student', widget.studentName),
              _pdfRow('Class', widget.className),
              _pdfRow('Amount Paid', amount),
              _pdfRow('Payment Method', widget.payment.paymentMethod ?? 'Cash'),
              _pdfRow('Date', paymentDate),
              _pdfRow('Recorded By', widget.payment.recordedBy),
              _pdfRow('Term', 'Term ${widget.payment.term}'),
              _pdfRow('Academic Year', widget.payment.academicYear),
              _pdfRow('Status', widget.payment.status),
              if (widget.payment.status == 'VOIDED') ...[
                _pdfRow('Void Reason', widget.payment.voidReason ?? 'N/A'),
                _pdfRow('Voided By', widget.payment.voidedBy ?? 'N/A'),
              ],
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text('$label:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }

  Future<void> _printReceipt() async {
    final pdf = await _buildReceiptPdf();
    await Printing.layoutPdf(onLayout: (_) async => pdf);
  }

  Future<void> _downloadReceipt() async {
    final pdf = await _buildReceiptPdf();
    await Printing.sharePdf(
      bytes: pdf,
      filename: '${widget.payment.receiptNumber}.pdf',
    );
  }

  Future<void> _voidPayment() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Void Receipt'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Void reason',
            hintText: 'Provide an audit reason',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, reasonController.text.trim()),
            child: const Text('Void'),
          ),
        ],
      ),
    );

    if (!mounted || reason == null) return;
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Void reason is required.')),
      );
      return;
    }

    setState(() => _isBusy = true);
    try {
      await PaymentService(widget.db).voidPayment(
        paymentId: widget.payment.id,
        reason: reason,
        voidedBy: widget.db.userId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt marked as VOIDED.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to void payment: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = NumberFormat.currency(symbol: '\$', decimalDigits: 2)
        .format(widget.payment.amount);
    final dateText = DateFormat('dd MMM yyyy').format(widget.payment.paymentDate);

    return Scaffold(
      appBar: AppBar(title: Text('Receipt ${widget.payment.receiptNumber}')),
      body: AbsorbPointer(
        absorbing: _isBusy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Receipt: ${widget.payment.receiptNumber}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _detailRow('Student', widget.studentName),
                    _detailRow('Class', widget.className),
                    _detailRow('Amount Paid', amount),
                    _detailRow('Payment Method', widget.payment.paymentMethod ?? 'Cash'),
                    _detailRow('Date', dateText),
                    _detailRow('Recorded By', widget.payment.recordedBy),
                    _detailRow('Term', 'Term ${widget.payment.term}'),
                    _detailRow('Academic Year', widget.payment.academicYear),
                    _detailRow('Status', widget.payment.status),
                    if (widget.payment.status == 'VOIDED') ...[
                      _detailRow('Void Reason', widget.payment.voidReason ?? 'N/A'),
                      _detailRow('Voided By', widget.payment.voidedBy ?? 'N/A'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _printReceipt,
              icon: const Icon(Icons.print),
              label: const Text('Print Receipt'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _downloadReceipt,
              icon: const Icon(Icons.download),
              label: const Text('Download PDF'),
            ),
            if (widget.canVoid && widget.payment.status != 'VOIDED') ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _voidPayment,
                icon: const Icon(Icons.block),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                label: const Text('Void (Admin Only)'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
