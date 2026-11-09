// Модели данных и парсер ссылок vless://
import 'dart:convert';

const _badExit = {'RU', 'BY', 'CN', 'IR', 'KP', 'SY', 'CU'};

class SubSource {
  String name;
  String url;
  bool enabled;
  bool custom;
  String? lastError;
  int lastCount;

  SubSource(this.name, this.url,
      {this.enabled = true, this.custom = false, this.lastCount = 0});

  Map<String, dynamic> toJson() =>
      {'name': name, 'url': url, 'enabled': enabled, 'custom': custom};

  factory SubSource.fromJson(Map<String, dynamic> j) => SubSource(
        (j['name'] ?? '') as String,
        (j['url'] ?? '') as String,
        enabled: (j['enabled'] ?? true) as bool,
        custom: (j['custom'] ?? false) as bool,
      );
}

class VlessServer {
  final String raw;
  final String uuid;
  final String host;
  final int port;
  final String name;
  final Map<String, String> q;

  int? tcpMs; // TCP-пинг
  int? delayMs; // реальная задержка через ядро
  bool tested = false; // проходил ли реальный тест
  String? country; // страна выхода (Cloudflare trace)
  String source = '';

  VlessServer({
    required this.raw,
    required this.uuid,
    required this.host,
    required this.port,
    required this.name,
    required this.q,
  });

  String get key => '$uuid@$host:$port';
  String get security => q['security'] ?? 'none';
  String get network {
    final t = (q['type'] ?? 'tcp').toLowerCase();
    if (t == 'splithttp') return 'xhttp';
    if (t == 'raw') return 'tcp';
    return t.isEmpty ? 'tcp' : t;
  }

  bool get isReality => security == 'reality';
  bool get alive => tested && delayMs != null;
  bool get badExit => country != null && _badExit.contains(country);
  /// Пригоден для «всего»: жив и выход не в РФ/Беларуси/Китае и т.п.
  bool get good => alive && !badExit;

  bool get valid {
    if (uuid.isEmpty || host.isEmpty || port <= 0 || port > 65535) return false;
    if (isReality && (q['pbk'] ?? '').isEmpty) return false;
    const nets = {'tcp', 'ws', 'grpc', 'xhttp', 'httpupgrade'};
    return nets.contains(network);
  }

  Map<String, dynamic> toJson() => {
        'raw': raw,
        'tcp': tcpMs,
        'delay': delayMs,
        'tested': tested,
        'cc': country,
        'src': source,
      };

  static VlessServer? fromJson(Map<String, dynamic> j) {
    final s = parseVless((j['raw'] ?? '') as String);
    if (s == null) return null;
    s.tcpMs = j['tcp'] as int?;
    s.delayMs = j['delay'] as int?;
    s.tested = (j['tested'] ?? false) as bool;
    s.country = j['cc'] as String?;
    s.source = (j['src'] ?? '') as String;
    return s;
  }
}

String _dec(String s, {bool plus = false}) {
  try {
    return Uri.decodeComponent(plus ? s.replaceAll('+', '%20') : s);
  } catch (_) {
    return s;
  }
}

VlessServer? parseVless(String line) {
  line = line.trim();
  if (line.length < 10 || !line.toLowerCase().startsWith('vless://')) {
    return null;
  }
  var rest = line.substring(8);
  var name = '';
  final hi = rest.indexOf('#');
  if (hi >= 0) {
    name = _dec(rest.substring(hi + 1), plus: true).trim();
    rest = rest.substring(0, hi);
  }
  var query = '';
  final qi = rest.indexOf('?');
  if (qi >= 0) {
    query = rest.substring(qi + 1);
    rest = rest.substring(0, qi);
  }
  while (rest.endsWith('/')) {
    rest = rest.substring(0, rest.length - 1);
  }
  final at = rest.lastIndexOf('@');
  if (at < 0) return null;
  final uuid = _dec(rest.substring(0, at)).trim();
  final hp = rest.substring(at + 1);
  String host;
  int port;
  if (hp.startsWith('[')) {
    final e = hp.indexOf(']');
    if (e < 0 || hp.length < e + 2) return null;
    host = hp.substring(1, e);
    port = int.tryParse(hp.substring(e + 2)) ?? 0;
  } else {
    final c = hp.lastIndexOf(':');
    if (c < 0) return null;
    host = hp.substring(0, c);
    port = int.tryParse(hp.substring(c + 1)) ?? 0;
  }
  final q = <String, String>{};
  for (final kv in query.split('&')) {
    if (kv.isEmpty) continue;
    final i = kv.indexOf('=');
    if (i < 0) {
      q[kv.toLowerCase()] = '';
    } else {
      q[kv.substring(0, i).toLowerCase()] = _dec(kv.substring(i + 1));
    }
  }
  return VlessServer(
    raw: line,
    uuid: uuid,
    host: host,
    port: port,
    name: name.isEmpty ? '$host:$port' : name,
    q: q,
  );
}

/// Разбор содержимого подписки: обычный текст или base64.
List<VlessServer> parseSubscription(String body) {
  var text = body;
  if (!text.contains('://')) {
    text = tryBase64(text) ?? text;
  }
  final out = <VlessServer>[];
  for (final l in text.split(RegExp(r'[\r\n]+'))) {
    final s = parseVless(l);
    if (s != null) out.add(s);
  }
  return out;
}

String? tryBase64(String s) {
  try {
    var t = s.replaceAll(RegExp(r'\s'), '');
    t = t.replaceAll('-', '+').replaceAll('_', '/');
    while (t.length % 4 != 0) {
      t += '=';
    }
    return utf8.decode(base64.decode(t), allowMalformed: true);
  } catch (_) {
    return null;
  }
}
