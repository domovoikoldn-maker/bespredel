// Windows: системный прокси, DNS, запуск zapret (winws) с правами администратора.
import 'dart:async';
import 'dart:io';

import '../presets.dart';

class WinNet {
  static Directory? tmp;
  static bool? _admin;
  static void Function(String) log = (_) {};

  static Future<bool> isAdmin() async {
    if (_admin != null) return _admin!;
    try {
      final r = await Process.run('net', ['session']);
      _admin = r.exitCode == 0;
    } catch (_) {
      _admin = false;
    }
    return _admin!;
  }

  static String q(String s) => "'${s.replaceAll("'", "''")}'";

  static Future<ProcessResult?> _ps(List<String> args, Duration timeout) async {
    try {
      return await Process.run('powershell', [
        '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden',
        ...args,
      ]).timeout(timeout);
    } on TimeoutException {
      log('PowerShell: превышено время ожидания');
      return null;
    }
  }

  /// Выполнить PowerShell-скрипт. elevated — с запросом UAC, если приложение не от админа.
  /// Важно: ждём только сам процесс powershell (WaitForExit), а не всё дерево —
  /// иначе Start-Process -Wait зависает навсегда, пока жив запущенный winws.
  static Future<int> runPs(String script,
      {bool elevated = false, Duration timeout = const Duration(seconds: 90)}) async {
    final dir = tmp ?? Directory.systemTemp;
    final f = File('${dir.path}\\bp_${DateTime.now().microsecondsSinceEpoch}.ps1');
    await f.writeAsString('﻿$script');
    try {
      ProcessResult? r;
      if (!elevated || await isAdmin()) {
        r = await _ps(['-File', f.path], timeout);
      } else {
        final path = f.path.replaceAll("'", "''");
        final inner = "try { "
            "\$p = Start-Process powershell -Verb RunAs -PassThru -WindowStyle Hidden "
            "-ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File','\"$path\"'; "
            "if (-not \$p.WaitForExit(${timeout.inSeconds * 1000 - 5000})) { exit 1460 }; "
            "exit \$p.ExitCode } catch { exit 1223 }";
        r = await _ps(['-Command', inner], timeout);
      }
      if (r == null) return 1460;
      final err = r.stderr.toString().trim();
      if (err.isNotEmpty) log('PowerShell: $err');
      return r.exitCode;
    } finally {
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  /// Перезапустить приложение с правами администратора.
  static Future<bool> relaunchAsAdmin() async {
    final exe = Platform.resolvedExecutable;
    final r = await _ps([
      '-Command',
      'try { Start-Process -FilePath ${q(exe)} -Verb RunAs; exit 0 } catch { exit 1223 }'
    ], const Duration(seconds: 60));
    return r?.exitCode == 0;
  }

  static const _refresh = r'''
$sig = '[DllImport("wininet.dll")] public static extern bool InternetSetOption(IntPtr h, int o, IntPtr b, int l);'
$t = Add-Type -MemberDefinition $sig -Name WinInet -Namespace Bespredel -PassThru
[void]$t::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0)
[void]$t::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0)
''';

  static Future<void> setProxy(int httpPort) async {
    await runPs('''
\$p = 'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings'
Set-ItemProperty -Path \$p -Name ProxyEnable -Value 1
Set-ItemProperty -Path \$p -Name ProxyServer -Value '127.0.0.1:$httpPort'
Set-ItemProperty -Path \$p -Name ProxyOverride -Value 'localhost;127.*;10.*;172.16.*;192.168.*;<local>'
$_refresh''');
  }

  static Future<void> clearProxy() async {
    await runPs('''
\$p = 'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings'
Set-ItemProperty -Path \$p -Name ProxyEnable -Value 0
$_refresh''');
  }

  static Future<bool> setDns(DnsPreset d) async {
    final ips = d.ips.map(q).join(',');
    final code = await runPs('''
\$ips = @($ips)
Get-NetAdapter | Where-Object { \$_.Status -eq 'Up' } | ForEach-Object {
  Set-DnsClientServerAddress -InterfaceIndex \$_.ifIndex -ServerAddresses \$ips -ErrorAction SilentlyContinue
}
foreach (\$ip in \$ips) {
  try { netsh dns add encryption server=\$ip dohtemplate=${d.doh} autoupgrade=yes udpfallback=no | Out-Null } catch {}
}
Clear-DnsClientCache
exit 0
''', elevated: true, timeout: const Duration(seconds: 60));
    return code == 0;
  }

  static Future<void> resetDns() async {
    await runPs('''
Get-NetAdapter | Where-Object { \$_.Status -eq 'Up' } | ForEach-Object {
  Set-DnsClientServerAddress -InterfaceIndex \$_.ifIndex -ResetServerAddresses -ErrorAction SilentlyContinue
}
Clear-DnsClientCache
exit 0
''', elevated: true, timeout: const Duration(seconds: 60));
  }

  /// Запуск winws. Возвращает null при успехе или текст ошибки.
  static Future<String?> startZapret(String exe, String args, String workDir) async {
    final dir = tmp ?? Directory.systemTemp;
    final out = '${dir.path}\\winws.log';
    final err = '${dir.path}\\winws.err';
    for (final p in [out, err]) {
      try {
        File(p).deleteSync();
      } catch (_) {}
    }
    final code = await runPs('''
Get-Process -Name winws -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 300
\$p = Start-Process -FilePath ${q(exe)} -ArgumentList ${q(args)} -WorkingDirectory ${q(workDir)} -WindowStyle Hidden -PassThru -RedirectStandardOutput ${q(out)} -RedirectStandardError ${q(err)}
Start-Sleep -Milliseconds 2500
if (\$p.HasExited) { exit 2 } else { exit 0 }
''', elevated: true, timeout: const Duration(seconds: 60));
    if (code == 0) return null;
    if (code == 1223) return 'Отменено: нужно разрешить запуск от администратора';
    if (code == 1460) return 'Истекло время ожидания';
    var detail = '';
    for (final p in [err, out]) {
      try {
        detail += File(p).readAsStringSync();
      } catch (_) {}
    }
    detail = detail.trim();
    if (detail.length > 400) detail = detail.substring(detail.length - 400);
    return 'winws завершился сразу (код $code)${detail.isEmpty ? '' : ': $detail'}';
  }

  static Future<void> stopZapret() async {
    if (!await isZapretRunning()) return;
    await runPs('''
Get-Process -Name winws -ErrorAction SilentlyContinue | Stop-Process -Force
exit 0
''', elevated: true, timeout: const Duration(seconds: 45));
  }

  static Future<bool> isZapretRunning() async {
    try {
      final r = await Process.run('tasklist', ['/FI', 'IMAGENAME eq winws.exe', '/NH']);
      return r.stdout.toString().toLowerCase().contains('winws.exe');
    } catch (_) {
      return false;
    }
  }

  static Future<void> killOwnCores() async {
    for (final n in ['bp-xray.exe', 'bp-ciadpi.exe']) {
      try {
        await Process.run('taskkill', ['/F', '/IM', n, '/T']);
      } catch (_) {}
    }
  }

  static Future<void> openUrl(String url) async {
    try {
      await Process.run('rundll32', ['url.dll,FileProtocolHandler', url]);
    } catch (_) {}
  }
}
