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
String shopUnit(String unit)=>switch(unit.toLowerCase()){'pcs'=>'Piece','ft'=>'Feet','gazz'=>'Gazz','set'=>'Set','packet'=>'Packet','roll'=>'Roll','table sheet'=>'Table Sheet',_=>unit};

class _CartRow{
  final Map<String,Object?> product;
  final qty=TextEditingController(text:'1');
  final price=TextEditingController(text:'0');
  late String unit;
  final factor=TextEditingController(text:'1');
  _CartRow(this.product){unit='${product['unit']}';}
  void dispose(){qty.dispose();price.dispose();factor.dispose();}
}
class _ExtraPaymentRow {
  int? accountId;
  final amount=TextEditingController(text:'0');
  _ExtraPaymentRow(this.accountId);
  void dispose()=>amount.dispose();
}

class _ModernPosScreenState extends State<ModernPosScreen>{
  final store=Store.instance;
  final search=TextEditingController(),paid=TextEditingController(text:'0'),notes=TextEditingController();
  List<Map<String,Object?>> catalog=[];Map<int,String> parties={};Map<int,String> accounts={};Map<int,List<Map<String,Object?>>> availableUnits={};
  final cart=<_CartRow>[];
  final extraPayments=<_ExtraPaymentRow>[];
  String category='All',date=nowDate();int? partyId,accountId;bool busy=false;String? error;
  bool get sale=>widget.kind=='sale';
  @override void initState(){super.initState();load();}
  @override void dispose(){search.dispose();paid.dispose();notes.dispose();for(final row in cart)row.dispose();for(final row in extraPayments)row.dispose();super.dispose();}
  Future<void> load()async{
    final c=await store.stock();
    final p=await store.read('SELECT id,name FROM parties WHERE kind=? AND active=1 ORDER BY name',[sale?'customer':'supplier']);
    final a=await store.paymentAccountOptions();
    final conversions=await store.read('SELECT variant_id,unit,factor,can_buy,can_sell FROM variant_units');
    final unitMap=<int,List<Map<String,Object?>>>{};
    for(final variant in c){
      final id=variant['id'] as int;
      final extras=conversions.where((x)=>x['variant_id']==id &&
          (sale?x['can_sell']:x['can_buy'])==1 &&
          '${x['unit']}'.toLowerCase()!='${variant['unit']}'.toLowerCase()).toList();
      final finishedSheetRoll='${variant['unit']}'.toLowerCase()=='pcs' &&
          conversions.any((x)=>x['variant_id']==id &&
            '${x['unit']}'.toLowerCase()=='table sheet' &&
            numVal(x['factor'])==1);
      // For ready-made Table Sheet Rolls, show only "Roll" at purchase and
      // "Table Sheet" / "Roll" at sale. No confusing "Piece" or Gazz.
      unitMap[id]=finishedSheetRoll ? extras : [
        {'unit':'${variant['unit']}','factor':1.0},...extras];
    }
    if(!mounted)return;
    setState((){
      catalog=c;availableUnits=unitMap;parties={for(final x in p)x['id'] as int:'${x['name']}'};
      accounts=a;
      accountId??=accounts.isEmpty?null:accounts.keys.first;
      if(!sale)partyId??=parties.isEmpty?null:parties.keys.first;
    });
  }
  double get total=>cart.fold<double>(0,(v,r)=>v+(double.tryParse(r.qty.text)??0)*(double.tryParse(r.price.text)??0));
  double get payment=>(double.tryParse(paid.text)??0)+
    extraPayments.fold<double>(0,(sum,p)=>sum+(double.tryParse(p.amount.text)??0));
  List<PaymentPart> get enteredPayments=>[
    if((double.tryParse(paid.text)??0)>0 && accountId!=null)
      PaymentPart(accountId!,double.parse(paid.text)),
    for(final row in extraPayments)
      if((double.tryParse(row.amount.text)??0)>0 && row.accountId!=null)
        PaymentPart(row.accountId!,double.parse(row.amount.text)),
  ];
  String get paymentLabel=>payment>=total&&total>0?'PAID':payment>0?'PARTIALLY PAID':'UNPAID';
  void add(Map<String,Object?> entry){
    final row=cart.where((x)=>x.product['id']==entry['id']);
    if(row.isNotEmpty){final r=row.first;r.qty.text='${(double.tryParse(r.qty.text)??0)+1}';setState((){});}
    else{
      final newRow=_CartRow(entry);
      final units=availableUnits[entry['id'] as int]??[];
      final preferences=sale?['table sheet']:['roll','packet','set'];
      for(final preferred in preferences){
        final matching=units.where((u)=>'${u['unit']}'.toLowerCase()==preferred);
        if(matching.isNotEmpty){newRow.unit='${matching.first['unit']}';newRow.factor.text='${numVal(matching.first['factor'])}';break;}
      }
      setState(()=>cart.add(newRow));
    }
  }
  Future<void> chooseVariant(Map<String,Object?> product) async {
    // Group by product. The shopkeeper must choose exactly one of its size,
    // color, quality or cut variations before a cart item is created.
    final options=catalog.where((v)=>v['product_id']==product['product_id']).toList();
    if(options.isEmpty)return;
    if(options.length==1){add(options.first);return;}
    int selectedId=options.first['id'] as int;
    final choice=await showDialog<Map<String,Object?>>(context:context,
      builder:(dialogContext)=>StatefulBuilder(builder:(ctx,setModal){
        final selected=options.firstWhere((v)=>v['id']==selectedId);
        return AlertDialog(
          title:Text('Choose Variation — ${product['product']}'),
          content:SizedBox(width:510,child:Column(mainAxisSize:MainAxisSize.min,children:[
            DropdownButtonFormField<int>(key:ValueKey(selectedId),initialValue:selectedId,isExpanded:true,
              decoration:const InputDecoration(labelText:'Size / Color / Design / Pack'),
              items:options.map((v)=>DropdownMenuItem<int>(value:v['id'] as int,
                child:Text(('${v['attrs']??''}').trim().isEmpty
                  ? '${v['package']??'Standard'}'
                  : '${v['attrs']} · ${v['package']??'Piece'}',overflow:TextOverflow.ellipsis))).toList(),
              onChanged:(v){if(v!=null)setModal(()=>selectedId=v);}),
            const SizedBox(height:12),Align(alignment:Alignment.centerLeft,
              child:Text('Stock: ${numVal(selected['qty']).toStringAsFixed(2)} ${selected['display_unit']??shopUnit('${selected['unit']}')}',
                style:const TextStyle(fontWeight:FontWeight.w600,color:Color(0xFF1D68B2)))),
          ])),
          actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Cancel')),
            FilledButton.icon(onPressed:()=>Navigator.pop(dialogContext,selected),
              icon:const Icon(Icons.add),label:const Text('Add to Cart'),style:FilledButton.styleFrom(minimumSize:const Size(160,48)))]);
      }));
    if(choice!=null&&mounted)add(choice);
  }
  void changeCartUnit(_CartRow row,String unit){
    final choice=(availableUnits[row.product['id'] as int]??[]).firstWhere((u)=>u['unit']==unit);
    setState((){row.unit=unit;row.factor.text='${numVal(choice['factor'])}';});
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
      final lines=cart.map((r)=>ItemLine(r.product['id'] as int,double.parse(r.qty.text),double.parse(r.price.text),unit:r.unit,factor:double.parse(r.factor.text))).toList();
      if(lines.any((x)=>x.rate<0||x.qty<=0))throw const FormatException('Quantity must be positive; price cannot be negative');
      final amounts=[paid.text,...extraPayments.map((p)=>p.amount.text)];
      if(amounts.any((text)=>double.tryParse(text)==null ||
          !double.parse(text).isFinite || double.parse(text)<0))
        throw const FormatException('Enter valid non-negative payment amounts');
      if(extraPayments.any((p)=>p.accountId==null))
        throw const FormatException('Select an account for every payment');
      if(payment>total+0.001)throw const FormatException('Total payments cannot exceed bill total');
      if(sale && partyId==null && (total-payment).abs()>0.001)
        throw const FormatException('Select customer when a balance is unpaid');
      final id=await store.postDocumentSplit(widget.kind,partyId,date,lines,
          enteredPayments,notes:notes.text);
      if(!mounted)return;
      final savedStatus=paymentLabel;
      final saved=List<_CartRow>.of(cart);
      final oldPayments=List<_ExtraPaymentRow>.of(extraPayments);
      setState((){cart.clear();extraPayments.clear();paid.text='0';notes.clear();error=null;});
      for(final r in saved)r.dispose();
      for(final r in oldPayments)r.dispose();
      await load();
      if(!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('${sale?'Sale':'Purchase'} #$id saved · stock updated · $savedStatus')));
      // Auto-print intentionally disabled; reprint from Sales/Purchases invoice list.
      widget.onChange();
    }catch(e){if(mounted)setState(()=>error='$e');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context){
    final query=search.text.toLowerCase();
    final filtered=catalog.where((p)=>(category=='All'||p['category']==category)&&('${p['product']} ${p['sku']} ${p['attrs']}').toLowerCase().contains(query)).toList();
    final cats=['All',...{for(final p in catalog)'${p['category']}'}];
    final grouped=<int,Map<String,Object?>>{};
    for(final item in filtered){grouped.putIfAbsent(item['product_id'] as int,()=>item);}
    final displayProducts=grouped.values.toList();
    return LayoutBuilder(builder:(ctx,layout)=>Padding(padding:const EdgeInsets.all(12),child:Column(children:[
      Row(children:[Icon(sale?Icons.point_of_sale:Icons.local_shipping_outlined,color:const Color(0xFF4B63D9),size:26),const SizedBox(width:10),Expanded(child:Text(sale?'Sales POS · Manual Billing':'Purchase POS · Stock In',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800))),const SizedBox.shrink()]),const SizedBox(height:12),
      Expanded(child:layout.maxWidth>1000?Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(flex:5,child:catalogPane(displayProducts,cats)),const SizedBox(width:12),Expanded(flex:7,child:cartPane())]):ListView(children:[SizedBox(height:400,child:catalogPane(displayProducts,cats)),const SizedBox(height:12),SizedBox(height:650,child:cartPane())]))
    ])));
  }
  Widget catalogPane(List<Map<String,Object?>> filtered,List<String> categories)=>Card(child:Padding(padding:const EdgeInsets.all(15),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    TextField(controller:search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),labelText:'Search Product / Size / Color')),const SizedBox(height:12),
    SizedBox(height:48,child:ListView(scrollDirection:Axis.horizontal,children:categories.map((c)=>Padding(padding:const EdgeInsets.only(right:8),child:ChoiceChip(label:Text(c),selected:c==category,onSelected:(_)=>setState(()=>category=c)))).toList())),
    const SizedBox(height:6),Expanded(child:filtered.isEmpty?const Center(child:Text('No matching variations')):ListView.builder(itemCount:filtered.length,itemBuilder:(ctx,i){final p=filtered[i];final qty=numVal(p['qty']);return Card(color:const Color(0xFFF6F8FD),child:ListTile(onTap:()=>chooseVariant(p),title:Text('${p['product']}',style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text('${p['category']} • Tap to choose variation\n${catalog.where((v)=>v['product_id']==p['product_id']).length} variations available',style:TextStyle(color:qty<0?Colors.deepOrange:Colors.blueGrey)),isThreeLine:true,trailing:FilledButton.icon(onPressed:()=>chooseVariant(p),icon:const Icon(Icons.add_shopping_cart,size:19),label:const Text('Add to Cart'),style:FilledButton.styleFrom(minimumSize:const Size(130,46)))));}))
  ])));
  Widget cartPane()=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Row(children:[Expanded(child:Text('Bill Cart · ${cart.length} Items',style:const TextStyle(fontSize:22,fontWeight:FontWeight.w800))),Text(paymentLabel,style:TextStyle(fontWeight:FontWeight.w800,fontSize:11,color:paymentLabel=='PAID'?Colors.green:Colors.deepOrange))]),const SizedBox(height:9),
    Expanded(child:cart.isEmpty?const Center(child:Text('Select a product from the left')):ListView(children:[for(final row in cart)Card(color:const Color(0xFFF9FAFD),child:Padding(padding:const EdgeInsets.all(9),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Expanded(child:Text('${row.product['product']}',style:const TextStyle(fontWeight:FontWeight.bold))),IconButton(onPressed:(){setState(()=>cart.remove(row));row.dispose();},icon:const Icon(Icons.close,size:18))]),
      Text('Size / Color: ${(row.product['attrs']??'Standard').toString().isEmpty?'Standard':row.product['attrs']}',style:const TextStyle(color:Colors.blueGrey,fontSize:11)),const SizedBox(height:6),
      DropdownButtonFormField<String>(key:ValueKey('${row.product['id']}-${row.unit}'),initialValue:row.unit,isExpanded:true,
        decoration:InputDecoration(labelText:sale?'Sell as':'Purchase as'),
        items:(availableUnits[row.product['id'] as int]??[{'unit':row.unit,'factor':1.0}])
            .map((u)=>DropdownMenuItem(value:'${u['unit']}',child:Text(shopUnit('${u['unit']}')))).toList(),
        onChanged:(v){if(v!=null)changeCartUnit(row,v);}),
      const SizedBox(height:3),Text('Stock: ${(double.tryParse(row.qty.text)??0)*(double.tryParse(row.factor.text)??0)} ${row.product['display_unit']??shopUnit('${row.product['unit']}')}',
          style:const TextStyle(color:Colors.blueGrey,fontSize:11)),
      const SizedBox(height:6),Row(children:[Expanded(child:TextField(controller:row.qty,decoration:const InputDecoration(labelText:'Quantity'),keyboardType:TextInputType.number,onChanged:(_)=>setState((){}))),const SizedBox(width:8),Expanded(child:TextField(controller:row.price,decoration:InputDecoration(labelText:'${sale?'Selling':'Purchase'} price per ${shopUnit(row.unit)}'),keyboardType:TextInputType.number,onChanged:(_)=>setState((){})))]),const SizedBox(height:5),Align(alignment:Alignment.centerRight,child:Text(money((double.tryParse(row.qty.text)??0)*(double.tryParse(row.price.text)??0)),style:const TextStyle(fontWeight:FontWeight.bold)))
    ])))])),const Divider(),
    DropdownButtonFormField<int?>(value:partyId,isExpanded:true,decoration:InputDecoration(labelText:sale?'Customer':'Supplier'),items:[if(sale)const DropdownMenuItem<int?>(value:null,child:Text('Walk-in (fully paid only)')),...parties.entries.map((e)=>DropdownMenuItem<int?>(value:e.key,child:Text(e.value,overflow:TextOverflow.ellipsis)))],onChanged:(v)=>setState(()=>partyId=v)),const SizedBox(height:8),
    DropdownButtonFormField<int>(value:accountId,isExpanded:true,decoration:const InputDecoration(labelText:'Payment account · Holder · ID'),items:accounts.entries.map((e)=>DropdownMenuItem<int>(value:e.key,child:Text(e.value,overflow:TextOverflow.ellipsis))).toList(),onChanged:(v)=>setState(()=>accountId=v)),const SizedBox(height:8),
    Row(children:[Expanded(child:TextFormField(initialValue:date,decoration:const InputDecoration(labelText:'Invoice date YYYY-MM-DD'),onChanged:(v)=>date=v)),const SizedBox(width:8),Expanded(child:TextField(controller:notes,decoration:const InputDecoration(labelText:'Notes (optional)')))]),const SizedBox(height:8),
    Row(children:[Expanded(child:TextField(controller:paid,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'First payment (Rs.)'),onChanged:(_)=>setState((){}))),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.end,children:[const Text('Total amount',style:TextStyle(color:Colors.blueGrey,fontSize:11)),Text(money(total),style:const TextStyle(fontWeight:FontWeight.w900,fontSize:20)),Text('Balance: ${money(total-payment)}',style:const TextStyle(fontSize:11))]))]),
    const SizedBox(height:10),
    Row(children:[const Expanded(child:Text('Split payment: Cash + Bank + Wallet',style:TextStyle(fontWeight:FontWeight.w700,fontSize:12))),
      TextButton.icon(onPressed:accounts.isEmpty?null:()=>setState(()=>extraPayments.add(_ExtraPaymentRow(accounts.keys.first))),
        icon:const Icon(Icons.add,size:18),label:const Text('Add payment method'))]),
    if(extraPayments.isNotEmpty)SizedBox(height:extraPayments.length>2?132.0:extraPayments.length*66.0,
      child:ListView.builder(itemCount:extraPayments.length,itemBuilder:(ctx,i){final row=extraPayments[i];return Padding(
        padding:const EdgeInsets.only(bottom:6),child:Row(children:[
          Expanded(flex:5,child:DropdownButtonFormField<int>(
            key:ValueKey('split-account-$i-${row.accountId}'),initialValue:row.accountId,isExpanded:true,
            decoration:InputDecoration(labelText:'Payment ${i+2} account',isDense:true),
            items:accounts.entries.map((e)=>DropdownMenuItem<int>(value:e.key,child:Text(e.value,overflow:TextOverflow.ellipsis))).toList(),
            onChanged:(v)=>setState(()=>row.accountId=v))),
          const SizedBox(width:7),Expanded(flex:3,child:TextField(controller:row.amount,
            keyboardType:const TextInputType.numberWithOptions(decimal:true),
            decoration:const InputDecoration(labelText:'Amount (Rs.)',isDense:true),onChanged:(_)=>setState((){}))),
          IconButton(tooltip:'Remove payment',onPressed:(){setState(()=>extraPayments.remove(row));row.dispose();},icon:const Icon(Icons.close))
        ]));})),
    if(extraPayments.isNotEmpty)Text('Received / Paid: ${money(payment)} · Remaining credit: ${money(total-payment)}',
      style:const TextStyle(color:Color(0xFF28577F),fontSize:12,fontWeight:FontWeight.w600)),
    if(error!=null)Padding(padding:const EdgeInsets.all(7),child:Text(error!,style:const TextStyle(color:Colors.red,fontSize:12))),const SizedBox(height:9),
    FilledButton.icon(onPressed:busy || CommercialCore.instance.current?.allowed(sale?'Sales / Billing':'Purchases','create')!=true?null:submit,icon:const Icon(Icons.check_circle_outline),label:Padding(padding:const EdgeInsets.all(10),child:Text(busy?'Saving...':sale?'Save Sale & Deduct Stock':'Save Purchase & Add Stock'))),
    const SizedBox(height:4),const Text('Price is entered manually. Stock updates automatically.',style:TextStyle(fontSize:10,color:Colors.blueGrey),textAlign:TextAlign.center)
  ])));
}

class _HistoryPane extends StatelessWidget {
  final String kind;final VoidCallback onBack,onChange;
  final Future<void> Function(int invoiceId)? onCorrectInvoice;
  const _HistoryPane({required this.kind,required this.onBack,required this.onChange,this.onCorrectInvoice});
  Future<void> reprint(int id)async{
    final rows=await Store.instance.read('''SELECT p.name AS Product,v.sku AS SKU,l.qty AS Quantity,coalesce(u.unit,v.unit) AS Unit,l.rate/100.0 AS Rate,l.amount/100.0 AS Amount
      FROM document_lines l JOIN variants v ON v.id=l.variant_id JOIN products p ON p.id=v.product_id LEFT JOIN document_line_units u ON u.line_id=l.id WHERE l.document_id=?''',[id]);
    await Exports.pdf(ReportResult('Invoice #$id',const ['Product','SKU','Quantity','Unit','Rate','Amount'],rows.map((r)=>['${r['Product']}','${r['SKU']}','${r['Quantity']}','${r['Unit']}','${r['Rate']}','${r['Amount']}']).toList()),print:true);
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
              IconButton(tooltip:'Delete / cancel invoice',onPressed:()async{
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
