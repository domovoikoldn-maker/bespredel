// Главное состояние приложения: серверы, режимы, подключение.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'core_runner.dart';
import 'models.dart';
import 'platform/android_vpn.dart';
import 'platform/windows_net.dart';
import 'presets.dart';
import 'xray_config.dart';

enum ConnState { off, connecting, on, error }

final app = AppState();

class AppState extends ChangeNotifier {
  late Directory dataDir;
  final cores = CoreRunner();

  // Настройки
  List<SubSource> sources = buildDefaultSources();
  List<VlessServer> servers = [];
  String? selectedKey;
  BypassMode mode = BypassMode.auto;
  int byedpiPreset = 0;
  String byedpiCustom = '';
  int zapretPreset = 0;
  int dnsPreset = 0;
  bool ruDirect = true;
  bool onlyReality = false;
  bool zapretWithDns = true;
  bool winSystemDns = false; // DNS-режим: менять ещё и DNS Windows (нужен админ)
  int fragPreset = 0;
  bool matrixRain = true;
  bool isAdmin = false;
  String initError = '';
  bool ready = false;
  String testUrl = 'https://www.gstatic.com/generate_204';
  bool _proxyLeft = false;
  bool _dnsLeft = false;

  // Состояние
  ConnState state = ConnState.off;
  String status = 'Отключено';
  BypassMode? activeMode;
  VlessServer? activeServer;
  bool busy = false;
  String busyText = '';
  double progress = 0;
  final logs = <String>[];
  final checks = <String, int?>{}; // результат проверки сервисов
  final checking = <String>{};

  ManagedProc? _xray;
  ManagedProc? _dpi;
  bool _zapretOn = false;
  bool _dnsOn = false;
  bool _vpnOn = false;

  bool get isWindows => Platform.isWindows;
  bool get isAndroid => Platform.isAndroid;
  bool get connected => state == ConnState.on;

  List<BypassMode> get availableModes => [
        BypassMode.auto,
        BypassMode.vless,
        BypassMode.multi,
        BypassMode.fragment,
        BypassMode.byedpi,
        if (isWindows) BypassMode.zapret,
        BypassMode.dns,
      ];

  DnsPreset get dns => dnsPresets[math.min(math.max(dnsPreset, 0), dnsPresets.length - 1)];

  FragPreset get frag => fragPresets[math.min(math.max(fragPreset, 0), fragPresets.length - 1)];

  String get byedpiArgs => byedpiPreset < 0
      ? byedpiCustom
      : byeDpiPresets[math.min(byedpiPreset, byeDpiPresets.length - 1)].args;

  VlessServer? get selected {
    for (final s in servers) {
      if (s.key == selectedKey) return s;
    }
    return null;
  }

  List<VlessServer> get visibleServers {
    final l = servers.where((s) => !onlyReality || s.isReality).toList();
    int score(VlessServer s) {
      if (s.alive) return s.delayMs!;
      if (s.tested) return 900000 + (s.tcpMs ?? 99999);
      if (s.tcpMs != null) return 100000 + s.tcpMs!;
      return 800000;
    }

    l.sort((a, b) => score(a).compareTo(score(b)));
    return l;
  }

  int get aliveCount => servers.where((s) => s.alive).length;

  void log(String l) {
    final t = DateTime.now();
    final ts = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
    logs.add('$ts $l');
    if (logs.length > 600) logs.removeRange(0, logs.length - 600);
    if (kDebugMode) debugPrint(l);
  }

  void _busy(String text, [double p = 0]) {
    busy = true;
    busyText = text;
    progress = p;
    notifyListeners();
  }

  void _idle() {
    busy = false;
    busyText = '';
    progress = 0;
    notifyListeners();
  }

  // ---------- Инициализация и сохранение ----------

  Future<void> init() async {
    try {
      await _init();
    } catch (e, st) {
      initError = '$e';
      log('Ошибка запуска: $e\n$st');
    }
    ready = true;
    notifyListeners();
  }

