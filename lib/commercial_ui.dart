import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'commercial_core.dart';
import 'store.dart';

class CommercialGate extends StatefulWidget {
  final Widget child;
  const CommercialGate({super.key,required this.child});
  @override State<CommercialGate> createState()=>_CommercialGateState();
}
class _CommercialGateState extends State<CommercialGate> {
  final c=CommercialCore.instance;
  bool busy=true,hasOwner=false;String? error;Timer? clockTimer;
  @override void initState(){super.initState();c.addListener(changed);load();clockTimer=Timer.periodic(const Duration(minutes:1),(_)async{await c.refreshLicense();if(mounted)setState((){});});}
  @override void dispose(){clockTimer?.cancel();c.removeListener(changed);super.dispose();}
  Future<void> load()async{
    try{
      final owner=await c.hasOwner;await c.refreshLicense();
      if(mounted)setState((){hasOwner=owner;busy=false;error=null;});
    }catch(e){if(mounted)setState((){error='$e';busy=false;});}
  }
  void changed(){if(mounted)setState((){});}
  @override Widget build(BuildContext context){
    if(busy)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    if(error!=null)return Scaffold(body:Center(child:SelectableText(error!)));
    if(!hasOwner)return _CredentialScreen(register:true,onSuccess:()async{hasOwner=true;await load();changed();});
    if(c.current==null)return _CredentialScreen(register:false,onSuccess:changed);
    if(!c.license.allowed)return ActivationScreen(onActivated:changed,onSignOut:(){c.signOut();changed();});
    return widget.child;
  }
}

class _CredentialScreen extends StatefulWidget {
  final bool register;final VoidCallback onSuccess;
  const _CredentialScreen({required this.register,required this.onSuccess});
  @override State<_CredentialScreen> createState()=>_CredentialScreenState();
}
class _CredentialScreenState extends State<_CredentialScreen>{
  final username=TextEditingController(),password=TextEditingController(),confirmPass=TextEditingController();
  bool busy=false,hidden=true;String? error;
  @override void dispose(){username.dispose();password.dispose();confirmPass.dispose();super.dispose();}
  Future<void> submit()async{
    if(busy)return;
    setState((){busy=true;error=null;});
    try{
      if(widget.register){
        if(password.text!=confirmPass.text)throw const FormatException('Passwords do not match');
        await CommercialCore.instance.registerOwner(username.text,password.text);
      }else{await CommercialCore.instance.signIn(username.text,password.text);}
      widget.onSuccess();
    }catch(e){if(mounted)setState(()=>error='$e');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(backgroundColor:const Color(0xFFF1F4FA),body:Center(child:SingleChildScrollView(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:460),child:Card(child:Padding(padding:const EdgeInsets.all(34),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    const Icon(Icons.storefront_rounded,size:52,color:Color(0xFF4B63D9)),const SizedBox(height:12),
    Text(widget.register?'Set up your shop owner account':'Welcome back to ShopDesk',textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:23)),
    const SizedBox(height:8),Text(widget.register?'Your free 48-hour trial starts after registration.':'Sign in to manage your store.',textAlign:TextAlign.center,style:const TextStyle(color:Colors.blueGrey)),const SizedBox(height:27),
    TextField(controller:username,decoration:const InputDecoration(labelText:'Username',prefixIcon:Icon(Icons.person_outline))),const SizedBox(height:13),
    TextField(controller:password,obscureText:hidden,onSubmitted:(_)=>submit(),decoration:InputDecoration(labelText:'Password',prefixIcon:const Icon(Icons.lock_outline),suffixIcon:IconButton(onPressed:()=>setState(()=>hidden=!hidden),icon:Icon(hidden?Icons.visibility:Icons.visibility_off)))),
    if(widget.register)...[const SizedBox(height:13),TextField(controller:confirmPass,obscureText:hidden,decoration:const InputDecoration(labelText:'Confirm password'))],
    if(error!=null)...[const SizedBox(height:12),Text(error!,style:const TextStyle(color:Colors.red))],const SizedBox(height:24),
    FilledButton.icon(onPressed:busy?null:submit,icon:Icon(widget.register?Icons.how_to_reg:Icons.login),label:Padding(padding:const EdgeInsets.all(9),child:Text(widget.register?'Create owner account':'Log in'))),
    const SizedBox(height:12),const Text('Offline single-PC installation · data stays on this machine',textAlign:TextAlign.center,style:TextStyle(fontSize:11,color:Colors.blueGrey))
  ])))))));
}

