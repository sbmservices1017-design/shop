import 'package:flutter/material.dart';
import 'store.dart';

class AdvancedDashboard extends StatelessWidget {
  final int revision;const AdvancedDashboard({super.key,required this.revision});
  Future<List<List<Map<String,Object?>>>> load() async {
    final s=Store.instance;return Future.wait([
      s.read("SELECT coalesce(sum(total),0) AS n FROM documents WHERE kind='sale' AND date=? AND status='POSTED'",[nowDate()]),
      s.read("SELECT coalesce(sum(total),0) AS n FROM documents WHERE kind='purchase' AND date=? AND status='POSTED'",[nowDate()]),
      s.read('SELECT count(*) AS n FROM variants WHERE active=1'),
      s.read('SELECT count(*) AS n FROM (SELECT v.id FROM variants v LEFT JOIN stock_movements m ON m.variant_id=v.id GROUP BY v.id HAVING coalesce(sum(m.qty),0)<=0)'),
      s.read("SELECT coalesce(sum(CASE WHEN p.kind='customer' THEN l.debit-l.credit ELSE 0 END),0) AS n FROM party_ledger l JOIN parties p ON p.id=l.party_id"),
      s.read("SELECT coalesce(sum(CASE WHEN p.kind='supplier' THEN l.credit-l.debit ELSE 0 END),0) AS n FROM party_ledger l JOIN parties p ON p.id=l.party_id"),
      s.read("SELECT coalesce(sum(e.amount),0) AS n FROM expenses e WHERE e.date=? AND NOT EXISTS (SELECT 1 FROM reversed_transactions r WHERE r.kind='expense' AND r.source_id=e.id)",[nowDate()]),
      s.read("SELECT date,sum(total) AS total FROM documents WHERE kind='sale' AND status='POSTED' AND date>=date('now','-13 day') GROUP BY date ORDER BY date"),
      s.read("SELECT d.invoice,d.date,d.kind,d.total,coalesce(p.name,'Walk-in') AS party FROM documents d LEFT JOIN parties p ON p.id=d.party_id WHERE d.status='POSTED' ORDER BY d.id DESC LIMIT 8")
    ]);
  }
  @override Widget build(BuildContext context)=>FutureBuilder<List<List<Map<String,Object?>>>>(future:load(),builder:(ctx,snap){
    if(snap.hasError)return Center(child:Text('Dashboard error: ${snap.error}'));
    if(!snap.hasData)return const Center(child:CircularProgressIndicator());
    final d=snap.data!;
    num value(int i)=numVal(d[i].first['n']);
    final cards=<({String title,String value,IconData icon,Color color})>[
      (title:'Today Sales',value:'Rs. ${(value(0)/100).toStringAsFixed(0)}',icon:Icons.trending_up,color:Colors.green),
      (title:'Today Purchases',value:'Rs. ${(value(1)/100).toStringAsFixed(0)}',icon:Icons.shopping_bag_outlined,color:Colors.blue),
      (title:'Active Variations',value:'${value(2).toInt()}',icon:Icons.inventory_2_outlined,color:Colors.indigo),
      (title:'Low / Negative Stock',value:'${value(3).toInt()}',icon:Icons.warning_amber,color:Colors.deepOrange),
      (title:'Customer Receivables',value:'Rs. ${(value(4)/100).toStringAsFixed(0)}',icon:Icons.people_outline,color:Colors.teal),
      (title:'Supplier Payables',value:'Rs. ${(value(5)/100).toStringAsFixed(0)}',icon:Icons.local_shipping,color:Colors.purple),
      (title:'Today Expenses',value:'Rs. ${(value(6)/100).toStringAsFixed(0)}',icon:Icons.payments_outlined,color:Colors.red)
    ];
    final amounts={for(final r in d[7])'${r['date']}':numVal(r['total'])};
    final values=List.generate(14,(i){final key=DateTime.now().subtract(Duration(days:13-i)).toIso8601String().substring(0,10);return (key,amounts[key]??0.0);});
    final maxAmount=values.fold<double>(1,(a,x)=>x.$2>a?x.$2:a);
    return ListView(padding:const EdgeInsets.all(24),children:[
      const Text('Business Overview',style:TextStyle(fontSize:25,fontWeight:FontWeight.w900)),const SizedBox(height:4),const Text('Live shop metrics · offline SQLite',style:TextStyle(color:Colors.blueGrey)),const SizedBox(height:20),
      Wrap(spacing:12,runSpacing:12,children:cards.map((c)=>SizedBox(width:225,child:Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(c.icon,color:c.color),const SizedBox(height:13),Text(c.title,style:const TextStyle(color:Colors.blueGrey,fontSize:12)),const SizedBox(height:5),Text(c.value,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:21))]))))).toList()),
      const SizedBox(height:18),
      Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Sales trend · last 14 days',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold)),
          const SizedBox(height:12),
          SizedBox(height:140,child:Row(crossAxisAlignment:CrossAxisAlignment.end,
            children:values.map((v)=>Expanded(child:Tooltip(
              message:'${v.$1} · Rs. ${(v.$2/100).toStringAsFixed(2)}',
              child:Padding(padding:const EdgeInsets.symmetric(horizontal:3),
                child:Container(height:4+120*v.$2/maxAmount,
                  decoration:BoxDecoration(color:const Color(0xFF4B63D9),borderRadius:BorderRadius.circular(4)))
              )))).toList()))
        ]))),
      const SizedBox(height:17),const Text('Recent Transactions',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),const SizedBox(height:8),
      Card(child:Column(children:d[8].isEmpty?[const ListTile(title:Text('No transactions yet'))]:d[8].map((r)=>ListTile(leading:Icon(r['kind']=='sale'?Icons.receipt_outlined:Icons.shopping_cart_outlined),title:Text('${r['invoice']} · ${r['party']}'),subtitle:Text('${r['date']} · ${r['kind']}'),trailing:Text('Rs. ${(numVal(r['total'])/100).toStringAsFixed(2)}',style:const TextStyle(fontWeight:FontWeight.bold)))).toList())),
      const SizedBox(height:12),const Text('Gross profit is deliberately excluded until verified inventory costing / COGS is implemented.',style:TextStyle(color:Colors.blueGrey,fontSize:12))
    ]);
  });
}
