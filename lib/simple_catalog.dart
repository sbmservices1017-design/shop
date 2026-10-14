import 'package:flutter/material.dart';
import 'store.dart';
import 'commercial_core.dart';

/// Straightforward catalog for shopkeepers: Category -> Product -> Variations.
/// SKU and stock conversion remain internal; users enter only pack size.
class SimpleCategoriesScreen extends StatefulWidget {
  final VoidCallback onChange;
  const SimpleCategoriesScreen({super.key, required this.onChange});
  @override State<SimpleCategoriesScreen> createState() => _SimpleCategoriesScreenState();
}

class _SimpleCategoriesScreenState extends State<SimpleCategoriesScreen> {
  List<Map<String, Object?>> rows = [];
  bool loading = true;
  @override void initState() { super.initState(); _reload(); }
  Future<void> _reload() async {
    final items = await Store.instance.read('SELECT id,name FROM categories WHERE active=1 ORDER BY name');
    if (mounted) setState(() { rows = items; loading = false; });
  }
  bool get canAdd => CommercialCore.instance.current?.allowed('Categories & Fields', 'create') == true;
  bool get canEdit => CommercialCore.instance.current?.allowed('Categories & Fields', 'edit') == true;
  bool get canDelete => CommercialCore.instance.current?.allowed('Categories & Fields', 'delete') == true;

  Future<String?> _nameDialog(String title, [String initial = '']) async {
    final controller = TextEditingController(text: initial);
    try {
      return await showDialog<String>(context:context, builder:(dialog) => AlertDialog(
        title:Text(title), content:SizedBox(width:390, child:TextField(controller:controller,autofocus:true,
        textCapitalization:TextCapitalization.words,decoration:const InputDecoration(labelText:'Category name',hintText:'e.g. Mattress, Chatai, Blanket'),
        onSubmitted:(v) { if (v.trim().isNotEmpty) Navigator.pop(dialog,v.trim()); })),
        actions:[TextButton(onPressed:()=>Navigator.pop(dialog), child:const Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(dialog,controller.text.trim()),child:const Text('Save'))]));
    } finally { controller.dispose(); }
  }
  Future<void> _run(Future<void> Function() action) async {
    try { await action(); await _reload(); widget.onChange(); }
    catch (e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not save: $e'))); }
  }
  @override Widget build(BuildContext context) => Padding(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('Categories',style:TextStyle(fontSize:25,fontWeight:FontWeight.w800)),
    const SizedBox(height:8),const Text('Step 1: Add simple categories. Product sizes, colors and packs are added on the Products page.',style:TextStyle(color:Colors.blueGrey)),
    const SizedBox(height:20),Align(alignment:Alignment.centerRight,child:FilledButton.icon(
      onPressed:canAdd?()=>_run(()async{final n=await _nameDialog('New category');if(n!=null&&n.isNotEmpty)await Store.instance.addCategory(n);}):null,
      icon:const Icon(Icons.add),label:const Text('New Category'))),
    const SizedBox(height:12),Expanded(child:loading?const Center(child:CircularProgressIndicator()):
    Card(child:rows.isEmpty?const Center(child:Text('No categories yet. Click New Category.')):
      ListView.separated(itemCount:rows.length,separatorBuilder:(_,__)=>const Divider(height:1),
        itemBuilder:(ctx,i){final item=rows[i];return ListTile(
        leading:const CircleAvatar(child:Icon(Icons.category_outlined)),title:Text('${item['name']}',style:const TextStyle(fontWeight:FontWeight.w700)),
        trailing:Wrap(spacing:8,children:[IconButton(tooltip:'Rename',onPressed:canEdit?()=>_run(()async{
          final n=await _nameDialog('Rename category','${item['name']}');
          if(n!=null&&n.isNotEmpty)await Store.instance.db.rawUpdate('UPDATE categories SET name=? WHERE id=?',[n,item['id']]);
        }):null,icon:const Icon(Icons.edit_outlined)),
        IconButton(tooltip:'Archive',onPressed:canDelete?()=>_run(()async{
          final used=await Store.instance.count('SELECT count(*) FROM products WHERE category_id=? AND active=1',[item['id']]);
          if(used>0)throw const FormatException('Archive its products first.');
          await Store.instance.archive('categories',item['id'] as int);
        }):null,icon:const Icon(Icons.archive_outlined))]));})))
  ]));
}

