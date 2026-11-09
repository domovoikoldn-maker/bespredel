// Встроенные пресеты: источники конфигов, стратегии ByeDPI / zapret, DNS.
import 'models.dart';

enum BypassMode { auto, vless, multi, fragment, byedpi, zapret, dns }

extension BypassModeInfo on BypassMode {
  String get title => const {
        BypassMode.auto: 'АВТО',
        BypassMode.vless: 'VLESS',
        BypassMode.multi: 'МУЛЬТИ',
        BypassMode.fragment: 'ФРАГМЕНТ',
        BypassMode.byedpi: 'BYEDPI',
        BypassMode.zapret: 'ZAPRET',
        BypassMode.dns: 'DNS',
      }[this]!;

  String get desc => const {
        BypassMode.auto:
            'Сам соберёт и проверит серверы и подключит самый быстрый рабочий. Если рабочих нет — Фрагментация + DNS для ИИ.',
        BypassMode.vless:
            'Весь трафик через один VLESS+Reality сервер из открытых подписок. Работает всё: YouTube, Telegram, Claude, Gemini.',
        BypassMode.multi:
            'До 8 лучших VLESS-серверов сразу. Ядро каждые 30 с проверяет их и само переключается на живой. Если упали все — уходит во фрагментацию.',
        BypassMode.fragment:
            'Без серверов: ядро Xray режет TLS-приветствие на кусочки, и DPI не видит, куда ты идёшь. DNS через DoH. Не нужен админ.',
        BypassMode.byedpi:
            'Локальный обход DPI (ByeDPI) без серверов. YouTube, Discord и др. + ИИ-сервисы через DNS Comss. Telegram может не работать.',
        BypassMode.zapret:
            'zapret (winws) — обход DPI на уровне драйвера, работает для всех программ (Discord, игры). Нужны права администратора.',
        BypassMode.dns:
            'Только ИИ-сервисы с геоблоком (ChatGPT, Claude, Gemini, Copilot) через DNS Comss. Скорость не режется.',
      }[this]!;
}

class FragPreset {
  final String name;
  final String packets;
  final String length;
  final String interval;
  const FragPreset(this.name, this.packets, this.length, this.interval);
}

const fragPresets = <FragPreset>[
  FragPreset('Стандарт', 'tlshello', '100-200', '10-20'),
  FragPreset('Мелкая нарезка', 'tlshello', '10-20', '5-10'),
  FragPreset('Агрессивный', '1-3', '1-5', '1-2'),
  FragPreset('Быстрый', 'tlshello', '3-5', '1'),
];

const defaultSources = <List<Object>>[
  // [имя, url, включён]
  ['vless-checker — проверенные каждые 30 мин',
    'https://raw.githubusercontent.com/tiagorrg/vless-checker/main/docs/keys.json', true],
  ['zieng2 — VLESS universal (свежие)',
    'https://raw.githubusercontent.com/zieng2/wl/main/vless_universal.txt', true],
  ['zieng2 — VLESS lite',
    'https://raw.githubusercontent.com/zieng2/wl/main/vless_lite.txt', true],
  ['igareck — WHITE CIDR (проверенные)',
    'https://raw.githubusercontent.com/igareck/vpn-configs-for-russia/main/WHITE-CIDR-RU-checked.txt', false],
  ['kort0881 — большой сборник (14 тыс., долго)',
    'https://raw.githubusercontent.com/kort0881/vpn-vless-configs-russia/main/data/githubmirror/clean/vless.txt', false],
  ['igareck — ЧС VLESS (топ-150, моб.)',
    'https://raw.githubusercontent.com/igareck/vpn-configs-for-russia/main/BLACK_VLESS_RUS_mobile.txt', true],
  ['igareck — ЧС VLESS (все)',
    'https://raw.githubusercontent.com/igareck/vpn-configs-for-russia/main/BLACK_VLESS_RUS.txt', false],
  ['igareck — Белые списки (выход в РФ, только для моб. интернета)',
    'https://raw.githubusercontent.com/igareck/vpn-configs-for-russia/main/Vless-Reality-White-Lists-Rus-Mobile.txt', false],
  ['barry-far — VLESS',
    'https://raw.githubusercontent.com/barry-far/V2ray-Config/main/Splitted-By-Protocol/vless.txt', true],
  ['Epodonios — VLESS',
    'https://raw.githubusercontent.com/Epodonios/v2ray-configs/main/Splitted-By-Protocol/vless.txt', false],
  ['soroushmirzaei — VLESS',
    'https://raw.githubusercontent.com/soroushmirzaei/telegram-configs-collector/main/protocols/vless', false],
  ['mahdibland — агрегатор (микс)',
    'https://raw.githubusercontent.com/mahdibland/V2RayAggregator/master/sub/sub_merge.txt', false],
];

List<SubSource> buildDefaultSources() => [
      for (final s in defaultSources)
        SubSource(s[0] as String, s[1] as String, enabled: s[2] as bool)
    ];

/// Зеркала для raw.githubusercontent.com — на случай блокировки GitHub.
List<String> mirrorsFor(String url) {
  final out = <String>[url];
  final m = RegExp(r'^https://raw\.githubusercontent\.com/([^/]+)/([^/]+)/([^/]+)/(.+)$')
      .firstMatch(url);
  if (m != null) {
    final o = m.group(1), r = m.group(2), b = m.group(3), p = m.group(4);
    out.add('https://cdn.jsdelivr.net/gh/$o/$r@$b/$p');
    out.add('https://raw.githack.com/$o/$r/$b/$p');
  }
  return out;
}

