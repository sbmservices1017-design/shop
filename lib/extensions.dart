// ShopDesk transaction extensions. All stock, party ledger and account postings
// are committed together in one SQLite transaction. Nothing is hard-deleted.
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'store.dart';

class ReturnItem {
  final int sourceLineId;
  final double quantity;
  const ReturnItem(this.sourceLineId, this.quantity);
}

Future<void> ensureExtendedSchema(Store s) async {
  for (final sql in <String>[
    '''CREATE TABLE IF NOT EXISTS document_returns(id INTEGER PRIMARY KEY,document_id INTEGER NOT NULL REFERENCES documents(id),date TEXT NOT NULL,amount INTEGER NOT NULL,refunded INTEGER NOT NULL,account_id INTEGER NOT NULL REFERENCES accounts(id),reason TEXT NOT NULL DEFAULT '',status TEXT NOT NULL DEFAULT 'POSTED' CHECK(status IN ('POSTED','VOID')))''',
    '''CREATE TABLE IF NOT EXISTS return_lines(id INTEGER PRIMARY KEY,return_id INTEGER NOT NULL REFERENCES document_returns(id),source_line_id INTEGER NOT NULL REFERENCES document_lines(id),variant_id INTEGER NOT NULL REFERENCES variants(id),qty REAL NOT NULL CHECK(qty>0),amount INTEGER NOT NULL)''',
    '''CREATE TABLE IF NOT EXISTS reversed_transactions(id INTEGER PRIMARY KEY,kind TEXT NOT NULL,source_id INTEGER NOT NULL,date TEXT NOT NULL,note TEXT NOT NULL DEFAULT '',UNIQUE(kind,source_id))''',
    '''CREATE INDEX IF NOT EXISTS ix_returns_invoice ON document_returns(document_id,status)''',
    '''CREATE INDEX IF NOT EXISTS ix_returns_lines ON return_lines(source_line_id)''',
    '''CREATE INDEX IF NOT EXISTS ix_reversed_source ON reversed_transactions(kind,source_id)'''
  ]) { await s.db.execute(sql); }
}

extension ShopDeskExtendedOperations on Store {
  /// Read-only database consistency checks; safe to run before taking backups.
  /// This does not replace Windows acceptance testing or a restore drill.
  Future<List<String>> verifyDatabase() async {
    final issues=<String>[];
    final integrity=await read('PRAGMA integrity_check');
    if(integrity.isEmpty || integrity.any((row)=>row.values.first != 'ok')){
      issues.add('SQLite integrity_check reported a problem: $integrity');
    }
    final fk=await read('PRAGMA foreign_key_check');
    if(fk.isNotEmpty)issues.add('Foreign-key violations: ${fk.length}');
    final badJournals=await read('''SELECT j.id AS id,sum(l.debit-l.credit) AS balance FROM journal j
      JOIN journal_lines l ON l.journal_id=j.id GROUP BY j.id HAVING balance<>0''');
    if(badJournals.isNotEmpty)issues.add('Unbalanced journal entries: ${badJournals.length}');
    final badReturns=await read('''SELECT dl.id AS id,dl.qty AS sold,coalesce(sum(rl.qty),0) AS returned
      FROM document_lines dl JOIN return_lines rl ON rl.source_line_id=dl.id
      JOIN document_returns dr ON dr.id=rl.return_id AND dr.status='POSTED'
      GROUP BY dl.id HAVING returned>sold+0.000001''');
    if(badReturns.isNotEmpty)issues.add('Excess returned quantities: ${badReturns.length}');
    return issues;
  }
  Future<void> _reverseJournal(Transaction t,String source,int id,String reason) async {
    final entries=await t.rawQuery('SELECT id FROM journal WHERE source_type=? AND source_id=?',[source,id]);
    for(final j in entries){
      final lines=await t.rawQuery('SELECT account_id,debit,credit FROM journal_lines WHERE journal_id=?',[j['id']]);
      await addJournal(t,'void_$source',id,nowDate(),reason,lines.map((l)=>[
        l['account_id'] as int,l['credit'] as int,l['debit'] as int
      ]).toList());
    }
  }

