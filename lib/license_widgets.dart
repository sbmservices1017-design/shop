import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'commercial_core.dart';

String readableRemaining(Duration time) {
  if(time.isNegative || time == Duration.zero)return '00:00:00';
  final s=time.inSeconds;
  final days=s~/86400;
  final hours=(s%86400)~/3600;
  final minutes=(s%3600)~/60;
  final seconds=s%60;
  final clock='${hours.toString().padLeft(2,'0')}:${minutes.toString().padLeft(2,'0')}:${seconds.toString().padLeft(2,'0')}';
  return days==0?clock:'${days}d $clock';
}

class LicenseCountdown extends StatefulWidget {
  final bool compact;
  const LicenseCountdown({super.key,this.compact=false});
  @override State<LicenseCountdown> createState()=>_LicenseCountdownState();
}
class _LicenseCountdownState extends State<LicenseCountdown>{
  Future<void> openActivation() async {
    final ctrl=TextEditingController();
    var working=false;
    String error='';
    try {
      await showDialog<void>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
        title:const Text('Activate your license key'),
        content:SizedBox(width:480,child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Machine ID',style:TextStyle(fontWeight:FontWeight.w700)),
          const SizedBox(height:5),SelectableText(CommercialCore.instance.deviceCode),
          TextButton.icon(onPressed:()=>Clipboard.setData(ClipboardData(text:CommercialCore.instance.deviceCode)),icon:const Icon(Icons.copy),label:const Text('Copy Machine ID')),
          const SizedBox(height:12),TextField(controller:ctrl,minLines:2,maxLines:4,decoration:const InputDecoration(labelText:'Signed activation key',hintText:'Paste key from owner generator')),
          if(error.isNotEmpty)Padding(padding:const EdgeInsets.only(top:12),child:Text(error,style:const TextStyle(color:Colors.red))),
        ])),
        actions:[TextButton(onPressed:working?null:()=>Navigator.pop(ctx),child:const Text('Close')),
          FilledButton(onPressed:working?null:()async{
            update(()=>working=true);
            try{await CommercialCore.instance.activate(ctrl.text.trim());
              if(ctx.mounted)Navigator.pop(ctx);
              if(mounted)setState((){});
            }catch(e){update(()=>error='$e');}finally{if(ctx.mounted)update(()=>working=false);}
          },child:Text(working?'Checking…':'Activate License'))]
      )));
    } finally {ctrl.dispose();}
  }

  Timer? timer;
  @override void initState(){super.initState();timer=Timer.periodic(const Duration(seconds:1),(_){if(mounted)setState((){});});}
  @override void dispose(){timer?.cancel();super.dispose();}
  @override Widget build(BuildContext context){
    final c=CommercialCore.instance;
    final remaining=c.license.expires?.difference(DateTime.now().toUtc());
    final expired=!c.license.allowed || (remaining!=null && remaining.isNegative);
    final isTrial=c.license.label=='Trial';
    final color=expired?Colors.red:isTrial?Colors.deepOrange:Colors.green;
    final status=expired?'Activation required':isTrial?'Trial expires in':c.license.label;
    return InkWell(onTap:openActivation,borderRadius:BorderRadius.circular(12),child:Container(padding:EdgeInsets.symmetric(horizontal:widget.compact?12:18,vertical:widget.compact?8:15),
      decoration:BoxDecoration(color:color.withValues(alpha:0.08),border:Border.all(color:color.withValues(alpha:0.3)),borderRadius:BorderRadius.circular(12)),
      child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(expired?Icons.lock_clock_outlined:Icons.verified_outlined,size:widget.compact?17:22,color:color),const SizedBox(width:9),
        Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[Text(status,style:TextStyle(color:color,fontSize:widget.compact?10:12,fontWeight:FontWeight.w700)),
          if(remaining!=null && !expired)Text(readableRemaining(remaining),style:TextStyle(color:color,fontSize:widget.compact?12:20,fontWeight:FontWeight.w800,fontFeatures:const [FontFeature.tabularFigures()]))
          else if(remaining==null && !expired)Text('No expiry',style:TextStyle(color:color,fontWeight:FontWeight.bold,fontSize:widget.compact?11:15))]),
      ]),
    ));
  }
}
