import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'store.dart';
import 'nexa_theme.dart';

/// NexaDash-inspired desktop layout. All figures come from the existing
/// ShopDesk SQLite tables. Refresh: every five seconds and after transactions.
/// Profit is deliberately excluded until stock costing is implemented.
class AdvancedDashboard extends StatefulWidget {
  final int revision;
  const AdvancedDashboard({super.key, required this.revision});
  @override State<AdvancedDashboard> createState() => _AdvancedDashboardState();
}

class _AdvancedDashboardState extends State<AdvancedDashboard> {
  Timer? ticker;
  int rangeDays = 30;
  late Future<List<List<Map<String, Object?>>>> results;
  final colors = const [Nexa.brightBlue, Nexa.purple, Nexa.orange, Nexa.green, Nexa.pink];

  @override void initState() {
    super.initState();
    results = load();
    ticker = Timer.periodic(const Duration(seconds: 5), (_) {
      if(mounted) setState(() => results = load());
    });
  }
  @override void didUpdateWidget(covariant AdvancedDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) results = load();
  }
  @override void dispose() { ticker?.cancel(); super.dispose(); }

  Future<List<List<Map<String, Object?>>>> load() async {
    final s = Store.instance;
    final now = DateTime.now();
    final since = DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: rangeDays - 1)));
    final until = DateFormat('yyyy-MM-dd').format(now);
    return Future.wait([
      s.read("SELECT coalesce(sum(total),0) n FROM documents WHERE kind='sale' AND date>=? AND date<=? AND status='POSTED'",[since,until]),
      s.read("SELECT coalesce(sum(total),0) n FROM documents WHERE kind='purchase' AND date>=? AND date<=? AND status='POSTED'",[since,until]),
      s.read('SELECT count(*) n FROM variants WHERE active=1'),
      s.read('SELECT count(*) n FROM (SELECT v.id FROM variants v LEFT JOIN stock_movements m ON m.variant_id=v.id WHERE v.active=1 GROUP BY v.id HAVING coalesce(sum(m.qty),0)<=0)'),
      s.read("SELECT coalesce(sum(CASE WHEN p.kind='customer' THEN l.debit-l.credit ELSE 0 END),0) n FROM party_ledger l JOIN parties p ON p.id=l.party_id"),
      s.read("SELECT coalesce(sum(CASE WHEN p.kind='supplier' THEN l.credit-l.debit ELSE 0 END),0) n FROM party_ledger l JOIN parties p ON p.id=l.party_id"),
      s.read("SELECT coalesce(sum(e.amount),0) n FROM expenses e WHERE e.date>=? AND e.date<=? AND NOT EXISTS (SELECT 1 FROM reversed_transactions r WHERE r.kind='expense' AND r.source_id=e.id)",[since,until]),
      s.read("SELECT date,kind,sum(total) total FROM documents WHERE status='POSTED' AND date>=? AND date<=? GROUP BY date,kind ORDER BY date",[since,until]),
      s.read("SELECT d.invoice,d.date,d.kind,d.total,d.paid,coalesce(p.name,'Walk-in') party FROM documents d LEFT JOIN parties p ON p.id=d.party_id WHERE d.status='POSTED' ORDER BY d.id DESC LIMIT 6"),
      s.read('SELECT c.name name,coalesce(sum(m.qty),0) qty FROM categories c JOIN products p ON p.category_id=c.id JOIN variants v ON v.product_id=p.id LEFT JOIN stock_movements m ON m.variant_id=v.id GROUP BY c.id ORDER BY abs(qty) DESC LIMIT 6'),
      s.read("SELECT c.name name,coalesce(sum(e.amount),0) amount FROM expenses e JOIN expense_categories c ON e.category_id=c.id WHERE e.date>=? AND e.date<=? AND NOT EXISTS (SELECT 1 FROM reversed_transactions r WHERE r.kind='expense' AND r.source_id=e.id) GROUP BY c.id ORDER BY amount DESC LIMIT 6",[since,until]),
      s.read("SELECT CASE WHEN paid>=total THEN 'Paid' WHEN paid>0 THEN 'Partially Paid' ELSE 'Unpaid' END status,count(*) n FROM documents WHERE kind='sale' AND status='POSTED' GROUP BY 1"),
      s.read("SELECT p.name name,coalesce(sum(l.qty),0) qty,coalesce(sum(l.amount),0) revenue FROM document_lines l JOIN documents d ON d.id=l.document_id JOIN variants v ON v.id=l.variant_id JOIN products p ON p.id=v.product_id WHERE d.kind='sale' AND d.status='POSTED' AND d.date>=? AND d.date<=? GROUP BY p.id ORDER BY qty DESC LIMIT 5",[since,until]),
      s.read("SELECT count(*) n FROM documents WHERE kind='sale' AND date>=? AND date<=? AND status='POSTED'",[since,until]),
      s.read("SELECT c.name name,coalesce(sum(l.amount),0) amount FROM document_lines l JOIN documents d ON d.id=l.document_id JOIN variants v ON v.id=l.variant_id JOIN products p ON p.id=v.product_id JOIN categories c ON c.id=p.category_id WHERE d.kind='sale' AND d.status='POSTED' AND d.date>=? AND d.date<=? GROUP BY c.id ORDER BY amount DESC LIMIT 5",[since,until]),
      s.read("SELECT count(*) n FROM parties WHERE kind='customer'"),
    ]);
  }

  String money(Object? cents) => 'Rs. ${NumberFormat('#,##0').format(numVal(cents)/100)}';
  String number(Object? v) => NumberFormat('#,##0.##').format(numVal(v));

  Widget sectionTitle(String heading, {Widget? trailing}) => Row(children:[
    Expanded(child: Text(heading, style: const TextStyle(color:Nexa.white,fontSize:18,fontWeight:FontWeight.w800))),
    if(trailing!=null)trailing,
  ]);

  Widget statistic(String label, String value, IconData icon, Color tint, String note) => NexaPanel(
    padding: const EdgeInsets.all(18), child: SizedBox(height:102, child:Row(crossAxisAlignment: CrossAxisAlignment.start,children:[
      Container(width:54,height:54,decoration:BoxDecoration(color:tint,borderRadius:BorderRadius.circular(12)),child:Icon(icon,color:Colors.white,size:26)),
      const SizedBox(width:16),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(label,style:const TextStyle(color:Nexa.muted,fontSize:13)),
        const SizedBox(height:8),
        FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,child:Text(value,style:const TextStyle(color:Nexa.white,fontSize:25,fontWeight:FontWeight.w800))),
        const Spacer(),
        Text(note,style:const TextStyle(color:Nexa.secondary,fontSize:11),overflow:TextOverflow.ellipsis),
      ])),
      const Icon(Icons.more_horiz,color:Nexa.secondary,size:17),
    ])));

  Widget panel(String title,Widget body,{String? description})=>NexaPanel(
    child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      sectionTitle(title),if(description!=null)...[const SizedBox(height:5),Text(description,style:const TextStyle(color:Nexa.secondary,fontSize:11))],
      const SizedBox(height:18),body,
    ]),
  );

  Widget barRows(List<Map<String,Object?>> rows,String amountKey,Color shade,{bool inMoney=false}) {
    if(rows.isEmpty)return const Text('No records for this period',style:TextStyle(color:Nexa.muted,fontSize:12));
    final max=rows.fold<double>(1,(v,r)=>math.max(v,numVal(r[amountKey]).abs()));
    return Column(children:rows.map((r){final val=numVal(r[amountKey]);return Padding(
      padding:const EdgeInsets.only(bottom:14),child:Column(children:[
        Row(children:[Expanded(child:Text('${r['name']}',overflow:TextOverflow.ellipsis,style:const TextStyle(color:Nexa.muted,fontSize:12))),Text(inMoney?money(val):number(val),style:const TextStyle(color:Nexa.white,fontSize:12,fontWeight:FontWeight.w600))]),
        const SizedBox(height:8),ClipRRect(borderRadius:BorderRadius.circular(4),child:LinearProgressIndicator(value:val.abs()/max,minHeight:7,color:val<0?Nexa.orange:shade,backgroundColor:Nexa.outline)),
      ]));}).toList());
  }

  Widget donut(List<Map<String,Object?>> categoryRows){
    final categories=categoryRows.where((r)=>numVal(r['amount'])>0).toList();
    final sum=categories.fold<double>(0,(v,r)=>v+numVal(r['amount']));
    return SizedBox(height:240,child:LayoutBuilder(builder:(context,c){
      final horizontal=c.maxWidth>390;
      final chart=SizedBox(width:200,height:200,child:Stack(alignment:Alignment.center,children:[
        CustomPaint(size:const Size(200,200),painter:_DonutPainter(categories.map((e)=>numVal(e['amount'])).toList(),colors)),
        Column(mainAxisSize:MainAxisSize.min,children:[Text(money(sum),style:const TextStyle(color:Nexa.white,fontWeight:FontWeight.w800,fontSize:17)),const Text('Total Sales',style:TextStyle(color:Nexa.muted,fontSize:11))]),
      ]));
      final legend=Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        if(categories.isEmpty)const Text('No sales yet',style:TextStyle(color:Nexa.muted,fontSize:12)),
        for(var i=0;i<categories.length;i++)Padding(padding:const EdgeInsets.symmetric(vertical:7),child:Row(children:[
          Container(width:12,height:12,decoration:BoxDecoration(color:colors[i%colors.length],borderRadius:BorderRadius.circular(4))),
          const SizedBox(width:9),Expanded(child:Text('${categories[i]['name']}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Nexa.muted,fontSize:11))),
          Text('${(100*numVal(categories[i]['amount'])/sum).toStringAsFixed(0)}%',style:const TextStyle(color:Nexa.white,fontWeight:FontWeight.w700,fontSize:11)),
        ])),
      ]);
      return horizontal?Row(children:[Expanded(flex:5,child:Center(child:chart)),const SizedBox(width:16),Expanded(flex:4,child:legend)]):Column(children:[Expanded(child:FittedBox(child:chart)),const SizedBox(height:8),SizedBox(height:80,child:SingleChildScrollView(child:legend))]);
    }));
  }

  Widget recentTable(List<Map<String,Object?>> rows){
    if(rows.isEmpty)return const Padding(padding:EdgeInsets.all(20),child:Text('No sales or purchases yet',style:TextStyle(color:Nexa.muted)));
    return Column(children:[
      const _TableHeader(['Invoice','Customer / Supplier','Type','Amount','Status'],[3,4,2,2,2]),
      for(final r in rows)Container(decoration:const BoxDecoration(border:Border(bottom:BorderSide(color:Nexa.outline,width:.6))),padding:const EdgeInsets.symmetric(vertical:13,horizontal:10),child:Row(children:[
        _cell('${r['invoice']}',3,Nexa.white),_cell('${r['party']}',4,Nexa.muted),
        _cell('${r['kind']}'.toUpperCase(),2,Nexa.muted),
        _cell(money(r['total']),2,Nexa.white),
        Expanded(flex:2,child:Align(alignment:Alignment.centerLeft,child:Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),decoration:BoxDecoration(color:(numVal(r['paid'])>=numVal(r['total'])?Nexa.green:Nexa.orange).withValues(alpha:.16),borderRadius:BorderRadius.circular(14)),child:Text(numVal(r['paid'])>=numVal(r['total'])?'PAID':numVal(r['paid'])>0?'PARTIAL':'UNPAID',style:TextStyle(color:numVal(r['paid'])>=numVal(r['total'])?Nexa.green:Nexa.orange,fontSize:9,fontWeight:FontWeight.w800))))),
      ])),
    ]);
  }
  Widget _cell(String text,int flex,Color c)=>Expanded(flex:flex,child:Text(text,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:c,fontSize:11,fontWeight:FontWeight.w600)));

  Widget topTable(List<Map<String,Object?>> rows){
    if(rows.isEmpty)return const Padding(padding:EdgeInsets.all(20),child:Text('No sales in selected period',style:TextStyle(color:Nexa.muted)));
    return Column(children:[
      const _TableHeader(['#','Product','Units sold','Revenue'],[1,5,2,3]),
      for(var i=0;i<rows.length;i++)Container(decoration:const BoxDecoration(border:Border(bottom:BorderSide(color:Nexa.outline,width:.6))),padding:const EdgeInsets.symmetric(vertical:12,horizontal:10),child:Row(children:[
        _cell('${i+1}',1,Nexa.muted),
        Expanded(flex:5,child:Row(children:[Container(width:26,height:26,decoration:BoxDecoration(color:Nexa.outline,borderRadius:BorderRadius.circular(6)),child:const Icon(Icons.inventory_2_outlined,color:Nexa.muted,size:15)),const SizedBox(width:8),Expanded(child:Text('${rows[i]['name']}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Nexa.white,fontSize:11)))])),
        _cell(number(rows[i]['qty']),2,Nexa.muted),_cell(money(rows[i]['revenue']),3,Nexa.white),
      ])),
    ]);
  }

  @override Widget build(BuildContext context) => FutureBuilder<List<List<Map<String,Object?>>>>(
    future:results,builder:(context,snapshot){
      if(snapshot.hasError)return Center(child:SelectableText('Dashboard data could not load: ${snapshot.error}',style:const TextStyle(color:Nexa.orange)));
      if(!snapshot.hasData)return const Center(child:CircularProgressIndicator(color:Nexa.brightBlue));
      final data=snapshot.data!;
      double metric(int index)=>numVal(data[index].first['n']);
      final sales={for(final r in data[7].where((x)=>x['kind']=='sale')) '${r['date']}':numVal(r['total'])/100};
      final purchases={for(final r in data[7].where((x)=>x['kind']=='purchase')) '${r['date']}':numVal(r['total'])/100};
      final labels=List.generate(rangeDays,(i)=>DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(Duration(days:rangeDays-1-i))));
      final salePoints=labels.map((d)=>sales[d]??0.0).toList();
      final purchasePoints=labels.map((d)=>purchases[d]??0.0).toList();
      return LayoutBuilder(builder:(context,layout){
        final usable=math.max(330.0,layout.maxWidth-44);
        final count=usable>=1060?4:usable>=600?2:1;
        final cardWidth=(usable-12*(count-1))/count;
        final wide=usable>=880;
        final big=wide?(usable-14)*0.59:usable;
        final small=wide?(usable-14)*0.41:usable;
        return Container(decoration:const BoxDecoration(gradient:Nexa.pageGradient),child:ListView(padding:const EdgeInsets.all(22),children:[
          Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('Dashboard',style:TextStyle(color:Nexa.white,fontSize:29,fontWeight:FontWeight.w800)),
            const SizedBox(height:4),const Text('Your shop performance, updated from live SQLite data.',style:TextStyle(color:Nexa.muted,fontSize:13)),
          ])),
            Container(padding:const EdgeInsets.symmetric(horizontal:10),decoration:BoxDecoration(color:Nexa.panel,border:Border.all(color:Nexa.outline),borderRadius:BorderRadius.circular(9)),child:DropdownButtonHideUnderline(child:DropdownButton<int>(value:rangeDays,dropdownColor:Nexa.panel,iconEnabledColor:Nexa.muted,style:const TextStyle(color:Nexa.white,fontSize:12),items:const [DropdownMenuItem(value:7,child:Text('Last 7 Days')),DropdownMenuItem(value:14,child:Text('Last 14 Days')),DropdownMenuItem(value:30,child:Text('Last 30 Days'))],onChanged:(v){if(v!=null)setState((){rangeDays=v;results=load();});}))),
          ]),
          const SizedBox(height:18),
          Wrap(spacing:12,runSpacing:12,children:[
            SizedBox(width:cardWidth,child:statistic('Total Sales',money(metric(0)),Icons.currency_rupee,Nexa.brightBlue,'Selected period')),
            SizedBox(width:cardWidth,child:statistic('Sales Invoices',number(metric(13)),Icons.shopping_cart_outlined,Nexa.green,'Posted sales')),
            SizedBox(width:cardWidth,child:statistic('Customers',number(metric(15)),Icons.people_alt_outlined,Nexa.purple,'Registered customers')),
            SizedBox(width:cardWidth,child:statistic('Total Purchases',money(metric(1)),Icons.trending_up,Nexa.orange,'Selected period')),
          ]),
          const SizedBox(height:16),
          Wrap(spacing:14,runSpacing:14,children:[
            SizedBox(width:big,child:panel('Revenue Overview',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(money(metric(0)),style:const TextStyle(color:Nexa.white,fontSize:27,fontWeight:FontWeight.w800)),
              const SizedBox(height:17),
              SizedBox(height:204,child:CustomPaint(painter:_TrendPainter(salePoints,purchasePoints),child:const SizedBox.expand())),
              const SizedBox(height:11),const Row(children:[_Legend('Sales',Nexa.brightBlue),SizedBox(width:16),_Legend('Purchases',Nexa.green)]),
            ]),description:'Sales and purchase trends over the selected period')),
            SizedBox(width:small,child:panel('Sales by Category',donut(data[14]),description:'Posted sales grouped by product category')),
          ]),
          const SizedBox(height:16),
          Wrap(spacing:14,runSpacing:14,children:[
            SizedBox(width:big,child:panel('Recent Orders',recentTable(data[8]),description:'Most recent posted sales and purchases')),
            SizedBox(width:small,child:panel('Top Selling Products',topTable(data[12]),description:'Most sold products in selected period')),
          ]),
          const SizedBox(height:16),
          Wrap(spacing:14,runSpacing:14,children:[
            SizedBox(width:big,child:panel('Expenses by Category',barRows(data[10],'amount',Nexa.orange,inMoney:true),description:'Expenses in the selected period')),
            SizedBox(width:small,child:panel('Stock & Outstanding',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              _InfoRow('Active SKUs',number(metric(2)),Nexa.brightBlue),
              _InfoRow('Zero / Negative Stock',number(metric(3)),Nexa.orange),
              _InfoRow('Customer Receivables',money(metric(4)),Nexa.green),
              _InfoRow('Supplier Payables',money(metric(5)),Nexa.purple),
              _InfoRow('Expenses',money(metric(6)),Nexa.pink),
            ]),description:'Live stock and ledger balances')),
          ]),
          const SizedBox(height:15),
          const Text('Live business figures refresh every 5 seconds. License countdown refreshes every second. Profit is not shown until COGS is verified.',style:TextStyle(color:Nexa.secondary,fontSize:10)),
        ]));
      });
    },
  );
}

