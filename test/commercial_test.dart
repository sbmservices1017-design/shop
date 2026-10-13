import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopdesk_flutter/store.dart';
import 'package:shopdesk_flutter/commercial_core.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  final store=Store.instance,core=CommercialCore.instance;
  setUpAll(()async{
    tmp=await Directory.systemTemp.createTemp('shopdesk_commercial_');
    await store.init(overridePath:'${tmp.path}/test.sqlite');
    await core.init();
  });
  tearDownAll(()async{await store.db.close();await tmp.delete(recursive:true);});
  test('owner registration starts 48-hour trial and sign-in is authenticated',()async{
    expect(await core.hasOwner,false);
    await core.registerOwner('ShopOwner','test-password-123');
    expect(await core.hasOwner,true);
    expect(core.current?.isAdmin,true);
    expect(core.license.label,'Trial');
    final time=await core.readSetting('trial_start_utc');
    expect(time,isNotNull);
    core.signOut();
    await expectLater(core.signIn('ShopOwner','incorrect-password'),throwsFormatException);
    await core.signIn('ShopOwner','test-password-123');
    expect(core.current?.username,'ShopOwner');
  });
  test('users only see explicitly authorized modules',()async{
    await core.createUser('CashierOne','very-secure-123');
    final users=await store.read('SELECT id FROM app_users WHERE username=?',['CashierOne']);
    final id=users.first['id'] as int;
    await core.setUserPermission(id,'Sales / Billing',{'view','create'});
    core.signOut();
    await core.signIn('CashierOne','very-secure-123');
    expect(core.current!.allowed('Sales / Billing','view'),true);
    expect(core.current!.allowed('Purchases','view'),false);
    expect(core.current!.allowed('Sales / Billing','delete'),false);
  });
  test('invalid license is rejected',()async{
    await expectLater(core.activate('invalid-key'),throwsFormatException);
  });
}
