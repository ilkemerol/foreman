"""Builds assets/foreman.svg, the README banner: a pixel-art night building site.

The foreman (main session) hands pieces to a crew of pixel agents working on the
floors of a building; each agent shows its board stage. All art is drawn here
from character maps (no external images or fonts). Run: python assets/banner.py
"""
import os
from collections import defaultdict

W, H, U = 1200, 600, 4  # canvas and the world's pixel unit

# ---- helpers ---------------------------------------------------------------

class Layer:
    """Collects pixel rects per colour and writes one <path> per colour."""
    def __init__(self, attrs=''):
        self.rects = defaultdict(list)
        self.attrs = attrs

    def rect(self, x, y, w, h, c):
        if w > 0 and h > 0:
            self.rects[c].append((x, y, w, h))

    def sprite(self, rows, pal, x, y, s=U):
        for j, row in enumerate(rows):
            i = 0
            while i < len(row):
                ch = row[i]
                if ch == '.' or ch == ' ':
                    i += 1
                    continue
                k = i
                while k < len(row) and row[k] == ch:
                    k += 1
                self.rect(x + i * s, y + j * s, (k - i) * s, s, pal[ch])
                i = k

    def svg(self):
        out = []
        for c, rs in self.rects.items():
            d = ''.join(f'M{x} {y}h{w}v{h}h{-w}z' for x, y, w, h in rs)
            out.append(f'<path fill="{c}" d="{d}"/>')
        return f'<g{self.attrs}>' + ''.join(out) + '</g>'


def L(x, y, w, h, c, layer):  # world units -> px
    layer.rect(x * U, y * U, w * U, h * U, c)


def blink(values, dur, begin='0s', attr='opacity'):
    return (f'<animate attributeName="{attr}" values="{values}" dur="{dur}" begin="{begin}" '
            f'calcMode="discrete" repeatCount="indefinite"/>')


# ---- palette (foreman-vision's stage colours and icon colours) -------------

OUT = '#1c1306'
RUN, WAIT, VERIFY, DONE = '#22c55e', '#f97316', '#3b82f6', '#c8a6ff'

HAT_Y = {'y': '#facc15', 'h': '#fef08a', 's': '#ca8a04'}
HAT_W = {'y': '#f1f5f9', 'h': '#ffffff', 's': '#94a3b8'}

def pal(shirt, shade, hat=HAT_Y, vest='#f97316'):
    p = {'o': OUT, 'k': '#f4c59c', 'K': '#e0a47a', 'p': '#111827', 'm': '#7c2d12',
         'b': shirt, 'B': shade, 'v': vest, 'w': '#f8fafc', 'd': '#3f2a14',
         'l': '#334155', 'L': '#111827'}
    p.update(hat)
    return p

# a crew member, 12x20, front view, arms down
CREW = [
    '....oooo....',
    '..oohhyyoo..',
    '.ohhyyyyyso.',
    '.ohyyyyyyso.',
    'oossssssssoo',
    '.okkkkkkkko.',
    '.okpkkkkpko.',
    '.okpkkkkpko.',
    '.oKkkkkkkKo.',
    '..okkmmkko..',
    '.oobbbbbboo.',
    'obbbvvvvbbbo',
    'obobvwwvbobo',
    'obobvvvvbobo',
    'okobwwwwboko',
    '.o.oddddo.o.',
    '...ollllo...',
    '...ollollo..',
    '..oLLooLLo..',
    '..oooooooo..',
]
# arms raised: the same body, the arms drawn by ARM beside the head
CREW_UP = CREW[:10] + [
    '.oobbbbbboo.',
    '.obbvvvvbbo.',
    '..obvwwvbo..',
    '..obvvvvbo..',
    '..obwwwwbo..',
    '..oddddddo..',
] + CREW[16:]
ARM = ['ooo', 'oko', 'obo', 'obo', 'obo', 'obo', 'obo', 'obo', 'obo', 'obo']

# the foreman's clipboard: the plan, one task split into three pieces
CLIP = [
    '...ooo...',
    'oooxxxooo',
    'oqqqwqqqo',
    'oqwwwwwqo',
    'oqwqwqwqo',
    'oqGqBqOqo',
    'oqqqqqqqo',
    'ooooooooo',
]

# foreman-vision's own icon: a friendly face under a yellow hard hat
ICON = [
    '................',
    '......oooo......',
    '....oohhyyoo....',
    '...ohhyyyyyso...',
    '..ohyyyyyyyyso..',
    '..ohyyyyyyyyso..',
    'ooossssssssssooo',
    'ohhyyyyyyyyyyyso',
    'oooooooooooooooo',
    '..okkkkkkkkkko..',
    '..okkpkkkkpkko..',
    '..okkpkkkkpkko..',
    '..okkkkkkkkkko..',
    '..okkkpkkpkkko..',
    '...okkkppkkko...',
    '....oooooooo....',
]

