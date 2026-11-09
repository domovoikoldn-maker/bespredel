import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../presets.dart';
import 'theme.dart';

IconData modeIcon(BypassMode m) => const {
      BypassMode.auto: Icons.auto_awesome_rounded,
      BypassMode.vless: Icons.vpn_lock_rounded,
      BypassMode.multi: Icons.hub_rounded,
      BypassMode.fragment: Icons.content_cut_rounded,
      BypassMode.byedpi: Icons.bolt_rounded,
      BypassMode.zapret: Icons.shield_rounded,
      BypassMode.dns: Icons.travel_explore_rounded,
    }[m]!;

/// Маскот-каомодзи, реагирующий на состояние.
String mascot(ConnState s) => switch (s) {
      ConnState.off => '(￣ω￣) zzZ',
      ConnState.connecting => '(ง •̀_•́)ง',
      ConnState.on => '٩(◕‿◕)۶',
      ConnState.error => '(╥﹏╥)',
    };

String mascotLine(ConnState s) => switch (s) {
      ConnState.off => 'жду команды, сэмпай…',
      ConnState.connecting => 'взламываю матрицу…',
      ConnState.on => 'блокировки повержены!',
      ConnState.error => 'не вышло… попробуй другой метод',
    };

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          Row(children: [
            const Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: GlitchText('BESPREDEL', size: 30))),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('ベスプレデル', style: mono(size: 11, color: kPink, spacing: 2)),
              Text('by domovoi4ik', style: mono(size: 10, color: kMuted)),
            ]),
          ]),
          const SizedBox(height: 22),
          Center(child: Reactor()),
          const SizedBox(height: 14),
          Center(
            child: Text(mascot(app.state),
                style: TextStyle(fontSize: 22, color: app.state == ConnState.on ? kGreen : kCyan)),
          ),
          const SizedBox(height: 2),
          Center(child: Text(mascotLine(app.state), style: mono(size: 12, color: kMuted))),
          const SizedBox(height: 14),
          _Terminal(),
          if (app.busy) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: app.progress > 0 ? app.progress : null,
              color: kPink,
              backgroundColor: kSurface2,
              minHeight: 3,
            ),
            const SizedBox(height: 6),
            Text(app.busyText, textAlign: TextAlign.center, style: mono(size: 11, color: kMuted)),
          ],
          const SectionTitle('Метод обхода'),
          _ModePicker(),
          if (app.mode == BypassMode.vless || app.mode == BypassMode.auto || app.mode == BypassMode.multi) ...[
            const SectionTitle('Сервер'),
            _ServerCard(),
          ],
          SectionTitle('Доступ к сервисам',
              trailing: TextButton.icon(
                onPressed: app.checking.isEmpty ? app.checkServices : null,
                icon: const Icon(Icons.radar_rounded, size: 18, color: kCyan),
                label: Text('СКАН', style: mono(size: 12, color: kCyan, weight: FontWeight.w800, spacing: 1)),
              )),
          _ServiceGrid(),
          if (app.isWindows && app.connected && app.activeMode != BypassMode.zapret) ...[
            const SizedBox(height: 12),
            NeonButton(
              label: 'Telegram Desktop через Беспредел',
              icon: Icons.send_rounded,
              onPressed: app.connectTelegram,
            ),
          ],
        ],
      ),
    );
  }
}

/// Большая кнопка-«реактор» с вращающимися неоновыми кольцами.
class Reactor extends StatefulWidget {
  const Reactor({super.key});
  @override
  State<Reactor> createState() => _ReactorState();
}

class _ReactorState extends State<Reactor> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = app.state;
    final on = st == ConnState.on;
    final connecting = st == ConnState.connecting;
    final color = switch (st) {
      ConnState.on => kGreen,
      ConnState.connecting => kCyan,
      ConnState.error => kDanger,
      ConnState.off => kPink,
    };
    const size = 210.0;
    return GestureDetector(
      onTap: app.busy && !connecting ? null : app.toggle,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final speed = connecting ? 4.0 : (on ? 1.0 : 0.4);
            final pulse = 0.5 + 0.5 * math.sin(_c.value * 2 * math.pi * 3);
            return SizedBox(
              width: size,
              height: size,
              child: CustomPaint(
                painter: _ReactorPainter(t: _c.value * speed, color: color, pulse: pulse, on: on),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.power_settings_new_rounded, size: 58, color: color),
                    const SizedBox(height: 6),
                    Text(
                      on ? '[ ONLINE ]' : connecting ? '[ HACKING ]' : st == ConnState.error ? '[ ERROR ]' : '[ ВЗЛОМАТЬ ]',
                      style: mono(size: 13, color: color, weight: FontWeight.w900, spacing: 1.5),
                    ),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ReactorPainter extends CustomPainter {
  final double t;
  final Color color;
  final double pulse;
  final bool on;
  _ReactorPainter({required this.t, required this.color, required this.pulse, required this.on});

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width / 2;
    // свечение
    canvas.drawCircle(
        c,
        r * 0.62,
        Paint()
          ..color = color.withOpacity(on ? 0.16 + 0.1 * pulse : 0.06)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30));
    // внутренний диск
    canvas.drawCircle(c, r * 0.6, Paint()..color = const Color(0xFF080B12));
    canvas.drawCircle(
        c,
        r * 0.6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withOpacity(0.9));
    // вращающиеся дуги
    void arcs(double rad, double width, int n, double rot, Color col) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..color = col;
      final rect = Rect.fromCircle(center: c, radius: rad);
      final seg = 2 * math.pi / n;
      for (var i = 0; i < n; i++) {
        canvas.drawArc(rect, rot + i * seg, seg * 0.55, false, p);
      }
    }

    arcs(r * 0.75, 3, 3, t * 2 * math.pi, color.withOpacity(0.85));
    arcs(r * 0.86, 1.5, 8, -t * 2 * math.pi * 0.6, kCyan.withOpacity(0.5));
    arcs(r * 0.96, 1, 24, t * 2 * math.pi * 0.3, kPink.withOpacity(0.35));
    // метки
    final tick = Paint()
      ..color = color.withOpacity(0.5)
      ..strokeWidth = 1;
    for (var i = 0; i < 36; i++) {
      final a = i * math.pi / 18;
      final p1 = c + Offset(math.cos(a), math.sin(a)) * (r * 0.66);
      final p2 = c + Offset(math.cos(a), math.sin(a)) * (r * (i % 3 == 0 ? 0.7 : 0.68));
      canvas.drawLine(p1, p2, tick);
    }
  }

  @override
  bool shouldRepaint(covariant _ReactorPainter o) => true;
}

