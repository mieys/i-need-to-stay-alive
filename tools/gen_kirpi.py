"""Evcil hayvan KİRPİ - "Tombul Kirpi" (2026-10-13; kullanıcı 4 prototipten A'yı seçti, bkz. tools/proto_20261013/gen_kirpi_pet.py).
ESKİ sayfa (kullanıcının masaüstü çizimi, 30x25 px) + eski üretici: tools/proto_20261013/out/eski_kirpi/ (git'te YOKTU, tek kopya orada).

Çizim: dolgu haritası ('q' = diken bölgesi) + otomatik 1 px kontur (köpek/peri mürekkebi). Diken dokusu texture(): üst kenar açık, alt kenar /
yüz komşusu koyu, şaşırtmalı krem uç + sol altında koyu çizgi. Diken AÇIK = spike_list(): merkezden eşit açılı ışın, 2 px uç.
Yönler: right (yan), left (right'ın aynası), down (ön), up (arka). Her yön x (acik|kapali):
    <durum>_<yön>        duruş, IDLE_SEQ (4,5 sn döngü, 8 fps taban + kare süreleri): yavaş nefes (sırt 2 kademede 1 px kabarır, DOKU KAYMAZ),
                         arada göz kırpma + iki kez burun çekme. Kullanıcı ilk sürümü (3 fps, satır silip çöken 2 kare) "doğal değil" buldu.
    <durum>_walk_<yön>   yürüyüş, 4 kare (gövde 1 px sekme + ayak değişimi), 8 fps
Hücre 32x32, ayak çizgisi hücre satırı 30 (kirpi_pet.gd sprite ofseti -14 ile düğüm orijini), gölge karelere GÖMÜLÜ (ground_shadow.gd tonları).
Sayfa 288x256: sütun 0-4 duruş pozları (IDLE_POSES), 5-8 yürüyüş; satır = durum (acik 0-3, kapali 4-7) x yön (right, down, up, left).
Çıktı: assets/pets/kirpi/kirpi_sheet.png + kirpi_frames.tres (+ önizleme: tools/proto_20261013/out/kirpi_v2_anim.gif / _kareler.png).
Kullanım (proje kökünden): python -I tools/gen_kirpi.py   sonra   Godot --headless --path . --import
"""
import math
import os

from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
OUT = os.path.join(ROOT, 'assets', 'pets', 'kirpi')
PREVIEW = os.path.join(ROOT, 'tools', 'proto_20261013', 'out')
CELL = 32
FOOT_ROW = 28               # ayak dolgusunun hücre satırı (altındaki kontur 29, kirpi_pet.gd orijini 30)
DIRS = ['right', 'down', 'up', 'left']  # satır sırası
IDLE_FPS = 8.0
WALK_FPS = 8.0
IDLE_POSES = ['rest', 'half', 'full', 'blink', 'sniff']       # sayfa sütunları
# (poz, süre: IDLE_FPS karesi) - toplam 36 = 4,5 sn. Nefes: dinlenme -> yarım -> dolu (tut) -> yarım -> dinlenme.
IDLE_SEQ = [('rest', 6), ('half', 1), ('full', 6), ('half', 1), ('rest', 3), ('blink', 1), ('rest', 2), ('half', 1), ('full', 6), ('half', 1),
            ('rest', 2), ('sniff', 1), ('rest', 1), ('sniff', 1), ('rest', 3)]
INK = (46, 30, 44)
QUILL = set('dmlt')
PAL = {'d': (96, 62, 50), 'm': (140, 96, 68), 'l': (178, 130, 90), 't': (240, 220, 178),
       'f': (250, 226, 190), 's': (226, 188, 148), 'c': (244, 152, 146), 'n': (58, 36, 46), 'e': (44, 28, 36),
       'E': (236, 158, 148), 'p': (214, 166, 130)}

