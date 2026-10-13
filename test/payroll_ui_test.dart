import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopdesk_flutter/payroll_dialog.dart';
import 'package:shopdesk_flutter/payroll_math.dart';

void main(){
  testWidgets('Advance recovery updates net salary and Pay Now in UI', (tester)async{
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Builder(builder:(ctx)=>
      ElevatedButton(onPressed:()=>showDialog<bool>(context:ctx,builder:(dctx)=>const PayrollDialog(
        employeeId:1,employeeName:'Test Employee',
        quote:PayrollQuote(4000000,500000),cashAccounts:{1:'Cash'})),
        child:const Text('Open Payroll'))))));
    await tester.tap(find.text('Open Payroll'));
    await tester.pumpAndSettle();
    expect(find.text('Run Payroll • Test Employee'),findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1),'5000');
    await tester.pump();
    final texts=tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(texts[2].controller!.text,'35000.00');
    expect(find.text('Rs. 35000.00'),findsWidgets);
    await tester.enterText(find.byType(TextField).at(2),'30000');
    await tester.pump();
    expect(find.text('Rs. 5000.00'),findsWidgets);
  });
}