class _Terminal extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final color = switch (app.state) {
      ConnState.on => kGreen,
      ConnState.error => kDanger,
      ConnState.connecting => kCyan,
      ConnState.off => kMuted,
    };
    final tail = app.logs.length > 3 ? app.logs.sublist(app.logs.length - 3) : app.logs;
    return Panel(
      accent: color,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('root@bespredel:~\$ ', style: mono(size: 12, color: kPink, weight: FontWeight.w700)),
          Expanded(
            child: Text(app.status,
                maxLines: 2, overflow: TextOverflow.ellipsis, style: mono(size: 12, color: color, weight: FontWeight.w700)),
          ),
        ]),
        for (final l in tail)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text('> $l',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(size: 10.5, color: kGreen.withOpacity(0.7))),
          ),
      ]),
    );
  }
}

class _ModePicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final modes = app.availableModes;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final m in modes)
          ChoiceChip(
            avatar: Icon(modeIcon(m), size: 16, color: app.mode == m ? kCyan : kMuted),
            label: Text(m.title, style: mono(size: 12, weight: FontWeight.w800, spacing: 1, color: app.mode == m ? Colors.white : kMuted)),
            selected: app.mode == m,
            showCheckmark: false,
            side: BorderSide(color: app.mode == m ? kPink : kCyan.withOpacity(0.2)),
            onSelected: app.state == ConnState.connecting
                ? null
                : (_) async {
                    final wasOn = app.connected;
                    if (wasOn) await app.disconnect();
                    app.update(() => app.mode = m);
                    if (wasOn) await app.connect();
                  },
          ),
      ]),
      const SizedBox(height: 10),
      Panel(
        accent: kPink,
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(modeIcon(app.mode), color: kPink),
          const SizedBox(width: 12),
          Expanded(child: Text(app.mode.desc, style: const TextStyle(height: 1.4, fontSize: 13))),
        ]),
      ),
    ]);
  }
}

class _ServerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = app.activeServer ?? (app.mode == BypassMode.multi ? null : app.selected);
    final multi = app.mode == BypassMode.multi || app.activeMode == BypassMode.multi;
    return Panel(
      child: Row(children: [
        Icon(multi ? Icons.hub_rounded : Icons.public_rounded, color: kCyan),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                multi
                    ? 'Пул из ${math.min(app.aliveCount, 8)} лучших серверов'
                    : s?.name ?? (app.mode == BypassMode.auto ? 'Выберется автоматически' : 'Сервер не выбран'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: mono(weight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(
              s == null || multi
                  ? 'всего: ${app.servers.length} • живых: ${app.aliveCount}'
                  : '${s.security.toUpperCase()} • ${s.network} • ${s.source}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mono(size: 11, color: kMuted),
            ),
          ]),
        ),
        if (!multi && s?.delayMs != null)
          Text('${s!.delayMs}ms', style: mono(color: pingColor(s.delayMs), weight: FontWeight.w800)),
      ]),
    );
  }
}

class _ServiceGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 560 ? 3 : 2;
      final w = (c.maxWidth - (cols - 1) * 10) / cols;
      return Wrap(spacing: 10, runSpacing: 10, children: [
        for (final s in serviceChecks) SizedBox(width: w, child: _ServiceTile(name: s.$1)),
      ]);
    });
  }
}

class _ServiceTile extends StatelessWidget {
  final String name;
  const _ServiceTile({required this.name});
  @override
  Widget build(BuildContext context) {
    final r = app.checks[name];
    final busy = app.checking.contains(name);
    Widget trailing;
    Color accent = kCyan.withOpacity(0.4);
    if (busy) {
      trailing = const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: kCyan));
    } else if (r == null) {
      trailing = Text('---', style: mono(size: 11, color: kMuted));
    } else if (r < 0) {
      accent = kDanger;
      trailing = Text('BLOCK', style: mono(size: 11, color: kDanger, weight: FontWeight.w900));
    } else {
      accent = kGreen;
      trailing = Text('OK ${r}ms', style: mono(size: 11, color: kGreen, weight: FontWeight.w800));
    }
    return Panel(
      accent: accent,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(children: [
        Expanded(child: Text(name, style: mono(size: 13, weight: FontWeight.w700))),
        trailing,
      ]),
    );
  }
}
