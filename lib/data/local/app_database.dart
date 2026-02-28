import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// Common structure for all syncable tables
mixin SyncableTable on Table {
  TextColumn get id => text()(); // UUID
  @JsonKey('school_id')
  TextColumn get schoolId => text()();
  @JsonKey('created_at')
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @JsonKey('updated_at')
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  @JsonKey('sync_status')
  TextColumn get syncStatus => text().withDefault(const Constant('PENDING'))(); // PENDING, SYNCED
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Teacher')
class Teachers extends Table with SyncableTable {
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get phone => text().nullable()();
}

@DataClassName('Student')
class Students extends Table with SyncableTable {
  TextColumn get name => text().withLength(min: 1, max: 100)();
  @JsonKey('date_of_birth')
  DateTimeColumn get dateOfBirth => dateTime()();
  @JsonKey('guardian_contact')
  TextColumn get guardianContact => text().nullable()();
  @JsonKey('class_id')
  TextColumn get classId => text().references(Classes, #id)();
  @JsonKey('user_id')
  TextColumn get userId => text().nullable()(); // Link to auth.users.id
  TextColumn get email => text().nullable()(); // Email for auto-linking
}

@DataClassName('SchoolClass')
class Classes extends Table with SyncableTable {
  TextColumn get name => text()();
  @JsonKey('teacher_id')
  TextColumn get teacherId => text().nullable().references(Teachers, #id)();
  @JsonKey('base_fee')
  RealColumn get baseFee => real().withDefault(const Constant(0.0))();
}

@DataClassName('Subject')
class Subjects extends Table with SyncableTable {
  TextColumn get name => text()();
  @JsonKey('class_id')
  TextColumn get classId => text().references(Classes, #id)();
}

@DataClassName('ExamMark')
class ExamMarks extends Table with SyncableTable {
  @JsonKey('student_id')
  TextColumn get studentId => text().references(Students, #id)();
  @JsonKey('subject_id')
  TextColumn get subjectId => text().references(Subjects, #id)();
  IntColumn get score => integer()();
  IntColumn get term => integer()();
}

@DataClassName('FeePayment')
class FeePayments extends Table with SyncableTable {
  @JsonKey('student_id')
  TextColumn get studentId => text().references(Students, #id)();
  RealColumn get amount => real()();
  @JsonKey('payment_date')
  DateTimeColumn get paymentDate => dateTime()();
  @JsonKey('payment_method')
  TextColumn get paymentMethod => text().nullable()();
  @JsonKey('receipt_number')
  TextColumn get receiptNumber => text().unique()(); // UNIQUE constraint
  @JsonKey('academic_year')
  TextColumn get academicYear => text()();
  IntColumn get term => integer()();
  @JsonKey('recorded_by')
  TextColumn get recordedBy => text()();
  TextColumn get status => text().withDefault(const Constant('SUCCESS'))(); // SUCCESS, VOIDED
  @JsonKey('void_reason')
  TextColumn get voidReason => text().nullable()();
  @JsonKey('voided_by')
  TextColumn get voidedBy => text().nullable()();
}

@DataClassName('Staff')
class Staffs extends Table with SyncableTable {
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get role => text()(); // e.g., Admin, Accountant, Security
  TextColumn get phone => text().nullable()();
}

@DataClassName('Notification')
class Notifications extends Table with SyncableTable {
  TextColumn get title => text()();
  TextColumn get message => text()();
  TextColumn get type => text()(); // e.g., FEE_REMINDER, GENERAL
  @JsonKey('is_read')
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  @JsonKey('student_id')
  TextColumn get studentId => text().nullable().references(Students, #id)();
}

@DriftDatabase(tables: [
  Teachers,
  Students,
  Classes,
  Subjects,
  ExamMarks,
  FeePayments,
  Staffs,
  Notifications,
])
class AppDatabase extends _$AppDatabase {
  final String userId;
  final String schoolId;
  
  AppDatabase(this.userId, this.schoolId, [QueryExecutor? e]) 
      : super(e ?? _openConnection(userId));

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onUpgrade: (m, from, to) async {
        if (from < 6) {
          await m.addColumn(feePayments, feePayments.receiptNumber);
        }
        if (from < 7) {
          // Migration to version 7
          await m.addColumn(classes, classes.baseFee);
          await m.addColumn(feePayments, feePayments.academicYear);
          await m.addColumn(feePayments, feePayments.term);
          await m.addColumn(feePayments, feePayments.recordedBy);
          await m.addColumn(feePayments, feePayments.status);
          await m.addColumn(feePayments, feePayments.voidReason);
          await m.addColumn(feePayments, feePayments.voidedBy);
          
          // Note: Making receipt_number unique might require data cleanup if duplicates exist,
          // but Drift handles the schema change. In a real production app with data, 
          // you'd need a more cautious approach if duplicates were possible.
        }
      },
    );
  }
}

LazyDatabase _openConnection(String userId) {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db_$userId.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