class _Legend extends StatelessWidget {
  final String name;final Color color;
  const _Legend(this.name,this.color);
  @override Widget build(BuildContext context)=>Row(mainAxisSize:MainAxisSize.min,children:[CircleAvatar(radius:4,backgroundColor:color),const SizedBox(width:6),Text(name,style:const TextStyle(color:Nexa.muted,fontSize:11))]);
}
class _InfoRow extends StatelessWidget {
  final String name,value;final Color color;
  const _InfoRow(this.name,this.value,this.color);
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(vertical:10),child:Row(children:[CircleAvatar(radius:5,backgroundColor:color),const SizedBox(width:9),Expanded(child:Text(name,style:const TextStyle(color:Nexa.muted,fontSize:11))),Text(value,style:const TextStyle(color:Nexa.white,fontSize:12,fontWeight:FontWeight.w700))]));
}
class _TableHeader extends StatelessWidget {
  final List<String> columns;final List<int> flexes;
  const _TableHeader(this.columns,this.flexes);
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(vertical:12,horizontal:10),decoration:BoxDecoration(color:Nexa.panelTop,borderRadius:BorderRadius.circular(8)),child:Row(children:[for(var i=0;i<columns.length;i++)Expanded(flex:flexes[i],child:Text(columns[i],style:const TextStyle(color:Nexa.muted,fontSize:10)))]));
}

