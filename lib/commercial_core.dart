import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart' as digest;
import 'package:cryptography/cryptography.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'store.dart';
import 'license_public.dart';

/// Single-PC local identity and signed-license implementation.
/// Security limitations: a determined local administrator can modify the DB or executable.
/// Never ship the Ed25519 PRIVATE key with a Windows release or GitHub repository.
const commercialModules = <String>[
  'Dashboard','Products & Variants','Categories & Fields','Stock & Adjustments',
  'Sales / Billing','Purchases','Returns & Refunds','Customers','Suppliers',
  'Expenses','Employees & Payroll','Accounts & Journal','Reports / Export',
  'Settings & Backup','Users & Permissions'
];

class ShopUser {
  final int id;
  final String username;
  final bool isAdmin;
  final Map<String,Set<String>> permissions;
  const ShopUser(this.id,this.username,this.isAdmin,this.permissions);
  bool allowed(String module,String action) => isAdmin || (permissions[module]?.contains(action) ?? false);
}

class LicenseState {
  final String label;
  final bool allowed;
  final DateTime? expires;
  final Duration? remaining;
  const LicenseState(this.label,this.allowed,{this.expires,this.remaining});
}

class CommercialCore extends ChangeNotifier {
  CommercialCore._();
  static final CommercialCore instance=CommercialCore._();
  final Store store=Store.instance;
  ShopUser? current;
  String deviceCode='';
  LicenseState license=const LicenseState('Unregistered',false);
  static const _operations=['view','create','edit','delete'];
  final _hasher=Pbkdf2(macAlgorithm:Hmac.sha256(),iterations:120000,bits:256);

  Future<File> _trialMarker() async {
    // Test/override databases use an isolated anchor beside their DB.
    if(p.basename(store.dbPath)!='shopdesk.sqlite') {
      return File(p.join(p.dirname(store.dbPath),'shopdesk_trial_first_registration.txt'));
    }
    final folder=await getApplicationSupportDirectory();
    return File(p.join(folder.path,'shopdesk_trial_first_registration.txt'));
  }
  Future<String> _trialStartAnchor() async {
    final marker=await _trialMarker();
    if(await marker.exists()) {
      final saved=(await marker.readAsString()).trim();
      if(DateTime.tryParse(saved)!=null)return saved;
    }
    final value=DateTime.now().toUtc().toIso8601String();
    await marker.writeAsString(value,flush:true);
    return value;
  }
  Future<void> _reconcileTrialAnchor() async {
    final raw=await readSetting('trial_start_utc');
    if(raw==null)return;
    final existing=DateTime.tryParse(raw)?.toUtc();
    if(existing==null)return;
    final marker=await _trialMarker();
    if(!await marker.exists()){
      await marker.writeAsString(existing.toIso8601String(),flush:true);
      return;
    }
    final anchored=DateTime.tryParse((await marker.readAsString()).trim())?.toUtc();
    if(anchored==null || existing.isBefore(anchored)) {
      await marker.writeAsString(existing.toIso8601String(),flush:true);
    }else if(anchored.isBefore(existing)) {
      await saveSetting('trial_start_utc',anchored.toIso8601String());
    }
  }

