import 'package:flutter/material.dart';
import 'store.dart';

/// Shop dashboard backed by the same SQLite transaction data as the reports.
class AdvancedDashboard extends StatelessWidget {
  final int revision;

  const AdvancedDashboard({super.key, required this.revision});

  Future<List<List<Map<String, Object?>>>> load() async {
    final store = Store.instance;
    return Future.wait([
      store.read(
        "SELECT coalesce(sum(total),0) AS n FROM documents WHERE kind='sale' AND date=? AND status='POSTED'",
        [nowDate()],
      ),
      store.read(
        "SELECT coalesce(sum(total),0) AS n FROM documents WHERE kind='purchase' AND date=? AND status='POSTED'",
        [nowDate()],
      ),
      store.read('SELECT count(*) AS n FROM variants WHERE active=1'),
      store.read(
        'SELECT count(*) AS n FROM ('
        'SELECT v.id FROM variants v LEFT JOIN stock_movements m '
        'ON m.variant_id=v.id GROUP BY v.id '
        'HAVING coalesce(sum(m.qty),0)<=0)',
      ),
      store.read(
        "SELECT coalesce(sum(CASE WHEN p.kind='customer' THEN l.debit-l.credit ELSE 0 END),0) AS n "
        'FROM party_ledger l JOIN parties p ON p.id=l.party_id',
      ),
      store.read(
        "SELECT coalesce(sum(CASE WHEN p.kind='supplier' THEN l.credit-l.debit ELSE 0 END),0) AS n "
        'FROM party_ledger l JOIN parties p ON p.id=l.party_id',
      ),
      store.read(
        "SELECT coalesce(sum(e.amount),0) AS n FROM expenses e WHERE e.date=? "
        "AND NOT EXISTS (SELECT 1 FROM reversed_transactions r WHERE r.kind='expense' AND r.source_id=e.id)",
        [nowDate()],
      ),
      store.read(
        "SELECT date,sum(total) AS total FROM documents WHERE kind='sale' "
        "AND status='POSTED' AND date>=date('now','-13 day') "
        'GROUP BY date ORDER BY date',
      ),
      store.read(
        "SELECT d.invoice,d.date,d.kind,d.total,coalesce(p.name,'Walk-in') AS party "
        'FROM documents d LEFT JOIN parties p ON p.id=d.party_id '
        "WHERE d.status='POSTED' ORDER BY d.id DESC LIMIT 8",
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<List<Map<String, Object?>>>>(
      future: load(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child:Text('Dashboard error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child:CircularProgressIndicator());
        }

        final data = snapshot.data!;
        double metric(int index) => numVal(data[index].first['n']);
        final cards = <({String title, String value, IconData icon, Color color})>[
          (
            title:'Today Sales',
            value:'Rs. ${(metric(0) / 100).toStringAsFixed(0)}',
            icon:Icons.trending_up,
            color:Colors.green,
          ),
          (
            title:'Today Purchases',
            value:'Rs. ${(metric(1) / 100).toStringAsFixed(0)}',
            icon:Icons.shopping_bag_outlined,
            color:Colors.blue,
          ),
          (
            title:'Active Variations',
            value:'${metric(2).toInt()}',
            icon:Icons.inventory_2_outlined,
            color:Colors.indigo,
          ),
          (
            title:'Low / Negative Stock',
            value:'${metric(3).toInt()}',
            icon:Icons.warning_amber,
            color:Colors.deepOrange,
          ),
          (
            title:'Customer Receivables',
            value:'Rs. ${(metric(4) / 100).toStringAsFixed(0)}',
            icon:Icons.people_outline,
            color:Colors.teal,
          ),
          (
            title:'Supplier Payables',
            value:'Rs. ${(metric(5) / 100).toStringAsFixed(0)}',
            icon:Icons.local_shipping,
            color:Colors.purple,
          ),
          (
            title:'Today Expenses',
            value:'Rs. ${(metric(6) / 100).toStringAsFixed(0)}',
            icon:Icons.payments_outlined,
            color:Colors.red,
          ),
        ];

        final amounts = <String, double>{
          for (final row in data[7]) '${row['date']}': numVal(row['total']),
        };
        final values = List.generate(14, (index) {
          final date = DateTime.now()
              .subtract(Duration(days: 13 - index))
              .toIso8601String()
              .substring(0, 10);
          return (date, amounts[date] ?? 0.0);
        });
        final maximum = values.fold<double>(
          1,
          (previous, point) => point.$2 > previous ? point.$2 : previous,
        );

        return ListView(
          padding:const EdgeInsets.all(24),
          children:[
            const Text(
              'Business Overview',
              style:TextStyle(fontSize:25, fontWeight:FontWeight.w900),
            ),
            const SizedBox(height:4),
            const Text(
              'Live shop metrics · offline SQLite',
              style:TextStyle(color:Colors.blueGrey),
            ),
            const SizedBox(height:20),
            Wrap(
              spacing:12,
              runSpacing:12,
              children:cards.map((card) {
                return SizedBox(
                  width:225,
                  child:Card(
                    child:Padding(
                      padding:const EdgeInsets.all(18),
                      child:Column(
                        crossAxisAlignment:CrossAxisAlignment.start,
                        children:[
                          Icon(card.icon, color:card.color),
                          const SizedBox(height:13),
                          Text(
                            card.title,
                            style:const TextStyle(color:Colors.blueGrey, fontSize:12),
                          ),
                          const SizedBox(height:5),
                          Text(
                            card.value,
                            style:const TextStyle(fontWeight:FontWeight.w900, fontSize:21),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height:18),
            Card(
              child:Padding(
                padding:const EdgeInsets.all(20),
                child:Column(
                  crossAxisAlignment:CrossAxisAlignment.start,
                  children:[
                    const Text(
                      'Sales trend · last 14 days',
                      style:TextStyle(fontSize:17, fontWeight:FontWeight.bold),
                    ),
                    const SizedBox(height:12),
                    SizedBox(
                      height:140,
                      child:Row(
                        crossAxisAlignment:CrossAxisAlignment.end,
                        children:values.map((point) {
                          return Expanded(
                            child:Tooltip(
                              message:'${point.$1} · Rs. ${(point.$2 / 100).toStringAsFixed(2)}',
                              child:Padding(
                                padding:const EdgeInsets.symmetric(horizontal:3),
                                child:Container(
                                  height:4 + (120 * point.$2 / maximum),
                                  decoration:BoxDecoration(
                                    color:const Color(0xFF4B63D9),
                                    borderRadius:BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height:17),
            const Text(
              'Recent Transactions',
              style:TextStyle(fontSize:18, fontWeight:FontWeight.bold),
            ),
            const SizedBox(height:8),
            Card(
              child:Column(
                children:data[8].isEmpty
                    ? [const ListTile(title:Text('No transactions yet'))]
                    : data[8].map((row) {
                        return ListTile(
                          leading:Icon(
                            row['kind'] == 'sale'
                                ? Icons.receipt_outlined
                                : Icons.shopping_cart_outlined,
                          ),
                          title:Text('${row['invoice']} · ${row['party']}'),
                          subtitle:Text('${row['date']} · ${row['kind']}'),
                          trailing:Text(
                            'Rs. ${(numVal(row['total']) / 100).toStringAsFixed(2)}',
                            style:const TextStyle(fontWeight:FontWeight.bold),
                          ),
                        );
                      }).toList(),
              ),
            ),
            const SizedBox(height:12),
            const Text(
              'Gross profit is deliberately excluded until verified inventory costing / COGS is implemented.',
              style:TextStyle(color:Colors.blueGrey, fontSize:12),
            ),
          ],
        );
      },
    );
  }
}
