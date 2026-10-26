import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopdesk_flutter/store.dart';
import 'package:shopdesk_flutter/extensions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final store=Store.instance;
  late Directory temporary;
  setUpAll(()async {
    temporary=await Directory.systemTemp.createTemp('shopdesk_stock_edit_');
    await store.init(overridePath:'${temporary.path}/shop.sqlite');
    await ensureExtendedSchema(store);
  });
  tearDownAll(()async {
    await store.db.close();
    await temporary.delete(recursive:true);
  });

  test('Stock variation cost and selling price editable without rewriting invoice price',()async {
    final category=await store.addCategory('Stock Edit Test');
    final product=await store.addProduct(category,'Floor Roll');
    final variation=await store.addVariant(product,'STOCK-EDIT-1','ft',{},10);
    final customer=await store.addParty('customer','Stock Testing Client','','');
    final cash=(await store.read("SELECT id FROM accounts WHERE code='1000'")).first['id'] as int;
    final sale=await store.postDocument('sale',customer,nowDate(),[
      ItemLine(variation,4,150),
    ],0,cash);
    await store.editStockDetails(variation,purchasePrice:90,salePrice:170,
      targetStock:15,reason:'Physical stock count');
    final stock=(await store.stock()).firstWhere((row)=>row['id']==variation);
    expect(numVal(stock['qty']),15);
    expect(rupees(stock['purchase_price']),90);
    expect(rupees(stock['sale_price']),170);
    // Historical invoice sale rate is NOT silently changed by stock price edits.
    final saved=(await store.read('SELECT rate FROM document_lines WHERE document_id=?',[sale])).single;
    expect(rupees(saved['rate']),150);
    final ledger=await store.stockLedger(variation);
    expect(ledger.length,3);
    expect(numVal(ledger.last['balance']),15);
    expect(ledger.any((r)=>numVal(r['out_qty'])==4),true);
    expect(ledger.any((r)=>r['source_type']=='sale' && '${r['invoice']}'.isNotEmpty),true);
    expect(ledger.any((r)=>numVal(r['in_qty'])==9),true);
    await expectLater(store.editStockDetails(variation,purchasePrice:95,salePrice:180,
        targetStock:16,reason:''),throwsFormatException);
    expect(numVal((await store.stockLedger(variation)).last['balance']),15);
  });

  test('Deleted expense disappears from active screen and journal is reversed',()async {
    final general=(await store.read("SELECT id FROM expense_categories WHERE name='General'")).first['id'] as int;
    final cash=(await store.read("SELECT id FROM accounts WHERE code='1000'")).first['id'] as int;
    await store.addExpense(general,2500,cash,'Demo expense',nowDate());
    final entry=(await store.read("SELECT id FROM expenses WHERE description='Demo expense' ORDER BY id DESC LIMIT 1")).single;
    final id=entry['id'] as int;
    await store.voidExpense(id);
    final active=await store.read('''SELECT e.id FROM expenses e
      WHERE e.id=? AND NOT EXISTS (
        SELECT 1 FROM reversed_transactions r WHERE r.kind='expense' AND r.source_id=e.id
      )''',[id]);
    expect(active,isEmpty);
    final reversals=await store.read("SELECT id FROM reversed_transactions WHERE kind='expense' AND source_id=?",[id]);
    expect(reversals.length,1);
    final expenseJournal=await store.read("SELECT count(*) AS n FROM journal WHERE source_id=? AND source_type IN ('expense','void_expense')",[id]);
    expect(expenseJournal.single['n'],2);
    await expectLater(store.voidExpense(id),throwsFormatException);
  });
}
