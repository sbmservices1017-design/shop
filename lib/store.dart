// Build source revision: SHOPDESK_SOURCE_0_4_2_ANALYZER_FIX
import 'dart:io';
import 'dart:convert';
import 'payroll_math.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

int pennies(num amount) => (amount * 100).round();
double rupees(Object? paisa) => ((paisa as num?) ?? 0).toDouble() / 100;
double numVal(Object? value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
String nowDate() => DateTime.now().toIso8601String().substring(0,10);
String nowStamp() => DateTime.now().toIso8601String();

String paymentAccountLabel(Map<String,Object?> account) {
  final holder='${account['holder_name']??''}'.trim();
  final code='${account['code']??account['id']}';
  final name='${account['name']}';
  return holder.isEmpty?'$name  •  $code':'$name  •  $holder  •  $code';
}


const schema = <String>[
  '''CREATE TABLE IF NOT EXISTS app_settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)''',
  '''CREATE TABLE IF NOT EXISTS document_revisions(id INTEGER PRIMARY KEY,document_id INTEGER NOT NULL REFERENCES documents(id),changed_at TEXT NOT NULL,old_invoice TEXT NOT NULL,old_date TEXT NOT NULL,old_party_id INTEGER,old_total INTEGER NOT NULL,old_paid INTEGER NOT NULL,old_notes TEXT NOT NULL,old_lines_json TEXT NOT NULL)''',
  '''CREATE TABLE IF NOT EXISTS receipt_allocations(receipt_id INTEGER NOT NULL REFERENCES receipts(id),document_id INTEGER NOT NULL REFERENCES documents(id),amount INTEGER NOT NULL CHECK(amount>0),PRIMARY KEY(receipt_id,document_id))''',
  '''CREATE TABLE IF NOT EXISTS document_payment_parts(id INTEGER PRIMARY KEY,document_id INTEGER NOT NULL REFERENCES documents(id),account_id INTEGER NOT NULL REFERENCES accounts(id),amount INTEGER NOT NULL CHECK(amount>0),active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0,1)))''',
  '''CREATE INDEX IF NOT EXISTS idx_document_payment_parts ON document_payment_parts(document_id,active)''',
'''CREATE TABLE IF NOT EXISTS categories(id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE COLLATE NOCASE, active INTEGER NOT NULL DEFAULT 1)''',
'''CREATE TABLE IF NOT EXISTS attributes(id INTEGER PRIMARY KEY, category_id INTEGER NOT NULL REFERENCES categories(id), name TEXT NOT NULL, kind TEXT NOT NULL DEFAULT 'text', choices TEXT NOT NULL DEFAULT '', UNIQUE(category_id,name))''',
'''CREATE TABLE IF NOT EXISTS products(id INTEGER PRIMARY KEY, category_id INTEGER NOT NULL REFERENCES categories(id), name TEXT NOT NULL, active INTEGER NOT NULL DEFAULT 1)''',
'''CREATE TABLE IF NOT EXISTS variants(id INTEGER PRIMARY KEY, product_id INTEGER NOT NULL REFERENCES products(id), sku TEXT UNIQUE NOT NULL COLLATE NOCASE, unit TEXT NOT NULL DEFAULT 'pcs', active INTEGER NOT NULL DEFAULT 1)''',
'''CREATE TABLE IF NOT EXISTS variant_values(variant_id INTEGER NOT NULL REFERENCES variants(id),attribute_id INTEGER NOT NULL REFERENCES attributes(id),value TEXT NOT NULL,PRIMARY KEY(variant_id,attribute_id))''',
'''CREATE TABLE IF NOT EXISTS parties(id INTEGER PRIMARY KEY,kind TEXT NOT NULL CHECK(kind IN ('customer','supplier')),name TEXT NOT NULL,phone TEXT NOT NULL DEFAULT '',address TEXT NOT NULL DEFAULT '',active INTEGER NOT NULL DEFAULT 1)''',
'''CREATE TABLE IF NOT EXISTS documents(id INTEGER PRIMARY KEY,kind TEXT NOT NULL CHECK(kind IN ('sale','purchase')),invoice TEXT NOT NULL UNIQUE,party_id INTEGER REFERENCES parties(id),date TEXT NOT NULL,total INTEGER NOT NULL DEFAULT 0,paid INTEGER NOT NULL DEFAULT 0,notes TEXT NOT NULL DEFAULT '',status TEXT NOT NULL DEFAULT 'POSTED' CHECK(status IN ('POSTED','VOID')))''',
'''CREATE TABLE IF NOT EXISTS document_lines(id INTEGER PRIMARY KEY,document_id INTEGER NOT NULL REFERENCES documents(id),variant_id INTEGER NOT NULL REFERENCES variants(id),qty REAL NOT NULL CHECK(qty>0),rate INTEGER NOT NULL CHECK(rate>=0),amount INTEGER NOT NULL CHECK(amount>=0),is_current INTEGER NOT NULL DEFAULT 1)''',
'''CREATE TABLE IF NOT EXISTS variant_units(variant_id INTEGER NOT NULL REFERENCES variants(id),unit TEXT NOT NULL COLLATE NOCASE,factor REAL NOT NULL CHECK(factor>0),can_buy INTEGER NOT NULL DEFAULT 1,can_sell INTEGER NOT NULL DEFAULT 1,PRIMARY KEY(variant_id,unit))''',
'''CREATE TABLE IF NOT EXISTS document_line_units(line_id INTEGER PRIMARY KEY REFERENCES document_lines(id) ON DELETE CASCADE,unit TEXT NOT NULL,factor REAL NOT NULL CHECK(factor>0))''',
'''CREATE TABLE IF NOT EXISTS payment_accounts(account_id INTEGER PRIMARY KEY REFERENCES accounts(id),kind TEXT NOT NULL CHECK(kind IN ('cash','bank','wallet')),holder_name TEXT NOT NULL DEFAULT '')''',
'''CREATE TABLE IF NOT EXISTS stock_movements(id INTEGER PRIMARY KEY,variant_id INTEGER NOT NULL REFERENCES variants(id),qty REAL NOT NULL,source_type TEXT NOT NULL,source_id INTEGER NOT NULL,date TEXT NOT NULL,note TEXT NOT NULL DEFAULT '')''',
'''CREATE TABLE IF NOT EXISTS party_ledger(id INTEGER PRIMARY KEY,party_id INTEGER NOT NULL REFERENCES parties(id),debit INTEGER NOT NULL DEFAULT 0,credit INTEGER NOT NULL DEFAULT 0,source_type TEXT NOT NULL,source_id INTEGER NOT NULL,date TEXT NOT NULL,note TEXT NOT NULL DEFAULT '',payment_account_id INTEGER REFERENCES accounts(id))''',
'''CREATE TABLE IF NOT EXISTS accounts(id INTEGER PRIMARY KEY,code TEXT NOT NULL UNIQUE,name TEXT NOT NULL,type TEXT NOT NULL,active INTEGER NOT NULL DEFAULT 1)''',
'''CREATE TABLE IF NOT EXISTS journal(id INTEGER PRIMARY KEY,date TEXT NOT NULL,source_type TEXT NOT NULL,source_id INTEGER NOT NULL,note TEXT NOT NULL DEFAULT '')''',
'''CREATE TABLE IF NOT EXISTS journal_lines(id INTEGER PRIMARY KEY,journal_id INTEGER NOT NULL REFERENCES journal(id),account_id INTEGER NOT NULL REFERENCES accounts(id),debit INTEGER NOT NULL DEFAULT 0,credit INTEGER NOT NULL DEFAULT 0)''',
'''CREATE TABLE IF NOT EXISTS receipts(id INTEGER PRIMARY KEY,party_id INTEGER NOT NULL REFERENCES parties(id),date TEXT NOT NULL,amount INTEGER NOT NULL CHECK(amount>0),account_id INTEGER NOT NULL REFERENCES accounts(id),note TEXT NOT NULL DEFAULT '')''',
'''CREATE TABLE IF NOT EXISTS receipt_allocations(receipt_id INTEGER NOT NULL REFERENCES receipts(id), document_id INTEGER NOT NULL REFERENCES documents(id), amount INTEGER NOT NULL CHECK(amount>0),PRIMARY KEY(receipt_id,document_id))''',
'''CREATE TABLE IF NOT EXISTS expense_categories(id INTEGER PRIMARY KEY,name TEXT NOT NULL UNIQUE COLLATE NOCASE)''',
'''CREATE TABLE IF NOT EXISTS expenses(id INTEGER PRIMARY KEY,category_id INTEGER NOT NULL REFERENCES expense_categories(id),date TEXT NOT NULL,amount INTEGER NOT NULL CHECK(amount>0),account_id INTEGER NOT NULL REFERENCES accounts(id),description TEXT NOT NULL DEFAULT '')''',
'''CREATE TABLE IF NOT EXISTS employees(id INTEGER PRIMARY KEY,name TEXT NOT NULL,designation TEXT NOT NULL DEFAULT '',salary INTEGER NOT NULL DEFAULT 0,active INTEGER NOT NULL DEFAULT 1)''',
'''CREATE TABLE IF NOT EXISTS employee_ledger(id INTEGER PRIMARY KEY,employee_id INTEGER NOT NULL REFERENCES employees(id),date TEXT NOT NULL,kind TEXT NOT NULL,amount INTEGER NOT NULL,source_type TEXT NOT NULL,source_id INTEGER NOT NULL,note TEXT NOT NULL DEFAULT '')''',
'''CREATE TABLE IF NOT EXISTS payroll(id INTEGER PRIMARY KEY,employee_id INTEGER NOT NULL REFERENCES employees(id),period TEXT NOT NULL,gross INTEGER NOT NULL,recovery INTEGER NOT NULL,net INTEGER NOT NULL,paid INTEGER NOT NULL,date TEXT NOT NULL,UNIQUE(employee_id,period))''',
'''CREATE TABLE IF NOT EXISTS audit(id INTEGER PRIMARY KEY,at TEXT NOT NULL,event TEXT NOT NULL,entity TEXT NOT NULL,entity_id INTEGER NOT NULL,notes TEXT NOT NULL DEFAULT '')''',
'''CREATE INDEX IF NOT EXISTS idx_stock_variant ON stock_movements(variant_id)''',
'''CREATE INDEX IF NOT EXISTS idx_ledger_party ON party_ledger(party_id,date)''',
'''CREATE INDEX IF NOT EXISTS idx_journal_account ON journal_lines(account_id)'''
];

/// One portion of a sale/purchase invoice, paid through one cash/bank/wallet.
/// Amount is in rupees; persistence converts to integer paisa.
class PaymentPart {
  final int accountId;
  final double amount;
  const PaymentPart(this.accountId, this.amount);
}

class ItemLine {
  final int variantId;
  final double qty;
  final double rate;
  final String? unit;
  final double factor;
  const ItemLine(this.variantId,this.qty,this.rate,{this.unit,this.factor=1});
}

class Store {
  Store._();
  static final Store instance = Store._();
  late Database db;
  late String dbPath;

  Future<void> init({String? overridePath}) async {
    sqfliteFfiInit();
    final root = overridePath == null ? await getApplicationSupportDirectory() : Directory(path.dirname(overridePath));
    await root.create(recursive:true);
    dbPath=overridePath ?? path.join(root.path,'shopdesk.sqlite');
    db = await databaseFactoryFfi.openDatabase(dbPath,options:OpenDatabaseOptions(onConfigure:(d) async {
      await d.execute('PRAGMA foreign_keys=ON');
      await d.execute('PRAGMA busy_timeout=5000');
      await d.execute('PRAGMA journal_mode=WAL');
    }));
    for(final sql in schema){await db.execute(sql);}
    for(final a in <List<String>>[
      ['1000','Cash','asset'],['1010','Bank','asset'],['1100','Accounts Receivable','asset'],
      ['1200','Inventory','asset'],['1300','Employee Advances','asset'],
      ['2000','Accounts Payable','liability'],['2100','Salary Payable','liability'],
      ['3000','Opening Equity','equity'],['4000','Sales Revenue','revenue'],
      ['5000','Cost of Sales','expense'],['6100','Operating Expense','expense'],['6200','Salary Expense','expense']
    ]) {await db.rawInsert('INSERT OR IGNORE INTO accounts(code,name,type) VALUES(?,?,?)',a);}
    // Historic returned lines must remain FK-valid during subsequent invoice edits.
    final documentLineColumns=await db.rawQuery('PRAGMA table_info(document_lines)');
    if(!documentLineColumns.any((c)=>c['name']=='is_current')){
      await db.execute('ALTER TABLE document_lines ADD COLUMN is_current INTEGER NOT NULL DEFAULT 1');
    }
    // Account list creation date; legacy accounts receive the earliest activity date.
    final accountColumns=await db.rawQuery('PRAGMA table_info(accounts)');
    if(!accountColumns.any((c)=>c['name']=='created_at')) {
      await db.execute('ALTER TABLE accounts ADD COLUMN created_at TEXT');
    }
    await db.execute("""UPDATE accounts SET created_at=COALESCE(
      (SELECT MIN(j.date) FROM journal_lines l JOIN journal j ON j.id=l.journal_id
       WHERE l.account_id=accounts.id), date('now')) WHERE created_at IS NULL""");
    await db.rawInsert("INSERT OR IGNORE INTO expense_categories(name) VALUES('General')");
    // Safe repeated migration; never change historical stock on upgrade.
    await db.execute("INSERT OR IGNORE INTO payment_accounts(account_id,kind) SELECT id,CASE WHEN code='1000' THEN 'cash' ELSE 'bank' END FROM accounts WHERE code IN ('1000','1010')");
    // Existing installations have payment_accounts without a holder_name column.
    // Adding the column preserves every account ID, invoice, and journal reference.
    final paymentColumns=await db.rawQuery('PRAGMA table_info(payment_accounts)');
    if(!paymentColumns.any((column)=>column['name']=='holder_name')){
      await db.execute("ALTER TABLE payment_accounts ADD COLUMN holder_name TEXT NOT NULL DEFAULT ''");
    }
    // Payment account reference on each party-ledger row. Existing invoices and
    // receipts remain intact; older rows use a report-side account lookup.
    final ledgerColumns=await db.rawQuery('PRAGMA table_info(party_ledger)');
    if(!ledgerColumns.any((column)=>column['name']=='payment_account_id')){
      await db.execute('ALTER TABLE party_ledger ADD COLUMN payment_account_id INTEGER REFERENCES accounts(id)');
    }
    // Existing Roll variants may have been purchase-only. Allow selling a full
    // Roll as well as Feet/Gazz without changing its stored conversion factor.
    await db.execute("UPDATE variant_units SET can_sell=1 WHERE lower(unit)='roll' AND can_sell=0");
  }

  Future<List<Map<String,Object?>>> read(String sql,[List<Object?> args=const []]) => db.rawQuery(sql,args);
  Future<int> count(String sql,[List<Object?> args=const []]) async => ((await read(sql,args)).first.values.first as num).toInt();
  Future<void> audit(Transaction t,String event,String entity,int id,[String notes='']) async {
    await t.rawInsert('INSERT INTO audit(at,event,entity,entity_id,notes) VALUES(?,?,?,?,?)',[nowStamp(),event,entity,id,notes]);
  }

  Future<int> addCategory(String name) async {
    if(name.trim().isEmpty) throw const FormatException('Category name is required');
    return db.rawInsert('INSERT INTO categories(name) VALUES(?)',[name.trim()]);
  }
  Future<int> addAttribute(int category,String name,String kind,String choices) async => db.rawInsert('INSERT INTO attributes(category_id,name,kind,choices) VALUES(?,?,?,?)',[category,name.trim(),kind,choices]);
  Future<int> addProduct(int category,String name) async => db.rawInsert('INSERT INTO products(category_id,name) VALUES(?,?)',[category,name.trim()]);
  Future<int> addVariant(int product,String sku,String unit,Map<int,String> values,double opening) async => db.transaction((t) async {
    if(sku.trim().isEmpty) throw const FormatException('SKU is required');
    final productRow=await t.rawQuery('SELECT category_id FROM products WHERE id=?',[product]);
    if(productRow.isEmpty) throw const FormatException('Product not found');
    final attrs=await t.rawQuery('SELECT * FROM attributes WHERE category_id=?',[productRow.first['category_id']]);
    for(final a in attrs) {
      final id=a['id'] as int; final value=(values[id] ?? '').trim();
      if(value.isEmpty) continue;
      if(a['kind']=='number' && double.tryParse(value)==null) throw FormatException('${a['name']} must be numeric');
      if(a['kind']=='choice' && !((a['choices'] as String).split('|').map((x)=>x.trim()).contains(value))) throw FormatException('Invalid choice for ${a['name']}');
    }
    final vid=await t.rawInsert('INSERT INTO variants(product_id,sku,unit) VALUES(?,?,?)',[product,sku.trim(),unit]);
    for(final e in values.entries){if(e.value.trim().isNotEmpty){await t.rawInsert('INSERT INTO variant_values(variant_id,attribute_id,value) VALUES(?,?,?)',[vid,e.key,e.value.trim()]);}}
    if(!opening.isFinite || (opening*1000-(opening*1000).round()).abs()>0.00001)throw const FormatException('Opening stock must have at most 3 decimals');
    if(opening!=0){await t.rawInsert('INSERT INTO stock_movements(variant_id,qty,source_type,source_id,date,note) VALUES(?,?,?,?,?,?)',[vid,opening,'OPENING',vid,nowDate(),'Opening inventory']);}
    await audit(t,'ADD','variant',vid,sku);
    return vid;
  });

  /// Simple shopkeeper workflow. One category -> product -> sellable variation.
  /// All quantities are stored in canonical loose pieces or feet.
  /// Purchases/sales choose their pack/unit; invoices snapshot the factor.
  Future<int> createSimpleVariant({
    required int productId,
    String size='',
    String color='',
    String design='',
    String quality='',
    required String packing,
    required double packSize,
    double feetPerGazz=3,
    double? rollGazz,
    double? tableSheetGazz,
    int? sheetsPerRoll,
    double openingPacks=0,
  }) async {
    if(!{'piece','set','packet','roll','table_sheet_roll'}.contains(packing)) {
      throw const FormatException('Choose Piece, Set, Packet, Roll or Table Sheet Roll');
    }
    // Finished, ready-made Table Sheets are counted as individual Sheets.
    // This is a DIFFERENT variation from a length-based Roll (Feet/Gazz).
    if(packing=='table_sheet_roll' &&
       (sheetsPerRoll==null || sheetsPerRoll<1 || sheetsPerRoll>1000000)) {
      throw const FormatException('Enter how many Table Sheets are inside one Roll');
    }
    if(packing!='table_sheet_roll' && sheetsPerRoll!=null) {
      throw const FormatException('Sheets per Roll is only valid for Table Sheet Rolls');
    }
    // Stock is always stored in feet for Rolls and pieces for Sets/Packets.
    // New simple catalog collects Gazz per Roll; older clients can still
    // supply packSize in Feet to keep existing tests and data compatible.
    final factor=packing=='table_sheet_roll' ? sheetsPerRoll!.toDouble()
        : (packing=='roll' && rollGazz!=null
          ? rollGazz*feetPerGazz : (packing=='piece'?1.0:packSize));
    if(rollGazz!=null && (packing!='roll' || !rollGazz.isFinite || rollGazz<=0)) {
      throw const FormatException('Gazz per Roll must be a positive number');
    }
    if(tableSheetGazz!=null && (packing!='roll' || !tableSheetGazz.isFinite ||
      tableSheetGazz<=0 || tableSheetGazz*feetPerGazz>factor)) {
      throw const FormatException('Table Sheet length must be positive and cannot exceed one Roll');
    }
    if(!factor.isFinite || factor<=0 || factor>1000000 ||
       !feetPerGazz.isFinite || feetPerGazz<=0 || feetPerGazz>1000000 ||
       !openingPacks.isFinite || openingPacks<0 || openingPacks>100000000 ||
       ((openingPacks*factor)*1000-(openingPacks*factor*1000).round()).abs()>0.00001) {
      throw const FormatException('Enter valid pack/roll length and opening stock');
    }
    if(packing!='roll' && packing!='piece' && (factor-factor.round()).abs()>0.000001) {
      throw const FormatException('Pieces per set/packet must be a whole number');
    }
    if(packing!='roll' && (openingPacks*factor-(openingPacks*factor).round()).abs()>0.000001) {
      throw const FormatException('Opening stock in Pieces must be a whole number');
    }
    final details=<String,String>{'Size':size.trim(),'Color':color.trim(),
      'Design':design.trim(),'Quality':quality.trim(),
      if(packing=='table_sheet_roll') 'Packing':'Table Sheet Roll ($sheetsPerRoll Sheets)'};
    return db.transaction((t) async {
      final pr=await t.rawQuery('SELECT category_id FROM products WHERE id=? AND active=1',[productId]);
      if(pr.isEmpty)throw const FormatException('Product not found');
      final category=pr.first['category_id'] as int;
      final sku='P${productId}-V${DateTime.now().microsecondsSinceEpoch}';
      final baseUnit=packing=='roll'?'ft':'pcs';
      final vid=await t.rawInsert('INSERT INTO variants(product_id,sku,unit) VALUES(?,?,?)',
        [productId,sku,baseUnit]);
      for(final entry in details.entries) {
        if(entry.value.isEmpty)continue;
        await t.rawInsert('INSERT OR IGNORE INTO attributes(category_id,name,kind,choices) VALUES(?,?,?,?)',
          [category,entry.key,'text','']);
        final attr=await t.rawQuery('SELECT id FROM attributes WHERE category_id=? AND name=?',
          [category,entry.key]);
        await t.rawInsert('INSERT INTO variant_values(variant_id,attribute_id,value) VALUES(?,?,?)',
          [vid,attr.first['id'],entry.value]);
      }
      if(packing=='table_sheet_roll') {
        // Buy 1 Roll = N ready-made Sheets, sell as Sheets or full Rolls.
        // Keep canonical stock in whole pieces; no length/Gazz conversion.
        await t.rawInsert('INSERT INTO variant_units(variant_id,unit,factor,can_buy,can_sell) VALUES(?,?,?,?,?)',
          [vid,'roll',factor,1,1]);
        await t.rawInsert('INSERT INTO variant_units(variant_id,unit,factor,can_buy,can_sell) VALUES(?,?,?,?,?)',
          [vid,'table sheet',1.0,0,1]);
      } else if(packing!='piece') {
        await t.rawInsert('INSERT INTO variant_units(variant_id,unit,factor,can_buy,can_sell) VALUES(?,?,?,?,?)',
          [vid,packing,factor,1,1]);
      }
      if(packing=='roll') {
        await t.rawInsert('INSERT INTO variant_units(variant_id,unit,factor,can_buy,can_sell) VALUES(?,?,?,?,?)',
          [vid,'gazz',feetPerGazz,0,1]);
        if(tableSheetGazz!=null) {
          await t.rawInsert('INSERT INTO variant_units(variant_id,unit,factor,can_buy,can_sell) VALUES(?,?,?,?,?)',
            [vid,'table sheet',tableSheetGazz*feetPerGazz,0,1]);
        }
      }
      final opening=openingPacks*factor;
      if(opening!=0) {
        await t.rawInsert('INSERT INTO stock_movements(variant_id,qty,source_type,source_id,date,note) VALUES(?,?,?,?,?,?)',
          [vid,opening,'OPENING',vid,nowDate(),'Opening stock in $packing']);
      }
      await audit(t,'ADD','variant',vid,
          packing=='table_sheet_roll'
            ? 'Table Sheet Roll of $sheetsPerRoll individual Sheets'
            : 'Simple product variation: $packing');
      return vid;
    });
  }

  /// Edit common Size/Color/Design/Quality details without exposing attribute IDs.
  /// Other legacy category attributes are left intact.
  Future<void> updateSimpleVariantDetails(int variantId, Map<String,String> details) async => db.transaction((t) async {
    const names=['Size','Color','Design','Quality'];
    final existing=await t.rawQuery('''SELECT p.category_id FROM variants v JOIN products p ON p.id=v.product_id
      WHERE v.id=? AND v.active=1''',[variantId]);
    if(existing.isEmpty)throw const FormatException('Variation not found');
    final category=existing.first['category_id'] as int;
    for(final name in names){
      final value=(details[name]??'').trim();
      final known=await t.rawQuery('SELECT id FROM attributes WHERE category_id=? AND name=?',[category,name]);
      int? attribute=known.isEmpty?null:known.first['id'] as int;
      if(attribute==null && value.isNotEmpty){
        attribute=await t.rawInsert('INSERT INTO attributes(category_id,name,kind,choices) VALUES(?,?,?,?)',[category,name,'text','']);
      }
      if(attribute==null)continue;
      await t.rawDelete('DELETE FROM variant_values WHERE variant_id=? AND attribute_id=?',[variantId,attribute]);
      if(value.isNotEmpty)await t.rawInsert('INSERT INTO variant_values(variant_id,attribute_id,value) VALUES(?,?,?)',[variantId,attribute,value]);
    }
    await audit(t,'UPDATE','variant',variantId,'Edited Size/Color/Design/Quality');
  });

  /// Replace a variant's category-defined values atomically. Names/types belong
  /// to the product category; changing one variant cannot mutate another SKU.
  Future<void> updateVariantValues(int variantId,Map<int,String> values) async => db.transaction((t)async{
    final rows=await t.rawQuery('''SELECT p.category_id FROM variants v JOIN products p ON p.id=v.product_id
      WHERE v.id=? AND v.active=1''',[variantId]);
    if(rows.isEmpty)throw const FormatException('Variation not found');
    final attrs=await t.rawQuery('SELECT id,name,kind,choices FROM attributes WHERE category_id=?',[rows.first['category_id']]);
    final eligible={for(final a in attrs)a['id'] as int:a};
    for(final e in values.entries){
      final a=eligible[e.key];if(a==null)throw const FormatException('Field does not belong to this category');
      final val=e.value.trim();if(val.isEmpty)continue;
      if(a['kind']=='number' && double.tryParse(val)==null)throw FormatException('Invalid numeric value for ${a['name']}');
      if(a['kind']=='choice' && !(a['choices'] as String).split('|').map((x)=>x.trim()).contains(val))throw FormatException('Invalid choice for ${a['name']}');
    }
    await t.rawDelete('DELETE FROM variant_values WHERE variant_id=?',[variantId]);
    for(final e in values.entries){if(e.value.trim().isNotEmpty)await t.rawInsert('INSERT INTO variant_values(variant_id,attribute_id,value) VALUES(?,?,?)',[variantId,e.key,e.value.trim()]);}
    await audit(t,'UPDATE','variant',variantId,'Variation attributes edited');
  });

  Future<int> addParty(String kind,String name,String phone,String address) {if(!{'customer','supplier'}.contains(kind)||name.trim().isEmpty)throw const FormatException('Customer/supplier name required');return db.rawInsert('INSERT INTO parties(kind,name,phone,address) VALUES(?,?,?,?)',[kind,name.trim(),phone.trim(),address.trim()]);}
  Future<void> updateParty(int id,String name,String phone,String address) async {await db.rawUpdate('UPDATE parties SET name=?,phone=?,address=? WHERE id=?',[name,phone,address,id]);}
  Future<void> archive(String table,int id) async {
    if(!{'categories','products','variants','parties','employees','accounts'}.contains(table)) throw ArgumentError('Unsupported archive table');
    await db.rawUpdate('UPDATE $table SET active=0 WHERE id=?',[id]);
  }
  /// User-facing Delete: deactivates catalog and ledger records without destroying
  /// posted accounting history. Prevents hiding outstanding balances or live stock.
  Future<void> deleteManagedRecord(String table,int id) async {
    if(!{'categories','products','variants','parties','accounts'}.contains(table)){
      throw const FormatException('Unsupported record type for deletion');
    }
    await db.transaction((t) async {
      final rows=await t.rawQuery('SELECT id FROM $table WHERE id=? AND active=1',[id]);
      if(rows.isEmpty)throw const FormatException('Record is already deleted or missing');
      if(table=='categories'){
        final children=await t.rawQuery('SELECT 1 FROM products WHERE category_id=? AND active=1 LIMIT 1',[id]);
        if(children.isNotEmpty)throw const FormatException('Delete active products in this category first');
      }
      if(table=='products' || table=='variants'){
        final stock=await t.rawQuery(table=='products'
          ? '''SELECT coalesce(sum(m.qty),0) AS available FROM stock_movements m
              JOIN variants v ON v.id=m.variant_id WHERE v.product_id=?'''
          : 'SELECT coalesce(sum(qty),0) AS available FROM stock_movements WHERE variant_id=?',[id]);
        if(numVal(stock.first['available']).abs()>0.000001){
          throw const FormatException('Stock balance is not zero. Adjust stock before deleting');
        }
      }
      if(table=='parties'){
        final balance=await t.rawQuery('SELECT coalesce(sum(debit-credit),0) AS outstanding FROM party_ledger WHERE party_id=?',[id]);
        if(((balance.first['outstanding'] as num?)?.toInt()??0)!=0){
          throw const FormatException('Customer / supplier has an outstanding ledger balance. Settle it before deleting');
        }
      }
      if(table=='accounts'){
        final account=await t.rawQuery('SELECT code FROM accounts WHERE id=?',[id]);
        final code='${account.first['code']}';
        if(!code.startsWith('GL-') && !code.startsWith('PAY-')){
          throw const FormatException('Built-in accounting control accounts cannot be deleted');
        }
        final balance=await t.rawQuery('SELECT coalesce(sum(debit-credit),0) AS balance FROM journal_lines WHERE account_id=?',[id]);
        if(((balance.first['balance'] as num?)?.toInt()??0)!=0){
          throw const FormatException('Account has a non-zero journal balance. Settle it before deleting');
        }
      }
      await t.rawUpdate('UPDATE $table SET active=0 WHERE id=?',[id]);
      await audit(t,'DELETE',table,id,'Soft deleted, historical records preserved');
    });
  }

  Future<void> deleteExpenseCategory(int id) async {
    await db.transaction((t) async {
      final used=await t.rawQuery('SELECT id FROM expenses WHERE category_id=? LIMIT 1',[id]);
      if(used.isNotEmpty)throw const FormatException('Expense category has transactions and cannot be deleted');
      await t.rawDelete('DELETE FROM expense_categories WHERE id=?',[id]);
      await audit(t,'DELETE','expense_category',id,'Deleted unused expense category');
    });
  }

  Future<List<Map<String,Object?>>> stock() => read('''SELECT v.id, p.name AS product,c.name AS category,v.sku,v.unit,coalesce(sum(m.qty),0) AS qty,
    CASE WHEN EXISTS(SELECT 1 FROM variant_units ts WHERE ts.variant_id=v.id AND ts.unit='table sheet' AND ts.factor=1)
      THEN 'Table Sheets' ELSE v.unit END AS display_unit,
    p.id AS product_id,(SELECT group_concat(a.name||': '||vv.value,', ') FROM variant_values vv JOIN attributes a ON a.id=vv.attribute_id WHERE vv.variant_id=v.id) AS attrs,
    CASE WHEN EXISTS(SELECT 1 FROM variant_units ts WHERE ts.variant_id=v.id AND ts.unit='table sheet' AND ts.factor=1)
      THEN '1 Roll = '||(SELECT CAST(ru.factor AS INTEGER) FROM variant_units ru WHERE ru.variant_id=v.id AND ru.unit='roll')||' Table Sheets'
      ELSE (SELECT u.unit||' of '||CAST(u.factor AS TEXT)||' '||v.unit FROM variant_units u WHERE u.variant_id=v.id AND u.unit IN ('set','packet','roll') LIMIT 1) END AS package
    FROM variants v JOIN products p ON p.id=v.product_id JOIN categories c ON c.id=p.category_id
    LEFT JOIN stock_movements m ON m.variant_id=v.id WHERE v.active=1 AND p.active=1 AND c.active=1 GROUP BY v.id ORDER BY p.name,v.sku''');
  /// A variant has one canonical stock unit (variants.unit).  All purchase/sale
  /// units convert INTO canonical units; a historical invoice snapshots its factor.
  Future<List<Map<String,Object?>>> unitOptions(int variant,{required bool sale}) async {
    final rows=await read('SELECT unit FROM variants WHERE id=? AND active=1',[variant]);
    if(rows.isEmpty)throw const FormatException('Active variation not found');
    final base='${rows.first['unit']}';
    final choices=<Map<String,Object?>>[{'unit':base,'factor':1.0}];
    final more=await read('SELECT unit,factor FROM variant_units WHERE variant_id=? AND ${sale?'can_sell':'can_buy'}=1 ORDER BY unit',[variant]);
    for(final r in more){if('${r['unit']}'.toLowerCase()!=base.toLowerCase())choices.add(r);}
    return choices;
  }
  Future<void> setVariantUnit(int variant,String unit,double factor,{bool canBuy=true,bool canSell=true}) async {
    if(unit.trim().isEmpty||!factor.isFinite||factor<=0||factor>100000000)throw const FormatException('Enter valid unit and positive conversion quantity');
    await db.transaction((t)async{
      final rows=await t.rawQuery('SELECT unit FROM variants WHERE id=? AND active=1',[variant]);
      if(rows.isEmpty)throw const FormatException('Variation not found');
      if('${rows.first['unit']}'.toLowerCase()==unit.trim().toLowerCase())throw const FormatException('Base stock unit is already available automatically at 1:1');
      await t.rawInsert('INSERT INTO variant_units(variant_id,unit,factor,can_buy,can_sell) VALUES(?,?,?,?,?) ON CONFLICT(variant_id,unit) DO UPDATE SET factor=excluded.factor,can_buy=excluded.can_buy,can_sell=excluded.can_sell',[variant,unit.trim(),factor,canBuy?1:0,canSell?1:0]);
      await audit(t,'SET','variant_unit',variant,'${unit.trim()} = $factor ${rows.first['unit']}');
    });
  }
  /// Payment accounts keep their original accounts.id primary key forever.
  /// An empty [code] generates the next unique, human-readable PAY-000001 code.
  /// Nonempty legacy codes remain supported for backwards compatibility.
  Future<int> addPaymentAccount(String code,String name,String kind,{String holderName=''}) async {
    if(!{'cash','bank','wallet'}.contains(kind)||name.trim().isEmpty){
      throw const FormatException('Account name and a valid payment method are required');
    }
    final enteredCode=code.trim();
    return db.transaction((t)async {
      var finalCode=enteredCode;
      if(finalCode.isEmpty){
        final rows=await t.rawQuery('''SELECT COALESCE(MAX(CAST(SUBSTR(code,5) AS INTEGER)),0) AS latest
          FROM accounts WHERE code GLOB 'PAY-[0-9]*' AND LENGTH(code)=10''');
        final highestExisting=(rows.first['latest'] as num?)?.toInt()??0;
        final counterRows=await t.rawQuery("SELECT value FROM app_settings WHERE key='payment_account_sequence'");
        final lastIssued=counterRows.isEmpty?0:(int.tryParse('${counterRows.first['value']}')??0);
        final next=(highestExisting>lastIssued?highestExisting:lastIssued)+1;
        finalCode='PAY-${next.toString().padLeft(6,'0')}';
        await t.rawInsert('''INSERT INTO app_settings(key,value) VALUES('payment_account_sequence',?)
          ON CONFLICT(key) DO UPDATE SET value=excluded.value''',['$next']);
      }
      final id=await t.rawInsert('INSERT INTO accounts(code,name,type,created_at) VALUES(?,?,?,?)',[finalCode,name.trim(),'asset',nowDate()]);
      await t.rawInsert('INSERT INTO payment_accounts(account_id,kind,holder_name) VALUES(?,?,?)',
        [id,kind,holderName.trim()]);
      await audit(t,'ADD','payment_account',id,'$finalCode ${name.trim()} · ${holderName.trim()}');
      return id;
    });
  }
  /// General ledger accounts get their own automatic GL series; system codes
  /// (1000, 1010, etc.) remain unchanged for existing accounting references.
  Future<int> addLedgerAccount(String name,String type) async {
    if(name.trim().isEmpty||!{'asset','liability','equity','revenue','expense'}.contains(type)){
      throw const FormatException('Enter account name and valid account type');
    }
    return db.transaction((t)async {
      final existing=await t.rawQuery("SELECT COALESCE(MAX(CAST(SUBSTR(code,4) AS INTEGER)),0) AS latest FROM accounts WHERE code GLOB 'GL-[0-9]*' AND LENGTH(code)=9");
      final highest=(existing.first['latest'] as num?)?.toInt()??0;
      final counter=await t.rawQuery("SELECT value FROM app_settings WHERE key='ledger_account_sequence'");
      final last=counter.isEmpty?0:(int.tryParse('${counter.first['value']}')??0);
      final next=(highest>last?highest:last)+1;
      final code='GL-${next.toString().padLeft(6,'0')}';
      await t.rawInsert("INSERT INTO app_settings(key,value) VALUES('ledger_account_sequence',?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",['$next']);
      final id=await t.rawInsert('INSERT INTO accounts(code,name,type,created_at) VALUES(?,?,?,?)',
        [code,name.trim(),type,nowDate()]);
      await audit(t,'ADD','account',id,'$code ${name.trim()}');
      return id;
    });
  }
  Future<List<Map<String,Object?>>> paymentAccountRows() => read('''
    SELECT a.id,a.code,a.name,pa.kind,pa.holder_name FROM accounts a
    JOIN payment_accounts pa ON pa.account_id=a.id
    WHERE a.active=1 ORDER BY a.name,a.code''');
  Future<Map<int,String>> paymentAccountOptions() async {
    final rows=await paymentAccountRows();
    return {for(final a in rows)a['id'] as int: paymentAccountLabel(a)};
  }
  Future<void> updatePaymentAccountDetails(int accountId,{required String name,required String holderName}) async {
    if(name.trim().isEmpty)throw const FormatException('Account name is required');
    await db.transaction((t)async {
      final found=await t.rawQuery('''SELECT a.id FROM accounts a
        JOIN payment_accounts p ON p.account_id=a.id WHERE a.id=?''',[accountId]);
      if(found.isEmpty)throw const FormatException('Payment account not found');
      await t.rawUpdate('UPDATE accounts SET name=? WHERE id=?',[name.trim(),accountId]);
      await t.rawUpdate('UPDATE payment_accounts SET holder_name=? WHERE account_id=?',
        [holderName.trim(),accountId]);
      await audit(t,'EDIT','payment_account',accountId,'Payment account name / holder changed');
    });
  }
  Future<void> adjustStock(int variant,double diff,String reason) async {
    if(!diff.isFinite||diff==0||(diff*1000-(diff*1000).round()).abs()>0.00001) throw const FormatException('Adjustment must be nonzero with max 3 decimals');
    await db.transaction((t) async {
      final id=await t.rawInsert('INSERT INTO stock_movements(variant_id,qty,source_type,source_id,date,note) VALUES(?,?,?,?,?,?)',[variant,diff,'ADJUST',0,nowDate(),reason]);
      await t.rawUpdate('UPDATE stock_movements SET source_id=? WHERE id=?',[id,id]);
      await audit(t,'ADJUST','stock',id,reason);
    });
  }
  Future<int> accountCode(Transaction t,String code) async => ((await t.rawQuery('SELECT id FROM accounts WHERE code=?',[code])).first['id'] as int);
  Future<int> addJournal(Transaction t,String source,int sourceId,String date,String note,List<List<int>> items) async {
    final debit=items.fold<int>(0,(s,e)=>s+e[1]);final credit=items.fold<int>(0,(s,e)=>s+e[2]);
    if(debit!=credit) throw StateError('Unbalanced journal: $debit / $credit');
    final id=await t.rawInsert('INSERT INTO journal(date,source_type,source_id,note) VALUES(?,?,?,?)',[date,source,sourceId,note]);
    for(final item in items){if(item[1]!=0||item[2]!=0){await t.rawInsert('INSERT INTO journal_lines(journal_id,account_id,debit,credit) VALUES(?,?,?,?)',[id,...item]);}}
    return id;
  }
  Future<int> postDocument(String kind,int? partyId,String date,List<ItemLine> items,double paid,int paymentAccount,{String notes=''}) async {
    if(!{'sale','purchase'}.contains(kind)) throw const FormatException('Invalid document type');
    if(items.isEmpty) throw const FormatException('Add at least one product');
    if(!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) || DateTime.tryParse(date)==null) throw const FormatException('Enter a valid invoice date (YYYY-MM-DD)');
    if(kind=='purchase' && partyId==null) throw const FormatException('Supplier required');
    for(final x in items){if(x.qty<=0||x.rate<0 || !x.qty.isFinite || !x.rate.isFinite || (x.qty*1000-(x.qty*1000).round()).abs()>0.00001) throw const FormatException('Quantity must be positive with max 3 decimals; price must be non-negative');}
    final total=items.fold<int>(0,(s,e)=>s+pennies(e.qty*e.rate));
    if(!paid.isFinite) throw const FormatException('Invalid payment amount');
    final money=pennies(paid);
    if(money<0||money>total) throw const FormatException('Paid amount cannot exceed total');
    return db.transaction((t)=>_postDocumentTxn(t,kind,partyId,date,items,paid,paymentAccount,notes));
  }
  /// Multiple payment methods are saved atomically with the invoice, party ledger,
  /// stock movements and one balanced journal. Unpaid balance remains on credit.
  Future<int> postDocumentSplit(String kind,int? partyId,String date,
      List<ItemLine> items,List<PaymentPart> payments,{String notes=''}) async {
    if(!{'sale','purchase'}.contains(kind)||items.isEmpty)throw const FormatException('Invalid invoice');
    if(!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)||DateTime.tryParse(date)==null)
      throw const FormatException('Enter a valid date YYYY-MM-DD');
    if(kind=='purchase'&&partyId==null)throw const FormatException('Choose a supplier');
    if(payments.any((p)=>!p.amount.isFinite || p.amount<=0))
      throw const FormatException('Payment portions must be positive');
    final total=items.fold<int>(0,(a,b)=>a+pennies(b.qty*b.rate));
    final paid=payments.fold<int>(0,(a,b)=>a+pennies(b.amount));
    if(paid>total)throw const FormatException('Total payments cannot exceed invoice total');
    if(kind=='sale' && partyId==null && paid!=total)
      throw const FormatException('Select a customer for any unpaid balance');
    return db.transaction((t)=>_postDocumentTxn(t,kind,partyId,date,items,
      paid/100,payments.isEmpty?0:payments.first.accountId,notes,payments:payments));
  }

  /// Atomic invoice numbering. Values are editable by an administrator in Settings.
  /// Separate counters are maintained for sales and purchases.
  Future<String> _reserveInvoiceNumber(Transaction t,String kind) async {
    final prefixKey='invoice_prefix_$kind';
    final nextKey='invoice_next_$kind';
    final prefixRows=await t.rawQuery('SELECT value FROM app_settings WHERE key=?',[prefixKey]);
    final nextRows=await t.rawQuery('SELECT value FROM app_settings WHERE key=?',[nextKey]);
    final prefix=prefixRows.isEmpty?(kind=='sale'?'SAL':'PUR'):'${prefixRows.first['value']}';
    var next=int.tryParse(nextRows.isEmpty?'1':'${nextRows.first['value']}')??1;
    if(next<1)throw const FormatException('Invoice serial must be positive');
    String invoice;
    do {
      invoice='$prefix-${next.toString().padLeft(6,'0')}';
      next++;
    } while((await t.rawQuery('SELECT 1 FROM documents WHERE invoice=? LIMIT 1',[invoice])).isNotEmpty);
    await t.rawInsert('INSERT OR REPLACE INTO app_settings(key,value) VALUES(?,?)',[nextKey,'$next']);
    return invoice;
  }
  Future<int> _postDocumentTxn(Transaction t,String kind,int? partyId,String date,List<ItemLine> items,double paid,int paymentAccount,String notes,{int? existingId,String? existingInvoice,List<PaymentPart>? payments}) async {
    // Preconditions rechecked inside correction transactions as well.
    if(!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)||DateTime.tryParse(date)==null)throw const FormatException('Invalid invoice date');
    if(!{'sale','purchase'}.contains(kind)||items.isEmpty)throw const FormatException('Invalid bill or empty items');
    if(kind=='purchase'&&partyId==null)throw const FormatException('Supplier required');
    if(items.any((x)=>!x.qty.isFinite||!x.rate.isFinite||!x.factor.isFinite||x.factor<=0||x.qty<=0||x.rate<0||(x.qty*1000-(x.qty*1000).round()).abs()>0.00001))throw const FormatException('Invalid quantity, unit factor or price');
    final checkedTotal=items.fold<int>(0,(a,b)=>a+pennies(b.qty*b.rate));
    final total=checkedTotal; // Invoice total in paisa, computed inside the transaction.
    if(!paid.isFinite) throw const FormatException('Invalid amount paid');
    final portions=payments??(pennies(paid)>0 ? [PaymentPart(paymentAccount,paid)] : <PaymentPart>[]);
    if(portions.any((part)=>!part.amount.isFinite || part.amount<=0))
      throw const FormatException('Enter positive payments only');
    final money=portions.fold<int>(0,(sum,part)=>sum+pennies(part.amount));
    if(money<0||money>total)throw const FormatException('Total payment exceeds invoice amount');
    for(final part in portions){
      final available=await t.rawQuery('SELECT a.id FROM accounts a JOIN payment_accounts pa ON pa.account_id=a.id WHERE a.id=? AND a.active=1',[part.accountId]);
      if(available.isEmpty)throw FormatException('Invalid payment account: ${part.accountId}');
    }
    {
      if(partyId!=null){final p=await t.rawQuery('SELECT kind FROM parties WHERE id=? AND active=1',[partyId]);if(p.isEmpty||p.first['kind']!=(kind=='sale'?'customer':'supplier'))throw const FormatException('Invalid customer/supplier');}
      for(final x in items){
        final eligible=await t.rawQuery('''SELECT v.id,v.unit FROM variants v JOIN products p ON p.id=v.product_id
            JOIN categories c ON c.id=p.category_id WHERE v.id=? AND v.active=1 AND p.active=1 AND c.active=1''',[x.variantId]);
        if(eligible.isEmpty)throw const FormatException('Product variation is archived or missing');
        final stockUnit='${eligible.first['unit']}';
        // Loose Pieces cannot be sold or purchased in fractions.
        if(stockUnit.toLowerCase()=='pcs' && (x.qty*x.factor-(x.qty*x.factor).round()).abs()>0.000001) {
          throw const FormatException('Pieces must be whole numbers. Choose a valid quantity.');
        }
        final selectedUnit=(x.unit??stockUnit).trim();
        if(selectedUnit.toLowerCase()!=stockUnit.toLowerCase()){
          final conversion=await t.rawQuery('SELECT factor,can_buy,can_sell FROM variant_units WHERE variant_id=? AND unit=?',[x.variantId,selectedUnit]);
          if(conversion.isEmpty || ((kind=='sale'?conversion.first['can_sell']:conversion.first['can_buy']) as int)!=1)throw FormatException('Unit $selectedUnit is not allowed for ${kind=='sale'?'sale':'purchase'}');
          // Purchase pack lengths may vary; POS stores an explicit positive factor.
          if(kind=='sale' && (numVal(conversion.first['factor'])-x.factor).abs()>0.000001)throw const FormatException('Sale unit factor changed; reselect the unit');
        }else if((x.factor-1).abs()>0.000001)throw const FormatException('Base unit must use 1:1 conversion');
        if(!((x.qty*x.factor).isFinite)||(x.qty*x.factor*1000000-(x.qty*x.factor*1000000).round()).abs()>0.00001)throw const FormatException('Converted stock quantity exceeds allowed precision');
      }
      final ref=existingInvoice??await _reserveInvoiceNumber(t,kind);
      final int id;
      if(existingId!=null){
        id=existingId;
        await t.rawUpdate('UPDATE document_payment_parts SET active=0 WHERE document_id=?',[id]);
        await t.rawUpdate("UPDATE documents SET kind=?,invoice=?,party_id=?,date=?,total=?,paid=?,notes=?,status='POSTED' WHERE id=?",[kind,ref,partyId,date,total,money,notes,id]);
        // Preserve old invoice lines with linked return history (including voided
        // returns) for foreign-key integrity. Archived rows are hidden everywhere
        // except historical return details and audit/revision records.
        await t.rawUpdate('UPDATE document_lines SET is_current=0 WHERE document_id=?',[id]);
        await t.rawDelete('''DELETE FROM document_line_units WHERE line_id IN (
          SELECT id FROM document_lines WHERE document_id=?
            AND id NOT IN (SELECT source_line_id FROM return_lines))''',[id]);
        await t.rawDelete('''DELETE FROM document_lines WHERE document_id=?
          AND id NOT IN (SELECT source_line_id FROM return_lines)''',[id]);
      }else{
        id=await t.rawInsert('INSERT INTO documents(kind,invoice,party_id,date,total,paid,notes) VALUES(?,?,?,?,?,?,?)',[kind,ref,partyId,date,total,money,notes]);
      }
      for(final part in portions){
        await t.rawInsert('INSERT INTO document_payment_parts(document_id,account_id,amount) VALUES(?,?,?)',[id,part.accountId,pennies(part.amount)]);
      }
      for(final x in items){final amount=pennies(x.qty*x.rate);
        final lineId=await t.rawInsert('INSERT INTO document_lines(document_id,variant_id,qty,rate,amount) VALUES(?,?,?,?,?)',[id,x.variantId,x.qty,pennies(x.rate),amount]);
        final baseUnit=await t.rawQuery('SELECT unit FROM variants WHERE id=?',[x.variantId]);
        await t.rawInsert('INSERT INTO document_line_units(line_id,unit,factor) VALUES(?,?,?)',[lineId,x.unit??baseUnit.first['unit'],x.factor]);
        await t.rawInsert('INSERT INTO stock_movements(variant_id,qty,source_type,source_id,date,note) VALUES(?,?,?,?,?,?)',[x.variantId,x.qty*x.factor*(kind=='sale'?-1:1),kind,id,date,ref]);
      }
      final outstanding=total-money;
      if(partyId!=null){
        if(kind=='sale'){
          await t.rawInsert('INSERT INTO party_ledger(party_id,debit,credit,source_type,source_id,date,note) VALUES(?,?,?,?,?,?,?)',[partyId,total,0,'sale',id,date,ref]);
          for(final part in portions){await t.rawInsert('INSERT INTO party_ledger(party_id,debit,credit,source_type,source_id,date,note,payment_account_id) VALUES(?,?,?,?,?,?,?,?)',[partyId,0,pennies(part.amount),'sale_payment',id,date,ref,part.accountId]);}
        }else{
          await t.rawInsert('INSERT INTO party_ledger(party_id,debit,credit,source_type,source_id,date,note) VALUES(?,?,?,?,?,?,?)',[partyId,0,total,'purchase',id,date,ref]);
          for(final part in portions){await t.rawInsert('INSERT INTO party_ledger(party_id,debit,credit,source_type,source_id,date,note,payment_account_id) VALUES(?,?,?,?,?,?,?,?)',[partyId,pennies(part.amount),0,'purchase_payment',id,date,ref,part.accountId]);}
        }
      }else if(outstanding>0){throw const FormatException('Credit sale requires customer');}
      final ar=await accountCode(t,'1100');final ap=await accountCode(t,'2000');final inv=await accountCode(t,'1200');final rev=await accountCode(t,'4000');
      final cashLines=portions.map((p)=>[
        p.accountId, kind=='sale'?pennies(p.amount):0, kind=='purchase'?pennies(p.amount):0
      ]).toList();
      if(kind=='sale'){
        await addJournal(t,kind,id,date,ref,[...cashLines,[ar,outstanding,0],[rev,0,total]]);
      }else{
        await addJournal(t,kind,id,date,ref,[[inv,total,0],...cashLines,[ap,0,outstanding]]);
      }
      await audit(t,'POST',kind,id,ref);
      return id;
    }
  }
  /// Invoice cancellation keeps customer/supplier receipts as unapplied credit.
  /// Linked active returns must first be cancelled to avoid an invalid reversal.
  /// All changes occur in one SQLite transaction, including stock + journals.
  Future<void> cancelInvoiceSafely(int id) async => db.transaction((t)async {
    final existing=await t.rawQuery("SELECT * FROM documents WHERE id=? AND status='POSTED'",[id]);
    if(existing.isEmpty)throw const FormatException('Invoice already cancelled or not found');
    final returns=await t.rawQuery("SELECT id FROM document_returns WHERE document_id=? AND status='POSTED' LIMIT 1",[id]);
    if(returns.isNotEmpty)throw const FormatException('This invoice has an active return. Cancel the linked return first, then delete this invoice.');
    final allocations=await t.rawQuery('SELECT receipt_id,amount FROM receipt_allocations WHERE document_id=?',[id]);
    if(allocations.isNotEmpty){
      final totalAllocated=allocations.fold<int>(0,(n,r)=>n+(r['amount'] as int));
      // Release allocations without deleting real-world payments; retain them as unapplied credit.
      await t.rawDelete('DELETE FROM receipt_allocations WHERE document_id=?',[id]);
      await t.rawUpdate('UPDATE documents SET paid=paid-? WHERE id=?',[totalAllocated,id]);
      await audit(t,'UNALLOCATE','invoice',id,'Released $totalAllocated paisa into unapplied customer/supplier credit');
    }
    await _voidDocumentTxn(t,id);
  });
  Future<void> voidDocument(int id) async => db.transaction((t)=>_voidDocumentTxn(t,id));
  Future<void> _voidDocumentTxn(Transaction t,int id,{String? reversalDate}) async {
    final ds=await t.rawQuery("SELECT * FROM documents WHERE id=? AND status='POSTED'",[id]);
    if(ds.isEmpty)throw const FormatException('Active invoice not found');
    final allocated=await t.rawQuery('SELECT 1 FROM receipt_allocations WHERE document_id=? LIMIT 1',[id]);
    if(allocated.isNotEmpty)throw const FormatException('Reverse allocated receipts before correcting/voiding this invoice');
    final attached=await t.rawQuery("SELECT id FROM document_returns WHERE document_id=? AND status='POSTED' LIMIT 1",[id]);
    if(attached.isNotEmpty)throw const FormatException('Void or reverse linked returns first');
    final d=ds.first;final kind=d['kind'] as String;final date=reversalDate??nowDate();
    await t.rawUpdate("UPDATE documents SET status='VOID' WHERE id=?",[id]);
    final lines=await t.rawQuery('SELECT l.*,coalesce(u.factor,1) AS stock_factor FROM document_lines l LEFT JOIN document_line_units u ON u.line_id=l.id WHERE l.document_id=? AND l.is_current=1',[id]);
    for(final x in lines){await t.rawInsert('INSERT INTO stock_movements(variant_id,qty,source_type,source_id,date,note) VALUES(?,?,?,?,?,?)',[x['variant_id'],numVal(x['qty'])*numVal(x['stock_factor'])*(kind=='sale'?1:-1),'void_$kind',id,date,'Void invoice']);}
    final ledger=await t.rawQuery("SELECT * FROM party_ledger WHERE source_id=? AND source_type IN ('sale','purchase','sale_payment','purchase_payment')",[id]);
    for(final l in ledger){await t.rawInsert('INSERT INTO party_ledger(party_id,debit,credit,source_type,source_id,date,note,payment_account_id) VALUES(?,?,?,?,?,?,?,?)',[l['party_id'],l['credit'],l['debit'],'void_$kind',id,date,'Reversal',l['payment_account_id']]);}
    final journals=await t.rawQuery('SELECT id FROM journal WHERE source_type=? AND source_id=?',[kind,id]);
    for(final j in journals){final jl=await t.rawQuery('SELECT account_id,debit,credit FROM journal_lines WHERE journal_id=?',[j['id']]);
      await addJournal(t,'void_$kind',id,date,'Reversal',jl.map((x)=>[x['account_id'] as int,x['credit'] as int,x['debit'] as int]).toList());}
    await t.rawUpdate('UPDATE document_payment_parts SET active=0 WHERE document_id=?',[id]);
    await audit(t,'VOID',kind,id);
   }
  /// Corrects the SAME invoice ID/number, not a replacement row.
  /// Original ledgers/journals stay as audited reversals; prior versions are
  /// tagged 'superseded_*' to prevent a future void reversing them twice.
  Future<int> reviseDocument(int oldId,String kind,int? partyId,String date,List<ItemLine> items,double paid,int paymentAccount,{String notes=''}) async => db.transaction((t)async{
    final originals=await t.rawQuery("SELECT * FROM documents WHERE id=? AND status='POSTED'",[oldId]);
    if(originals.isEmpty||originals.first['kind']!=kind)throw const FormatException('Posted invoice not found');
    final splitRows=await t.rawQuery('SELECT account_id,amount FROM document_payment_parts WHERE document_id=? AND active=1 ORDER BY id',[oldId]);
    final original=originals.first;
    final installments=await t.rawQuery('SELECT receipt_id,amount FROM receipt_allocations WHERE document_id=?',[oldId]);
    final originalInitial=splitRows.fold<int>(0,(n,r)=>n+(r['amount'] as int));
    final allocated=installments.fold<int>(0,(n,r)=>n+(r['amount'] as int));
    if(pennies(paid)!=originalInitial+allocated)throw const FormatException(
      'Correct the invoice items and prices here. To change payment amounts, use installment/payment history instead.');
    final preservedPayments=splitRows.map((r)=>PaymentPart(r['account_id'] as int,(r['amount'] as int)/100)).toList();
    final oldLines=await t.rawQuery('SELECT l.variant_id,l.qty,l.rate,l.amount,coalesce(u.unit,v.unit) AS unit,coalesce(u.factor,1) AS factor FROM document_lines l JOIN variants v ON v.id=l.variant_id LEFT JOIN document_line_units u ON u.line_id=l.id WHERE l.document_id=? AND l.is_current=1 ORDER BY l.id',[oldId]);
    // Active returns depend on currently posted invoice lines; cancel them first.
    final activeReturns=await t.rawQuery("SELECT 1 FROM document_returns WHERE document_id=? AND status='POSTED' LIMIT 1",[oldId]);
    if(activeReturns.isNotEmpty)throw const FormatException('Cancel linked sale/purchase returns before correcting this invoice.');
    // Historical return links are retained on archived invoice lines.
    await t.rawInsert('''INSERT INTO document_revisions(document_id,changed_at,old_invoice,old_date,old_party_id,old_total,old_paid,old_notes,old_lines_json)
      VALUES(?,?,?,?,?,?,?,?,?)''',[oldId,nowStamp(),original['invoice'],original['date'],original['party_id'],original['total'],original['paid'],original['notes'],jsonEncode(oldLines)]);
    // Keep actual incoming/outgoing receipts in their bank/wallet ledgers.
    // Only their invoice allocation is detached during correction, then re-applied.
    await t.rawDelete('DELETE FROM receipt_allocations WHERE document_id=?',[oldId]);
    if(allocated>0)await t.rawUpdate('UPDATE documents SET paid=paid-? WHERE id=?',[allocated,oldId]);
    await _voidDocumentTxn(t,oldId,reversalDate:original['date'] as String);
    // Mark the old version's entries so subsequent corrections/voids only
    // reverse the currently posted version.
    for(final source in ['sale','purchase','sale_payment','purchase_payment']){
      await t.rawUpdate('UPDATE party_ledger SET source_type=? WHERE source_id=? AND source_type=?',
        ['superseded_$source',oldId,source]);
    }
    await t.rawUpdate('UPDATE journal SET source_type=? WHERE source_id=? AND source_type=?',
      ['superseded_$kind',oldId,kind]);
    final updated=await _postDocumentTxn(t,kind,partyId,date,items,originalInitial/100,paymentAccount,notes,
      existingId:oldId,existingInvoice:original['invoice'] as String,payments:preservedPayments);
    final updatedTotal=(await t.rawQuery('SELECT total FROM documents WHERE id=?',[oldId])).first['total'] as int;
    var available=(updatedTotal-originalInitial).clamp(0,updatedTotal);
    for(final r in installments){
      final portion=(r['amount'] as int)<available?(r['amount'] as int):available;
      if(portion>0){
        await t.rawInsert('INSERT INTO receipt_allocations(receipt_id,document_id,amount) VALUES(?,?,?)',[r['receipt_id'],oldId,portion]);
        await t.rawUpdate('UPDATE documents SET paid=paid+? WHERE id=?',[portion,oldId]);
        available-=portion;
      }
    }
    await audit(t,'REVISE',kind,oldId,'Updated invoice ${original['invoice']} in place');
    return updated;
  });
  Future<void> recordPayment(int partyId,double amount,int accountId,String note) async {
    final p=pennies(amount);if(!amount.isFinite || p<=0)throw const FormatException('Amount must be positive');
    await db.transaction((t)async{
      final parties=await t.rawQuery('SELECT * FROM parties WHERE id=?',[partyId]);if(parties.isEmpty) throw const FormatException('Party not found');
      final kind=parties.first['kind'];final id=await t.rawInsert('INSERT INTO receipts(party_id,date,amount,account_id,note) VALUES(?,?,?,?,?)',[partyId,nowDate(),p,accountId,note]);
      // Apply receipt to oldest outstanding invoices for this customer/supplier.
      // Any excess remains an unallocated account credit.
      var remaining=p;
      final openInvoices=await t.rawQuery("SELECT id,total,paid FROM documents WHERE party_id=? AND kind=? AND status='POSTED' AND total>paid ORDER BY date,id",[partyId,kind=='customer'?'sale':'purchase']);
      for(final invoice in openInvoices){
        if(remaining<=0)break;
        final due=(invoice['total'] as int)-(invoice['paid'] as int);
        final portion=due<remaining?due:remaining;
        if(portion<=0)continue;
        await t.rawInsert('INSERT INTO receipt_allocations(receipt_id,document_id,amount) VALUES(?,?,?)',[id,invoice['id'],portion]);
        await t.rawUpdate('UPDATE documents SET paid=paid+? WHERE id=?',[portion,invoice['id']]);
        remaining-=portion;
      }
      await t.rawInsert('INSERT INTO party_ledger(party_id,debit,credit,source_type,source_id,date,note,payment_account_id) VALUES(?,?,?,?,?,?,?,?)',[partyId,kind=='supplier'?p:0,kind=='customer'?p:0,'receipt',id,nowDate(),note,accountId]);
      final offset=await accountCode(t,kind=='customer'?'1100':'2000');
      await addJournal(t,'receipt',id,nowDate(),note,kind=='customer'?[[accountId,p,0],[offset,0,p]]:[[offset,p,0],[accountId,0,p]]);
      await audit(t,'POST','receipt',id);
    });
  }
  /// Allocate a later installment to the SELECTED invoice, not the oldest
  /// customer/supplier invoice. Each installment can use a different account.
  Future<int> recordInvoiceInstallment(int documentId,double amount,int accountId,
      String note,{String? paymentDate}) async {
    if(!amount.isFinite || pennies(amount)<=0)
      throw const FormatException('Payment must be positive');
    final day=paymentDate??nowDate();
    if(!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)||
      DateTime.tryParse(day)==null ||
      DateTime.tryParse(day)!.toIso8601String().substring(0,10)!=day)
        throw const FormatException('Payment date must be YYYY-MM-DD');
    final amountPaisa=pennies(amount);
    return db.transaction((t) async {
      final docs=await t.rawQuery(
        "SELECT id,kind,party_id,total,paid FROM documents WHERE id=? AND status='POSTED'",[documentId]);
      if(docs.isEmpty)throw const FormatException('Active invoice not found');
      final d=docs.first;
      final due=(d['total'] as int)-(d['paid'] as int);
      if(amountPaisa>due)throw FormatException('Payment cannot exceed invoice balance: Rs. ${rupees(due).toStringAsFixed(2)}');
      final partyId=d['party_id'] as int?;
      if(partyId==null)throw const FormatException('Walk-in invoices cannot have unpaid balances');
      final account=await t.rawQuery('SELECT a.id FROM accounts a JOIN payment_accounts p ON p.account_id=a.id WHERE a.id=? AND a.active=1',[accountId]);
      if(account.isEmpty)throw const FormatException('Select a valid Cash, Bank or Wallet');
      final kind='${d['kind']}';
      final receipt=await t.rawInsert('INSERT INTO receipts(party_id,date,amount,account_id,note) VALUES(?,?,?,?,?)',[partyId,day,amountPaisa,accountId,note]);
      await t.rawInsert('INSERT INTO receipt_allocations(receipt_id,document_id,amount) VALUES(?,?,?)',[receipt,documentId,amountPaisa]);
      await t.rawUpdate('UPDATE documents SET paid=paid+? WHERE id=?',[amountPaisa,documentId]);
      await t.rawInsert('INSERT INTO party_ledger(party_id,debit,credit,source_type,source_id,date,note,payment_account_id) VALUES(?,?,?,?,?,?,?,?)',[partyId,kind=='purchase'?amountPaisa:0,
        kind=='sale'?amountPaisa:0,'receipt',receipt,day,note,accountId]);
      final offset=await accountCode(t,kind=='sale'?'1100':'2000');
      await addJournal(t,'receipt',receipt,day,note,kind=='sale'
        ? [[accountId,amountPaisa,0],[offset,0,amountPaisa]]
        : [[offset,amountPaisa,0],[accountId,0,amountPaisa]]);
      await audit(t,'POST','invoice_installment',receipt,
          'Invoice $documentId paid through account $accountId');
      return receipt;
    });
  }

  Future<void> addExpense(int category,double amount,int account,String description,String date) async {
    final p=pennies(amount);if(!amount.isFinite || p<=0)throw const FormatException('Expense must be positive');
    await db.transaction((t)async{
      final id=await t.rawInsert('INSERT INTO expenses(category_id,date,amount,account_id,description) VALUES(?,?,?,?,?)',[category,date,p,account,description]);
      final expense=await accountCode(t,'6100');await addJournal(t,'expense',id,date,description,[[expense,p,0],[account,0,p]]);
      await audit(t,'POST','expense',id);
    });
  }
  Future<int> addEmployee(String name,String designation,double salary) {if(name.trim().isEmpty||!salary.isFinite||salary<0)throw const FormatException('Enter employee name and a non-negative salary');return db.rawInsert('INSERT INTO employees(name,designation,salary) VALUES(?,?,?)',[name.trim(),designation,pennies(salary)]);}
  Future<void> employeeAdvance(int employee,double amount,int cashAccount) async {
    final p=pennies(amount);if(!amount.isFinite || p<=0)throw const FormatException('Positive advance required');
    await db.transaction((t)async{
      final id=await t.rawInsert('INSERT INTO employee_ledger(employee_id,date,kind,amount,source_type,source_id,note) VALUES(?,?,?,?,?,?,?)',[employee,nowDate(),'ADVANCE',p,'advance',0,'Advance paid']);
      await t.rawUpdate('UPDATE employee_ledger SET source_id=? WHERE id=?',[id,id]);
      await addJournal(t,'advance',id,nowDate(),'Employee advance',[[await accountCode(t,'1300'),p,0],[cashAccount,0,p]]);
      await audit(t,'POST','employee_advance',id);
    });
  }
  Future<int> payrollRun(int employee,String period,double recovery,double payNow,int cashAccount,{String? salaryDate}) async => db.transaction((t)async{
    final effectiveDate=salaryDate??nowDate();
    if(!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(effectiveDate)||
        DateTime.tryParse(effectiveDate)==null ||
        DateTime.tryParse(effectiveDate)!.toIso8601String().substring(0,10)!=effectiveDate)
      throw const FormatException('Enter a valid payroll date YYYY-MM-DD');
    final rows=await t.rawQuery('SELECT salary FROM employees WHERE id=? AND active=1',[employee]);if(rows.isEmpty)throw const FormatException('Employee not found');
    if(!recovery.isFinite||!payNow.isFinite) {
      throw const FormatException('Recovery and payment amounts must be valid numbers');
    }
    if(!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(period)) {
      throw const FormatException('Choose a valid payroll period in YYYY-MM format');
    }
    final previous=await t.rawQuery('SELECT id FROM payroll WHERE employee_id=? AND period=? LIMIT 1',[employee,period]);
    if(previous.isNotEmpty) {
      throw FormatException('Payroll has already been processed for $period. Use a different period; do not pay the same month twice.');
    }
    final gross=(rows.first['salary'] as num).toInt();
    final rec=pennies(recovery),pay=pennies(payNow);
    final adv=await t.rawQuery("SELECT coalesce(sum(CASE WHEN kind='ADVANCE' THEN amount WHEN kind='RECOVERY' THEN -amount ELSE 0 END),0) AS bal FROM employee_ledger WHERE employee_id=?",[employee]);
    final quote=PayrollQuote(gross,(adv.first['bal'] as num).toInt());
    final net=quote.netPayable(rec);
    quote.salaryDue(rec,pay); // Validates Pay Now against net salary, not gross salary.
    final id=await t.rawInsert('INSERT INTO payroll(employee_id,period,gross,recovery,net,paid,date) VALUES(?,?,?,?,?,?,?)',[employee,period,gross,rec,net,pay,effectiveDate]);
    for(final e in <List<Object>>[['SALARY_DUE',gross],['RECOVERY',rec],['SALARY_PAID',pay]]){
      if((e[1] as int)>0)await t.rawInsert('INSERT INTO employee_ledger(employee_id,date,kind,amount,source_type,source_id,note) VALUES(?,?,?,?,?,?,?)',[employee,effectiveDate,e[0],e[1],'payroll',id,period]);
    }
    await addJournal(t,'payroll',id,effectiveDate,period,[[await accountCode(t,'6200'),gross,0],[await accountCode(t,'1300'),0,rec],[cashAccount,0,pay],[await accountCode(t,'2100'),0,net-pay]]);
    await audit(t,'POST','payroll',id);
    return id;
  });
  Future<void> transfer(int from,int to,double amount,String note) async {
    final p=pennies(amount);if(!amount.isFinite || from==to||p<=0)throw const FormatException('Select different accounts and positive amount');
    await db.transaction((t)async{
      final id=await addJournal(t,'transfer',DateTime.now().microsecondsSinceEpoch,nowDate(),note,[[to,p,0],[from,0,p]]);
      await audit(t,'POST','transfer',id,note);
    });
  }
  Future<void> backup(String destination) async {
    if(File(destination).existsSync()) throw const FileSystemException('Choose a new backup filename');
    final escaped=destination.replaceAll("'","''");
    await db.execute("VACUUM INTO '$escaped'");
  }
}
