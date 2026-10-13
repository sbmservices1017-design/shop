import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:shopdesk_flutter/boot_setup.dart';
import 'package:shopdesk_flutter/license_widgets.dart';

void main(){
  test('Trial countdown formatting',(){
    expect(readableRemaining(const Duration(hours:47,minutes:5,seconds:9)),'1d 23:05:09');
    expect(readableRemaining(const Duration(hours:1,minutes:2,seconds:3)),'01:02:03');
    expect(readableRemaining(const Duration(seconds:-1)),'00:00:00');
  });
  test('Reject corrupted or incompatible backup',()async{
    final folder=await Directory.systemTemp.createTemp('shopdesk_test_');
    try {
      final invalid=File('${folder.path}/fake.sqlite');
      await invalid.writeAsString('not a SQLite database');
      expect(()=>ShopDatabaseSetup.validateFile(invalid.path),throwsA(isA<Exception>()));
      final db=sqlite.sqlite3.open('${folder.path}/empty.sqlite');
      db.execute('CREATE TABLE category(id INTEGER PRIMARY KEY)');
      db.dispose();
      expect(()=>ShopDatabaseSetup.validateFile('${folder.path}/empty.sqlite'),throwsFormatException);
    }finally{await folder.delete(recursive:true);}
  });
}
