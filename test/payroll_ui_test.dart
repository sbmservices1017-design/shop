import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopdesk_flutter/payroll_dialog.dart';
import 'package:shopdesk_flutter/payroll_math.dart';

void main() {
  testWidgets('Advance recovery updates net salary and Pay Now in UI', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showDialog<bool>(
              context: ctx,
              builder: (dctx) => const PayrollDialog(
                employeeId: 1,
                employeeName: 'Test Employee',
                quote: PayrollQuote(4000000, 500000),
                cashAccounts: {1: 'Cash'},
              ),
            ),
            child: const Text('Open Payroll'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open Payroll'));
    await tester.pumpAndSettle();
    expect(find.text('Run Payroll • Test Employee'), findsOneWidget);

    // Do not rely on TextField indexes: the salary payment date is an
    // independent field added after the payroll period.
    final salaryDateField = find.byKey(const Key('payroll_salary_date'));
    final recoveryField = find.byKey(const Key('payroll_recovery'));
    final payNowField = find.byKey(const Key('payroll_pay_now'));
    expect(salaryDateField, findsOneWidget);
    expect(recoveryField, findsOneWidget);
    expect(payNowField, findsOneWidget);
    final originalSalaryDate = tester.widget<TextField>(salaryDateField).controller!.text;

    await tester.ensureVisible(recoveryField);
    await tester.enterText(recoveryField, '5000');
    await tester.pump();
    expect(tester.widget<TextField>(payNowField).controller!.text, '35000.00');
    expect(find.text('Rs. 35000.00'), findsWidgets);
    expect(tester.widget<TextField>(salaryDateField).controller!.text, originalSalaryDate);

    await tester.ensureVisible(payNowField);
    await tester.enterText(payNowField, '30000');
    await tester.pump();
    expect(find.text('Rs. 5000.00'), findsWidgets); // Remaining salary due.
  });
}