# rows: dolgu; hub/arc: açık diken ışınları (merkez, başlangıç°, bitiş°, adet); breath: nefeste kabaran sütun aralıkları (yarım, dolu);
# blink / sniff: (x, y) -> yeni harf (None = sil) - göz kapanır / burun ucu 1 px kalkar (arka görünümde yok);
# walk: kare başına (gövde kayması, [(ayak sol sütunu, 'down' | 'lift')]); shadow: (yarı genişlik, çekirdek yarı genişlik).
VIEWS = {
    'right': {
        'rows': [
            ".....qqqqqq.........",
            "...qqqqqqqqqq.......",
            "..qqqqqqqqqqqq......",
            ".qqqqqqqqqqqqq......",
            ".qqqqqqqqqqqqEfff...",
            "qqqqqqqqqqqqqffeff..",
            "qqqqqqqqqqqqfffefffn",
            "qqqqqqqqqqqsfccffff.",
            ".qqqqqqqqqssfffff...",
            "..qqsssssssssff.....",
            "...pp......pp.......",
        ],
        'hub': (6, 7), 'arc': (28, 205, 9), 'breath': ((6, 9), (4, 11)), 'shadow': (10, 7),
        'blink': {(15, 5): 'f', (14, 6): 'e'}, 'sniff': {(19, 6): None, (18, 5): 'f', (19, 5): 'n'},
        'walk': [(0, [(3, 'down'), (11, 'down')]), (-1, [(2, 'down'), (12, 'lift')]),
                 (0, [(4, 'down'), (10, 'down')]), (-1, [(5, 'lift'), (11, 'down')])],
    },
    'down': {
        'rows': [
            ".....qqqqq.....",
            "...qqqqqqqqq...",
            "..qqqqqqqqqqq..",
            ".qqqqqqqqqqqqq.",
            ".qqqEqfffqEqqq.",
            "qqqqqfffffqqqqq",
            "qqqqfefffefqqqq",
            "qqqqcefnfecqqqq",
            ".qqqqfffffqqqq.",
            "..qqqqsssqqqq..",
            "...pp.....pp...",
        ],
        'hub': (7, 6), 'arc': (-25, 205, 11), 'breath': ((5, 9), (4, 10)), 'shadow': (8, 5),
        'blink': {(5, 7): 'f', (9, 7): 'f'}, 'sniff': {(7, 7): 'f', (7, 6): 'n'},
        'walk': [(0, [(3, 'down'), (10, 'down')]), (-1, [(3, 'down'), (10, 'lift')]),
                 (0, [(3, 'down'), (10, 'down')]), (-1, [(3, 'lift'), (10, 'down')])],
    },
    'up': {
        'rows': [
            ".....qqqqq.....",
            "...qqqqqqqqq...",
            "..qqqqqqqqqqq..",
            ".qqqqqqqqqqqqq.",
            ".qqqqqqqqqqqqq.",
            "qqqqqqqqqqqqqqq",
            "qqqqqqqqqqqqqqq",
            "qqqqqqqqqqqqqqq",
            ".qqqqqqqqqqqqq.",
            "..qqqqsssqqqq..",
            "...pp.....pp...",
        ],
        'hub': (7, 6), 'arc': (-25, 205, 11), 'breath': ((5, 9), (4, 10)), 'shadow': (8, 5),
        'walk': [(0, [(3, 'down'), (10, 'down')]), (-1, [(3, 'lift'), (10, 'down')]),
                 (0, [(3, 'down'), (10, 'down')]), (-1, [(3, 'down'), (10, 'lift')])],
    },
}


def grid(rows):
    w = len(rows[0])
    g = {}
    for y, row in enumerate(rows):
        assert len(row) == w, (y, row, len(row), w)
        for x, ch in enumerate(row):
            if ch != '.':
                g[(x, y)] = ch
    return g, w, len(rows)


