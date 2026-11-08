// Запуск и остановка ядер: Xray, ByeDPI (ciadpi).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'platform/android_vpn.dart';

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
  String get winwsPath => '$zapretDir\\winws.exe';
  String get zapretBin => '$zapretDir\\files\\';
  String get zapretList => '$zapretDir\\lists\\list-general.txt';

  bool get hasXray => File(xrayPath).existsSync();
  bool get hasCiadpi => File(ciadpiPath).existsSync();
  bool get hasZapret => Platform.isWindows && File(winwsPath).existsSync();

  Future<ManagedProc?> _start(String name, String exe, List<String> args) async {
    if (!File(exe).existsSync()) {
      throw Exception('Не найдено ядро: $exe');
    }
    final p = await Process.start(exe, args, workingDirectory: dataDir.path);
    final mp = ManagedProc(name, p, log);
    await Future.delayed(const Duration(milliseconds: 900));
    if (mp.exited) return null;
    return mp;
  }

  Future<ManagedProc?> startXray(Map<String, dynamic> config, String name) async {
    final f = File('${dataDir.path}${Platform.pathSeparator}$name.json');
    await f.writeAsString(const JsonEncoder.withIndent(' ').convert(config));
    return _start(name, xrayPath, ['run', '-c', f.path]);
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

Future<int?> tcpPing(String host, int port, {int timeoutMs = 3000}) async {
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