class ActivationScreen extends StatefulWidget {
  final VoidCallback onActivated,onSignOut;
  const ActivationScreen({super.key,required this.onActivated,required this.onSignOut});
  @override State<ActivationScreen> createState()=>_ActivationScreenState();
}
class _ActivationScreenState extends State<ActivationScreen>{
  final code=TextEditingController();String? error;bool busy=false;
  @override void dispose(){code.dispose();super.dispose();}
  Future<void> submit()async{
    if(busy)return;setState((){busy=true;error=null;});
    try{await CommercialCore.instance.activate(code.text);widget.onActivated();}
    catch(e){if(mounted)setState(()=>error='$e');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context){final c=CommercialCore.instance;
    return Scaffold(backgroundColor:const Color(0xFFF1F4FA),body:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:570),child:Card(child:Padding(padding:const EdgeInsets.all(30),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Icon(Icons.key_rounded,size:55,color:Color(0xFF4B63D9)),const SizedBox(height:16),const Text('Activate ShopDesk',textAlign:TextAlign.center,style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
      const SizedBox(height:7),Text(c.license.label,textAlign:TextAlign.center,style:const TextStyle(color:Colors.deepOrange,fontWeight:FontWeight.w600)),const SizedBox(height:18),
      const Text('Your device code (send to software owner):'),const SizedBox(height:7),SelectableText(c.deviceCode,style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold,letterSpacing:1)),
      Align(alignment:Alignment.centerRight,child:TextButton.icon(onPressed:()=>Clipboard.setData(ClipboardData(text:c.deviceCode)),icon:const Icon(Icons.copy),label:const Text('Copy device code'))),const SizedBox(height:18),
      TextField(controller:code,maxLines:4,decoration:const InputDecoration(labelText:'Signed activation key',hintText:'Paste the activation key from software owner')),
      if(error!=null)Padding(padding:const EdgeInsets.only(top:10),child:Text(error!,style:const TextStyle(color:Colors.red))),const SizedBox(height:18),
      FilledButton.icon(onPressed:busy?null:submit,icon:const Icon(Icons.verified_user),label:const Padding(padding:EdgeInsets.all(9),child:Text('Activate license'))),
      const SizedBox(height:13),TextButton(onPressed:widget.onSignOut,child:const Text('Sign out'))
    ]))))));
  }
}

class UserManagementScreen extends StatefulWidget {const UserManagementScreen({super.key});@override State<UserManagementScreen> createState()=>_UserManagementScreenState();}
class _UserManagementScreenState extends State<UserManagementScreen>{
  final core=CommercialCore.instance;bool busy=false;String? status;
  Future<void> run(Future<void> Function() action)async{try{setState(()=>busy=true);await action();setState(()=>status='Saved successfully');}catch(e){if(mounted)setState(()=>status='$e');}finally{if(mounted)setState(()=>busy=false);}}
  Future<Map<String,String>?> userDialog({Map<String,Object?>? existing})async{
    final name=TextEditingController(text:'${existing?['username']??''}');final password=TextEditingController();
    try{return await showDialog<Map<String,String>>(context:context,builder:(ctx)=>AlertDialog(title:Text(existing==null?'New User':'Edit User'),content:SizedBox(width:420,child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Username')),const SizedBox(height:10),TextField(controller:password,decoration:InputDecoration(labelText:existing==null?'Password (min. 10 characters)':'New password (leave blank to keep)'),obscureText:true)])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,{'username':name.text,'password':password.text}),child:const Text('Save'))]));}
    finally{name.dispose();password.dispose();}
  }
  Future<void> permissions(int userId,String username) async {
    final rows=await Store.instance.read(
      'SELECT module,operation FROM app_permissions WHERE user_id=?',[userId]);
    final rights={for(final m in commercialModules)m:<String>{}};
    for(final r in rows){rights['${r['module']}']?.add('${r['operation']}');}
    if(!mounted)return;
    await showDialog<void>(context:context,builder:(ctx){
      return StatefulBuilder(builder:(dialogContext,change){
        final formRows=<Widget>[];
        for(final module in commercialModules){
          final checkboxes=<Widget>[];
          for(final op in const ['view','create','edit','delete']){
            checkboxes.add(SizedBox(width:112,child:CheckboxListTile(
              dense:true,contentPadding:EdgeInsets.zero,title:Text(op),
              value:rights[module]!.contains(op),
              onChanged:(v)=>change((){
                if(v==true){rights[module]!.add(op);if(op!='view')rights[module]!.add('view');}
                else{if(op=='view'){rights[module]!.clear();}else{rights[module]!.remove(op);}}
              }))));
          }
          formRows.add(Card(child:Padding(padding:const EdgeInsets.all(12),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(module,style:const TextStyle(fontWeight:FontWeight.bold)),
              Wrap(spacing:10,children:checkboxes)
            ]))));
        }
        return AlertDialog(
          title:Text('Permissions · $username'),
          content:SizedBox(width:670,height:540,child:ListView(children:formRows)),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
            FilledButton(onPressed:()async{
              try{
                for(final entry in rights.entries){
                  await core.setUserPermission(userId,entry.key,entry.value);
                }
                if(ctx.mounted)Navigator.pop(ctx);
              }catch(e){
                if(ctx.mounted){ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text('$e')));}
              }
            },child:const Text('Save all permissions'))
          ]);
      });
    });
  }
  @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,Object?>>>(future:Store.instance.read('SELECT id,username,is_admin,active,created_at FROM app_users ORDER BY id'),builder:(ctx,snap){
    if(core.current?.isAdmin!=true)return const Center(child:Text('Admin access required'));
    if(!snap.hasData)return const Center(child:CircularProgressIndicator());
    return ListView(padding:const EdgeInsets.all(24),children:[Row(children:[const Expanded(child:Text('Team & module permissions',style:TextStyle(fontSize:21,fontWeight:FontWeight.w800))),FilledButton.icon(onPressed:busy?null:()=>run(()async{final r=await userDialog();if(r!=null){await core.createUser(r['username']!,r['password']!);}}),icon:const Icon(Icons.person_add),label:const Text('Add user'))]),
    if(status!=null)Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Text(status!,style:TextStyle(color:status=='Saved successfully'?Colors.green:Colors.red))),
    ...snap.data!.map((u)=>Card(child:ListTile(leading:CircleAvatar(child:Text('${u['username']}'.substring(0,1).toUpperCase())),title:Text('${u['username']}'),subtitle:Text(u['is_admin']==1?'Administrator':'Employee · ${u['active']==1?'Active':'Disabled'}'),trailing:Wrap(spacing:6,children:[
      IconButton(tooltip:'Edit user',onPressed:busy?null:()=>run(()async{final r=await userDialog(existing:u);if(r!=null)await core.editUser(u['id'] as int,username:r['username'],password:r['password']);}),icon:const Icon(Icons.edit)),
      if(u['is_admin']!=1)IconButton(tooltip:'Module permissions',onPressed:()=>permissions(u['id'] as int,'${u['username']}').then((_){if(mounted)setState((){});}),icon:const Icon(Icons.admin_panel_settings)),
      if(u['id']!=core.current?.id)IconButton(tooltip:u['active']==1?'Disable user':'Enable user',onPressed:()=>run(()=>core.editUser(u['id'] as int,active:u['active']!=1)),icon:Icon(u['active']==1?Icons.person_off:Icons.person))
    ])))).toList()]);
  });
}

