import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift; // Helper for Value
import 'package:school_management/features/payments/payments_page.dart';
import 'package:school_management/data/local/app_database.dart';
import 'package:uuid/uuid.dart';

void main() {
  testWidgets('Payments Page Record Payment Test', (WidgetTester tester) async {
    // 1. Setup in-memory database
    final db = AppDatabase('test_user_', 'test_school_', NativeDatabase.memory());

    // 2. Add a mock student to the database
    const uuid = Uuid();
    final schoolId = uuid.v4();
    final studentId = uuid.v4();
    final classId = uuid.v4();
    
    // Create class
    await db.into(db.classes).insert(
      ClassesCompanion.insert(
        id: classId,
        schoolId: schoolId,
        name: 'Test Class',
        teacherId: drift.Value(uuid.v4()),
      )
    );

    // Create student
    await db.into(db.students).insert(
        StudentsCompanion.insert(
          id: studentId,
          schoolId: schoolId,
          name: 'John Doe',
          dateOfBirth: DateTime(2010),
          classId: classId,
        )
      );

    // 3. Pump the widget
    await tester.pumpWidget(MaterialApp(
      home: PaymentsPage(db: db),
    ));
    await tester.pumpAndSettle(); // Wait for _loadData

    // 4. Verify empty state
    expect(find.text('No payments found for selected filters.'), findsOneWidget);

    // 5. Tap add button
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // 6. Verify Dialog
    expect(find.text('Record Fee Payment'), findsOneWidget);

    // 7. Verify Student is selected (John Doe)
    // The DropdownButtonFormField shows the selected item's child.
    expect(find.text('John Doe'), findsOneWidget);

    // 8. Enter Amount
    // There is a TextFormField with label 'Amount ($)'
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount (\$)'), '50');
    await tester.pumpAndSettle();

    // 9. Record
    await tester.tap(find.text('Record'));
    await tester.pumpAndSettle();

    // 10. Verify payment in list
    // Should verify 'John Doe' is visible in the list (title)
    // And '$50.00' is visible (trailing)
    expect(find.text('John Doe'), findsOneWidget);
    expect(find.text('\$50.00'), findsOneWidget);
    expect(find.text('No payments recorded yet.'), findsNothing);

    // Cleanup
    await db.close();
  });
}
