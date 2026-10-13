import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'store.dart';
import 'license_widgets.dart';

/// Real-time local dashboard: refreshes from SQLite every 5 seconds.
/// Financial margin/COGS is intentionally not claimed without verified costing.
class AdvancedDashboard extends StatefulWidget {
  final int revision;
  const AdvancedDashboard({super.key,required this.revision});
  @override State<AdvancedDashboard> createState()=>_AdvancedDashboardState();
}
class _AdvancedDashboardState extends State<AdvancedDashboard>{
  Timer? ticker;
  late Future<List<List<Map<String,Object?>>>> future;
  @override void initState(){super.initState();future=load();ticker=Timer.periodic(const Duration(seconds:5),(_){if(mounted)setState(()=>future=load());});}
  @override void didUpdateWidget(covariant AdvancedDashboard oldWidget){super.didUpdateWidget(oldWidget);if(oldWidget.revision!=widget.revision)future=load();}
  @override void dispose(){ticker?.cancel();super.dispose();}
  Future<List<List<Map<String,Object?>>>> load()async {
    final s=Store.instance;
    final today=nowDate();
    final since=DateTime.now().subtract(const Duration(days:13)).toIso8601String().substring(0,10);
    return Future.wait([
      s.read("SELECT coalesce(sum(total),0) n FROM documents WHERE kind='sale' AND date=? AND status='POSTED'",[today]),
      s.read("SELECT coalesce(sum(total),0) n FROM documents WHERE kind='purchase' AND date=? AND status='POSTED'",[today]),
      s.read('SELECT count(*) n FROM variants WHERE active=1'),
      s.read('SELECT count(*) n FROM (SELECT v.id FROM variants v LEFT JOIN stock_movements m ON m.variant_id=v.id WHERE v.active=1 GROUP BY v.id HAVING coalesce(sum(m.qty),0)<=0)'),
      s.read("SELECT coalesce(sum(CASE WHEN p.kind='customer' THEN l.debit-l.credit ELSE 0 END),0) n FROM party_ledger l JOIN parties p ON p.id=l.party_id"),
      s.read("SELECT coalesce(sum(CASE WHEN p.kind='supplier' THEN l.credit-l.debit ELSE 0 END),0) n FROM party_ledger l JOIN parties p ON p.id=l.party_id"),
      s.read("SELECT coalesce(sum(e.amount),0) n FROM expenses e WHERE e.date=? AND NOT EXISTS (SELECT 1 FROM reversed_transactions r WHERE r.kind='expense' AND r.source_id=e.id)",[today]),
      s.read("SELECT date,kind,sum(total) total FROM documents WHERE status='POSTED' AND date>=? GROUP BY date,kind ORDER BY date",[since]),
      s.read("SELECT d.invoice,d.date,d.kind,d.total,coalesce(p.name,'Walk-in') party FROM documents d LEFT JOIN parties p ON p.id=d.party_id WHERE d.status='POSTED' ORDER BY d.id DESC LIMIT 7"),
      s.read('SELECT c.name name,coalesce(sum(m.qty),0) qty FROM categories c JOIN products p ON p.category_id=c.id JOIN variants v ON v.product_id=p.id LEFT JOIN stock_movements m ON m.variant_id=v.id GROUP BY c.id ORDER BY abs(qty) DESC LIMIT 6'),
      s.read("SELECT c.name name,coalesce(sum(e.amount),0) amount FROM expenses e JOIN expense_categories c ON e.category_id=c.id WHERE e.date>=date('now','start of month') AND NOT EXISTS (SELECT 1 FROM reversed_transactions r WHERE r.kind='expense' AND r.source_id=e.id) GROUP BY c.id ORDER BY amount DESC LIMIT 6"),
      s.read("SELECT CASE WHEN paid>=total THEN 'Paid' WHEN paid>0 THEN 'Partially Paid' ELSE 'Unpaid' END status,count(*) n FROM documents WHERE kind='sale' AND status='POSTED' GROUP BY 1"),
      s.read("SELECT p.name name,coalesce(sum(l.qty),0) qty FROM document_lines l JOIN documents d ON d.id=l.document_id JOIN variants v ON v.id=l.variant_id JOIN products p ON p.id=v.product_id WHERE d.kind='sale' AND d.status='POSTED' GROUP BY p.id ORDER BY qty DESC LIMIT 5"),
      s.read("SELECT count(*) n FROM documents WHERE kind='sale' AND date=? AND status='POSTED'",[today]),
    ]);
  }
  String rs(Object? amount)=>'Rs. ${(numVal(amount)/100).toStringAsFixed(0)}';
  Widget card(String title,String value,IconData icon,Color color,{String? sub})=>Container(
    width:225,padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18),border:Border.all(color:const Color(0xffe9edf5))),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:color.withValues(alpha:0.1),borderRadius:BorderRadius.circular(12)),child:Icon(icon,color:color,size:22)),
      const SizedBox(height:13),Text(title,style:const TextStyle(color:Color(0xff758199),fontSize:12,fontWeight:FontWeight.w600)),
      const SizedBox(height:5),Text(value,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:Color(0xff1b2940))),
      if(sub!=null)...[const SizedBox(height:4),Text(sub,style:const TextStyle(fontSize:10,color:Colors.blueGrey))]
    ]));
  Widget surface(String title,Widget child,{String? subtitle})=>Container(
    padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(17),border:Border.all(color:const Color(0xffe9edf5))),
    child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Text(title,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800)),
      if(subtitle!=null)...[const SizedBox(height:4),Text(subtitle,style:const TextStyle(color:Colors.blueGrey,fontSize:11))],
      const SizedBox(height:16),child]));
  Widget bars(List<Map<String,Object?>> rows,String amountField,Color shade,{bool currency=false}){
    final max=rows.fold<double>(1,(v,r)=>math.max(v,numVal(r[amountField]).abs()));
    if(rows.isEmpty)return const Text('No transactions yet.',style:TextStyle(color:Colors.blueGrey));
    return Column(children:rows.map((r){final val=numVal(r[amountField]);
      return Padding(padding:const EdgeInsets.only(bottom:13),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Expanded(child:Text('${r['name']}',overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600))),const SizedBox(width:8),Text(currency?rs(val):val.toStringAsFixed(1),style:const TextStyle(fontSize:11,color:Colors.blueGrey))]),
        const SizedBox(height:6),ClipRRect(borderRadius:BorderRadius.circular(4),child:LinearProgressIndicator(value:val.abs()/max,minHeight:8,color:val<0?Colors.deepOrange:shade,backgroundColor:const Color(0xffeef2fa)))
      ]));}).toList());
  }
  @override Widget build(BuildContext context)=>FutureBuilder<List<List<Map<String,Object?>>>>(future:future,builder:(context,snapshot){
    if(snapshot.hasError)return Center(child:SelectableText('Dashboard data could not load: ${snapshot.error}'));
    if(!snapshot.hasData)return const Center(child:CircularProgressIndicator());
    final data=snapshot.data!;
    double metric(int index)=>numVal(data[index].first['n']);
    final sales={for(final row in data[7].where((x)=>x['kind']=='sale'))'${row['date']}':numVal(row['total'])/100};
    final purchases={for(final row in data[7].where((x)=>x['kind']=='purchase'))'${row['date']}':numVal(row['total'])/100};
    final labels=List.generate(14,(i)=>DateTime.now().subtract(Duration(days:13-i)).toIso8601String().substring(0,10));
    final salePoints=labels.map((d)=>sales[d]??0.0).toList();
    final purchasePoints=labels.map((d)=>purchases[d]??0.0).toList();
    final paymentRows=data[11];
    final cardItems=[
      ('Today Sales',rs(metric(0)),Icons.trending_up_rounded,const Color(0xff2ca979),'Confirmed invoices'),
      ('Today Purchases',rs(metric(1)),Icons.shopping_bag_outlined,const Color(0xff5267e7),'Purchase invoices'),
      ('Today Expenses',rs(metric(6)),Icons.account_balance_wallet_outlined,const Color(0xffe99a3b),'Expense entries'),
      ('Invoices Today','${metric(13).toInt()}',Icons.receipt_long_outlined,const Color(0xff9772e2),'Sales count'),
      ('Product Variants','${metric(2).toInt()}',Icons.inventory_2_outlined,const Color(0xff337bb8),'Active SKUs'),
      ('Low / Negative','${metric(3).toInt()}',Icons.warning_amber_outlined,const Color(0xffef7559),'Zero or below'),
      ('Customer Due',rs(metric(4)),Icons.people_outline,const Color(0xff17a6a6),'Outstanding ledger'),
      ('Supplier Due',rs(metric(5)),Icons.local_shipping_outlined,const Color(0xff9654c6),'Outstanding ledger'),
    ];
    return LayoutBuilder(builder:(context,layout){
      final innerWidth=math.max(350.0,layout.maxWidth-48);
      final width=innerWidth>=960?(innerWidth-12)/2:innerWidth;
      return ListView(padding:const EdgeInsets.all(24),children:[
        Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xff182743),Color(0xff334f94)]),borderRadius:BorderRadius.circular(20)),
          child:Wrap(crossAxisAlignment:WrapCrossAlignment.center,runSpacing:12,spacing:25,alignment:WrapAlignment.spaceBetween,children:[
            const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Business Overview',style:TextStyle(color:Colors.white,fontSize:25,fontWeight:FontWeight.w900)),
              SizedBox(height:6),Text('Live inventory • Sales • Purchases • Accounts',style:TextStyle(color:Color(0xffd3def6),fontSize:12))]),
            const LicenseCountdown(),
          ])),
        const SizedBox(height:20),
        Wrap(spacing:12,runSpacing:12,children:cardItems.map((c)=>card(c.$1,c.$2,c.$3,c.$4,sub:c.$5)).toList()),
        const SizedBox(height:18),
        Wrap(spacing:12,runSpacing:12,children:[
          SizedBox(width:width,child:surface('Sales vs Purchases',Column(children:[
            SizedBox(height:205,child:CustomPaint(painter:_TrendPainter(salePoints,purchasePoints),child:const SizedBox.expand())),
            const SizedBox(height:9),const Row(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(Icons.circle,size:9,color:Color(0xff5267e7)),SizedBox(width:5),Text('Sales',style:TextStyle(fontSize:11)),SizedBox(width:20),Icon(Icons.circle,size:9,color:Color(0xff2ca979)),SizedBox(width:5),Text('Purchases',style:TextStyle(fontSize:11))]),
          ]),subtitle:'Last 14 days · live from posted invoices')),
          SizedBox(width:width,child:surface('Stock by Category',bars(data[9],'qty',const Color(0xff5972e9)),subtitle:'Current units by category · orange bars indicate negative stock')),
          SizedBox(width:width,child:surface('Expenses by Category',bars(data[10],'amount',const Color(0xffe99a3b),currency:true),subtitle:'This month')),
          SizedBox(width:width,child:surface('Payment Status',Column(children:[...paymentRows.map((r)=>ListTile(dense:true,contentPadding:EdgeInsets.zero,leading:Icon(r['status']=='Paid'?Icons.check_circle:r['status']=='Partially Paid'?Icons.timelapse:Icons.pending_outlined,color:r['status']=='Paid'?Colors.green:Colors.orange),title:Text('${r['status']}'),trailing:Text('${r['n']} bills',style:const TextStyle(fontWeight:FontWeight.w700)))),if(paymentRows.isEmpty)const Text('No bills yet')]),subtitle:'Sales invoice payment breakdown')),
          SizedBox(width:width,child:surface('Top Selling Products',bars(data[12],'qty',const Color(0xff26a6a8)),subtitle:'Units sold (all time)')),
          SizedBox(width:width,child:surface('Customer vs Supplier Outstanding',Column(children:[bars([
            {'name':'Customer receivables','amount':metric(4)},
            {'name':'Supplier payables','amount':metric(5)}], 'amount',const Color(0xff5972e9),currency:true)]),subtitle:'From customer & supplier ledgers')),
        ]),
        const SizedBox(height:18),surface('Recent Sales & Purchases',data[8].isEmpty?const Text('No transactions yet'):Column(children:data[8].map((r)=>ListTile(
          leading:CircleAvatar(backgroundColor:const Color(0xffedf2fc),child:Icon(r['kind']=='sale'?Icons.point_of_sale:Icons.shopping_cart_outlined,size:19,color:const Color(0xff5267e7))),
          title:Text('${r['invoice']}   •   ${r['party']}',style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600)),
          subtitle:Text('${r['date']}  ·  ${r['kind']}',style:const TextStyle(fontSize:11)),trailing:Text(rs(r['total']),style:const TextStyle(fontWeight:FontWeight.w800,fontSize:12)))).toList())),
        const SizedBox(height:15),const Text('Business amounts and stock refresh automatically every 5 seconds. License countdown updates every second. Profit/COGS is not shown until costing is verified.',style:TextStyle(color:Colors.blueGrey,fontSize:11))
      ]);
    });
  });
}

