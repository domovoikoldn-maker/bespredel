import 'package:flutter/material.dart';

const kBg = Color(0xFF0B0B10);
const kSurface = Color(0xFF16161E);
const kSurface2 = Color(0xFF1F1F2A);
const kRed = Color(0xFFFF3B3B);
const kOrange = Color(0xFFFF9A1F);
const kGreen = Color(0xFF2EE59D);
const kMuted = Color(0xFF8C8CA0);

const kGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kRed, kOrange],
);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kRed,
    brightness: Brightness.dark,
  ).copyWith(primary: kRed, secondary: kOrange, surface: kSurface);
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: kBg,
    appBarTheme: const AppBarTheme(backgroundColor: kBg, elevation: 0, centerTitle: false),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: kSurface,
      indicatorColor: kRed.withOpacity(0.22),
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
    ),
    dividerColor: Colors.white10,
    chipTheme: ChipThemeData(
      backgroundColor: kSurface2,
      selectedColor: kRed.withOpacity(0.25),
      side: const BorderSide(color: Colors.white12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

/// Карточка-контейнер в стиле приложения.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? kSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: child,
      );
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
        child: Row(children: [
          Expanded(
            child: Text(text.toUpperCase(),
                style: const TextStyle(
                    color: kMuted, fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w600)),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

Color pingColor(int? ms) {
  if (ms == null || ms < 0) return kRed;
  if (ms < 400) return kGreen;
  if (ms < 1000) return kOrange;
  return const Color(0xFFFFD166);
}