# 5x7 pixel font for the title and tagline
FONT = {
    'A': ['.###.', '#...#', '#...#', '#####', '#...#', '#...#', '#...#'],
    'B': ['####.', '#...#', '#...#', '####.', '#...#', '#...#', '####.'],
    'C': ['.###.', '#...#', '#....', '#....', '#....', '#...#', '.###.'],
    'D': ['####.', '#...#', '#...#', '#...#', '#...#', '#...#', '####.'],
    'E': ['#####', '#....', '#....', '####.', '#....', '#....', '#####'],
    'F': ['#####', '#....', '#....', '####.', '#....', '#....', '#....'],
    'H': ['#...#', '#...#', '#...#', '#####', '#...#', '#...#', '#...#'],
    'I': ['###', '.#.', '.#.', '.#.', '.#.', '.#.', '###'],
    'L': ['#....', '#....', '#....', '#....', '#....', '#....', '#####'],
    'M': ['#...#', '##.##', '#.#.#', '#.#.#', '#...#', '#...#', '#...#'],
    'N': ['#...#', '##..#', '#.#.#', '#..##', '#...#', '#...#', '#...#'],
    'O': ['.###.', '#...#', '#...#', '#...#', '#...#', '#...#', '.###.'],
    'P': ['####.', '#...#', '#...#', '####.', '#....', '#....', '#....'],
    'R': ['####.', '#...#', '#...#', '####.', '#.#..', '#..#.', '#...#'],
    'S': ['.####', '#....', '#....', '.###.', '....#', '....#', '####.'],
    'T': ['#####', '..#..', '..#..', '..#..', '..#..', '..#..', '..#..'],
    'U': ['#...#', '#...#', '#...#', '#...#', '#...#', '#...#', '.###.'],
    'W': ['#...#', '#...#', '#...#', '#.#.#', '#.#.#', '##.##', '#...#'],
    '.': ['.', '.', '.', '.', '.', '#', '#'],
    ' ': ['..', '..', '..', '..', '..', '..', '..'],
}


def text_px(layer, s, x, y, scale, color, gap=1, bold=False):
    """Pixel text; returns the end x."""
    for ch in s:
        g = FONT[ch]
        if bold:
            g = [''.join('#' if (i < len(r) and r[i] == '#') or (i > 0 and r[i - 1] == '#') else '.'
                         for i in range(len(r) + 1)) for r in g]
        for j, row in enumerate(g):
            for i, c in enumerate(row):
                if c == '#':
                    layer.rect(x + i * scale, y + j * scale, scale, scale,
                               color[j] if isinstance(color, list) else color)
        x += (len(g[0]) + gap) * scale
    return x


# ---- the scene ---------------------------------------------------------------

def build():
    parts = []
    bg = Layer(' shape-rendering="crispEdges"')

    # night sky in dithered bands
    sky = ['#0b1026', '#0f1531', '#141a3b', '#1a1f46', '#221f4f', '#2c2456', '#3a2a5c']
    band = 136 // len(sky) + 1
    for i, c in enumerate(sky):
        L(0, i * band, 300, band, c, bg)
        if i:  # checker dither on the seam
            for x in range(0, 300, 2):
                L(x + (i % 2), i * band, 1, 1, sky[i - 1], bg)
    # moon
    MOON = ['..oooo..', '.oyyyyo.', 'oyyyhyyo', 'oyhyyyyo', 'oyyyyyyo', 'oyyyyhyo', '.oyyyyo.', '..oooo..']
    bg.sprite(MOON, {'o': '#c7c2a8', 'y': '#fff6d5', 'h': '#e9e1bd'}, 151 * U, 4 * U)
    parts.append(bg.svg())

    # stars, a few twinkling
    stars = [(148, 3), (176, 9), (12, 37), (40, 33), (100, 30), (120, 5), (205, 4), (230, 12), (250, 3),
             (290, 8), (283, 30), (160, 26), (190, 31), (128, 40), (60, 44), (8, 6), (110, 46), (268, 40)]
    for n, (x, y) in enumerate(stars):
        anim = blink('1;0.25;1;1', f'{2 + n % 4}s', f'{n * 0.37:.2f}s') if n % 3 == 0 else ''
        c = '#ffffff' if n % 2 else '#c7d2fe'
        parts.append(f'<rect x="{x * U}" y="{y * U}" width="{U}" height="{U}" fill="{c}" shape-rendering="crispEdges">{anim}</rect>')

    # a shooting star now and then
    parts.append('<g shape-rendering="crispEdges" opacity="0"><rect x="0" y="0" width="8" height="4" fill="#ffffff"/>'
                 '<rect x="-12" y="-4" width="12" height="4" fill="#c7d2fe" opacity="0.7"/><rect x="-28" y="-8" width="16" height="4" fill="#818cf8" opacity="0.4"/>'
                 '<animateTransform attributeName="transform" type="translate" values="330 150;520 236;520 236" keyTimes="0;0.12;1" dur="7s" '
                 'begin="1.5s" repeatCount="indefinite"/>'
                 '<animate attributeName="opacity" values="0;1;1;0;0" keyTimes="0;0.02;0.1;0.12;1" dur="7s" begin="1.5s" repeatCount="indefinite"/></g>')

    # far city
    city = Layer(' shape-rendering="crispEdges"')
    lit = []
    towers = [(0, 104, 14), (14, 96, 10), (24, 110, 16), (40, 100, 12), (52, 92, 9), (61, 106, 14), (75, 98, 12),
              (87, 108, 16), (103, 94, 10), (113, 102, 14), (127, 110, 12), (139, 104, 10), (262, 100, 12),
              (274, 92, 10), (284, 106, 16)]
    for n, (x, top, w) in enumerate(towers):
        L(x, top, w, 136 - top, '#161b38' if n % 2 else '#1b2142', city)
        L(x, top, w, 1, '#262d55', city)
        for wy in range(top + 3, 132, 5):
            for wx in range(x + 2, x + w - 2, 4):
                if (wx * 7 + wy * 3 + n) % 5 == 0:
                    lit.append((wx, wy))
                else:
                    L(wx, wy, 2, 2, '#232a4d', city)
    parts.append(city.svg())
    for n, (x, y) in enumerate(lit):
        anim = blink('1;1;0.15;1', f'{5 + n % 5}s', f'{n * 0.9 % 6:.1f}s') if n % 7 == 0 else ''
        parts.append(f'<rect x="{x * U}" y="{y * U}" width="8" height="8" fill="#f6c86b" opacity="0.85" shape-rendering="crispEdges">{anim}</rect>')

    # ground: sidewalk and street
    g = Layer(' shape-rendering="crispEdges"')
    L(0, 136, 300, 14, '#1d2033', g)
    L(0, 136, 300, 3, '#4b5170', g)
    L(0, 136, 300, 1, '#6b7296', g)
    for x in range(0, 300, 10):
        L(x, 136, 1, 3, '#3a3f5c', g)
    for x in range(4, 300, 16):
        L(x, 144, 8, 1, '#a17a1f', g)
    parts.append(g.svg())

    parts.append(crane_and_building())
    parts.append(left_side())
    parts.append(title())
    parts.append(frame())
    return parts


