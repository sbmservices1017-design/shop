import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'store.dart';
import 'extensions.dart';
import 'commercial_core.dart';
import 'nexa_theme.dart';

/// Restore is performed BEFORE the DB is opened by Store, never with live handles.
class ShopDatabaseSetup {
  static Future<String> get databasePath async {
    final support=await getApplicationSupportDirectory();
    await support.create(recursive:true);
    return path.join(support.path,'shopdesk.sqlite');
  }
  static Future<bool> get exists async => File(await databasePath).exists();

  static void validateFile(String filename) {
    if(!File(filename).existsSync())throw const FormatException('Backup not found.');
    final db=sqlite.sqlite3.open(filename,mode:sqlite.OpenMode.readOnly);
    try {
      final status=db.select('PRAGMA integrity_check');
      if(status.length!=1 || status.first['integrity_check']!='ok')throw const FormatException('Backup failed SQLite integrity check');
      final tableNames=db.select("SELECT name FROM sqlite_master WHERE type='table'")
          .map((r)=>'${r['name']}').toSet();
      const expected=<String,List<String>>{
        'categories':['id','name'],
        'products':['id','category_id','name'],
        'variants':['id','product_id','sku','unit'],
        'stock_movements':['variant_id','qty','source_type','source_id','date'],
        'documents':['id','kind','invoice','party_id','date','total','paid','status'],
        'document_lines':['document_id','variant_id','qty','rate'],
        'parties':['id','kind','name'],
        'party_ledger':['party_id','debit','credit','source_type','source_id'],
      };
      for(final entry in expected.entries){
        if(!tableNames.contains(entry.key))throw FormatException('Not a compatible ShopDesk backup: ${entry.key} missing');
        final columns=db.select('PRAGMA table_info(${entry.key})').map((r)=>'${r['name']}').toSet();
        for(final column in entry.value){
          if(!columns.contains(column))throw FormatException('Backup is missing ${entry.key}.$column');
        }
      }
    } finally { db.dispose(); }
  }

  static Future<void> importFirstBackup(String from) async {
    final dest=await databasePath;
    if(await File(dest).exists())throw StateError('A shop database already exists.');
    final staged=File('$dest.importing');
    try {
      if(await staged.exists())await staged.delete();
      await File(from).copy(staged.path);
      validateFile(staged.path);
      await staged.rename(dest);
    } finally {if(await staged.exists())await staged.delete();}
  }

  /// Stage a later restore for NEXT startup so SQLite has no open handles.
  static Future<String> queueRestore(String from) async {
    final dest=await databasePath;
    final pending=File('$dest.restore_pending');
    final staged=File('$dest.restore_temp');
    try{
      if(await staged.exists())await staged.delete();
      await File(from).copy(staged.path);
      validateFile(staged.path);
      if(await pending.exists())await pending.delete();
      await staged.rename(pending.path);
      return pending.path;
    }finally{if(await staged.exists())await staged.delete();}
  }

  static Future<void> applyQueuedRestore() async {
    final dest=await databasePath;
    final pending=File('$dest.restore_pending');
    if(!await pending.exists())return;
    validateFile(pending.path);
    final original=File(dest);
    if(await original.exists()) {
      // Make an offline rollback copy before replacing a previously-opened DB.
      final stamp=DateTime.now().millisecondsSinceEpoch;
      await original.copy('$dest.before_restore_$stamp');
    }
    // Normal app shutdown should leave no WAL writers. Rename stale WAL/SHM
    // only after the application has stopped and before Store opens SQLite.
    for(final suffix in ['-wal','-shm']){
      final sidecar=File('$dest$suffix');
      if(await sidecar.exists())await sidecar.delete();
    }
    await pending.copy(dest);
    await pending.delete();
  }
}

class ShopDeskBootstrap extends StatefulWidget {
  final Widget Function() application;
  const ShopDeskBootstrap({super.key,required this.application});
  @override State<ShopDeskBootstrap> createState()=>_ShopDeskBootstrapState();
}
class _ShopDeskBootstrapState extends State<ShopDeskBootstrap> {
  bool loading=true,setup=false,ready=false,busy=false;
  String? error;
  @override void initState(){super.initState();inspect();}
  Future<void> inspect() async {
    try {
      await ShopDatabaseSetup.applyQueuedRestore();
      final exists=await ShopDatabaseSetup.exists;
      if(exists){await launch();return;}
      if(mounted)setState((){loading=false;setup=true;});
    }catch(e){if(mounted)setState((){error='$e';loading=false;});}
  }
  Future<void> launch() async {
    try {
      await Store.instance.init();
      await ensureExtendedSchema(Store.instance);
      await CommercialCore.instance.init();
      if(mounted)setState((){ready=true;loading=false;setup=false;busy=false;error=null;});
    }catch(e){if(mounted)setState((){error='$e';loading=false;busy=false;});}
  }
  Future<void> createNew()async{setState(()=>busy=true);await launch();}
  Future<void> restore()async{
    if(busy)return;
    try{
      final selected=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['sqlite','db','backup']);
      final file=selected?.files.single.path;
      if(file==null)return;
      setState((){busy=true;error=null;});
      await ShopDatabaseSetup.importFirstBackup(file);
      await launch();
    }catch(e){if(mounted)setState((){error='$e';busy=false;});}
  }
  @override Widget build(BuildContext context){
    if(ready)return widget.application();
    if(loading)return const Scaffold(backgroundColor:Nexa.background,body:Center(child:CircularProgressIndicator(color:Nexa.brightBlue)));
    return NexaAuthLayout(
      heading:'Welcome to ShopDesk Pro',
      subtitle:'First-time setup: start with an empty database or recover an existing ShopDesk backup.',
      icon:Icons.layers_rounded,maxWidth:680,
      child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        _setupChoice(Icons.add_box_outlined,'Create New Database','Set up a fresh local shop, then register its owner.',busy?null:createNew),
        const SizedBox(height:14),
        _setupChoice(Icons.restore_page_outlined,'Restore From Backup','Import a compatible ShopDesk SQLite backup, keeping previous accounts and data.',busy?null:restore),
        const SizedBox(height:18),
        const Text('This screen appears once for a new installation. Later launches will open the login or activation screen.',style:TextStyle(color:Nexa.muted,fontSize:11,height:1.5)),
        if(error!=null)...[const SizedBox(height:14),SelectableText(error!,style:const TextStyle(color:Nexa.orange))],
        if(busy)...[const SizedBox(height:14),const LinearProgressIndicator(color:Nexa.brightBlue)],
      ]),
    );
  }
  Widget _setupChoice(IconData icon,String title,String description,VoidCallback? tap)=>Material(color:Colors.transparent,child:InkWell(onTap:tap,borderRadius:BorderRadius.circular(12),child:Container(
    padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Nexa.panelTop,border:Border.all(color:Nexa.outline),borderRadius:BorderRadius.circular(12)),
    child:Row(children:[Container(width:50,height:50,decoration:BoxDecoration(color:Nexa.brightBlue.withValues(alpha:.18),borderRadius:BorderRadius.circular(10)),child:Icon(icon,color:Nexa.brightBlue,size:25)),
      const SizedBox(width:15),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:Nexa.white,fontWeight:FontWeight.w800,fontSize:15)),const SizedBox(height:5),Text(description,style:const TextStyle(color:Nexa.muted,fontSize:11))])),
      const Icon(Icons.arrow_forward_ios,color:Nexa.secondary,size:16),
    ]),
  )));
}
