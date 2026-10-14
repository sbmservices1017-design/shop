import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopdesk_flutter/store.dart';
import 'package:shopdesk_flutter/extensions.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  final store=Store.instance;
  setUpAll(()async{
    tmp=await Directory.systemTemp.createTemp('simple_shop_catalog_');
    await store.init(overridePath:'${tmp.path}/simple.sqlite');
    await ensureExtendedSchema(store);
  });
  tearDownAll(()async{await store.db.close();await tmp.delete(recursive:true);});

  test('one Set of 3 is three loose pieces; void restores stock',()async{
    final category=await store.addCategory('Mats');
    final product=await store.addProduct(category,'Door Mat');
    final variant=await store.createSimpleVariant(productId:product,size:'Large',color:'Blue',packing:'set',packSize:3,openingPacks:2);
    expect(numVal((await store.stock()).firstWhere((r)=>r['id']==variant)['qty']),6);
    final units=await store.unitOptions(variant,sale:true);
    expect(units.any((x)=>x['unit']=='set' && numVal(x['factor'])==3),true);
    final supplier=await store.addParty('supplier','Set Supplier','','');
    final customer=await store.addParty('customer','Set Client','','');
    final cash=(await store.read("SELECT id FROM accounts WHERE code='1000'")).first['id'] as int;
    final sale=await store.postDocument('sale',customer,nowDate(),[ItemLine(variant,4,200,unit:'pcs',factor:1)],800,cash);
    expect(numVal((await store.stock()).firstWhere((r)=>r['id']==variant)['qty']),2);
    final purchase=await store.postDocument('purchase',supplier,nowDate(),[ItemLine(variant,1,350,unit:'set',factor:3)],0,cash);
    expect(numVal((await store.stock()).firstWhere((r)=>r['id']==variant)['qty']),5);
    await store.updateSimpleVariantDetails(variant,{'Size':'Medium','Color':'Red'});
    expect('${(await store.stock()).firstWhere((r)=>r['id']==variant)['attrs']}',contains('Red'));
    await store.voidDocument(sale);await store.voidDocument(purchase);
    expect(numVal((await store.stock()).firstWhere((r)=>r['id']==variant)['qty']),6);
  });

  test('rolls bought and gazz sold reduce base Feet; negative stock allowed',()async{
    final category=await store.addCategory('Floor Sheets');
    final product=await store.addProduct(category,'Vinyl Floor Sheet');
    final variant=await store.createSimpleVariant(productId:product,design:'Stone',packing:'roll',packSize:90,feetPerGazz:3);
    final units=await store.unitOptions(variant,sale:true);
    expect(units.any((x)=>x['unit']=='gazz' && numVal(x['factor'])==3),true);
    final supplier=await store.addParty('supplier','Roll Supplier','','');
    final customer=await store.addParty('customer','Roll Client','','');
    final cash=(await store.read("SELECT id FROM accounts WHERE code='1000'")).first['id'] as int;
    final purchase=await store.postDocument('purchase',supplier,nowDate(),[ItemLine(variant,1,3000,unit:'roll',factor:90)],0,cash);
    final sale=await store.postDocument('sale',customer,nowDate(),[ItemLine(variant,5,150,unit:'gazz',factor:3)],0,cash);
    expect(numVal((await store.stock()).firstWhere((r)=>r['id']==variant)['qty']),75);
    final extra=await store.postDocument('sale',customer,nowDate(),[ItemLine(variant,100,40,unit:'ft',factor:1)],0,cash);
    expect(numVal((await store.stock()).firstWhere((r)=>r['id']==variant)['qty']),-25);
    await store.voidDocument(extra);await store.voidDocument(sale);await store.voidDocument(purchase);
    expect(numVal((await store.stock()).firstWhere((r)=>r['id']==variant)['qty']),0);
  });
  test('roll quantity and Gazz per roll automatically produce Feet; Table Sheets deduct Feet',()async{
    final category=await store.addCategory('Dining Cloth');
    final product=await store.addProduct(category,'Printed Table Sheet Roll');
    final variant=await store.createSimpleVariant(
      productId:product,design:'Floral',packing:'roll',packSize:1,
      rollGazz:30,tableSheetGazz:2,openingPacks:2);
    // 2 Rolls x 30 Gazz x 3 Feet/Gazz = 180 Feet.
    expect(numVal((await store.stock()).firstWhere((r)=>r['id']==variant)['qty']),180);
    final saleUnits=await store.unitOptions(variant,sale:true);
    final buyingUnits=await store.unitOptions(variant,sale:false);
    expect(saleUnits.any((x)=>x['unit']=='roll' && numVal(x['factor'])==90),true);
    expect(saleUnits.any((x)=>x['unit']=='table sheet' && numVal(x['factor'])==6),true);
    expect(saleUnits.any((x)=>x['unit']=='gazz' && numVal(x['factor'])==3),true);
    expect(buyingUnits.any((x)=>x['unit']=='roll' && numVal(x['factor'])==90),true);
    expect(buyingUnits.any((x)=>x['unit']=='table sheet'),false);
    final customer=await store.addParty('customer','Cloth Customer','','');
    final cash=(await store.read("SELECT id FROM accounts WHERE code='1000'")).first['id'] as int;
    final invoice=await store.postDocument('sale',customer,nowDate(),[
      ItemLine(variant,4,350,unit:'table sheet',factor:6),
    ],0,cash);
    expect(numVal((await store.stock()).firstWhere((r)=>r['id']==variant)['qty']),156);
    await store.voidDocument(invoice);
    expect(numVal((await store.stock()).firstWhere((r)=>r['id']==variant)['qty']),180);
  });

  test('dynamic sets of 3, 5, 7, 9 and loose packet pieces',()async{
    final category=await store.addCategory('Sets and Bundles');
    final product=await store.addProduct(category,'Kitchen Items');
    for(final size in [3,5,7,9]){
      final vid=await store.createSimpleVariant(productId:product,packing:'set',
        packSize:size.toDouble(),openingPacks:1);
      expect(numVal((await store.stock()).firstWhere((r)=>r['id']==vid)['qty']),size);
      expect((await store.unitOptions(vid,sale:true)).any((u)=>u['unit']=='set'&&numVal(u['factor'])==size),true);
    }
    final packet=await store.createSimpleVariant(productId:product,packing:'packet',packSize:12,openingPacks:2);
    final units=await store.unitOptions(packet,sale:true);
    expect(units.any((u)=>u['unit']=='pcs' && numVal(u['factor'])==1),true);
    expect(units.any((u)=>u['unit']=='packet' && numVal(u['factor'])==12),true);
    final customer=await store.addParty('customer','Loose Packet Buyer','','');
    final cash=(await store.read("SELECT id FROM accounts WHERE code='1000'")).first['id'] as int;
    final sale=await store.postDocument('sale',customer,nowDate(),[
      ItemLine(packet,7,30,unit:'pcs',factor:1),
    ],0,cash);
    expect(numVal((await store.stock()).firstWhere((r)=>r['id']==packet)['qty']),17);
    await store.voidDocument(sale);
    expect(numVal((await store.stock()).firstWhere((r)=>r['id']==packet)['qty']),24);
  });

  test('Table Sheet length must fit the Roll',()async{
    final category=await store.addCategory('Custom Cuts');
    final product=await store.addProduct(category,'Cut Roll');
    expect(() => store.createSimpleVariant(productId:product,packing:'roll',packSize:1,
      rollGazz:2,tableSheetGazz:5),throwsFormatException);
  });

  test('packet of 12 can be sold loose by piece',()async{
    final category=await store.addCategory('Blankets');
    final product=await store.addProduct(category,'Table Sheet');
    final variant=await store.createSimpleVariant(productId:product,packing:'packet',packSize:12,openingPacks:2);
    expect(numVal((await store.stock()).firstWhere((r)=>r['id']==variant)['qty']),24);
    final units=await store.unitOptions(variant,sale:true);
    expect(units.any((x)=>x['unit']=='packet'),true);
    expect(units.any((x)=>x['unit']=='pcs'),true);
  });
}