  Future<void> init() async {
    final db=store.db;
    await db.execute('''CREATE TABLE IF NOT EXISTS app_users(
      id INTEGER PRIMARY KEY, username TEXT NOT NULL UNIQUE COLLATE NOCASE,
      salt TEXT NOT NULL, pass_hash TEXT NOT NULL, is_admin INTEGER NOT NULL DEFAULT 0,
      active INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS app_permissions(
      user_id INTEGER NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
      module TEXT NOT NULL, operation TEXT NOT NULL,
      PRIMARY KEY(user_id,module,operation))''');
    await db.execute('CREATE TABLE IF NOT EXISTS app_settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    await db.execute('''CREATE TABLE IF NOT EXISTS receipt_allocations(
      receipt_id INTEGER NOT NULL REFERENCES receipts(id),
      document_id INTEGER NOT NULL REFERENCES documents(id),
      amount INTEGER NOT NULL CHECK(amount>0),PRIMARY KEY(receipt_id,document_id))''');
    await db.execute('''CREATE TABLE IF NOT EXISTS login_events(
      id INTEGER PRIMARY KEY, at TEXT NOT NULL, user_id INTEGER, event TEXT NOT NULL,
      FOREIGN KEY(user_id) REFERENCES app_users(id))''');
    deviceCode=await _deviceCode();
    await _reconcileTrialAnchor();
    await refreshLicense();
  }

  Future<String> _deviceCode() async {
    String input=Platform.localHostname;
    if(Platform.isWindows){
      try {
        final result=await Process.run('reg',['query',r'HKLM\SOFTWARE\Microsoft\Cryptography','/v','MachineGuid']);
        if(result.exitCode==0){
          final m=RegExp(r'MachineGuid\s+REG_SZ\s+(\S+)',caseSensitive:false).firstMatch('${result.stdout}');
          if(m!=null)input=m.group(1)!;
        }
      }catch(_){/* Fallback to host name for unsupported Windows configurations */}
    }
    return digest.sha256.convert(utf8.encode('SHOPDESK-V1/$input')).toString().substring(0,32).toUpperCase();
  }

  Future<String?> readSetting(String key) async {
    final rows=await store.read('SELECT value FROM app_settings WHERE key=?',[key]);
    return rows.isEmpty?null:rows.first['value'] as String;
  }
  Future<void> saveSetting(String key,String value) async {
    await store.db.rawInsert('INSERT INTO app_settings(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value',[key,value]);
  }
  Future<bool> get hasOwner async => (await store.count('SELECT count(*) FROM app_users'))>0;
  Future<String> _hashPassword(String password,List<int> salt) async {
    final key=await _hasher.deriveKeyFromPassword(password:password,nonce:salt);
    return base64Encode(await key.extractBytes());
  }
  List<int> _randomSalt()=>List.generate(24,(_)=>Random.secure().nextInt(256));
  bool _equal(String a,String b){
    if(a.length!=b.length)return false;
    var mismatch=0;
    for(var i=0;i<a.length;i++){mismatch|=a.codeUnitAt(i)^b.codeUnitAt(i);}
    return mismatch==0;
  }
  String _validName(String name){
    final clean=name.trim();
    if(!RegExp(r'^[a-zA-Z0-9_.-]{3,40}$').hasMatch(clean))throw const FormatException('Username: 3–40 letters, numbers, dot, underscore or dash');
    return clean;
  }
  void _validPassword(String password){if(password.length<10)throw const FormatException('Password must contain at least 10 characters');}

  Future<void> registerOwner(String name,String password) async {
    if(await hasOwner)throw StateError('Owner already exists');
    _validPassword(password);
    final trialStart=await _trialStartAnchor();
    final salt=_randomSalt();final hash=await _hashPassword(password,salt);
    await store.db.transaction((t)async {
      final existing=await t.rawQuery('SELECT count(*) AS n FROM app_users');
      if((existing.first['n'] as int)>0)throw StateError('Owner already exists');
      final id=await t.rawInsert('INSERT INTO app_users(username,salt,pass_hash,is_admin,created_at) VALUES(?,?,?,?,?)',[_validName(name),base64Encode(salt),hash,1,DateTime.now().toUtc().toIso8601String()]);
      await t.rawInsert('INSERT OR IGNORE INTO app_settings(key,value) VALUES(?,?)',['trial_start_utc',trialStart]);
      await t.rawInsert('INSERT INTO login_events(at,user_id,event) VALUES(?,?,?)',[DateTime.now().toUtc().toIso8601String(),id,'OWNER_REGISTERED']);
    });
    await signIn(name,password);
  }

  Future<void> signIn(String name,String password) async {
    final rows=await store.read('SELECT * FROM app_users WHERE username=? AND active=1',[name.trim()]);
    if(rows.isEmpty)throw const FormatException('Incorrect username or password');
    final row=rows.first;
    final hash=await _hashPassword(password,base64Decode(row['salt'] as String));
    if(!_equal(hash,row['pass_hash'] as String)){
      await store.db.rawInsert('INSERT INTO login_events(at,user_id,event) VALUES(?,?,?)',[DateTime.now().toUtc().toIso8601String(),row['id'],'LOGIN_FAILED']);
      throw const FormatException('Incorrect username or password');
    }
    final perms=await store.read('SELECT module,operation FROM app_permissions WHERE user_id=?',[row['id']]);
    final grants=<String,Set<String>>{};
    for(final p in perms){grants.putIfAbsent(p['module'] as String,()=>{}).add(p['operation'] as String);}
    current=ShopUser(row['id'] as int,row['username'] as String,row['is_admin']==1,grants);
    await store.db.rawInsert('INSERT INTO login_events(at,user_id,event) VALUES(?,?,?)',[DateTime.now().toUtc().toIso8601String(),row['id'],'LOGIN_SUCCESS']);
    await refreshLicense();
    notifyListeners();
  }
  void signOut(){current=null;notifyListeners();}

  Future<LicenseState> refreshLicense() async {
    final now=DateTime.now().toUtc();
    final lastRaw=await readSetting('last_seen_utc');
    final last=lastRaw==null?null:DateTime.tryParse(lastRaw)?.toUtc();
    if(last!=null && now.isBefore(last.subtract(const Duration(minutes:5)))) {
      license=const LicenseState('Clock check required',false);
      return license;
    }
    if(last==null || now.isAfter(last))await saveSetting('last_seen_utc',now.toIso8601String());
    final token=await readSetting('signed_license');
    if(token!=null){
      final payload=await _verifiedPayload(token);
      if(payload!=null){
        final end=payload['expires_utc']==null?null:DateTime.tryParse('${payload['expires_utc']}')?.toUtc();
        if(end==null || now.isBefore(end)){
          license=LicenseState(end==null?'Lifetime Active':'Licensed Active',true,expires:end,remaining:end?.difference(now));
          return license;
        }
      }
    }
    final trialStart=await readSetting('trial_start_utc');
    if(trialStart==null){license=const LicenseState('Registration required',false);return license;}
    final start=DateTime.tryParse(trialStart)?.toUtc();
    if(start==null || now.isBefore(start.subtract(const Duration(minutes:5)))){license=const LicenseState('Trial verification required',false);return license;}
    final end=start.add(const Duration(hours:48));
    license=now.isBefore(end)?LicenseState('Trial',true,expires:end,remaining:end.difference(now)):LicenseState('Trial expired',false,expires:end);
    return license;
  }
  String _pad(String part)=>part.padRight(part.length+((4-part.length%4)%4),'=');
  Future<Map<String,dynamic>?> _verifiedPayload(String token) async {
    try{
      if(licensePublicKeyBase64.isEmpty)return null;
      final parts=token.trim().split('.');if(parts.length!=2)return null;
      final message=base64Url.decode(_pad(parts[0]));
      final signature=base64Url.decode(_pad(parts[1]));
      final ok=await Ed25519().verify(message,signature:Signature(signature,publicKey:SimplePublicKey(base64Decode(licensePublicKeyBase64),type:KeyPairType.ed25519)));
      if(!ok)return null;
      final data=jsonDecode(utf8.decode(message));if(data is! Map<String,dynamic>)return null;
      if(data['product']!='ShopDesk'||data['device']!=deviceCode)return null;
      return data;
    }catch(_){return null;}
  }
  Future<void> activate(String token) async {
    final data=await _verifiedPayload(token);
    if(data==null)throw const FormatException('Invalid activation key or different computer');
    final issued=DateTime.tryParse('${data['issued_utc']}')?.toUtc();
    final end=data['expires_utc']==null?null:DateTime.tryParse('${data['expires_utc']}')?.toUtc();
    if(issued==null||issued.isAfter(DateTime.now().toUtc().add(const Duration(minutes:10))))throw const FormatException('Invalid license issue date');
    if(end!=null && !end.isAfter(DateTime.now().toUtc()))throw const FormatException('Activation key has already expired');
    await saveSetting('signed_license',token.trim());
    await refreshLicense();
    notifyListeners();
  }

  Future<void> createUser(String username,String password,{bool isAdmin=false}) async {
    if(current?.isAdmin!=true)throw StateError('Admin access required');
    _validPassword(password);final salt=_randomSalt();final hash=await _hashPassword(password,salt);
    await store.db.rawInsert('INSERT INTO app_users(username,salt,pass_hash,is_admin,created_at) VALUES(?,?,?,?,?)',[_validName(username),base64Encode(salt),hash,isAdmin?1:0,DateTime.now().toUtc().toIso8601String()]);
  }
  Future<void> editUser(int id,{String? username,String? password,bool? active}) async {
    if(current?.isAdmin!=true)throw StateError('Admin access required');
    if(id==current?.id && active==false)throw StateError('Cannot disable your own account');
    await store.db.transaction((t)async{
      if(username!=null)await t.rawUpdate('UPDATE app_users SET username=? WHERE id=?',[_validName(username),id]);
      if(password!=null && password.isNotEmpty){_validPassword(password);final salt=_randomSalt();final hash=await _hashPassword(password,salt);await t.rawUpdate('UPDATE app_users SET salt=?,pass_hash=? WHERE id=?',[base64Encode(salt),hash,id]);}
      if(active!=null)await t.rawUpdate('UPDATE app_users SET active=? WHERE id=?',[active?1:0,id]);
    });
  }
  Future<void> setUserPermission(int id,String module,Set<String> operations) async {
    if(current?.isAdmin!=true)throw StateError('Admin access required');
    if(!commercialModules.contains(module)||operations.any((p)=>!_operations.contains(p)))throw ArgumentError('Invalid permission');
    await store.db.transaction((t)async {
      final users=await t.rawQuery('SELECT is_admin FROM app_users WHERE id=?',[id]);
      if(users.isEmpty)throw StateError('User not found');
      if(users.first['is_admin']==1)throw StateError('Administrators have full access');
      await t.rawDelete('DELETE FROM app_permissions WHERE user_id=? AND module=?',[id,module]);
      for(final op in operations){await t.rawInsert('INSERT INTO app_permissions(user_id,module,operation) VALUES(?,?,?)',[id,module,op]);}
    });
  }

  Future<void> saveShopProfile({required String name,required String phone,required String address,String? logoPath}) async {
    if(current?.isAdmin!=true)throw StateError('Admin access required');
    await saveSetting('shop_name',name.trim());
    await saveSetting('shop_phone',phone.trim());
    await saveSetting('shop_address',address.trim());
    if(logoPath!=null)await saveSetting('shop_logo',logoPath);
  }
}
