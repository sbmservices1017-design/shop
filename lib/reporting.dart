import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'store.dart';
import 'commercial_core.dart';

const reportTypes=<String>[
  'Sales','Purchases','Products','Stock','Stock Movements','Customers','Suppliers',
  'Customer Ledger','Supplier Ledger','Customer Receivables','Supplier Payables',
  'Expenses','Employees','Employee Ledger','Payroll','Cash & Bank', 'Trial Balance',
  'Revenue & Expenses','Sales Returns','Purchase Returns','Payments','Salary Outstanding','Account Ledger','Stock As of Date','Daily Sales Summary','Monthly Sales Summary','Audit Trail'
];

class ReportFilter {
  final String type;
  final String start;
  final String end;
  final int? product;
  final int? category;
  final int? party;
  final int? employee;
  final int? variant;
  final int? expenseCategory;
  final String paymentStatus;
  final String stockStatus;
  final double? minAmount;
  final double? maxAmount;
  final String search;
  const ReportFilter({required this.type,required this.start,required this.end,
    this.product,this.category,this.party,this.employee,this.variant,this.expenseCategory,
    this.paymentStatus='all',this.stockStatus='all',this.minAmount,this.maxAmount,this.search=''});
}
class ReportResult {
  final String title;
  final List<String> headings;
  final List<List<String>> rows;
  const ReportResult(this.title,this.headings,this.rows);
}

