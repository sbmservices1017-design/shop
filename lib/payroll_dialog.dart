import 'package:flutter/material.dart';
import 'payroll_math.dart';
import 'store.dart';

/// Simple live payroll preview: recover from ADVANCE then pay NET, not GROSS.
class PayrollDialog extends StatefulWidget {
  final int employeeId;
  final String employeeName;
  final PayrollQuote quote;
  final Map<int,String> cashAccounts;
  const PayrollDialog({super.key,required this.employeeId,required this.employeeName,
    required this.quote,required this.cashAccounts});
  @override
  State<PayrollDialog> createState()=>_PayrollDialogState();
}

class _PayrollDialogState extends State<PayrollDialog> {
  late final TextEditingController _period;
  late final TextEditingController _salaryDate;
  late final TextEditingController _recovery;
  late final TextEditingController _paid;
  int? _cashAccount;
  bool _paymentManuallyEdited=false;
  bool _saving=false;
  String? _serverError;

  @override
  void initState(){
    super.initState();
    final today=DateTime.now();
    _period=TextEditingController(text:'${today.year}-${today.month.toString().padLeft(2,'0')}');
    _salaryDate=TextEditingController(text:nowDate());
    _recovery=TextEditingController(text:'0.00');
    _paid=TextEditingController(text:pkr(widget.quote.gross));
    _cashAccount=widget.cashAccounts.isEmpty?null:widget.cashAccounts.keys.first;
  }
  @override
  void dispose(){_period.dispose();_salaryDate.dispose();_recovery.dispose();_paid.dispose();super.dispose();}

  int? _parsePaisa(String raw) {
    final n=double.tryParse(raw.trim());
    if(n==null||!n.isFinite||n<0)return null;
    return pennies(n);
  }
  int? get _recoverAmount => _parsePaisa(_recovery.text);
  int? get _paidAmount => _parsePaisa(_paid.text);
  int? get _netAmount {
    final r=_recoverAmount;
    if(r==null)return null;
    try{return widget.quote.netPayable(r);}on FormatException{return null;}
  }
  String? get _validationMessage {
    if(!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(_period.text.trim())) {
      return 'Period must be YYYY-MM (example: 2026-10).';
    }
    final enteredDate=_salaryDate.text.trim();
    final parsed=DateTime.tryParse(enteredDate);
    if(!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(enteredDate) || parsed==null ||
        parsed.toIso8601String().substring(0,10)!=enteredDate)
      return 'Enter a valid salary payment date YYYY-MM-DD.';
    final r=_recoverAmount,p=_paidAmount;
    if(r==null||p==null)return 'Enter positive or zero recovery and payment amounts.';
    try{widget.quote.salaryDue(r,p);}on FormatException catch(e){return e.message;}
    if(_cashAccount==null)return 'Select a cash or bank account.';
    return null;
  }

  void _recoveryChanged(String value){
    final net=_netAmount;
    if(!_paymentManuallyEdited&&net!=null){_paid.text=pkr(net);}
    setState(()=>_serverError=null);
  }

  Future<void> _save()async {
    final validation=_validationMessage;
    if(validation!=null){setState(()=>_serverError=validation);return;}
    setState((){_saving=true;_serverError=null;});
    try {
      await Store.instance.payrollRun(widget.employeeId,_period.text.trim(),
        _recoverAmount!/100,_paidAmount!/100,_cashAccount!,salaryDate:_salaryDate.text.trim());
      if(mounted)Navigator.of(context).pop(true);
    } catch(error){
      if(mounted)setState(()=>_serverError=error is FormatException?error.message:'Could not save payroll: $error');
    }finally{
      if(mounted)setState(()=>_saving=false);
    }
  }

