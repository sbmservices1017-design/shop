import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopdesk_flutter/store.dart';
import 'package:shopdesk_flutter/extensions.dart';
import 'package:shopdesk_flutter/database_reset.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  final s=Store.instance;
  late Directory tmp;
  late int cash;
  setUpAll(()async {
    tmp=await Directory.systemTemp.createTemp('shopdesk_recovery_');
    await s.init(overridePath:'${tmp.path}/recovery.sqlite');
    await ensureExtendedSchema(s);
    cash=(await s.read("SELECT id FROM accounts WHERE code='1000'")).first['id'] as int;
  });
  tearDownAll(()async{await s.db.close();await tmp.delete(recursive:true);});

  test('return edit retains ID and cancellation hides active return',() async {
    final category=await s.addCategory('Return Edit Test');
    final product=await s.addProduct(category,'Door Mat');
    final variant=await s.addVariant(product,'RET-REV-01','pcs',{},0);
    final customer=await s.addParty('customer','Return Edit Customer','','');
    final invoice=await s.postDocument('sale',customer,nowDate(),[ItemLine(variant,10,100)],0,cash);
    final line=(await s.read('SELECT id FROM document_lines WHERE document_id=?',[invoice])).first['id'] as int;
    final returned=await s.postReturn(invoice,[ReturnItem(line,2)],0,cash,'Initial 2 pieces');
    expect(numVal((await s.stock()).firstWhere((r)=>r['id']==variant)['qty']),-8);
    final result=await s.reviseReturn(returned,[ReturnItem(line,3)],0,cash,'Correct to 3 pieces');
    expect(result,returned);
    expect((await s.read('SELECT qty FROM return_lines WHERE return_id=?',[returned])).first['qty'],3);
    expect(numVal((await s.stock()).firstWhere((r)=>r['id']==variant)['qty']),-7);
    expect(await s.count('SELECT count(*) FROM return_revisions WHERE return_id=?',[returned]),1);
    await s.voidReturn(returned);
    expect(numVal((await s.stock()).firstWhere((r)=>r['id']==variant)['qty']),-10);
    expect((await s.read('SELECT status FROM document_returns WHERE id=?',[returned])).first['status'],'VOID');
    // Voided returns still reference the historic source line: invoice editing
    // must preserve that source for audit rather than failing on a foreign key.
    final corrected=await s.reviseDocument(invoice,'sale',customer,nowDate(),[ItemLine(variant,5,100)],0,cash);
    expect(corrected,invoice);
    expect(await s.count('SELECT count(*) FROM document_lines WHERE document_id=? AND is_current=1',[invoice]),1);
    expect(await s.count('SELECT count(*) FROM document_lines WHERE document_id=? AND is_current=0',[invoice]),1);
    expect(numVal((await s.stock()).firstWhere((r)=>r['id']==variant)['qty']),-5);
    await s.cancelInvoiceSafely(invoice);
    expect(numVal((await s.stock()).firstWhere((r)=>r['id']==variant)['qty']),0);
    expect((await s.read('SELECT status FROM documents WHERE id=?',[invoice])).first['status'],'VOID');
    expect((await s.read("SELECT count(*) AS n FROM documents WHERE status='POSTED' AND id=?",[invoice])).first['n'],0);
  });

  test('split payments and installments stay with corrected invoice; delete releases credit',()async{
    final category=await s.addCategory('Split Invoice Correction');
    final product=await s.addProduct(category,'Mattress');
    final variant=await s.addVariant(product,'RET-REV-02','pcs',{},0);
    final customer=await s.addParty('customer','Split Invoice Customer','','');
    final bank=(await s.read("SELECT id FROM accounts WHERE code='1010'")).first['id'] as int;
    final doc=await s.postDocumentSplit('sale',customer,nowDate(),[ItemLine(variant,1,1000)],
      [PaymentPart(cash,200),PaymentPart(bank,300)]);
    await s.recordInvoiceInstallment(doc,400,bank,'Later installment');
    final result=await s.reviseDocument(doc,'sale',customer,nowDate(),[ItemLine(variant,1,800)],900,cash);
    expect(result,doc);
    final row=(await s.read('SELECT total,paid FROM documents WHERE id=?',[doc])).first;
    expect(row['total'],80000);
    expect(row['paid'],80000);
    expect(await s.count('SELECT count(*) FROM document_payment_parts WHERE document_id=? AND active=1',[doc]),2);
    expect((await s.read('SELECT sum(amount) AS a FROM receipt_allocations WHERE document_id=?',[doc])).first['a'],30000);
    // Rs. 100 is retained as an unapplied payment and never silently erased.
    await s.cancelInvoiceSafely(doc);
    expect((await s.read('SELECT status FROM documents WHERE id=?',[doc])).first['status'],'VOID');
    expect(await s.count('SELECT count(*) FROM receipt_allocations WHERE document_id=?',[doc]),0);
  });

  test('accounts creation dates migrate and owner PIN protects reset/backup',()async{
    final fields=await s.read('PRAGMA table_info(accounts)');
    expect(fields.any((f)=>f['name']=='created_at'),true);
    await expectLater(ShopDataReset.clear(pin:'00000',administrator:true),throwsFormatException);
    await expectLater(ShopDataReset.clear(pin:'00000',administrator:false),throwsFormatException);
    // Never commit the owner PIN into public test sources.
    // Private verification: flutter test --dart-define=SHOPDESK_RESET_TEST_PIN=XXXXX
    const ownerTestPin=String.fromEnvironment('SHOPDESK_RESET_TEST_PIN');
    if(ownerTestPin.isEmpty)return;
    final backup=await ShopDataReset.clear(pin:ownerTestPin,administrator:true);
    expect(await File(backup).exists(),true);
    expect(await s.count('SELECT count(*) FROM documents'),0);
    expect(await s.count('SELECT count(*) FROM document_returns'),0);
    expect(await s.count('SELECT count(*) FROM products'),0);
    expect(await s.count('SELECT count(*) FROM parties'),0);
    expect(await s.count('SELECT count(*) FROM accounts'),12);
    expect(await s.count('SELECT count(*) FROM expense_categories'),1);
    final check=await s.read('PRAGMA foreign_key_check');
    expect(check,isEmpty);
  });
}
