import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../models.dart';
import 'theme.dart';

class ServersPage extends StatelessWidget {
  const ServersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final list = app.visibleServers;
        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: kRed,
            foregroundColor: Colors.white,
            onPressed: () => _addManual(context),
            icon: const Icon(Icons.add_link_rounded),
            label: const Text('Добавить'),
          ),
          body: CustomScrollView(slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverList.list(children: [
                Row(children: [
                  const Text('Серверы', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Источники подписок',
                    onPressed: () => _sources(context),
                    icon: const Icon(Icons.source_rounded),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(
                  'Всего ${app.servers.length} • рабочих ${app.aliveCount} • источников ${app.sources.where((s) => s.enabled).length}',
                  style: const TextStyle(color: kMuted),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: kSurface2, foregroundColor: Colors.white),
                      onPressed: app.busy ? null : app.updateServers,
                      icon: const Icon(Icons.cloud_download_rounded),
                      label: const Text('Обновить'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: kRed, foregroundColor: Colors.white),
                      onPressed: app.busy || app.servers.isEmpty ? null : app.testServers,
                      icon: const Icon(Icons.speed_rounded),
                      label: const Text('Проверить'),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  FilterChip(
                    label: const Text('Только Reality'),
                    selected: app.onlyReality,
                    onSelected: (v) => app.update(() => app.onlyReality = v),
                  ),
                  const Spacer(),
                  if (app.servers.isNotEmpty)
                    TextButton(
                      onPressed: app.busy ? null : () => _confirmClear(context),
                      child: const Text('Очистить', style: TextStyle(color: kMuted)),
                    ),
                ]),
                if (app.busy) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: app.progress > 0 ? app.progress : null,
                    color: kOrange,
                    backgroundColor: kSurface2,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 6),
                  Text(app.busyText, style: const TextStyle(color: kMuted, fontSize: 12)),
                ],
                const SizedBox(height: 10),
              ]),
            ),
            if (list.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'Список пуст.\nНажми «Обновить», чтобы собрать VLESS-конфиги из открытых репозиториев GitHub.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: kMuted, height: 1.4),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                sliver: SliverList.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _ServerTile(list[i]),
                ),
              ),
          ]),
        );
      },
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Очистить список?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Очистить')),
        ],
      ),
    );
    if (ok == true) app.clearServers();
  }

  Future<void> _addManual(BuildContext context) async {
    final ctl = TextEditingController();
    final clip = await Clipboard.getData('text/plain');
    if (clip?.text?.contains('vless://') ?? false) ctl.text = clip!.text!;
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Добавить сервер'),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: ctl,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'Вставь ссылки vless:// (по одной в строке) или base64-подписку',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Добавить')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final added = app.addManual(ctl.text);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(added ? 'Добавлено' : 'Не нашёл корректных ссылок vless://')),
      );
    }
  }

  void _sources(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurface,
      builder: (c) => const _SourcesSheet(),
    );
  }
}

class _ServerTile extends StatelessWidget {
  final VlessServer s;
  const _ServerTile(this.s);

  @override
  Widget build(BuildContext context) {
    final selected = app.selectedKey == s.key;
    String ping;
    Color pc;
    if (s.tested) {
      ping = s.delayMs != null ? '${s.delayMs} мс' : 'не работает';
      pc = pingColor(s.delayMs);
    } else if (s.tcpMs != null) {
      ping = 'tcp ${s.tcpMs}';
      pc = kMuted;
    } else {
      ping = '—';
      pc = kMuted;
    }
    return Material(
      color: selected ? kRed.withOpacity(0.14) : kSurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => app.selectServer(s),
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: s.raw));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ссылка скопирована')));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? kRed : Colors.white.withOpacity(0.05)),
          ),
          child: Row(children: [
            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? kRed : kMuted, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(children: [
                  _Tag(s.security == 'none' ? 'NONE' : s.security.toUpperCase(),
                      s.isReality ? kGreen : kOrange),
                  const SizedBox(width: 6),
                  _Tag(s.network, kMuted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(s.source, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: kMuted, fontSize: 11)),
                  ),
                ]),
              ]),
            ),
            const SizedBox(width: 8),
            Text(ping, style: TextStyle(color: pc, fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      );
}

class _SourcesSheet extends StatelessWidget {
  const _SourcesSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListenableBuilder(
        listenable: app,
        builder: (context, _) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Center(
              child: Container(
                width: 40, height: 4, margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(children: [
              const Expanded(
                child: Text('Источники подписок', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              TextButton.icon(
                onPressed: () => _add(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Свой'),
              ),
            ]),
            const Text(
              'Открытые репозитории GitHub с VLESS-конфигами. Если GitHub недоступен, используются зеркала jsDelivr и GitHack.',
              style: TextStyle(color: kMuted, fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 12),
            for (final s in app.sources)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Panel(
                  color: kSurface2,
                  padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          s.lastError != null
                              ? 'Ошибка: ${s.lastError}'
                              : s.lastCount > 0
                                  ? 'Получено: ${s.lastCount}'
                                  : s.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: s.lastError != null ? kRed : kMuted, fontSize: 11),
                        ),
                      ]),
                    ),
                    if (s.custom)
                      IconButton(
                        onPressed: () => app.removeSource(s),
                        icon: const Icon(Icons.delete_outline_rounded, color: kMuted),
                      ),
                    Switch(
                      value: s.enabled,
                      activeColor: kRed,
                      onChanged: (v) => app.update(() => s.enabled = v),
                    ),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final name = TextEditingController();
    final url = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Новый источник'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Название')),
          const SizedBox(height: 8),
          TextField(
            controller: url,
            decoration: const InputDecoration(labelText: 'URL подписки (raw .txt)'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Добавить')),
        ],
      ),
    );
    if (ok == true && url.text.trim().startsWith('http')) {
      app.addSource(name.text.trim(), url.text.trim());
    }
  }
}
