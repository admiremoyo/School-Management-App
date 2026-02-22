import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:school_management/features/registration/registration_page.dart';
import 'package:school_management/data/local/app_database.dart';

void main() {
  testWidgets('Registration Page Date Picker Test', (WidgetTester tester) async {
    // 1. Setup in-memory database
    final db = AppDatabase(NativeDatabase.memory());

    // 2. Pump the widget
    await tester.pumpWidget(MaterialApp(
      home: RegistrationPage(db: db),
    ));
    await tester.pumpAndSettle(); // Wait for _loadClasses futures

    // 3. Find the date input field
    // Note: We changed it to a TextFormField with 'Date of Birth' label
    final dateFieldFinder = find.widgetWithText(TextFormField, 'Date of Birth'); // Initial label might be hidden by controller logic?
    // Actually decoration labelText is 'Date of Birth'.
    
    // Check if field exists
    expect(dateFieldFinder, findsOneWidget);

    // 4. Tap to open date picker
    await tester.tap(dateFieldFinder);
    await tester.pumpAndSettle();

    // 5. Verify Date Picker is shown
    expect(find.byType(DatePickerDialog), findsOneWidget);

    // 6. Select a date (e.g., 15th of current month/year or visible month)
    // We just tap 'OK' to select today's date (default selection) or pick a specific date.
    // Let's just tap 'OK' which confirms the selection.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // 7. Verify the text field is updated
    // The controller text should now contain the date.
    final formField = tester.widget<TextFormField>(dateFieldFinder);
    expect(formField.controller?.text, isNotEmpty);
    
    // Cleanup
    await db.close();
  });
}
