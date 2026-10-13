/// All amounts are stored as integer paisa; calculations must not use floating-point rupees.
/// This model is shared by the Payroll dialog and the database posting method.
class PayrollQuote {
  final int gross;
  final int advanceOutstanding;
  const PayrollQuote(this.gross, this.advanceOutstanding);

  int get maximumRecovery => gross < advanceOutstanding ? gross : advanceOutstanding;

  int netPayable(int recovery) {
    if (recovery < 0 || recovery > maximumRecovery) {
      throw FormatException(
        'Advance recovery cannot exceed available advance or gross salary. '
        'Maximum recovery: Rs. ${pkr(maximumRecovery)}.',
      );
    }
    return gross - recovery;
  }

  int salaryDue(int recovery, int paidNow) {
    final net = netPayable(recovery);
    if (paidNow < 0 || paidNow > net) {
      throw FormatException(
        'Monthly salary is Rs. ${pkr(gross)}. After recovery of '
        'Rs. ${pkr(recovery)}, net payable is Rs. ${pkr(net)}. '
        'Pay now must be between Rs. 0.00 and Rs. ${pkr(net)}.',
      );
    }
    return net - paidNow;
  }

  int advanceAfterRecovery(int recovery) {
    netPayable(recovery);
    return advanceOutstanding - recovery;
  }
}

String pkr(int paisa) => (paisa / 100).toStringAsFixed(2);
