import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'store.dart';
import 'extensions.dart';
import 'reporting.dart';
import 'commercial_core.dart';
import 'commercial_ui.dart';
import 'modern_pos.dart';
import 'advanced_dashboard.dart';
import 'boot_setup.dart';
import 'settings_hub.dart';
import 'license_widgets.dart';
import 'nexa_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShopDesk());
}
const ink=Color(0xFF142B46);
const blue=Color(0xFF4B63D9);
const bg=Color(0xFFF5F9FF);
String activeShopModule='Dashboard';
bool canShopAction(String action)=>CommercialCore.instance.current?.allowed(activeShopModule,action)==true;
String rs(Object? v)=>'Rs. ${NumberFormat('#,##0.00').format(numVal(v))}';
String funds(Object? paisa)=>rs(rupees(paisa));

class ShopDesk extends StatelessWidget {
  const ShopDesk({super.key});
  @override Widget build(BuildContext context)=>MaterialApp(
    title:'ShopDesk — Offline ERP',debugShowCheckedModeBanner:false,
    scrollBehavior: const MaterialScrollBehavior().copyWith(scrollbars:true),
    theme:ThemeData(useMaterial3:true,textTheme:ThemeData.light().textTheme.apply(bodyColor:ink,displayColor:ink),colorScheme:ColorScheme.fromSeed(seedColor:blue,brightness:Brightness.light),scaffoldBackgroundColor:bg,
      scrollbarTheme:ScrollbarThemeData(thumbVisibility:WidgetStateProperty.all(true),trackVisibility:WidgetStateProperty.all(true),thickness:WidgetStateProperty.all(11),radius:const Radius.circular(8),thumbColor:WidgetStateProperty.all(const Color(0xFF6F9ACD)),trackColor:WidgetStateProperty.all(const Color(0xFFE2EEFC))),
      cardTheme:CardThemeData(color:Colors.white,elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18))),
      inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:Colors.white,contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:14),
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:Color(0xFFE2E7F0))),
        enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:Color(0xFFE2E7F0))))),
    home:ShopDeskBootstrap(application:()=>const CommercialGate(child:Shell())));
}

class FieldSpec {
  final String key,label;
  final String initial;
  final bool numeric;
  final Map<int,String>? choices;
  final bool mustFill;
  const FieldSpec(this.key,this.label,{this.initial='',this.numeric=false,this.choices,this.mustFill=true});
}
Future<Map<String,String>?> ask(BuildContext context,String title,List<FieldSpec> specs) async {
  final controllers={for(final x in specs)x.key:TextEditingController(text:x.initial)};
  try {
    return await showDialog<Map<String,String>>(context:context,builder:(ctx){
      final formKey=GlobalKey<FormState>();
      return AlertDialog(title:Text(title),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),
        content:SizedBox(width:460,child:Form(key:formKey,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:specs.map((f){
          if(f.choices!=null){
            if(controllers[f.key]!.text.isEmpty && f.choices!.isNotEmpty){controllers[f.key]!.text='${f.choices!.keys.first}';}
            return Padding(padding:const EdgeInsets.only(bottom:12),child:DropdownButtonFormField<String>(
              initialValue:f.choices!.containsKey(int.tryParse(controllers[f.key]!.text))?controllers[f.key]!.text:null,
              decoration:InputDecoration(labelText:f.label),isExpanded:true,
              items:f.choices!.entries.map((e)=>DropdownMenuItem(value:'${e.key}',child:Text(e.value,overflow:TextOverflow.ellipsis))).toList(),
              onChanged:(s)=>controllers[f.key]!.text=s??'',validator:(s)=>f.mustFill&&(s==null||s.isEmpty)?'Required':null));
          }
          return Padding(padding:const EdgeInsets.only(bottom:12),child:TextFormField(controller:controllers[f.key],
            decoration:InputDecoration(labelText:f.label),keyboardType:f.numeric?const TextInputType.numberWithOptions(decimal:true):TextInputType.text,
            validator:(s){if(f.mustFill&&(s==null||s.trim().isEmpty))return 'Required';if(f.numeric && s!.isNotEmpty && double.tryParse(s)==null)return 'Enter valid number';return null;}));
        }).toList())))),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
          FilledButton(onPressed:(){if(formKey.currentState!.validate()){Navigator.pop(ctx,{for(final e in controllers.entries)e.key:e.value.text.trim()});}},child:const Text('Save'))]);
    });
  }finally{for(final c in controllers.values){c.dispose();}}
}

Future<void> showError(BuildContext context,Object error)async{
  if(context.mounted)await showDialog(context:context,builder:(ctx)=>AlertDialog(title:const Text('Could not save'),content:SelectableText('$error'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('OK'))]));
}
Future<bool> confirm(BuildContext context,String text)async=>(await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Please confirm'),content:Text(text),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Back')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Confirm'))])))??false;

class Shell extends StatefulWidget {const Shell({super.key});@override State<Shell> createState()=>_ShellState();}
class _ShellState extends State<Shell> {
  int page=0;int revision=0;
  final menu=<({String label,IconData icon})>[
    (label:'Dashboard',icon:Icons.dashboard_rounded),
    (label:'POS',icon:Icons.point_of_sale_rounded),
    (label:'Sales Invoices',icon:Icons.receipt_long_outlined),
    (label:'Sale Returns',icon:Icons.assignment_return_outlined),
    (label:'Purchase Invoices',icon:Icons.shopping_cart_outlined),
    (label:'Purchase Returns',icon:Icons.keyboard_return_outlined),
    (label:'Products & Variants',icon:Icons.inventory_2_outlined),
    (label:'Categories & Fields',icon:Icons.category_outlined),
    (label:'Stock & Adjustments',icon:Icons.warehouse_outlined),
    (label:'Customers',icon:Icons.people_outline),
    (label:'Suppliers',icon:Icons.local_shipping_outlined),
    (label:'Expenses',icon:Icons.payments_outlined),
    (label:'Employees & Payroll',icon:Icons.badge_outlined),
    (label:'Accounts & Journal',icon:Icons.account_balance_outlined),
    (label:'Reports / Export',icon:Icons.analytics_outlined),
    (label:'Settings & Backup',icon:Icons.settings_outlined)
  ];
  String moduleKey(int i)=>switch(i){
    1||2=>'Sales / Billing',3||5=>'Returns & Refunds',4=>'Purchases',
    _=>menu[i].label
  };
  void refresh(){if(mounted)setState(()=>revision++);}
  Future<void> correctPostedInvoice(String kind,int id)async{
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>InvoiceDialog(kind:kind,existingId:id));
    if(ok==true)refresh();
  }
  Widget screen(){activeShopModule=moduleKey(page);return switch(page){
    0=>AdvancedDashboard(revision:revision),
    1=>PosWorkspace(onChange:refresh),
    2=>DocumentScreen(kind:'sale',onChange:refresh),
    3=>ReturnScreen(kind:'sale',onChange:refresh),
    4=>DocumentScreen(kind:'purchase',onChange:refresh),
    5=>ReturnScreen(kind:'purchase',onChange:refresh),
    6=>ProductsScreen(onChange:refresh),7=>CategoriesScreen(onChange:refresh),
    8=>StockScreen(onChange:refresh),9=>PartiesScreen(kind:'customer',onChange:refresh),
    10=>PartiesScreen(kind:'supplier',onChange:refresh),
    11=>ExpenseScreen(onChange:refresh),12=>EmployeeScreen(onChange:refresh),
    13=>AccountsScreen(onChange:refresh),14=>ReportsScreen(revision:revision),
    _=>const SettingsHub()};}
  Future<void> searchModules(List<int> available) async {
    final chosen=await showSearch<int?>(context:context,delegate:_ModuleSearchDelegate(menu,available));
    if(chosen!=null && mounted)setState(()=>page=chosen);
  }
  @override Widget build(BuildContext context){
    final core=CommercialCore.instance;
    final available=[for(var i=0;i<menu.length;i++)if(core.current?.allowed(moduleKey(i),'view')==true)i];
    if(available.isEmpty)return Scaffold(body:Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[const Text('No modules assigned to this account.'),TextButton(onPressed:core.signOut,child:const Text('Sign out'))])));
    if(!available.contains(page))page=available.first;
    final dark=false;
    return Scaffold(backgroundColor:dark?Nexa.background:bg,body:Row(children:[
      Container(width:237,decoration:const BoxDecoration(color:Nexa.sidebar,border:Border(right:BorderSide(color:Nexa.outline))),child:Column(children:[
        Padding(padding:const EdgeInsets.fromLTRB(23,23,12,29),child:Row(children:[
          Container(padding:const EdgeInsets.all(8),decoration:BoxDecoration(gradient:Nexa.blueGradient,borderRadius:BorderRadius.circular(9)),child:const Icon(Icons.layers_rounded,color:Colors.white,size:23)),
          const SizedBox(width:13),const Text('ShopDesk',style:TextStyle(color:Nexa.white,fontWeight:FontWeight.w800,fontSize:20)),
          const Padding(padding:EdgeInsets.only(left:5,top:5),child:Text('PRO',style:TextStyle(color:Nexa.brightBlue,fontWeight:FontWeight.w800,fontSize:9))),
        ])),
        Expanded(child:ListView(padding:const EdgeInsets.symmetric(horizontal:16),children:[
          for(final i in available)Padding(padding:const EdgeInsets.only(bottom:5),child:Material(
            color:Colors.transparent,child:InkWell(borderRadius:BorderRadius.circular(9),onTap:()=>setState(()=>page=i),child:Container(
              height:45,padding:const EdgeInsets.symmetric(horizontal:13),decoration:BoxDecoration(
                gradient:i==page?Nexa.blueGradient:null,borderRadius:BorderRadius.circular(9)),
              child:Row(children:[Icon(menu[i].icon,size:19,color:i==page?Colors.white:Nexa.secondary),const SizedBox(width:14),Expanded(child:Text(menu[i].label,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:i==page?Colors.white:Nexa.muted,fontSize:13,fontWeight:i==page?FontWeight.w700:FontWeight.w500)))]),
            ))) )
        ])),
        Padding(padding:const EdgeInsets.fromLTRB(15,12,15,12),child:NexaPanel(padding:const EdgeInsets.all(13),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Row(children:[Icon(Icons.verified_user_outlined,color:Nexa.orange,size:18),SizedBox(width:8),Text('License status',style:TextStyle(color:Nexa.white,fontSize:12,fontWeight:FontWeight.w700))]),
          const SizedBox(height:11),const LicenseCountdown(compact:true),
          const SizedBox(height:9),const Text('Offline • SQLite • Single PC',style:TextStyle(color:Nexa.secondary,fontSize:10)),
        ]))),
      ])),
      Expanded(child:Column(children:[
        Container(height:63,decoration:BoxDecoration(color:dark?Nexa.header:Colors.white,border:Border(bottom:BorderSide(color:dark?Nexa.outline:const Color(0xFFE8EDF5)))),padding:const EdgeInsets.symmetric(horizontal:22),child:Row(children:[
          Expanded(child:Text(menu[page].label,style:TextStyle(fontSize:18,color:dark?Nexa.white:ink,fontWeight:FontWeight.w800))),
          TextButton.icon(onPressed:()=>searchModules(available),icon:Icon(Icons.search,size:18,color:dark?Nexa.muted:ink),label:Text('Search modules...',style:TextStyle(fontSize:12,color:dark?Nexa.muted:ink))),
          const SizedBox(width:9),IconButton(tooltip:'Refresh',onPressed:refresh,icon:Icon(Icons.refresh,size:19,color:dark?Nexa.muted:ink)),
          const SizedBox(width:8),const LicenseCountdown(compact:true),const SizedBox(width:8),Container(width:1,height:26,color:dark?Nexa.outline:const Color(0xFFE3E7F0)),const SizedBox(width:12),
          const Icon(Icons.account_circle_outlined,color:Nexa.brightBlue,size:29),const SizedBox(width:9),
          Text(core.current?.username??'',style:TextStyle(color:dark?Nexa.white:ink,fontWeight:FontWeight.w700,fontSize:12)),
          IconButton(tooltip:'Sign out',onPressed:core.signOut,icon:Icon(Icons.logout,size:18,color:dark?Nexa.muted:ink)),
        ])),
        Expanded(child:KeyedSubtree(key:ValueKey('$page-$revision'),child:screen())),
      ])),
    ]));
  }
}