  Future<void> _init() async {
    try {
      dataDir = await getApplicationSupportDirectory();
    } catch (_) {
      dataDir = Directory.systemTemp;
    }
    await dataDir.create(recursive: true);
    WinNet.tmp = dataDir;
    WinNet.log = log;
    cores.log = log;
    try {
      await cores.init(dataDir);
    } catch (e) {
      log('Ошибка инициализации ядер: $e');
    }
    await _load();
    if (isWindows) {
      // восстановление после аварийного закрытия
      await WinNet.killOwnCores();
      isAdmin = await WinNet.isAdmin();
      if (_proxyLeft) {
        await WinNet.clearProxy();
        _proxyLeft = false;
      }
    }
    if (isAndroid) {
      try {
        if (await AndroidVpn.isRunning()) await AndroidVpn.stop();
      } catch (e) {
        log('VPN: $e');
      }
    }
    log('Беспредел запущен. Ядра: xray=${cores.hasXray}, byedpi=${cores.hasCiadpi}'
        '${isWindows ? ', zapret=${cores.hasZapret}' : ''}');
    await save();
  }

  File get _settingsFile => File('${dataDir.path}${Platform.pathSeparator}settings.json');

  Future<void> _load() async {
    try {
      if (!_settingsFile.existsSync()) return;
      final j = jsonDecode(await _settingsFile.readAsString()) as Map<String, dynamic>;
      final src = (j['sources'] as List?)?.map((e) => SubSource.fromJson(e as Map<String, dynamic>)).toList();
      if (src != null && src.isNotEmpty) {
        // добавляем новые встроенные источники из обновлений
        final urls = src.map((s) => s.url).toSet();
        for (final d in buildDefaultSources()) {
          if (!urls.contains(d.url)) src.add(d..enabled = false);
        }
        sources = src;
      }
      servers = ((j['servers'] as List?) ?? [])
          .map((e) => VlessServer.fromJson(e as Map<String, dynamic>))
          .whereType<VlessServer>()
          .toList();
      selectedKey = j['selected'] as String?;
      mode = BypassMode.values.firstWhere((m) => m.name == j['mode'], orElse: () => BypassMode.auto);
      if (!availableModes.contains(mode)) mode = BypassMode.auto;
      byedpiPreset = (j['byedpiPreset'] ?? 0) as int;
      byedpiCustom = (j['byedpiCustom'] ?? '') as String;
      zapretPreset = (j['zapretPreset'] ?? 0) as int;
      dnsPreset = (j['dnsPreset'] ?? 0) as int;
      ruDirect = (j['ruDirect'] ?? true) as bool;
      onlyReality = (j['onlyReality'] ?? false) as bool;
      zapretWithDns = (j['zapretWithDns'] ?? true) as bool;
      winSystemDns = (j['winSystemDns'] ?? false) as bool;
      fragPreset = (j['fragPreset'] ?? 0) as int;
      matrixRain = (j['matrixRain'] ?? true) as bool;
      testUrl = (j['testUrl'] ?? testUrl) as String;
      _proxyLeft = (j['proxyLeft'] ?? false) as bool;
      _dnsLeft = (j['dnsLeft'] ?? false) as bool;
    } catch (e) {
      log('Не удалось прочитать настройки: $e');
    }
  }

  Future<void> save() async {
    final j = {
      'sources': sources.map((s) => s.toJson()).toList(),
      'servers': servers.take(3000).map((s) => s.toJson()).toList(),
      'selected': selectedKey,
      'mode': mode.name,
      'byedpiPreset': byedpiPreset,
      'byedpiCustom': byedpiCustom,
      'zapretPreset': zapretPreset,
      'dnsPreset': dnsPreset,
      'ruDirect': ruDirect,
      'onlyReality': onlyReality,
      'zapretWithDns': zapretWithDns,
      'winSystemDns': winSystemDns,
      'fragPreset': fragPreset,
      'matrixRain': matrixRain,
      'testUrl': testUrl,
      'proxyLeft': _proxyLeft,
      'dnsLeft': _dnsLeft,
    };
    try {
      await _settingsFile.writeAsString(jsonEncode(j));
    } catch (e) {
      log('Не удалось сохранить настройки: $e');
    }
  }

  void update(void Function() f) {
    f();
    notifyListeners();
    save();
  }

  bool get dnsWasLeftChanged => _dnsLeft;

  Future<void> restoreDnsAfterCrash() async {
    await WinNet.resetDns();
    _dnsLeft = false;
    await save();
    notifyListeners();
  }

  // ---------- Сборщик серверов ----------

