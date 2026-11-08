import 'package:flutter/material.dart';

import '../app_state.dart';
import '../presets.dart';
import 'theme.dart';

class MethodsPage extends StatefulWidget {
  const MethodsPage({super.key});
  @override
  State<MethodsPage> createState() => _MethodsPageState();
}

class _MethodsPageState extends State<MethodsPage> {
  late final TextEditingController _custom = TextEditingController(text: app.byedpiCustom);

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  Widget _radio({
    required bool selected,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: selected ? kRed.withOpacity(0.14) : kSurface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: selected ? kRed : kMuted, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitle, style: const TextStyle(color: kMuted, fontSize: 12)),
                      ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );

  void _changed() {
    if (app.connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Изменения применятся после переподключения')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Text('Методы обхода', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Тонкая настройка каждого способа', style: TextStyle(color: kMuted)),

          // ByeDPI
          SectionTitle('ByeDPI — стратегия',
              trailing: TextButton.icon(
                onPressed: app.busy || app.connected ? null : app.autoPickByeDpi,
                icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                label: const Text('Подобрать'),
              )),
          if (app.busy && app.busyText.contains('ByeDPI') || app.busyText.startsWith('Стратегия'))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(app.busyText, style: const TextStyle(color: kOrange, fontSize: 12)),
            ),
          for (var i = 0; i < byeDpiPresets.length; i++)
            _radio(
              selected: app.byedpiPreset == i,
              title: byeDpiPresets[i].name,
              subtitle: '${byeDpiPresets[i].desc}\n${byeDpiPresets[i].args}',
              onTap: () {
                app.update(() => app.byedpiPreset = i);
                _changed();
              },
            ),
          _radio(
            selected: app.byedpiPreset < 0,
            title: 'Своя стратегия',
            subtitle: 'Аргументы ciadpi (см. README ByeDPI)',
            onTap: () {
              app.update(() => app.byedpiPreset = -1);
              _changed();
            },
          ),
          if (app.byedpiPreset < 0)
            TextField(
              controller: _custom,
              onChanged: (v) => app.update(() => app.byedpiCustom = v),
              style: const TextStyle(fontFamily: 'monospace'),
              decoration: const InputDecoration(
                hintText: '--disorder 1 --auto=torst --tlsrec 1+s',
                border: OutlineInputBorder(),
              ),
            ),

          // Zapret
          if (app.isWindows) ...[
            const SectionTitle('Zapret (winws) — стратегия'),
            for (var i = 0; i < zapretPresets.length; i++)
              _radio(
                selected: app.zapretPreset == i,
                title: zapretPresets[i].name,
                onTap: () {
                  app.update(() => app.zapretPreset = i);
                  _changed();
                },
              ),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              activeColor: kRed,
              title: const Text('Включать DNS Comss вместе с zapret'),
              subtitle: const Text('Чтобы заодно открывались ChatGPT, Claude, Gemini',
                  style: TextStyle(color: kMuted, fontSize: 12)),
              value: app.zapretWithDns,
              onChanged: (v) => app.update(() => app.zapretWithDns = v),
            ),
            if (!app.cores.hasZapret)
              const Text('⚠ Папка cores\\zapret не найдена рядом с программой',
                  style: TextStyle(color: kOrange, fontSize: 12)),
          ],

          // DNS
          const SectionTitle('DNS'),
          for (var i = 0; i < dnsPresets.length; i++)
            _radio(
              selected: app.dnsPreset == i,
              title: '${dnsPresets[i].name}${dnsPresets[i].aiUnlock ? '  ★ ИИ' : ''}',
              subtitle: '${dnsPresets[i].desc}\n${dnsPresets[i].ips.join(', ')}',
              onTap: () {
                app.update(() => app.dnsPreset = i);
                _changed();
              },
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Text(
              'В режимах ByeDPI и DNS сайты ИИ (Claude, Gemini, ChatGPT…) всегда резолвятся через Comss — это и есть «DNS-обход» геоблока.',
              style: TextStyle(color: kMuted, fontSize: 12, height: 1.35),
            ),
          ),

          // Маршрутизация
          const SectionTitle('Маршрутизация'),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            activeColor: kRed,
            title: const Text('Российские сайты напрямую'),
            subtitle: const Text('.ru, .рф, VK, Яндекс, банки, Госуслуги — мимо VLESS/ByeDPI',
                style: TextStyle(color: kMuted, fontSize: 12)),
            value: app.ruDirect,
            onChanged: (v) {
              app.update(() => app.ruDirect = v);
              _changed();
            },
          ),
        ],
      ),
    );
  }
}
