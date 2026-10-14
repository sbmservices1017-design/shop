import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopdesk_flutter/store.dart';
import 'package:shopdesk_flutter/extensions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final store = Store.instance;
  late Directory temp;

  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('shopdesk_delete_test_');
    await store.init(overridePath:'${temp.path}/delete.sqlite');
    await ensureExtendedSchema(store);
  });
  tearDownAll(() async {
    await store.db.close();
    await temp.delete(recursive:true);
  });

  test('Category cannot be deleted until its active product is removed', () async {
    final category = await store.addCategory('Testing unused categories');
    final product = await store.addProduct(category, 'Simple test product');
    await expectLater(store.deleteManagedRecord('categories',category),throwsFormatException);
    await store.deleteManagedRecord('products',product);
    await store.deleteManagedRecord('categories',category);
    expect(await store.count('SELECT count(*) FROM categories WHERE id=? AND active=1',[category]),0);
    expect(await store.count('SELECT count(*) FROM products WHERE id=? AND active=1',[product]),0);
  });

  test('Variation and product deletion require zero stock', () async {
    final category=await store.addCategory('Stock delete protection');
    final product=await store.addProduct(category,'Stock-protected item');
    final variant=await store.addVariant(product,'TEST-DELETE-STOCK-01','pcs',{},0);
    await store.db.rawInsert('''INSERT INTO stock_movements(variant_id,qty,source_type,source_id,date,note)
      VALUES(?,?,?,?,?,?)''',[variant,6,'adjustment',1,nowDate(),'Example balance']);
    await expectLater(store.deleteManagedRecord('variants',variant),throwsFormatException);
    await expectLater(store.deleteManagedRecord('products',product),throwsFormatException);
    await store.db.rawInsert('''INSERT INTO stock_movements(variant_id,qty,source_type,source_id,date,note)
      VALUES(?,?,?,?,?,?)''',[variant,-6,'adjustment',2,nowDate(),'Stock cleared']);
    await store.deleteManagedRecord('variants',variant);
    await store.deleteManagedRecord('products',product);
    expect((await store.read('SELECT active FROM variants WHERE id=?',[variant])).first['active'],0);
  });

  test('Customer with outstanding ledger cannot be hidden', () async {
    final party=await store.addParty('customer','Open-balance customer','','');
    await store.db.rawInsert('''INSERT INTO party_ledger
      (party_id,debit,credit,source_type,source_id,date,note) VALUES(?,?,?,?,?,?,?)''',
      [party,10000,0,'opening',1,nowDate(),'Test opening']);
    await expectLater(store.deleteManagedRecord('parties',party),throwsFormatException);
    await store.db.rawInsert('''INSERT INTO party_ledger
      (party_id,debit,credit,source_type,source_id,date,note) VALUES(?,?,?,?,?,?,?)''',
      [party,0,10000,'receipt',2,nowDate(),'Settled']);
    await store.deleteManagedRecord('parties',party);
    expect((await store.read('SELECT active FROM parties WHERE id=?',[party])).first['active'],0);
  });

  test('Built-in accounts cannot be removed; custom zero-balance accounts can', () async {
    final builtIn=(await store.read("SELECT id FROM accounts WHERE code='1000'")).first['id'] as int;
    await expectLater(store.deleteManagedRecord('accounts',builtIn),throwsFormatException);
    final account=await store.addLedgerAccount('Temporary example','asset');
    await store.deleteManagedRecord('accounts',account);
    expect((await store.read('SELECT active FROM accounts WHERE id=?',[account])).first['active'],0);
  });

  test('Only unused expense categories can be deleted', () async {
    final category=await store.db.rawInsert('INSERT INTO expense_categories(name) VALUES(?)',['One-off example']);
    await store.deleteExpenseCategory(category);
    expect(await store.count('SELECT count(*) FROM expense_categories WHERE id=?',[category]),0);
  });
}
