import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopdesk_flutter/shop_shortcuts.dart';

void main() {
  test('ShopDesk shortcuts use unique combinations and valid menu positions', () {
    final seen = <String>{};
    for (final shortcut in shopNavigationShortcuts) {
      expect(seen.add(shortcut.keys), isTrue, reason: 'Duplicate ${shortcut.keys}');
      expect(shortcut.pageIndex, inInclusiveRange(0, 15));
    }
    expect(
      shopNavigationShortcuts.where((s) => s.keys == 'F2').single.pageIndex,
      1,
    );
    expect(
      shopNavigationShortcuts.where((s) => s.keys == 'Ctrl+9').single.pageIndex,
      15,
    );
  });

  testWidgets('navigation shortcut works with a focused search input', (tester) async {
    int? destination;
    await tester.pumpWidget(MaterialApp(
      home: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          for (final shortcut in shopNavigationShortcuts)
            shortcut.activator: () => destination = shortcut.pageIndex,
        },
        child: const Focus(
          autofocus: true,
          child: Scaffold(body: Center(child: TextField())),
        ),
      ),
    ));
    await tester.pump();
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await tester.pump();
    expect(destination, 1);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit8);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(destination, 14);
  });
}