class ShopProfileScreen extends StatefulWidget {const ShopProfileScreen({super.key});@override State<ShopProfileScreen> createState()=>_ShopProfileScreenState();}
class _ShopProfileScreenState extends State<ShopProfileScreen>{
  final core=CommercialCore.instance,name=TextEditingController(),phone=TextEditingController(),address=TextEditingController();
  String? logo;String? message;
  @override void initState(){super.initState();load();}
  Future<void> load()async{final n=await core.readSetting('shop_name');final ph=await core.readSetting('shop_phone');final a=await core.readSetting('shop_address');final l=await core.readSetting('shop_logo');if(mounted)setState((){name.text=n??'';phone.text=ph??'';address.text=a??'';logo=l;});}
  @override void dispose(){name.dispose();phone.dispose();address.dispose();super.dispose();}
  Future<void> pick()async{
    final result=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['png','jpg','jpeg']);
    final source=result?.files.single.path;if(source==null)return;
    final folder=await getApplicationSupportDirectory();
    final destination=p.join(folder.path,'shop_logo${p.extension(source).toLowerCase()}');
    await File(source).copy(destination);setState(()=>logo=destination);
  }
  Future<void> save()async{try{await core.saveShopProfile(name:name.text,phone:phone.text,address:address.text,logoPath:logo??'');setState(()=>message='Shop profile saved');}catch(e){setState(()=>message='$e');}}
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(24),children:[const Text('Shop Details & Branding',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),const SizedBox(height:12),Card(child:Padding(padding:const EdgeInsets.all(22),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    if(logo!=null&&logo!.isNotEmpty&&File(logo!).existsSync())Image.file(File(logo!),height:92,width:170,fit:BoxFit.contain),const SizedBox(height:14),
    Wrap(spacing:12,children:[OutlinedButton.icon(onPressed:pick,icon:const Icon(Icons.image_outlined),label:const Text('Upload logo')),TextButton.icon(onPressed:()=>setState(()=>logo=''),icon:const Icon(Icons.delete_outline),label:const Text('Remove logo'))]),
    const SizedBox(height:18),TextField(controller:name,decoration:const InputDecoration(labelText:'Shop name')),const SizedBox(height:12),TextField(controller:phone,decoration:const InputDecoration(labelText:'Phone')),const SizedBox(height:12),TextField(controller:address,decoration:const InputDecoration(labelText:'Address')),const SizedBox(height:18),
    FilledButton.icon(onPressed:save,icon:const Icon(Icons.save),label:const Text('Save profile')),if(message!=null)Text(message!)
  ])))]);
}
