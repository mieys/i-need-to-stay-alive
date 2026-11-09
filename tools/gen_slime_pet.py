"""Evcil hayvan MİNİK CADI (iyi slime) - kullanıcının çizimi (2026-11-09, Desktop.zip: "(iyi slime)idle.png" 96x96 + "(iyi slime)hop.png"
192x96; kaynaklar tools/pet_kaynak/). Hücre 32x32; kaynak satırları: 0 ön (down), 1 yan (SOLA bakar), 2 arka (up). Sağ = sol satırın aynası.

Üretilenler (kullanıcının pikselleri DEĞİŞMEZ; sadece dizilir, gölge eklenir, büyü kareleri kulaklar parlatılarak türetilir):
    assets/pets/slime/slime_sheet.png (544x128) + slime_frames.tres
        satır = yön (down, left, right, up); sütun 0-2 duruş (idle_<yön>), 3-8 zıplama (hop_<yön>), 9-16 büyü (cast_<yön>)
        büyü: "pembe kulakları parıldayarak" - kulak dolgusu 3 kademede pembeden kremli beyaza açılır, kulağın çevresine düz (dither'sız)
        pembe hale, kulak uçlarında sırayla yanan 4 köşeli yıldızlar; gövde tepe karesinde zıplamanın gerilme pozuyla (hop 3) kabarır.
        Gölge: tek ton (alfa 96, madde 487) zemin elipsi, havadaki karede küçülür. Zemin satırı 25 (slime_pet.gd sprite ofseti -9).
    assets/pets/slime/slime_buyu_halka.png  - sahibin ayağında açılan pembe büyü çemberi (12 kare x 56x30, merkez 28,15), uçları incelerek söner
    assets/pets/slime/slime_buyu_yukselis.png - sahibin çevresinde yükselen pembe oklar (statlar artar) + yıldızlar (12 kare x 40x60, ayak 20,56)
    assets/ui/status/slime_buyu.png (24x24) - buff rozeti simgesi (önden duruş karesi 1:1)
Kullanım (proje kökünden): python -I tools/gen_slime_pet.py   sonra   Godot --headless --path . --import
Önizleme (oyuna girmez): --onizleme <klasör>  -> slime_kareler.png + slime_buyu.gif
"""
import math
import os
import sys

from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
SRC = os.path.join(ROOT, 'tools', 'pet_kaynak')
OUT = os.path.join(ROOT, 'assets', 'pets', 'slime')
STATUS = os.path.join(ROOT, 'assets', 'ui', 'status')
CELL = 32
GROUND_ROW = 25          # gövdenin alt konturu satır 24; zemin (düğüm orijini) satır 25
DIRS = ['down', 'left', 'right', 'up']
SRC_ROW = {'down': 0, 'left': 1, 'right': 1, 'up': 2}
IDLE_FPS = 5.0
HOP_FPS = 10.0
CAST_FPS = 10.0

EAR_FILL = [(249, 57, 150), (190, 51, 136), (128, 44, 122)]       # parlaktan koyuya
EAR_INK = (69, 40, 60)
CREAM = (255, 244, 250)
PINK_L = (255, 170, 216)
PINK_M = (255, 112, 186)
PINK_H = (249, 57, 150)
# Kulak parlaması: kademe -> (dolgu eşlemesi, kontur rengi, hale halkaları [(renk, alfa)])
GLOW = {
    0: ({}, None, []),
    1: ({EAR_FILL[0]: (255, 112, 186), EAR_FILL[1]: (232, 74, 160), EAR_FILL[2]: (170, 56, 140)}, None, []),
    2: ({EAR_FILL[0]: (255, 170, 216), EAR_FILL[1]: (255, 112, 186), EAR_FILL[2]: (222, 74, 160)}, (110, 46, 96), [(PINK_M, 120)]),
    3: ({EAR_FILL[0]: (255, 232, 244), EAR_FILL[1]: (255, 170, 216), EAR_FILL[2]: (255, 112, 186)}, (156, 58, 124), [(PINK_L, 170), (PINK_M, 70)]),
}
# Büyü: (kaynak kare: ('idle'|'hop', i), parlama kademesi, (sol kulak yıldızı, sağ kulak yıldızı)) - yıldız 0 yok / 1 nokta / 2 artı / 3 büyük
CAST_SEQ = [(('idle', 0), 0, (0, 0)), (('idle', 1), 1, (1, 0)), (('idle', 2), 2, (2, 1)), (('hop', 3), 3, (3, 2)),
            (('hop', 3), 3, (2, 3)), (('idle', 2), 2, (1, 2)), (('idle', 1), 1, (0, 1)), (('idle', 0), 0, (0, 0))]
