import 'package:flutter_test/flutter_test.dart';
import 'package:shopdesk_flutter/payroll_math.dart';

void main(){
  test('Pay now is NET after advance recovery, not GROSS',(){
    const quote=PayrollQuote(4000000,500000);
    expect(quote.maximumRecovery,500000);
    expect(quote.netPayable(500000),3500000);
    expect(quote.salaryDue(500000,3500000),0);
    expect(quote.advanceAfterRecovery(500000),0);
    expect(()=>quote.salaryDue(500000,4000000),throwsFormatException);
    expect(()=>quote.netPayable(500001),throwsFormatException);
  });
  test('Partial pay leaves salary due',(){
    const quote=PayrollQuote(4000000,500000);
    expect(quote.salaryDue(500000,3000000),500000);
  });
}
