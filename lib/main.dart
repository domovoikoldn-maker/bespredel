import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'ui/home_page.dart';
import 'ui/methods_page.dart';
import 'ui/servers_page.dart';
import 'ui/settings_page.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.init();
  runApp(const BespredelApp());
}

class BespredelApp extends StatelessWidget {
  const BespredelApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Беспредел',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const Shell(),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;
  late final AppLifecycleListener _life;

  static const _pages = [HomePage(), ServersPage(), MethodsPage(), SettingsPage()];
  static const _dest = [
    (Icons.power_settings_new_rounded, 'Главная'),
    (Icons.dns_rounded, 'Серверы'),
    (Icons.tune_rounded, 'Методы'),
    (Icons.settings_rounded, 'Ещё'),
  ];

  @override
  void initState() {
    super.initState();
    // При закрытии окна на Windows — снять прокси/DNS и остановить ядра
    _life = AppLifecycleListener(onExitRequested: () async {
      if (app.connected) await app.disconnect(silent: true);
      return AppExitResponse.exit;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _askDnsRestore());
  }

  Future<void> _askDnsRestore() async {
    if (!app.isWindows || !app.dnsWasLeftChanged) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('DNS не был восстановлен'),
        content: const Text(
            'Похоже, прошлый сеанс завершился аварийно и DNS остался изменённым. Вернуть DNS по умолчанию?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Оставить')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Вернуть')),
        ],
      ),
    );
    if (ok == true) await app.restoreDnsAfterCrash();
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 820;
    final body = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: KeyedSubtree(key: ValueKey(_tab), child: _pages[_tab]),
    );
    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            backgroundColor: kSurface,
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            labelType: NavigationRailLabelType.all,
            indicatorColor: kRed.withOpacity(0.22),
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: _Logo(size: 42),
            ),
            destinations: [
              for (final d in _dest)
                NavigationRailDestination(icon: Icon(d.$1), label: Text(d.$2)),
            ],
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 860), child: body),
            ),
          ),
        ]),
      );
    }
    return Scaffold(
      body: SafeArea(child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          for (final d in _dest) NavigationDestination(icon: Icon(d.$1), label: d.$2),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  final double size;
  const _Logo({required this.size});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(gradient: kGradient, borderRadius: BorderRadius.circular(size * 0.3)),
        alignment: Alignment.center,
        child: Text('Б',
            style: TextStyle(fontSize: size * 0.55, fontWeight: FontWeight.w900, color: Colors.white)),
      );
}
