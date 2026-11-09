// Запуск и остановка ядер: Xray, ByeDPI (ciadpi).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'platform/android_vpn.dart';
import 'presets.dart';

class ManagedProc {
  final String name;
  final Process proc;
  bool exited = false;
  int? code;

  ManagedProc(this.name, this.proc, void Function(String) log) {
    const dec = Utf8Decoder(allowMalformed: true);
    proc.stdout.transform(dec).transform(const LineSplitter()).listen((l) => log('[$name] $l'));
    proc.stderr.transform(dec).transform(const LineSplitter()).listen((l) => log('[$name] $l'));
    proc.exitCode.then((c) {
      exited = true;
      code = c;
      log('[$name] завершился, код $c');
    });
  }

  Future<void> kill() async {
    if (exited) return;
    proc.kill();
    try {
      await proc.exitCode.timeout(const Duration(seconds: 2));
    } catch (_) {
      proc.kill(ProcessSignal.sigkill);
    }
  }
}

class CoreRunner {
  late Directory dataDir;
  String _nativeDir = '';
  void Function(String) log = (_) {};

  Future<void> init(Directory data) async {
    dataDir = data;
    if (Platform.isAndroid) {
      _nativeDir = await AndroidVpn.nativeDir();
    }
  }

  String get _winCores =>
      '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}cores';

  String get xrayPath => Platform.isWindows
      ? '$_winCores\\bp-xray.exe'
      : '$_nativeDir/libxray.so';

  String get ciadpiPath => Platform.isWindows
      ? '$_winCores\\bp-ciadpi.exe'
      : '$_nativeDir/libbyedpi.so';

  String get zapretDir => '$_winCores\\zapret';
  String get zapretBinDir => '$zapretDir\\bin\\';
  String get zapretListsDir => '$zapretDir\\lists\\';
  String get winwsPath => '${zapretBinDir}winws.exe';

  /// Стратегии Flowseal из strategies.json (кладётся при сборке).
  List<ZapretPreset> loadZapretStrategies() {
    try {
      final f = File('$zapretDir\\strategies.json');
      if (f.existsSync()) {
        final l = (jsonDecode(f.readAsStringSync()) as List)
            .map((e) => ZapretPreset((e as Map)['name'] as String, e['args'] as String))
            .toList();
        if (l.isNotEmpty) return l;
      }
    } catch (e) {
      log('strategies.json: $e');
    }
    return const [];
  }

  String zapretArgs(ZapretPreset p) =>
      p.args.replaceAll('%BIN%', zapretBinDir).replaceAll('%LISTS%', zapretListsDir);

  /// Запуск winws напрямую (когда приложение уже от администратора).
  Future<ManagedProc?> startWinws(ZapretPreset p) async {
    final args = splitArgs(zapretArgs(p));
    final proc = await Process.start(winwsPath, args, workingDirectory: zapretBinDir);
    final mp = ManagedProc('winws', proc, log);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mp.exited) return null;
    return mp;
  }

  bool get hasXray => File(xrayPath).existsSync();
  bool get hasCiadpi => File(ciadpiPath).existsSync();
  bool get hasZapret => Platform.isWindows && File(winwsPath).existsSync();

  Future<ManagedProc?> _start(String name, String exe, List<String> args, {int? readyPort}) async {
    if (!File(exe).existsSync()) {
      throw Exception('Не найдено ядро: $exe');
    }
    final p = await Process.start(exe, args, workingDirectory: dataDir.path);
    final mp = ManagedProc(name, p, log);
    if (readyPort == null) {
      await Future.delayed(const Duration(milliseconds: 700));
    } else {
      // ждём, пока ядро откроет порт (обычно 100–300 мс), а не фиксированные 0,9 с
      await waitPort(readyPort, () => mp.exited);
    }
    if (mp.exited) return null;
    return mp;
  }

  Future<ManagedProc?> startXray(Map<String, dynamic> config, String name, {int? readyPort}) async {
    final f = File('${dataDir.path}${Platform.pathSeparator}$name.json');
    await f.writeAsString(jsonEncode(config));
    return _start(name, xrayPath, ['run', '-c', f.path], readyPort: readyPort);
  }

  Future<ManagedProc?> startCiadpi(int port, String args, {String name = 'byedpi'}) async {
    final a = <String>['-i', '127.0.0.1', '-p', '$port'];
    a.addAll(args.split(RegExp(r'\s+')).where((e) => e.isNotEmpty));
    return _start(name, ciadpiPath, a);
  }
}

