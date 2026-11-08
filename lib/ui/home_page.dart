import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../presets.dart';
import 'theme.dart';

IconData modeIcon(BypassMode m) => const {
      BypassMode.auto: Icons.auto_awesome_rounded,
      BypassMode.vless: Icons.vpn_lock_rounded,
      BypassMode.byedpi: Icons.bolt_rounded,
      BypassMode.zapret: Icons.shield_rounded,
      BypassMode.dns: Icons.travel_explore_rounded,
    }[m]!;

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const _Header(),
          const SizedBox(height: 18),
          Center(child: PowerButton()),
          const SizedBox(height: 16),
          _StatusLine(),
          if (app.busy) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: app.progress > 0 ? app.progress : null,
              color: kOrange,
              backgroundColor: kSurface2,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 6),
            Text(app.busyText, textAlign: TextAlign.center, style: const TextStyle(color: kMuted, fontSize: 12)),
          ],
          const SectionTitle('Способ обхода'),
          _ModePicker(),
          if (app.mode == BypassMode.vless || app.mode == BypassMode.auto) ...[
            const SectionTitle('Сервер'),
            _ServerCard(),
          ],
          SectionTitle('Доступ к сервисам',
              trailing: TextButton.icon(
                onPressed: app.checking.isEmpty ? app.checkServices : null,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Проверить'),
              )),
          _ServiceGrid(),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) => Row(children: [
        ShaderMask(
          shaderCallback: (r) => kGradient.createShader(r),
          child: const Text('БЕСПРЕДЕЛ',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white)),
        ),
        const Spacer(),
        const Text('by domovoi4ik', style: TextStyle(color: kMuted, fontSize: 12)),
      ]);
}

class PowerButton extends StatefulWidget {
  const PowerButton({super.key});
  @override
  State<PowerButton> createState() => _PowerButtonState();
}

class _PowerButtonState extends State<PowerButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

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
    const size = 190.0;
    return GestureDetector(
      onTap: app.busy && !connecting ? null : app.toggle,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final glow = on ? 0.45 + 0.15 * math.sin(_c.value * 2 * math.pi) : 0.0;
          return Stack(alignment: Alignment.center, children: [
            if (connecting)
              Transform.rotate(
                angle: _c.value * 2 * math.pi,
                child: Container(
                  width: size + 18,
                  height: size + 18,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(colors: [Colors.transparent, kOrange, kRed, Colors.transparent]),
                  ),
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: on ? kGradient : null,
                color: on ? null : kSurface2,
                border: Border.all(color: on ? Colors.white24 : Colors.white10, width: 2),
                boxShadow: [
                  if (on) BoxShadow(color: kRed.withOpacity(glow), blurRadius: 60, spreadRadius: 6),
                ],
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.power_settings_new_rounded,
                    size: 72, color: on ? Colors.white : (st == ConnState.error ? kRed : Colors.white70)),
                const SizedBox(height: 6),
                Text(
                  on
                      ? 'ВКЛЮЧЕНО'
                      : connecting
                          ? 'ПОДКЛЮЧЕНИЕ'
                          : 'ВКЛЮЧИТЬ',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: on ? Colors.white : Colors.white70),
                ),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final color = switch (app.state) {
      ConnState.on => kGreen,
      ConnState.error => kRed,
      ConnState.connecting => kOrange,
      ConnState.off => kMuted,
    };
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(app.status,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ),
      ]),
    ]);
  }
}

class _ModePicker extends StatelessWidget {
  const _ModePicker();
  @override
  Widget build(BuildContext context) {
    final modes = app.availableModes;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final m in modes)
          ChoiceChip(
            avatar: Icon(modeIcon(m), size: 18, color: app.mode == m ? kOrange : kMuted),
            label: Text(m.title),
            selected: app.mode == m,
            showCheckmark: false,
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
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(modeIcon(app.mode), color: kOrange),
          const SizedBox(width: 12),
          Expanded(child: Text(app.mode.desc, style: const TextStyle(height: 1.35))),
        ]),
      ),
    ]);
  }
}

class _ServerCard extends StatelessWidget {
  const _ServerCard();
  @override
  Widget build(BuildContext context) {
    final s = app.activeServer ?? app.selected;
    return Panel(
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: kSurface2, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.public_rounded, color: kOrange),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s?.name ?? (app.mode == BypassMode.auto ? 'Выберется автоматически' : 'Сервер не выбран'),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
              s == null
                  ? 'Всего: ${app.servers.length}, рабочих: ${app.aliveCount}'
                  : '${s.security.toUpperCase()} • ${s.network} • ${s.source}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: kMuted, fontSize: 12),
            ),
          ]),
        ),
        if (s?.delayMs != null)
          Text('${s!.delayMs} мс', style: TextStyle(color: pingColor(s.delayMs), fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid();
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 560 ? 3 : 2;
      final w = (c.maxWidth - (cols - 1) * 10) / cols;
      return Wrap(spacing: 10, runSpacing: 10, children: [
        for (final s in serviceChecks)
          SizedBox(width: w, child: _ServiceTile(name: s.$1)),
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
    if (busy) {
      trailing = const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
    } else if (r == null) {
      trailing = const Icon(Icons.remove_rounded, color: kMuted, size: 18);
    } else if (r < 0) {
      trailing = const Icon(Icons.close_rounded, color: kRed, size: 20);
    } else {
      trailing = Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$r мс', style: const TextStyle(color: kMuted, fontSize: 11)),
        const SizedBox(width: 4),
        const Icon(Icons.check_circle_rounded, color: kGreen, size: 18),
      ]);
    }
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
        trailing,
      ]),
    );
  }
}