def texture(g, step=4):
    out = dict(g)
    for (x, y), ch in g.items():
        if ch != 'q':
            continue
        up, down = g.get((x, y - 1)), g.get((x, y + 1))
        side = [g.get((x - 1, y)), g.get((x + 1, y))]
        tone = 'm'
        if up is None:
            tone = 'l'
        elif down != 'q' or any(n is not None and n != 'q' for n in side):
            tone = 'd'
        elif (y + 1) % 2 == 0 and (x + 3 + ((y + 3) // 2 % 2) * (step // 2)) % step == 0:
            tone = 't'
        elif g.get((x, y - 2)) is None:
            tone = 'l'
        out[(x, y)] = tone
    for (x, y), ch in list(out.items()):          # her ucun sol altına koyu gölge: nokta değil, diken çizgisi okunsun
        if ch == 't' and out.get((x - 1, y + 1)) == 'm':
            out[(x - 1, y + 1)] = 'd'
    return out


def spike_list(g, hub, arc):
    """Diken AÇIK uçları: merkezden eşit açılı ışın; ışının değdiği en dış diken pikseli (taban) + 2 px uç. [(taban, p1, p2)]"""
    out = []
    a0, a1, n = arc
    for i in range(n):
        a = math.radians(a0 + (a1 - a0) * i / (n - 1))
        dx, dy = math.cos(a), -math.sin(a)
        base = None
        r = 30.0
        while r > 0.0:
            p = (round(hub[0] + dx * r), round(hub[1] + dy * r))
            if p in g:
                base = p if g[p] in QUILL else None
                break
            r -= 0.25
        if base is None:
            continue
        p1 = (round(base[0] + dx * 1.3), round(base[1] + dy * 1.3))
        p2 = (round(base[0] + dx * 2.5), round(base[1] + dy * 2.5))
        if p1 in g or p2 in g:
            continue
        out.append((base, p1, p2))
    return out


def quill_top(g, x):
    return min(y for (gx, y), ch in g.items() if gx == x and ch in QUILL)


def add_spikes(g, spikes, rest=None, band=None):
    """Uçları dolguya ekler. Nefes pozunda (rest = kabarmamış dolgu, band = kabaran sütunlar) tabanı kabaran sütunun TEPESİ olan uçlar sırtla
    birlikte 1 px kalkar - uçlar her pozda yeniden hesaplanırsa yer değiştirip titriyordu."""
    out = dict(g)
    for base, p1, p2 in spikes:
        up = 1 if band is not None and band[0] <= base[0] <= band[1] and base[1] == quill_top(rest, base[0]) else 0
        out[(p1[0], p1[1] - up)] = 'l'
        out[(p2[0], p2[1] - up)] = 't'
    return out


def inflate(g, x0, x1):
    """Nefes: x0..x1 sütunlarında diken bölgesinin tepesine 1 px eklenir (sırt kabarır; doku ve yüz yerinde kalır)."""
    out = dict(g)
    for x in range(x0, x1 + 1):
        out[(x, quill_top(g, x) - 1)] = 'l'
    return out


def edit(g, changes):
    out = dict(g)
    for p, ch in changes.items():
        if ch is None:
            out.pop(p, None)
        else:
            out[p] = ch
    return out


def pose(g, h, dy, feet):
    """Yürüyüş karesi: gövde dy kadar kayar; 'down' ayak yere basar (gövde kalkmışsa 2 px bacak), 'lift' ayak havada (gövdenin hemen altı)."""
    out = {(x, y + dy): ch for (x, y), ch in g.items() if ch != 'p'}
    for x, kind in feet:
        ys = [h - 1] if kind == 'down' else [h - 1 + dy]
        if kind == 'down' and dy < 0:
            ys.append(h - 2)
        for y in ys:
            for fx in (x, x + 1):
                out.setdefault((fx, y), 'p')
    return out


def cell(g, w, h, shadow, flip=False):
    """32x32 kare: gölge + dolgu + kontur. Gövde yatayda ortalı, ayak satırı FOOT_ROW."""
    im = Image.new('RGBA', (CELL, CELL), (0, 0, 0, 0))
    px = im.load()
    hw, core = shadow
    for row, half, alpha in ((FOOT_ROW, hw - 1, 71), (FOOT_ROW + 1, hw, 71), (FOOT_ROW + 2, hw - 2, 71), (FOOT_ROW + 1, core, 108)):
        for x in range(CELL // 2 - half, CELL // 2 + half):
            px[x, row] = (0, 0, 0, alpha)
    ox, oy = CELL // 2 - w // 2, FOOT_ROW - (h - 1)
    ink = set()
    for (x, y) in g:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + dx, y + dy) not in g:
                ink.add((x + dx, y + dy))
    for (x, y) in ink:
        px[x + ox, y + oy] = INK + (255,)
    for (x, y), ch in g.items():
        px[x + ox, y + oy] = PAL[ch] + (255,)
    return im.transpose(Image.FLIP_LEFT_RIGHT) if flip else im


def frames_for(view, opened):
    """(duruş pozları sözlüğü, yürüyüş kareleri, genişlik, yükseklik) - kareler dolgu sözlüğü."""
    g, w, h = grid(view['rows'])
    g = texture(g)

    tips = spike_list(g, view['hub'], view['arc']) if opened else []
    rest = add_spikes(g, tips)
    half, full = view['breath']
    idle = {'rest': rest, 'half': add_spikes(inflate(g, *half), tips, g, half), 'full': add_spikes(inflate(g, *full), tips, g, full),
            'blink': edit(rest, view.get('blink', {})), 'sniff': edit(rest, view.get('sniff', {}))}
    walk = [pose(rest, h, dy, feet) for dy, feet in view['walk']]
    return idle, walk, w, h


def main():
    ncol = len(IDLE_POSES) + 4
    sheet = Image.new('RGBA', (CELL * ncol, CELL * 8), (0, 0, 0, 0))
    cells = {}
    for si, state in enumerate(('acik', 'kapali')):
        for di, d in enumerate(DIRS):
            view = VIEWS['right' if d == 'left' else d]
            idle, walk, w, h = frames_for(view, state == 'acik')
            row = si * 4 + di
            for fi, g in enumerate([idle[k] for k in IDLE_POSES] + walk):
                c = cell(g, w, h, view['shadow'], d == 'left')
                sheet.alpha_composite(c, (fi * CELL, row * CELL))
                cells[(state, d, fi)] = c
    os.makedirs(OUT, exist_ok=True)
    sheet.save(os.path.join(OUT, 'kirpi_sheet.png'))

    lines = ['[gd_resource type="SpriteFrames" format=3]', '',
             '[ext_resource type="Texture2D" path="res://assets/pets/kirpi/kirpi_sheet.png" id="1"]', '']
    for row in range(8):
        for col in range(ncol):
            lines += ['[sub_resource type="AtlasTexture" id="AT_%d"]' % (row * ncol + col), 'atlas = ExtResource("1")',
                      'region = Rect2(%d, %d, %d, %d)' % (col * CELL, row * CELL, CELL, CELL), '']
    anims = []
    for si, state in enumerate(('acik', 'kapali')):
        for di, d in enumerate(DIRS):
            at0 = (si * 4 + di) * ncol
            anims.append(('%s_%s' % (state, d), [(at0 + IDLE_POSES.index(k), dur) for k, dur in IDLE_SEQ], IDLE_FPS))
            anims.append(('%s_walk_%s' % (state, d), [(at0 + len(IDLE_POSES) + f, 1) for f in range(4)], WALK_FPS))
    lines.append('[resource]')
    blocks = []
    for name, frames, fps in anims:
        fr = ',\n'.join('{\n"duration": %.1f,\n"texture": SubResource("AT_%d")\n}' % (dur, i) for i, dur in frames)
        blocks.append('{\n"frames": [%s],\n"loop": true,\n"name": &"%s",\n"speed": %s\n}' % (fr, name, fps))
    lines.append('animations = [%s]' % ', '.join(blocks))
    lines.append('')
    with open(os.path.join(OUT, 'kirpi_frames.tres'), 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))
    print('wrote', OUT, sheet.size, len(anims), 'animasyon; durus', len(IDLE_SEQ), 'kare,', sum(d for _, d in IDLE_SEQ) / IDLE_FPS, 'sn')
    preview(cells)


def preview(cells):
    """Önizleme (oyuna girmez): tüm kareler x4 + çimen üstünde hareketli GIF (üst satır duruş, alt satır yürüyüş; sol 4 kapalı, sağ 4 açık)."""
    if not os.path.isdir(PREVIEW):
        return
    grass = (126, 176, 84, 255)
    ncol = len(IDLE_POSES) + 4
    still = Image.new('RGBA', (CELL * ncol, CELL * 8), grass)
    for si, state in enumerate(('kapali', 'acik')):
        for di, d in enumerate(DIRS):
            for fi in range(ncol):
                still.alpha_composite(cells[(state, d, fi)], (fi * CELL, (si * 4 + di) * CELL))
    still.resize((still.width * 4, still.height * 4), Image.NEAREST).convert('RGB').save(os.path.join(PREVIEW, 'kirpi_v2_kareler.png'))
    order = ['down', 'left', 'right', 'up']
    zoom = 5
    top = 9                             # hücrenin boş üst satırları kırpılır
    timeline = [IDLE_POSES.index(k) for k, dur in IDLE_SEQ for _ in range(dur)]
    frames = []
    for t in range(len(timeline)):      # adım = 1 / IDLE_FPS sn (oyundaki gerçek hız)
        im = Image.new('RGBA', (CELL * 8, (CELL - top) * 2), grass)
        for si, state in enumerate(('kapali', 'acik')):
            for di, d in enumerate(order):
                x = (si * 4 + di) * CELL
                im.alpha_composite(cells[(state, d, timeline[t])].crop((0, top, CELL, CELL)), (x, 0))
                im.alpha_composite(cells[(state, d, len(IDLE_POSES) + t % 4)].crop((0, top, CELL, CELL)), (x, CELL - top))
        frames.append(im.resize((im.width * zoom, im.height * zoom), Image.NEAREST).convert('RGB'))
    frames[0].save(os.path.join(PREVIEW, 'kirpi_v2_anim.gif'), save_all=True, append_images=frames[1:], duration=int(1000 / IDLE_FPS), loop=0)


if __name__ == '__main__':
    main()
