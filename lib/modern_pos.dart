import 'package:flutter/material.dart';
import 'store.dart';
import 'reporting.dart';
import 'commercial_core.dart';

class ModernPosScreen extends StatefulWidget {
  final String kind;final VoidCallback onChange;
  final Future<void> Function(int invoiceId)? onCorrectInvoice;
  const ModernPosScreen({super.key,required this.kind,required this.onChange,this.onCorrectInvoice});
  @override State<ModernPosScreen> createState()=>_ModernPosScreenState();
}
class _CartRow{
  final Map<String,Object?> product;
  final qty=TextEditingController(text:'1');
  final price=TextEditingController(text:'0');
  _CartRow(this.product);
  void dispose(){qty.dispose();price.dispose();}
}
class _ModernPosScreenState extends State<ModernPosScreen>{
  final store=Store.instance;
  final search=TextEditingController(),paid=TextEditingController(text:'0'),notes=TextEditingController();
  List<Map<String,Object?>> catalog=[];Map<int,String> parties={};Map<int,String> accounts={};
  final cart=<_CartRow>[];
  String category='All',date=nowDate();int? partyId,accountId;bool busy=false,history=false;String? error;
  bool get sale=>widget.kind=='sale';
  @override void initState(){super.initState();load();}
  @override void dispose(){search.dispose();paid.dispose();notes.dispose();for(final row in cart)row.dispose();super.dispose();}
  Future<void> load()async{
    final c=await store.stock();
    final p=await store.read('SELECT id,name FROM parties WHERE kind=? AND active=1 ORDER BY name',[sale?'customer':'supplier']);
    final a=await store.read("SELECT id,name FROM accounts WHERE active=1 AND code IN ('1000','1010') ORDER BY id");
    if(!mounted)return;
    setState((){
      catalog=c;parties={for(final x in p)x['id'] as int:'${x['name']}'};
      accounts={for(final x in a)x['id'] as int:'${x['name']}'};
      accountId??=accounts.isEmpty?null:accounts.keys.first;
      if(!sale)partyId??=parties.isEmpty?null:parties.keys.first;
    });
  }
  double get total=>cart.fold<double>(0,(v,r)=>v+(double.tryParse(r.qty.text)??0)*(double.tryParse(r.price.text)??0));
  double get payment=>double.tryParse(paid.text)??0;
  String get paymentLabel=>payment>=total&&total>0?'PAID':payment>0?'PARTIALLY PAID':'UNPAID';
  void add(Map<String,Object?> entry){
    final row=cart.where((x)=>x.product['id']==entry['id']);
    if(row.isNotEmpty){final r=row.first;r.qty.text='${(double.tryParse(r.qty.text)??0)+1}';setState((){});}
    else{setState(()=>cart.add(_CartRow(entry)));}
  }
  String money(double n)=>'Rs. ${n.toStringAsFixed(2)}';
  Future<void> submit()async{
    if(busy)return;
    setState((){busy=true;error=null;});
    try{
      if(CommercialCore.instance.current?.allowed(sale?'Sales / Billing':'Purchases','create')!=true)throw StateError('You do not have permission to create invoices');
      if(cart.isEmpty)throw const FormatException('Add at least one product');
      if(accountId==null)throw const FormatException('Choose Cash or Bank account');
      if(!sale && partyId==null)throw const FormatException('Select a supplier');
      final lines=cart.map((r)=>ItemLine(r.product['id'] as int,double.parse(r.qty.text),double.parse(r.price.text))).toList();
      if(lines.any((x)=>x.rate<0||x.qty<=0))throw const FormatException('Quantity must be positive; price cannot be negative');
      if(payment<0 || payment>total)throw const FormatException('Payment cannot exceed bill total');
      if(sale && partyId==null && payment<total)throw const FormatException('Select a customer when payment is partially or fully on credit');
      final id=await store.postDocument(widget.kind,partyId,date,lines,payment,accountId!,notes:notes.text);
      if(!mounted)return;
      final savedStatus=paymentLabel;
      final saved=List<_CartRow>.of(cart);
      setState((){cart.clear();paid.text='0';notes.clear();error=null;});
      for(final r in saved)r.dispose();
      await load();
      if(!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('${sale?'Sale':'Purchase'} #$id saved · stock updated · $savedStatus')));
      final printNow=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Invoice saved'),content:const Text('Do you want to print the A4 invoice now?'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Not now')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Print A4'))]));
      if(printNow==true){
        final items=await store.read('''SELECT p.name AS Product,v.sku AS SKU,l.qty AS Quantity,l.rate/100.0 AS Rate,l.amount/100.0 AS Amount
          FROM document_lines l JOIN variants v ON v.id=l.variant_id JOIN products p ON p.id=v.product_id WHERE l.document_id=?''',[id]);
        await Exports.pdf(ReportResult('${sale?'Sale':'Purchase'} Invoice #$id',const ['Product','SKU','Quantity','Rate','Amount'],items.map((m)=>['${m['Product']}','${m['SKU']}','${m['Quantity']}','${m['Rate']}','${m['Amount']}']).toList()),print:true);
      }
      widget.onChange();
    }catch(e){if(mounted)setState(()=>error='$e');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context){
    final query=search.text.toLowerCase();
    final filtered=catalog.where((p)=>(category=='All'||p['category']==category)&&('${p['product']} ${p['sku']} ${p['attrs']}').toLowerCase().contains(query)).toList();
    final cats=['All',...{for(final p in catalog)'${p['category']}'}];
    return LayoutBuilder(builder:(ctx,layout)=>Padding(padding:const EdgeInsets.all(20),child:Column(children:[
      Row(children:[Icon(sale?Icons.point_of_sale:Icons.local_shipping_outlined,color:const Color(0xFF4B63D9),size:26),const SizedBox(width:10),Expanded(child:Text(sale?'Sales POS · Manual Billing':'Purchase POS · Stock In',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800))),TextButton.icon(onPressed:()=>setState(()=>history=!history),icon:Icon(history?Icons.shopping_cart:Icons.history),label:Text(history?'Back to POS':'Invoice History'))]),const SizedBox(height:12),
      if(history)Expanded(child:_HistoryPane(kind:widget.kind,onBack:()=>setState(()=>history=false),onChange:widget.onChange,onCorrectInvoice:widget.onCorrectInvoice))
      else Expanded(child:layout.maxWidth>1000?Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(flex:6,child:catalogPane(filtered,cats)),const SizedBox(width:14),Expanded(flex:5,child:cartPane())]):ListView(children:[SizedBox(height:400,child:catalogPane(filtered,cats)),const SizedBox(height:12),SizedBox(height:650,child:cartPane())]))
    ])));
  }
  Widget catalogPane(List<Map<String,Object?>> filtered,List<String> categories)=>Card(child:Padding(padding:const EdgeInsets.all(15),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    TextField(controller:search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),labelText:'Search product, variation, SKU, design')),const SizedBox(height:12),
    SizedBox(height:48,child:ListView(scrollDirection:Axis.horizontal,children:categories.map((c)=>Padding(padding:const EdgeInsets.only(right:8),child:ChoiceChip(label:Text(c),selected:c==category,onSelected:(_)=>setState(()=>category=c)))).toList())),
    const SizedBox(height:6),Expanded(child:filtered.isEmpty?const Center(child:Text('No matching variations')):ListView.builder(itemCount:filtered.length,itemBuilder:(ctx,i){final p=filtered[i];final qty=numVal(p['qty']);return Card(color:const Color(0xFFF6F8FD),child:ListTile(onTap:()=>add(p),title:Text('${p['product']} • ${p['sku']}',style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text('${p['attrs']??'No attributes'}\nStock: $qty ${p['unit']} · ${p['category']}',style:TextStyle(color:qty<0?Colors.deepOrange:Colors.blueGrey)),isThreeLine:true,trailing:const Icon(Icons.add_circle,color:Color(0xFF4B63D9))));}))
  ])));
  Widget cartPane()=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Row(children:[Expanded(child:Text('Bill Cart · ${cart.length} SKU',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800))),Text(paymentLabel,style:TextStyle(fontWeight:FontWeight.w800,fontSize:11,color:paymentLabel=='PAID'?Colors.green:Colors.deepOrange))]),const SizedBox(height:9),
    Expanded(child:cart.isEmpty?const Center(child:Text('Select a product from the left')):ListView(children:[for(final row in cart)Card(color:const Color(0xFFF9FAFD),child:Padding(padding:const EdgeInsets.all(9),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Expanded(child:Text('${row.product['product']} · ${row.product['sku']}',style:const TextStyle(fontWeight:FontWeight.bold))),IconButton(onPressed:(){setState(()=>cart.remove(row));row.dispose();},icon:const Icon(Icons.close,size:18))]),
      Text('Variation: ${row.product['attrs']??'Standard'}',style:const TextStyle(color:Colors.blueGrey,fontSize:11)),const SizedBox(height:6),Row(children:[Expanded(child:TextField(controller:row.qty,decoration:const InputDecoration(labelText:'Quantity'),keyboardType:TextInputType.number,onChanged:(_)=>setState((){}))),const SizedBox(width:8),Expanded(child:TextField(controller:row.price,decoration:InputDecoration(labelText:sale?'Manual selling rate':'Purchase rate'),keyboardType:TextInputType.number,onChanged:(_)=>setState((){})))]),const SizedBox(height:5),Align(alignment:Alignment.centerRight,child:Text(money((double.tryParse(row.qty.text)??0)*(double.tryParse(row.price.text)??0)),style:const TextStyle(fontWeight:FontWeight.bold)))
    ])))])),const Divider(),
    DropdownButtonFormField<int?>(value:partyId,isExpanded:true,decoration:InputDecoration(labelText:sale?'Customer':'Supplier'),items:[if(sale)const DropdownMenuItem<int?>(value:null,child:Text('Walk-in (fully paid only)')),...parties.entries.map((e)=>DropdownMenuItem<int?>(value:e.key,child:Text(e.value,overflow:TextOverflow.ellipsis)))],onChanged:(v)=>setState(()=>partyId=v)),const SizedBox(height:8),
    DropdownButtonFormField<int>(value:accountId,decoration:const InputDecoration(labelText:'Payment account'),items:accounts.entries.map((e)=>DropdownMenuItem<int>(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setState(()=>accountId=v)),const SizedBox(height:8),
    Row(children:[Expanded(child:TextFormField(initialValue:date,decoration:const InputDecoration(labelText:'Invoice date YYYY-MM-DD'),onChanged:(v)=>date=v)),const SizedBox(width:8),Expanded(child:TextField(controller:notes,decoration:const InputDecoration(labelText:'Notes (optional)')))]),const SizedBox(height:8),
    Row(children:[Expanded(child:TextField(controller:paid,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Paid now (Rs.)'),onChanged:(_)=>setState((){}))),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.end,children:[const Text('Total amount',style:TextStyle(color:Colors.blueGrey,fontSize:11)),Text(money(total),style:const TextStyle(fontWeight:FontWeight.w900,fontSize:20)),Text('Balance: ${money(total-payment)}',style:const TextStyle(fontSize:11))]))]),
    if(error!=null)Padding(padding:const EdgeInsets.all(7),child:Text(error!,style:const TextStyle(color:Colors.red,fontSize:12))),const SizedBox(height:9),
    FilledButton.icon(onPressed:busy || CommercialCore.instance.current?.allowed(sale?'Sales / Billing':'Purchases','create')!=true?null:submit,icon:const Icon(Icons.check_circle_outline),label:Padding(padding:const EdgeInsets.all(10),child:Text(busy?'Saving...':sale?'Save Sale & Deduct Stock':'Save Purchase & Add Stock'))),
    const SizedBox(height:4),const Text('Negative stock allowed. Rate is entered manually for every bill.',style:TextStyle(fontSize:10,color:Colors.blueGrey),textAlign:TextAlign.center)
  ])));
}

class _HistoryPane extends StatelessWidget {
  final String kind;final VoidCallback onBack,onChange;
  final Future<void> Function(int invoiceId)? onCorrectInvoice;
  const _HistoryPane({required this.kind,required this.onBack,required this.onChange,this.onCorrectInvoice});
  Future<void> reprint(int id)async{
    final rows=await Store.instance.read('''SELECT p.name AS Product,v.sku AS SKU,l.qty AS Quantity,l.rate/100.0 AS Rate,l.amount/100.0 AS Amount
      FROM document_lines l JOIN variants v ON v.id=l.variant_id JOIN products p ON p.id=v.product_id WHERE l.document_id=?''',[id]);
    await Exports.pdf(ReportResult('Invoice #$id',const ['Product','SKU','Quantity','Rate','Amount'],rows.map((r)=>['${r['Product']}','${r['SKU']}','${r['Quantity']}','${r['Rate']}','${r['Amount']}']).toList()),print:true);
  }
  @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,Object?>>>(future:Store.instance.read('''SELECT d.*,coalesce(p.name,'Walk-in') AS party FROM documents d LEFT JOIN parties p ON p.id=d.party_id WHERE d.kind=? ORDER BY d.id DESC LIMIT 150''',[kind]),builder:(ctx,snap){
    if(!snap.hasData)return const Center(child:CircularProgressIndicator());
    return Card(child:ListView(children:[
      ListTile(title:const Text('Recent invoices',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),trailing:TextButton(onPressed:onBack,child:const Text('New invoice'))),
      ...snap.data!.map((d){
        final total=rupees(d['total']);final paid=rupees(d['paid']);
        final module=kind=='sale'?'Sales / Billing':'Purchases';
        return ListTile(
          title:Text('${d['invoice']} · ${d['party']}'),
          subtitle:Text('${d['date']} · ${d['status']} · ${paid>=total?'Paid':paid>0?'Partially Paid':'Unpaid'} · Rs. ${total.toStringAsFixed(2)}'),
          trailing:Wrap(spacing:2,children:[
            IconButton(tooltip:'Reprint invoice',onPressed:()=>reprint(d['id'] as int),icon:const Icon(Icons.print)),
            if(d['status']=='POSTED'&&CommercialCore.instance.current?.allowed(module,'edit')==true && onCorrectInvoice!=null)
              IconButton(tooltip:'Correct invoice',onPressed:()=>onCorrectInvoice!(d['id'] as int),icon:const Icon(Icons.edit_note)),
            if(d['status']=='POSTED'&&CommercialCore.instance.current?.allowed(module,'delete')==true)
              IconButton(tooltip:'Void invoice',onPressed:()async{
                final proceed=await showDialog<bool>(context:context,builder:(dialog)=>AlertDialog(title:const Text('Void invoice?'),content:const Text('Stock and accounting postings will be reversed.'),actions:[TextButton(onPressed:()=>Navigator.pop(dialog,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(dialog,true),child:const Text('Void'))]));
                if(proceed==true){
                  try{await Store.instance.voidDocument(d['id'] as int);onChange();}
                  catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
                }
              },icon:const Icon(Icons.block))
          ])
        );
      })
    ]));
  });
}