  Future<String> _fetch(String url) async {
    Object? lastErr;
    for (final u in mirrorsFor(url)) {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      if (_xray != null && !_xray!.exited) {
        client.findProxy = (_) => 'PROXY 127.0.0.1:$kHttpPort';
      }
      try {
        final req = await client.getUrl(Uri.parse(u)).timeout(const Duration(seconds: 12));
        final resp = await req.close().timeout(const Duration(seconds: 20));
        if (resp.statusCode != 200) {
          await resp.drain<void>();
          lastErr = 'HTTP ${resp.statusCode}';
          continue;
        }
        final body = await resp
            .transform(const Utf8Decoder(allowMalformed: true))
            .join()
            .timeout(const Duration(seconds: 40));
        return body;
      } catch (e) {
        lastErr = e;
      } finally {
        client.close(force: true);
      }
    }
    throw Exception(lastErr?.toString() ?? 'нет ответа');
  }

  /// Скачать все включённые подписки и собрать список VLESS.
  Future<void> updateServers() async {
    if (busy) return;
    final enabled = sources.where((s) => s.enabled).toList();
    if (enabled.isEmpty) {
      status = 'Включи хотя бы один источник';
      notifyListeners();
      return;
    }
    _busy('Скачиваю подписки…');
    final old = {for (final s in servers) s.key: s};
    final fresh = <String, VlessServer>{};
    var done = 0;
    await Future.wait(enabled.map((src) async {
      try {
        final body = await _fetch(src.url);
        final list = parseSubscription(body).where((s) => s.valid).toList();
        src.lastCount = list.length;
        src.lastError = null;
        for (final s in list) {
          s.source = src.name;
          final prev = old[s.key];
          if (prev != null) {
            s.tcpMs = prev.tcpMs;
            s.delayMs = prev.delayMs;
            s.tested = prev.tested;
          }
          fresh.putIfAbsent(s.key, () => s);
        }
        log('Источник «${src.name}»: ${list.length} VLESS');
      } catch (e) {
        src.lastError = e.toString();
        log('Источник «${src.name}»: ошибка $e');
      }
      done++;
      progress = done / enabled.length;
      notifyListeners();
    }));
    // ручные серверы сохраняем
    for (final s in old.values.where((s) => s.source == 'Вручную')) {
      fresh.putIfAbsent(s.key, () => s);
    }
    if (fresh.isNotEmpty) servers = fresh.values.toList();
    _idle();
    status = 'Собрано серверов: ${servers.length}';
    await save();
    notifyListeners();
  }

  bool addManual(String text) {
    var added = 0;
    for (final s in parseSubscription(text)) {
      if (!s.valid) continue;
      s.source = 'Вручную';
      servers.removeWhere((e) => e.key == s.key);
      servers.insert(0, s);
      added++;
    }
    if (added > 0) {
      notifyListeners();
      save();
    }
    return added > 0;
  }

  Future<void> tcpPingAll() async {
    final list = servers.toList();
    const chunk = 48;
    for (var i = 0; i < list.length; i += chunk) {
      final part = list.sublist(i, math.min(i + chunk, list.length));
      await Future.wait(part.map((s) async => s.tcpMs = await tcpPing(s.host, s.port)));
      progress = (i + part.length) / list.length;
      busyText = 'TCP-пинг: ${i + part.length}/${list.length}';
      notifyListeners();
    }
  }

  /// Реальная проверка серверов через Xray (пакетами).
  Future<void> testServers({int limit = 150}) async {
    if (busy) return;
    if (!cores.hasXray) {
      status = 'Ядро Xray не найдено';
      notifyListeners();
      return;
    }
    _busy('TCP-пинг…');
    await tcpPingAll();
    var list = visibleServers.where((s) => s.tcpMs != null).toList()
      ..sort((a, b) => a.tcpMs!.compareTo(b.tcpMs!));
    for (final s in servers.where((s) => s.tcpMs == null)) {
      s.tested = true;
      s.delayMs = null;
    }
    if (list.length > limit) list = list.sublist(0, limit);
    const batch = 25;
    for (var i = 0; i < list.length; i += batch) {
      final part = list.sublist(i, math.min(i + batch, list.length));
      busyText = 'Проверка через ядро: ${i + part.length}/${list.length}';
      progress = (i + part.length) / list.length;
      notifyListeners();
      await _testBatch(part);
    }
    final alive = aliveCount;
    _idle();
    status = 'Рабочих серверов: $alive';
    final best = visibleServers.firstOrNull;
    if (best != null && best.alive && (selected == null || !selected!.alive)) {
      selectedKey = best.key;
    }
    await save();
    notifyListeners();
  }

