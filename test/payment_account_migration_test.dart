import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shopdesk_flutter/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  final store=Store.instance;

  setUpAll(() async {
    directory=await Directory.systemTemp.createTemp('shopdesk_payment_migration_');
    sqfliteFfiInit();
    final location='${directory.path}/old_version.sqlite';
    final legacy=await databaseFactoryFfi.openDatabase(location);
    await legacy.execute('''CREATE TABLE accounts(
      id INTEGER PRIMARY KEY,code TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,type TEXT NOT NULL,active INTEGER NOT NULL DEFAULT 1)''');
    await legacy.execute('''CREATE TABLE payment_accounts(
      account_id INTEGER PRIMARY KEY REFERENCES accounts(id),
      kind TEXT NOT NULL CHECK(kind IN ('cash','bank','wallet')))''');
    await legacy.rawInsert("INSERT INTO accounts(code,name,type) VALUES('1000','Cash','asset')");
    await legacy.rawInsert("INSERT INTO payment_accounts(account_id,kind) VALUES(1,'cash')");
    await legacy.close();
    await store.init(overridePath:location);
  });
  tearDownAll(() async {
    await store.db.close();
    await directory.delete(recursive:true);
  });

  test('legacy payment accounts migrate without losing their identity',() async {
    final rows=await store.read('SELECT a.id,a.code,pa.holder_name FROM accounts a JOIN payment_accounts pa ON pa.account_id=a.id WHERE a.code=?',['1000']);
    expect(rows.length,1);
    expect(rows.single['id'],1);
    expect(rows.single['holder_name'],'');
  });

  test('new accounts automatically get distinct references and visible holders',() async {
    final one=await store.addPaymentAccount('','HBL','bank',holderName:'First Holder');
    final two=await store.addPaymentAccount('','JazzCash','wallet',holderName:'Second Holder');
    final accounts=await store.paymentAccountOptions();
    expect(accounts[one],contains('First Holder'));
    expect(accounts[two],contains('Second Holder'));
    final refs=await store.read('SELECT code FROM accounts WHERE id IN (?,?) ORDER BY id',[one,two]);
    expect(refs[0]['code'],'PAY-000001');
    expect(refs[1]['code'],'PAY-000002');
    final general=await store.addLedgerAccount('Office Account','asset');
    final generalRows=await store.read('SELECT code FROM accounts WHERE id=?',[general]);
    expect(generalRows.single['code'],'GL-000001');
    await store.updatePaymentAccountDetails(one,name:'HBL Business',holderName:'New Holder');
    final updated=await store.paymentAccountOptions();
    expect(updated[one],contains('New Holder'));
    expect(updated[one],contains('PAY-000001'));
  });
}
