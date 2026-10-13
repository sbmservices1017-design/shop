import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopdesk_flutter/nexa_theme.dart';

void main() {
  test('light theme contrast tokens are retained', () {
    expect(Nexa.background,const Color(0xFFF5F9FF));
    expect(Nexa.panel,Colors.white);
    expect(Nexa.white,const Color(0xFF142B46));
  });
  testWidgets('Nexa first-run/login layout retains content and colors', (tester) async {
    await tester.pumpWidget(const MaterialApp(home:NexaAuthLayout(
      heading:'Welcome back',
      subtitle:'Sign in to ShopDesk',
      icon:Icons.login,
      child:Text('Login form'),
    )));
    expect(find.text('Welcome back'),findsOneWidget);
    expect(find.text('Login form'),findsOneWidget);
    expect(find.text('ShopDesk Pro'),findsOneWidget);
    expect(find.byType(NexaPanel),findsOneWidget);
  });
}