Future<ReportResult> buildReport(Store s,ReportFilter f) async {
  final where=<String>[];
  final args=<Object?>[];
  String dateFilter(String column) {args.add(f.start);args.add(f.end);return '$column BETWEEN ? AND ?';}
  String term(String column) {args.add('%${f.search}%');return '$column LIKE ?';}
  String sql='';
  List<String> headers=[];
  switch(f.type){
    case 'Sales':
    case 'Purchases':
      final sale=f.type=='Sales';
      where.add("d.kind='${sale?'sale':'purchase'}'");where.add("d.status='POSTED'");where.add(dateFilter('d.date'));
      if(f.party!=null){where.add('d.party_id=?');args.add(f.party);}
      if(f.category!=null){where.add('c.id=?');args.add(f.category);}
      if(f.product!=null){where.add('p.id=?');args.add(f.product);}
      if(f.variant!=null){where.add('v.id=?');args.add(f.variant);}
      if(f.paymentStatus=='paid')where.add('d.paid>=d.total');
      if(f.paymentStatus=='partial')where.add('d.paid>0 AND d.paid<d.total');
      if(f.paymentStatus=='unpaid')where.add('d.paid=0');
      if(f.minAmount!=null){where.add('l.amount>=?');args.add(pennies(f.minAmount!));}
      if(f.maxAmount!=null){where.add('l.amount<=?');args.add(pennies(f.maxAmount!));}
      if(f.search.isNotEmpty){where.add('(d.invoice LIKE ? OR p.name LIKE ? OR v.sku LIKE ? OR pa.name LIKE ?)');
        args.addAll(List.filled(4,'%${f.search}%'));}
      sql='''SELECT d.date AS Date,d.invoice AS Invoice,coalesce(pa.name,'Walk-in') AS Party,p.name AS Product,v.sku AS SKU,l.qty AS Qty,coalesce(lu.unit,v.unit) AS Unit,l.rate/100.0 AS Rate,l.amount/100.0 AS Amount,d.paid/100.0 AS 'Invoice Paid',d.total/100.0 AS 'Invoice Total'
        FROM documents d JOIN document_lines l ON l.document_id=d.id JOIN variants v ON v.id=l.variant_id JOIN products p ON p.id=v.product_id JOIN categories c ON c.id=p.category_id
        LEFT JOIN parties pa ON pa.id=d.party_id LEFT JOIN document_line_units lu ON lu.line_id=l.id WHERE ${where.join(' AND ')} ORDER BY d.date DESC,d.id DESC''';
      headers=['Date','Invoice','Party','Product','SKU','Qty','Unit','Rate','Amount','Invoice Paid','Invoice Total'];
      break;
    case 'Products':
    case 'Stock':
      if(f.category!=null){where.add('c.id=?');args.add(f.category);}
      if(f.product!=null){where.add('p.id=?');args.add(f.product);}
      if(f.variant!=null){where.add('v.id=?');args.add(f.variant);}
      if(f.search.isNotEmpty){where.add('(p.name LIKE ? OR v.sku LIKE ?)');args.addAll(['%${f.search}%','%${f.search}%']);}
      sql='''SELECT c.name AS Category,p.name AS Product,v.sku AS SKU,v.unit AS Unit,
        coalesce(sum(m.qty),0) AS Stock,
        coalesce((SELECT group_concat(a.name||': '||vv.value,', ') FROM variant_values vv JOIN attributes a ON a.id=vv.attribute_id WHERE vv.variant_id=v.id),'') AS Attributes
        FROM variants v JOIN products p ON p.id=v.product_id JOIN categories c ON c.id=p.category_id LEFT JOIN stock_movements m ON m.variant_id=v.id
        ${where.isEmpty?'':'WHERE ${where.join(' AND ')}'} GROUP BY v.id
        ${f.stockStatus=='negative'?'HAVING Stock<0':f.stockStatus=='zero'?'HAVING Stock=0':f.stockStatus=='positive'?'HAVING Stock>0':''}
        ORDER BY c.name,p.name''';
      headers=['Category','Product','SKU','Unit','Stock','Attributes'];break;
    case 'Stock Movements':
      where.add(dateFilter('m.date'));
      if(f.product!=null){where.add('p.id=?');args.add(f.product);}
      if(f.category!=null){where.add('c.id=?');args.add(f.category);}
      if(f.variant!=null){where.add('v.id=?');args.add(f.variant);}
      sql='''SELECT m.date AS Date,p.name AS Product,v.sku AS SKU,m.source_type AS Source,m.qty AS Qty,v.unit AS Unit,m.note AS Note FROM stock_movements m
      JOIN variants v ON v.id=m.variant_id JOIN products p ON p.id=v.product_id JOIN categories c ON c.id=p.category_id WHERE ${where.join(' AND ')} ORDER BY m.date DESC,m.id DESC''';
      headers=['Date','Product','SKU','Source','Qty','Unit','Note'];break;
    case 'Customers':
    case 'Suppliers':
      final kind=f.type=='Customers'?'customer':'supplier';where.add('pa.kind=?');args.add(kind);args.insert(0,f.end);
      if(f.party!=null){where.add('pa.id=?');args.add(f.party);}
      if(f.search.isNotEmpty){where.add(term('pa.name'));}
      sql='''SELECT pa.name AS Name,pa.phone AS Phone,pa.address AS Address,
      coalesce(sum(CASE WHEN pa.kind='customer' THEN l.debit-l.credit ELSE l.credit-l.debit END),0)/100.0 AS Balance
      FROM parties pa LEFT JOIN party_ledger l ON pa.id=l.party_id AND l.date<=? WHERE ${where.join(' AND ')} GROUP BY pa.id ORDER BY pa.name''';
      headers=['Name','Phone','Address','Balance'];break;
    case 'Customer Ledger':
    case 'Supplier Ledger':
      where.add("pa.kind='${f.type=='Customer Ledger'?'customer':'supplier'}'");where.add(dateFilter('l.date'));
      if(f.party!=null){where.add('pa.id=?');args.add(f.party);}
      sql='''SELECT l.party_id AS PartyId,l.date AS Date,pa.name AS Party,l.source_type AS Source,l.source_id AS Ref,l.debit/100.0 AS Debit,l.credit/100.0 AS Credit,l.note AS Note
      FROM party_ledger l JOIN parties pa ON pa.id=l.party_id WHERE ${where.join(' AND ')} ORDER BY l.date,l.id''';
      headers=['Date','Party','Source','Ref','Debit','Credit','Note','Running Balance'];break;
    case 'Customer Receivables':
    case 'Supplier Payables':
      final kind=f.type=='Customer Receivables'?'customer':'supplier';
      where.add('pa.kind=?');args.add(kind);args.insert(0,f.end);
      if(f.party!=null){where.add('pa.id=?');args.add(f.party);}
      sql='''SELECT pa.name AS Name,pa.phone AS Phone,
      coalesce(sum(CASE WHEN pa.kind='customer' THEN l.debit-l.credit ELSE l.credit-l.debit END),0)/100.0 AS Outstanding
      FROM parties pa LEFT JOIN party_ledger l ON pa.id=l.party_id AND l.date<=? WHERE ${where.join(' AND ')} GROUP BY pa.id HAVING Outstanding>0 ORDER BY Outstanding DESC''';
      headers=['Name','Phone','Outstanding'];break;
    case 'Expenses':
      where.add(dateFilter('e.date'));
      if(f.expenseCategory!=null){where.add('e.category_id=?');args.add(f.expenseCategory);}
      if(f.minAmount!=null){where.add('e.amount>=?');args.add(pennies(f.minAmount!));}
      if(f.maxAmount!=null){where.add('e.amount<=?');args.add(pennies(f.maxAmount!));}
      if(f.search.isNotEmpty){where.add(term('e.description'));}
      sql='''SELECT e.date AS Date,c.name AS Category,e.description AS Description,e.amount/100.0 AS Amount,a.name AS Paid_From
      FROM expenses e JOIN expense_categories c ON c.id=e.category_id JOIN accounts a ON a.id=e.account_id
      LEFT JOIN reversed_transactions r ON r.kind='expense' AND r.source_id=e.id WHERE r.id IS NULL AND ${where.join(' AND ')} ORDER BY e.date DESC,e.id DESC''';
      headers=['Date','Category','Description','Amount','Paid_From'];break;
    case 'Employees':
      where.add('1=1');if(f.employee!=null){where.add('e.id=?');args.add(f.employee);}
      if(f.search.isNotEmpty){where.add(term('e.name'));}
      sql='''SELECT e.name AS Name,e.designation AS Designation,e.salary/100.0 AS Monthly_Salary,e.active AS Active,
      coalesce((SELECT sum(CASE WHEN kind='ADVANCE' THEN amount WHEN kind='RECOVERY' THEN -amount ELSE 0 END) FROM employee_ledger WHERE employee_id=e.id),0)/100.0 AS Advance_Balance
      FROM employees e WHERE ${where.join(' AND ')} ORDER BY e.name''';
      headers=['Name','Designation','Monthly_Salary','Active','Advance_Balance'];break;
    case 'Employee Ledger':
      where.add(dateFilter('l.date'));
      if(f.employee!=null){where.add('e.id=?');args.add(f.employee);}
      sql='''SELECT l.date AS Date,e.name AS Employee,l.kind AS Type,l.amount/100.0 AS Amount,l.note AS Note FROM employee_ledger l JOIN employees e ON e.id=l.employee_id WHERE ${where.join(' AND ')} ORDER BY l.date,l.id''';
      headers=['Date','Employee','Type','Amount','Note'];break;
    case 'Payroll':
      where.add(dateFilter('p.date'));
      if(f.employee!=null){where.add('e.id=?');args.add(f.employee);}
      sql='''SELECT p.date AS Date,e.name AS Employee,p.period AS Period,p.gross/100.0 AS Gross,p.recovery/100.0 AS Recovered,p.net/100.0 AS Net,p.paid/100.0 AS Paid,
      (p.net-p.paid)/100.0 AS Outstanding FROM payroll p JOIN employees e ON e.id=p.employee_id WHERE ${where.join(' AND ')} ORDER BY p.date DESC''';
      headers=['Date','Employee','Period','Gross','Recovered','Net','Paid','Outstanding'];break;
    case 'Cash & Bank':
      where.add(dateFilter('j.date'));where.add("a.id IN (SELECT account_id FROM payment_accounts)");
      sql='''SELECT j.date AS Date,a.name AS Account,j.source_type AS Source,j.note AS Description,jl.debit/100.0 AS Debit,jl.credit/100.0 AS Credit
      FROM journal_lines jl JOIN journal j ON j.id=jl.journal_id JOIN accounts a ON a.id=jl.account_id WHERE ${where.join(' AND ')} ORDER BY j.date,j.id''';
      headers=['Date','Account','Source','Description','Debit','Credit'];break;
    case 'Trial Balance':
      // Cumulative to end date; not only within period.
      args.addAll([f.end,f.end,f.end]);
      sql='''SELECT a.code AS Code,a.name AS Account,a.type AS Type,
      coalesce(sum(CASE WHEN j.date<=? THEN jl.debit ELSE 0 END),0)/100.0 AS Debit,
      coalesce(sum(CASE WHEN j.date<=? THEN jl.credit ELSE 0 END),0)/100.0 AS Credit,
      (coalesce(sum(CASE WHEN j.date<=? THEN jl.debit-jl.credit ELSE 0 END),0))/100.0 AS Net_Dr
      FROM accounts a LEFT JOIN journal_lines jl ON jl.account_id=a.id LEFT JOIN journal j ON j.id=jl.journal_id
      GROUP BY a.id ORDER BY a.code''';
      headers=['Code','Account','Type','Debit','Credit','Net_Dr'];break;
    case 'Revenue & Expenses':
      // Does not include inventory cost-of-sales: see limitations.
      where.add(dateFilter('j.date'));where.add("a.type IN ('revenue','expense')");
      sql='''SELECT a.code AS Code,a.name AS Account,a.type AS Type,
      coalesce(sum(jl.credit-jl.debit),0)/100.0 AS Net_Credit
      FROM journal_lines jl JOIN journal j ON j.id=jl.journal_id JOIN accounts a ON a.id=jl.account_id WHERE ${where.join(' AND ')} GROUP BY a.id ORDER BY a.code''';
      headers=['Code','Account','Type','Net_Credit'];break;
    case 'Sales Returns':
    case 'Purchase Returns':
      final sale=f.type=='Sales Returns';
      where.add('d.kind=?');args.add(sale?'sale':'purchase');where.add(dateFilter('r.date'));
      if(f.party!=null){where.add('d.party_id=?');args.add(f.party);}
      if(f.category!=null){where.add('c.id=?');args.add(f.category);}
      if(f.product!=null){where.add('p.id=?');args.add(f.product);}
      if(f.variant!=null){where.add('v.id=?');args.add(f.variant);}
      if(f.search.isNotEmpty){where.add(term('d.invoice'));}
      sql='''SELECT r.date AS Date,d.invoice AS Original_Invoice,coalesce(pa.name,'Walk-in') AS Party,
        p.name AS Product,v.sku AS SKU,rl.qty AS Qty,v.unit AS Unit,rl.amount/100.0 AS Return_Amount,
        r.refunded/100.0 AS Cash_Refund,r.reason AS Reason,r.status AS Status
        FROM return_lines rl JOIN document_returns r ON r.id=rl.return_id
        JOIN documents d ON d.id=r.document_id
        JOIN document_lines dl ON dl.id=rl.source_line_id
        JOIN variants v ON v.id=rl.variant_id JOIN products p ON p.id=v.product_id JOIN categories c ON c.id=p.category_id
        LEFT JOIN parties pa ON pa.id=d.party_id WHERE ${where.join(' AND ')} ORDER BY r.date DESC,r.id DESC''';
      headers=['Date','Original_Invoice','Party','Product','SKU','Qty','Unit','Return_Amount','Cash_Refund','Reason','Status'];break;
    case 'Payments':
      where.add(dateFilter('r.date'));
      if(f.party!=null){where.add('r.party_id=?');args.add(f.party);}
      sql='''SELECT r.date AS Date,p.name AS Party,p.kind AS Type,r.amount/100.0 AS Amount,
        a.name AS Account,r.note AS Note,CASE WHEN rev.id IS NULL THEN 'POSTED' ELSE 'VOID' END AS Status
        FROM receipts r JOIN parties p ON p.id=r.party_id JOIN accounts a ON a.id=r.account_id
        LEFT JOIN reversed_transactions rev ON rev.kind='receipt' AND rev.source_id=r.id
        WHERE ${where.join(' AND ')} ORDER BY r.date DESC,r.id DESC''';
      headers=['Date','Party','Type','Amount','Account','Note','Status'];break;
    case 'Salary Outstanding':
      where.add('e.active=1');
      if(f.employee!=null){where.add('e.id=?');args.add(f.employee);}
      sql='''SELECT e.name AS Employee,e.designation AS Role,
        coalesce(sum(CASE WHEN l.kind='SALARY_DUE' THEN l.amount WHEN l.kind IN ('RECOVERY','SALARY_PAID') THEN -l.amount ELSE 0 END),0)/100.0 AS Outstanding
        FROM employees e LEFT JOIN employee_ledger l ON l.employee_id=e.id WHERE ${where.join(' AND ')}
        GROUP BY e.id HAVING Outstanding>0 ORDER BY Outstanding DESC''';
      headers=['Employee','Role','Outstanding'];break;
    case 'Account Ledger':
      where.add(dateFilter('j.date'));
      if(f.search.isNotEmpty){where.add('(a.name LIKE ? OR a.code LIKE ? OR j.note LIKE ?)');args.addAll(List.filled(3,'%${f.search}%'));}
      sql='''SELECT j.date AS Date,a.code AS Code,a.name AS Account,j.source_type AS Type,
        j.source_id AS Ref,j.note AS Note,jl.debit/100.0 AS Debit,jl.credit/100.0 AS Credit
        FROM journal_lines jl JOIN journal j ON j.id=jl.journal_id JOIN accounts a ON a.id=jl.account_id
        WHERE ${where.join(' AND ')} ORDER BY j.date,j.id,jl.id''';
      headers=['Date','Code','Account','Type','Ref','Note','Debit','Credit'];break;
    case 'Stock As of Date':
      where.add('m.date<=?');args.add(f.end);
      if(f.category!=null){where.add('c.id=?');args.add(f.category);}
      if(f.product!=null){where.add('p.id=?');args.add(f.product);}
      if(f.variant!=null){where.add('v.id=?');args.add(f.variant);}
      sql='''SELECT c.name AS Category,p.name AS Product,v.sku AS SKU,v.unit AS Unit,
        coalesce(sum(m.qty),0) AS Stock
        FROM variants v JOIN products p ON p.id=v.product_id JOIN categories c ON c.id=p.category_id
        LEFT JOIN stock_movements m ON m.variant_id=v.id AND m.date<=?
        ${f.category!=null||f.product!=null||f.variant!=null?'WHERE '+[if(f.category!=null)'c.id=?',if(f.product!=null)'p.id=?',if(f.variant!=null)'v.id=?'].join(' AND '):''}
        GROUP BY v.id ORDER BY p.name,v.sku''';
      args.clear();args.add(f.end);if(f.category!=null)args.add(f.category);if(f.product!=null)args.add(f.product);if(f.variant!=null)args.add(f.variant);
      headers=['Category','Product','SKU','Unit','Stock'];break;
    case 'Daily Sales Summary':
      where.add("d.kind='sale'");where.add("d.status='POSTED'");where.add(dateFilter('d.date'));
      sql='''SELECT d.date AS Date,count(*) AS Bills,sum(d.total)/100.0 AS Revenue,sum(d.paid)/100.0 AS Collected,
        sum(d.total-d.paid)/100.0 AS Credit_Due FROM documents d WHERE ${where.join(' AND ')} GROUP BY d.date ORDER BY d.date''';
      headers=['Date','Bills','Revenue','Collected','Credit_Due'];break;
    case 'Monthly Sales Summary':
      where.add("d.kind='sale'");where.add("d.status='POSTED'");where.add(dateFilter('d.date'));
      sql='''SELECT substr(d.date,1,7) AS Month,count(*) AS Bills,sum(d.total)/100.0 AS Revenue,
        sum(d.paid)/100.0 AS Collected,sum(d.total-d.paid)/100.0 AS Credit_Due
        FROM documents d WHERE ${where.join(' AND ')} GROUP BY substr(d.date,1,7) ORDER BY Month''';
      headers=['Month','Bills','Revenue','Collected','Credit_Due'];break;
    case 'Audit Trail':
      where.add(dateFilter('substr(at,1,10)'));
      sql='SELECT at AS Timestamp,event AS Event,entity AS Entity,entity_id AS ID,notes AS Details FROM audit WHERE ${where.join(' AND ')} ORDER BY id DESC';
      headers=['Timestamp','Event','Entity','ID','Details'];break;
    default:throw ArgumentError('Unsupported report');
  }
  final data=await s.read(sql,args);
  if(f.type=='Customer Ledger'||f.type=='Supplier Ledger'){
    final kind=f.type=='Customer Ledger'?'customer':'supplier';
    final openingRows=await s.read("""SELECT p.id AS party_id,sum(l.debit-l.credit) AS net
      FROM party_ledger l JOIN parties p ON p.id=l.party_id
      WHERE p.kind=? AND l.date<? ${f.party==null?'':'AND p.id=?'} GROUP BY p.id""",
      [kind,f.start,if(f.party!=null)f.party]);
    final balances=<String,int>{};
    for(final r in openingRows){balances['${r['party_id']}']=(r['net'] as num).toInt()*(kind=='customer'?1:-1);}
    final rows=<List<String>>[];
    for(final r in data){
      final name='${r['PartyId']}';
      final debit=pennies(numVal(r['Debit']));final credit=pennies(numVal(r['Credit']));
      balances[name]=(balances[name]??0)+(kind=='customer'?debit-credit:credit-debit);
      rows.add([...headers.take(7).map((h)=>'${r[h]??''}'),rupees(balances[name]).toStringAsFixed(2)]);
    }
    return ReportResult(f.type,headers,rows);
  }
  final values=data.map((r)=>headers.map((h)=>'${r[h] ?? ''}').toList()).toList();
  return ReportResult(f.type,headers,values);
}