  Widget _moneyRow(String label,int amount,{bool highlighted=false})=>Padding(
    padding:const EdgeInsets.symmetric(vertical:5),
    child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
      Expanded(child:Text(label,style:TextStyle(fontWeight:highlighted?FontWeight.bold:FontWeight.w500))),
      Text('Rs. ${pkr(amount)}',style:TextStyle(fontWeight:highlighted?FontWeight.w800:FontWeight.w600,
        color:highlighted?const Color(0xFF1969C5):const Color(0xFF19344B))),
    ]),
  );
  @override
  Widget build(BuildContext context){
    final recovery=_recoverAmount,paid=_paidAmount,net=_netAmount;
    int? salaryDue;
    if(recovery!=null&&paid!=null){
      try{salaryDue=widget.quote.salaryDue(recovery,paid);}on FormatException{salaryDue=null;}
    }
    return AlertDialog(
      title:Text('Run Payroll • ${widget.employeeName}'),
      content:SizedBox(width:500,child:SingleChildScrollView(child:Column(
        mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(
          color:const Color(0xFFEDF6FF),borderRadius:BorderRadius.circular(12),
          border:Border.all(color:const Color(0xFFC9E4FE))),child:Column(children:[
          _moneyRow('Monthly gross salary',widget.quote.gross),
          _moneyRow('Outstanding advance',widget.quote.advanceOutstanding),
          _moneyRow('Maximum recovery this month',widget.quote.maximumRecovery),
        ])),
        const SizedBox(height:16),
        TextField(controller:_period,decoration:const InputDecoration(labelText:'Payroll month (YYYY-MM)'),
          onChanged:(_)=>setState(()=>_serverError=null)),
        const SizedBox(height:12),
        TextField(controller:_salaryDate,decoration:const InputDecoration(
          labelText:'Salary / payment date (YYYY-MM-DD)',
          helperText:'Date salary is paid; month and year above remain the payroll period'),
          onChanged:(_)=>setState(()=>_serverError=null)),
        const SizedBox(height:12),
        TextField(controller:_recovery,keyboardType:const TextInputType.numberWithOptions(decimal:true),
          decoration:const InputDecoration(labelText:'Recover from advance (Rs.)',helperText:'Deduct this from gross salary'),
          onChanged:_recoveryChanged),
        const SizedBox(height:12),
        TextField(controller:_paid,keyboardType:const TextInputType.numberWithOptions(decimal:true),
          decoration:const InputDecoration(labelText:'Pay now (Rs.)',helperText:'Auto-fills net salary; change for partial payment'),
          onChanged:(_){_paymentManuallyEdited=true;setState(()=>_serverError=null);}),
        const SizedBox(height:12),
        DropdownButtonFormField<int>(
          initialValue:_cashAccount,
          isExpanded:true,
          decoration:const InputDecoration(labelText:'Pay from cash / bank'),
          items:widget.cashAccounts.entries.map((e)=>DropdownMenuItem<int>(value:e.key,child:Text(e.value))).toList(),
          onChanged:_saving?null:(v)=>setState(()=>_cashAccount=v),
        ),
        const SizedBox(height:14),
        Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(
          color:const Color(0xFFF3FAFF),borderRadius:BorderRadius.circular(12)),child:Column(children:[
          _moneyRow('Net salary payable',net??widget.quote.gross,highlighted:true),
          if(salaryDue!=null)_moneyRow('Remaining salary due',salaryDue),
          if(recovery!=null&&recovery<=widget.quote.maximumRecovery)
            _moneyRow('Advance remaining after recovery',widget.quote.advanceOutstanding-recovery),
        ])),
        if(_serverError!=null)...[
          const SizedBox(height:12),
          Text(_serverError!,style:const TextStyle(color:Color(0xFFB42318))),
        ],
        const SizedBox(height:8),
        const Text('Example: Gross Rs. 40,000 − recovery Rs. 5,000 = pay now Rs. 35,000.',
          style:TextStyle(fontSize:12,color:Color(0xFF58738E))),
      ]))),
      actions:[TextButton(onPressed:_saving?null:()=>Navigator.of(context).pop(false),child:const Text('Cancel')),
        FilledButton.icon(onPressed:_saving?null:_save,
          icon:_saving?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.check_circle_outline),
          label:const Text('Save Payroll'))],
    );
  }
}
