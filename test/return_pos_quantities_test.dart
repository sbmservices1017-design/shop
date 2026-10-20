import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopdesk_flutter/store.dart';
import 'package:shopdesk_flutter/extensions.dart';
import 'package:shopdesk_flutter/reporting.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final s=Store.instance;
  late Directory temp;
  late int cash;
  setUpAll(() async {
    temp=await Directory.systemTemp.createTemp('shopdesk_returns_');
    await s.init(overridePath:'${temp.path}/returns.sqlite');
    await ensureExtendedSchema(s);
    cash=(await s.read("SELECT id FROM accounts WHERE code='1000'")).first['id'] as int;
  });
  tearDownAll(() async {await s.db.close();await temp.delete(recursive:true);});

  Future<List<Map<String,Object?>>> lineQuantities(int invoice) => s.read('''
    SELECT l.id,l.qty AS original,
      coalesce((SELECT sum(rl.qty) FROM return_lines rl JOIN document_returns r
        ON r.id=rl.return_id WHERE rl.source_line_id=l.id AND r.status='POSTED'),0) AS returned,
      l.qty-coalesce((SELECT sum(rl.qty) FROM return_lines rl JOIN document_returns r
        ON r.id=rl.return_id WHERE rl.source_line_id=l.id AND r.status='POSTED'),0) AS remaining
    FROM document_lines l WHERE l.document_id=? AND l.is_current=1 ORDER BY l.id''',[invoice]);

  test('Sale: full return, partial return, repeat return and void recalculate invoice quantities',() async {
    final category=await s.addCategory('Return Quantities Sale');
    final product=await s.addProduct(category,'Mattress');
    final doubleSize=await s.addVariant(product,'RET-MAT-DOUBLE','pcs',{},0);
    final singleSize=await s.addVariant(product,'RET-MAT-SINGLE','pcs',{},0);
    final customer=await s.addParty('customer','Return Qty Customer','','');
    final inv=await s.postDocument('sale',customer,nowDate(),[
      ItemLine(doubleSize,10,1000),ItemLine(singleSize,5,500)
    ],0,cash);
    final initial=await lineQuantities(inv);
    final one=initial.first['id'] as int,two=initial.last['id'] as int;
    final r1=await s.postReturn(inv,[ReturnItem(one,3),ReturnItem(two,2)],0,cash,'Partial');
    var rows=await lineQuantities(inv);
    expect(numVal(rows.first['original']),10);
    expect(numVal(rows.first['returned']),3);
    expect(numVal(rows.first['remaining']),7);
    expect(numVal(rows.last['returned']),2);
    expect(numVal(rows.last['remaining']),3);
    final r2=await s.postReturn(inv,[ReturnItem(one,7),ReturnItem(two,3)],0,cash,'Remaining full invoice');
    rows=await lineQuantities(inv);
    expect(rows.every((x)=>numVal(x['remaining'])==0),true);
    expect(await s.count("SELECT count(*) FROM document_returns WHERE document_id=? AND status='POSTED'",[inv]),2);
    await s.voidReturn(r2);
    rows=await lineQuantities(inv);
    expect(numVal(rows.first['remaining']),7);
    expect(numVal(rows.last['remaining']),3);
    final edited=await s.reviseReturn(r1,[ReturnItem(one,4)],0,cash,'Updated single variation');
    expect(edited,r1);
    rows=await lineQuantities(inv);
    expect(numVal(rows.first['remaining']),6);
    expect(numVal(rows.last['remaining']),5);
    expect(await s.count('SELECT count(*) FROM return_revisions WHERE return_id=?',[r1]),1);
    final report=await buildReport(s,ReportFilter(type:'Sales',start:'2000-01-01',end:'2100-12-31'));
    expect(report.headings,contains('Returned_Qty'));
    expect(report.headings,contains('Remaining_Qty'));
    final remainingIndex=report.headings.indexOf('Remaining_Qty');
    expect(report.rows.any((row)=>row.contains('RET-MAT-DOUBLE') && num.tryParse(row[remainingIndex])==6),true);
  });

  test('Purchase: partial and full returns track units and preserve original history',() async {
    final category=await s.addCategory('Return Quantities Purchase');
    final product=await s.addProduct(category,'Floor Roll');
    final roll=await s.addVariant(product,'RET-ROLL','feet',{},0);
    await s.setVariantUnit(roll,'Roll',90,canBuy:true,canSell:true);
    final supplier=await s.addParty('supplier','Return Qty Supplier','','');
    final inv=await s.postDocument('purchase',supplier,nowDate(),[
      ItemLine(roll,2,1200,unit:'Roll',factor:90)
    ],0,cash);
    final line=(await lineQuantities(inv)).first['id'] as int;
    final r=await s.postReturn(inv,[ReturnItem(line,1)],0,cash,'One Roll');
    var qty=(await lineQuantities(inv)).first;
    expect(numVal(qty['original']),2);
    expect(numVal(qty['remaining']),1);
    final report=await buildReport(s,ReportFilter(type:'Purchases',start:'2000-01-01',end:'2100-12-31'));
    expect(report.rows.any((row)=>row.contains('RET-ROLL') && row.contains('Roll')),true);
    final returnReport=await buildReport(s,ReportFilter(type:'Purchase Returns',start:'2000-01-01',end:'2100-12-31'));
    expect(returnReport.headings,contains('Variation'));
    expect(returnReport.rows.any((row)=>row.contains('RET-ROLL') && row.contains('Roll')),true);
    await s.voidReturn(r);
    qty=(await lineQuantities(inv)).first;
    expect(numVal(qty['returned']),0);
    expect(numVal(qty['remaining']),2);
  });
}
