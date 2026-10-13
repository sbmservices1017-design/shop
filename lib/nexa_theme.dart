import 'package:flutter/material.dart';

/// Reusable NexaDash-inspired visual tokens. No business logic lives here.
abstract final class Nexa {
  static const background = Color(0xFF0A1523);
  static const sidebar = Color(0xFF0C1829);
  static const panel = Color(0xFF111F30);
  static const panelTop = Color(0xFF15263B);
  static const header = Color(0xFF0C1726);
  static const outline = Color(0xFF22354A);
  static const muted = Color(0xFFA4B7D2);
  static const secondary = Color(0xFF7F96B7);
  static const brightBlue = Color(0xFF247BFF);
  static const green = Color(0xFF26CD94);
  static const purple = Color(0xFFA34CF6);
  static const orange = Color(0xFFFF914D);
  static const pink = Color(0xFFE74E9B);
  static const white = Color(0xFFF8FAFF);

  static const cardGradient = LinearGradient(
    colors: [Color(0xFF152336), Color(0xFF101C2B)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const pageGradient = LinearGradient(
    colors: [Color(0xFF0D1929), Color(0xFF09121E)],
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

  @override Widget build(BuildContext context) {
    final old = Theme.of(context);
    final authTheme = old.copyWith(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Nexa.brightBlue,
        brightness: Brightness.dark,
        surface: Nexa.panel,
      ),
      textTheme: old.textTheme.apply(bodyColor: Nexa.white, displayColor: Nexa.white),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0D1B2D),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 17),
        labelStyle: const TextStyle(color: Nexa.muted),
        hintStyle: const TextStyle(color: Nexa.secondary),
        prefixIconColor: Nexa.secondary,
        suffixIconColor: Nexa.secondary,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Nexa.outline)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Nexa.outline)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Nexa.brightBlue, width: 1.6)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Nexa.brightBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(100, 51),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Nexa.white,
          minimumSize: const Size(100, 51),
          side: const BorderSide(color: Nexa.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
    return Theme(
      data: authTheme,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: Nexa.pageGradient),
          child: SizedBox.expand(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(25),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: NexaPanel(
                    padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 34),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: Nexa.blueGradient,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(icon, color: Colors.white, size: 26),
                          ),
                        ),
                        const SizedBox(height: 19),
                        const Text('SHOPDESK PRO', textAlign: TextAlign.center,
                          style: TextStyle(color: Nexa.brightBlue, fontWeight: FontWeight.w800, letterSpacing: 2.1, fontSize: 11)),
                        const SizedBox(height: 9),
                        Text(heading, textAlign: TextAlign.center,
                          style: const TextStyle(color: Nexa.white, fontWeight: FontWeight.w800, fontSize: 25)),
                        const SizedBox(height: 8),
                        Text(subtitle, textAlign: TextAlign.center,
                          style: const TextStyle(color: Nexa.muted, fontSize: 12, height: 1.5)),
                        const SizedBox(height: 27),
                        child,
                        const SizedBox(height: 21),
                        const Text('OFFLINE  •  SQLITE  •  SECURE LOCAL DATA', textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10, color: Nexa.secondary, letterSpacing: 1)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
