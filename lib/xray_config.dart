// Генерация JSON-конфигов для Xray-core.
import 'models.dart';
import 'presets.dart';

bool _ne(String? s) => s != null && s.isNotEmpty;

Map<String, dynamic> vlessOutbound(VlessServer s, String tag) {
  final q = s.q;
  final net = s.network;
  final stream = <String, dynamic>{'network': net == 'tcp' ? 'raw' : net};
  final sec = s.security;
  final fp = _ne(q['fp']) ? q['fp'] : 'chrome';
  if (sec == 'reality') {
    stream['security'] = 'reality';
    stream['realitySettings'] = {
      'serverName': q['sni'] ?? '',
      'fingerprint': fp,
      'publicKey': q['pbk'] ?? '',
      'shortId': q['sid'] ?? '',
      'spiderX': q['spx'] ?? '',
      if (_ne(q['pqv'])) 'mldsa65Verify': q['pqv'],
    };
  } else if (sec == 'tls') {
    stream['security'] = 'tls';
    stream['tlsSettings'] = {
      'serverName': _ne(q['sni']) ? q['sni'] : s.host,
      'fingerprint': fp,
      'allowInsecure': q['allowinsecure'] == '1' || q['allowinsecure'] == 'true',
      if (_ne(q['alpn'])) 'alpn': q['alpn']!.split(','),
    };
  }
  final path = _ne(q['path']) ? q['path']! : '/';
  final host = q['host'] ?? '';
  switch (net) {
    case 'ws':
      stream['wsSettings'] = {'path': path, 'host': host};
      break;
    case 'grpc':
      stream['grpcSettings'] = {
        'serviceName': q['servicename'] ?? '',
        'multiMode': q['mode'] == 'multi',
      };
      break;
    case 'xhttp':
      stream['xhttpSettings'] = {
        'path': path,
        'host': host,
        'mode': _ne(q['mode']) ? q['mode'] : 'auto',
      };
      break;
    case 'httpupgrade':
      stream['httpupgradeSettings'] = {'path': path, 'host': host};
      break;
    default:
      if (q['headertype'] == 'http') {
        stream['rawSettings'] = {
          'header': {
            'type': 'http',
            'request': {
              'path': [path],
              'headers': {
                'Host': [if (host.isNotEmpty) host]
              }
            }
          }
        };
      }
  }
  return {
    'tag': tag,
    'protocol': 'vless',
    'settings': {
      'vnext': [
        {
          'address': s.host,
          'port': s.port,
          'users': [
            {
              'id': s.uuid,
              'encryption': _ne(q['encryption']) ? q['encryption'] : 'none',
              'flow': q['flow'] ?? '',
            }
          ]
        }
      ]
    },
    'streamSettings': stream,
  };
}

Map<String, dynamic> socksOutbound(String tag, int port) => {
      'tag': tag,
      'protocol': 'socks',
      'settings': {
        'servers': [
          {'address': '127.0.0.1', 'port': port}
        ]
      },
    };

const _privateCidrs = [
  '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16', '127.0.0.0/8',
  '169.254.0.0/16', '100.64.0.0/10', 'fc00::/7', 'fe80::/10', '::1/128',
];

const _ruDomains = [
  'regexp:\\.ru\$', 'regexp:\\.su\$', 'regexp:\\.xn--p1ai\$',
  'domain:vk.com', 'domain:vk.me', 'domain:userapi.com', 'domain:yandex.net',
  'domain:ya.ru', 'domain:gosuslugi.ru', 'domain:sberbank.ru', 'domain:tbank.ru',
  'domain:ozon.ru', 'domain:wildberries.ru', 'domain:mail.ru', 'domain:max.ru',
];

Map<String, dynamic> _sniff() => {
      'enabled': true,
      'destOverride': ['http', 'tls', 'quic'],
      'routeOnly': true,
    };

List<Map<String, dynamic>> _inbounds() => [
      {
        'tag': 'socks-in',
        'listen': '127.0.0.1',
        'port': kSocksPort,
        'protocol': 'socks',
        'settings': {'auth': 'noauth', 'udp': true},
        'sniffing': _sniff(),
      },
      {
        'tag': 'http-in',
        'listen': '127.0.0.1',
        'port': kHttpPort,
        'protocol': 'http',
        'settings': {},
        'sniffing': _sniff(),
      },
    ];

Map<String, dynamic> _dns(DnsPreset selected) {
  final ai = dnsPresets.firstWhere((d) => d.aiUnlock);
  final hosts = <String, dynamic>{};
  for (final d in dnsPresets) {
    hosts[d.dohHost] = d.ips;
  }
  return {
    'hosts': hosts,
    'servers': [
      {
        'address': ai.doh.replaceFirst('https://', 'https+local://'),
        'domains': aiDomains,
        'skipFallback': true,
      },
      selected.doh.replaceFirst('https://', 'https+local://'),
      selected.ips.first,
    ],
    'queryStrategy': 'UseIPv4',
  };
}

enum XrayMain { vless, multi, fragment, byedpi, dnsOnly }

Map<String, dynamic> fragOutbound(String tag, FragPreset f) => {
      'tag': tag,
      'protocol': 'freedom',
      'settings': {
        'domainStrategy': 'UseIPv4',
        'fragment': {'packets': f.packets, 'length': f.length, 'interval': f.interval},
      },
    };