class Exports {
  static Future<void> pdf(ReportResult report,{bool print=false}) async {
    final settings=CommercialCore.instance;
    final shopName=await settings.readSetting('shop_name')??'ShopDesk';
    final shopPhone=await settings.readSetting('shop_phone')??'';
    final shopAddress=await settings.readSetting('shop_address')??'';
    final logoPath=await settings.readSetting('shop_logo')??'';
    pw.MemoryImage? logo;
    if(logoPath.isNotEmpty){
      final image=File(logoPath);
      if(await image.exists()){
        try{logo=pw.MemoryImage(await image.readAsBytes());}catch(_){/* continue without logo */}
      }
    }
    final doc=pw.Document();
    final landscape=report.headings.length>6;
    doc.addPage(pw.MultiPage(pageFormat:landscape?PdfPageFormat.a4.landscape:PdfPageFormat.a4,
      margin:const pw.EdgeInsets.all(24),
      header:(context)=>pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
        pw.Row(children:[if(logo!=null)pw.Padding(padding:const pw.EdgeInsets.only(right:10),child:pw.Image(logo,height:34,width:42)),pw.Expanded(child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[pw.Text(shopName,style:pw.TextStyle(fontSize:14,fontWeight:pw.FontWeight.bold)),if(shopPhone.isNotEmpty||shopAddress.isNotEmpty)pw.Text('$shopPhone  $shopAddress',style:const pw.TextStyle(fontSize:8)),pw.Text(report.title,style:const pw.TextStyle(fontSize:10))]))]),
        pw.Text('Generated ${DateTime.now().toLocal().toString().substring(0,16)}',style:const pw.TextStyle(fontSize:8)),pw.SizedBox(height:10)]),
      footer:(context)=>pw.Align(alignment:pw.Alignment.centerRight,child:pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',style:const pw.TextStyle(fontSize:8))),
      build:(context)=>[pw.TableHelper.fromTextArray(headers:report.headings,
        data:report.rows.isEmpty?[List.filled(report.headings.length,'')]:report.rows,
        headerStyle:pw.TextStyle(fontSize:7,fontWeight:pw.FontWeight.bold),cellStyle:const pw.TextStyle(fontSize:7),
        cellPadding:const pw.EdgeInsets.all(4),headerDecoration:const pw.BoxDecoration(color:PdfColors.grey200))]));
    final bytes=await doc.save();
    if(print){await Printing.layoutPdf(onLayout:(fmt)async=>bytes,name:'ShopDesk ${report.title}');return;}
    final location=await FilePicker.platform.saveFile(dialogTitle:'Save A4 Report as PDF',fileName:'shopdesk_${report.title.toLowerCase().replaceAll(' ','_')}.pdf',type:FileType.custom,allowedExtensions:['pdf']);
    if(location!=null)await File(location).writeAsBytes(bytes);
  }
  static Future<void> excel(ReportResult report) async {
    final workbook=Excel.createExcel();
    final sheet=workbook['Report'];
    sheet.appendRow(report.headings.map((x)=>TextCellValue(x)).toList());
    for(final row in report.rows){sheet.appendRow(row.map((x)=>TextCellValue(x)).toList());}
    final bytes=workbook.encode();
    if(bytes==null)throw StateError('Could not create XLSX');
    final location=await FilePicker.platform.saveFile(dialogTitle:'Save Excel Report',fileName:'shopdesk_${report.title.toLowerCase().replaceAll(' ','_')}.xlsx',type:FileType.custom,allowedExtensions:['xlsx']);
    if(location!=null)await File(location).writeAsBytes(bytes);
  }
}
