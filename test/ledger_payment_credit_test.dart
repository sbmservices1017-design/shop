import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopdesk_flutter/store.dart';
import 'package:shopdesk_flutter/reporting.dart';
import 'package:shopdesk_flutter/extensions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final s=Store.instance;
  late Directory tmp;
  setUpAll(() async {
    tmp=await Directory.systemTemp.createTemp('shopdesk_payment_ledger_');
    await s.init(overridePath:'${tmp.path}/ledger.sqlite');
    await ensureExtendedSchema(s);
  });
  tearDownAll(() async {await s.db.close();await tmp.delete(recursive:true);});

  test('Split payments retain their Cash / Bank account in customer ledger',() async {
    final cat=await s.addCategory('Payment Ledger Test');
    final prod=await s.addProduct(cat,'Ledger Mattress');
    final variant=await s.createSimpleVariant(productId:prod,packing:'piece',packSize:1);
    final customer=await s.addParty('customer','Ledger Customer','','');
    final cash=(await s.read("SELECT id FROM accounts WHERE code='1000'")).first['id'] as int;
    final bank=(await s.read("SELECT id FROM accounts WHERE code='1010'")).first['id'] as int;
    final wallet=await s.addPaymentAccount('','Ledger Wallet','wallet',holderName:'Shop Owner');
    final invoice=await s.postDocumentSplit('sale',customer,'2026-10-15',[
      ItemLine(variant,1,10000)
    ],[PaymentPart(cash,4000),PaymentPart(bank,2000)]);
    final ledger=await buildReport(s,ReportFilter(type:'Customer Ledger',start:'2026-10-01',end:'2026-10-31',party:customer));
    final method=ledger.headings.indexOf('Payment Method');
    expect(method,greaterThanOrEqualTo(0));
    expect(ledger.rows.where((r)=>r[method].contains('Cash')).length,1);
    expect(ledger.rows.where((r)=>r[method].contains('Bank')).length,1);
    expect(ledger.rows.last.last,'4000.00');
    final due=await s.read("SELECT coalesce(sum(total-paid),0) AS n FROM documents WHERE kind='sale' AND status='POSTED'");
    expect(due.first['n'],400000);
    final receipt=await s.recordInvoiceInstallment(invoice,1000,wallet,'Wallet installment',paymentDate:'2026-10-15');
    final after=await buildReport(s,ReportFilter(type:'Customer Ledger',start:'2026-10-01',end:'2026-10-31',party:customer));
    expect(after.rows.last[method],contains('Ledger Wallet'));
    expect(after.rows.last.last,'3000.00');
    await s.voidReceipt(receipt);
    final reversed=await buildReport(s,ReportFilter(type:'Customer Ledger',start:'2026-10-01',end:'2026-10-31',party:customer));
    expect(reversed.rows.last[method],contains('Ledger Wallet'));
    expect(reversed.rows.last.last,'4000.00');
    expect((await s.read("SELECT coalesce(sum(total-paid),0) AS n FROM documents WHERE kind='sale' AND status='POSTED'")).first['n'],400000);
  });

  test('Supplier ledger and account ledger show actual payment accounts',() async {
    final variant=(await s.read('SELECT id FROM variants ORDER BY id DESC LIMIT 1')).first['id'] as int;
    final supplier=await s.addParty('supplier','Ledger Supplier','','');
    final cash=(await s.read("SELECT id FROM accounts WHERE code='1000'")).first['id'] as int;
    final wallet=(await s.read("SELECT id FROM accounts WHERE name='Ledger Wallet'")).first['id'] as int;
    await s.postDocumentSplit('purchase',supplier,'2026-10-15',[
      ItemLine(variant,1,3000)
    ],[PaymentPart(cash,1000),PaymentPart(wallet,500)]);
    final report=await buildReport(s,ReportFilter(type:'Supplier Ledger',start:'2026-10-01',end:'2026-10-31',party:supplier));
    final idx=report.headings.indexOf('Payment Method');
    expect(report.rows.where((r)=>r[idx].contains('Cash')),isNotEmpty);
    expect(report.rows.where((r)=>r[idx].contains('Ledger Wallet')),isNotEmpty);
    expect(report.rows.last.last,'1500.00');
    final accounts=await buildReport(s,ReportFilter(type:'Account Ledger',start:'2026-10-01',end:'2026-10-31'));
    expect(accounts.headings,contains('Payment Method'));
    final employees=await buildReport(s,ReportFilter(type:'Employee Ledger',start:'2026-10-01',end:'2026-10-31'));
    expect(employees.headings,contains('Payment Method'));
  });
}
