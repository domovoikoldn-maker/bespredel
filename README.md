<p align="center"><img src="docs/icon.png" width="160"></p>

# BESPREDEL // ベスプレデル

**Обход блокировок для Windows и Android** — YouTube, Telegram, Discord, Claude, Gemini, ChatGPT и др.
Разработчик: **domovoi4ik**

Одна кнопка «Включить», под капотом — несколько независимых способов обхода. Если один перестал работать, переключаешься на другой в один тап.

| Режим | Как работает | Что открывает | Windows | Android |
|---|---|---|:-:|:-:|
| **Авто** | Собирает и проверяет VLESS-серверы: несколько живых — Мульти, один — VLESS, ни одного — Фрагмент | всё | ✅ | ✅ |
| **VLESS** | VLESS + Reality через Xray-core, конфиги из открытых репозиториев GitHub | всё, включая Telegram | ✅ | ✅ |
| **Мульти** | До 8 лучших VLESS сразу, ядро само переключается на живой каждые 30 с; если упали все — фрагментация | всё | ✅ | ✅ |
| **Фрагмент** | Xray режет TLS ClientHello на кусочки, DNS через DoH. Без серверов и без админа | YouTube, Discord и др. + ИИ | ✅ | ✅ |
| **ByeDPI** | Локальный обход DPI (ciadpi), без серверов. ИИ-сайты — через DNS Comss | YouTube, Discord, Instagram и т.п. + ИИ | ✅ | ✅ |
| **Zapret** | winws + WinDivert на уровне драйвера, 4 стратегии | YouTube, Discord (+ ИИ, если включён DNS) | ✅ | — |
| **DNS** | ИИ-сайты резолвятся через Comss.one и идут на его прокси; на Windows работает через системный прокси без админа | ChatGPT, Claude, Gemini, Copilot, Grok | ✅ | ✅ |

## Возможности

- **Сборщик VLESS+Reality** из открытых подписок (igareck/vpn-configs-for-russia, barry-far, Epodonios, soroushmirzaei, mahdibland), можно добавить свои источники. При блокировке GitHub автоматически идёт через зеркала jsDelivr и GitHack.
- **Двухэтапная проверка**: быстрый TCP-пинг всех серверов, затем реальный тест через ядро Xray (пакетами по 25 серверов) — в списке остаются только те, что реально пропускают трафик.
- **Подбор стратегии ByeDPI** одной кнопкой: перебирает пресеты и проверяет YouTube/Discord.
- **Умная маршрутизация**: российские сайты напрямую, ИИ-сервисы через Comss DNS, QUIC блокируется в режиме ByeDPI (браузер уходит на TCP, где работает обход).
- **Проверка сервисов** на главном экране: YouTube, Claude, Gemini, ChatGPT, Telegram, Discord.
- Переключение сервера на лету, журнал ядер, восстановление прокси/DNS после аварийного закрытия.

## Как это устроено

```
                ┌──────────── Flutter UI (общий для Windows и Android) ────────────┐
                │  Главная • Серверы • Методы • Ещё        app_state.dart          │
                └──────────────┬───────────────────────────────┬───────────────────┘
                               │ генерирует JSON и запускает   │
                      ┌────────▼────────┐             ┌────────▼────────┐
  Windows: системный  │   Xray-core     │──SOCKS────▶ │  ByeDPI ciadpi  │  (режим ByeDPI)
  HTTP-прокси :10809  │  :10808 / :10809│             │     :10810      │
  Android: VpnService │  VLESS+Reality  │             └─────────────────┘
  → hev-socks5-tunnel │  DNS (DoH)      │
  → SOCKS :10808      └─────────────────┘
  Windows Zapret: winws.exe + WinDivert (отдельно, с правами администратора)
  Windows DNS: смена DNS адаптеров + DoH (netsh)
```

| Файл | Что внутри |
|---|---|
| `lib/app_state.dart` | Логика: сборщик, тесты, подключение, режимы |
| `lib/xray_config.dart` | Генерация конфигов Xray (vless:// → outbound, маршрутизация, DNS) |
| `lib/models.dart` | Парсер `vless://` и подписок (текст/base64) |
| `lib/presets.dart` | Источники, стратегии ByeDPI/zapret, DNS-серверы, домены ИИ |
| `lib/platform/windows_net.dart` | Системный прокси, DNS, запуск winws через UAC |
| `android/.../BespredelVpnService.kt` | VpnService + tun2socks |

## Сборка

Проще всего — через **GitHub Actions** (ничего не нужно ставить):

1. Создай репозиторий на GitHub и залей туда эту папку.
2. Вкладка **Actions** → workflow «Сборка Беспредел» запустится сам (или нажми *Run workflow*).
3. Через ~10–15 минут в артефактах будут `Bespredel-android.apk` и `Bespredel-windows-x64.zip`.
4. Чтобы сделать релиз: `git tag v1.0.0 && git push --tags` — файлы появятся в Releases.

Workflow сам скачивает Xray-core (последний релиз), собирает ByeDPI и hev-socks5-tunnel из исходников, берёт winws из `bol-van/zapret-win-bundle`, генерирует платформенные файлы Flutter и собирает приложение.

### Локально

Нужны Flutter 3.24+, для Android — Android SDK + NDK r26, для Windows — Visual Studio 2022 с «Desktop development with C++».

```bash
# Android
export NDK=/путь/к/android-ndk-r26d
bash scripts/build_android_cores.sh
flutter create --org com.domovoi4ik --project-name bespredel --platforms=android .
bash scripts/patch_android.sh
flutter build apk --release --target-platform android-arm64,android-x64
```

```powershell
# Windows (ciadpi.exe собери в MSYS2: make windows CC=gcc, положи как cores-win\bp-ciadpi.exe)
./scripts/prepare_windows_cores.ps1 -Out cores-win
flutter create --org com.domovoi4ik --project-name bespredel --platforms=windows .
flutter build windows --release
Copy-Item cores-win build\windows\x64\runner\Release\cores -Recurse
```

## Важно знать

- **Android**: APK подписан постоянным ключом (`keystore/`), обновления ставятся поверх. Если Play Защита ругается — «Подробнее → Всё равно установить».
- **Windows**: архив распаковывать целиком, папка `cores` должна лежать рядом с `bespredel.exe`. Антивирус может ругаться на WinDivert (часть zapret) — это ложное срабатывание, добавь папку в исключения. Режимы Zapret и DNS запрашивают права администратора (окно UAC).
- **Telegram** в режимах ByeDPI/Zapret может не работать (блок по IP) — для него используй VLESS.
- **Публичные серверы** принадлежат неизвестным людям: трафик внутри HTTPS защищён, но не логинься через них в банк и т.п. без необходимости.
- Публичные конфиги быстро умирают — жми «Обновить» и «Проверить» на вкладке «Серверы», режим «Авто» делает это сам.

## Благодарности

[Xray-core](https://github.com/XTLS/Xray-core) (MPL-2.0) • [ByeDPI](https://github.com/hufrea/byedpi) (MIT) • [zapret](https://github.com/bol-van/zapret) (MIT) • [hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel) (MIT) • [igareck/vpn-configs-for-russia](https://github.com/igareck/vpn-configs-for-russia) • [Comss.one DNS](https://www.comss.ru/)

---
© domovoi4ik
