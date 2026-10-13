import 'package:flutter/material.dart';
import 'brand_identity.dart';

/// Reusable NexaDash-inspired visual tokens. No business logic lives here.
abstract final class Nexa {
  static const background = Color(0xFFF5F9FF);
  static const sidebar = Color(0xFFFFFFFF);
  static const panel = Color(0xFFFFFFFF);
  static const panelTop = Color(0xFFEDF5FF);
  static const header = Color(0xFFFFFFFF);
  static const outline = Color(0xFFD8E6F7);
  static const muted = Color(0xFF263D59);
  static const secondary = Color(0xFF516C88);
  static const brightBlue = Color(0xFF1769D2);
  static const green = Color(0xFF138B65);
  static const purple = Color(0xFFA34CF6);
  static const orange = Color(0xFFD06A27);
  static const pink = Color(0xFFE74E9B);
  static const white = Color(0xFF142B46);

  static const cardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FBFF)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const pageGradient = LinearGradient(
    colors: [Color(0xFFF7FAFF), Color(0xFFEEF6FF)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const blueGradient = LinearGradient(
    colors: [Color(0xFF368BFF), Color(0xFF1868ED)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
}

class NexaPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const NexaPanel({super.key, required this.child, this.padding = const EdgeInsets.all(20)});

  @override Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: Nexa.cardGradient,
      border: Border.all(color: Nexa.outline),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Padding(padding: padding, child: child),
  );
}

/// Shared for first launch, owner registration, login and license activation.
/// All onboarding screens share the same SBM Services split-screen shell.
/// On a normal Windows desktop the logo is always on the left and the form is on
/// the right. Smaller windows use a vertically scrollable layout without overflow.
class NexaAuthLayout extends StatelessWidget {
  final String heading;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final double maxWidth;

  const NexaAuthLayout({
    super.key,
    required this.heading,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.maxWidth = 530,
  });

  Widget _brandPanel({bool compact = false}) => Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(horizontal: compact ? 22 : 46, vertical: compact ? 20 : 36),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF0C1E36), Color(0xFF12395F), Color(0xFF1C65AC)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Image.asset(SbmIdentity.logoAsset,
          width: compact ? 195 : 360,
          height: compact ? 110 : 205,
          fit: BoxFit.contain,
          semanticLabel: 'SBM Services logo'),
        SizedBox(height: compact ? 5 : 17),
        Text('ShopDesk Pro', textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800,
            fontSize: compact ? 22 : 34, letterSpacing: -.6)),
        const SizedBox(height: 8),
        Text('Complete Shop Management Solution', textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFD8EAFB),
            fontSize: compact ? 11 : 15)),
        if (!compact) ...[
          const SizedBox(height: 38),
          const Wrap(alignment: WrapAlignment.center, spacing: 15, runSpacing: 14,
            children: [
              _BrandFeature(Icons.point_of_sale_rounded, 'POS & Sales'),
              _BrandFeature(Icons.inventory_2_outlined, 'Inventory'),
              _BrandFeature(Icons.shopping_cart_outlined, 'Purchases'),
              _BrandFeature(Icons.badge_outlined, 'Employees'),
              _BrandFeature(Icons.analytics_outlined, 'Reports'),
            ]),
          const SizedBox(height: 36),
          const Text('Simple   •   Reliable   •   Offline',
            style: TextStyle(color: Color(0xFFBDD9F7), fontSize: 12)),
        ],
      ],
    ),
  );

  Widget _formPanel() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: NexaPanel(
          padding: const EdgeInsets.symmetric(horizontal: 31, vertical: 31),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFE6F2FF),
                    borderRadius: BorderRadius.circular(11)),
                  child: Icon(icon, color: Nexa.brightBlue, size: 26),
                ),
              ),
              const SizedBox(height: 17),
              Text(heading,
                style: const TextStyle(color: Nexa.white,
                  fontWeight: FontWeight.w800, fontSize: 25)),
              const SizedBox(height: 8),
              Text(subtitle,
                style: const TextStyle(color: Nexa.muted,
                  fontSize: 12, height: 1.55)),
              const SizedBox(height: 24),
              child,
              const SizedBox(height: 17),
              const Text('OFFLINE  •  SQLITE  •  SECURE LOCAL DATA',
                textAlign: TextAlign.center,
                style: TextStyle(color: Nexa.secondary,
                  fontSize: 10, letterSpacing: .8)),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final old = Theme.of(context);
    final authTheme = old.copyWith(
      colorScheme: ColorScheme.fromSeed(seedColor: Nexa.brightBlue),
      textTheme: old.textTheme.apply(bodyColor: Nexa.white, displayColor: Nexa.white),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF3F8FF),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
        labelStyle: const TextStyle(color: Nexa.muted),
        hintStyle: const TextStyle(color: Nexa.secondary),
        prefixIconColor: Nexa.secondary,
        suffixIconColor: Nexa.secondary,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Nexa.outline)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Nexa.outline)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Nexa.brightBlue, width: 1.6)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Nexa.brightBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(100, 49),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );

    return Theme(
      data: authTheme,
      child: Scaffold(
        backgroundColor: Nexa.background,
        body: SafeArea(
          child: Column(children: [
            Expanded(child: LayoutBuilder(builder: (context, size) {
              if (size.maxWidth >= 900) {
                return Row(children: [
                  Expanded(flex: 43, child: _brandPanel()),
                  Expanded(flex: 57, child: _formPanel()),
                ]);
              }
              return SingleChildScrollView(
                child: Column(children: [
                  _brandPanel(compact: true),
                  _formPanel(),
                ]),
              );
            })),
            const SbmFooter(),
          ]),
        ),
      ),
    );
  }
}

class _BrandFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  const _BrandFeature(this.icon, this.title);
  @override Widget build(BuildContext context) => SizedBox(
    width: 95,
    child: Column(children: [
      Icon(icon, color: Color(0xFF9FD3FF), size: 26),
      const SizedBox(height: 7),
      Text(title, textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 11,
          fontWeight: FontWeight.w600)),
    ]),
  );
}
