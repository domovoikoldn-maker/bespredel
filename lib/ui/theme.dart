// Киберпанк / хакерская тема с аниме-акцентами.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

const kBg = Color(0xFF05060A);
const kSurface = Color(0xE60B0F16);
const kSurface2 = Color(0xFF111723);
const kCyan = Color(0xFF00F0FF);
const kPink = Color(0xFFFF2BD6);
const kGreen = Color(0xFF39FF14);
const kMuted = Color(0xFF6E7F96);
const kDanger = Color(0xFFFF3355);

// Совместимые имена, которые используют страницы
const kRed = kPink;
const kOrange = kCyan;

const kMono = 'monospace';
const kMonoFallback = ['Cascadia Mono', 'Consolas', 'Roboto Mono', 'Courier New'];

const kGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kPink, Color(0xFF8A2BFF), kCyan],
);

TextStyle mono({double size = 13, Color color = Colors.white, FontWeight weight = FontWeight.w500, double spacing = 0}) =>
    TextStyle(
      fontFamily: kMono,
      fontFamilyFallback: kMonoFallback,
      fontSize: size,
      color: color,
      fontWeight: weight,
      letterSpacing: spacing,
    );

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: kPink, brightness: Brightness.dark)
      .copyWith(primary: kPink, secondary: kCyan, surface: kSurface2, error: kDanger);
  final base = ThemeData(useMaterial3: true, brightness: Brightness.dark, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: kBg,
    textTheme: base.textTheme.apply(fontFamily: kMono),
    appBarTheme: const AppBarTheme(backgroundColor: kBg, elevation: 0),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xF2070A10),
      indicatorColor: kPink.withOpacity(0.18),
      iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? kCyan : kMuted)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => mono(
          size: 11,
          color: s.contains(WidgetState.selected) ? kCyan : kMuted,
          spacing: 1)),
    ),
    dividerColor: Colors.white10,
    snackBarTheme: SnackBarThemeData(
      backgroundColor: kSurface2,
      contentTextStyle: mono(color: kCyan),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4), side: const BorderSide(color: kCyan, width: 1)),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: const Color(0xFF0B0F16),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6), side: BorderSide(color: kPink.withOpacity(0.5))),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: kSurface2,
      selectedColor: kPink.withOpacity(0.2),
      labelStyle: mono(size: 12, weight: FontWeight.w700, spacing: 1),
      side: BorderSide(color: kCyan.withOpacity(0.25)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? kCyan : kMuted),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? kCyan.withOpacity(0.3) : kSurface2),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: kCyan)),
    ),
  );
}

/// Панель с неоновой рамкой и «уголками» как в HUD.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color accent;
  const Panel(
      {super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.accent = kCyan});

  @override
  Widget build(BuildContext context) => CustomPaint(
        foregroundPainter: _CornerPainter(accent),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? kSurface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: accent.withOpacity(0.16)),
          ),
          child: child,
        ),
      );
}

class _CornerPainter extends CustomPainter {
  final Color c;
  _CornerPainter(this.c);
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = c.withOpacity(0.85)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    const l = 10.0;
    final path = Path()
      ..moveTo(0, l)
      ..lineTo(0, 0)
      ..lineTo(l, 0)
      ..moveTo(s.width - l, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width, l)
      ..moveTo(s.width, s.height - l)
      ..lineTo(s.width, s.height)
      ..lineTo(s.width - l, s.height)
      ..moveTo(l, s.height)
      ..lineTo(0, s.height)
      ..lineTo(0, s.height - l);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) => old.c != c;
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
        child: Row(children: [
          Text('// ', style: mono(color: kPink, weight: FontWeight.w800)),
          Expanded(
            child: Text(text.toUpperCase(),
                style: mono(color: kCyan, size: 12, spacing: 2, weight: FontWeight.w700)),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

/// Заголовок страницы в стиле терминала.
class PageTitle extends StatelessWidget {
  final String text;
  final String? jp;
  const PageTitle(this.text, {super.key, this.jp});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('> ', style: mono(size: 24, color: kPink, weight: FontWeight.w900)),
          Flexible(child: Text(text, style: mono(size: 24, weight: FontWeight.w900, spacing: 2))),
          const BlinkCursor(),
        ]),
        if (jp != null) Text(jp!, style: mono(size: 11, color: kMuted, spacing: 3)),
      ]);
}

class BlinkCursor extends StatefulWidget {
  const BlinkCursor({super.key});
  @override
  State<BlinkCursor> createState() => _BlinkCursorState();
}

class _BlinkCursorState extends State<BlinkCursor> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Opacity(
          opacity: _c.value < 0.5 ? 1 : 0,
          child: Container(width: 10, height: 20, margin: const EdgeInsets.only(left: 4, bottom: 4), color: kCyan),
        ),
      );
}

/// Глитч-надпись с RGB-сдвигом.
class GlitchText extends StatefulWidget {
  final String text;
  final double size;
  const GlitchText(this.text, {super.key, this.size = 30});
  @override
  State<GlitchText> createState() => _GlitchTextState();
}