/// HTTP-проба через локальный HTTP-прокси (или напрямую, если port == null).
/// Возвращает задержку в мс либо null.
Future<int?> httpProbe(String url, {int? proxyPort, int timeoutSec = 8, bool strict = true}) async {
  final client = HttpClient()
    ..connectionTimeout = Duration(seconds: timeoutSec)
    ..userAgent =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36';
  if (proxyPort != null) {
    client.findProxy = (_) => 'PROXY 127.0.0.1:$proxyPort';
  }
  final sw = Stopwatch()..start();
  try {
    final req = await client.getUrl(Uri.parse(url)).timeout(Duration(seconds: timeoutSec));
    req.followRedirects = true;
    req.maxRedirects = 5;
    final resp = await req.close().timeout(Duration(seconds: timeoutSec));
    await resp.drain<void>().timeout(Duration(seconds: timeoutSec));
    final ms = sw.elapsedMilliseconds;
    final code = resp.statusCode;
    if (strict) {
      return (code == 204 || code == 200) ? ms : null;
    }
    final loc = resp.redirects.isEmpty ? '' : resp.redirects.last.location.toString().toLowerCase();
    if (code == 451 || code >= 500) return null;
    if (loc.contains('unavailable') || loc.contains('unsupported') || loc.contains('not-available')) {
      return null;
    }
    return ms;
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

Future<int?> tcpPing(String host, int port, {int timeoutMs = 1500}) async {
  final sw = Stopwatch()..start();
  try {
    final s = await Socket.connect(host, port, timeout: Duration(milliseconds: timeoutMs));
    final ms = sw.elapsedMilliseconds;
    s.destroy();
    return ms;
  } catch (_) {
    return null;
  }
}

/// Разбор строки аргументов с учётом кавычек: --a="x y" -> --a=x y
List<String> splitArgs(String s) {
  final out = <String>[];
  final cur = StringBuffer();
  var inQ = false;
  var has = false;
  for (final ch in s.split('')) {
    if (ch == '"') {
      inQ = !inQ;
      has = true;
    } else if (ch == ' ' && !inQ) {
      if (has || cur.isNotEmpty) out.add(cur.toString());
      cur.clear();
      has = false;
    } else {
      cur.write(ch);
    }
  }
  if (has || cur.isNotEmpty) out.add(cur.toString());
  return out;
}

/// GET с телом ответа (через локальный HTTP-прокси или напрямую).
Future<(int, String)?> httpGet(String url, {int? proxyPort, int timeoutSec = 8}) async {
  final client = HttpClient()
    ..connectionTimeout = Duration(seconds: timeoutSec)
    ..userAgent =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36';
  if (proxyPort != null) client.findProxy = (_) => 'PROXY 127.0.0.1:$proxyPort';
  try {
    final req = await client.getUrl(Uri.parse(url)).timeout(Duration(seconds: timeoutSec));
    final resp = await req.close().timeout(Duration(seconds: timeoutSec));
    final body = await resp
        .transform(const Utf8Decoder(allowMalformed: true))
        .join()
        .timeout(Duration(seconds: timeoutSec));
    return (resp.statusCode, body.length > 200000 ? body.substring(0, 200000) : body);
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// Страна выхода по Cloudflare trace (loc=XX).
Future<String?> traceCountry(String host, {int? proxyPort, int timeoutSec = 8}) async {
  final r = await httpGet('https://$host/cdn-cgi/trace', proxyPort: proxyPort, timeoutSec: timeoutSec);
  if (r == null || r.$1 != 200) return null;
  final m = RegExp(r'^loc=([A-Z]{2})', multiLine: true).firstMatch(r.$2);
  return m?.group(1);
}

/// Ждать, пока локальный порт начнёт принимать соединения.
Future<bool> waitPort(int port, bool Function() dead, {int timeoutMs = 4000}) async {
  final sw = Stopwatch()..start();
  while (sw.elapsedMilliseconds < timeoutMs) {
    if (dead()) return false;
    try {
      final s = await Socket.connect('127.0.0.1', port, timeout: const Duration(milliseconds: 300));
      s.destroy();
      return true;
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 60));
    }
  }
  return false;
}
