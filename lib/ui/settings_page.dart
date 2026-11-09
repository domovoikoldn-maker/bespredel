import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../platform/android_vpn.dart';
import '../main.dart' show Logo;
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
          const PageTitle('СИСТЕМА', jp: 'システム // настройки и журнал'),
          if (app.isWindows) ...[
            const SectionTitle('Права'),
            Panel(
              accent: app.isAdmin ? kGreen : kPink,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(app.isAdmin ? '✓ Запущено от администратора' : 'Запущено без прав администратора',
                    style: mono(weight: FontWeight.w800, color: app.isAdmin ? kGreen : Colors.white)),
                const SizedBox(height: 6),
                Text(
                    app.isAdmin
                        ? 'Zapret и смена DNS работают без лишних запросов.'
                        : 'Для Zapret каждый раз будет появляться окно UAC. Проще перезапустить программу от администратора.',
                    style: mono(size: 11, color: kMuted)),
                if (!app.isAdmin) ...[
                  const SizedBox(height: 10),
                  NeonButton(
                      label: 'Перезапустить от админа',
                      icon: Icons.admin_panel_settings_rounded,
                      color: kPink,
                      onPressed: app.relaunchAsAdmin),
                ],
              ]),
            ),
          ],
          if (app.isAndroid) ...[
            const SectionTitle('Работа в фоне'),
            Panel(
              accent: kPink,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Чтобы Android не убивал Беспредел в фоне', style: mono(weight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                    '1) Разреши работу без ограничений батареи (кнопка ниже).\n'
                    '2) Xiaomi/Huawei/Honor/OPPO/realme: в настройках приложения включи «Автозапуск» и закрепи его в недавних.\n'
                    '3) Разреши уведомления — значок ключа VPN показывается вместе с уведомлением.',
                    style: mono(size: 11, color: kMuted)),
                const SizedBox(height: 10),
                NeonButton(
                  label: 'Отключить экономию батареи',
                  icon: Icons.battery_charging_full_rounded,
                  color: kPink,
                  onPressed: () => AndroidVpn.ignoreBatteryOptimizations(),
                ),
              ]),
            ),
          ],
          const SectionTitle('Интерфейс'),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: SwitchListTile(
              title: const Text('Матричный дождь на фоне'),
              subtitle: Text('Выключи, если тормозит или садится батарея', style: mono(size: 11, color: kMuted)),
              value: app.matrixRain,
              onChanged: (v) => app.update(() => app.matrixRain = v),
            ),
          ),
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
              if (app.isWindows) _core('zapret Flowseal (${app.zapretList.length} стратегий)', app.cores.hasZapret),
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
                        style: mono(size: 10.5, color: kGreen.withOpacity(0.8)),
                      ),
                    ),
            ),
          ),
          const SectionTitle('О приложении'),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Logo(size: 52),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    GlitchText('BESPREDEL', size: 20),
                    Text('ベスプレデル • v2.1.0', style: TextStyle(color: kMuted)),
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
                style: TextStyle(color: kPink, fontSize: 12, height: 1.4),
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
          Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded, color: ok ? kGreen : kDanger, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(name)),
          Text(ok ? 'найдено' : 'нет', style: TextStyle(color: ok ? kMuted : kRed, fontSize: 12)),
        ]),
      );
}
