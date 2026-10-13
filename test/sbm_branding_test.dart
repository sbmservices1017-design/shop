import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopdesk_flutter/brand_identity.dart';
import 'package:shopdesk_flutter/nexa_theme.dart';

void main() {
  testWidgets('Owner footer includes copyright and support contacts', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Column(children: [Spacer(), SbmFooter()]))));
    expect(find.text(SbmIdentity.copyright), findsOneWidget);
    expect(find.text('Support: ${SbmIdentity.phone}'), findsOneWidget);
    expect(find.text(SbmIdentity.email), findsOneWidget);
  });

  testWidgets('Desktop authentication uses branded left panel and right form', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() { tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });
    await tester.pumpWidget(const MaterialApp(home: NexaAuthLayout(
      heading: 'Welcome back', subtitle: 'Sign in',
      icon: Icons.lock_outline,
      child: TextField(decoration: InputDecoration(labelText: 'Username')),
    )));
    expect(find.text('ShopDesk Pro'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    expect(find.text(SbmIdentity.email), findsOneWidget);
  });
}
