import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import '../local/app_database.dart';
import 'receipt_service.dart';

class PaymentService {
  final AppDatabase db;
  final ReceiptService _receiptService;

  PaymentService(this.db) : _receiptService = ReceiptService(db);

  Future<FeePayment> recordPayment({
    required String studentId,
    required double amount,
    required DateTime paymentDate,
    required String paymentMethod,
    required String recordedBy,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Amount must be greater than zero.');
    }

    return db.transaction(() async {
      final student = await (db.select(db.students)
            ..where((t) => t.id.equals(studentId)))
          .getSingleOrNull();
      if (student == null) {
        throw StateError('Student not found.');
      }

      final receiptNumber = await _receiptService.generateReceiptNumberAtomic(
        paymentDate: paymentDate,
      );

      final now = DateTime.now();
      await db.into(db.feePayments).insert(
            FeePaymentsCompanion.insert(
              id: const Uuid().v4(),
              schoolId: student.schoolId,
              studentId: student.id,
              amount: amount,
              paymentDate: paymentDate,
              paymentMethod: drift.Value(paymentMethod),
              receiptNumber: receiptNumber,
              academicYear: _receiptService.academicYearFromDate(paymentDate),
              term: _receiptService.termFromDate(paymentDate),
              recordedBy: recordedBy,
              status: const drift.Value('SUCCESS'),
              syncStatus: const drift.Value('PENDING'),
              createdAt: drift.Value(now),
              updatedAt: drift.Value(now),
            ),
          );

      return (db.select(db.feePayments)
            ..where((t) => t.receiptNumber.equals(receiptNumber)))
          .getSingle();
    });
  }

  Future<void> voidPayment({
    required String paymentId,
    required String reason,
    required String voidedBy,
  }) async {
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw ArgumentError('Void reason is required.');
    }

    final updated = await (db.update(db.feePayments)
          ..where((t) => t.id.equals(paymentId) & t.status.equals('SUCCESS')))
        .write(
      FeePaymentsCompanion(
        status: const drift.Value('VOIDED'),
        deleted: const drift.Value(true),
        voidReason: drift.Value(trimmedReason),
        voidedBy: drift.Value(voidedBy),
        updatedAt: drift.Value(DateTime.now()),
        syncStatus: const drift.Value('PENDING'),
      ),
    );

    if (updated == 0) {
      throw StateError('Payment not found or already voided.');
    }
  }
}
