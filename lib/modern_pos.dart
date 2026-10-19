import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'store.dart';
import 'reporting.dart';
import 'commercial_core.dart';
import 'package:flutter/services.dart';

class ModernPosScreen extends StatefulWidget {
  final String kind;final VoidCallback onChange;
  final ValueChanged<bool>? onCartChanged;
  final Future<void> Function(int invoiceId)? onCorrectInvoice;
  const ModernPosScreen({super.key,required this.kind,required this.onChange,
    this.onCartChanged,this.onCorrectInvoice});
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
  final productSearchFocus=FocusNode(debugLabel:'pos-product-search');
  final cartScroll=ScrollController(),paymentScroll=ScrollController();
  bool showPaymentDetails=false;
  List<Map<String,Object?>> catalog=[];Map<int,String> parties={};Map<int,String> accounts={};Map<int,List<Map<String,Object?>>> availableUnits={};
  final cart=<_CartRow>[];
  final extraPayments=<_ExtraPaymentRow>[];
  String category='All',date=nowDate();int? partyId,accountId;bool busy=false;String? error;
  bool get sale=>widget.kind=='sale';
  @override void initState(){super.initState();load();}
  @override void dispose(){productSearchFocus.dispose();search.dispose();paid.dispose();notes.dispose();cartScroll.dispose();paymentScroll.dispose();for(final row in cart)row.dispose();for(final row in extraPayments)row.dispose();super.dispose();}
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
    if(row.isNotEmpty){final r=row.first;r.qty.text='${(double.tryParse(r.qty.text)??0)+1}';setState((){cart.remove(r);cart.insert(0,r);});}
    else{
      final newRow=_CartRow(entry);
      final units=availableUnits[entry['id'] as int]??[];
      final preferences=sale?['table sheet']:['roll','packet','set'];
      for(final preferred in preferences){
        final matching=units.where((u)=>'${u['unit']}'.toLowerCase()==preferred);
        if(matching.isNotEmpty){newRow.unit='${matching.first['unit']}';newRow.factor.text='${numVal(matching.first['factor'])}';break;}
      }
      setState(()=>cart.insert(0,newRow));
    }
    widget.onCartChanged?.call(cart.isNotEmpty);
    WidgetsBinding.instance.addPostFrameCallback((_){if(cartScroll.hasClients)cartScroll.jumpTo(0);});
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
      widget.onCartChanged?.call(false);
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
  void focusProductSearch(){
    productSearchFocus.requestFocus();
    search.selection=TextSelection(baseOffset:0,extentOffset:search.text.length);
  }
  @override Widget build(BuildContext context){
    final query=search.text.toLowerCase();
    final filtered=catalog.where((p)=>(category=='All'||p['category']==category)&&('${p['product']} ${p['sku']} ${p['attrs']}').toLowerCase().contains(query)).toList();
    final cats=['All',...{for(final p in catalog)'${p['category']}'}];
    final grouped=<int,Map<String,Object?>>{};
    for(final item in filtered){grouped.putIfAbsent(item['product_id'] as int,()=>item);}
    final displayProducts=grouped.values.toList();
    return CallbackShortcuts(bindings:<ShortcutActivator,VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyF,control:true):focusProductSearch,
      const SingleActivator(LogicalKeyboardKey.keyS,control:true):(){if(!busy)submit();},
      const SingleActivator(LogicalKeyboardKey.f6):()=>setState(()=>showPaymentDetails=!showPaymentDetails),
    },child:Focus(autofocus:true,child:LayoutBuilder(builder:(ctx,layout)=>Padding(padding:const EdgeInsets.all(12),child:Column(children:[
      Row(children:[Icon(sale?Icons.point_of_sale:Icons.local_shipping_outlined,color:const Color(0xFF4B63D9),size:26),const SizedBox(width:10),Expanded(child:Text(sale?'Sales POS · Manual Billing':'Purchase POS · Stock In',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800))),const Text('Ctrl+F Search  •  F6 Payments  •  Ctrl+S Save',style:TextStyle(fontSize:11,color:Color(0xFF58708B)))]),const SizedBox(height:12),
      Expanded(child:layout.maxWidth>1000?Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(flex:4,child:catalogPane(displayProducts,cats)),const SizedBox(width:12),Expanded(flex:6,child:cartPane())]):ListView(children:[SizedBox(height:400,child:catalogPane(displayProducts,cats)),const SizedBox(height:12),SizedBox(height:650,child:cartPane())]))
    ])))));
  }
  Widget catalogPane(List<Map<String,Object?>> filtered,List<String> categories)=>Card(child:Padding(padding:const EdgeInsets.all(15),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    TextField(key:const Key('pos-product-search'),focusNode:productSearchFocus,
      controller:search,onChanged:(_)=>setState((){}),
      onSubmitted:(_){if(filtered.isNotEmpty)chooseVariant(filtered.first);},
      decoration:const InputDecoration(prefixIcon:Icon(Icons.search),labelText:'Search Product / Size / Color  (Ctrl+F)')),const SizedBox(height:12),
    SizedBox(height:48,child:ListView(scrollDirection:Axis.horizontal,children:categories.map((c)=>Padding(padding:const EdgeInsets.only(right:8),child:ChoiceChip(label:Text(c),selected:c==category,onSelected:(_)=>setState(()=>category=c)))).toList())),
    const SizedBox(height:6),Expanded(child:filtered.isEmpty?const Center(child:Text('No matching variations')):ListView.builder(itemCount:filtered.length,itemBuilder:(ctx,i){final p=filtered[i];final qty=numVal(p['qty']);return Card(color:const Color(0xFFF6F8FD),child:ListTile(onTap:()=>chooseVariant(p),title:Text('${p['product']}',style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text('${p['category']} • Tap to choose variation\n${catalog.where((v)=>v['product_id']==p['product_id']).length} variations available',style:TextStyle(color:qty<0?Colors.deepOrange:Colors.blueGrey)),isThreeLine:true,trailing:FilledButton.icon(onPressed:()=>chooseVariant(p),icon:const Icon(Icons.add_shopping_cart,size:19),label:const Text('Add to Cart'),style:FilledButton.styleFrom(minimumSize:const Size(130,46)))));}))
  ])));
  // Compact billing grid: new products appear at the TOP without hunting in a
  // nested scroll view. Dense lines keep 6–10 products visible on a normal
  // desktop. Beyond available height, a prominent scrollbar is intentional.
  Widget cartLine(_CartRow row, bool narrow) {
    final id=row.product['id'];
    final attrs='${row.product['attrs']??''}'.trim();
    final variant=attrs.isEmpty?'Standard':attrs;
    final units=availableUnits[id as int]??[{'unit':row.unit,'factor':1.0}];
    final product=Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[
      Text('${row.product['product']}',maxLines:1,overflow:TextOverflow.ellipsis,
        style:const TextStyle(fontWeight:FontWeight.w700,fontSize:12,color:Color(0xFF172C46))),
      Text(variant,maxLines:1,overflow:TextOverflow.ellipsis,
        style:const TextStyle(fontSize:10,color:Color(0xFF58708B))),
    ]);
    final unitSelect=DropdownButton<String>(
      isExpanded:true,isDense:true,value:row.unit,underline:const SizedBox.shrink(),
      style:const TextStyle(fontSize:11,color:Color(0xFF183454)),
      items:units.map((u)=>DropdownMenuItem<String>(value:'${u['unit']}',
        child:Text(shopUnit('${u['unit']}'),overflow:TextOverflow.ellipsis))).toList(),
      onChanged:(v){if(v!=null)changeCartUnit(row,v);});
    Widget numberField(TextEditingController controller,String hint) => TextField(
      controller:controller,keyboardType:const TextInputType.numberWithOptions(decimal:true),
      textAlign:TextAlign.center,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600),
      decoration:InputDecoration(hintText:hint,isDense:true,contentPadding:const EdgeInsets.symmetric(horizontal:6,vertical:9),
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(7))),
      onChanged:(_)=>setState((){}));
    final amount=Text(money((double.tryParse(row.qty.text)??0)*(double.tryParse(row.price.text)??0)),
      maxLines:1,overflow:TextOverflow.ellipsis,textAlign:TextAlign.end,
      style:const TextStyle(fontWeight:FontWeight.w800,fontSize:11,color:Color(0xFF134C93)));
    final remove=IconButton(tooltip:'Remove from cart',visualDensity:VisualDensity.compact,
      constraints:const BoxConstraints.tightFor(width:30,height:34),padding:EdgeInsets.zero,
      onPressed:(){setState(()=>cart.remove(row));row.dispose();widget.onCartChanged?.call(cart.isNotEmpty);},
      icon:const Icon(Icons.close_rounded,size:17,color:Color(0xFFBA3A3A)));
    return Container(key:ValueKey('compact-cart-$id'),
      margin:const EdgeInsets.only(bottom:4),padding:const EdgeInsets.symmetric(horizontal:7,vertical:5),
      decoration:BoxDecoration(color:const Color(0xFFF7FAFF),
        border:Border.all(color:const Color(0xFFDCE9F8)),borderRadius:BorderRadius.circular(8)),
      child:narrow
      ? Column(children:[
          Row(children:[Expanded(child:product),const SizedBox(width:4),amount,remove]),
          const SizedBox(height:5),
          Row(children:[Expanded(flex:4,child:unitSelect),const SizedBox(width:5),
            Expanded(flex:3,child:numberField(row.qty,'Qty')),const SizedBox(width:5),
            Expanded(flex:3,child:numberField(row.price,'Price'))]),
        ])
      : Row(children:[
          Expanded(flex:5,child:product),const SizedBox(width:6),
          Expanded(flex:3,child:unitSelect),const SizedBox(width:6),
          SizedBox(width:58,child:numberField(row.qty,'Qty')),const SizedBox(width:6),
          SizedBox(width:78,child:numberField(row.price,'Rate')),const SizedBox(width:6),
          SizedBox(width:90,child:amount),remove,
        ]));
  }

  Widget paymentForm(){
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      DropdownButtonFormField<int?>(value:partyId,isExpanded:true,
        decoration:InputDecoration(isDense:true,labelText:sale?'Customer':'Supplier'),
        items:[if(sale)const DropdownMenuItem<int?>(value:null,child:Text('Walk-in (fully paid only)')),
          ...parties.entries.map((e)=>DropdownMenuItem<int?>(value:e.key,child:Text(e.value,overflow:TextOverflow.ellipsis)))],
        onChanged:(v)=>setState(()=>partyId=v)),
      const SizedBox(height:6),
      DropdownButtonFormField<int>(value:accountId,isExpanded:true,
        decoration:const InputDecoration(labelText:'First payment account',isDense:true),
        items:accounts.entries.map((e)=>DropdownMenuItem<int>(value:e.key,child:Text(e.value,overflow:TextOverflow.ellipsis))).toList(),
        onChanged:(v)=>setState(()=>accountId=v)),
      const SizedBox(height:6),
      Row(children:[Expanded(child:TextField(controller:paid,
        keyboardType:const TextInputType.numberWithOptions(decimal:true),
        decoration:const InputDecoration(labelText:'Paid now (Rs.)',isDense:true),onChanged:(_)=>setState((){}))),
        const SizedBox(width:7),Expanded(child:TextFormField(initialValue:date,
          decoration:const InputDecoration(labelText:'Date YYYY-MM-DD',isDense:true),onChanged:(v)=>date=v))]),
      const SizedBox(height:6),
      TextField(controller:notes,decoration:const InputDecoration(labelText:'Notes (optional)',isDense:true)),
      Row(children:[const Expanded(child:Text('Split payment • Cash / Bank / Wallet',
        style:TextStyle(fontWeight:FontWeight.w600,fontSize:11))),
        TextButton.icon(onPressed:accounts.isEmpty?null:()=>setState(()=>extraPayments.add(_ExtraPaymentRow(accounts.keys.first))),
          icon:const Icon(Icons.add,size:16),label:const Text('Add method'))]),
      for(var i=0;i<extraPayments.length;i++) Padding(padding:const EdgeInsets.only(bottom:5),child:Row(children:[
        Expanded(flex:5,child:DropdownButtonFormField<int>(
          key:ValueKey('split-account-$i-${extraPayments[i].accountId}'),initialValue:extraPayments[i].accountId,
          isExpanded:true,decoration:InputDecoration(labelText:'Account ${i+2}',isDense:true),
          items:accounts.entries.map((e)=>DropdownMenuItem<int>(value:e.key,child:Text(e.value,overflow:TextOverflow.ellipsis))).toList(),
          onChanged:(v)=>setState(()=>extraPayments[i].accountId=v))),
        const SizedBox(width:7),Expanded(flex:3,child:TextField(controller:extraPayments[i].amount,
          keyboardType:const TextInputType.numberWithOptions(decimal:true),
          decoration:const InputDecoration(labelText:'Amount',isDense:true),onChanged:(_)=>setState((){}))),
        IconButton(tooltip:'Remove payment',onPressed:(){final row=extraPayments.removeAt(i);setState((){});row.dispose();},
          icon:const Icon(Icons.close,size:18)),
      ])),
    ]);
  }

  Widget cartPane()=>Card(child:Padding(padding:const EdgeInsets.all(10),child:LayoutBuilder(
    builder:(ctx,bounds){
      final narrow=bounds.maxWidth<575;
      // Keep most of the viewport for the cart instead of allowing payment
      // widgets to push product lines outside the visible area.
      final paymentHeight=math.min(236.0,math.max(110.0,bounds.maxHeight*.36));
      return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Row(children:[Expanded(child:Text('Bill Cart · ${cart.length} Items',
          style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800))),
          Text(paymentLabel,style:TextStyle(fontWeight:FontWeight.w800,fontSize:11,
            color:paymentLabel=='PAID'?Colors.green:Colors.deepOrange))]),
        const SizedBox(height:5),
        if(cart.isNotEmpty&&!narrow) const Padding(padding:EdgeInsets.symmetric(horizontal:9,vertical:3),
          child:Row(children:[Expanded(flex:5,child:Text('Product / Variation',style:TextStyle(fontSize:10,fontWeight:FontWeight.bold))),
            SizedBox(width:6),Expanded(flex:3,child:Text('Unit',style:TextStyle(fontSize:10,fontWeight:FontWeight.bold))),
            SizedBox(width:6),SizedBox(width:58,child:Text('Qty',style:TextStyle(fontSize:10,fontWeight:FontWeight.bold))),
            SizedBox(width:6),SizedBox(width:78,child:Text('Rate',style:TextStyle(fontSize:10,fontWeight:FontWeight.bold))),
            SizedBox(width:6),SizedBox(width:90,child:Text('Amount',style:TextStyle(fontSize:10,fontWeight:FontWeight.bold))),
            SizedBox(width:30)])),
        Expanded(child:cart.isEmpty?const Center(child:Text('Select a product from the left')):
          Scrollbar(controller:cartScroll,thumbVisibility:true,child:ListView.builder(
            key:const Key('compact-pos-cart'),controller:cartScroll,
            padding:const EdgeInsets.only(right:7),itemCount:cart.length,
            itemBuilder:(ctx,i)=>cartLine(cart[i],narrow)))),
        const SizedBox(height:5),
        Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:5),
          decoration:BoxDecoration(color:const Color(0xFFEAF4FF),borderRadius:BorderRadius.circular(8)),
          child:Row(children:[Expanded(child:Text('Total: ${money(total)}',
            style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800))),
            Text('Due: ${money(total-payment)}',style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700))])),
        const SizedBox(height:5),
        OutlinedButton.icon(onPressed:()=>setState(()=>showPaymentDetails=!showPaymentDetails),
          icon:Icon(showPaymentDetails?Icons.expand_less:Icons.expand_more,size:16),
          label:Text(showPaymentDetails?'Hide Payment Details':'Show Payment Details')),
        if(showPaymentDetails)SizedBox(height:paymentHeight,
          child:Scrollbar(controller:paymentScroll,thumbVisibility:true,child:SingleChildScrollView(
            controller:paymentScroll,padding:const EdgeInsets.only(right:6,bottom:4),child:paymentForm()))),
        if(error!=null)Padding(padding:const EdgeInsets.symmetric(vertical:4),
          child:Text(error!,maxLines:2,overflow:TextOverflow.ellipsis,
            style:const TextStyle(color:Colors.red,fontSize:11))),
        const SizedBox(height:5),
        FilledButton.icon(onPressed:busy || CommercialCore.instance.current?.allowed(
          sale?'Sales / Billing':'Purchases','create')!=true?null:submit,
          icon:const Icon(Icons.check_circle_outline,size:20),
          label:Text(busy?'Saving...':sale?'Save Sale & Deduct Stock  (Ctrl+S)':'Save Purchase & Add Stock  (Ctrl+S)'),
          style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(42))),
      ]);
    })));

}

