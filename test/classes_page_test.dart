import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:school_management/features/classes/classes_page.dart';
import 'package:school_management/data/local/app_database.dart';

void main() {
  testWidgets('Classes Page Add Class Test', (WidgetTester tester) async {
    // 1. Setup in-memory database
    final db = AppDatabase(NativeDatabase.memory());

    // 2. Pump the widget
    await tester.pumpWidget(MaterialApp(
      home: ClassesPage(db: db),
    ));
    await tester.pumpAndSettle();

    // 3. Verify empty state
    expect(find.text('No classes found. Add one!'), findsOneWidget);

    // 4. Tap add button
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // 5. Verify Dialog opens
    expect(find.text('Add New Class'), findsOneWidget);

    // 6. Enter class name
    await tester.enterText(find.byType(TextFormField), 'Grade 1');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    // 7. Verify class is added to list
    expect(find.text('Grade 1'), findsOneWidget);
    expect(find.text('No classes found. Add one!'), findsNothing);

    // Cleanup
    await db.close();
  });
}