  Future<void> _testBatch(List<VlessServer> b) async {
    ManagedProc? p;
    try {
      p = await cores.startXray(buildTestConfig(b, kTestBasePort), 'xray-test');
    } catch (e) {
      log('Тест: $e');
    }
    if (p == null) {
      if (b.length > 1) {
        final h = b.length ~/ 2;
        await _testBatch(b.sublist(0, h));
        await _testBatch(b.sublist(h));
      } else {
        b.first
          ..tested = true
          ..delayMs = null;
      }
      return;
    }
    await Future.wait([
      for (var i = 0; i < b.length; i++)
        httpProbe(testUrl, proxyPort: kTestBasePort + i, timeoutSec: 7).then((ms) {
          b[i]
            ..tested = true
            ..delayMs = ms;
        })
    ]);
    await p.kill();
    notifyListeners();
  }

  // ---------- Подключение ----------

  Future<void> toggle() async {
    if (state == ConnState.connecting) return;
    if (connected) {
      await disconnect();
    } else {
      await connect();
    }
  }

  Future<void> connect() async {
    if (busy) return;
    state = ConnState.connecting;
    status = 'Подключаюсь…';
    checks.clear();
    notifyListeners();
    try {
      var m = mode;
      if (m == BypassMode.auto) m = await _resolveAuto();
      activeMode = m;
      switch (m) {
        case BypassMode.vless:
          await _connectVless();
          break;
        case BypassMode.multi:
          await _connectMulti();
          break;
        case BypassMode.fragment:
          await _startXrayMain(XrayMain.fragment);
          await _attachSystem(dnsOnly: false);
          break;
        case BypassMode.byedpi:
          await _connectByeDpi();
          break;
        case BypassMode.zapret:
          await _connectZapret();
          break;
        case BypassMode.dns:
          await _connectDns();
          break;
        case BypassMode.auto:
          break;
      }
      state = ConnState.on;
      status = _statusText(m);
      log('Подключено: $status');
      notifyListeners();
      unawaited(checkServices());
    } catch (e) {
      log('Ошибка подключения: $e');
      await disconnect(silent: true);
      state = ConnState.error;
      status = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  String _statusText(BypassMode m) {
    switch (m) {
      case BypassMode.vless:
        return 'VLESS • ${activeServer?.name ?? ''}';
      case BypassMode.multi:
        return 'МУЛЬТИ • ${_multiCount} серверов, автопереключение';
      case BypassMode.fragment:
        return 'ФРАГМЕНТ • ${frag.name}';
      case BypassMode.byedpi:
        return 'ByeDPI • ${byedpiPreset < 0 ? 'своя стратегия' : byeDpiPresets[byedpiPreset].name}';
      case BypassMode.zapret:
        return 'Zapret • ${zapretPresets[zapretPreset].name}';
      case BypassMode.dns:
        return 'DNS • ${dns.name}';
      case BypassMode.auto:
        return 'Авто';
    }
  }

  Future<BypassMode> _resolveAuto() async {
    status = 'Авто: ищу рабочий сервер…';
    notifyListeners();
    if (servers.isEmpty) await updateServers();
    if (servers.isNotEmpty && aliveCount == 0) {
      await testServers(limit: 60);
    }
    final alive = visibleServers.where((s) => s.alive).toList();
    if (alive.length >= 2) return BypassMode.multi;
    if (alive.isNotEmpty) {
      if (selected == null || !selected!.alive) selectedKey = alive.first.key;
      return BypassMode.vless;
    }
    log('Авто: рабочих VLESS нет, включаю фрагментацию + DNS для ИИ');
    return BypassMode.fragment;
  }

  int _multiCount = 0;

  Future<void> _connectMulti() async {
    var pool = visibleServers.where((s) => s.alive).take(8).toList();
    if (pool.isEmpty) {
      await testServers(limit: 80);
      pool = visibleServers.where((s) => s.alive).take(8).toList();
    }
    if (pool.isEmpty) throw Exception('Нет рабочих серверов. Попробуй режим ФРАГМЕНТ или ByeDPI');
    _multiCount = pool.length;
    activeServer = null;
    await _startXrayMain(XrayMain.multi, pool: pool);
    await _attachSystem(dnsOnly: false);
  }

  Future<void> _startXrayMain(XrayMain kind, {VlessServer? server, List<VlessServer> pool = const []}) async {
    final cfg = buildMainConfig(
        kind: kind, server: server, pool: pool, dns: dns, ruDirect: ruDirect, frag: frag, testUrl: testUrl);
    _xray = await cores.startXray(cfg, 'xray');
    if (_xray == null) {
      throw Exception('Xray не запустился — смотри журнал');
    }
  }

  Future<void> _attachSystem({required bool dnsOnly}) async {
    if (isWindows) {
      await WinNet.setProxy(kHttpPort);
      _proxyLeft = true;
      await save();
    } else if (isAndroid) {
      final ok = await AndroidVpn.prepare();
      if (!ok) throw Exception('Нет разрешения на VPN');
      await AndroidVpn.start(socksPort: kSocksPort, dnsOnly: dnsOnly, title: 'Беспредел • ${activeMode?.title}');
      _vpnOn = true;
    }
  }

  Future<void> _connectVless() async {
    var s = selected;
    if (s == null) {
      s = visibleServers.where((x) => x.alive).firstOrNull ?? visibleServers.firstOrNull;
      if (s == null) throw Exception('Нет серверов. Открой «Серверы» → «Обновить»');
      selectedKey = s.key;
    }
    activeServer = s;
    await _startXrayMain(XrayMain.vless, server: s);
    await _attachSystem(dnsOnly: false);
  }

  Future<void> _connectByeDpi() async {
    _dpi = await cores.startCiadpi(kByeDpiPort, byedpiArgs);
    if (_dpi == null) throw Exception('ByeDPI не запустился — проверь аргументы стратегии');
    await _startXrayMain(XrayMain.byedpi);
    await _attachSystem(dnsOnly: false);
  }

  Future<void> _connectZapret() async {
    if (!cores.hasZapret) throw Exception('zapret не найден в папке cores');
    final args = zapretPresets[zapretPreset]
        .args
        .replaceAll('%BIN%', cores.zapretBin)
        .replaceAll('%LIST%', cores.zapretList);
    status = isAdmin ? 'Запускаю winws…' : 'Подтверди запуск от администратора…';
    notifyListeners();
    final err = await WinNet.startZapret(cores.winwsPath, args, cores.zapretDir);
    if (err != null) throw Exception(err);
    _zapretOn = true;
    if (zapretWithDns) {
      final dnsOk = await WinNet.setDns(dnsPresets.firstWhere((d) => d.aiUnlock));
      if (dnsOk) {
        _dnsOn = true;
        _dnsLeft = true;
        await save();
      }
    }
  }

  Future<void> _connectDns() async {
    await _startXrayMain(XrayMain.dnsOnly);
    await _attachSystem(dnsOnly: true);
    if (isWindows && winSystemDns) {
      final ok = await WinNet.setDns(dns);
      if (ok) {
        _dnsOn = true;
        _dnsLeft = true;
        await save();
      } else {
        log('DNS Windows не изменён (нет прав администратора) — работает через прокси');
      }
    }
  }

  Future<void> disconnect({bool silent = false}) async {
    if (!silent) {
      status = 'Отключаюсь…';
      notifyListeners();
    }
    try {
      if (_vpnOn) {
        await AndroidVpn.stop();
        _vpnOn = false;
      }
      if (isWindows && _proxyLeft) {
        await WinNet.clearProxy();
        _proxyLeft = false;
      }
      await _xray?.kill();
      _xray = null;
      await _dpi?.kill();
      _dpi = null;
      if (_zapretOn) {
        await WinNet.stopZapret();
        _zapretOn = false;
      }
      if (_dnsOn) {
        await WinNet.resetDns();
        _dnsOn = false;
        _dnsLeft = false;
      }
    } catch (e) {
      log('Ошибка при отключении: $e');
    }
    await save();
    if (!silent) {
      state = ConnState.off;
      status = 'Отключено';
      activeMode = null;
      activeServer = null;
      checks.clear();
      notifyListeners();
    }
  }

  /// Переключиться на другой сервер на лету.
  Future<void> selectServer(VlessServer s) async {
    selectedKey = s.key;
    notifyListeners();
    await save();
    if (connected && activeMode == BypassMode.vless) {
      await _xray?.kill();
      try {
        activeServer = s;
        await _startXrayMain(XrayMain.vless, server: s);
        status = _statusText(BypassMode.vless);
        unawaited(checkServices());
      } catch (e) {
        log('$e');
        await disconnect();
      }
      notifyListeners();
    }
  }

  // ---------- Проверка сервисов ----------

  Future<void> checkServices() async {
    final viaProxy = _xray != null && !_xray!.exited;
    for (final c in serviceChecks) {
      checking.add(c.$1);
    }
    notifyListeners();
    await Future.wait(serviceChecks.map((c) async {
      final ms = await httpProbe(c.$2,
          proxyPort: viaProxy ? kHttpPort : null, timeoutSec: 10, strict: c.$1 == 'YouTube');
      checks[c.$1] = ms ?? -1;
      checking.remove(c.$1);
      notifyListeners();
    }));
  }

  // ---------- Подбор стратегии ByeDPI ----------

  Future<void> autoPickByeDpi() async {
    if (busy || connected) return;
    _busy('Подбираю стратегию ByeDPI…');
    const urls = [
      'https://www.youtube.com/generate_204',
      'https://i.ytimg.com/generate_204',
      'https://discord.com/api/v9/experiments',
    ];
    int? bestIdx;
    var bestScore = -1;
    var bestMs = 1 << 30;
    for (var i = 0; i < byeDpiPresets.length; i++) {
      busyText = 'Стратегия ${i + 1}/${byeDpiPresets.length}: ${byeDpiPresets[i].name}';
      progress = i / byeDpiPresets.length;
      notifyListeners();
      ManagedProc? dpi;
      ManagedProc? x;
      try {
        dpi = await cores.startCiadpi(kByeDpiPort + 1, byeDpiPresets[i].args, name: 'dpi-test');
        x = await cores.startXray(buildByeDpiTestConfig(kTestBasePort, kByeDpiPort + 1), 'xray-dpitest');
        if (dpi == null || x == null) continue;
        var score = 0;
        var total = 0;
        for (final u in urls) {
          final ms = await httpProbe(u, proxyPort: kTestBasePort, timeoutSec: 6, strict: false);
          if (ms != null) {
            score++;
            total += ms;
          }
        }
        log('ByeDPI «${byeDpiPresets[i].name}»: $score/${urls.length}');
        if (score > bestScore || (score == bestScore && total < bestMs)) {
          bestScore = score;
          bestMs = total;
          bestIdx = i;
        }
      } catch (e) {
        log('Подбор: $e');
      } finally {
        await x?.kill();
        await dpi?.kill();
      }
    }
    if (bestIdx != null && bestScore > 0) {
      byedpiPreset = bestIdx;
      status = 'Лучшая стратегия: ${byeDpiPresets[bestIdx].name}';
    } else {
      status = 'Ни одна стратегия не прошла проверку';
    }
    _idle();
    await save();
  }

  // ---------- Источники ----------

  void addSource(String name, String url) {
    sources.add(SubSource(name.isEmpty ? url : name, url, custom: true));
    notifyListeners();
    save();
  }

  void removeSource(SubSource s) {
    sources.remove(s);
    notifyListeners();
    save();
  }

  void clearServers() {
    servers.clear();
    selectedKey = null;
    notifyListeners();
    save();
  }

  // ---------- Разное ----------

  Future<void> relaunchAsAdmin() async {
    if (!isWindows) return;
    if (connected) await disconnect(silent: true);
    final ok = await WinNet.relaunchAsAdmin();
    if (ok) exit(0);
  }

  /// Подключить Telegram к локальному SOCKS5 Беспредела (удобно для Telegram Desktop).
  Future<void> connectTelegram() async {
    const url = 'tg://socks?server=127.0.0.1&port=$kSocksPort';
    if (isWindows) {
      await WinNet.openUrl(url);
    } else {
      await AndroidVpn.openUrl(url);
    }
  }
}