/// Основной конфиг для подключения.
/// vless    — всё через один VLESS;
/// multi    — балансировщик по нескольким VLESS + запасная фрагментация;
/// fragment — без серверов, фрагментация TLS ClientHello;
/// byedpi   — через локальный ciadpi;
/// dnsOnly  — всё напрямую (через DoH), ИИ-сайты по IP из Comss DNS.
Map<String, dynamic> buildMainConfig({
  required XrayMain kind,
  VlessServer? server,
  List<VlessServer> pool = const [],
  required DnsPreset dns,
  required bool ruDirect,
  FragPreset frag = const FragPreset('', 'tlshello', '100-200', '10-20'),
  String testUrl = 'https://www.gstatic.com/generate_204',
}) {
  final outbounds = <Map<String, dynamic>>[];
  Map<String, dynamic>? observatory;
  final balancers = <Map<String, dynamic>>[];

  switch (kind) {
    case XrayMain.vless:
      outbounds.add(vlessOutbound(server!, 'proxy'));
      break;
    case XrayMain.multi:
      for (var i = 0; i < pool.length; i++) {
        outbounds.add(vlessOutbound(pool[i], 'p$i'));
      }
      observatory = {
        'subjectSelector': ['p'],
        'pingConfig': {
          'destination': testUrl,
          'interval': '30s',
          'connectivity': '',
          'timeout': '6s',
          'sampling': 2,
        },
      };
      balancers.add({
        'tag': 'bal',
        'selector': ['p'],
        'strategy': {'type': 'leastPing'},
        'fallbackTag': 'frag',
      });
      break;
    case XrayMain.fragment:
      break;
    case XrayMain.byedpi:
      outbounds.add(socksOutbound('proxy', kByeDpiPort));
      break;
    case XrayMain.dnsOnly:
      break;
  }
  outbounds.add(fragOutbound('frag', frag));
  outbounds.add({
    'tag': 'direct',
    'protocol': 'freedom',
    'settings': {'domainStrategy': kind == XrayMain.dnsOnly ? 'UseIPv4' : 'AsIs'},
  });
  outbounds.add({
    'tag': 'ai-direct',
    'protocol': 'freedom',
    'settings': {
      'domainStrategy': 'UseIPv4',
      if (kind == XrayMain.fragment)
        'fragment': {'packets': frag.packets, 'length': frag.length, 'interval': frag.interval},
    },
  });
  outbounds.add({'tag': 'block', 'protocol': 'blackhole'});
  outbounds.add({'tag': 'dns-out', 'protocol': 'dns'});

  final rules = <Map<String, dynamic>>[
    {
      'type': 'field',
      'inboundTag': ['socks-in'],
      'port': '53',
      'network': 'udp',
      'outboundTag': 'dns-out',
    },
    {'type': 'field', 'ip': _privateCidrs, 'outboundTag': 'direct'},
  ];
  final viaServer = kind == XrayMain.vless || kind == XrayMain.multi;
  if (!viaServer) {
    // ИИ-сервисы: резолвим через Comss и идём на их прокси напрямую
    rules.add({'type': 'field', 'domain': aiDomains, 'outboundTag': 'ai-direct'});
  }
  if (kind == XrayMain.byedpi || kind == XrayMain.fragment) {
    // QUIC не обходится этими методами — заставляем браузер уйти на TCP
    rules.add({'type': 'field', 'network': 'udp', 'port': '443', 'outboundTag': 'block'});
  }
  if (ruDirect && kind != XrayMain.dnsOnly) {
    rules.add({'type': 'field', 'domain': _ruDomains, 'outboundTag': 'direct'});
  }
  // Правило «по умолчанию»
  switch (kind) {
    case XrayMain.vless:
    case XrayMain.byedpi:
      rules.add({'type': 'field', 'network': 'tcp,udp', 'outboundTag': 'proxy'});
      break;
    case XrayMain.multi:
      rules.add({'type': 'field', 'network': 'tcp,udp', 'balancerTag': 'bal'});
      break;
    case XrayMain.fragment:
      rules.add({'type': 'field', 'network': 'tcp,udp', 'outboundTag': 'frag'});
      break;
    case XrayMain.dnsOnly:
      rules.add({'type': 'field', 'network': 'tcp,udp', 'outboundTag': 'direct'});
      break;
  }

  return {
    'log': {'loglevel': 'warning'},
    'dns': _dns(dns),
    'inbounds': _inbounds(),
    'outbounds': outbounds,
    if (observatory != null) 'burstObservatory': observatory,
    'routing': {
      'domainStrategy': 'AsIs',
      'rules': rules,
      if (balancers.isNotEmpty) 'balancers': balancers,
    },
  };
}

/// Конфиг для пакетного теста: на каждый сервер свой HTTP-вход.
Map<String, dynamic> buildTestConfig(List<VlessServer> list, int basePort) {
  final inbounds = <Map<String, dynamic>>[];
  final outbounds = <Map<String, dynamic>>[];
  final rules = <Map<String, dynamic>>[];
  for (var i = 0; i < list.length; i++) {
    inbounds.add({
      'tag': 'in$i',
      'listen': '127.0.0.1',
      'port': basePort + i,
      'protocol': 'http',
      'settings': {},
    });
    outbounds.add(vlessOutbound(list[i], 'out$i'));
    rules.add({
      'type': 'field',
      'inboundTag': ['in$i'],
      'outboundTag': 'out$i',
    });
  }
  outbounds.add({'tag': 'direct', 'protocol': 'freedom'});
  return {
    'log': {'loglevel': 'error'},
    'inbounds': inbounds,
    'outbounds': outbounds,
    'routing': {'rules': rules},
  };
}

/// Конфиг для подбора стратегии ByeDPI: HTTP-вход → SOCKS ciadpi.
Map<String, dynamic> buildByeDpiTestConfig(int httpPort, int dpiPort) => {
      'log': {'loglevel': 'error'},
      'inbounds': [
        {'tag': 'in', 'listen': '127.0.0.1', 'port': httpPort, 'protocol': 'http', 'settings': {}}
      ],
      'outbounds': [socksOutbound('proxy', dpiPort)],
    };
