import 'package:uuid/uuid.dart';
import '../../../data/local/app_database.dart';
import 'package:drift/drift.dart' as drift;

class FeeReminderService {
  final AppDatabase db;

  FeeReminderService(this.db);

  /// Scans all students and generates notifications for those with overdue fees.
  /// For this implementation, we assume a standard fee of $500 per term.
  Future<int> generateReminders() async {
    const double standardFee = 500.0;
    int remindersCreated = 0;

    // 1. Get all students
    final allStudents = await db.select(db.students).get();

    for (final student in allStudents) {
      // 2. Sum up their payments
      final payments = await (db.select(db.feePayments)
            ..where((t) => t.studentId.equals(student.id)))
          .get();
      
      double totalPaid = 0;
      for (var p in payments) {
        totalPaid += p.amount;
      }

      // 3. Check if they owe money
      if (totalPaid < standardFee) {
        double balance = standardFee - totalPaid;

        // 4. Create a notification if one doesn't already exist for this term (mocked logic)
        // In a real app, we might check the last reminder date to avoid spamming.
        
        await db.into(db.notifications).insert(
          NotificationsCompanion.insert(
            id: const Uuid().v4(),
            schoolId: db.schoolId,
            title: 'Fee Reminder: ${student.name}',
            message: 'Outstanding balance of \$${balance.toStringAsFixed(2)} for Term 1.',
            type: 'FEE_REMINDER',
            studentId: drift.Value(student.id),
          ),
        );
        remindersCreated++;
      }
    }

    return remindersCreated;
  }

  /// Returns the count of unread notifications.
  Stream<int> watchUnreadCount() {
    return (db.select(db.notifications)
          ..where((t) => t.isRead.equals(false)))
        .watch()
        .map((list) => list.length);
  }
}