CAST_SPELL_FRAME = 4      # büyü bu karede çıkar (slime_pet.gd CAST_RELEASE ile aynı: 4 / 10 fps = 0,4 sn)


def load(name):
    return Image.open(os.path.join(SRC, name)).convert('RGBA')


def src_cell(sheet, row, col):
    return sheet.crop((col * CELL, row * CELL, col * CELL + CELL, row * CELL + CELL))


def put(px, x, y, rgb, a=255):
    if 0 <= x < CELL and 0 <= y < CELL:
        px[x, y] = rgb + (a,)


def shadow_layer(body):
    """Tek ton zemin gölgesi (alfa 96): gövde havadaysa (alt satırı zeminden yukarıda) küçülür."""
    im = Image.new('RGBA', (CELL, CELL), (0, 0, 0, 0))
    px = im.load()
    bb = body.getbbox()
    lift = max(0, (GROUND_ROW - 1) - (bb[3] - 1)) if bb else 0
    shrink = (lift + 1) // 2
    cx = (bb[0] + bb[2]) / 2.0 if bb else CELL / 2.0
    for row, half in ((GROUND_ROW - 2, 10), (GROUND_ROW - 1, 11), (GROUND_ROW, 9)):
        h = max(3, half - shrink)
        for x in range(int(round(cx - h)), int(round(cx + h))):
            put(px, x, row, (0, 0, 0), 96)
    return im


def ear_pixels(im):
    px = im.load()
    fill = {(x, y) for y in range(CELL) for x in range(CELL) if px[x, y][3] and px[x, y][:3] in EAR_FILL}
    ink = set()
    for (x, y) in fill:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if 0 <= q[0] < CELL and 0 <= q[1] < CELL and px[q][3] and px[q][:3] == EAR_INK:
                ink.add(q)
    return fill, ink