class PosWorkspace extends StatefulWidget {
  final VoidCallback onChange;
  const PosWorkspace({super.key,required this.onChange});
  @override State<PosWorkspace> createState()=>_PosWorkspaceState();
}
class _PosWorkspaceState extends State<PosWorkspace> {
  String kind='sale';
  @override Widget build(BuildContext context)=>Column(children:[
    Padding(padding:const EdgeInsets.fromLTRB(20,14,20,0),child:Row(children:[
      const Text('Point of Sale',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800)),const Spacer(),
      SegmentedButton<String>(segments:const [
        ButtonSegment(value:'sale',label:Text('Sales POS'),icon:Icon(Icons.sell_outlined)),
        ButtonSegment(value:'purchase',label:Text('Purchase POS'),icon:Icon(Icons.local_shipping_outlined))
      ],selected:{kind},onSelectionChanged:(values)=>setState(()=>kind=values.first)),
    ])),
    Expanded(child:ModernPosScreen(key:ValueKey(kind),kind:kind,onChange:widget.onChange)),
  ]);
}

class _ModuleSearchDelegate extends SearchDelegate<int?> {
  final List<({String label,IconData icon})> items;
  final List<int> available;
  _ModuleSearchDelegate(this.items,this.available);
  @override List<Widget> buildActions(BuildContext context)=>[IconButton(onPressed:()=>query='',icon:const Icon(Icons.clear))];
  @override Widget buildLeading(BuildContext context)=>IconButton(onPressed:()=>close(context,null),icon:const Icon(Icons.arrow_back));
  @override Widget buildResults(BuildContext context)=>buildSuggestions(context);
  @override Widget buildSuggestions(BuildContext context){
    final matches=available.where((i)=>items[i].label.toLowerCase().contains(query.trim().toLowerCase())).toList();
    return ListView(children:[for(final i in matches)ListTile(leading:Icon(items[i].icon),title:Text(items[i].label),onTap:()=>close(context,i))]);
  }
}

Widget section(String title,{Widget? action})=>Padding(padding:const EdgeInsets.only(bottom:16),child:Row(children:[Expanded(child:Text(title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800,color:ink))),if(action!=null)action]));
Widget addButton(String label,VoidCallback onTap)=>FilledButton.icon(onPressed:canShopAction('create')?onTap:null,icon:const Icon(Icons.add,size:17),label:Text(label));
Widget pageWrap(List<Widget> children)=>SingleChildScrollView(padding:const EdgeInsets.all(25),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:children));
Widget panel(Widget child)=>Card(child:Padding(padding:const EdgeInsets.all(19),child:child));
Widget listing(List<String> headers,List<List<Widget>> rows)=>panel(_WideTable(headers:headers,rows:rows));
class _WideTable extends StatefulWidget{
  final List<String> headers;final List<List<Widget>> rows;
  const _WideTable({required this.headers,required this.rows});
  @override State<_WideTable> createState()=>_WideTableState();
}
class _WideTableState extends State<_WideTable>{
  final ScrollController controller=ScrollController();
  @override void dispose(){controller.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scrollbar(controller:controller,thumbVisibility:true,trackVisibility:true,thickness:11,
    child:SingleChildScrollView(controller:controller,scrollDirection:Axis.horizontal,child:DataTable(
      headingRowHeight:47,dataRowMinHeight:47,dataRowMaxHeight:80,columnSpacing:24,
      columns:widget.headers.map((h)=>DataColumn(label:Text(h,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:12)))).toList(),
      rows:widget.rows.map((r)=>DataRow(cells:r.map((w)=>DataCell(w)).toList())).toList())));
}
Widget txt(Object? s)=>Text('${s??''}',style:const TextStyle(fontSize:13));
Widget buttons(List<Widget> widgets)=>Wrap(spacing:6,children:widgets);
Widget small(String s,VoidCallback tap,{IconData icon=Icons.edit_outlined}){
  final title=s.toLowerCase();
  final action=title.contains('view')||title.contains('print')?'view':title.contains('archive')||title.contains('void')||title.contains('disable')?'delete':title.contains('edit')||title.contains('rename')||title.contains('correct')?'edit':'create';
  return IconButton(tooltip:s,onPressed:canShopAction(action)?tap:null,icon:Icon(icon,size:18));
}
Future<Map<int,String>> options(Store s,String query,[List<Object?> args=const []]) async => {for(final x in await s.read(query,args))x['id'] as int:'${x['name']}'};
Future<Map<int,String>> variants(Store s) async => {for(final x in await s.stock())x['id'] as int:'${x['product']} • ${x['sku']} (${x['unit']})'};
Future<Map<int,String>> accountChoices(Store s)=>options(s,"SELECT id,name FROM accounts WHERE type='asset' AND code IN ('1000','1010') ORDER BY id");

class Dashboard extends StatelessWidget {
  final int revision;const Dashboard({super.key,required this.revision});
  @override Widget build(BuildContext context)=>FutureBuilder<List<Object>>(future:Future.wait([
    Store.instance.read('SELECT count(*) AS n FROM variants WHERE active=1'),Store.instance.read("SELECT coalesce(sum(total),0) AS n FROM documents WHERE kind='sale' AND status='POSTED' AND date=?",[nowDate()]),
    Store.instance.read('SELECT count(*) AS n FROM (SELECT v.id FROM variants v LEFT JOIN stock_movements m ON m.variant_id=v.id GROUP BY v.id HAVING coalesce(sum(m.qty),0)<=0)'),
    Store.instance.read("SELECT coalesce(sum(CASE WHEN pa.kind='customer' THEN l.debit-l.credit ELSE 0 END),0) AS n FROM party_ledger l JOIN parties pa ON pa.id=l.party_id"),
    Store.instance.read("SELECT coalesce(sum(CASE WHEN pa.kind='supplier' THEN l.credit-l.debit ELSE 0 END),0) AS n FROM party_ledger l JOIN parties pa ON pa.id=l.party_id"),
    Store.instance.read("SELECT d.date,d.invoice,d.kind,d.total,coalesce(pa.name,'Walk-in') AS party FROM documents d LEFT JOIN parties pa ON pa.id=d.party_id WHERE d.status='POSTED' ORDER BY d.id DESC LIMIT 10")
  ]),builder:(ctx,snap){if(!snap.hasData)return const Center(child:CircularProgressIndicator());
    final data=snap.data!;int first(int i)=>numVal((data[i] as List<Map<String,Object?>>).first['n']).toInt();
    final recent=data[5] as List<Map<String,Object?>>;
    final cards=[('Products / Variants','${first(0)}',Icons.inventory_2_outlined),('Today Sales',funds(first(1)),Icons.receipt_long_outlined),('Zero / Negative Stock','${first(2)}',Icons.warning_amber_rounded),('Customer Balance',funds(first(3)),Icons.people_outline),('Supplier Payable',funds(first(4)),Icons.local_shipping_outlined)];
    return pageWrap([const Text('Shop overview',style:TextStyle(fontSize:14,color:Colors.blueGrey)),const SizedBox(height:14),
      Wrap(spacing:12,runSpacing:12,children:cards.map((c)=>SizedBox(width:225,child:Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(c.$3,color:blue),const SizedBox(height:12),Text(c.$1,style:const TextStyle(color:Colors.blueGrey,fontSize:12)),const SizedBox(height:7),Text(c.$2,style:const TextStyle(fontWeight:FontWeight.w800,color:ink,fontSize:20))]))))).toList()),
      const SizedBox(height:25),section('Recent transactions'),listing(['Date','Invoice','Type','Party','Total'],recent.map((r)=>[txt(r['date']),txt(r['invoice']),txt(r['kind']),txt(r['party']),txt(funds(r['total']))]).toList()),
      const Padding(padding:EdgeInsets.only(top:10),child:Text('Note: Profit is not finalized until inventory costing / COGS is implemented.',style:TextStyle(fontSize:12,color:Colors.blueGrey)))]);
  });
}

