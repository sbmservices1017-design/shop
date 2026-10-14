import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopdesk_flutter/store.dart';
import 'package:shopdesk_flutter/extensions.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  final store=Store.instance;
  setUpAll(()async{
    tmp=await Directory.systemTemp.createTemp('shopdesk_096_');
    await store.init(overridePath:'${tmp.path}/data.sqlite');
    await ensureExtendedSchema(store);
  });
  tearDownAll(()async{await store.db.close();await tmp.delete(recursive:true);});

  test('sales POS: cash + bank + wallet plus a later installment reconcile exactly',()async{
    final cat=await store.addCategory('Split sale items');
    final product=await store.addProduct(cat,'Mattress Deluxe');
    final variant=await store.createSimpleVariant(productId:product,size:'Double',color:'Blue');
    final customer=await store.addParty('customer','Split Customer','','');
    final cash=(await store.read("SELECT id FROM accounts WHERE code='1000'")).first['id'] as int;
    final bank=(await store.read("SELECT id FROM accounts WHERE code='1010'")).first['id'] as int;
    final wallet=await store.addPaymentAccount('','Payment Test Wallet','wallet',holderName:'Owner');
    final id=await store.postDocumentSplit('sale',customer,'2026-10-14',[
      ItemLine(variant,1,20000)
    ],[PaymentPart(cash,8000),PaymentPart(bank,7000),PaymentPart(wallet,2000)]);
    final initial=(await store.read('SELECT total,paid FROM documents WHERE id=?',[id])).first;
    expect(initial['total'],2000000);expect(initial['paid'],1700000);
    final parts=await store.read('SELECT account_id,amount FROM document_payment_parts WHERE document_id=? AND active=1 ORDER BY id',[id]);
    expect(parts.map((p)=>p['amount']).toList(),[800000,700000,200000]);
    final accountLines=await store.read("SELECT l.account_id,l.debit FROM journal j JOIN journal_lines l ON l.journal_id=j.id WHERE j.source_type='sale' AND j.source_id=? AND l.account_id IN (?,?,?)",[id,cash,bank,wallet]);
    expect(accountLines.length,3);
    final receipt=await store.recordInvoiceInstallment(id,3000,wallet,'Remaining installment',paymentDate:'2026-10-20');
    expect((await store.read('SELECT paid FROM documents WHERE id=?',[id])).first['paid'],2000000);
    expect((await store.read('SELECT document_id,amount FROM receipt_allocations WHERE receipt_id=?',[receipt])).first['amount'],300000);
    await expectLater(store.recordInvoiceInstallment(id,1,cash,'Overpay'),throwsFormatException);
    await store.voidReceipt(receipt);
    expect((await store.read('SELECT paid FROM documents WHERE id=?',[id])).first['paid'],1700000);
    await expectLater(store.reviseDocument(id,'sale',customer,'2026-10-14',[
      ItemLine(variant,1,20000)],17000,cash),throwsFormatException);
    await store.voidDocument(id);
    expect((await store.read('SELECT COUNT(*) AS n FROM document_payment_parts WHERE document_id=? AND active=1',[id])).first['n'],0);
    expect(numVal((await store.stock()).firstWhere((r)=>r['id']==variant)['qty']),0);
  });

  test('purchase POS: three accounts on one supplier bill and account-safe installment',()async{
    final cat=await store.addCategory('Purchase Split Items');
    final product=await store.addProduct(cat,'Packet Mat');
    final variant=await store.createSimpleVariant(productId:product,packing:'packet',packSize:12);
    final supplier=await store.addParty('supplier','Installment Supplier','','');
    final cash=(await store.read("SELECT id FROM accounts WHERE code='1000'")).first['id'] as int;
    final bank=(await store.read("SELECT id FROM accounts WHERE code='1010'")).first['id'] as int;
    final bill=await store.postDocumentSplit('purchase',supplier,nowDate(),[
      ItemLine(variant,2,2400,unit:'packet',factor:12)
    ],[PaymentPart(cash,1000),PaymentPart(bank,800)]);
    expect((await store.read('SELECT paid FROM documents WHERE id=?',[bill])).first['paid'],180000);
    await store.recordInvoiceInstallment(bill,3000,bank,'Third supplier installment');
    expect((await store.read('SELECT paid FROM documents WHERE id=?',[bill])).first['paid'],480000);
    expect(numVal((await store.stock()).firstWhere((r)=>r['id']==variant)['qty']),24);
  });

  test('roll units include Roll + Feet + Gazz and ready-made sheet Roll is distinct',()async{
    final cat=await store.addCategory('Roll & Sheet goods');
    final prod=await store.addProduct(cat,'Roll Goods');
    final roll=await store.createSimpleVariant(productId:prod,packing:'roll',rollGazz:30,packSize:1,openingPacks:1);
    final units=await store.unitOptions(roll,sale:true);
    expect(units.any((x)=>x['unit']=='roll'&&numVal(x['factor'])==90),true);
    expect(units.any((x)=>x['unit']=='ft'),true);
    expect(units.any((x)=>x['unit']=='gazz'&&numVal(x['factor'])==3),true);
    final sheet=await store.createSimpleVariant(productId:prod,packing:'table_sheet_roll',sheetsPerRoll:20,openingPacks:2);
    expect((await store.unitOptions(sheet,sale:true)).any((u)=>u['unit']=='roll'&&numVal(u['factor'])==20),true);
    final stockBefore=numVal((await store.stock()).firstWhere((r)=>r['id']==sheet)['qty']);
    await store.adjustStock(sheet,-3,'Damaged sheets');
    expect(numVal((await store.stock()).firstWhere((r)=>r['id']==sheet)['qty']),stockBefore-3);
    expect(numVal((await store.stock()).firstWhere((r)=>r['id']==roll)['qty']),90);
  });

  test('salary payroll stores independent period and actual salary date',()async{
    final cash=(await store.read("SELECT id FROM accounts WHERE code='1000'")).first['id'] as int;
    final employee=await store.addEmployee('Date Test Employee','Staff',40000);
    await store.employeeAdvance(employee,5000,cash);
    final payroll=await store.payrollRun(employee,'2026-09',5000,35000,cash,salaryDate:'2026-10-14');
    final row=(await store.read('SELECT period,date,net,paid FROM payroll WHERE id=?',[payroll])).first;
    expect(row['period'],'2026-09');expect(row['date'],'2026-10-14');
    expect(row['net'],3500000);expect(row['paid'],3500000);
    final journals=await store.read("SELECT date FROM journal WHERE source_type='payroll' AND source_id=?",[payroll]);
    expect(journals.first['date'],'2026-10-14');
  });
}