def ear_tips(fill):
    """İki kulağın en üst pikseli (sol / sağ küme, x ortancasına göre)."""
    if not fill:
        return []
    xs = sorted(p[0] for p in fill)
    mid = xs[len(xs) // 2]
    tips = []
    for cluster in ([p for p in fill if p[0] < mid], [p for p in fill if p[0] >= mid]):
        if cluster:
            top = min(p[1] for p in cluster)
            row = sorted(p[0] for p in cluster if p[1] == top)
            tips.append((row[len(row) // 2], top))
    return tips


def star(px, c, size, shift):
    """4 köşeli yıldız: 1 = krem nokta, 2 = artı (krem merkez, pembe kollar), 3 = büyük artı (pembe uçlu)."""
    x, y = c
    if size <= 0:
        return
    if size == 1:
        put(px, x, y, CREAM)
        return
    put(px, x, y, CREAM)
    for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        put(px, x + d[0], y + d[1], PINK_L if size == 3 else PINK_M)
        if size == 3:
            put(px, x + 2 * d[0], y + 2 * d[1], PINK_H, 210)
    if size == 3 and shift:
        for d in ((1, 1), (-1, -1), (1, -1), (-1, 1)):
            put(px, x + d[0], y + d[1], PINK_M, 150)


def glow_frame(base, stage, stars):
    """Kulakları `stage` kademesinde parlatır, çevresine hale + uçlara yıldız ekler (kullanıcının gövde pikselleri aynı kalır)."""
    im = base.copy()
    px = im.load()
    fill, ink = ear_pixels(base)
    remap, ink_col, halo = GLOW[stage]
    for (x, y) in fill:
        c = px[x, y][:3]
        if c in remap:
            px[x, y] = remap[c] + (255,)
    if ink_col:
        for (x, y) in ink:
            px[x, y] = ink_col + (255,)
    ear = fill | ink
    ring = set(ear)
    for col, alpha in halo:
        nxt = set()
        for (x, y) in ring:
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    q = (x + dx, y + dy)
                    if q not in ring and 0 <= q[0] < CELL and 0 <= q[1] < CELL and px[q][3] == 0:
                        nxt.add(q)
        for q in nxt:
            px[q] = col + (alpha,)
        ring |= nxt
    tips = ear_tips(fill)
    for i, tip in enumerate(tips[:2]):
        s = stars[i] if i < len(stars) else 0
        star(px, (tip[0] + (1 if i else -1), tip[1] - 3 - (1 if s == 3 else 0)), s, i == 0)
    return im


def compose(body, flip):
    out = shadow_layer(body)
    out.alpha_composite(body)
    return out.transpose(Image.FLIP_LEFT_RIGHT) if flip else out


def build_sheet(idle, hop):
    ncol = 3 + 6 + len(CAST_SEQ)
    sheet = Image.new('RGBA', (ncol * CELL, len(DIRS) * CELL), (0, 0, 0, 0))
    cells = {}
    for di, d in enumerate(DIRS):
        r = SRC_ROW[d]
        flip = d == 'right'
        col = 0
        for i in range(3):
            c = compose(src_cell(idle, r, i), flip)
            sheet.alpha_composite(c, (col * CELL, di * CELL))
            cells[(d, col)] = c
            col += 1
        for i in range(6):
            c = compose(src_cell(hop, r, i), flip)
            sheet.alpha_composite(c, (col * CELL, di * CELL))
            cells[(d, col)] = c
            col += 1
        for (kind, i), stage, stars in CAST_SEQ:
            base = src_cell(idle if kind == 'idle' else hop, r, i)
            c = compose(glow_frame(base, stage, stars), flip)
            sheet.alpha_composite(c, (col * CELL, di * CELL))
            cells[(d, col)] = c
            col += 1
    return sheet, cells, ncol


def write_tres(ncol):
    lines = ['[gd_resource type="SpriteFrames" format=3]', '',
             '[ext_resource type="Texture2D" path="res://assets/pets/slime/slime_sheet.png" id="1"]', '']
    for row in range(len(DIRS)):
        for col in range(ncol):
            lines += ['[sub_resource type="AtlasTexture" id="AT_%d"]' % (row * ncol + col), 'atlas = ExtResource("1")',
                      'region = Rect2(%d, %d, %d, %d)' % (col * CELL, row * CELL, CELL, CELL), '']
    anims = []
    for di, d in enumerate(DIRS):
        at0 = di * ncol
        anims.append(('idle_' + d, [at0 + i for i in range(3)], IDLE_FPS, True))
        anims.append(('hop_' + d, [at0 + 3 + i for i in range(6)], HOP_FPS, True))
        anims.append(('cast_' + d, [at0 + 9 + i for i in range(len(CAST_SEQ))], CAST_FPS, False))
    lines.append('[resource]')
    blocks = []
    for name, frames, fps, loop in anims:
        fr = ',\n'.join('{\n"duration": 1.0,\n"texture": SubResource("AT_%d")\n}' % i for i in frames)
        blocks.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}' % (fr, 'true' if loop else 'false', name, fps))
    lines.append('animations = [%s]' % ', '.join(blocks))
    lines.append('')
    with open(os.path.join(OUT, 'slime_frames.tres'), 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))


# ------------------------------------------------------------------ büyü efekti sayfaları

RING_W, RING_H, RING_N = 56, 30, 12
RING_RX = [5, 10, 15, 19, 21, 22, 22, 22, 22, 22, 22, 22]


def ellipse_points(rx, ry, steps=None):
    """Tam sayı elips çevresi (yatay 2:1), açı ile birlikte - kesintisiz 1 px çizgi."""
    steps = steps or max(48, int(rx * 10))
    pts = {}
    for k in range(steps):
        a = k / steps * math.tau
        p = (int(round(math.cos(a) * rx)), int(round(math.sin(a) * ry)))
        pts.setdefault(p, a)
    return pts


def ring_frame(t):
    im = Image.new('RGBA', (RING_W, RING_H), (0, 0, 0, 0))
    px = im.load()
    cx, cy = RING_W // 2, RING_H // 2
    rx = RING_RX[t]
    ry = max(2, rx // 2)

    def plot(x, y, col, a=255):
        x += cx
        y += cy
        if 0 <= x < RING_W and 0 <= y < RING_H:
            px[x, y] = col + (a,)

    # açılış parlaması: içi düz pembe bantlar (dither yok), krem çekirdek
    if t <= 3:
        fill_a = [110, 90, 55, 25][t]
        for y in range(-ry + 1, ry):
            span = int(rx * math.sqrt(max(0.0, 1.0 - (y / ry) ** 2))) - 1
            for x in range(-span, span + 1):
                inner = (x / max(1, rx)) ** 2 + (y / max(1, ry)) ** 2 < 0.25
                plot(x, y, CREAM if (inner and t <= 1) else PINK_L, fill_a + (60 if inner and t <= 1 else 0))
    # bitişte çember incelerek hilallere ayrılır (uçlar sivri - keskin kesik yok)
    gaps = {9: 2, 10: 4, 11: 4}.get(t, 0)
    gap_w = {9: 0.18, 10: 0.42, 11: 0.66}.get(t, 0.0)
    rot = t * 0.21

    def visible(a):
        if not gaps:
            return 1.0
        ph = ((a - rot) / math.tau * gaps) % 1.0
        d = abs(ph - 0.5) * 2.0          # 1 = hilalin ortası, 0 = boşluğun ortası
        return d - gap_w

    alpha = 255 if t < 10 else (200 if t == 10 else 140)
    for (x, y), a in ellipse_points(rx, ry).items():
        v = visible(a)
        if v <= 0.0:
            continue
        plot(x, y, PINK_H, alpha)
        if v > 0.18:                       # iç açık bant hilalin ucunda incelir
            ix = int(round(math.cos(a) * (rx - 1)))
            iy = int(round(math.sin(a) * (ry - 1)))
            if (ix, iy) != (x, y):
                plot(ix, iy, PINK_L, alpha)
    # iç sihir çemberi (tam görünürken)
    if 3 <= t <= 8:
        for (x, y), a in ellipse_points(int(rx * 0.55), max(1, int(ry * 0.55))).items():
            if visible(a) > 0.0:
                plot(x, y, (255, 190, 226), 150 if t < 8 else 90)
    # çemberin üstünde dönen 4 yıldız
    if 2 <= t <= 9:
        size = 3 if 4 <= t <= 6 else (1 if t in (2, 9) else 2)
        for k in range(4):
            a = t * 0.21 + k * math.tau / 4
            sx = int(round(math.cos(a) * rx))
            sy = int(round(math.sin(a) * ry))
            plot(sx, sy, CREAM)
            if size >= 2:
                for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    plot(sx + d[0], sy + d[1], PINK_L if size == 3 else PINK_M)
            if size == 3:
                for d in ((2, 0), (-2, 0), (0, 2), (0, -2)):
                    plot(sx + d[0], sy + d[1], PINK_H, 200)
    return im


RISE_W, RISE_H, RISE_N = 40, 60, 12
RISE_FOOT = (20, 56)
# yükselen ok: (x, başlangıç yüksekliği (ayaktan yukarı), başlangıç karesi)
CHEVRONS = [(-12, 10, 0), (11, 16, 1), (-4, 4, 2), (6, 22, 3), (-9, 26, 4), (13, 6, 5)]
RISE_SPARKS = [(-15, 30, 1), (14, 34, 2), (2, 40, 3), (-6, 18, 5), (9, 12, 6)]


def chevron(px, x, y, life_left):
    """5 px genişlikte yukarı ok (^): üst satır açık pembe + krem uç, alt satır koyu pembe; ömrünün sonunda incelir."""
    def p(dx, dy, col, a=255):
        X, Y = x + dx, y + dy
        if 0 <= X < RISE_W and 0 <= Y < RISE_H:
            px[X, Y] = col + (a,)
    if life_left <= 1:
        p(0, 0, PINK_L, 170)
        p(-1, 1, PINK_M, 120)
        p(1, 1, PINK_M, 120)
        return
    p(0, 0, CREAM)
    p(-1, 1, PINK_L)
    p(1, 1, PINK_L)
    p(-2, 2, PINK_M)
    p(2, 2, PINK_M)
    p(0, 1, PINK_H, 230)
    p(-1, 2, PINK_H, 230)
    p(1, 2, PINK_H, 230)
    if life_left >= 4:
        p(-2, 3, PINK_H, 160)
        p(2, 3, PINK_H, 160)


def rise_frame(t):
    im = Image.new('RGBA', (RISE_W, RISE_H), (0, 0, 0, 0))
    px = im.load()
    fx, fy = RISE_FOOT
    life = 7
    for x, h0, start in CHEVRONS:
        k = t - start
        if 0 <= k < life:
            chevron(px, fx + x, fy - h0 - k * 3, life - k)
    for x, h0, start in RISE_SPARKS:
        k = t - start
        if 0 <= k < 5:
            size = [1, 2, 3, 2, 1][k]
            sx, sy = fx + x, fy - h0 - k
            if 0 <= sx < RISE_W and 0 <= sy < RISE_H:
                px[sx, sy] = CREAM + (255,)
                if size >= 2:
                    for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        X, Y = sx + d[0], sy + d[1]
                        if 0 <= X < RISE_W and 0 <= Y < RISE_H:
                            px[X, Y] = (PINK_L if size == 3 else PINK_M) + (255,)
                if size == 3:
                    for d in ((2, 0), (-2, 0), (0, 2), (0, -2)):
                        X, Y = sx + d[0], sy + d[1]
                        if 0 <= X < RISE_W and 0 <= Y < RISE_H:
                            px[X, Y] = PINK_H + (190,)
    return im


def strip(frames, w, h):
    im = Image.new('RGBA', (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        im.alpha_composite(f, (i * w, 0))
    return im


def status_icon(idle):
    body = src_cell(idle, 0, 0)
    bb = body.getbbox()
    crop = body.crop(bb)
    icon = Image.new('RGBA', (24, 24), (0, 0, 0, 0))
    icon.alpha_composite(crop, ((24 - crop.width) // 2, (24 - crop.height) // 2 + 1))
    return icon


def preview(folder, cells, ncol, rings, rises):
    os.makedirs(folder, exist_ok=True)
    grass = (126, 176, 84, 255)
    still = Image.new('RGBA', (CELL * ncol, CELL * len(DIRS)), grass)
    for di, d in enumerate(DIRS):
        for c in range(ncol):
            still.alpha_composite(cells[(d, c)], (c * CELL, di * CELL))
    still.resize((still.width * 4, still.height * 4), Image.NEAREST).convert('RGB').save(os.path.join(folder, 'slime_kareler.png'))
    # büyü GIF'i: solda slime büyü klibi, sağda sahibin yerinde çember + yükselen oklar (karakter yerine gri silüet)
    zoom = 4
    frames = []
    W, H = 120, 70
    for t in range(len(CAST_SEQ) + RING_N):
        im = Image.new('RGBA', (W, H), grass)
        ci = min(t, len(CAST_SEQ) - 1)
        im.alpha_composite(cells[('right', 9 + ci)], (6, 30))
        k = t - CAST_SPELL_FRAME
        if 0 <= k < RING_N:
            im.alpha_composite(rings[k], (60, 52))
        sil = Image.new('RGBA', (14, 40), (70, 70, 90, 160))
        im.alpha_composite(sil, (81, 27))
        if 0 <= k < RISE_N:
            im.alpha_composite(rises[k], (68, 11))
        frames.append(im.resize((W * zoom, H * zoom), Image.NEAREST).convert('RGB'))
    frames[0].save(os.path.join(folder, 'slime_buyu.gif'), save_all=True, append_images=frames[1:], duration=100, loop=0)


def main():
    idle = load('iyi_slime_idle.png')
    hop = load('iyi_slime_hop.png')
    os.makedirs(OUT, exist_ok=True)
    sheet, cells, ncol = build_sheet(idle, hop)
    sheet.save(os.path.join(OUT, 'slime_sheet.png'))
    write_tres(ncol)
    rings = [ring_frame(t) for t in range(RING_N)]
    rises = [rise_frame(t) for t in range(RISE_N)]
    strip(rings, RING_W, RING_H).save(os.path.join(OUT, 'slime_buyu_halka.png'))
    strip(rises, RISE_W, RISE_H).save(os.path.join(OUT, 'slime_buyu_yukselis.png'))
    status_icon(idle).save(os.path.join(STATUS, 'slime_buyu.png'))
    print('wrote', OUT, sheet.size, 'halka', RING_N, 'yukselis', RISE_N)
    if '--onizleme' in sys.argv:
        preview(sys.argv[sys.argv.index('--onizleme') + 1], cells, ncol, rings, rises)


if __name__ == '__main__':
    main()