class CategoriesScreen extends StatefulWidget {final VoidCallback onChange;const CategoriesScreen({super.key,required this.onChange});@override State<CategoriesScreen> createState()=>_CategoriesScreenState();}
class _CategoriesScreenState extends State<CategoriesScreen>{final s=Store.instance;int? selected;
  Future<void> run(Future<void> Function() fn)async{try{await fn();widget.onChange();}catch(e){if(mounted)await showError(context,e);}}
  @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,Object?>>>(future:s.read('SELECT * FROM categories WHERE active=1 ORDER BY name'),builder:(ctx,c){if(!c.hasData)return const Center(child:CircularProgressIndicator());
    final cats=c.data!;selected ??=cats.isEmpty?null:cats.first['id'] as int;
    return pageWrap([section('Categories',action:addButton('New category',()=>run(()async{final f=await ask(context,'Add category',[const FieldSpec('name','Name')]);if(f!=null)await s.addCategory(f['name']!);}))),
      listing(['Category','Actions'],cats.map((x)=>[txt(x['name']),buttons([small('Edit',()=>run(()async{final f=await ask(context,'Rename category',[FieldSpec('name','Name',initial:'${x['name']}')]);if(f!=null)await s.db.rawUpdate('UPDATE categories SET name=? WHERE id=?',[f['name'],x['id']]);})),small('Archive',()=>run(()async{if(await confirm(context,'Archive this category?'))await s.archive('categories',x['id'] as int);}),icon:Icons.archive_outlined)])]).toList()),
      const SizedBox(height:12),section('Category-specific product fields',action:addButton('Add field',()=>run(()async{
        final f=await ask(context,'Define dynamic field',[FieldSpec('cat','Category',choices:{for(final x in cats)x['id'] as int:'${x['name']}'}),const FieldSpec('name','Field name'),const FieldSpec('kind','Type (text / number / choice)',initial:'text'),const FieldSpec('choices','Choices separated by |',mustFill:false)]);
        if(f!=null){if(!{'text','number','choice'}.contains(f['kind']))throw const FormatException('Type must be text, number or choice');await s.addAttribute(int.parse(f['cat']!),f['name']!,f['kind']!,f['choices']!);}
      }))),FutureBuilder<List<Map<String,Object?>>>(future:s.read('SELECT a.id,a.name,a.kind,a.choices,c.name AS category FROM attributes a JOIN categories c ON c.id=a.category_id ORDER BY c.name,a.name'),builder:(ctx,a)=>a.hasData?listing(['Category','Field','Type','Choices','Action'],a.data!.map((x)=>[txt(x['category']),txt(x['name']),txt(x['kind']),txt(x['choices']),small('Edit',()=>run(()async{
        final f=await ask(context,'Edit field',[FieldSpec('name','Name',initial:'${x['name']}'),FieldSpec('kind','Type',initial:'${x['kind']}'),FieldSpec('choices','Choices',initial:'${x['choices']}',mustFill:false)]);if(f!=null)await s.db.rawUpdate('UPDATE attributes SET name=?,kind=?,choices=? WHERE id=?',[f['name'],f['kind'],f['choices'],x['id']]);}))]).toList()):const LinearProgressIndicator())]);
  });
}

class ProductsScreen extends StatefulWidget {final VoidCallback onChange;const ProductsScreen({super.key,required this.onChange});@override State<ProductsScreen> createState()=>_ProductsScreenState();}
class _ProductsScreenState extends State<ProductsScreen>{final s=Store.instance;
  Future<void> change(Future<void> Function() fn) async{try{await fn();widget.onChange();}catch(e){if(mounted)await showError(context,e);}}
  Future<void> addVariant(int? preselect)async{
    final products=await s.read('SELECT id,name,category_id FROM products WHERE active=1 ORDER BY name');if(products.isEmpty)throw const FormatException('Create a product first');
    if(!mounted)return;
    final f=await ask(context,'New stock variation',[FieldSpec('product','Product',initial:preselect==null?'':'$preselect',choices:{for(final x in products)x['id'] as int:'${x['name']}'}),const FieldSpec('sku','SKU / Barcode'),const FieldSpec('unit','Unit (pcs / meter / roll / ft)',initial:'pcs'),const FieldSpec('opening','Opening stock',initial:'0',numeric:true)]);
    if(f==null)return;
    final product=int.parse(f['product']!);final cat=products.firstWhere((p)=>p['id']==product)['category_id'];
    final attrs=await s.read('SELECT * FROM attributes WHERE category_id=? ORDER BY name',[cat]);
    final values=<int,String>{};
    if(attrs.isNotEmpty&&mounted){
      final custom=await ask(context,'Set variation attributes',attrs.map((a)=>FieldSpec('${a['id']}','${a['name']} (${a['kind']})',mustFill:false)).toList());
      if(custom==null)return;
      for(final x in custom.entries){if(x.value.isNotEmpty)values[int.parse(x.key)]=x.value;}
    }
    await s.addVariant(product,f['sku']!,f['unit']!,values,double.parse(f['opening']!));
  }
  @override Widget build(BuildContext context)=>FutureBuilder<List<Object>>(future:Future.wait([s.read('SELECT p.*,c.name AS category FROM products p JOIN categories c ON c.id=p.category_id WHERE p.active=1 ORDER BY p.name'),s.stock()]),builder:(ctx,snap){if(!snap.hasData)return const Center(child:CircularProgressIndicator());
    final products=snap.data![0] as List<Map<String,Object?>>;final stock=snap.data![1] as List<Map<String,Object?>>;
    return pageWrap([section('Product catalog',action:buttons([addButton('Add product',()=>change(()async{final cats=await options(s,'SELECT id,name FROM categories WHERE active=1 ORDER BY name');if(cats.isEmpty)throw const FormatException('Create category first');if(!mounted)return;final f=await ask(context,'Add product',[FieldSpec('category','Category',choices:cats),const FieldSpec('name','Product name')]);if(f!=null)await s.addProduct(int.parse(f['category']!),f['name']!);})),
      addButton('Add variation',()=>change(()=>addVariant(null)))])),
      listing(['Product','Category','Manage'],products.map((p)=>[txt(p['name']),txt(p['category']),buttons([
        small('Add variation',()=>change(()=>addVariant(p['id'] as int)),icon:Icons.add_circle_outline),
        small('Rename',()=>change(()async{final f=await ask(context,'Rename product',[FieldSpec('name','Name',initial:'${p['name']}')]);if(f!=null)await s.db.rawUpdate('UPDATE products SET name=? WHERE id=?',[f['name'],p['id']]);})),
        small('Archive',()=>change(()async{if(await confirm(context,'Archive product? Existing transactions remain.'))await s.archive('products',p['id'] as int);}),icon:Icons.archive_outlined)])]).toList()),
      const SizedBox(height:15),section('Variants & stock'),listing(['SKU','Product','Attributes','Unit','Stock','Actions'],stock.map((v)=>[txt(v['sku']),txt(v['product']),SizedBox(width:220,child:txt(v['attrs'])),txt(v['unit']),Text('${v['qty']}',style:TextStyle(fontWeight:FontWeight.bold,color:numVal(v['qty'])<0?Colors.red:ink)),buttons([
        small('Edit attributes',()=>change(()async{
          final id=v['id'] as int;
          final attrs=await s.read('''SELECT a.id,a.name,a.kind,a.choices,coalesce(vv.value,'') AS val
            FROM variants vr JOIN products p ON p.id=vr.product_id
            JOIN attributes a ON a.category_id=p.category_id
            LEFT JOIN variant_values vv ON vv.attribute_id=a.id AND vv.variant_id=vr.id
            WHERE vr.id=? ORDER BY a.name''',[id]);
          if(attrs.isEmpty)throw const FormatException('This category has no custom fields');
          if(!mounted)return;
          final vals=await ask(context,'Edit variation fields',attrs.map((a)=>FieldSpec('${a['id']}','${a['name']} • ${a['kind']}${a['kind']=='choice'?' • ${a['choices']}':''}',initial:'${a['val']}',mustFill:false,numeric:a['kind']=='number')).toList());
          if(vals!=null)await s.updateVariantValues(id,{for(final e in vals.entries)int.parse(e.key):e.value});
        }),icon:Icons.tune_outlined),
        small('Edit SKU/unit',()=>change(()async{final f=await ask(context,'Edit variant',[FieldSpec('sku','SKU',initial:'${v['sku']}'),FieldSpec('unit','Unit',initial:'${v['unit']}')]);if(f!=null)await s.db.rawUpdate('UPDATE variants SET sku=?,unit=? WHERE id=?',[f['sku'],f['unit'],v['id']]);})),
        small('Archive',()=>change(()async{if(await confirm(context,'Archive variant?'))await s.archive('variants',v['id'] as int);}),icon:Icons.archive_outlined)])]).toList())]);
  });
}