class SimpleProductsScreen extends StatefulWidget {
  final VoidCallback onChange;
  const SimpleProductsScreen({super.key,required this.onChange});
  @override State<SimpleProductsScreen> createState()=>_SimpleProductsScreenState();
}

class _SimpleProductsScreenState extends State<SimpleProductsScreen> {
  final store=Store.instance;
  List<Map<String,Object?>> categories=[],products=[],variants=[];
  int? filterCategory;
  String search='';
  bool busy=true;
  @override void initState(){super.initState();_reload();}
  Future<void> _reload()async{
    final results=await Future.wait([
      store.read('SELECT id,name FROM categories WHERE active=1 ORDER BY name'),
      store.read('''SELECT p.id,p.name,p.category_id,c.name AS category FROM products p JOIN categories c ON c.id=p.category_id WHERE p.active=1 ORDER BY c.name,p.name'''),
      store.stock()
    ]);
    if(mounted)setState((){categories=results[0];products=results[1];variants=results[2];busy=false;});
  }
  bool allow(String action)=>CommercialCore.instance.current?.allowed('Products & Variants',action)==true;
  Future<void> _run(Future<void> Function() task)async{
    try{await task();await _reload();widget.onChange();}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not save: $e')));}
  }
  Future<void> _addProduct() async {
    if(categories.isEmpty)throw const FormatException('Please add a Category first.');
    int category=categories.first['id'] as int;
    final name=TextEditingController();
    try{
      final result=await showDialog<(int,String)?>(context:context,builder:(context)=>StatefulBuilder(builder:(ctx,setModal)=>AlertDialog(
        title:const Text('Step 2 · Add Product'),content:SizedBox(width:420,child:Column(mainAxisSize:MainAxisSize.min,children:[
          DropdownButtonFormField<int>(initialValue:category,isExpanded:true,decoration:const InputDecoration(labelText:'Category'),
            items:categories.map((c)=>DropdownMenuItem(value:c['id'] as int,child:Text('${c['name']}'))).toList(),onChanged:(v)=>setModal(()=>category=v??category)),
          const SizedBox(height:15),TextField(controller:name,decoration:const InputDecoration(labelText:'Product name',hintText:'e.g. Cotton Chatai')),
        ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,(category,name.text.trim())),child:const Text('Save Product'))])));
      if(result!=null){if(result.$2.isEmpty)throw const FormatException('Product name is required');await store.addProduct(result.$1,result.$2);}
    }finally{name.dispose();}
  }
  Future<void> _addVariation(int productId)async{
    final form=GlobalKey<FormState>();
    final fields={for(final name in ['size','color','design','quality','packSize','gazz','opening'])name:TextEditingController()};
    fields['packSize']!.text='1';fields['gazz']!.text='3';fields['opening']!.text='0';
    String packing='piece';
    String packLabel()=>switch(packing){'set'=>'How many pieces in one Set?','packet'=>'How many pieces in one Packet?','roll'=>'How many Feet in one Roll?',_=>'Pieces per Piece'};
    try{
      final values=await showDialog<Map<String,String>?>(context:context,builder:(context)=>StatefulBuilder(builder:(ctx,setModal)=>AlertDialog(
        title:const Text('Step 3 · Add Size / Color / Pack'),scrollable:true,
        content:SizedBox(width:485,child:Form(key:form,child:Column(mainAxisSize:MainAxisSize.min,children:[
          const Align(alignment:Alignment.centerLeft,child:Text('Variation details (optional)',style:TextStyle(fontWeight:FontWeight.w700))),const SizedBox(height:10),
          Row(children:[Expanded(child:TextFormField(controller:fields['size'],decoration:const InputDecoration(labelText:'Size',hintText:'6 × 4, Double'))),
            const SizedBox(width:10),Expanded(child:TextFormField(controller:fields['color'],decoration:const InputDecoration(labelText:'Color',hintText:'Red, Blue')))]),
          const SizedBox(height:10),Row(children:[Expanded(child:TextFormField(controller:fields['design'],decoration:const InputDecoration(labelText:'Design',hintText:'Flower, Plain'))),
            const SizedBox(width:10),Expanded(child:TextFormField(controller:fields['quality'],decoration:const InputDecoration(labelText:'Quality',hintText:'Premium')))]),
          const SizedBox(height:17),DropdownButtonFormField<String>(initialValue:packing,decoration:const InputDecoration(labelText:'How do you purchase this product?'),
            items:const [DropdownMenuItem(value:'piece',child:Text('Single Piece')),
              DropdownMenuItem(value:'set',child:Text('Set (e.g. 3 pieces)')),
              DropdownMenuItem(value:'packet',child:Text('Packet (e.g. 12 pieces)')),
              DropdownMenuItem(value:'roll',child:Text('Roll (sell in Feet / Gazz)'))],
            onChanged:(v){if(v==null)return;setModal((){packing=v;fields['packSize']!.text=switch(v){'set'=>'3','packet'=>'12','roll'=>'100',_=>'1'};});}),
          if(packing!='piece')...[const SizedBox(height:11),TextFormField(controller:fields['packSize'],keyboardType:const TextInputType.numberWithOptions(decimal:true),
            decoration:InputDecoration(labelText:packLabel(),helperText:packing=='roll'?'e.g. 1 Roll = 100 Feet':'Sale can also be done as loose Pieces'),
            validator:(s){final n=double.tryParse(s??'');return n==null||n<=0?'Enter a valid quantity':null;})],
          if(packing=='roll')...[const SizedBox(height:10),TextFormField(controller:fields['gazz'],keyboardType:const TextInputType.numberWithOptions(decimal:true),
            decoration:const InputDecoration(labelText:'Feet per Gazz',helperText:'Default: 1 Gazz = 3 Feet (editable)'),
            validator:(s){final n=double.tryParse(s??'');return n==null||n<=0?'Enter feet per Gazz':null;})],
          const SizedBox(height:12),TextFormField(controller:fields['opening'],keyboardType:const TextInputType.numberWithOptions(decimal:true),
            decoration:InputDecoration(labelText:'Opening quantity',helperText:'Enter in ${packing=='piece'?'Pieces':packing=='roll'?'Rolls':packing=='set'?'Sets':'Packets'}; zero is fine'),
            validator:(s){final n=double.tryParse(s??'');return n==null||n<0?'Must be zero or more':null;}),
          const SizedBox(height:12),Container(width:double.infinity,padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:const Color(0xFFEDF6FF),borderRadius:BorderRadius.circular(9)),
            child:Text(switch(packing){'roll'=>'Buy in Rolls; sell in Feet, Gazz or Rolls. Stock is tracked in Feet.',
            'set'=>'Buy Sets or Pieces; sell Sets or loose Pieces. Stock is tracked in Pieces.',
            'packet'=>'Buy Packets or Pieces; sell Packets or loose Pieces. Stock is tracked in Pieces.',
            _=>'Buy and sell in Pieces. Each Size/Color has separate stock.'},style:const TextStyle(fontSize:12,color:Color(0xFF28577F))))
        ]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
          FilledButton(onPressed:(){if(form.currentState!.validate())Navigator.pop(ctx,{for(final e in fields.entries)e.key:e.value.text.trim(),'packing':packing});},
            child:const Text('Save Variation'))])));
      if(values!=null){await store.createSimpleVariant(productId:productId,size:values['size']!,color:values['color']!,
        design:values['design']!,quality:values['quality']!,packing:values['packing']!,packSize:double.parse(values['packSize']!),
        feetPerGazz:double.parse(values['gazz']!),openingPacks:double.parse(values['opening']!));}
    }finally{for(final controller in fields.values){controller.dispose();}}
  }
  Future<void> _editVariation(int id)async{
    final known=['Size','Color','Design','Quality'];
    final old=await store.read('''SELECT a.name,vv.value FROM variant_values vv JOIN attributes a ON a.id=vv.attribute_id WHERE vv.variant_id=?''',[id]);
    if(!mounted)return;
    final names={for(final x in old)'${x['name']}':'${x['value']}'};
    final cs={for(final name in known)name:TextEditingController(text:names[name]??'')};
    try{
      final result=await showDialog<Map<String,String>?>(context:context,builder:(ctx)=>AlertDialog(
        title:const Text('Edit Variation Details'),content:SizedBox(width:430,child:Column(mainAxisSize:MainAxisSize.min,children:[
        for(final name in known)Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:cs[name],decoration:InputDecoration(labelText:name)))])),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,{for(final e in cs.entries)e.key:e.value.text.trim()}),child:const Text('Update'))]));
      if(result!=null)await store.updateSimpleVariantDetails(id,result);
    }finally{for(final c in cs.values){c.dispose();}}
  }
  @override Widget build(BuildContext context){
    final visible=products.where((p)=>(filterCategory==null||p['category_id']==filterCategory)&&
      ('${p['name']} ${p['category']}'.toLowerCase().contains(search.trim().toLowerCase()))).toList();
    return Padding(padding:const EdgeInsets.all(23),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Products & Variations',style:TextStyle(fontSize:25,fontWeight:FontWeight.w800)),const SizedBox(height:6),
      const Text('Category → Product → Size / Color → Piece, Set, Packet or Roll. No SKU or conversion setup required.',style:TextStyle(color:Colors.blueGrey)),
      const SizedBox(height:15),Wrap(spacing:12,runSpacing:10,children:[
        SizedBox(width:260,child:TextField(decoration:const InputDecoration(prefixIcon:Icon(Icons.search),labelText:'Search products'),onChanged:(v)=>setState(()=>search=v))),
        SizedBox(width:230,child:DropdownButtonFormField<int?>(key:ValueKey(filterCategory),initialValue:filterCategory,
          decoration:const InputDecoration(labelText:'Category'),items:[const DropdownMenuItem<int?>(value:null,child:Text('All Categories')),
          ...categories.map((c)=>DropdownMenuItem<int?>(value:c['id'] as int,child:Text('${c['name']}')))],
          onChanged:(v)=>setState(()=>filterCategory=v))),
        FilledButton.icon(onPressed:allow('create')?()=>_run(_addProduct):null,icon:const Icon(Icons.add),label:const Text('New Product')),
      ]),const SizedBox(height:15),Expanded(child:busy?const Center(child:CircularProgressIndicator()):
      visible.isEmpty?const Center(child:Text('No products yet. Add a Category, then a Product.')):
      ListView.separated(itemCount:visible.length,separatorBuilder:(_,__)=>const SizedBox(height:8),
        itemBuilder:(ctx,i){final p=visible[i];final pvars=variants.where((v)=>v['product_id']==p['id']).toList();
        return Card(child:ExpansionTile(key:PageStorageKey(p['id']),initiallyExpanded:visible.length==1,
          title:Text('${p['name']}',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:16)),
          subtitle:Text('${p['category']} • ${pvars.length} variations'),
          trailing:const Icon(Icons.keyboard_arrow_down),childrenPadding:const EdgeInsets.fromLTRB(14,0,14,15),children:[
          Align(alignment:Alignment.centerRight,child:Wrap(spacing:8,children:[
            OutlinedButton.icon(onPressed:allow('edit')?()=>_run(()async{
              final n=TextEditingController(text:'${p['name']}');try{final value=await showDialog<String>(context:context,builder:(d)=>AlertDialog(
                title:const Text('Rename product'),content:TextField(controller:n,decoration:const InputDecoration(labelText:'Product name')),
                actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Cancel')),
                  FilledButton(onPressed:()=>Navigator.pop(d,n.text.trim()),child:const Text('Save'))]));
                if(value!=null&&value.isNotEmpty)await store.db.rawUpdate('UPDATE products SET name=? WHERE id=?',[value,p['id']]);
              }finally{n.dispose();}
            }):null,icon:const Icon(Icons.edit_outlined,size:17),label:const Text('Rename')),
            FilledButton.icon(onPressed:allow('create')?()=>_run(()=>_addVariation(p['id'] as int)):null,
              icon:const Icon(Icons.add,size:18),label:const Text('Add Size / Variation')),
          ])),const SizedBox(height:8),
          if(pvars.isEmpty)const Padding(padding:EdgeInsets.all(13),child:Text('No variation. Add a Standard variation or enter Size/Color.')),
          for(final v in pvars)ListTile(dense:true,
            leading:const CircleAvatar(radius:17,child:Icon(Icons.style_outlined,size:17)),
            title:Text(('${v['attrs']??''}').trim().isEmpty?'Standard':'${v['attrs']}',style:const TextStyle(fontWeight:FontWeight.w600)),
            subtitle:Text('Stock: ${numVal(v['qty']).toStringAsFixed(numVal(v['qty'])%1==0?0:2)} ${v['unit']=='ft'?'Feet':'Pieces'} • ${v['package']??'Single Piece'}'),
            trailing:Wrap(children:[IconButton(tooltip:'Edit Size/Color',onPressed:allow('edit')?()=>_run(()=>_editVariation(v['id'] as int)):null,icon:const Icon(Icons.edit_outlined)),
              IconButton(tooltip:'Archive variation',onPressed:allow('delete')?()=>_run(()async{await store.archive('variants',v['id'] as int);}):null,icon:const Icon(Icons.archive_outlined))]),
          )
        ]));}))
    ]));
  }
}
