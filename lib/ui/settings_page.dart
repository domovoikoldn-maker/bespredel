import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import 'theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Text('Ещё', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SectionTitle('Проверка серверов'),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Адрес для теста задержки', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButton<String>(
                isExpanded: true,
                value: app.testUrl,
                items: const [
                  DropdownMenuItem(
                      value: 'https://www.gstatic.com/generate_204', child: Text('Google (generate_204)')),
                  DropdownMenuItem(
                      value: 'https://cp.cloudflare.com/generate_204', child: Text('Cloudflare (generate_204)')),
                  DropdownMenuItem(
                      value: 'https://www.youtube.com/generate_204', child: Text('YouTube (generate_204)')),
                ],
                onChanged: (v) => app.update(() => app.testUrl = v ?? app.testUrl),
              ),
            ]),
          ),
          const SectionTitle('Ядра'),
          Panel(
            child: Column(children: [
              _core('Xray-core (VLESS+Reality)', app.cores.hasXray),
              _core('ByeDPI (ciadpi)', app.cores.hasCiadpi),
              if (app.isWindows) _core('zapret (winws + WinDivert)', app.cores.hasZapret),
              if (app.isAndroid) _core('hev-socks5-tunnel (VPN)', true),
            ]),
          ),
          SectionTitle('Журнал',
              trailing: TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: app.logs.join('\n')));
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Журнал скопирован')));
                },
                child: const Text('Копировать'),
              )),
          Panel(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              height: 220,
              child: app.logs.isEmpty
                  ? const Center(child: Text('Пусто', style: TextStyle(color: kMuted)))
                  : ListView.builder(
                      reverse: true,
                      itemCount: app.logs.length,
                      itemBuilder: (_, i) => Text(
                        app.logs[app.logs.length - 1 - i],
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white70),
                      ),
                    ),
            ),
          ),
          const SectionTitle('О приложении'),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(gradient: kGradient, borderRadius: BorderRadius.circular(16)),
                  alignment: Alignment.center,
                  child: const Text('Б',
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Беспредел', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    Text('версия 1.0.0', style: TextStyle(color: kMuted)),
                  ]),
                ),
              ]),
              const SizedBox(height: 14),
              const Text('Разработчик: domovoi4ik', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              const Text(
                'Использует открытые проекты: Xray-core (XTLS), ByeDPI (hufrea), zapret (bol-van), '
                'hev-socks5-tunnel (heiher). Конфиги — из открытых репозиториев GitHub '
                '(igareck/vpn-configs-for-russia и др.). DNS для ИИ — Comss.one.',
                style: TextStyle(color: kMuted, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 10),
              const Text(
                'Публичные серверы принадлежат неизвестным людям: не вводи через них пароли от банков и важных аккаунтов без HTTPS.',
                style: TextStyle(color: kOrange, fontSize: 12, height: 1.4),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _core(String name, bool ok) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded, color: ok ? kGreen : kRed, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(name)),
          Text(ok ? 'найдено' : 'нет', style: TextStyle(color: ok ? kMuted : kRed, fontSize: 12)),
        ]),
      );
}