class StockScreen extends StatefulWidget{final VoidCallback onChange;const StockScreen({super.key,required this.onChange});@override State<StockScreen> createState()=>_StockScreenState();}
class _StockScreenState extends State<StockScreen>{final s=Store.instance;
  Future<void> add()async{try{final vs=await variants(s);if(!mounted)return;final f=await ask(context,'Stock adjustment',[FieldSpec('variant','Product / SKU',choices:vs),const FieldSpec('qty','Quantity change (+ / -)',numeric:true),const FieldSpec('note','Reason')]);
    if(f!=null){await s.adjustStock(int.parse(f['variant']!),double.parse(f['qty']!),f['note']!);widget.onChange();}
  }catch(e){if(mounted)await showError(context,e);}}
  @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,Object?>>>(future:s.stock(),builder:(ctx,snap){if(!snap.hasData)return const Center(child:CircularProgressIndicator());
    final all=snap.data!;return pageWrap([section('Live stock balances',action:addButton('Adjust stock',add)),
      panel(const Text('Negative stock is allowed. Invoice save does not block at zero stock. Purchases increase the same variant stock automatically.',style:TextStyle(color:Colors.blueGrey))),
      listing(['Product','SKU','Category','Unit','Available','Status'],all.map((v){final qty=numVal(v['qty']);return [txt(v['product']),txt(v['sku']),txt(v['category']),txt(v['unit']),Text('$qty',style:TextStyle(fontWeight:FontWeight.w800,color:qty<0?Colors.red:qty==0?Colors.orange:ink)),Text(qty<0?'NEGATIVE':qty==0?'EMPTY':'IN STOCK',style:TextStyle(color:qty<0?Colors.red:Colors.blueGrey,fontWeight:FontWeight.w700,fontSize:11))];}).toList())]);
  });
}

class DocumentScreen extends StatefulWidget {final String kind;final VoidCallback onChange;const DocumentScreen({super.key,required this.kind,required this.onChange});@override State<DocumentScreen> createState()=>_DocumentScreenState();}
class _DocumentScreenState extends State<DocumentScreen>{final s=Store.instance;
  String term='',paymentFilter='All';
  final searchController=TextEditingController();
  late Future<List<Map<String,Object?>>> invoiceFuture;
  @override void initState(){super.initState();invoiceFuture=loadInvoices();}
  Future<List<Map<String,Object?>>> loadInvoices()=>s.read('''SELECT d.*,coalesce(p.name,'Walk-in') AS party FROM documents d
    LEFT JOIN parties p ON p.id=d.party_id WHERE d.kind=? ORDER BY d.id DESC LIMIT 500''',[widget.kind]);
  @override void dispose(){searchController.dispose();super.dispose();}