  /// Return against a specific invoice LINE, not just SKU; prevents refunding
  /// against a different rate or returning more than originally sold/bought.
  Future<int> postReturn(int documentId,List<ReturnItem> lines,double refund,int account,String reason) async {
    if(lines.isEmpty)throw const FormatException('Select at least one returned item');
    final paid=pennies(refund);
    if(!refund.isFinite || paid<0)throw const FormatException('Invalid refund amount');
    return db.transaction((t)async{
      final ds=await t.rawQuery("SELECT * FROM documents WHERE id=? AND status='POSTED'",[documentId]);
      if(ds.isEmpty)throw const FormatException('Original invoice must be posted');
      final doc=ds.first;final kind=doc['kind'] as String;final party=doc['party_id'] as int?;
      final matching=await t.rawQuery('SELECT id FROM accounts WHERE id=? AND code IN (\'1000\',\'1010\')',[account]);
      if(matching.isEmpty)throw const FormatException('Choose cash or bank account');
      final sourceRows=await t.rawQuery('SELECT * FROM document_lines WHERE document_id=?',[documentId]);
      final source={for(final x in sourceRows)x['id'] as int:x};
      final selected=<int,double>{};
      for(final line in lines){
        if(!line.quantity.isFinite||line.quantity<=0||!source.containsKey(line.sourceLineId)) throw const FormatException('Invalid return quantity / invoice line');
        selected.update(line.sourceLineId,(q)=>q+line.quantity,ifAbsent:()=>line.quantity);
      }
      int total=0;
      for(final e in selected.entries){
        final l=source[e.key]!;
        final returned=await t.rawQuery('''SELECT coalesce(sum(rl.qty),0) AS qty FROM return_lines rl
          JOIN document_returns r ON r.id=rl.return_id WHERE rl.source_line_id=? AND r.status='POSTED' ''',[e.key]);
        final remaining=numVal(l['qty'])-numVal(returned.first['qty']);
        if(e.value>remaining+0.000001) throw FormatException('Return quantity exceeds remaining for line ${e.key}');
        total+=((l['rate'] as int)*e.value).round();
      }
      if(paid>total)throw const FormatException('Refund cannot exceed value of returned items');
      if(party==null && paid!=total)throw const FormatException('Walk-in customer refund must equal the return value');
      final date=nowDate();
      final id=await t.rawInsert('INSERT INTO document_returns(document_id,date,amount,refunded,account_id,reason) VALUES(?,?,?,?,?,?)',[documentId,date,total,paid,account,reason]);
      for(final e in selected.entries){
        final l=source[e.key]!;
        await t.rawInsert('INSERT INTO return_lines(return_id,source_line_id,variant_id,qty,amount) VALUES(?,?,?,?,?)',
          [id,e.key,l['variant_id'],e.value,((l['rate'] as int)*e.value).round()]);
        final unitFactors=await t.rawQuery('SELECT factor FROM document_line_units WHERE line_id=?',[e.key]);
        final factor=unitFactors.isEmpty?1.0:numVal(unitFactors.first['factor']);
        await t.rawInsert('INSERT INTO stock_movements(variant_id,qty,source_type,source_id,date,note) VALUES(?,?,?,?,?,?)',
          [l['variant_id'],e.value*factor*(kind=='sale'?1:-1),'${kind}_return',id,date,reason]);
      }
      if(party!=null){
        await t.rawInsert('INSERT INTO party_ledger(party_id,debit,credit,source_type,source_id,date,note) VALUES(?,?,?,?,?,?,?)',
          [party,kind=='purchase'?total:0,kind=='sale'?total:0,'${kind}_return',id,date,reason]);
        if(paid>0)await t.rawInsert('INSERT INTO party_ledger(party_id,debit,credit,source_type,source_id,date,note,payment_account_id) VALUES(?,?,?,?,?,?,?,?)',
          [party,kind=='sale'?paid:0,kind=='purchase'?paid:0,'${kind}_return_refund',id,date,reason,account]);
      }
      final receivable=await accountCode(t,'1100');
      final payable=await accountCode(t,'2000');
      final revenue=await accountCode(t,'4000');
      final inventory=await accountCode(t,'1200');
      final journal=<List<int>>[];
      if(kind=='sale'){
        journal.addAll([[revenue,total,0],[receivable,0,total]]);
        if(paid>0)journal.addAll([[receivable,paid,0],[account,0,paid]]);
      }else{
        journal.addAll([[payable,total,0],[inventory,0,total]]);
        if(paid>0)journal.addAll([[account,paid,0],[payable,0,paid]]);
      }
      await addJournal(t,'${kind}_return',id,date,'Return of ${doc['invoice']}: $reason',journal);
      await audit(t,'RETURN',kind,id,'Original invoice ${doc['invoice']}');
      return id;
    });
  }