class _GlitchTextState extends State<GlitchText> with SingleTickerProviderStateMixin {
  late final Ticker _t;
  final _rnd = math.Random();
  Offset _a = Offset.zero, _b = Offset.zero;
  Duration _last = Duration.zero;
  int _burst = 0;

  @override
  void initState() {
    super.initState();
    _t = createTicker((el) {
      if (el - _last < const Duration(milliseconds: 60)) return;
      _last = el;
      if (_burst > 0) {
        _burst--;
        setState(() {
          _a = Offset(_rnd.nextDouble() * 6 - 3, _rnd.nextDouble() * 2 - 1);
          _b = Offset(_rnd.nextDouble() * 6 - 3, _rnd.nextDouble() * 2 - 1);
        });
      } else if (_rnd.nextDouble() < 0.025) {
        _burst = 4 + _rnd.nextInt(4);
      } else if (_a != const Offset(1.5, 0)) {
        setState(() {
          _a = const Offset(1.5, 0);
          _b = const Offset(-1.5, 0);
        });
      }
    })
      ..start();
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = mono(size: widget.size, weight: FontWeight.w900, spacing: widget.size * 0.18);
    return Stack(children: [
      Transform.translate(offset: _a, child: Text(widget.text, style: st.copyWith(color: kCyan.withOpacity(0.85)))),
      Transform.translate(offset: _b, child: Text(widget.text, style: st.copyWith(color: kPink.withOpacity(0.85)))),
      Text(widget.text, style: st.copyWith(color: Colors.white)),
    ]);
  }
}

/// Фон: «матричный дождь» из катаканы + сканлайны.
class CyberBackground extends StatefulWidget {
  final bool rain;
  final Widget child;
  const CyberBackground({super.key, required this.rain, required this.child});
  @override
  State<CyberBackground> createState() => _CyberBackgroundState();
}

class _CyberBackgroundState extends State<CyberBackground> with SingleTickerProviderStateMixin {
  late final Ticker _t;
  final _rain = _RainModel();
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _t = createTicker((el) {
      if (!widget.rain) return;
      if (el - _last < const Duration(milliseconds: 70)) return;
      _last = el;
      _rain.step();
      setState(() {});
    })
      ..start();
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.6),
                radius: 1.3,
                colors: [Color(0xFF13082A), kBg],
              ),
            ),
          ),
        ),
        if (widget.rain)
          Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: _RainPainter(_rain)))),
        Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _ScanlinePainter()))),
        widget.child,
      ]);
}

class _RainModel {
  static const chars = 'ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ01ベスプレデル';
  final rnd = math.Random();
  List<double> drops = [];
  List<int> seeds = [];
  int cols = 0;
  int tick = 0;

  void ensure(int c) {
    if (c == cols) return;
    cols = c;
    drops = List.generate(c, (_) => rnd.nextDouble() * -40);
    seeds = List.generate(c, (_) => rnd.nextInt(1 << 20));
  }

  void step() {
    tick++;
    for (var i = 0; i < drops.length; i++) {
      drops[i] += 0.5 + (seeds[i] % 5) * 0.12;
      if (drops[i] > 60 && rnd.nextDouble() > 0.97) drops[i] = rnd.nextDouble() * -20;
    }
  }

  String ch(int col, int row) => chars[(seeds[col] + row * 7 + (tick ~/ 6) * (col % 3 == 0 ? 1 : 0)) % chars.length];
}

class _RainPainter extends CustomPainter {
  final _RainModel m;
  _RainPainter(this.m);
  static const cell = 16.0;

  @override
  void paint(Canvas canvas, Size size) {
    final cols = (size.width / (cell * 1.6)).ceil();
    m.ensure(cols);
    final rows = (size.height / cell).ceil();
    for (var c = 0; c < cols; c++) {
      final head = m.drops[c];
      for (var k = 0; k < 14; k++) {
        final r = head.floor() - k;
        if (r < 0 || r > rows) continue;
        final a = (1 - k / 14) * (k == 0 ? 0.55 : 0.16);
        final tp = TextPainter(
          text: TextSpan(
            text: m.ch(c, r),
            style: TextStyle(
              fontSize: 12,
              color: (k == 0 ? Colors.white : (c % 4 == 0 ? kPink : kCyan)).withOpacity(a),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(c * cell * 1.6, r * cell));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.black.withOpacity(0.18);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Неоновая кнопка.
class NeonButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color;
  final bool filled;
  const NeonButton(
      {super.key, required this.label, this.icon, this.onPressed, this.color = kCyan, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final c = enabled ? color : kMuted;
    return Material(
      color: filled && enabled ? c.withOpacity(0.18) : Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: BorderSide(color: c.withOpacity(0.8))),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: 18, color: c), const SizedBox(width: 8)],
            Flexible(
              child: Text(label.toUpperCase(),
                  overflow: TextOverflow.ellipsis, style: mono(size: 12, color: c, weight: FontWeight.w800, spacing: 1.5)),
            ),
          ]),
        ),
      ),
    );
  }
}

Color pingColor(int? ms) {
  if (ms == null || ms < 0) return kDanger;
  if (ms < 400) return kGreen;
  if (ms < 1000) return kCyan;
  return const Color(0xFFFFD166);
}