  Future<void> create([int? existing]) async {final ok=await showDialog<bool>(context:context,builder:(ctx)=>InvoiceDialog(kind:widget.kind,existingId:existing));if(ok==true)widget.onChange();}
  Future<void> voidIt(int id)async{try{if(await confirm(context,'Void invoice? Stock, balances and journal entries will be reversed.')){await s.voidDocument(id);widget.onChange();}}catch(e){if(mounted)await showError(context,e);}}
  Future<void> previewInvoice(Map<String,Object?> row)async{
    try{final x=await s.read('''SELECT p.name AS Product,v.sku AS SKU,l.qty AS Qty,l.rate/100.0 AS Rate,l.amount/100.0 AS Amount FROM document_lines l JOIN variants v ON v.id=l.variant_id JOIN products p ON p.id=v.product_id WHERE l.document_id=?''',[row['id']]);
      final rpt=ReportResult('Invoice ${row['invoice']}',const ['Product','SKU','Qty','Rate','Amount'],x.map((r)=>['${r['Product']}','${r['SKU']}','${r['Qty']}','${r['Rate']}','${r['Amount']}']).toList());
      if(!mounted)return;
      await showDialog(context:context,builder:(ctx)=>AlertDialog(title:Text('${row['invoice']}  |  ${row['party']}'),content:SizedBox(width:640,child:Column(mainAxisSize:MainAxisSize.min,children:[listing(rpt.headings,rpt.rows.map((r)=>r.map((v)=>txt(v)).toList()).toList()),Text('Total: ${funds(row['total'])}     Paid: ${funds(row['paid'])}')])) ,actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Close')),OutlinedButton.icon(onPressed:()=>Exports.pdf(rpt),icon:const Icon(Icons.picture_as_pdf),label:const Text('PDF')),FilledButton.icon(onPressed:()=>Exports.pdf(rpt,print:true),icon:const Icon(Icons.print),label:const Text('A4 Print'))]));
    }catch(e){if(mounted)await showError(context,e);}
  }
  @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,Object?>>>(
    future:invoiceFuture,
    builder:(ctx,snap){if(!snap.hasData)return const Center(child:CircularProgressIndicator());
      final search=term.trim().toLowerCase();
      final filtered=snap.data!.where((r){
        if(search.isNotEmpty&&!('${r['invoice']} ${r['party']}'.toLowerCase().contains(search)))return false;
        final total=numVal(r['total']),paid=numVal(r['paid']);
        final status=paid>=total?'Paid':paid>0?'Partially Paid':'Unpaid';
        return paymentFilter=='All'||paymentFilter==status;
      }).toList();
      return pageWrap([
        section(widget.kind=='sale'?'Sales Invoices':'Purchase Invoices'),
        panel(Wrap(spacing:14,runSpacing:12,crossAxisAlignment:WrapCrossAlignment.center,children:[
          SizedBox(width:360,child:TextField(controller:searchController,decoration:const InputDecoration(prefixIcon:Icon(Icons.search),labelText:'Search invoice number or customer / supplier'),onChanged:(value)=>setState(()=>term=value))),
          SizedBox(width:205,child:DropdownButtonFormField<String>(key:ValueKey(paymentFilter),initialValue:paymentFilter,decoration:const InputDecoration(labelText:'Payment status'),items:['All','Paid','Unpaid','Partially Paid'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(value)=>setState(()=>paymentFilter=value??'All'))),
          OutlinedButton.icon(onPressed:(){searchController.clear();setState((){term='';paymentFilter='All';});},icon:const Icon(Icons.filter_alt_off),label:const Text('Clear Filters')),
          Text('${filtered.length} invoices',style:const TextStyle(fontWeight:FontWeight.w700,color:ink)),
        ])),
        listing(['Date','Invoice Number','Customer / Supplier','Total','Paid','Balance','Payment Status','Invoice Status','Actions'],filtered.map((r){
          final total=numVal(r['total']),paid=numVal(r['paid']);
          final paymentStatus=paid>=total?'Paid':paid>0?'Partially Paid':'Unpaid';
          return [txt(r['date']),txt(r['invoice']),txt(r['party']),txt(funds(r['total'])),txt(funds(r['paid'])),txt(funds(total-paid)),
            Text(paymentStatus,style:TextStyle(color:paymentStatus=='Paid'?const Color(0xFF16865B):const Color(0xFFBA651A),fontWeight:FontWeight.w800)),
            txt(r['status']),buttons([
              small('View / Print A4',()=>previewInvoice(r),icon:Icons.print_outlined),
              if(r['status']=='POSTED')small('Correct invoice',()=>create(r['id'] as int),icon:Icons.edit_note_outlined),
              if(r['status']=='POSTED')small('Void',()=>voidIt(r['id'] as int),icon:Icons.block)
            ])];
        }).toList()),
      ]);
    });

}


/// Stock returns, with per-invoice-line quantities and cash/credit refunds.
class ReturnScreen extends StatefulWidget {final VoidCallback onChange;final String kind;const ReturnScreen({super.key,required this.kind,required this.onChange});
  @override State<ReturnScreen> createState()=>_ReturnScreenState();}
class _ReturnScreenState extends State<ReturnScreen>{final s=Store.instance;
  Future<void> change(Future<void> Function() action)async{
    try{await action();widget.onChange();}catch(e){if(mounted)await showError(context,e);}
  }
  Future<void> add()async{
    final docs=await s.read("SELECT d.id,d.invoice,d.kind,coalesce(p.name,'Walk-in') AS party FROM documents d LEFT JOIN parties p ON p.id=d.party_id WHERE d.status='POSTED' AND d.kind=? ORDER BY d.id DESC LIMIT 300",[widget.kind]);
    if(docs.isEmpty)throw const FormatException('Create a sale or purchase first');
    if(!mounted)return;
    final choice=await ask(context,'Select original sale / purchase',[FieldSpec('doc','Invoice',choices:{for(final d in docs)d['id'] as int:'${d['invoice']} • ${d['party']}'})]);
    if(choice==null)return;
    final id=int.parse(choice['doc']!);
    final lines=await s.read('''SELECT l.id,p.name AS product,v.sku,l.qty,l.rate,
      coalesce((SELECT sum(rl.qty) FROM return_lines rl JOIN document_returns dr ON dr.id=rl.return_id
      WHERE rl.source_line_id=l.id AND dr.status='POSTED'),0) AS previously_returned
      FROM document_lines l JOIN variants v ON v.id=l.variant_id JOIN products p ON p.id=v.product_id WHERE l.document_id=?''',[id]);
    final accounts=await accountChoices(s);
    if(!mounted)return;
    final specs=<FieldSpec>[
      ...lines.map((l)=>FieldSpec('line_${l['id']}','${l['product']} / ${l['sku']} • remaining ${numVal(l['qty'])-numVal(l['previously_returned'])}',initial:'0',numeric:true)),
      const FieldSpec('refund','Refund now Rs. (0 if credit adjustment)',initial:'0',numeric:true),
      FieldSpec('account','Cash / Bank account',choices:accounts),
      const FieldSpec('reason','Return reason',initial:'Customer / supplier return')];
    final f=await ask(context,'Return items by invoice line',specs);
    if(f==null)return;
    final items=<ReturnItem>[];
    for(final l in lines){final amount=double.parse(f['line_${l['id']}']!);if(amount>0)items.add(ReturnItem(l['id'] as int,amount));}
    await s.postReturn(id,items,double.parse(f['refund']!),int.parse(f['account']!),f['reason']!);
  }
  @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,Object?>>>(future:s.read('''
    SELECT r.*,d.invoice,d.kind,coalesce(p.name,'Walk-in') AS party FROM document_returns r
    JOIN documents d ON d.id=r.document_id LEFT JOIN parties p ON p.id=d.party_id WHERE d.kind=? ORDER BY r.id DESC LIMIT 300
  ''',[widget.kind]),builder:(ctx,snap){if(!snap.hasData)return const Center(child:CircularProgressIndicator());
    return pageWrap([section(widget.kind=='sale'?'Sale Returns':'Purchase Returns',action:addButton('New return',()=>change(add))),
      panel(const Text('Returning a sold item adds stock; returning a purchased item subtracts stock. Partial quantities and refunds are permitted. Posted returns can be reversed with a full audit trail.',style:TextStyle(color:Colors.blueGrey))),
      listing(['Date','Original invoice','Type','Customer / Supplier','Return Value','Cash Refund','Status','Action'],snap.data!.map((r)=>[
        txt(r['date']),txt(r['invoice']),txt(r['kind']),txt(r['party']),txt(funds(r['amount'])),txt(funds(r['refunded'])),txt(r['status']),
        r['status']=='POSTED'?small('Void return',()=>change(()async{if(await confirm(context,'Void return? Stock, ledger and cash entries will be reversed.'))await s.voidReturn(r['id'] as int);}),icon:Icons.undo):txt('—')]).toList())]);
  });
}

class InvoiceDialog extends StatefulWidget {final String kind;final int? existingId;const InvoiceDialog({super.key,required this.kind,this.existingId});@override State<InvoiceDialog> createState()=>_InvoiceDialogState();}
class _InvoiceDialogState extends State<InvoiceDialog>{
  final s=Store.instance;final paid=TextEditingController(text:'0');final notes=TextEditingController();
  List<Map<String,Object?>> products=[];Map<int,String> parties={};Map<int,String> accounts={};
  int? party;int? cash;String date=nowDate();bool submitting=false;
  final lines=<_DraftLine>[];
  @override void initState(){super.initState();load();}
  Future<void> load() async{
    final variants=await s.stock();final p=await options(s,'SELECT id,name FROM parties WHERE kind=? AND active=1 ORDER BY name',[widget.kind=='sale'?'customer':'supplier']);final a=await accountChoices(s);
    Map<String,Object?>? existing;
    List<Map<String,Object?>>? oldLines;
    int? oldPaymentAccount;
    if(widget.existingId!=null){
      final rows=await s.read("SELECT * FROM documents WHERE id=? AND status='POSTED' AND kind=?",[widget.existingId,widget.kind]);
      if(rows.isEmpty)throw const FormatException('Invoice not found or already voided');
      existing=rows.first;
      oldLines=await s.read('SELECT variant_id,qty,rate FROM document_lines WHERE document_id=? ORDER BY id',[widget.existingId]);
      final previousAccounts=await s.read("SELECT jl.account_id FROM journal j JOIN journal_lines jl ON jl.journal_id=j.id JOIN accounts a ON a.id=jl.account_id WHERE j.source_type=? AND j.source_id=? AND a.code IN ('1000','1010') LIMIT 1",[widget.kind,widget.existingId]);
      if(previousAccounts.isNotEmpty)oldPaymentAccount=previousAccounts.first['account_id'] as int;
    }
    if(!mounted)return;
    setState((){
      products=variants;parties=p;accounts=a;
      party=existing==null?(widget.kind=='purchase'&&p.isNotEmpty?p.keys.first:null):existing['party_id'] as int?;
      cash=oldPaymentAccount??(a.isNotEmpty?a.keys.first:null);
      if(existing!=null){
        date=existing['date'] as String;
        paid.text=rupees(existing['paid']).toStringAsFixed(2);
        notes.text='${existing['notes']}';
        for(final row in oldLines!){lines.add(_DraftLine(row['variant_id'] as int,quantity:'${row['qty']}',price:rupees(row['rate']).toStringAsFixed(2)));}
      }else {lines.add(_DraftLine(variants.isEmpty?0:variants.first['id'] as int));}
    });
  }
  @override void dispose(){paid.dispose();notes.dispose();for(final l in lines)l.dispose();super.dispose();}
  double get total=>lines.fold(0.0,(t,l)=>t+(double.tryParse(l.qty.text)??0)*(double.tryParse(l.rate.text)??0));
  Future<void> submit()async{
    if(submitting)return;
    try{
      if(cash==null||products.isEmpty)throw const FormatException('Create a product and payment account first');
      setState(()=>submitting=true);
      final items=lines.map((l)=>ItemLine(l.variant,double.parse(l.qty.text),double.parse(l.rate.text))).toList();
      if(widget.existingId!=null){await s.reviseDocument(widget.existingId!,widget.kind,party,date,items,double.parse(paid.text),cash!,notes:notes.text);}
      else{await s.postDocument(widget.kind,party,date,items,double.parse(paid.text),cash!,notes:notes.text);}
      if(mounted)Navigator.pop(context,true);
    }catch(e){if(mounted)await showError(context,e);}finally{if(mounted)setState(()=>submitting=false);}
  }
  @override Widget build(BuildContext context){return Dialog(shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:940,maxHeight:780),child:Padding(padding:const EdgeInsets.all(22),child:Column(children:[
    Row(children:[const Icon(Icons.receipt_long,color:blue),const SizedBox(width:12),Expanded(child:Text(widget.existingId!=null?'Correct posted invoice':widget.kind=='sale'?'Create Manual Bill':'Record Supplier Purchase',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:20))),IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close))]),
    const Divider(),Expanded(child:ListView(children:[
      Row(children:[Expanded(child:DropdownButtonFormField<int?>(initialValue:party,decoration:InputDecoration(labelText:widget.kind=='sale'?'Customer (optional for cash sale)':'Supplier'),isExpanded:true,
        items:[if(widget.kind=='sale')const DropdownMenuItem<int?>(value:null,child:Text('Walk-in')), ...parties.entries.map((e)=>DropdownMenuItem<int?>(value:e.key,child:Text(e.value)))],onChanged:(x)=>setState(()=>party=x))),
        const SizedBox(width:14),Expanded(child:TextFormField(key:ValueKey('invoiceDate-$date'),initialValue:date,decoration:const InputDecoration(labelText:'Date YYYY-MM-DD'),onChanged:(v)=>date=v))]),
      const SizedBox(height:18),const Text('Line items • each variation has independent stock',style:TextStyle(fontWeight:FontWeight.w700)),const SizedBox(height:10),
      for(final l in lines)Padding(padding:const EdgeInsets.only(bottom:9),child:Row(children:[
        Expanded(flex:5,child:DropdownButtonFormField<int>(initialValue:l.variant==0?null:l.variant,isExpanded:true,decoration:const InputDecoration(labelText:'Product / SKU'),items:products.map((v)=>DropdownMenuItem(value:v['id'] as int,child:Text('${v['product']} | ${v['sku']} | stock ${v['qty']}',overflow:TextOverflow.ellipsis))).toList(),onChanged:(x)=>setState(()=>l.variant=x??0))),
        const SizedBox(width:9),Expanded(flex:2,child:TextField(controller:l.qty,decoration:const InputDecoration(labelText:'Qty'),keyboardType:TextInputType.number,onChanged:(_)=>setState((){}))),
        const SizedBox(width:9),Expanded(flex:2,child:TextField(controller:l.rate,decoration:InputDecoration(labelText:widget.kind=='sale'?'Manual Price':'Purchase Cost'),keyboardType:TextInputType.number,onChanged:(_)=>setState((){}))),
        const SizedBox(width:9),SizedBox(width:93,child:Text(rs((double.tryParse(l.qty.text)??0)*(double.tryParse(l.rate.text)??0)),style:const TextStyle(fontSize:11,fontWeight:FontWeight.bold))),
        IconButton(onPressed:lines.length<=1?null:(){setState(()=>lines.remove(l));l.dispose();},icon:const Icon(Icons.delete_outline))])),
      Align(alignment:Alignment.centerLeft,child:OutlinedButton.icon(onPressed:products.isEmpty?null:()=>setState(()=>lines.add(_DraftLine(products.first['id'] as int))),icon:const Icon(Icons.add),label:const Text('Add another line'))),
      const SizedBox(height:15),Row(children:[Expanded(child:DropdownButtonFormField<int>(initialValue:cash,decoration:const InputDecoration(labelText:'Payment account'),items:accounts.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(x)=>setState(()=>cash=x))),
        const SizedBox(width:12),Expanded(child:TextField(controller:paid,decoration:const InputDecoration(labelText:'Paid now (Rs.)'),keyboardType:TextInputType.number,onChanged:(_)=>setState((){})))]),
      const SizedBox(height:12),TextField(controller:notes,decoration:const InputDecoration(labelText:'Notes (optional)')),
      const SizedBox(height:10),const Text('Credit/partial sales require a customer. Negative stock will not block posting.',style:TextStyle(fontSize:11,color:Colors.blueGrey))])),
    if(widget.existingId!=null)const Text('Saving updates this same invoice number and ID. Prior stock and ledger entries remain in audit history.',style:TextStyle(fontSize:11,color:Colors.blueGrey)),
    const Divider(),Row(children:[Text('Grand Total    ${rs(total)}',style:const TextStyle(fontSize:21,color:ink,fontWeight:FontWeight.w900)),const Spacer(),TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),const SizedBox(width:12),FilledButton.icon(onPressed:submitting?null:submit,icon:const Icon(Icons.check),label:Text(submitting?'Saving…':'Post & Update Stock'))])]))));}
}
class _DraftLine {int variant;final qty=TextEditingController();final rate=TextEditingController();_DraftLine(this.variant,{String quantity='1',String price='0'}){qty.text=quantity;rate.text=price;}void dispose(){qty.dispose();rate.dispose();}}

