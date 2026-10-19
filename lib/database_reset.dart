// Restricted local-shop data reset. Keep authentication, device trial anchor and
// license state so a database clear never restarts the 48-hour trial.
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'store.dart';

class ShopDataReset {
  static const _expectedDigest = 'a250024d21e865bcde35dd8d5fc251aaa48c8e01f41a5492a6fe4578649d4103';

  static bool _verifyPin(String pin) {
    if(!RegExp(r'^\d{5}$').hasMatch(pin))return false;
    final candidate=sha256.convert(utf8.encode('shopdesk-business-clear-v1:$pin')).toString();
    // Compare all bytes without short circuiting (not a replacement for OS security).
    var result=0;
    for(var i=0;i<_expectedDigest.length;i++){
      result|=_expectedDigest.codeUnitAt(i)^candidate.codeUnitAt(i);
    }
    return result==0;
  }

  static Future<void> _setting(String key,String value) async {
    await Store.instance.db.rawInsert('''INSERT INTO app_settings(key,value) VALUES(?,?)
      ON CONFLICT(key) DO UPDATE SET value=excluded.value''',[key,value]);
  }
  static Future<String?> _read(String key) async {
    final r=await Store.instance.read('SELECT value FROM app_settings WHERE key=?',[key]);
    return r.isEmpty?null:'${r.first['value']}';
  }

  /// Administrator login must be checked by the invoking settings UI.
  /// Backup file is intentionally retained after the live database is cleared.
  static Future<String> clear({required String pin,required bool administrator}) async {
    if(!administrator)throw const FormatException('Only an administrator can reset shop data.');
    final lockUntil=DateTime.tryParse(await _read('reset_pin_locked_until')??'');
    if(lockUntil!=null && DateTime.now().toUtc().isBefore(lockUntil.toUtc())){
      throw const FormatException('Too many attempts. Wait 15 minutes before trying again.');
    }
    if(!_verifyPin(pin)){
      final failures=(int.tryParse(await _read('reset_pin_failures')??'0')??0)+1;
      await _setting('reset_pin_failures','$failures');
      if(failures>=5){
        await _setting('reset_pin_locked_until',DateTime.now().toUtc().add(const Duration(minutes:15)).toIso8601String());
        await _setting('reset_pin_failures','0');
      }
      throw const FormatException('Incorrect 5-digit owner PIN.');
    }
    await _setting('reset_pin_failures','0');
    await _setting('reset_pin_locked_until','');
    final store=Store.instance;
    final backupDir=Directory(path.join(path.dirname(store.dbPath),'ShopDesk_Reset_Backups'));
    await backupDir.create(recursive:true);
    final stamp=DateTime.now().toUtc().toIso8601String().replaceAll(RegExp(r'[^0-9]'),'');
    final backupFile=path.join(backupDir.path,'shopdesk_before_clear_$stamp.sqlite');
    await store.backup(backupFile);
    // Abort without deleting anything if the automatic backup was not created.
    if(!await File(backupFile).exists())throw StateError('Reset stopped: backup was not saved.');
    await store.db.transaction((t)async {
      for(final table in <String>[
        'return_revisions','return_lines','document_returns',
        'receipt_allocations','document_revisions','document_line_units',
        'document_lines','document_payment_parts','receipts','documents',
        'stock_movements','variant_values','variant_units','variants',
        'attributes','products','categories',
        'party_ledger','parties','employee_ledger','payroll','employees',
        'journal_lines','journal','expenses','expense_categories',
        'reversed_transactions','audit','payment_accounts','accounts'
      ]){
        await t.rawDelete('DELETE FROM $table');
      }
      const systemAccounts=<List<String>>[
        ['1000','Cash','asset'],['1010','Bank','asset'],['1100','Accounts Receivable','asset'],
        ['1200','Inventory','asset'],['1300','Employee Advances','asset'],
        ['2000','Accounts Payable','liability'],['2100','Salary Payable','liability'],
        ['3000','Opening Equity','equity'],['4000','Sales Revenue','revenue'],
        ['5000','Cost of Sales','expense'],['6100','Operating Expense','expense'],
        ['6200','Salary Expense','expense']
      ];
      for(final a in systemAccounts){
        await t.rawInsert('INSERT INTO accounts(code,name,type,created_at) VALUES(?,?,?,?)',
          [a[0],a[1],a[2],nowDate()]);
      }
      await t.rawInsert("INSERT INTO expense_categories(name) VALUES('General')");
      await t.rawInsert("""INSERT INTO payment_accounts(account_id,kind)
        SELECT id,CASE WHEN code='1000' THEN 'cash' ELSE 'bank' END
        FROM accounts WHERE code IN ('1000','1010')""");
      await t.rawDelete("DELETE FROM app_settings WHERE key LIKE 'invoice_%' OR key IN ('payment_account_sequence','ledger_account_sequence')");
    });
    return backupFile;
  }
}