def crane_and_building():
    out = []
    b = Layer(' shape-rendering="crispEdges"')
    # crane tower (lattice) and jib
    for y in range(14, 136):
        L(272, y, 1, 1, '#eab308', b)
        L(278, y, 1, 1, '#eab308', b)
        d = (y - 14) % 12
        x = 273 + (d if d < 6 else 11 - d)
        L(x, y, 1, 1, '#a16207', b)
    L(270, 134, 11, 2, '#475569', b)
    L(160, 14, 140, 1, '#eab308', b)
    L(160, 18, 140, 1, '#eab308', b)
    for x in range(160, 300):
        d = (x - 160) % 8
        L(x, 15 + (d if d < 4 else 7 - d) * 3 // 4, 1, 1, '#a16207', b)
    for i in range(0, 13):  # tie from the mast top
        L(275 - i * 9, 6 + i * 8 // 13, 2, 1, '#94a3b8', b)
        L(276 + i * 2, 6 + i * 8 // 13, 1, 1, '#94a3b8', b)
    L(274, 4, 3, 10, '#eab308', b)
    L(266, 19, 12, 8, '#facc15', b)  # cab
    L(267, 19, 10, 1, '#fef08a', b)
    L(271, 21, 5, 3, '#7dd3fc', b)
    L(286, 19, 12, 7, '#475569', b)  # counterweight
    L(286, 19, 12, 1, '#64748b', b)

    # building shell
    BRICK, MORTAR = '#9a3b26', '#7a2c1b'
    for col in (150, 259):
        L(col, 61, 3, 75, BRICK, b)
        for y in range(61, 136, 2):
            L(col + (1 if y % 4 == 1 else 0), y, 1, 1, MORTAR, b)
    # top floor: steel columns, open air
    for col in (150, 203, 259):
        L(col, 34, 3, 27, '#64748b', b)
        L(col, 34, 1, 27, '#94a3b8', b)
    L(150, 34, 20, 2, '#b45309', b)  # first beam already set
    L(150, 34, 20, 1, '#d97706', b)
    # slabs
    for y in (61, 97):
        L(146, y, 117, 3, '#9ca3af', b)
        L(146, y, 117, 1, '#d1d5db', b)
        L(146, y + 2, 117, 1, '#6b7280', b)

    for i in range(3):  # stacked beams and a toolbox on the top floor
        L(154 + i, 59 - i * 2, 16 - i * 2, 2, '#b45309', b)
        L(154 + i, 59 - i * 2, 16 - i * 2, 1, '#d97706', b)
    L(193, 55, 8, 6, '#dc2626', b)
    L(193, 55, 8, 1, '#f87171', b)
    L(196, 53, 2, 2, '#1f2937', b)
    # ---- floor 2: verify room (left) and waiting room (right)
    L(153, 64, 53, 33, '#3d4a73', b)       # wall
    L(153, 64, 53, 1, '#2a3354', b)
    L(153, 93, 53, 4, '#6b4f3a', b)        # floor
    L(153, 93, 53, 1, '#8a6a4f', b)
    L(206, 64, 3, 33, '#2a3354', b)        # partition
    L(209, 64, 50, 33, '#2e5f73', b)
    L(209, 93, 50, 4, '#3f6e86', b)
    for x in range(209, 259, 4):
        L(x, 93, 1, 4, '#335a70', b)
    window(b, 160, 69)
    window(b, 238, 69)
    shelf(b, 186, 70)
    # ---- floor 1: main office (left) and done lounge (right)
    L(153, 100, 61, 36, '#8b7bb0', b)
    L(153, 100, 61, 1, '#6c5c91', b)
    L(153, 131, 61, 5, '#8a5a32', b)
    for x in range(153, 214, 6):
        L(x, 131, 1, 5, '#6e4526', b)
    L(153, 131, 61, 1, '#a8743f', b)
    L(214, 100, 3, 36, '#5d4e82', b)
    L(217, 100, 42, 36, '#5b3d63', b)
    L(217, 131, 42, 5, '#7a4a78', b)
    for x in range(217, 259, 4):
        L(x, 131 + (x // 4) % 2, 2, 1, '#6a3d68', b)
    window(b, 160, 105)
    window(b, 240, 105)
    # whiteboard with the plan in the office
    L(184, 104, 22, 12, '#e5e7eb', b)
    L(184, 104, 22, 1, '#9ca3af', b)
    L(193, 106, 4, 2, '#334155', b)
    for i, c in enumerate((RUN, VERIFY, WAIT)):
        L(187 + i * 6, 111, 4, 2, c, b)
    L(194, 108, 1, 2, '#334155', b)
    L(189, 109, 12, 1, '#334155', b)
    out.append(b.svg())

    # ceiling lamps with soft light
    for (x, y, w) in ((168, 64, 30), (232, 64, 22), (175, 100, 34), (236, 100, 20)):
        out.append(f'<polygon points="{x*U} {y*U+8} {(x-w//2)*U} {(y+32)*U} {(x+w//2)*U} {(y+32)*U}" fill="url(#glow)"/>')
        out.append(f'<rect x="{(x-2)*U}" y="{y*U}" width="{5*U}" height="{U*2}" fill="#fde68a" shape-rendering="crispEdges"/>')

    s = Layer(' shape-rendering="crispEdges"')
    # floor 1 desks and agents
    desk(s, 158, 123)
    desk(s, 184, 123)
    lounge(s)
    # floor 2
    desk(s, 168, 87)
    sofa(s, 222, 85)
    out.append('<g id="crew">')
    out.append(s.svg())

    a = Layer(' shape-rendering="crispEdges"')
    a.sprite(CREW[:14], pal('#2563eb', '#1e40af'), 162 * U, 109 * U)   # test runner
    a.sprite(CREW[:14], pal('#16a34a', '#166534'), 188 * U, 109 * U)   # docs scan
    a.sprite(CREW[:14], pal('#0891b2', '#155e75'), 172 * U, 73 * U)    # type check
    a.sprite(CREW[:16], pal('#db2777', '#9d174d'), 228 * U, 72 * U)    # api design, on the sofa
    a.sprite(CREW[:16], pal('#7c3aed', '#5b21b6'), 236 * U, 113 * U)   # lint, in the lounge
    # top floor: guiding the beam, arms up
    p = pal('#ea580c', '#9a3412')
    a.sprite(CREW_UP, p, 176 * U, 41 * U)
    a.sprite(ARM, p, 174 * U, 37 * U)
    a.sprite(ARM, p, 187 * U, 37 * U)
    out.append(a.svg())

    # desks' front edges go over the seated agents
    f = Layer(' shape-rendering="crispEdges"')
    for (x, y) in ((158, 123), (184, 123), (168, 87)):
        desk_front(f, x, y)
    L(232, 120, 22, 2, '#a16207', f)  # cafe table over the lounge agent
    L(232, 120, 22, 1, '#ca8a04', f)
    L(242, 122, 2, 9, '#713f12', f)
    L(238, 130, 10, 1, '#713f12', f)
    sofa_front(f, 222, 85)
    out.append(f.svg())

    # typing hands and screens
    for (x, y, d) in ((162, 122, 0), (188, 122, 0.15), (172, 86, 0.3)):
        out.append(f'<g shape-rendering="crispEdges"><rect x="{(x+2)*U}" y="{y*U}" width="{2*U}" height="{U}" fill="#f4c59c">'
                   + blink('1;0', '0.4s', f'{d}s') + f'</rect><rect x="{(x+8)*U}" y="{y*U}" width="{2*U}" height="{U}" fill="#f4c59c">'
                   + blink('0;1', '0.4s', f'{d}s') + '</rect></g>')
    for (x, y, c, d) in ((172, 115, '#7ee787', 0), (198, 115, '#7ee787', 0.5), (182, 79, '#79c0ff', 0.2)):
        screen = (f'<g shape-rendering="crispEdges"><rect x="{x*U}" y="{y*U}" width="{7*U}" height="{5*U}" fill="#0d1117"/>'
                  f'<rect x="{(x+1)*U}" y="{(y+1)*U}" width="{3*U}" height="{U}" fill="{c}"/>'
                  f'<rect x="{(x+1)*U}" y="{(y+3)*U}" width="{5*U}" height="{U}" fill="{c}" opacity="0.6">{blink("1;0.2;1", "1.2s", f"{d}s")}</rect>'
                  f'<rect x="{(x+4)*U}" y="{(y+1)*U}" width="{2*U}" height="{U}" fill="{c}">{blink("1;0", "0.6s", f"{d}s")}</rect></g>')
        out.append(screen)
    # coffee steam in the lounge
    out.append(f'<g shape-rendering="crispEdges" fill="#e5e7eb" opacity="0.7"><rect x="{247*U}" y="{116*U}" width="{U}" height="{U}">'
               + blink('1;0;0', '1.5s') + f'</rect><rect x="{248*U}" y="{114*U}" width="{U}" height="{U}">' + blink('0;1;0', '1.5s')
               + f'</rect><rect x="{247*U}" y="{112*U}" width="{U}" height="{U}">' + blink('0;0;1', '1.5s') + '</rect></g>')
    out.append(f'<rect x="{246*U}" y="{117*U}" width="{3*U}" height="{3*U}" fill="#f8fafc" shape-rendering="crispEdges"/>')

    # the beam on the crane, slowly lowered and raised
    beam = Layer(' shape-rendering="crispEdges"')
    L(181, 19, 6, 2, '#475569', beam)        # trolley
    L(183, 21, 1, 9, '#cbd5e1', beam)        # cable
    L(182, 30, 3, 2, '#94a3b8', beam)        # hook
    for i in range(8):
        L(183 - i * 2, 32 + i // 2 * 1, 1, 1, '#cbd5e1', beam)
        L(184 + i * 2, 32 + i // 2 * 1, 1, 1, '#cbd5e1', beam)
    L(166, 35, 36, 3, '#b45309', beam)
    L(166, 35, 36, 1, '#d97706', beam)
    L(166, 37, 36, 1, '#7c2d12', beam)
    out.append('<g>' + beam.svg() + '<animateTransform attributeName="transform" type="translate" '
               'values="0 0;0 -4;0 -4;0 0;0 0" keyTimes="0;0.2;0.5;0.7;1" calcMode="discrete" dur="4s" repeatCount="indefinite"/></g>')
    # aviation light
    out.append(f'<rect x="{275*U}" y="{2*U}" width="{U}" height="{2*U}" fill="#ef4444" shape-rendering="crispEdges">{blink("1;0.15", "1.4s")}</rect>')
    out.append(f'<circle cx="{275*U+2}" cy="{3*U}" r="14" fill="url(#redglow)">{blink("1;0", "1.4s")}</circle>')
    out.append('</g>')

    # room signs (foreman-vision style)
    out.append(sign(155 * U, 96 * U - 2, 'Verify desk', '#79c0ff'))
    out.append(sign(211 * U, 96 * U - 2, 'Waiting room', '#ffb366'))
    out.append(sign(155 * U, 135 * U - 2, 'Main office', '#7ee787'))
    out.append(sign(219 * U, 135 * U - 2, 'Done lounge ✓', '#c8a6ff'))

    # name tags and tool pills
    out.append(tag(222 * U, 166, 'new floor', RUN, '▸ Edit floor3.ts'))
    out.append(tag(178 * U, 246, 'type check', VERIFY, '▸ Read diff', verifying=True))
    out.append(tag(165 * U, 402, 'test runner', RUN, '▸ Bash npm test'))
    out.append(tag(194 * U, 434, 'docs scan', RUN, '▸ Grep "board"'))
    out.append(tag(242 * U, 404, 'lint', DONE, '✓ done'))
    out.append(balloon(234 * U, 222))
    return ''.join(out)


def window(b, x, y):
    L(x, y, 14, 12, '#1f2937', b)
    L(x + 1, y + 1, 12, 10, '#111a3a', b)
    L(x + 1, y + 1, 12, 3, '#18234d', b)
    L(x + 7, y + 1, 1, 10, '#1f2937', b)
    L(x + 1, y + 6, 12, 1, '#1f2937', b)
    L(x + 3, y + 2, 1, 1, '#ffffff', b)
    L(x + 10, y + 4, 1, 1, '#c7d2fe', b)
    L(x - 1, y + 12, 16, 1, '#6b7280', b)


def shelf(b, x, y):
    L(x, y, 16, 20, '#5b3a1f', b)
    for r in range(3):
        yy = y + 1 + r * 6
        L(x + 1, yy, 14, 5, '#3b2412', b)
        for i, c in enumerate(('#ef4444', '#3b82f6', '#22c55e', '#eab308', '#a855f7', '#f97316', '#14b8a6')):
            if (i + r) % 4 != 3:
                L(x + 1 + i * 2, yy + 1 + (i % 2), 2, 4 - (i % 2), c, b)


def desk(s, x, y):
    # monitor back panel and stand drawn behind the agent? no: monitor sits on the desk to the right
    L(x + 13, y - 9, 9, 7, '#1f2937', s)
    L(x + 16, y - 2, 3, 2, '#374151', s)


def desk_front(f, x, y):
    L(x, y, 24, 2, '#b07a3c', f)
    L(x, y, 24, 1, '#d4a05a', f)
    L(x + 1, y + 2, 22, 4, '#7c4a1e', f)
    L(x + 2, y + 3, 6, 2, '#6a3d16', f)
    L(x + 1, y + 6, 2, 2, '#4a2a0f', f)
    L(x + 21, y + 6, 2, 2, '#4a2a0f', f)
    L(x + 3, y - 1, 7, 1, '#e5e7eb', f)  # keyboard


def lounge(s):
    L(230, 116, 4, 15, '#6b2d5e', s)   # chair backs
    L(252, 116, 4, 15, '#6b2d5e', s)
    L(222, 114, 6, 17, '#2f6b3a', s)   # plant
    L(223, 128, 4, 3, '#a16207', s)


def sofa(s, x, y):
    L(x, y - 4, 28, 6, '#9f1239', s)
    L(x, y - 4, 28, 1, '#e11d48', s)


def sofa_front(f, x, y):
    L(x, y + 2, 28, 4, '#be123c', f)
    L(x, y + 2, 28, 1, '#fb7185', f)
    L(x - 2, y - 2, 3, 8, '#9f1239', f)
    L(x + 27, y - 2, 3, 8, '#9f1239', f)
    L(x + 1, y + 6, 2, 2, '#4c0519', f)
    L(x + 25, y + 6, 2, 2, '#4c0519', f)


FONT_UI = "font-family=\"ui-monospace, 'SF Mono', Consolas, 'Liberation Mono', Menlo, monospace\""
FONT_SANS = "font-family=\"system-ui, -apple-system, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif\""


def tw(s, size):  # rough text width
    return int(len(s) * size * 0.62) + 1


def tag(cx, y, name, color, pill, verifying=False):
    """foreman-vision's name tag (coloured frame) with the tool pill under it."""
    nw = tw(name, 12) + 12
    pw = tw(pill, 11) + 10
    x = cx - nw // 2
    px_ = cx - pw // 2
    light = {RUN: '#7ee787', VERIFY: '#79c0ff', WAIT: '#ffb366', DONE: '#c8a6ff'}.get(color, '#7dd3fc')
    g = [f'<g shape-rendering="crispEdges">',
         f'<rect x="{x}" y="{y}" width="{nw}" height="18" fill="#1b1d26" stroke="{color}" stroke-width="2"/>',
         f'<text x="{cx}" y="{y + 13}" {FONT_SANS} font-size="12" font-weight="700" fill="{light}" text-anchor="middle">{name}</text>',
         f'<rect x="{px_}" y="{y + 21}" width="{pw}" height="15" fill="#0d1117" stroke="#30363d" stroke-width="1"/>',
         f'<text x="{cx}" y="{y + 32}" {FONT_UI} font-size="11" fill="{light}" text-anchor="middle">{esc(pill)}</text>']
    if verifying:  # the foreman's magnifier over a verifying piece
        g.append(f'<g transform="translate({x + nw + 4} {y})"><rect x="0" y="0" width="16" height="16" fill="{VERIFY}"/>'
                 f'<rect x="4" y="3" width="6" height="2" fill="#fff"/><rect x="3" y="5" width="2" height="5" fill="#fff"/>'
                 f'<rect x="9" y="5" width="2" height="5" fill="#fff"/><rect x="4" y="10" width="6" height="2" fill="#fff"/>'
                 f'<rect x="10" y="11" width="3" height="3" fill="#fff"/>{blink("1;0.4", "0.8s")}</g>')
    g.append('</g>')
    return ''.join(g)


def sign(x, y, label, color):
    w = tw(label, 11) + 12
    return (f'<g shape-rendering="crispEdges"><rect x="{x}" y="{y - 14}" width="{w}" height="18" fill="#272c3b" stroke="#141821" stroke-width="2"/>'
            f'<text x="{x + 6}" y="{y}" {FONT_SANS} font-size="11" font-weight="700" fill="{color}">{esc(label)}</text></g>')


def balloon(cx, y):
    """A waiting agent's speech balloon, bobbing, with a ringing bell."""
    w, h = 176, 44
    x = cx - w // 2
    return (f'<g shape-rendering="crispEdges">'
            f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#ffffff" stroke="#1b1f2a" stroke-width="3"/>'
            f'<rect x="{cx - 6}" y="{y + h + 1}" width="12" height="4" fill="#1b1f2a"/><rect x="{cx - 3}" y="{y + h + 5}" width="6" height="4" fill="#1b1f2a"/>'
            f'<g transform="translate({x + 8} {y + 13})"><rect x="3" y="0" width="6" height="2" fill="{WAIT}"/><rect x="1" y="2" width="10" height="8" fill="{WAIT}"/>'
            f'<rect x="0" y="10" width="12" height="2" fill="{WAIT}"/><rect x="5" y="12" width="2" height="2" fill="#7c2d12"/>'
            f'{blink("1;0.2", "0.6s")}</g>'
            f'<text x="{x + 26}" y="{y + 18}" {FONT_UI} font-size="11" font-weight="700" fill="#d9480f">needs-decision:</text>'
            f'<text x="{x + 26}" y="{y + 34}" {FONT_SANS} font-size="12" fill="#1b1f2a">which approach?</text>'
            f'<animateTransform attributeName="transform" type="translate" values="0 0;0 -4" dur="1.6s" calcMode="discrete" repeatCount="indefinite"/></g>')


def say(x, y, w, lines):
    """The foreman's speech balloon, its tail pointing right at him."""
    h = 14 + 17 * len(lines)
    g = [f'<g shape-rendering="crispEdges"><rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#ffffff" stroke="#1b1f2a" stroke-width="3"/>',
         f'<rect x="{x + w + 1}" y="{y + 12}" width="5" height="10" fill="#1b1f2a"/><rect x="{x + w + 6}" y="{y + 15}" width="5" height="5" fill="#1b1f2a"/>']
    for i, t in enumerate(lines):
        g.append(f'<text x="{x + 10}" y="{y + 22 + i * 17}" {FONT_SANS} font-size="13" font-weight="{700 if i == 0 else 600}" fill="#1b1f2a">{esc(t)}</text>')
    g.append('</g>')
    return ''.join(g)


def esc(s):
    return s.replace('&', '&amp;').replace('<', '&lt;').replace('"', '&quot;')


def left_side():
    out = []
    # street lamp
    lamp = Layer(' shape-rendering="crispEdges"')
    L(130, 104, 2, 32, '#334155', lamp)
    L(128, 134, 6, 2, '#1f2937', lamp)
    L(126, 102, 8, 3, '#334155', lamp)
    L(127, 105, 6, 1, '#fde68a', lamp)
    out.append(f'<polygon points="{127*U} {106*U} {116*U} {136*U} {144*U} {136*U} {133*U} {106*U}" fill="url(#glow)"/>')
    out.append('<ellipse cx="424" cy="544" rx="80" ry="12" fill="url(#spot)"/>')
    # bricks, cones and a barrier
    for i in range(3):
        for j in range(3 - i):
            L(40 + j * 5 + i * 2, 132 - i * 3, 5, 3, '#b45309', lamp)
            L(40 + j * 5 + i * 2, 132 - i * 3, 5, 1, '#d97706', lamp)
            L(40 + j * 5 + i * 2 + 4, 132 - i * 3, 1, 3, '#7c2d12', lamp)
    for x in (62, 68):
        L(x + 1, 129, 2, 1, '#f97316', lamp)
        L(x, 130, 4, 2, '#f8fafc', lamp)
        L(x, 132, 4, 2, '#f97316', lamp)
        L(x - 1, 134, 6, 2, '#ea580c', lamp)
    out.append(lamp.svg())

    # the foreman
    f = Layer(' shape-rendering="crispEdges"')
    fp = pal('#2563eb', '#1e40af', hat=HAT_W)
    f.sprite(CREW, fp, 380, 424, 6)
    f.sprite(CLIP, {'o': OUT, 'x': '#94a3b8', 'q': '#1d4ed8', 'w': '#dbeafe', 'G': RUN, 'B': '#93c5fd', 'O': WAIT}, 422, 484, 6)
    f.sprite(['ooo', 'okk', 'ooo'], fp, 410, 502, 6)
    out.append(f.svg())
    out.append(tag(422, 370, 'Foreman', '#38bdf8', '▸ Agent × 6'))
    out.append(say(158, 424, 214, ['Three pieces, in parallel.', 'Report back to me.']))

    # orders: dashes marching from the clipboard up a trunk line to each floor
    trunk = f'M478 506H574V194'
    branches = [(194, 588), (330, 588), (470, 588)]
    ds = [trunk] + [f'M574 {y}H{x}' for y, x in branches]
    for d in ds:
        out.append(f'<path d="{d}" fill="none" stroke="#7aa2ff" stroke-width="4" stroke-dasharray="8 8" shape-rendering="crispEdges">'
                   f'<animate attributeName="stroke-dashoffset" values="16;0" dur="0.6s" repeatCount="indefinite"/></path>')
    for y, x in branches:
        out.append(f'<g fill="#7aa2ff" shape-rendering="crispEdges"><rect x="{x}" y="{y - 6}" width="4" height="12"/>'
                   f'<rect x="{x + 4}" y="{y - 4}" width="4" height="8"/><rect x="{x + 8}" y="{y - 2}" width="4" height="4"/></g>')
        out.append(f'<rect x="{570}" y="{y - 4}" width="8" height="8" fill="#c7d2fe" shape-rendering="crispEdges"/>')
    return ''.join(out)


def title():
    out = []
    t = Layer(' shape-rendering="crispEdges"')
    t.sprite(ICON, {'o': '#1c1306', 'y': '#facc15', 'h': '#fef08a', 's': '#ca8a04', 'k': '#f4c59c', 'p': '#111827'}, 28, 34, 4)
    word, x0, y0, s = 'FOREMAN', 104, 36, 9
    # extrusion, outline, face
    for k in (3, 2, 1):
        text_px(t, word, x0 + k * 4, y0 + k * 4, s, '#7c2d12' if k > 1 else '#9a3412', gap=2, bold=True)
    for dx, dy in ((-4, 0), (4, 0), (0, -4), (0, 4)):
        text_px(t, word, x0 + dx, y0 + dy, s, OUT, gap=2, bold=True)
    grad = ['#fef08a', '#fde047', '#facc15', '#fbbf24', '#f59e0b', '#f97316', '#ea580c']
    text_px(t, word, x0, y0, s, grad, gap=2, bold=True)
    # tagline
    x = text_px(t, 'THE FOREMAN ', 32, 132, 2, '#e6e6eb', gap=1)
    x = text_px(t, 'PLANS. ', x, 132, 2, '#fb923c', gap=1)
    x = text_px(t, 'THE CREW ', x, 132, 2, '#e6e6eb', gap=1)
    text_px(t, 'BUILDS.', x, 132, 2, '#4ade80', gap=1)
    out.append(t.svg())
    # sparkle on the title
    out.append('<g shape-rendering="crispEdges" fill="#ffffff"><rect x="182" y="34" width="6" height="6"/>'
               '<rect x="176" y="36" width="4" height="2"/><rect x="190" y="36" width="4" height="2"/>'
               '<rect x="184" y="28" width="2" height="4"/><rect x="184" y="42" width="2" height="4"/>'
               + blink('1;0;0;0', '2.4s') + '</g>')
    out.append(board())
    return ''.join(out)


def board():
    """The agent board, as foreman-vision's board popup draws it."""
    rows = [('1', 'new floor', RUN, 'running'), ('2', 'test runner', RUN, 'running'), ('3', 'docs scan', RUN, 'running'),
            ('4', 'type check', VERIFY, 'verifying'), ('5', 'api design', WAIT, 'waiting'), ('6', 'lint', '#6b7280', 'done')]
    x, y, w = 32, 162, 248
    h = 50 + len(rows) * 19
    g = [f'<g shape-rendering="crispEdges">',
         f'<rect x="{x + 6}" y="{y + 6}" width="{w}" height="{h}" fill="#000000" opacity="0.45"/>',
         f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#ffffff" stroke="#1b1f2a" stroke-width="3"/>',
         f'<text x="{x + 10}" y="{y + 19}" {FONT_SANS} font-size="13" font-weight="800" fill="#1b1f2a">agent board</text>',
         f'<rect x="{x + w - 70}" y="{y + 7}" width="60" height="16" fill="#2a2113" stroke="#6b5426" stroke-width="1"/>',
         f'<text x="{x + w - 40}" y="{y + 19}" {FONT_SANS} font-size="10" font-weight="700" fill="#ffd28a" text-anchor="middle">foreman</text>',
         f'<text x="{x + 10}" y="{y + 40}" {FONT_SANS} font-size="10" font-weight="700" fill="#6b7280">#</text>',
         f'<text x="{x + 30}" y="{y + 40}" {FONT_SANS} font-size="10" font-weight="700" fill="#6b7280">JOB</text>',
         f'<text x="{x + 150}" y="{y + 40}" {FONT_SANS} font-size="10" font-weight="700" fill="#6b7280">STAGE</text>',
         f'<rect x="{x + 8}" y="{y + 44}" width="{w - 16}" height="2" fill="#1b1f2a"/>']
    for i, (n, job, c, st) in enumerate(rows):
        yy = y + 60 + i * 19
        g.append(f'<text x="{x + 10}" y="{yy}" {FONT_UI} font-size="12" fill="#6b7280">{n}</text>')
        g.append(f'<text x="{x + 30}" y="{yy}" {FONT_UI} font-size="12" fill="#1b1f2a">{job}</text>')
        dot = f'<rect x="{x + 150}" y="{yy - 9}" width="8" height="8" fill="{c}" stroke="#1b1f2a" stroke-width="1"/>'
        if st in ('running', 'waiting'):
            dot = dot[:-2] + '>' + blink('1;0.35', '1s' if st == 'running' else '0.6s', f'{i * 0.2:.1f}s') + '</rect>'
        g.append(dot)
        g.append(f'<text x="{x + 164}" y="{yy}" {FONT_UI} font-size="12" fill="#1b1f2a">{st}</text>')
        if i < len(rows) - 1:
            g.append(f'<rect x="{x + 8}" y="{yy + 5}" width="{w - 16}" height="1" fill="#d0d4dc"/>')
    g.append('</g>')
    return ''.join(g)


def frame():
    f = Layer(' shape-rendering="crispEdges"')
    f.rect(0, 0, W, 8, '#0b0d14'); f.rect(0, H - 8, W, 8, '#0b0d14')
    f.rect(0, 0, 8, H, '#0b0d14'); f.rect(W - 8, 0, 8, H, '#0b0d14')
    f.rect(8, 8, W - 16, 4, '#3b4160'); f.rect(8, 8, 4, H - 16, '#3b4160')
    f.rect(8, H - 12, W - 16, 4, '#151827'); f.rect(W - 12, 8, 4, H - 16, '#151827')
    # caption plate on the street
    out = f.svg()
    cap = 'main session = foreman  ·  subagents = crew  ·  one level deep'
    out += (f'<g shape-rendering="crispEdges"><rect x="404" y="562" width="{tw(cap, 13) + 20}" height="24" fill="#0d1117" stroke="#30363d" stroke-width="2"/>'
            f'<text x="414" y="579" {FONT_UI} font-size="13" fill="#e6e6eb">{esc(cap)}</text></g>')
    return out


def main():
    body = ''.join(build())
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" role="img" aria-labelledby="t d">'
           '<title id="t">foreman</title>'
           '<desc id="d">Pixel-art night building site: the foreman in a white hard hat holds the plan and sends dashed orders to a crew '
           'of pixel agents on the floors of a building. Each agent shows its board stage: running, verifying, waiting with a '
           'needs-decision balloon, done in the lounge. A crane lowers a beam onto the top floor.</desc>'
           '<defs><linearGradient id="glow" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fde68a" stop-opacity="0.32"/>'
           '<stop offset="1" stop-color="#fde68a" stop-opacity="0"/></linearGradient>'
           '<radialGradient id="spot"><stop offset="0" stop-color="#fde68a" stop-opacity="0.35"/><stop offset="1" stop-color="#fde68a" stop-opacity="0"/></radialGradient><radialGradient id="redglow"><stop offset="0" stop-color="#ef4444" stop-opacity="0.7"/><stop offset="1" stop-color="#ef4444" stop-opacity="0"/></radialGradient></defs>'
           f'<rect width="{W}" height="{H}" fill="#0b1026"/>' + body + '</svg>\n')
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'foreman.svg')
    with open(path, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(svg)
    print(path, len(svg), 'bytes')


if __name__ == '__main__':
    main()
