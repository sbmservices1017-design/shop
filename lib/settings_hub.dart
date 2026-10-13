import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'boot_setup.dart';
import 'commercial_core.dart';
import 'commercial_ui.dart';
import 'license_widgets.dart';
import 'store.dart';

class SettingsHub extends StatefulWidget {
  const SettingsHub({super.key});
  @override State<SettingsHub> createState()=>_SettingsHubState();
}
class _SettingsHubState extends State<SettingsHub> {
  int tab=0;
  final options=<({String title, IconData icon})>[
    (title:'Shop Profile',icon:Icons.store_outlined),
    (title:'Users & Permissions',icon:Icons.admin_panel_settings_outlined),
    (title:'Backup & Restore',icon:Icons.settings_backup_restore_rounded),
    (title:'License Activation',icon:Icons.key_outlined),
    (title:'System Information',icon:Icons.info_outline),
  ];
  @override Widget build(BuildContext context){
    if(CommercialCore.instance.current?.isAdmin!=true)return const Center(child:Text('Administrator access is required for settings.'));
    final screen=switch(tab){
      0=>const ShopProfileScreen(),
      1=>const UserManagementScreen(),
      2=>const BackupSettings(),
      3=>const LicenseSettings(),
      _=>const SystemInfo(),
    };
    return LayoutBuilder(builder:(context,constraints){
      final wide=constraints.maxWidth>=780;
      final menu=Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        const Padding(padding:EdgeInsets.all(20),child:Text('SETTINGS',style:TextStyle(fontWeight:FontWeight.w800,color:Colors.blueGrey,letterSpacing:1.5))),
        ...List.generate(options.length,(i)=>Padding(padding:const EdgeInsets.symmetric(horizontal:10,vertical:3),child:ListTile(
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)),selected:tab==i,
          selectedTileColor:const Color(0xffe5eafc),leading:Icon(options[i].icon),title:Text(options[i].title,style:const TextStyle(fontSize:13)),
          onTap:()=>setState(()=>tab=i)))),
      ]);
      return Column(children:[
        Padding(padding:const EdgeInsets.fromLTRB(24,18,24,10),child:Row(children:[const Icon(Icons.tune_rounded),const SizedBox(width:10),Text(options[tab].title,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w800))])),
        Expanded(child:wide?Row(crossAxisAlignment:CrossAxisAlignment.stretch,children:[SizedBox(width:245,child:Card(child:menu)),Expanded(child:screen)]):Column(children:[
          SizedBox(height:105,child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:List.generate(options.length,(i)=>Padding(padding:const EdgeInsets.all(4),child:ChoiceChip(label:Text(options[i].title),selected:tab==i,onSelected:(_)=>setState(()=>tab=i))))))),
          Expanded(child:screen),
        ])),
      ]);
    });
  }
}