  Future<void> voidReturn(int returnId) async => db.transaction((t)async{
    final found=await t.rawQuery("SELECT r.*,d.kind,d.party_id FROM document_returns r JOIN documents d ON d.id=r.document_id WHERE r.id=? AND r.status='POSTED'",[returnId]);
    if(found.isEmpty)throw const FormatException('Posted return not found');
    final ret=found.first;final kind=ret['kind'] as String;final date=nowDate();
    await t.rawUpdate("UPDATE document_returns SET status='VOID' WHERE id=?",[returnId]);
    final movements=await t.rawQuery('SELECT * FROM return_lines WHERE return_id=?',[returnId]);
    for(final l in movements){
      await t.rawInsert('INSERT INTO stock_movements(variant_id,qty,source_type,source_id,date,note) VALUES(?,?,?,?,?,?)',
        [l['variant_id'],-numVal(l['qty'])*(kind=='sale'?1:-1)*numVal((await t.rawQuery('SELECT coalesce(u.factor,1) AS factor FROM document_lines dl LEFT JOIN document_line_units u ON u.line_id=dl.id WHERE dl.id=?',[l['source_line_id']])).first['factor']),'void_${kind}_return',returnId,date,'Return voided']);
    }
    final ledgers=await t.rawQuery('SELECT * FROM party_ledger WHERE source_id=? AND source_type IN (?,?)',
      [returnId,'${kind}_return','${kind}_return_refund']);
    for(final l in ledgers){
      await t.rawInsert('INSERT INTO party_ledger(party_id,debit,credit,source_type,source_id,date,note,payment_account_id) VALUES(?,?,?,?,?,?,?,?)',
        [l['party_id'],l['credit'],l['debit'],'void_${kind}_return',returnId,date,'Return voided',l['payment_account_id']]);
    }
    await _reverseJournal(t,'${kind}_return',returnId,'Return voided');
    await audit(t,'VOID','return',returnId);
  });

  Future<void> voidReceipt(int receiptId) async => db.transaction((t)async{
    final row=await t.rawQuery('SELECT * FROM receipts WHERE id=?',[receiptId]);
    if(row.isEmpty)throw const FormatException('Receipt not found');
    if((await t.rawQuery("SELECT id FROM reversed_transactions WHERE kind='receipt' AND source_id=?",[receiptId])).isNotEmpty)throw const FormatException('Payment already reversed');
    final allocations=await t.rawQuery('SELECT document_id,amount FROM receipt_allocations WHERE receipt_id=?',[receiptId]);
    for(final a in allocations){
      await t.rawUpdate('UPDATE documents SET paid=paid-? WHERE id=?',[a['amount'],a['document_id']]);
    }
    await t.rawDelete('DELETE FROM receipt_allocations WHERE receipt_id=?',[receiptId]);
    final original=await t.rawQuery("SELECT * FROM party_ledger WHERE source_type='receipt' AND source_id=?",[receiptId]);
    for(final l in original){
      await t.rawInsert('INSERT INTO party_ledger(party_id,debit,credit,source_type,source_id,date,note,payment_account_id) VALUES(?,?,?,?,?,?,?,?)',
        [l['party_id'],l['credit'],l['debit'],'void_receipt',receiptId,nowDate(),'Payment reversal',l['payment_account_id']]);
    }
    await _reverseJournal(t,'receipt',receiptId,'Payment reversal');
    await t.rawInsert('INSERT INTO reversed_transactions(kind,source_id,date) VALUES(?,?,?)',['receipt',receiptId,nowDate()]);
    await audit(t,'VOID','receipt',receiptId);
  });

