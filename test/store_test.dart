import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopdesk_flutter/store.dart';
import 'package:shopdesk_flutter/reporting.dart';
import 'package:shopdesk_flutter/extensions.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  final s=Store.instance;
  setUpAll(()async{tmp=await Directory.systemTemp.createTemp('shopdesk_flutter_');await s.init(overridePath:'${tmp.path}/test.sqlite');await ensureExtendedSchema(s);});
  tearDownAll(()async{await s.db.close();await tmp.delete(recursive:true);});

  test('sale below zero and subsequent purchase recover stock with ledgers',()async{
    final cat=await s.addCategory('Mattresses');
    final prod=await s.addProduct(cat,'Foam Mattress');
    final varId=await s.addVariant(prod,'T-MAT-1','pcs',{},0);
    final customer=await s.addParty('customer','Testing Customer','','');
    final supplier=await s.addParty('supplier','Testing Supplier','','');
    final cash=(await s.read("SELECT id FROM accounts WHERE code='1000'")).first['id'] as int;
    final sale=await s.postDocument('sale',customer,nowDate(),[ItemLine(varId,5,1200)],1000,cash);
    expect(numVal((await s.stock()).first['qty']),-5);
    expect((await s.read('SELECT sum(debit-credit) AS bal FROM party_ledger WHERE party_id=?',[customer])).first['bal'],500000);
    final purchase=await s.postDocument('purchase',supplier,nowDate(),[ItemLine(varId,12,450)],0,cash);
    expect(numVal((await s.stock()).first['qty']),7);
    expect((await s.read('SELECT sum(credit-debit) AS bal FROM party_ledger WHERE party_id=?',[supplier])).first['bal'],540000);
    await s.voidDocument(sale);
    expect(numVal((await s.stock()).first['qty']),12);
    expect((await s.read('SELECT sum(debit-credit) AS bal FROM party_ledger WHERE party_id=?',[customer])).first['bal'],0);
    await s.voidDocument(purchase);
    expect(numVal((await s.stock()).first['qty']),0);
  });
  test('employee advance and payroll are reflected in ledger',()async{
    final cash=(await s.read("SELECT id FROM accounts WHERE code='1000'")).first['id'] as int;
    final e=await s.addEmployee('Team Member','Shop assistant',30000);
    await s.employeeAdvance(e,6000,cash);
    final payroll=await s.payrollRun(e,'2026-10',2500,27500,cash);
    expect(payroll,greaterThan(0));
    final entries=await s.read('SELECT kind,amount FROM employee_ledger WHERE employee_id=?',[e]);
    expect(entries.map((x)=>x['kind']),containsAll(['ADVANCE','RECOVERY','SALARY_DUE','SALARY_PAID']));
    final tb=await buildReport(s,ReportFilter(type:'Trial Balance',start:'2026-01-01',end:'2100-01-01'));
    expect(tb.rows,isNotEmpty);
  });
  test('report filters and A4-ready export data',()async{
    final r=await buildReport(s,ReportFilter(type:'Stock',start:'2026-01-01',end:'2100-01-01'));
    expect(r.headings,contains('Stock'));
    expect(r.rows,isNotEmpty);
  });
  test('linked sale returns and supplier purchase returns with accurate stock',()async{
    final c=await s.addCategory('Return Goods');
    final product=await s.addProduct(c,'Test Blanket');
    final vid=await s.addVariant(product,'RET-BLANKET','pcs',{},0);
    final customer=await s.addParty('customer','Return Client','','');
    final supplier=await s.addParty('supplier','Return Vendor','','');
    final cash=(await s.read("SELECT id FROM accounts WHERE code='1000'")).first['id'] as int;
    final sid=await s.postDocument('sale',customer,nowDate(),[ItemLine(vid,4,1000)],2000,cash);
    final saleLine=(await s.read('SELECT id FROM document_lines WHERE document_id=?',[sid])).first['id'] as int;
    final rid=await s.postReturn(sid,[ReturnItem(saleLine,2)],1000,cash,'One damaged item');
    expect(numVal((await s.stock()).firstWhere((r)=>r['id']==vid)['qty']),-2);
    await expectLater(s.voidDocument(sid),throwsFormatException);
    await expectLater(s.postReturn(sid,[ReturnItem(saleLine,3)],0,cash,'Excess'),throwsFormatException);
    final pid=await s.postDocument('purchase',supplier,nowDate(),[ItemLine(vid,10,500)],0,cash);
    final pline=(await s.read('SELECT id FROM document_lines WHERE document_id=?',[pid])).first['id'] as int;
    final prid=await s.postReturn(pid,[ReturnItem(pline,3)],0,cash,'Supplier rejected');
    expect(numVal((await s.stock()).firstWhere((r)=>r['id']==vid)['qty']),5);
    await s.voidReturn(prid);
    await s.voidReturn(rid);
    await s.voidDocument(sid);
    await s.voidDocument(pid);
    expect(numVal((await s.stock()).firstWhere((r)=>r['id']==vid)['qty']),0);
  });

  test('reverse customer payment and expense with balanced journals',()async{
    final customer=await s.addParty('customer','Payment Client','','');
    final cash=(await s.read("SELECT id FROM accounts WHERE code='1000'")).first['id'] as int;
    await s.recordPayment(customer,1250,cash,'Opening receipt');
    final receipt=(await s.read('SELECT max(id) AS id FROM receipts')).first['id'] as int;
    await s.voidReceipt(receipt);
    await expectLater(s.voidReceipt(receipt),throwsFormatException);
    final balance=(await s.read('SELECT sum(debit-credit) AS bal FROM party_ledger WHERE party_id=?',[customer])).first['bal'];
    expect(balance,0);
    final category=(await s.read("SELECT id FROM expense_categories WHERE name='General'")).first['id'] as int;
    await s.addExpense(category,150,cash,'Office expense',nowDate());
    final expense=(await s.read('SELECT max(id) AS id FROM expenses')).first['id'] as int;
    await s.voidExpense(expense);
    final imbalances=await s.read('''SELECT j.id,sum(l.debit-l.credit) AS diff FROM journal j
      JOIN journal_lines l ON l.journal_id=j.id GROUP BY j.id HAVING diff<>0''');
    expect(imbalances,isEmpty);
  });

  test('data integrity, forbidden duplicate opening and quantity validation',()async{
    final party=await s.addParty('customer','Single Opening Customer','','');
    await s.openingPartyBalance(party,200,'Opening');
    await expectLater(s.openingPartyBalance(party,200,'Duplicate'),throwsFormatException);
    final category=await s.addCategory('Precision Check');
    final product=await s.addProduct(category,'Measurement Product');
    final sku=await s.addVariant(product,'PRECISION-1','meter',{},0);
    final cash=(await s.read("SELECT id FROM accounts WHERE code='1000'")).first['id'] as int;
    await expectLater(s.postDocument('sale',null,nowDate(),[ItemLine(sku,1.00001,20)],20.0002,cash),throwsFormatException);
    expect(await s.verifyDatabase(),isEmpty);
  });

  test('invoice correction is atomic, maintains stock and preserves original history',()async{
    final category=await s.addCategory('Corrections');
    final prod=await s.addProduct(category,'Correction Test Item');
    final vid=await s.addVariant(prod,'REV-SKU','pcs',{},0);
    final client=await s.addParty('customer','Correction Customer','','');
    final cash=(await s.read("SELECT id FROM accounts WHERE code='1000'")).first['id'] as int;
    final original=await s.postDocument('sale',client,nowDate(),[ItemLine(vid,2,1000)],1000,cash);
    await expectLater(s.reviseDocument(original,'sale',client,nowDate(),[ItemLine(vid,0,1000)],0,cash),throwsFormatException);
    expect((await s.read('SELECT status FROM documents WHERE id=?',[original])).first['status'],'POSTED');
    expect(numVal((await s.stock()).firstWhere((x)=>x['id']==vid)['qty']),-2);
    final originalNumber=(await s.read('SELECT invoice FROM documents WHERE id=?',[original])).first['invoice'];
    final revised=await s.reviseDocument(original,'sale',client,nowDate(),[ItemLine(vid,3,1000)],500,cash);
    expect((await s.read('SELECT invoice FROM documents WHERE id=?',[original])).first['invoice'],originalNumber);
    expect(revised,original);
    expect((await s.read('SELECT status FROM documents WHERE id=?',[original])).first['status'],'POSTED');
    expect((await s.read('SELECT count(*) n FROM documents WHERE id=?',[original])).first['n'],1);
    expect((await s.read('SELECT status FROM documents WHERE id=?',[revised])).first['status'],'POSTED');
    expect(numVal((await s.stock()).firstWhere((x)=>x['id']==vid)['qty']),-3);
    final balance=(await s.read('SELECT sum(debit-credit) AS bal FROM party_ledger WHERE party_id=?',[client])).first['bal'];
    expect(balance,250000);
    final report=await buildReport(s,ReportFilter(type:'Sales',start:'2020-01-01',end:'2100-01-01',variant:vid,paymentStatus:'partial'));
    expect(report.rows.length,1);
    expect(await s.verifyDatabase(),isEmpty);
    final correctedAgain=await s.reviseDocument(original,'sale',client,nowDate(),[ItemLine(vid,4,1000)],1000,cash);
    expect(correctedAgain,original);
    expect((await s.read('SELECT count(*) AS n FROM document_revisions WHERE document_id=?',[original])).first['n'],2);
    expect(numVal((await s.stock()).firstWhere((x)=>x['id']==vid)['qty']),-4);
    await s.voidDocument(original);
    expect(numVal((await s.stock()).firstWhere((x)=>x['id']==vid)['qty']),0);
    expect((await s.read('SELECT count(*) AS n FROM documents WHERE id=?',[original])).first['n'],1);
    expect(await s.verifyDatabase(),isEmpty);
  });

  test('invoice prefixes and serials persist and advance independently',()async{
    final customer=await s.addParty('customer','Numbering customer','','');
    final supplier=await s.addParty('supplier','Numbering supplier','','');
    final category=await s.addCategory('Numbering category');
    final product=await s.addProduct(category,'Numbering product');
    final variant=await s.addVariant(product,'SERIAL-SKU','pcs',{},0);
    final cash=(await s.read("SELECT id FROM accounts WHERE code='1000'")).first['id'] as int;
    await s.db.rawInsert("INSERT OR REPLACE INTO app_settings(key,value) VALUES('invoice_prefix_sale','BILL')");
    await s.db.rawInsert("INSERT OR REPLACE INTO app_settings(key,value) VALUES('invoice_next_sale','18')");
    final a=await s.postDocument('sale',customer,nowDate(),[ItemLine(variant,1,100)],100,cash);
    final b=await s.postDocument('sale',customer,nowDate(),[ItemLine(variant,1,100)],100,cash);
    final c=await s.postDocument('purchase',supplier,nowDate(),[ItemLine(variant,1,50)],0,cash);
    expect((await s.read('SELECT invoice FROM documents WHERE id=?',[a])).first['invoice'],'BILL-000018');
    expect((await s.read('SELECT invoice FROM documents WHERE id=?',[b])).first['invoice'],'BILL-000019');
    expect('${(await s.read('SELECT invoice FROM documents WHERE id=?',[c])).first['invoice']}'.startsWith('PUR-'),true);
  });

  test('filtered ledgers display an opening-adjusted running balance',()async{
    final client=await s.addParty('customer','Ledger Running Balance Test','','');
    await s.openingPartyBalance(client,1000,'Opening test');
    final cash=(await s.read("SELECT id FROM accounts WHERE code='1000'")).first['id'] as int;
    await s.recordPayment(client,250,cash,'Paid against opening');
    final report=await buildReport(s,ReportFilter(type:'Customer Ledger',start:'2000-01-01',end:'2100-01-01',party:client));
    expect(report.headings.last,'Running Balance');
    expect(report.rows.last.last,'750.00');
  });

  test('opening balances and outstanding salary settlement',()async{
    final party=await s.addParty('supplier','Opening Vendor','','');
    await s.openingPartyBalance(party,800,'Opening supplier payable');
    final partyBal=(await s.read('SELECT sum(credit-debit) AS bal FROM party_ledger WHERE party_id=?',[party])).first['bal'];
    expect(partyBal,80000);
    final cash=(await s.read("SELECT id FROM accounts WHERE code='1000'")).first['id'] as int;
    final employee=await s.addEmployee('Salary Due Test','Clerk',10000);
    await s.payrollRun(employee,'2026-11',0,2500,cash);
    await s.paySalaryBalance(employee,7500,cash);
    await expectLater(s.paySalaryBalance(employee,1,cash),throwsFormatException);
    final rpt=await buildReport(s,ReportFilter(type:'Sales Returns',start:'2020-01-01',end:'2100-01-01'));
    expect(rpt.headings,contains('Cash_Refund'));
  });

  test('receipt allocation automatically updates invoice Paid status and reverses safely',()async{
    final cat=await s.addCategory('Payment State Test');
    final product=await s.addProduct(cat,'Payment Test Product');
    final variant=await s.addVariant(product,'PAY-TEST-001','pcs',{},0);
    final customer=await s.addParty('customer','Paid Status Customer','','');
    final cash=(await s.read("SELECT id FROM accounts WHERE code='1000'")).first['id'] as int;
    final invoice=await s.postDocument('sale',customer,nowDate(),[ItemLine(variant,1,1000)],0,cash);
    await s.recordPayment(customer,400,cash,'First instalment');
    var record=(await s.read('SELECT total,paid FROM documents WHERE id=?',[invoice])).first;
    expect(record['paid'],40000);
    await s.recordPayment(customer,600,cash,'Final instalment');
    record=(await s.read('SELECT total,paid FROM documents WHERE id=?',[invoice])).first;
    expect(record['paid'],record['total']);
    final latest=(await s.read('SELECT id FROM receipts WHERE party_id=? ORDER BY id DESC LIMIT 1',[customer])).first['id'] as int;
    await s.voidReceipt(latest);
    record=(await s.read('SELECT total,paid FROM documents WHERE id=?',[invoice])).first;
    expect(record['paid'],40000);
  });
}
