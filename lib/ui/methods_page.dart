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
          color: selected ? kPink.withOpacity(0.12) : kSurface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(color: selected ? kPink : kCyan.withOpacity(0.12))),
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: selected ? kRed : kMuted, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: mono(weight: FontWeight.w700)),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitle, style: mono(color: kMuted, size: 11)),
                      ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );

  Future<void> _pickZapret() async {
    if (!app.isAdmin) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Нужны права администратора', style: mono(size: 16, weight: FontWeight.w800)),
          content: const Text(
              'Подбор запускает zapret 20+ раз. Чтобы не нажимать «Да» в каждом окне UAC, перезапусти Беспредел от администратора.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Перезапустить')),
          ],
        ),
      );
      if (ok == true) await app.relaunchAsAdmin();
      return;
    }
    await app.autoPickZapret();
  }

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
          const PageTitle('МЕТОДЫ', jp: 'バイパス // тонкая настройка каждого способа'),

          // Фрагментация
          const SectionTitle('Фрагментация (Xray) — профиль'),
          for (var i = 0; i < fragPresets.length; i++)
            _radio(
              selected: app.fragPreset == i,
              title: fragPresets[i].name,
              subtitle: 'packets=${fragPresets[i].packets}  length=${fragPresets[i].length}  interval=${fragPresets[i].interval}',
              onTap: () {
                app.update(() => app.fragPreset = i);
                _changed();
              },
            ),

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
            SectionTitle('Zapret — ${app.zapretList.length} стратегий Flowseal',
                trailing: TextButton.icon(
                  onPressed: app.busy || app.connected ? null : _pickZapret,
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                  label: const Text('Подобрать'),
                )),
            Panel(
              accent: kPink,
              padding: const EdgeInsets.all(12),
              child: Text(
                'Стратегии подходят не всем провайдерам. Нажми «Подобрать» — Беспредел по очереди '
                'запустит каждую и проверит видео YouTube и Discord (1–3 мин, нужны права администратора).',
                style: mono(size: 11, color: kMuted),
              ),
            ),
            const SizedBox(height: 8),
            if (app.busy && app.busyText.startsWith('Стратегия'))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(app.busyText, style: mono(color: kCyan, size: 12)),
              ),
            for (final z in app.zapretList)
              _radio(
                selected: app.zapretName == z.name,
                title: z.name,
                subtitle: app.zapretScores.containsKey(z.name)
                    ? (app.zapretScores[z.name]! < 0 ? 'не запустилась' : 'тест: ${app.zapretScores[z.name]}/4')
                    : null,
                onTap: () {
                  app.update(() => app.zapretName = z.name);
                  _changed();
                },
              ),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              activeColor: kCyan,
              title: const Text('Включать DNS Comss вместе с zapret'),
              subtitle: const Text('Чтобы заодно открывались ChatGPT, Claude, Gemini',
                  style: TextStyle(color: kMuted, fontSize: 11)),
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

          if (app.isWindows)
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text('DNS-режим: менять ещё и DNS Windows'),
              subtitle: Text('Чтобы ИИ-сервисы открывались во всех программах, а не только в браузере. Нужен админ.',
                  style: mono(color: kMuted, size: 11)),
              value: app.winSystemDns,
              onChanged: (v) => app.update(() => app.winSystemDns = v),
            ),
          if (app.isWindows)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Text(
                '⚠ Если ИИ-сайты не открываются, отключи в браузере «Безопасный DNS» (Chrome/Edge: Настройки → Конфиденциальность → Безопасность). Иначе браузер обходит DNS Беспредела.',
                style: mono(color: const Color(0xFFFFD166), size: 11),
              ),
            ),

          // Маршрутизация
          const SectionTitle('Маршрутизация'),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            activeColor: kCyan,
            title: const Text('Российские сайты напрямую'),
            subtitle: const Text('.ru, .рф, VK, Яндекс, банки, Госуслуги — мимо VLESS/ByeDPI',
                style: TextStyle(color: kMuted, fontSize: 11)),
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
