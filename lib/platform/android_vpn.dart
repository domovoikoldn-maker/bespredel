import 'package:flutter/services.dart';

/// Мост к Kotlin-части: VpnService + hev-socks5-tunnel.
class AndroidVpn {
  static const _ch = MethodChannel('bespredel/vpn');

  static Future<String> nativeDir() async =>
      await _ch.invokeMethod<String>('nativeDir') ?? '';

  /// Запрашивает у системы разрешение на VPN. true — разрешено.
  static Future<bool> prepare() async =>
      await _ch.invokeMethod<bool>('prepare') ?? false;

  static Future<void> start({
    required int socksPort,
    required bool dnsOnly,
    required String title,
  }) =>
      _ch.invokeMethod('start', {
        'socksPort': socksPort,
        'dnsOnly': dnsOnly,
        'title': title,
      });

  static Future<void> stop() => _ch.invokeMethod('stop');

  static Future<void> openUrl(String url) => _ch.invokeMethod('openUrl', {'url': url});

  static Future<bool> isRunning() async =>
      await _ch.invokeMethod<bool>('isRunning') ?? false;
}
