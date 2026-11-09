#!/usr/bin/env python3
"""Конвертирует стратегии Flowseal/zapret-discord-youtube (*.bat) в strategies.json для Беспредела.

Использование: zapret_strategies.py <папка_flowseal> <выходной_strategies.json>
Плейсхолдеры %BIN% и %LISTS% остаются — приложение подставляет реальные пути.
Game Filter выключен (как по умолчанию у Flowseal: порт-заглушка 12).
"""
import json
import pathlib
import re
import sys


def natural_key(name: str):
    # general.bat первым, затем ALT, ALT2..ALT13, затем остальные
    order = 0 if name == 'general' else 1
    m = re.search(r'\(([^)]*?)(\d*)\)$', name)
    base, num = (m.group(1), int(m.group(2) or 1)) if m else (name, 0)
    return (order, base, num)


def parse(bat: pathlib.Path) -> str | None:
    text = bat.read_text(encoding='utf-8', errors='replace')
    # склеиваем строки, продолжённые ^
    text = re.sub(r'\^\s*\r?\n', ' ', text)
    for line in text.splitlines():
        if 'winws.exe' not in line:
            continue
        i = line.find('winws.exe"')
        if i < 0:
            continue
        args = line[i + len('winws.exe"'):].strip()
        args = re.sub(r'%GameFilter(TCP|UDP)?%', '12', args)
        args = re.sub(r'\s+', ' ', args)
        return args
    return None


def main():
    src = pathlib.Path(sys.argv[1])
    out = pathlib.Path(sys.argv[2])
    items = []
    for bat in src.glob('general*.bat'):
        args = parse(bat)
        if not args:
            continue
        name = bat.stem.replace('general', 'General', 1)
        items.append({'name': name, 'args': args})
    items.sort(key=lambda x: natural_key(x['name'].replace('General', 'general', 1)))
    if not items:
        sys.exit('no strategies found')
    out.write_text(json.dumps(items, ensure_ascii=False, indent=1), encoding='utf-8')
    print(f'strategies: {len(items)}')


if __name__ == '__main__':
    main()