class ByeDpiPreset {
  final String name;
  final String args;
  final String desc;
  const ByeDpiPreset(this.name, this.args, this.desc);
}

const byeDpiPresets = <ByeDpiPreset>[
  ByeDpiPreset('Универсальный', '--split 1 --disorder 3+s --mod-http=h,d --auto=torst --tlsrec 1+s',
      'Рекомендуемый автором ByeDPI, подходит большинству провайдеров'),
  ByeDpiPreset('Disorder + TLS rec', '--disorder 1 --auto=torst --tlsrec 1+s',
      'Классика: перемешивание + разбиение TLS-записи'),
  ByeDpiPreset('Split/Disorder (Windows)', '--split 1+s --disorder 3+s',
      'Рекомендуется для Windows'),
  ByeDpiPreset('Fake + TTL', '--fake -1 --ttl 8',
      'Фейковый пакет с малым TTL. Если не работает — попробуй TTL 5–10'),
  ByeDpiPreset('Fake + disorder', '--disorder 1 --fake -1 --auto=torst',
      'Агрессивный режим'),
  ByeDpiPreset('OOB', '--oob 1 --auto=torst --tlsrec 1+s',
      'Out-of-band байт, помогает у части провайдеров'),
];

class ZapretPreset {
  final String name;
  final String args; // %BIN% — папка bin, %LISTS% — папка lists
  const ZapretPreset(this.name, this.args);
}

/// Запасная стратегия, если strategies.json не найден (из general.bat Flowseal).
const zapretFallback = <ZapretPreset>[
  ZapretPreset('General',
      '--wf-tcp=80,443 --wf-udp=443,50000-50100 '
          '--filter-udp=443 --hostlist="%LISTS%list-general.txt" --dpi-desync=fake --dpi-desync-repeats=6 '
          '--dpi-desync-fake-quic="%BIN%quic_initial_www_google_com.bin" --new '
          '--filter-udp=50000-50100 --filter-l7=discord,stun --dpi-desync=fake --dpi-desync-repeats=6 --new '
          '--filter-tcp=443 --hostlist="%LISTS%list-google.txt" --ip-id=zero --dpi-desync=multisplit '
          '--dpi-desync-split-seqovl=681 --dpi-desync-split-pos=1 '
          '--dpi-desync-split-seqovl-pattern="%BIN%tls_clienthello_www_google_com.bin" --new '
          '--filter-tcp=80,443 --hostlist="%LISTS%list-general.txt" --dpi-desync=multisplit '
          '--dpi-desync-split-seqovl=568 --dpi-desync-split-pos=1 '
          '--dpi-desync-split-seqovl-pattern="%BIN%tls_clienthello_4pda_to.bin"'),
];

/// Страны, из которых ИИ-сервисы и YouTube недоступны/замедлены — такие VLESS-выходы бесполезны.
const badExitCountries = {'RU', 'BY', 'CN', 'IR', 'KP', 'SY', 'CU'};

class DnsPreset {
  final String name;
  final String desc;
  final List<String> ips;
  final String doh;
  final String dohHost;
  final bool aiUnlock;
  const DnsPreset(this.name, this.desc, this.ips, this.doh, this.dohHost,
      {this.aiUnlock = false});
}

const dnsPresets = <DnsPreset>[
  DnsPreset('Comss.one', 'Открывает ChatGPT, Claude, Gemini, Copilot, Grok и др.',
      ['83.220.169.155', '195.133.25.16'], 'https://dns.comss.one/dns-query', 'dns.comss.one',
      aiUnlock: true),
  DnsPreset('Cloudflare', 'Быстрый, без фильтрации', ['1.1.1.1', '1.0.0.1'],
      'https://cloudflare-dns.com/dns-query', 'cloudflare-dns.com'),
  DnsPreset('Google', 'Стабильный', ['8.8.8.8', '8.8.4.4'], 'https://dns.google/dns-query',
      'dns.google'),
  DnsPreset('AdGuard', 'Блокирует рекламу', ['94.140.14.14', '94.140.15.15'],
      'https://dns.adguard-dns.com/dns-query', 'dns.adguard-dns.com'),
  DnsPreset('Quad9', 'Защита от фишинга', ['9.9.9.9', '149.112.112.112'],
      'https://dns.quad9.net/dns-query', 'dns.quad9.net'),
];

/// Домены ИИ-сервисов, которые разблокируются через «умный» DNS.
const aiDomains = <String>[
  'domain:claude.ai', 'domain:anthropic.com', 'domain:claudeusercontent.com',
  'domain:gemini.google.com', 'domain:aistudio.google.com', 'domain:generativelanguage.googleapis.com',
  'domain:alkalimakersuite-pa.clients6.google.com', 'domain:notebooklm.google', 'domain:labs.google',
  'domain:chatgpt.com', 'domain:openai.com', 'domain:oaistatic.com', 'domain:oaiusercontent.com',
  'domain:sora.com', 'domain:copilot.microsoft.com', 'domain:grok.com', 'domain:x.ai',
  'domain:elevenlabs.io', 'domain:perplexity.ai',
];

/// Сайты, проверяемые на главном экране.
const serviceChecks = <(String, String)>[
  ('YouTube', 'видео'),
  ('Gemini', 'регион'),
  ('Claude', 'регион'),
  ('ChatGPT', 'регион'),
  ('Telegram', ''),
  ('Discord', ''),
];

const kSocksPort = 10808;
const kHttpPort = 10809;
const kByeDpiPort = 10810;
const kTestBasePort = 21000;