class _HistoryPane extends StatelessWidget {
  final String kind;final VoidCallback onBack,onChange;
  final Future<void> Function(int invoiceId)? onCorrectInvoice;
  const _HistoryPane({required this.kind,required this.onBack,required this.onChange,this.onCorrectInvoice});
  Future<void> reprint(int id)async{
    final rows=await Store.instance.read('''SELECT p.name AS Product,v.sku AS SKU,l.qty AS Quantity,coalesce(u.unit,v.unit) AS Unit,l.rate/100.0 AS Rate,l.amount/100.0 AS Amount
      FROM document_lines l JOIN variants v ON v.id=l.variant_id JOIN products p ON p.id=v.product_id LEFT JOIN document_line_units u ON u.line_id=l.id WHERE l.document_id=? AND l.is_current=1''',[id]);
    await Exports.pdf(ReportResult('Invoice #$id',const ['Product','SKU','Quantity','Unit','Rate','Amount'],rows.map((r)=>['${r['Product']}','${r['SKU']}','${r['Quantity']}','${r['Unit']}','${r['Rate']}','${r['Amount']}']).toList()),print:true);
  }
  @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,Object?>>>(future:Store.instance.read('''SELECT d.*,coalesce(p.name,'Walk-in') AS party FROM documents d LEFT JOIN parties p ON p.id=d.party_id WHERE d.kind=? AND d.status='POSTED' ORDER BY d.id DESC LIMIT 150''',[kind]),builder:(ctx,snap){
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
                  try{await Store.instance.cancelInvoiceSafely(d['id'] as int);onChange();}
                  catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
                }
              },icon:const Icon(Icons.block))
          ])
        );
      })
    ]));
  });
}