  Future<void> voidExpense(int expenseId) async => db.transaction((t)async{
    final row=await t.rawQuery('SELECT * FROM expenses WHERE id=?',[expenseId]);
    if(row.isEmpty)throw const FormatException('Expense not found');
    if((await t.rawQuery("SELECT id FROM reversed_transactions WHERE kind='expense' AND source_id=?",[expenseId])).isNotEmpty)throw const FormatException('Expense already reversed');
    await _reverseJournal(t,'expense',expenseId,'Expense reversal');
    await t.rawInsert('INSERT INTO reversed_transactions(kind,source_id,date) VALUES(?,?,?)',['expense',expenseId,nowDate()]);
    await audit(t,'VOID','expense',expenseId);
  });

  Future<void> openingPartyBalance(int partyId,double amount,String note) async {
    final paisa=pennies(amount);
    if(!amount.isFinite || paisa<=0)throw const FormatException('Enter a positive opening balance');
    await db.transaction((t)async{
      final p=await t.rawQuery('SELECT kind,name FROM parties WHERE id=?',[partyId]);
      if(p.isEmpty)throw const FormatException('Party not found');
      if((await t.rawQuery("SELECT id FROM party_ledger WHERE party_id=? AND source_type='opening' LIMIT 1",[partyId])).isNotEmpty)throw const FormatException('Opening balance already entered; use an audited adjustment instead');
      final customer=p.first['kind']=='customer';
      final id=await t.rawInsert('INSERT INTO party_ledger(party_id,debit,credit,source_type,source_id,date,note) VALUES(?,?,?,?,?,?,?)',
        [partyId,customer?paisa:0,customer?0:paisa,'opening',0,nowDate(),note]);
      await t.rawUpdate('UPDATE party_ledger SET source_id=? WHERE id=?',[id,id]);
      final control=await accountCode(t,customer?'1100':'2000');
      final equity=await accountCode(t,'3000');
      await addJournal(t,'opening',id,nowDate(),note,customer?[[control,paisa,0],[equity,0,paisa]]:[[equity,paisa,0],[control,0,paisa]]);
      await audit(t,'OPENING','party',partyId,note);
    });
  }

  Future<void> manualJournal(String date,int debitAccount,int creditAccount,double amount,String note) async {
    final p=pennies(amount);
    if(p<=0||!amount.isFinite||debitAccount==creditAccount)throw const FormatException('Invalid accounts or amount');
    await db.transaction((t)async{
      final id=await addJournal(t,'manual',DateTime.now().microsecondsSinceEpoch,date,note,[[debitAccount,p,0],[creditAccount,0,p]]);
      await audit(t,'POST','journal',id,note);
    });
  }

  Future<void> paySalaryBalance(int employee,double amount,int account) async {
    final p=pennies(amount);
    if(p<=0)throw const FormatException('Enter positive amount');
    await db.transaction((t)async{
      final bal=await t.rawQuery('''SELECT coalesce(sum(CASE WHEN kind='SALARY_DUE' THEN amount WHEN kind IN ('SALARY_PAID','RECOVERY') THEN -amount ELSE 0 END),0) AS due
        FROM employee_ledger WHERE employee_id=?''',[employee]);
      if(p>(bal.first['due'] as num).toInt())throw const FormatException('Payment exceeds salary due');
      final id=await t.rawInsert('INSERT INTO employee_ledger(employee_id,date,kind,amount,source_type,source_id,note) VALUES(?,?,?,?,?,?,?)',
        [employee,nowDate(),'SALARY_PAID',p,'salary_payment',0,'Salary balance paid']);
      await t.rawUpdate('UPDATE employee_ledger SET source_id=? WHERE id=?',[id,id]);
      await addJournal(t,'salary_payment',id,nowDate(),'Salary balance payment',[[await accountCode(t,'2100'),p,0],[account,0,p]]);
      await audit(t,'POST','salary_payment',id);
    });
  }
}