class PartiesScreen extends StatefulWidget {final String kind;final VoidCallback onChange;const PartiesScreen({super.key,required this.kind,required this.onChange});@override State<PartiesScreen> createState()=>_PartiesScreenState();}
class _PartiesScreenState extends State<PartiesScreen>{final s=Store.instance;
  Future<void> change(Future<void> Function() f) async {try{await f();widget.onChange();}catch(e){if(mounted)await showError(context,e);}}
  Future<void> form([Map<String,Object?>? p])async{final f=await ask(context,p==null?'Add ${widget.kind}':'Edit ${widget.kind}',[
    FieldSpec('name','Name',initial:'${p?['name']??''}'),FieldSpec('phone','Phone',initial:'${p?['phone']??''}',mustFill:false),FieldSpec('address','Address',initial:'${p?['address']??''}',mustFill:false)]);
    if(f!=null){if(p==null){await s.addParty(widget.kind,f['name']!,f['phone']!,f['address']!);}else{await s.updateParty(p['id'] as int,f['name']!,f['phone']!,f['address']!);}}
  }
  Future<void> ledger(Map<String,Object?> p)async{
    final kind=widget.kind=='customer'?'Customer Ledger':'Supplier Ledger';
    final report=await buildReport(s,ReportFilter(type:kind,start:'2000-01-01',end:'2100-01-01',party:p['id'] as int));
    if(!mounted)return;
    await showDialog(context:context,builder:(ctx)=>AlertDialog(title:Text('${p['name']} • $kind'),content:SizedBox(width:860,height:430,child:SingleChildScrollView(child:listing(report.headings,report.rows.map((r)=>r.map((v)=>txt(v)).toList()).toList()))),actions:[
      OutlinedButton(onPressed:()=>Exports.excel(report),child:const Text('Excel')),
      OutlinedButton(onPressed:()=>Exports.pdf(report),child:const Text('PDF')),
      OutlinedButton(onPressed:()=>Exports.pdf(report,print:true),child:const Text('Print A4')),
      TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Close'))]));
  }
  Future<void> opening(Map<String,Object?> p)async{
    final f=await ask(context,'Opening balance • ${p['name']}',[const FieldSpec('amount','Opening amount Rs.',numeric:true),const FieldSpec('note','Reference / Notes',initial:'Opening balance')]);
    if(f!=null)await s.openingPartyBalance(p['id'] as int,double.parse(f['amount']!),f['note']!);
  }
  Future<void> payments(Map<String,Object?> p)async{
    final rows=await s.read("SELECT r.*,a.name AS account,coalesce(v.id,0) AS is_void FROM receipts r JOIN accounts a ON a.id=r.account_id LEFT JOIN reversed_transactions v ON v.kind='receipt' AND v.source_id=r.id WHERE r.party_id=? ORDER BY r.id DESC",[p['id']]);
    if(!mounted)return;
    await showDialog(context:context,builder:(ctx)=>AlertDialog(title:Text('Payments • ${p['name']}'),content:SizedBox(width:680,height:400,child:SingleChildScrollView(child:listing(['Date','Amount','Account','Status','Action'],rows.map((r)=>[txt(r['date']),txt(funds(r['amount'])),txt(r['account']),txt(r['is_void']==0?'POSTED':'VOID'),r['is_void']==0?small('Reverse payment',()async{Navigator.pop(ctx);await change(()async{if(await confirm(context,'Reverse this payment with audit entry?'))await s.voidReceipt(r['id'] as int);});},icon:Icons.undo):txt('—')]).toList()))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Close'))]));
  }
  Future<void> pay(Map<String,Object?> p)async{final accounts=await accountChoices(s);if(!mounted)return;
    final f=await ask(context,widget.kind=='customer'?'Receive customer payment':'Pay supplier',[const FieldSpec('amount','Amount (Rs.)',numeric:true),FieldSpec('account','From / to account',choices:accounts),const FieldSpec('note','Reference / Note',mustFill:false)]);
    if(f!=null)await s.recordPayment(p['id'] as int,double.parse(f['amount']!),int.parse(f['account']!),f['note']!);
  }
  @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,Object?>>>(future:s.read('''SELECT p.*,coalesce(sum(CASE WHEN p.kind='customer' THEN l.debit-l.credit ELSE l.credit-l.debit END),0) AS balance
    FROM parties p LEFT JOIN party_ledger l ON l.party_id=p.id WHERE p.kind=? AND p.active=1 GROUP BY p.id ORDER BY p.name''',[widget.kind]),builder:(ctx,snap){if(!snap.hasData)return const Center(child:CircularProgressIndicator());
    return pageWrap([section(widget.kind=='customer'?'Customers & receivables':'Suppliers & payables',action:addButton('Add ${widget.kind}',()=>change(()=>form()))),
      listing(['Name','Phone','Address',widget.kind=='customer'?'Receivable':'Payable','Actions'],snap.data!.map((p)=>[
        txt(p['name']),txt(p['phone']),txt(p['address']),Text(funds(p['balance']),style:const TextStyle(fontWeight:FontWeight.w700)),
        buttons([small('Ledger',()=>ledger(p),icon:Icons.menu_book_outlined),small('Payment',()=>change(()=>pay(p)),icon:Icons.payments_outlined),small('Payments history',()=>payments(p),icon:Icons.history),small('Opening balance',()=>change(()=>opening(p)),icon:Icons.account_balance_wallet_outlined),
          small('Edit',()=>change(()=>form(p))),small('Archive',()=>change(()async{if(await confirm(context,'Archive record? The ledger will be preserved.'))await s.archive('parties',p['id'] as int);}),icon:Icons.archive_outlined)])]).toList())]);
  });
}

class ExpenseScreen extends StatefulWidget {final VoidCallback onChange;const ExpenseScreen({super.key,required this.onChange});@override State<ExpenseScreen> createState()=>_ExpenseScreenState();}
class _ExpenseScreenState extends State<ExpenseScreen>{final s=Store.instance;
  Future<void> change(Future<void> Function() f)async{try{await f();widget.onChange();}catch(e){if(mounted)await showError(context,e);}}
  Future<void> add()async{final cats=await options(s,'SELECT id,name FROM expense_categories ORDER BY name');final ac=await accountChoices(s);if(!mounted)return;
    final f=await ask(context,'Record an expense',[FieldSpec('category','Expense category',choices:cats),const FieldSpec('amount','Amount (Rs.)',numeric:true),FieldSpec('account','Paid from',choices:ac),FieldSpec('date','Date',initial:nowDate()),const FieldSpec('note','Description',mustFill:false)]);
    if(f!=null)await s.addExpense(int.parse(f['category']!),double.parse(f['amount']!),int.parse(f['account']!),f['note']!,f['date']!);
  }
  @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,Object?>>>(future:s.read("SELECT e.*,c.name AS category,a.name AS account,coalesce(r.id,0) AS reversed FROM expenses e JOIN expense_categories c ON c.id=e.category_id JOIN accounts a ON a.id=e.account_id LEFT JOIN reversed_transactions r ON r.kind='expense' AND r.source_id=e.id ORDER BY e.id DESC LIMIT 300"),builder:(ctx,snap){if(!snap.hasData)return const Center(child:CircularProgressIndicator());
    return pageWrap([section('Expense management',action:buttons([addButton('New category',()=>change(()async{final f=await ask(context,'Add expense category',[const FieldSpec('name','Category')]);if(f!=null)await s.db.rawInsert('INSERT INTO expense_categories(name) VALUES(?)',[f['name']]);})),addButton('Edit category',()=>change(()async{
        final categories=await options(s,'SELECT id,name FROM expense_categories ORDER BY name');
        final f=await ask(context,'Edit expense category',[FieldSpec('id','Category',choices:categories),const FieldSpec('name','New name')]);
        if(f!=null)await s.db.rawUpdate('UPDATE expense_categories SET name=? WHERE id=?',[f['name'],int.parse(f['id']!)]);
      })),addButton('New expense',()=>change(add))])),
    listing(['Date','Category','Note','Account','Amount','Status / Action'],snap.data!.map((e)=>[txt(e['date']),txt(e['category']),txt(e['description']),txt(e['account']),txt(funds(e['amount'])),e['reversed']==0?small('Reverse expense',()=>change(()async{if(await confirm(context,'Reverse expense and accounting entry?'))await s.voidExpense(e['id'] as int);}),icon:Icons.undo):txt('VOID')]).toList()),
    panel(const Text('Financial corrections should use reversal journal entries, not silent deletion of posted expenses.',style:TextStyle(fontSize:12,color:Colors.blueGrey)))]);
  });
}

class EmployeeScreen extends StatefulWidget {final VoidCallback onChange;const EmployeeScreen({super.key,required this.onChange});@override State<EmployeeScreen> createState()=>_EmployeeScreenState();}
class _EmployeeScreenState extends State<EmployeeScreen>{final s=Store.instance;
  Future<void> change(Future<void> Function() f)async{try{await f();widget.onChange();}catch(e){if(mounted)await showError(context,e);}}
  Future<void> employee()async{final f=await ask(context,'Register employee',[const FieldSpec('name','Full name'),const FieldSpec('role','Designation'),const FieldSpec('salary','Monthly salary (Rs.)',numeric:true)]);if(f!=null)await s.addEmployee(f['name']!,f['role']!,double.parse(f['salary']!));}
  Future<void> advance(Map<String,Object?> p)async{final ac=await accountChoices(s);if(!mounted)return;
    final f=await ask(context,'Advance • ${p['name']}',[const FieldSpec('amount','Advance Rs.',numeric:true),FieldSpec('account','Paid from',choices:ac)]);
    if(f!=null)await s.employeeAdvance(p['id'] as int,double.parse(f['amount']!),int.parse(f['account']!));
  }
  Future<void> salary(Map<String,Object?> p)async{final ac=await accountChoices(s);if(!mounted)return;
    final f=await ask(context,'Run salary • ${p['name']}',[FieldSpec('period','Period YYYY-MM',initial:nowDate().substring(0,7)),const FieldSpec('recovery','Advance recovery Rs.',numeric:true,initial:'0'),const FieldSpec('pay','Pay now Rs.',numeric:true,initial:'0'),FieldSpec('account','Paid from',choices:ac)]);
    if(f!=null)await s.payrollRun(p['id'] as int,f['period']!,double.parse(f['recovery']!),double.parse(f['pay']!),int.parse(f['account']!));
  }
  Future<void> settle(Map<String,Object?> p)async{final ac=await accountChoices(s);if(!mounted)return;
    final f=await ask(context,'Pay outstanding salary • ${p['name']}',[const FieldSpec('amount','Amount Rs.',numeric:true),FieldSpec('account','Payment account',choices:ac)]);
    if(f!=null)await s.paySalaryBalance(p['id'] as int,double.parse(f['amount']!),int.parse(f['account']!));
  }
  Future<void> ledger(Map<String,Object?> p)async{
    final report=await buildReport(s,ReportFilter(type:'Employee Ledger',start:'2000-01-01',end:'2100-01-01',employee:p['id'] as int));
    if(!mounted)return;
    await showDialog(context:context,builder:(ctx)=>AlertDialog(title:Text('${p['name']} • Employee ledger'),content:SizedBox(width:720,height:390,child:listing(report.headings,report.rows.map((row)=>row.map((v)=>txt(v)).toList()).toList())),actions:[
      OutlinedButton(onPressed:()=>Exports.excel(report),child:const Text('Excel')),
      OutlinedButton(onPressed:()=>Exports.pdf(report),child:const Text('PDF')),
      OutlinedButton(onPressed:()=>Exports.pdf(report,print:true),child:const Text('Print A4')),
      TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Close'))]));
  }
  @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,Object?>>>(future:s.read('''SELECT e.*,coalesce((SELECT sum(CASE WHEN kind='ADVANCE' THEN amount WHEN kind='RECOVERY' THEN -amount ELSE 0 END) FROM employee_ledger l WHERE l.employee_id=e.id),0) AS advance FROM employees e WHERE active=1 ORDER BY name'''),builder:(ctx,snap){if(!snap.hasData)return const Center(child:CircularProgressIndicator());
    return pageWrap([section('Employees, advances & payroll',action:addButton('Add employee',()=>change(employee))),
      listing(['Employee','Designation','Monthly Salary','Advance Due','Actions'],snap.data!.map((e)=>[txt(e['name']),txt(e['designation']),txt(funds(e['salary'])),txt(funds(e['advance'])),buttons([
        small('Give advance',()=>change(()=>advance(e)),icon:Icons.savings_outlined),small('Run payroll',()=>change(()=>salary(e)),icon:Icons.calculate_outlined),small('Pay salary due',()=>change(()=>settle(e)),icon:Icons.currency_exchange_outlined),small('Ledger',()=>ledger(e),icon:Icons.menu_book),
        small('Edit salary',()=>change(()async{final f=await ask(context,'Employee details',[FieldSpec('name','Name',initial:'${e['name']}'),FieldSpec('role','Role',initial:'${e['designation']}'),FieldSpec('salary','Salary Rs.',initial:'${rupees(e['salary'])}',numeric:true)]);if(f!=null)await s.db.rawUpdate('UPDATE employees SET name=?,designation=?,salary=? WHERE id=?',[f['name'],f['role'],pennies(double.parse(f['salary']!)),e['id']]);})),small('Archive',()=>change(()async{if(await confirm(context,'Archive this employee? Ledger and past payroll stay available.'))await s.archive('employees',e['id'] as int);}),icon:Icons.archive_outlined)
      ])]).toList())]);
  });
}

class AccountsScreen extends StatefulWidget {final VoidCallback onChange;const AccountsScreen({super.key,required this.onChange});@override State<AccountsScreen> createState()=>_AccountsScreenState();}
class _AccountsScreenState extends State<AccountsScreen>{final s=Store.instance;
  Future<void> change(Future<void> Function() f)async{try{await f();widget.onChange();}catch(e){if(mounted)await showError(context,e);}}
  Future<void> transfer()async{final ac=await accountChoices(s);if(!mounted)return;
    final f=await ask(context,'Cash / bank transfer',[FieldSpec('from','From',choices:ac),FieldSpec('to','To',choices:ac),const FieldSpec('amount','Amount Rs.',numeric:true),const FieldSpec('note','Note',mustFill:false)]);
    if(f!=null)await s.transfer(int.parse(f['from']!),int.parse(f['to']!),double.parse(f['amount']!),f['note']!);
  }
  Future<void> manual()async{final ac=await options(s,'SELECT id,name FROM accounts WHERE active=1 ORDER BY code');if(!mounted)return;
    final f=await ask(context,'Manual journal entry',[FieldSpec('date','Entry Date',initial:nowDate()),FieldSpec('debit','Debit account',choices:ac),FieldSpec('credit','Credit account',choices:ac),const FieldSpec('amount','Amount Rs.',numeric:true),const FieldSpec('note','Notes / reference',mustFill:false)]);
    if(f!=null)await s.manualJournal(f['date']!,int.parse(f['debit']!),int.parse(f['credit']!),double.parse(f['amount']!),f['note']!);
  }
  @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,Object?>>>(future:s.read('''SELECT a.id,a.code,a.name,a.type,coalesce(sum(jl.debit-jl.credit),0) AS dr_balance FROM accounts a LEFT JOIN journal_lines jl ON jl.account_id=a.id GROUP BY a.id ORDER BY a.code'''),builder:(ctx,snap){if(!snap.hasData)return const Center(child:CircularProgressIndicator());
    return pageWrap([section('Chart of accounts',action:buttons([addButton('Add account',()=>change(()async{
      final f=await ask(context,'Add account',[const FieldSpec('code','Code'),const FieldSpec('name','Account name'),const FieldSpec('type','Type: asset / liability / equity / revenue / expense')]);
      if(f!=null){if(!{'asset','liability','equity','revenue','expense'}.contains(f['type']))throw const FormatException('Invalid account type');await s.db.rawInsert('INSERT INTO accounts(code,name,type) VALUES(?,?,?)',[f['code'],f['name'],f['type']]);}
    })),addButton('Cash / bank transfer',()=>change(transfer)),addButton('Manual journal',()=>change(manual))])),
      listing(['Code','Account','Type','Net Dr balance'],snap.data!.map((a)=>[txt(a['code']),txt(a['name']),txt(a['type']),txt(funds(a['dr_balance']))]).toList()),
      panel(const Text('Accounting journal posts are atomic with bills, supplier purchases, customer receipts, expenses, advances and payroll. Stock costing / full financial closing remain under development.',style:TextStyle(color:Colors.blueGrey,fontSize:12)))]);
  });
}

class ReportsScreen extends StatefulWidget {final int revision;const ReportsScreen({super.key,required this.revision});@override State<ReportsScreen> createState()=>_ReportsScreenState();}
class _ReportsScreenState extends State<ReportsScreen>{final s=Store.instance;String type='Sales';DateTime start=DateTime(DateTime.now().year,DateTime.now().month,1);DateTime end=DateTime.now();int? category,product,party,employee;String search='';int? variant,expenseCategory;String paymentStatus='all',stockStatus='all';String minAmount='',maxAmount='';ReportResult? result;bool busy=false;
  Future<void> run()async{setState(()=>busy=true);try{result=await buildReport(s,ReportFilter(type:type,start:DateFormat('yyyy-MM-dd').format(start),end:DateFormat('yyyy-MM-dd').format(end),category:category,product:product,party:party,employee:employee,variant:variant,expenseCategory:expenseCategory,paymentStatus:paymentStatus,stockStatus:stockStatus,minAmount:double.tryParse(minAmount),maxAmount:double.tryParse(maxAmount),search:search));}catch(e){if(mounted)await showError(context,e);}finally{if(mounted)setState(()=>busy=false);}}
  Future<void> chooseDate(bool isStart)async{final d=await showDatePicker(context:context,initialDate:isStart?start:end,firstDate:DateTime(2000),lastDate:DateTime(2100));if(d!=null)setState((){if(isStart){start=d;}else{end=d;}});}
  @override Widget build(BuildContext context)=>FutureBuilder<List<Object>>(future:Future.wait([
    s.read('SELECT id,name FROM categories WHERE active=1 ORDER BY name'),s.read('SELECT id,name FROM products WHERE active=1 ORDER BY name'),s.read('SELECT id,name,kind FROM parties WHERE active=1 ORDER BY name'),s.read('SELECT id,name FROM employees WHERE active=1 ORDER BY name'),
    s.read('SELECT id,sku AS name FROM variants WHERE active=1 ORDER BY sku'),
    s.read('SELECT id,name FROM expense_categories ORDER BY name')
  ]),builder:(ctx,snap){if(!snap.hasData)return const Center(child:CircularProgressIndicator());
    final cats=snap.data![0] as List<Map<String,Object?>>;final ps=snap.data![1] as List<Map<String,Object?>>;final parties=snap.data![2] as List<Map<String,Object?>>;final em=snap.data![3] as List<Map<String,Object?>>;final vs=snap.data![4] as List<Map<String,Object?>>;final ec=snap.data![5] as List<Map<String,Object?>>;
    Widget dropdown(String label,int? value,List<Map<String,Object?>> rows,void Function(int?) changed)=>SizedBox(width:180,child:DropdownButtonFormField<int>(initialValue:value,isExpanded:true,decoration:InputDecoration(labelText:label),items:[const DropdownMenuItem(value:null,child:Text('All')), ...rows.map((r)=>DropdownMenuItem(value:r['id'] as int,child:Text('${r['name']}',overflow:TextOverflow.ellipsis)))],onChanged:changed));
    return pageWrap([section('Advanced reports & exports'),panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Wrap(spacing:10,runSpacing:10,crossAxisAlignment:WrapCrossAlignment.center,children:[
        SizedBox(width:210,child:DropdownButtonFormField<String>(initialValue:type,isExpanded:true,decoration:const InputDecoration(labelText:'Report'),items:reportTypes.map((x)=>DropdownMenuItem(value:x,child:Text(x,overflow:TextOverflow.ellipsis))).toList(),onChanged:(v)=>setState(()=>type=v??'Sales'))),
        OutlinedButton.icon(onPressed:()=>chooseDate(true),icon:const Icon(Icons.event),label:Text('From ${DateFormat('dd MMM yy').format(start)}')),
        OutlinedButton.icon(onPressed:()=>chooseDate(false),icon:const Icon(Icons.event),label:Text('To ${DateFormat('dd MMM yy').format(end)}')),
        dropdown('Category',category,cats,(v)=>setState(()=>category=v)),dropdown('Product',product,ps,(v)=>setState(()=>product=v)),
        dropdown('Customer / Supplier',party,parties,(v)=>setState(()=>party=v)),dropdown('Employee',employee,em,(v)=>setState(()=>employee=v)),
        dropdown('SKU variation',variant,vs,(v)=>setState(()=>variant=v)),
        dropdown('Expense category',expenseCategory,ec,(v)=>setState(()=>expenseCategory=v)),
        SizedBox(width:185,child:DropdownButtonFormField<String>(initialValue:paymentStatus,decoration:const InputDecoration(labelText:'Bill payment status'),items:const [DropdownMenuItem(value:'all',child:Text('All')),DropdownMenuItem(value:'paid',child:Text('Paid')),DropdownMenuItem(value:'partial',child:Text('Partially paid')),DropdownMenuItem(value:'unpaid',child:Text('Unpaid'))],onChanged:(v)=>setState(()=>paymentStatus=v??'all'))),
        SizedBox(width:185,child:DropdownButtonFormField<String>(initialValue:stockStatus,decoration:const InputDecoration(labelText:'Stock status'),items:const [DropdownMenuItem(value:'all',child:Text('All')),DropdownMenuItem(value:'negative',child:Text('Negative')),DropdownMenuItem(value:'zero',child:Text('Zero')),DropdownMenuItem(value:'positive',child:Text('Positive'))],onChanged:(v)=>setState(()=>stockStatus=v??'all'))),
        SizedBox(width:130,child:TextField(decoration:const InputDecoration(labelText:'Min amount'),keyboardType:TextInputType.number,onChanged:(v)=>minAmount=v)),
        SizedBox(width:130,child:TextField(decoration:const InputDecoration(labelText:'Max amount'),keyboardType:TextInputType.number,onChanged:(v)=>maxAmount=v)),
        SizedBox(width:200,child:TextField(decoration:const InputDecoration(labelText:'Search / Invoice'),onChanged:(v)=>search=v)),
        FilledButton.icon(onPressed:busy?null:run,icon:const Icon(Icons.filter_alt),label:const Text('Generate'))
      ]),const SizedBox(height:8),const Text('Report-specific filters: SKU, category and stock state for inventory; payment status for invoice sales/purchases; expense category and amount range for expenses. Other filters apply where relevant.',style:TextStyle(color:Colors.blueGrey,fontSize:11))])),
      if(busy)const LinearProgressIndicator(),
      if(result!=null)...[const SizedBox(height:16),section('${result!.title} • ${result!.rows.length} rows',action:buttons([
        OutlinedButton.icon(onPressed:()=>Exports.pdf(result!),icon:const Icon(Icons.picture_as_pdf),label:const Text('PDF')),
        OutlinedButton.icon(onPressed:()=>Exports.excel(result!),icon:const Icon(Icons.table_view),label:const Text('Excel')),
        FilledButton.icon(onPressed:()=>Exports.pdf(result!,print:true),icon:const Icon(Icons.print),label:const Text('A4 Print'))])),
        listing(result!.headings,result!.rows.take(200).map((r)=>r.map((x)=>SizedBox(width:x.length>40?200:null,child:txt(x))).toList()).toList()),
        if(result!.rows.length>200)const Text('On-screen preview shows first 200 rows; exports include all report rows.',style:TextStyle(color:Colors.blueGrey,fontSize:11))]
    ]);
  });
}

class SettingsScreen extends StatelessWidget {final VoidCallback onChange;const SettingsScreen({super.key,required this.onChange});
  @override Widget build(BuildContext context){final s=Store.instance;
    Future<void> backup()async{try{final base=DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());final directory=await showDialog<String>(context:context,builder:(ctx)=>SimpleDialog(title:const Text('Create backup'),children:[SimpleDialogOption(onPressed:()=>Navigator.pop(ctx,'backup'),child:const Text('Create a timestamped backup beside live database'))]));
      if(directory==null)return;final name='${s.dbPath.replaceAll('.sqlite','')}_backup_$base.sqlite';await s.backup(name);
      if(context.mounted)await showDialog(context:context,builder:(ctx)=>AlertDialog(title:const Text('Backup saved'),content:SelectableText(name),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('OK'))]));
    }catch(e){if(context.mounted)await showError(context,e);}}
    return pageWrap([section('System settings & data safety'),panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Single-computer offline installation',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold)),const SizedBox(height:12),SelectableText('SQLite database: ${s.dbPath}'),const SizedBox(height:18),FilledButton.icon(onPressed:backup,icon:const Icon(Icons.backup_outlined),label:const Text('Create database backup')),
      const SizedBox(height:12),OutlinedButton.icon(onPressed:()async{try{
        final results=await s.verifyDatabase();
        if(!context.mounted)return;
        await showDialog(context:context,builder:(ctx)=>AlertDialog(title:Text(results.isEmpty?'Database checks passed':'Database problems detected'),content:SelectableText(results.isEmpty?'SQLite integrity, foreign keys, balanced journals and return quantities passed. This is not a full accounting audit.':results.join('\n')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Close'))]));
      }catch(e){if(context.mounted)await showError(context,e);}},icon:const Icon(Icons.fact_check_outlined),label:const Text('Verify database integrity')),
      const SizedBox(height:15),const Text('Keep an additional backup on a USB drive or separate disk. To restore: close ShopDesk, keep a copy of the existing DB and replace the live .sqlite file with a validated backup.',style:TextStyle(color:Colors.blueGrey,fontSize:12))])),
      panel(const Text('Release status: integrated Flutter desktop source. Production hardening is still required: full cost accounting, role-based access, secure restores, migration strategy, returns/edits of posted financial transactions, and printer/Windows acceptance tests.',style:TextStyle(color:Colors.blueGrey,fontSize:12)))]);
  }
}
