import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'ui/home_page.dart';
import 'ui/methods_page.dart';
import 'ui/servers_page.dart';
import 'ui/settings_page.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Сначала показываем интерфейс, инициализация — в фоне (если что-то упадёт,
  // приложение всё равно откроется и покажет ошибку, а не закроется).
  runApp(const BespredelApp());
  app.init();
}

class BespredelApp extends StatelessWidget {
  const BespredelApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'BESPREDEL',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: ListenableBuilder(
          listenable: app,
          builder: (context, _) => app.ready ? const Shell() : const Splash(),
        ),
      );
}

class Splash extends StatelessWidget {
  const Splash({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBg,
        body: CyberBackground(
          rain: true,
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const GlitchText('BESPREDEL', size: 34),
              const SizedBox(height: 8),
              Text('ベスプレデル // by domovoi4ik', style: mono(size: 12, color: kMuted, spacing: 3)),
              const SizedBox(height: 28),
              const SizedBox(
                width: 160,
                child: LinearProgressIndicator(color: kPink, backgroundColor: kSurface2, minHeight: 2),
              ),
              const SizedBox(height: 10),
              Text('> init cores...', style: mono(size: 12, color: kGreen)),
            ]),
          ),
        ),
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
    (Icons.power_settings_new_rounded, 'ВЗЛОМ'),
    (Icons.dns_rounded, 'СЕРВЕРЫ'),
    (Icons.tune_rounded, 'МЕТОДЫ'),
    (Icons.terminal_rounded, 'СИСТЕМА'),
  ];

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onExitRequested: () async {
      if (app.connected) await app.disconnect(silent: true);
      return AppExitResponse.exit;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _startupDialogs());
  }

  Future<void> _startupDialogs() async {
    if (app.initError.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка запуска: ${app.initError}')));
    }
    if (!app.isWindows || !app.dnsWasLeftChanged) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('DNS не восстановлен', style: mono(size: 16, weight: FontWeight.w800)),
        content: const Text('Прошлый сеанс завершился аварийно, DNS Windows остался изменённым. Вернуть по умолчанию?'),
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
      duration: const Duration(milliseconds: 200),
      child: KeyedSubtree(key: ValueKey(_tab), child: _pages[_tab]),
    );
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final content = CyberBackground(
          rain: app.matrixRain,
          child: wide
              ? Row(children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xF2070A10),
                      border: Border(right: BorderSide(color: kCyan.withOpacity(0.15))),
                    ),
                    child: NavigationRail(
                      backgroundColor: Colors.transparent,
                      selectedIndex: _tab,
                      onDestinationSelected: (i) => setState(() => _tab = i),
                      labelType: NavigationRailLabelType.all,
                      indicatorColor: kPink.withOpacity(0.18),
                      selectedIconTheme: const IconThemeData(color: kCyan),
                      unselectedIconTheme: const IconThemeData(color: kMuted),
                      selectedLabelTextStyle: mono(size: 11, color: kCyan, spacing: 1),
                      unselectedLabelTextStyle: mono(size: 11, color: kMuted, spacing: 1),
                      leading: const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Logo(size: 44)),
                      destinations: [
                        for (final d in _dest) NavigationRailDestination(icon: Icon(d.$1), label: Text(d.$2)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 880), child: body),
                    ),
                  ),
                ])
              : SafeArea(child: body),
        );
        return Scaffold(
          backgroundColor: kBg,
          body: content,
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _tab,
                  onDestinationSelected: (i) => setState(() => _tab = i),
                  destinations: [
                    for (final d in _dest) NavigationDestination(icon: Icon(d.$1), label: d.$2),
                  ],
                ),
        );
      },
    );
  }
}

class Logo extends StatelessWidget {
  final double size;
  const Logo({super.key, required this.size});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.circular(size * 0.18),
          border: Border.all(color: kPink, width: 1.5),
          boxShadow: [BoxShadow(color: kPink.withOpacity(0.45), blurRadius: 14)],
        ),
        alignment: Alignment.center,
        child: Stack(alignment: Alignment.center, children: [
          Transform.translate(
              offset: const Offset(-1.5, 0),
              child: Text('B', style: mono(size: size * 0.55, color: kCyan, weight: FontWeight.w900))),
          Transform.translate(
              offset: const Offset(1.5, 0),
              child: Text('B', style: mono(size: size * 0.55, color: kPink, weight: FontWeight.w900))),
          Text('B', style: mono(size: size * 0.55, weight: FontWeight.w900)),
        ]),
      );
}
