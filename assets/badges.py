"""Builds assets/badges.svg, the README's status line picture: the badges
bin/foreman-statusline.sh prints, on a terminal strip. Run: python assets/badges.py
"""
import os
import sys

sys.dont_write_bytecode = True  # no assets/__pycache__ from the import below
from banner import FONT_SANS, FONT_UI, esc

W, ROW, TOP = 1200, 46, 52
ON, OFF = '#af5fff', '#6b7280'  # xterm 256-color 135 and the dim OFF
ROWS = [
    ('[FOREMAN:OFF]', OFF, 'foreman is off in this session'),
    ('[FOREMAN:ON]', ON, 'on for the whole session, no agents yet'),
    ('[FOREMAN:ON › 🔄 run:2 | ⏸️ wait:1 | ✅ done:3]', ON, 'two agents working, one waits for you, three done'),
    ('[FOREMAN:TASK › 🔄 run:1]', ON, 'a single /foreman <task> run'),
]


def main():
    h = TOP + ROW * len(ROWS) + 14
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {h}" width="{W}" height="{h}" role="img" aria-labelledby="t d">',
           '<title id="t">foreman status line badge</title>',
           '<desc id="d">' + esc(' · '.join(b for b, _, _ in ROWS)) + '</desc>',
           f'<rect x="1" y="1" width="{W - 2}" height="{h - 2}" rx="10" fill="#0d1117" stroke="#30363d" stroke-width="2"/>',
           f'<path d="M1 36 H{W - 1}" stroke="#30363d" stroke-width="2"/>']
    for i, c in enumerate(['#ff5f56', '#ffbd2e', '#27c93f']):
        out.append(f'<circle cx="{24 + i * 20}" cy="19" r="6" fill="{c}"/>')
    out.append(f'<text x="{W // 2}" y="24" {FONT_SANS} font-size="13" fill="#8b949e" text-anchor="middle">status line</text>')
    for i, (badge, color, note) in enumerate(ROWS):
        y = TOP + ROW * i + 26
        out.append(f'<text x="28" y="{y}" {FONT_UI} font-size="20" fill="{color}">{esc(badge)}</text>')
        out.append(f'<text x="740" y="{y}" {FONT_SANS} font-size="16" fill="#8b949e">{esc(note)}</text>')
    out.append('</svg>\n')
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'badges.svg')
    with open(path, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(''.join(out))
    print(path, os.path.getsize(path), 'bytes')


if __name__ == '__main__':
    main()