class BackupSettings extends StatefulWidget{const BackupSettings({super.key});@override State<BackupSettings> createState()=>_BackupSettingsState();}
class _BackupSettingsState extends State<BackupSettings>{
  String message='';bool busy=false;
  Future<void> backup()async{
    setState(()=>busy=true);
    try {
      final filename='shopdesk_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.sqlite';
      final location=await FilePicker.platform.saveFile(dialogTitle:'Save SQLite backup',fileName:filename,type:FileType.custom,allowedExtensions:['sqlite']);
      if(location==null)return;
      await Store.instance.backup(location);
      if(mounted)setState(()=>message='Backup successfully saved: $location');
    }catch(e){if(mounted)setState(()=>message='$e');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> restore()async{
    final selected=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['sqlite','db','backup']);
    final filename=selected?.files.single.path;
    if(filename==null || !mounted)return;
    final approved=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Restore database on next launch?'),content:const Text('A rollback copy of your current database will be kept. Existing shop data will be replaced after you CLOSE and RESTART ShopDesk. Keep an independent backup first.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Stage restore'))]));
    if(approved!=true)return;
    setState(()=>busy=true);
    try {
      await ShopDatabaseSetup.queueRestore(filename);
      if(mounted)setState(()=>message='Restore staged successfully. Close ShopDesk normally and restart it to load the selected database.');
    }catch(e){if(mounted)setState(()=>message='$e');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> verify()async{
    setState(()=>busy=true);
    try{final issues=await Store.instance.verifyDatabase();if(mounted)setState(()=>message=issues.isEmpty?'SQLite integrity, foreign keys and journal checks passed.':issues.join('\n'));}
    catch(e){if(mounted)setState(()=>message='$e');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(22),children:[
    Card(child:Padding(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Database safety',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),const SizedBox(height:10),
      SelectableText('Live SQLite database: ${Store.instance.dbPath}',style:const TextStyle(fontSize:12,color:Colors.blueGrey)),const SizedBox(height:16),
      Wrap(spacing:10,runSpacing:10,children:[FilledButton.icon(onPressed:busy?null:backup,icon:const Icon(Icons.save_alt),label:const Text('Create backup')),OutlinedButton.icon(onPressed:busy?null:restore,icon:const Icon(Icons.restore),label:const Text('Restore from backup')),OutlinedButton.icon(onPressed:busy?null:verify,icon:const Icon(Icons.fact_check),label:const Text('Check database integrity'))]),
      const SizedBox(height:14),const Text('A restore is applied only at the next application startup. Never copy over a live SQLite database manually.',style:TextStyle(color:Colors.blueGrey,fontSize:12)),
      if(message.isNotEmpty)...[const SizedBox(height:12),SelectableText(message)],
      if(busy)const LinearProgressIndicator(),
    ]))),
  ]);
}

class LicenseSettings extends StatefulWidget{const LicenseSettings({super.key});@override State<LicenseSettings> createState()=>_LicenseSettingsState();}
class _LicenseSettingsState extends State<LicenseSettings>{
  final keyController=TextEditingController();String message='';bool busy=false;
  @override void dispose(){keyController.dispose();super.dispose();}
  Future<void> activate()async{
    setState(()=>busy=true);
    try{await CommercialCore.instance.activate(keyController.text);if(mounted)setState(()=>message='License successfully activated.');}
    catch(e){if(mounted)setState(()=>message='$e');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context){final core=CommercialCore.instance;
    return ListView(padding:const EdgeInsets.all(22),children:[Card(child:Padding(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Offline license & machine activation',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800)),const SizedBox(height:15),const LicenseCountdown(),const SizedBox(height:14),
      const Text('Machine ID'),const SizedBox(height:6),SelectableText(core.deviceCode,style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold,letterSpacing:1)),
      TextButton.icon(onPressed:()=>Clipboard.setData(ClipboardData(text:core.deviceCode)),icon:const Icon(Icons.copy),label:const Text('Copy Machine ID')),
      const Divider(height:30),const Text('License key is generated by software owner on a separate computer using your Machine ID.',style:TextStyle(fontSize:12,color:Colors.blueGrey)),
      const SizedBox(height:10),TextField(controller:keyController,minLines:2,maxLines:4,decoration:const InputDecoration(labelText:'Signed activation key')),
      const SizedBox(height:14),FilledButton.icon(onPressed:busy?null:activate,icon:const Icon(Icons.verified),label:const Text('Activate / Renew license')),
      if(message.isNotEmpty)...[const SizedBox(height:10),SelectableText(message)],
      const SizedBox(height:20),const Text('Available license plans: 1 month, 1 year, 2 years or lifetime. The 48-hour trial starts only after initial owner registration.',style:TextStyle(color:Colors.blueGrey,fontSize:12)),
    ])))]);
  }
}
class SystemInfo extends StatelessWidget{const SystemInfo({super.key});
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(22),children:[Card(child:Padding(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('ShopDesk Pro v0.6',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800)),const SizedBox(height:14),const Text('Flutter · Windows desktop · offline SQLite'),const SizedBox(height:10),
    const Text('Shop profile → Users & Permissions → Backup & Restore → License Activation → System Information',style:TextStyle(color:Colors.blueGrey)),
    const SizedBox(height:16),SelectableText(Store.instance.dbPath),
    const SizedBox(height:16),const Text('This software should be run through the GitHub Windows build and tested with copied customer data before deploying to a live shop.',style:TextStyle(color:Colors.blueGrey,fontSize:12)),
  ])))]);
}