class _DonutPainter extends CustomPainter {
  final List<double> amounts; final List<Color> colors;
  const _DonutPainter(this.amounts,this.colors);
  @override void paint(Canvas canvas,Size size){
    final center=Offset(size.width/2,size.height/2);
    final radius=math.min(size.width,size.height)*.37;
    final paint=Paint()..style=PaintingStyle.stroke..strokeWidth=28;
    canvas.drawCircle(center,radius,paint..color=Nexa.outline);
    final total=amounts.fold<double>(0,(a,b)=>a+b);
    if(total<=0)return;
    var start=-math.pi/2;
    for(var i=0;i<amounts.length;i++){
      final sweep=math.pi*2*amounts[i]/total;
      canvas.drawArc(Rect.fromCircle(center:center,radius:radius),start,sweep,false,paint..color=colors[i%colors.length]);
      start+=sweep;
    }
  }
  @override bool shouldRepaint(covariant _DonutPainter old)=>!_same(amounts,old.amounts);
  bool _same(List<double> a,List<double> b){if(a.length!=b.length)return false;for(var i=0;i<a.length;i++){if(a[i]!=b[i])return false;}return true;}
}

class _TrendPainter extends CustomPainter {
  final List<double> sales,purchases;
  const _TrendPainter(this.sales,this.purchases);
  @override void paint(Canvas canvas,Size size){
    const left=12.0,right=9.0,top=10.0,bottom=12.0;
    final w=math.max(1.0,size.width-left-right),h=math.max(1.0,size.height-top-bottom);
    final maxValue=math.max(1.0,[...sales,...purchases].fold<double>(1,(v,x)=>math.max(v,x)));
    for(var i=0;i<=4;i++){
      final y=top+i*h/4;
      canvas.drawLine(Offset(left,y),Offset(left+w,y),Paint()..color=Nexa.outline..strokeWidth=1);
    }
    for(var i=0;i<=6;i++){
      final x=left+i*w/6;
      canvas.drawLine(Offset(x,top),Offset(x,top+h),Paint()..color=Nexa.outline.withValues(alpha:.65)..strokeWidth=1);
    }
    Path path(List<double> values){
      final p=Path();
      for(var i=0;i<values.length;i++){
        final pos=Offset(left+i*w/math.max(1,values.length-1),top+h*(1-values[i]/maxValue));
        if(i==0){p.moveTo(pos.dx,pos.dy);}else{p.lineTo(pos.dx,pos.dy);}
      }
      return p;
    }
    final salesPath=path(sales);
    if(sales.isNotEmpty){
      final fill=Path.from(salesPath)..lineTo(left+w,top+h)..lineTo(left,top+h)..close();
      canvas.drawPath(fill,Paint()..shader=LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Nexa.brightBlue.withValues(alpha:.34),Nexa.brightBlue.withValues(alpha:.01)]).createShader(Rect.fromLTWH(left,top,w,h)));
    }
    canvas.drawPath(salesPath,Paint()..color=Nexa.brightBlue..style=PaintingStyle.stroke..strokeWidth=2.8..strokeCap=StrokeCap.round);
    canvas.drawPath(path(purchases),Paint()..color=Nexa.green..style=PaintingStyle.stroke..strokeWidth=1.8..strokeCap=StrokeCap.round);
  }
  @override bool shouldRepaint(covariant _TrendPainter old)=>!_equals(sales,old.sales)||!_equals(purchases,old.purchases);
  bool _equals(List<double> a,List<double> b){if(a.length!=b.length)return false;for(var i=0;i<a.length;i++){if(a[i]!=b[i])return false;}return true;}
}
