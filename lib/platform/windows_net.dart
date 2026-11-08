// Windows: системный прокси, DNS, запуск zapret (winws) с правами администратора.
import 'dart:io';

import '../presets.dart';

class WinNet {
  static Directory? tmp;
  static bool? _admin;

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

  /// Выполнить PowerShell-скрипт. elevated — с запросом UAC, если нужно.
  static Future<int> runPs(String script, {bool elevated = false}) async {
    final dir = tmp ?? Directory.systemTemp;
    final f = File('${dir.path}\\bp_${DateTime.now().microsecondsSinceEpoch}.ps1');
    // BOM, чтобы PowerShell 5 правильно прочитал кириллицу в путях
    await f.writeAsString('﻿$script');
    try {
      if (!elevated || await isAdmin()) {
        final r = await Process.run('powershell', [
          '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
          '-WindowStyle', 'Hidden', '-File', f.path,
        ]);
        return r.exitCode;
      }
      final inner = "try { \$p = Start-Process powershell -Verb RunAs -Wait -PassThru "
          "-WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass',"
          "'-File','\"${f.path.replaceAll("'", "''")}\"'; exit \$p.ExitCode } catch { exit 1223 }";
      final r = await Process.run('powershell', [
        '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', inner,
      ]);
      return r.exitCode;
    } finally {
      try {
        await f.delete();
      } catch (_) {}
    }
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
  Set-DnsClientServerAddress -InterfaceIndex \$_.ifIndex -ServerAddresses \$ips
}
foreach (\$ip in \$ips) {
  try { netsh dns add encryption server=\$ip dohtemplate=${d.doh} autoupgrade=yes udpfallback=no | Out-Null } catch {}
}
Clear-DnsClientCache
exit 0
''', elevated: true);
    return code == 0;
  }

  static Future<void> resetDns() async {
    await runPs('''
Get-NetAdapter | Where-Object { \$_.Status -eq 'Up' } | ForEach-Object {
  Set-DnsClientServerAddress -InterfaceIndex \$_.ifIndex -ResetServerAddresses
}
Clear-DnsClientCache
exit 0
''', elevated: true);
  }

  static Future<bool> startZapret(String exe, String args, String workDir) async {
    final code = await runPs('''
Get-Process -Name winws -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Process -FilePath ${q(exe)} -ArgumentList ${q(args)} -WorkingDirectory ${q(workDir)} -WindowStyle Hidden
Start-Sleep -Milliseconds 1200
if (Get-Process -Name winws -ErrorAction SilentlyContinue) { exit 0 } else { exit 2 }
''', elevated: true);
    return code == 0;
  }

  static Future<void> stopZapret() async {
    if (!await isZapretRunning()) return;
    await runPs('''
Get-Process -Name winws -ErrorAction SilentlyContinue | Stop-Process -Force
exit 0
''', elevated: true);
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
}
