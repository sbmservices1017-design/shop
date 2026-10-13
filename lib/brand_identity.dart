import 'package:flutter/material.dart';

/// Commercial identity displayed throughout ShopDesk Pro.
/// This widget is purely presentational; billing, payroll and stock remain unchanged.
abstract final class SbmIdentity {
  static const name = 'SBM Services';
  static const phone = '03060730653';
  static const email = 'sbmservices@gmail.com';
  static const copyright = 'All Rights Reserved © SBM Services';
  static const logoAsset = 'assets/branding/sbm_logo.png';
}

class SbmFooter extends StatelessWidget {
  const SbmFooter({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
    decoration: const BoxDecoration(
      color: Color(0xFFFFFFFF),
      border: Border(top: BorderSide(color: Color(0xFFD9E8FA))),
    ),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 20,
      runSpacing: 6,
      children: const [
        Text(SbmIdentity.copyright,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11,
            color: Color(0xFF193C63))),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.support_agent_rounded, color: Color(0xFF1769D2), size: 16),
          SizedBox(width: 6),
          SelectableText('Support: ${SbmIdentity.phone}',
            style: TextStyle(fontSize: 11, color: Color(0xFF284B6E))),
        ]),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.email_outlined, color: Color(0xFF1769D2), size: 16),
          SizedBox(width: 6),
          SelectableText(SbmIdentity.email,
            style: TextStyle(fontSize: 11, color: Color(0xFF284B6E))),
        ]),
      ],
    ),
  );
}
