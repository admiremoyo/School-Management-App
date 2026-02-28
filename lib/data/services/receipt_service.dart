import '../local/app_database.dart';
import 'package:drift/drift.dart';

class ReceiptService {
  final AppDatabase db;
  static const _maxRetryAttempts = 5;

  ReceiptService(this.db);

  String academicYearFromDate(DateTime date) => date.year.toString();

  int termFromDate(DateTime date) {
    if (date.month <= 4) return 1;
    if (date.month <= 8) return 2;
    return 3;
  }

  /// Generates receipt numbers in format: RCPT-YYYY-XXXXXX
  /// Example: RCPT-2026-000123
  Future<String> generateReceiptNumberAtomic({
    required DateTime paymentDate,
  }) async {
    final year = paymentDate.year.toString();
    final prefix = 'RCPT-$year-';

    // Transaction keeps read + candidate generation consistent within this connection.
    return db.transaction(() async {
      for (var attempt = 0; attempt < _maxRetryAttempts; attempt++) {
        final row = await db.customSelect(
          '''
          SELECT receipt_number
          FROM fee_payments
          WHERE receipt_number LIKE ?
          ORDER BY receipt_number DESC
          LIMIT 1
          ''',
          variables: [Variable<String>('$prefix%')],
          readsFrom: {db.feePayments},
        ).getSingleOrNull();

        final latest = row?.data['receipt_number'] as String?;
        final latestSequence = _parseSequence(latest);
        final nextSequence = latestSequence + 1 + attempt;
        final candidate = '$prefix${nextSequence.toString().padLeft(6, '0')}';

        final exists = await (db.select(db.feePayments)
              ..where((t) => t.receiptNumber.equals(candidate)))
            .getSingleOrNull();
        if (exists == null) {
          return candidate;
        }
      }

      throw StateError(
        'Unable to generate a unique receipt number after $_maxRetryAttempts attempts.',
      );
    });
  }

  int _parseSequence(String? receiptNumber) {
    if (receiptNumber == null || receiptNumber.isEmpty) {
      return 0;
    }

    final parts = receiptNumber.split('-');
    if (parts.isEmpty) {
      return 0;
    }

    return int.tryParse(parts.last) ?? 0;
  }
}