class _TrendPainter extends CustomPainter {
  final List<double> sales,purchases;
  const _TrendPainter(this.sales,this.purchases);
  @override void paint(Canvas canvas,Size size){
    final paint=Paint()..style=PaintingStyle.stroke..strokeWidth=2.5..strokeCap=StrokeCap.round;
    final bounds=math.max(1.0,[...sales,...purchases].fold<double>(1,(a,b)=>math.max(a,b)));
    const pad=16.0;final width=math.max(1.0,size.width-pad*2),height=math.max(1.0,size.height-pad*2);
    for(var i=0;i<5;i++){
      final y=pad+i*height/4;
      canvas.drawLine(Offset(pad,y),Offset(size.width-pad,y),Paint()..color=const Color(0xffe8ecf4)..strokeWidth=1);
    }
    void draw(List<double> values,Color color){
      if(values.isEmpty)return;
      final path=Path();
      for(var i=0;i<values.length;i++){
        final point=Offset(pad+i*width/math.max(1,values.length-1),pad+height*(1-values[i]/bounds));
        if(i==0){path.moveTo(point.dx,point.dy);}else{path.lineTo(point.dx,point.dy);}
      }
      paint.color=color;canvas.drawPath(path,paint);
    }
    draw(sales,const Color(0xff5267e7));draw(purchases,const Color(0xff2ca979));
  }
  @override bool shouldRepaint(covariant _TrendPainter old)=>old.sales!=sales ||old.purchases!=purchases;
}
