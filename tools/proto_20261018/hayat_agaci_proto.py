"""2026-10-18 prototipi: OAKLEY yeni ULTİ "Hayat Ağacı" (kullanıcı: "oakleyin ultisini komple değiştirmeyi düşünüyorum" ->
önerilen Hayat Ağacı seçildi, "önce görsel prototipleri çıkar"). OYUNA BAĞLI DEĞİL, mekanik yok - sayılar ÖNERİ:
  * R: Oakley eğilip önüne tohum eker (pickup klibi = yere eğilme), ağaç 3 boyda büyür (küçük -> orta -> büyük).
  * Büyük boya ulaşınca açılış darbesi: alandaki yaratıklar geri itilir.
  * 12 sn: gölgesindeki (2:1 elips 130x65, Şovalye kubbesi gibi) dostlar saniyede can + mana kalkanı alır; 2 sn'de bir kökler
    en yakın 3 yaratığa (260 dünya içinde) uzanır, 4 sn sabitler (E Sarmaşıklar gibi; bosslar yavaşlar).
  * Süre bitince ağaç küçülerek toprağa çekilir, etrafa 3 çiçek bırakır (pasifin çiçeği).
Ağaçlar haritanın KENDİ tileseti (Harita içerikleri/sadece ağaç/Assets_separately/Trees_texture_shadow = haritadaki
"sadece agac golgeli"), 3/2/1 = küçük/orta/büyük. Karakter, slime, sarmaşık ve çiçek sayfaları oyunun kendisi.
Yönler (her biri ayrı ağaç + ayrı efekt dili):
  A Çiçek Ağacı     pembe çiçekli ağaç; düz bantlı saydamlık: zeminde yumuşak pembe ışık + kenar, düşen pembe yapraklar,
                    çiçekli ince kökler zeminde sürünür, yaratığı iki halkayla sarar.
  B Kadim Sarmaşık  yosunlu, sarkık sarmaşıklı ağaç; gölgelik: zemin taç gölgesiyle kararır + yaprak arası güneş benekleri,
                    kökler = E'nin GERÇEK sarmaşık sanatı (vine_seg/vine_head/entangle, tohum = vine_emerge) - kit bütünlüğü.
  C Bereket Ağacı   meyve ağacı; altın dil: kenarda yükselen ışık çizgileri, her can tikinde ağaçtan dosta elma uçar,
                    kökler toprağın altından kabararak gider, yaratığın dibinden kalın dolu köklerle fışkırır.
Ölçek: 1 GIF pikseli = 1 dünya birimi; arka plan gerçek çizici yakalaması (proto_20261016/harita_renk orman2_doygun_sonra:
oyundaki renk ayarı + doygunluk), 960x540 = 1080p oyun görüşü (kamera x2). Karakter pikseli 0,903, slime 0,949,
sarmaşık/sarılma 1,212 dünya (oyundaki TEXEL). Kare 70 ms gerçek zaman; 7,3 -> 11,2 sn arası atlanır.
Çıktı: out/hayat_agaci/hayat_agaci_{A,B,C}.gif + hayat_agaci_ozet.png (3 an x 3 yön, x2)
Kullanım (proje kökünden): python -I tools/proto_20261018/hayat_agaci_proto.py [A|B|C]   (argümansız: hepsi + özet)
"""
import math
import os
import random
import re
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..', '..'))
TREE_DIR = os.path.join(os.path.dirname(PROJECT), 'Harita içerikleri', 'sadece ağaç', 'Assets_separately')
BG_PATH = os.path.join(PROJECT, 'tools', 'proto_20261016', 'harita_renk', 'out', 'orman2_doygun_sonra.png')
OUT = os.path.join(HERE, 'out', 'hayat_agaci')

W, H = 960, 540
DT = 0.07
TAU = math.tau
CHAR_S = 2.2368375 * 0.8075 * 0.5  ## Oakley/Korsan/Şovalye sanat pikseli -> dünya (0,903)
SLIME_S = 0.94905
TEXEL = 1.212
ENT_FEET_Y = 4.0  ## fx_oakley_entangle.gd FEET_Y
ENT_GY = 24.0  ## SIZES["s"] zemin satırı

OAK = (480.0, 300.0)  ## Oakley ayağı (sağa bakar)
TREE = (514.0, 286.0)  ## gövde dibi = önüne ekilen tohum
RX, RY = 130.0, 65.0
ALLIES = [('korsan', 424.0, 330.0), ('sovalye', 600.0, 322.0)]
## ağaca göre (dx, dy): 2:1 ölçüde 155-260 uzakta başlar, açılışa kadar ~24 px yaklaşır -> en yakın 3-4'ü itilir
ENEMIES0 = [(TREE[0] + dx, TREE[1] + dy) for (dx, dy) in
            [(150, -20), (170, 45), (110, 95), (-160, -30), (-180, 50), (-100, 105), (30, -110), (60, 125)]]
SLIME_SPEED = 22.0
STOP_D = 160.0  ## 2:1 ölçüde: alanın (130) hemen dışında dururlar - içeri girip dostların üstüne binmesinler

T_SMALL, RISE = 0.45, 0.28
T_MED, T_LARGE = 0.82, 1.1
T_END = 12.0
WAVES = [2.0, 4.0, 6.0, 8.0, 10.0]
WAVE_N = 3
ROOT_RANGE = 260.0
ROOT_TIME = 4.0
ROOT_SPEED = 330.0
HEAL_EVERY = 1.0
KB_DIST, KB_TIME, KB_R = 42.0, 0.3, 180.0  ## KB_R: 2:1 ölçüde (alanın 1,4 katı)
WIGGLE_AMP, WIGGLE_FREQ = 6.0, 0.07  ## oakley_vine_visual.gd ile aynı yılankavi kıvrım (yalnız görsel)
WINDOWS = [(-0.4, 7.3), (11.2, 13.4)]
NAMES = {'A': 'Çiçek Ağacı', 'B': 'Kadim Sarmaşık', 'C': 'Bereket Ağacı'}
TREE_KIND = {'A': 'Flower_tree', 'B': 'Moss_tree', 'C': 'Fruit_tree'}

PINK = [(92, 34, 64), (170, 66, 108), (226, 118, 152), (250, 176, 198), (255, 234, 238)]
LEAF = [(24, 52, 30), (46, 96, 44), (84, 148, 58), (150, 198, 84), (222, 240, 170)]
GOLD = [(96, 52, 14), (170, 104, 24), (232, 170, 52), (252, 222, 120), (255, 248, 214)]
ROOT = [(38, 22, 14), (82, 50, 28), (124, 80, 44), (166, 118, 68), (204, 160, 104)]
DIRT = [(70, 48, 30), (104, 74, 46), (140, 104, 66)]
APPLE = [(70, 14, 20), (170, 32, 36), (226, 70, 60), (255, 200, 180)]


# ====================================================================== yardımcılar
def rgba(p):
    return Image.open(p).convert('RGBA')


def nscale(im, s):
    return im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.NEAREST)


def grid(im, fw, fh):
    return [[im.crop((c * fw, r * fh, c * fw + fw, r * fh + fh)) for c in range(im.width // fw)] for r in range(im.height // fh)]


def comp(dst, src, x, y):
    x, y = int(round(x)), int(round(y))
    sx0, sy0 = max(0, -x), max(0, -y)
    sx1, sy1 = min(src.width, dst.width - x), min(src.height, dst.height - y)
    if sx1 <= sx0 or sy1 <= sy0:
        return
    dst.alpha_composite(src.crop((sx0, sy0, sx1, sy1)), (x + sx0, y + sy0))


def faded(im, a):
    if a >= 0.999:
        return im
    arr = np.array(im)
    arr[:, :, 3] = (arr[:, :, 3].astype(np.float32) * max(0.0, a)).astype(np.uint8)
    return Image.fromarray(arr)


def band(a, n=5):
    return max(0.0, min(1.0, round(a * n) / n))


def ease_out(t):
    t = max(0.0, min(1.0, t))
    return 1 - (1 - t) ** 3


def font(sz):
    for c in (r'C:\Windows\Fonts\segoeuib.ttf', r'C:\Windows\Fonts\segoeui.ttf', r'C:\Windows\Fonts\arial.ttf'):
        if os.path.exists(c):
            return ImageFont.truetype(c, sz)
    return ImageFont.load_default()


def glyph(rows, pal):
    h, w = len(rows), max(len(r) for r in rows)
    im = Image.new('RGBA', (w, h))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in pal:
                im.putpixel((x, y), tuple(pal[ch]) + (255,))
    return im


def tres_frames(path):
    """SpriteFrames .tres -> {animasyon: [kare Image]} (AtlasTexture bölgeleri)."""
    txt = open(path, encoding='utf-8').read()
    sheet = rgba(os.path.join(PROJECT, re.search(r'path="res://([^"]+)"', txt).group(1)))
    regs = {}
    for m in re.finditer(r'id="([^"]+)"\]([^\[]*?)region = Rect2\(([^)]*)\)', txt, re.S):
        x, y, w, h = [int(float(v)) for v in m.group(3).split(',')]
        regs[m.group(1)] = sheet.crop((x, y, x + w, y + h))
    res = txt[txt.index('[resource]'):]
    anims, pos = {}, 0
    for m in re.finditer(r'"name": &"([^"]+)"', res):
        anims[m.group(1)] = [regs[i] for i in re.findall(r'SubResource\("([^"]+)"\)', res[pos:m.start()])]
        pos = m.end()
    return anims


class Ov:
    """Kayan nokta RGBA katmanı; yerel maskelerle 'üstüne' karıştırma."""

    def __init__(self):
        self.c = np.zeros((H, W, 4), np.float32)

    def put(self, x0, y0, m, rgb, a):
        if a <= 0.001:
            return
        h, w = m.shape
        X0, Y0, X1, Y1 = max(0, x0), max(0, y0), min(W, x0 + w), min(H, y0 + h)
        if X1 <= X0 or Y1 <= Y0:
            return
        mm = m[Y0 - y0:Y1 - y0, X0 - x0:X1 - x0]
        if not mm.any():
            return
        reg = self.c[Y0:Y1, X0:X1]
        d = reg[mm]
        oa = a + d[:, 3] * (1 - a)
        col = (np.array(rgb, np.float32) / 255.0 * a + d[:, :3] * d[:, 3:4] * (1 - a)) / np.maximum(oa[:, None], 1e-6)
        reg[mm] = np.concatenate([col, oa[:, None]], 1)

    def img(self):
        return Image.fromarray(np.clip(self.c * np.array([255, 255, 255, 255], np.float32), 0, 255).astype(np.uint8), 'RGBA')


def ell(cx, cy, rx, ry):
    x0, y0 = int(math.floor(cx - rx)) - 1, int(math.floor(cy - ry)) - 1
    w, h = int(2 * rx) + 4, int(2 * ry) + 4
    Y, X = np.mgrid[0:h, 0:w]
    return x0, y0, ((X + x0 + 0.5 - cx) / rx) ** 2 + ((Y + y0 + 0.5 - cy) / ry) ** 2


def ring(ov, cx, cy, rx, ry, th, rgb, a):
    x0, y0, d = ell(cx, cy, rx, ry)
    ov.put(x0, y0, (d <= 1.0) & (d >= ((rx - th) / rx) ** 2), rgb, a)


def dilate(m):
    o = m.copy()
    o[1:] |= m[:-1]
    o[:-1] |= m[1:]
    o[:, 1:] |= m[:, :-1]
    o[:, :-1] |= m[:, 1:]
    return o


def tube(ov, pts, r0, r1, pal, a, outline=True):
    """Kalınlığı r0 -> r1 incelen dolu boru (kök): koyu kontur, gövde, üst ışık, alt gölge."""
    if len(pts) < 2:
        return
    P = np.array(pts, np.float32)
    x0, y0 = int(P[:, 0].min() - r0 - 3), int(P[:, 1].min() - r0 - 3)
    w, h = int(P[:, 0].max() - x0 + r0 + 4), int(P[:, 1].max() - y0 + r0 + 4)
    Y, X = np.mgrid[0:h, 0:w]
    body = np.zeros((h, w), bool)
    seg = np.hypot(np.diff(P[:, 0]), np.diff(P[:, 1]))
    total = max(1e-3, seg.sum())
    s = 0.0
    for i in range(len(P) - 1):
        n = max(1, int(seg[i]))
        for j in range(n):
            q = j / n
            px, py = P[i] + (P[i + 1] - P[i]) * q
            r = r0 + (r1 - r0) * ((s + seg[i] * q) / total)
            body |= (X + x0 + 0.5 - px) ** 2 + (Y + y0 + 0.5 - py) ** 2 <= r * r
        s += seg[i]
    if outline:
        ov.put(x0, y0, dilate(body) & ~body, pal[0], a)
    ov.put(x0, y0, body, pal[2], a)
    top = body & ~np.roll(body, 1, axis=0)
    bot = body & ~np.roll(body, -1, axis=0)
    ov.put(x0, y0, bot & ~top, pal[1], a)
    ov.put(x0, y0, top, pal[3], a)


def sparkle(k, c_core, c_arm):
    """4 uçlu yıldız, kol boyu k (1-3)."""
    n = 2 * k + 1
    im = Image.new('RGBA', (n, n))
    for i in range(1, k + 1):
        for (dx, dy) in ((i, 0), (-i, 0), (0, i), (0, -i)):
            im.putpixel((k + dx, k + dy), tuple(c_arm if i > 1 or k == 1 else c_core) + (255,))
    im.putpixel((k, k), tuple(c_core) + (255,))
    return im


# ====================================================================== sanat
def char_rows(key, clip):
    return [[nscale(f, CHAR_S) for f in row]
            for row in grid(rgba(os.path.join(PROJECT, 'assets', 'characters', key, 'sheets', clip + '.png')), 48, 48)]


OAK_IDLE = char_rows('oakley', 'idle')
OAK_PICK = char_rows('oakley', 'pickup')
ALLY_IDLE = {k: char_rows(k, 'idle') for (k, _, _) in ALLIES}
CHAR_FEET, CHAR_CX = 40 * CHAR_S, 24 * CHAR_S
_SL = os.path.join(PROJECT, 'visuals', 'Yaratıklar', 'Tüm Yaratıklar', 'Slime 1', 'PNG', 'Slime1', 'With_shadow')
SLIME_WALK = [[nscale(f, SLIME_S) for f in row] for row in grid(rgba(os.path.join(_SL, 'Slime1_Walk_with_shadow.png')), 64, 64)]
SLIME_HURT = [[nscale(f, SLIME_S) for f in row] for row in grid(rgba(os.path.join(_SL, 'Slime1_Hurt_with_shadow.png')), 64, 64)]
SLIME_HALF = 32 * SLIME_S
_FX = os.path.join(PROJECT, 'assets', 'fx', 'oakley')
ENT_BACK = {k: [nscale(f, TEXEL) for f in v] for k, v in tres_frames(os.path.join(_FX, 'entangle_s_back_frames.tres')).items()}
ENT_FRONT = {k: [nscale(f, TEXEL) for f in v] for k, v in tres_frames(os.path.join(_FX, 'entangle_s_front_frames.tres')).items()}
VSEG = {k: [nscale(f, TEXEL) for f in v] for k, v in tres_frames(os.path.join(_FX, 'vine_seg_frames.tres')).items()}
VHEAD = {k: [nscale(f, TEXEL) for f in v] for k, v in tres_frames(os.path.join(_FX, 'vine_head_frames.tres')).items()}
EMERGE = [nscale(f, TEXEL) for f in tres_frames(os.path.join(_FX, 'vine_emerge_frames.tres'))['burst']]
FLOWER = tres_frames(os.path.join(PROJECT, 'assets', 'generated', 'fx_oakley_flower_stages_frames.tres'))['stage0'][0]


def tree_set(kind):
    out = []
    for i in (3, 2, 1):  ## küçük, orta, büyük
        plain = rgba(os.path.join(TREE_DIR, 'Trees', f'{kind}{i}.png'))
        shad = rgba(os.path.join(TREE_DIR, 'Trees_texture_shadow', f'{kind}{i}.png'))
        a = np.array(plain)[:, :, 3] > 0
        ys = np.where(a.any(axis=1))[0]
        by = int(ys.max())
        xs = np.where(a[by - 3:by + 1].any(axis=0))[0]
        ## gölgeli sürüm bazen başka tuvalde (Flower_tree2: 128 px, +32/+31): gölge sadece aşağı/sola taşar ->
        ## üst satır + sağ kenar hizalanır
        pb, sb = plain.getbbox(), shad.getbbox()
        out.append(dict(plain=plain, shad=shad, bx=(xs.min() + xs.max() + 1) / 2.0, by=by, top=int(ys.min()),
                        off=(sb[2] - pb[2], sb[1] - pb[1])))
    return out


def sway(im, by, top, t, amp=1.0):
    a = np.array(im)
    o = a.copy()
    lim = by - 14
    for y in range(min(lim, a.shape[0])):
        k = (lim - y) / max(1.0, lim - top)
        dx = int(round(amp * min(1.0, k) * math.sin(t * 1.6)))
        if dx:
            o[y] = np.roll(a[y], dx, axis=0)
    return Image.fromarray(o)


PLUS = ["..ooo..", "..oho..", "ooohooo", "ohhwhho", "ooohooo", "..oho..", "..ooo.."]
PETALS = [[".pq", "pp."], ["qp.", ".pp"], ["pq", "pp"], ["pp.", ".qp"]]
LEAVES = [["..gl", ".gG.", "gg.."], ["lg..", ".Gg.", "..gg"], [".gl.", "gGg.", ".g.."]]
BLOOM = [".p.", "pcp", ".p."]
APPLE_G = ["...s...", "..oslo.", ".orrRo.", "orrrRwo", "orrrrRo", ".orrro.", "..ooo.."]
SEED = [".o.", "oho", ".o."]


def plus_glyph(pal):
    return glyph(PLUS, {'o': pal[0], 'h': pal[3], 'w': pal[4]})


# ====================================================================== simülasyon (hepsi için aynı)
def simulate():
    """Yaratık konumları, kök dalgaları, can tikleri - her kare için durum."""
    n = int(round((WINDOWS[-1][1] - WINDOWS[0][0]) / DT)) + 1
    enemies = [dict(p=np.array(e, np.float64), row=0, root_from=-99.0, root_until=-99.0, kb=0.0, kbdir=None, moving=False)
               for e in ENEMIES0]
    roots = []
    snaps = []
    for k in range(n):
        t = WINDOWS[0][0] + k * DT
        for w in WAVES:
            if t - DT < w <= t:
                busy = {r['tgt'] for r in roots if r['arr'] is None}
                cand = []
                for i, e in enumerate(enemies):
                    if i in busy or e['root_until'] > t:
                        continue
                    d = math.hypot(e['p'][0] - TREE[0], e['p'][1] - TREE[1])
                    if d <= ROOT_RANGE:
                        cand.append((d, i))
                for _, i in sorted(cand)[:WAVE_N]:
                    roots.append(dict(tgt=i, t0=w, head=np.array([TREE[0], TREE[1] + 2.0]), path=[(w, TREE[0], TREE[1] + 2.0)],
                                      arr=None, seed=len(roots)))
        for e in enemies:
            e['moving'] = False
            if e['root_from'] <= t < e['root_until']:
                continue
            if e['kbdir'] is not None and T_LARGE <= t < T_LARGE + KB_TIME + DT:
                q0, q1 = ease_out((t - DT - T_LARGE) / KB_TIME), ease_out((t - T_LARGE) / KB_TIME)
                e['p'] += e['kbdir'] * KB_DIST * (q1 - q0)
                continue
            v = np.array([TREE[0], TREE[1]]) - e['p']
            if math.hypot(v[0], v[1] * 2.0) > STOP_D:
                e['p'] += v / max(1e-6, np.linalg.norm(v)) * SLIME_SPEED * DT
                e['moving'] = True
            e['row'] = (3 if v[0] > 0 else 2) if abs(v[0]) >= abs(v[1]) else (0 if v[1] > 0 else 1)
        if T_LARGE - DT < T_LARGE <= t + 1e-9 and t < T_LARGE + DT * 0.5:
            for e in enemies:
                v = e['p'] - np.array(TREE)
                if math.hypot(v[0], v[1] * 2.0) < KB_R:
                    e['kbdir'] = v / max(1e-6, np.linalg.norm(v))
        for r in roots:
            if r['arr'] is not None:
                continue
            e = enemies[r['tgt']]
            tgt = e['p'] + np.array([0.0, 5.0])
            v = tgt - r['head']
            d = np.linalg.norm(v)
            stp = ROOT_SPEED * DT
            if d <= stp:
                r['head'] = tgt.copy()
                r['arr'] = t
                e['root_from'], e['root_until'] = t, t + ROOT_TIME
                pt = r['head']
            else:
                ## gerçek yol düz (hedefe güdümlü); çizilen yol E sarmaşığı gibi yana salınır, iki uçta söner
                r['head'] = r['head'] + v / d * stp
                r['trav'] = r.get('trav', 0.0) + stp
                side = np.array([-v[1], v[0]]) / d
                amp = WIGGLE_AMP * min(1.0, (d - stp) / 30.0, r['trav'] / 20.0)
                pt = r['head'] + side * amp * math.sin(WIGGLE_FREQ * r['trav'] + r['seed'] * 1.7)
            r['path'].append((t, float(pt[0]), float(pt[1])))
        snaps.append([dict(p=e['p'].copy(), row=e['row'], rooted=e['root_from'] <= t < e['root_until'],
                           rf=e['root_from'], ru=e['root_until'], moving=e['moving'],
                           kb=e['kbdir'] is not None and T_LARGE <= t < T_LARGE + KB_TIME) for e in enemies])
    ticks = []
    who = [('oakley', OAK[0], OAK[1])] + list(ALLIES)
    for i, (_, x, y) in enumerate(who):
        tt = T_LARGE + 0.6 + i * 0.18
        while tt < T_END:
            ticks.append((tt, x, y, i))
            tt += HEAL_EVERY
    return snaps, roots, ticks


SNAPS, ROOTS, TICKS = simulate()


def snap_at(t):
    return SNAPS[min(len(SNAPS) - 1, max(0, int(round((t - WINDOWS[0][0]) / DT))))]


def zone_k(t):
    if t < T_LARGE:
        return 0.0
    if t < T_END:
        return ease_out((t - T_LARGE) / 0.3)
    return max(0.0, 1.0 - (t - T_END) / 0.4)


def tree_state(t):
    """(boy 0/1/2 ya da None, gömülme px, gölgeli mi)"""
    if t < T_SMALL:
        return None
    if t < T_SMALL + RISE:
        return (0, 1.0 - ease_out((t - T_SMALL) / RISE), False)
    if t < T_MED:
        return (0, 0.0, True)
    if t < T_LARGE:
        return (1, 0.0, True)
    if t < T_END + 0.15:
        return (2, 0.0, True)
    if t < T_END + 0.32:
        return (1, 0.0, True)
    if t < T_END + 0.32 + 0.3:
        return (0, ease_out((t - T_END - 0.32) / 0.3), False)
    return None


SWAPS = [T_SMALL + RISE, T_MED, T_LARGE, T_END + 0.15, T_END + 0.32]
FLOWER_T = T_END + 0.4
FLOWER_AT = [(TREE[0] - 44, TREE[1] + 14), (TREE[0] + 46, TREE[1] + 8), (TREE[0] + 4, TREE[1] + 34)]


# ====================================================================== parçacıklar
def make_particles(var):
    rng = random.Random(11 + ord(var))
    parts = []  ## dict(t0, life, x, y, vx, vy, g, kind, var)
    cy = TREE[1] - 40
    for k, ts in enumerate(SWAPS):
        big = ts == T_LARGE
        n = (14 if big else 8) if var != 'C' else (8 if big else 5)  ## C yıldızları seyrek (kalabalık "parazit" gibi)
        for i in range(n):
            a = TAU * (i + rng.random() * 0.6) / n
            sp = rng.uniform(40, 80) * (1.4 if big else 1.0)
            parts.append(dict(t0=ts, life=rng.uniform(0.5, 0.8), x=TREE[0] + math.cos(a) * 10, y=cy + math.sin(a) * 12,
                              vx=math.cos(a) * sp, vy=math.sin(a) * sp * 0.7 - 30, g=150.0, kind='puff', v=rng.randrange(4)))
    if var in 'AB':  ## düşen yapraklar (A pembe, B yeşil daha seyrek)
        step = 0.2 if var == 'A' else 0.45
        ts = T_LARGE + 0.1
        while ts < T_END:
            ox, oy = TREE[0] + rng.uniform(-26, 26), TREE[1] - rng.uniform(34, 62)
            for _ in range(20):
                lx, ly = ox + rng.uniform(-70, 70), TREE[1] + rng.uniform(-40, 46)
                if ((lx - TREE[0]) / RX) ** 2 + ((ly - TREE[1]) / RY) ** 2 < 0.85:
                    break
            parts.append(dict(t0=ts, life=4.2, x=ox, y=oy, lx=lx, ly=ly, kind='fall', v=rng.randrange(4),
                              ph=rng.random() * TAU))
            ts += step * rng.uniform(0.7, 1.3)
    if var == 'C':  ## her can tikinde ağaçtan dosta elma
        for (tt, x, y, i) in TICKS:
            parts.append(dict(t0=tt - 0.5, life=0.5, x=TREE[0] + rng.uniform(-18, 18), y=TREE[1] - rng.uniform(40, 60),
                              lx=x + rng.uniform(-3, 3), ly=y - 16, kind='fruit', v=0))
    return parts


# ====================================================================== çizim
class Art:
    def __init__(self, var):
        self.var = var
        self.trees = tree_set(TREE_KIND[var])
        self.pal = {'A': PINK, 'B': LEAF, 'C': GOLD}[var]
        self.plus = plus_glyph(self.pal)
        self.petals = [glyph(p, {'p': PINK[2], 'q': PINK[3]}) for p in PETALS]
        self.petals_g = [glyph(p, {'p': PINK[1], 'q': PINK[2]}) for p in PETALS]
        self.leaves = [glyph(p, {'g': LEAF[2], 'G': LEAF[3], 'l': LEAF[4]}) for p in LEAVES]
        self.bloom = glyph(BLOOM, {'p': PINK[2], 'c': PINK[4]})
        self.apple = glyph(APPLE_G, {'o': APPLE[0], 'r': APPLE[1], 'R': APPLE[2], 'w': APPLE[3], 's': ROOT[1], 'l': LEAF[2]})
        self.seed = glyph(SEED, {'o': self.pal[1], 'h': self.pal[4]})
        self.spark = {k: sparkle(k, self.pal[4], self.pal[3]) for k in (1, 2, 3)}
        self.parts = make_particles(var)
        rng = random.Random(5)
        self.dapples = []
        while len(self.dapples) < 8:
            x, y = rng.uniform(-0.8, 0.8), rng.uniform(-0.8, 0.8)
            if x * x + y * y < 0.6:
                self.dapples.append((TREE[0] + x * RX, TREE[1] + y * RY, rng.uniform(6, 10), rng.random() * TAU))

    # ------------------------------------------------------------ zemin
    def ground(self, base, t):
        """Zemin katmanı: alan, kökler, tohum - doğrudan zemine (base RGBA)."""
        z = zone_k(t)
        ov = Ov()
        if z > 0:
            x0, y0, d = ell(TREE[0], TREE[1], RX, RY)
            if self.var == 'A':
                ov.put(x0, y0, d <= 1.0, PINK[3], band(0.10 * z, 20))
                br = 0.20 + 0.04 * math.sin(t * 2.4)
                ov.put(x0, y0, (d <= 1.0) & (d > 0.88), PINK[4], band(br * z, 20))
                ov.put(x0, y0, (d <= 0.88) & (d > 0.80), PINK[3], band(0.08 * z, 20))
            elif self.var == 'B':
                arr = np.array(base).astype(np.float32)
                h, w = d.shape
                X0, Y0 = max(0, x0), max(0, y0)
                sub = arr[Y0:y0 + h, X0:x0 + w, :3]
                dd = d[Y0 - y0:Y0 - y0 + sub.shape[0], X0 - x0:X0 - x0 + sub.shape[1]]
                k = np.where(dd <= 0.82, 1.0, np.where(dd <= 0.92, 0.66, np.where(dd <= 1.0, 0.33, 0.0))) * z
                tint = np.array([0.70, 0.78, 0.86], np.float32)
                sub *= 1.0 - k[..., None] * (1.0 - tint)
                for (dx, dy, r, ph) in self.dapples:  ## yaprak arası güneş: yavaş kayan, nefes alan benekler
                    px, py = dx + 3 * math.sin(t * 0.7 + ph), dy + 1.5 * math.cos(t * 0.5 + ph)
                    rr = r * (0.85 + 0.15 * math.sin(t * 1.3 + ph))
                    ex0, ey0, de = ell(px, py, rr, rr * 0.5)
                    for lim, al in ((1.0, 0.22), (0.45, 0.4)):
                        m = de <= lim
                        hh, ww = m.shape
                        ys, xs = np.nonzero(m)
                        ys, xs = ys + ey0, xs + ex0
                        ok = (ys >= 0) & (ys < H) & (xs >= 0) & (xs < W)
                        ys, xs = ys[ok], xs[ok]
                        a = al * z
                        arr[ys, xs, :3] = arr[ys, xs, :3] * (1 - a) + np.array([255, 246, 196], np.float32) * a
                base =Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), 'RGBA')
            else:
                ov.put(x0, y0, d <= 1.0, GOLD[3], band(0.07 * z, 20))
                ov.put(x0, y0, (d <= 1.0) & (d > 0.9), GOLD[3], band(0.14 * z, 20))
        ## açılış darbesi halkası (zeminde)
        kt = t - T_LARGE
        if 0 <= kt < 0.42 and self.var in 'AC':
            q = ease_out(kt / 0.42)
            rx = 18 + (RX * 1.3 - 18) * q
            col = PINK[4] if self.var == 'A' else GOLD[4]
            ring(ov, TREE[0], TREE[1], rx, rx * 0.5, 3.0 - 1.5 * q, col, band(0.9 * (1 - q), 5))
            ring(ov, TREE[0], TREE[1], rx * 0.82, rx * 0.41, 1.5, col, band(0.4 * (1 - q), 5))
        elif 0 <= kt < 0.42:
            q = ease_out(kt / 0.42)
            rx = 18 + (RX * 1.2 - 18) * q
            ring(ov, TREE[0], TREE[1], rx, rx * 0.5, 2.0, LEAF[3], band(0.5 * (1 - q), 5))
        ## tohum
        if self.var != 'B' and 0.15 <= t < T_SMALL + RISE:
            ox, oy, dd = ell(TREE[0], TREE[1] + 1, 5, 2.5)
            ov.put(ox, oy, dd <= 1.0, DIRT[1], 1.0)
            ov.put(ox, oy, dd <= 0.45, DIRT[0], 1.0)
        img = Image.alpha_composite(base, ov.img())
        if self.var != 'B' and 0.18 <= t < T_SMALL + 0.1:
            q = (t - 0.18) / (T_SMALL + 0.1 - 0.18)
            comp(img, self.seed, TREE[0] - 1, TREE[1] - 3 - 2 * q)
            k = 1 + int(q * 2.99)
            sp = self.spark[min(3, k)]
            comp(img, sp, TREE[0] - sp.width // 2, TREE[1] - 4 - sp.height // 2 - 3 * q)
        self.roots_ground(img, t)
        ## yerdeki yapraklar (A/B)
        for p in self.parts:
            if p['kind'] == 'fall':
                lt = t - p['t0'] - 1.3
                if 0 <= lt < p['life'] - 1.3:
                    rem = p['life'] - 1.3 - lt
                    g = (self.petals_g if self.var == 'A' else self.leaves)[p['v'] % (4 if self.var == 'A' else 3)]
                    comp(img, faded(g, band(min(1.0, rem / 0.5), 3)), p['lx'], p['ly'])
        if self.var == 'C' and z > 0:
            self.rays(img, t, z, back=True)
        return img

    def rays(self, img, t, z, back):
        """C: alan kenarında yükselen altın ışık çizgileri (arkadakiler sprite'lardan önce, öndekiler sonra)."""
        ov = Ov()
        n = 20
        for i in range(n):
            a = TAU * i / n + 0.15
            if (math.sin(a) < 0) != back:
                continue
            x = TREE[0] + RX * 0.97 * math.cos(a)
            y = TREE[1] + RY * 0.97 * math.sin(a)
            ph = ((t * 0.9 + i * 0.37) % 1.0)
            L = 9 + 5 * ((i * 7) % 3)
            lift = ph * 14
            for j in range(L):
                al = band(z * (1 - j / L) * (1 - ph) * 0.8, 4)
                m = np.ones((1, 1), bool)
                ov.put(int(x), int(y - lift - j), m, GOLD[4] if j < 2 else GOLD[3], al)
        img.alpha_composite(ov.img())

    def roots_ground(self, img, t):
        ov = Ov()
        for r in ROOTS:
            if t < r['t0']:
                continue
            pts = [(x, y) for (tt, x, y) in r['path'] if tt <= t + 1e-6]
            end = (r['arr'] + ROOT_TIME) if r['arr'] is not None else 1e9
            if self.var == 'A':
                if t >= end + 0.5 or len(pts) < 2:
                    continue
                a = 1.0 if t < end else band(1.0 - (t - end) / 0.5, 3)
                tube(ov, pts, 2.2, 1.0, ROOT, a)
                ## çiçek tomurcukları
                acc, nxt = 0.0, 14.0
                for i in range(1, len(pts)):
                    acc += math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1])
                    if acc >= nxt:
                        nxt += 16.0
                        side = 2 if (int(nxt) // 16) % 2 else -3
                        self._later.append((self.bloom, pts[i][0] - 1, pts[i][1] + side - 1, a))
            elif self.var == 'B':
                ## gerçek E sarmaşığı: geçilen yolda her 8,5 birimde gövde parçası (1,3 sn yaşar, son 0,45 sn söner) + baş
                acc, nxt, vi = 0.0, 0.0, 0
                full = r['path']
                for i in range(1, len(full)):
                    tt, x, y = full[i]
                    if tt > t:
                        break
                    px, py = full[i - 1][1], full[i - 1][2]
                    sl = math.hypot(x - px, y - py)
                    while acc + sl >= nxt and sl > 0:
                        q = (nxt - acc) / sl
                        sx, sy = px + (x - px) * q, py + (y - py) * q
                        age = t - (full[i - 1][0] + DT * q)
                        if 0 <= age < 1.3:
                            k = int(round(math.atan2(y - py, x - px) / (TAU / 16))) % 16
                            fr = VSEG['d%d' % k][[0, 0, 1, 2][vi % 4]]
                            a = 1.0 if age < 0.85 else band(1.0 - (age - 0.85) / 0.45, 3)
                            self._segs.append((faded(fr, a), sx - fr.width / 2, sy - fr.height / 2))
                        vi += 1
                        nxt += 8.5
                    acc += sl
                if r['arr'] is None or t < r['arr']:
                    tt, x, y = [p for p in full if p[0] <= t][-1]
                    if len(full) > 1:
                        p0 = [p for p in full if p[0] <= t]
                        q0 = p0[-2] if len(p0) > 1 else p0[-1]
                        k = int(round(math.atan2(y - q0[2], x - q0[1]) / (TAU / 16))) % 16
                        fr = VHEAD['d%d' % k][int(t * 12) % 3]
                        self._segs.append((fr, x - fr.width / 2, y - fr.height / 2))
            else:
                ## C: toprak altından kabaran tümsek + arkasında solan çatlak
                if len(pts) < 2:
                    continue
                for i in range(1, len(r['path'])):
                    tt, x, y = r['path'][i]
                    if tt > t:
                        break
                    age = t - tt
                    if age < 0.9:
                        a = band(0.85 * (1 - age / 0.9), 3)
                        px, py = r['path'][i - 1][1], r['path'][i - 1][2]
                        n = max(1, int(math.hypot(x - px, y - py)))
                        for j in range(n):
                            q = j / n
                            ov.put(int(px + (x - px) * q), int(py + (y - py) * q), np.ones((1, 1), bool), DIRT[0], a)
                if r['arr'] is None:
                    hx, hy = pts[-1]
                    ox, oy, dd = ell(hx, hy, 4.5, 2.6)
                    ov.put(ox, oy, dd <= 1.0, DIRT[1], 1.0)
                    ov.put(ox, oy, (dd <= 1.0) & (dd > 0.55), DIRT[0], 1.0)
                    ov.put(ox, oy - 1, (dd <= 0.35), DIRT[2], 1.0)
        img.alpha_composite(ov.img())

    # ------------------------------------------------------------ sarılma (yaratık başına arka/ön)
    def wrap(self, img, e, t, front):
        if not (e['rf'] <= t < e['ru'] + 0.35):
            return
        x, y = e['p']
        feet = y + 5
        at = t - e['rf']
        rel = t - e['ru']
        if self.var == 'B':
            if rel >= 0:
                fr_list, f = ENT_FRONT['break'] if front else ENT_BACK['break'], int(rel * 14)
                if f >= len(fr_list):
                    return
            elif at < 8 / 16.0:
                fr_list, f = (ENT_FRONT if front else ENT_BACK)['grow'], int(at * 16)
            else:
                fr_list, f = (ENT_FRONT if front else ENT_BACK)['loop'], int((at - 0.5) * 6) % 6
            fr = fr_list[min(f, len(fr_list) - 1)]
            comp(img, fr, x - fr.width / 2, y + ENT_FEET_Y - ENT_GY * TEXEL)
            return
        ov = Ov()
        a = 1.0 if rel < 0 else band(1.0 - rel / 0.35, 3)
        if self.var == 'A':
            loops = [(feet - 2, 9.0, 3.2, 0.0), (feet - 8, 8.0, 3.0, 0.12)]
            for (cy, rx, ry, dl) in loops:
                if at < dl:
                    continue
                sweep = min(1.0, (at - dl) / 0.18)
                x0, y0, d = ell(x, cy, rx, ry)
                hh, ww = d.shape
                Y, X = np.mgrid[0:hh, 0:ww]
                ang = np.arctan2(Y + y0 + 0.5 - cy, X + x0 + 0.5 - x) % TAU
                m = (d <= 1.0) & (d >= ((rx - 2) / rx) ** 2) & (ang <= sweep * TAU)
                half = (Y + y0 + 0.5 - cy) >= 0
                m = m & half if front else m & ~half
                ov.put(x0, y0, dilate(m) & ~m & (half if front else ~half), ROOT[0], a)
                ov.put(x0, y0, m, ROOT[2], a)
                if front and sweep >= 1:
                    self._later.append((self.bloom, x - rx + 1, cy - 1, a))
                    self._later.append((self.bloom, x + rx - 4, cy - 1, a))
        else:  ## C: dipten fışkıran kalın kökler + kalın halka
            grow = min(1.0, at / 0.15)
            if rel >= 0:
                grow = max(0.0, 1.0 - rel / 0.3)
            for (dx, h0, back) in ((-10, 9, False), (10, 8, False), (-4, 11, True), (5, 10, True)):
                if back == front:
                    continue
                hgt = h0 * grow
                if hgt < 1:
                    continue
                bx = x + dx
                tip = (bx - math.copysign(4, dx) * grow, feet - hgt)
                tube(ov, [(bx, feet + 1), (bx + (tip[0] - bx) * 0.3, feet - hgt * 0.55), tip], 2.1, 0.8, ROOT, 1.0)
            if at > 0.12 and rel < 0:
                cy, rx, ry = feet - 5, 10.0, 3.6
                x0, y0, d = ell(x, cy, rx, ry)
                hh, ww = d.shape
                Y = np.mgrid[0:hh, 0:ww][0]
                half = (Y + y0 + 0.5 - cy) >= 0
                m = (d <= 1.0) & (d >= ((rx - 3) / rx) ** 2) & (half if front else ~half)
                ov.put(x0, y0, dilate(m) & ~m & (half if front else ~half), ROOT[0], 1.0)
                ov.put(x0, y0, m, ROOT[2], 1.0)
                ov.put(x0, y0, m & ~np.roll(m, 1, axis=0), ROOT[3], 1.0)
        img.alpha_composite(ov.img())

    # ------------------------------------------------------------ kare
    def frame(self, t):
        self._later, self._segs = [], []
        img = self.ground(BG.copy(), t)
        for (fr, x, y) in self._segs:
            comp(img, fr, x, y)
        ## B: tohum = vine_emerge, ayrıca açılışta kenardan 6 sarmaşık fışkırması
        if self.var == 'B':
            em = [(0.12, TREE[0], TREE[1])]
            em += [(T_LARGE + 0.03 * i, TREE[0] + RX * 0.9 * math.cos(TAU * i / 6 + 0.3), TREE[1] + RY * 0.9 * math.sin(TAU * i / 6 + 0.3))
                   for i in range(6)]
            em += [(r['t0'], TREE[0], TREE[1] + 2) for r in ROOTS if r['seed'] % 3 == 0]
            for (t0, x, y) in em:
                f = int((t - t0) * 20)
                if 0 <= f < len(EMERGE):
                    fr = EMERGE[f]
                    comp(img, fr, x - fr.width / 2, y - 34 * TEXEL)
        snap = snap_at(t)
        items = []
        oak_row = 2
        if 0 <= t < 0.5:
            f = [0, 1, 1, 2, 3][min(4, int(t / 0.1))]
            items.append((OAK[1], 'img', (OAK_PICK[oak_row][f], OAK[0] - CHAR_CX, OAK[1] - CHAR_FEET)))
        else:
            items.append((OAK[1], 'img', (OAK_IDLE[oak_row][int(t * 5) % 4], OAK[0] - CHAR_CX, OAK[1] - CHAR_FEET)))
        for (key, x, y) in ALLIES:
            items.append((y, 'img', (ALLY_IDLE[key][0][int(t * 5 + x) % 4], x - CHAR_CX, y - CHAR_FEET)))
        for e in snap:
            items.append((e['p'][1] + 6, 'slime', e))
        st = tree_state(t)
        if st is not None:
            items.append((TREE[1], 'tree', st))
        for (fx, fy) in FLOWER_AT:
            if t >= FLOWER_T:
                items.append((fy, 'flower', (fx, fy)))
        items.sort(key=lambda q: q[0])
        for (_, kind, data) in items:
            if kind == 'img':
                comp(img, data[0], data[1], data[2])
            elif kind == 'slime':
                e = data
                self.wrap(img, e, t, front=False)
                x, y = e['p']
                if e['kb']:
                    fr = SLIME_HURT[e['row']][min(4, int((t - T_LARGE) / 0.07))]
                elif e['rooted']:
                    fr = SLIME_WALK[e['row']][0]
                    x += 1 if int(t * 9) % 4 == 0 else 0  ## sabitken çırpınma
                else:
                    fr = SLIME_WALK[e['row']][int(t * 10 + x) % 8 if e['moving'] else 0]
                comp(img, fr, x - SLIME_HALF, y - SLIME_HALF)
                self.wrap(img, e, t, front=True)
            elif kind == 'tree':
                size, sink, shad = data
                tr = self.trees[size]
                src = tr['shad'] if shad else tr['plain']
                ox, oy = tr['off'] if shad else (0, 0)
                src = sway(src, tr['by'] + oy, tr['top'] + oy, t)
                dy = int(round(sink * (tr['by'] - tr['top'] + 2)))
                if dy > 0:  ## topraktan çıkar / toprağa çekilir: zemin çizgisinin altı kırpılır
                    src = src.crop((0, 0, src.width, max(0, tr['by'] + oy + 1 - dy)))
                comp(img, src, TREE[0] - tr['bx'] - ox, TREE[1] - tr['by'] - oy + dy)
            elif kind == 'flower':
                fx, fy = data
                comp(img, FLOWER, fx - FLOWER.width / 2, fy - FLOWER.height + 4)
        if self.var == 'C' and zone_k(t) > 0:
            self.rays(img, t, zone_k(t), back=False)
        for (g, x, y, a) in self._later:
            comp(img, faded(g, a), x, y)
        self.air(img, t)
        return img

    def air(self, img, t):
        """Havadaki parçacıklar + can tikleri + çiçek pırıltısı."""
        for p in self.parts:
            lt = t - p['t0']
            if p['kind'] == 'puff':
                if not (0 <= lt < p['life']):
                    continue
                x = p['x'] + p['vx'] * lt
                y = p['y'] + p['vy'] * lt + 0.5 * p['g'] * lt * lt
                a = band(1.0 - lt / p['life'], 3) if lt > p['life'] * 0.5 else 1.0
                if self.var == 'A':
                    g = self.petals[p['v'] % 4]
                elif self.var == 'B':
                    g = self.leaves[p['v'] % 3]
                else:
                    k = 3 if lt < p['life'] * 0.3 else (2 if lt < p['life'] * 0.65 else 1)
                    g = self.spark[k]
                comp(img, faded(g, a), x - g.width / 2, y - g.height / 2)
            elif p['kind'] == 'fall':
                if not (0 <= lt < 1.3):
                    continue
                q = lt / 1.3
                x = p['x'] + (p['lx'] - p['x']) * q + 4 * math.sin(lt * 5 + p['ph'])
                y = p['y'] + (p['ly'] - p['y']) * (q * q * 0.4 + q * 0.6)
                g = (self.petals if self.var == 'A' else self.leaves)[(p['v'] + int(lt * 6)) % (4 if self.var == 'A' else 3)]
                comp(img, g, x, y)
            elif p['kind'] == 'fruit':
                if not (0 <= lt < p['life']):
                    continue
                q = lt / p['life']
                x = p['x'] + (p['lx'] - p['x']) * q
                y = p['y'] + (p['ly'] - p['y']) * q - 26 * 4 * q * (1 - q)
                comp(img, self.apple, x - 3, y - 3)
        for (tt, x, y, i) in TICKS:
            lt = t - tt
            if not (0 <= lt < 0.7):
                continue
            q = lt / 0.7
            a = 1.0 if q < 0.5 else band(1.0 - (q - 0.5) / 0.5, 3)
            cx, cy = x + 9, y - 34 - 12 * ease_out(q)
            comp(img, faded(self.plus, a), cx - 3, cy - 3)
            if self.var == 'A':
                for j in range(3):
                    ang = TAU * j / 3 + lt * 6
                    g = self.petals[j]
                    comp(img, faded(g, a), x + 8 * math.cos(ang) - 1, y - 8 - 18 * q + 3 * math.sin(ang))
            elif self.var == 'B':
                for j in range(2):
                    ang = TAU * j / 2 + lt * 5
                    g = self.leaves[j]
                    comp(img, faded(g, a), x + 9 * math.cos(ang) - 2, y - 10 - 16 * q + 3 * math.sin(ang))
            else:
                for j, (dx, dy) in enumerate(((-8, -18), (7, -26))):
                    k = 3 if lt < 0.15 else (2 if lt < 0.35 else 1)
                    sp = self.spark[k]
                    comp(img, faded(sp, a), x + dx - k, y + dy - k)
        ft = t - FLOWER_T
        if 0 <= ft < 0.5:  ## çiçek düşüşü: zeminde genişleyen halka (oyundaki çiçek stage0 filizi, haritanın otlarına benziyor)
            ov = Ov()
            q = ease_out(ft / 0.5)
            for (fx, fy) in FLOWER_AT:
                ring(ov, fx, fy + 3, 4 + 12 * q, (4 + 12 * q) * 0.5, 1.5, self.pal[4], band(0.9 * (1 - q), 4))
            img.alpha_composite(ov.img())
        if 0 <= ft < 0.45:
            for (fx, fy) in FLOWER_AT:
                k = 3 if ft < 0.15 else (2 if ft < 0.3 else 1)
                sp = sparkle(k, PINK[4] if self.var == 'A' else LEAF[4] if self.var == 'B' else GOLD[4],
                             self.pal[3])
                comp(img, sp, fx - k, fy - 20 - k)


def background():
    bg = np.array(rgba(BG_PATH))
    ## yakalama aracının ölçek kuklaları (3 karakter) çimle örtülür: her satır kutunun iki yanındaki çim rengiyle
    ## (yakın yarı yakın kenardan) doldurulur - zemin düz renk + leke, satır uzatması iz bırakmaz. Şovalye'nin solundaki
    ## kaya da gider (Oakley tam önünde tohum ekiyor, arkasında hayalet gibi duruyordu).
    for (x0, y0, x1, y1, sides) in [(425, 259, 443, 292, 'lr'), (466, 243, 512, 286, 'lr'), (462, 293, 483, 331, 'lr')]:
        for y in range(y0, y1):
            ## kenardaki tek piksel bir filiz olabilir (açık çizgi bırakıyordu): yanlardaki 8 pikselin en sık rengi
            def mode(seg):
                vals, cnt = np.unique(seg.reshape(-1, 4), axis=0, return_counts=True)
                return vals[cnt.argmax()].copy()
            L, R = mode(bg[y, x0 - 8:x0]), mode(bg[y, x1:x1 + 8])
            for x in range(x0, x1):
                bg[y, x] = R if (sides == 'r' or x - x0 >= (x1 - x0) // 2) else L
    return Image.fromarray(bg)


BG = background()


def phase(t):
    if t < 0:
        return 'Oakley R tuşuna basar'
    if t < 0.5:
        return 'Önüne tohum eker'
    if t < T_LARGE:
        return 'Ağaç büyür (küçük > orta > büyük)'
    if t < T_LARGE + 0.6:
        return 'Açılış: alandaki yaratıklar geri itilir'
    if t >= T_END:
        return 'Süre bitti: ağaç toprağa çekilir, 3 çiçek bırakır'
    for w in WAVES:
        if w <= t < w + 1.0:
            return 'Kök dalgası: en yakın 3 yaratık 4 sn sabitlenir (2 sn\'de bir)'
    return 'Gölgesindeki dostlar saniyede can + mana kalkanı alır (12 sn)'


def times():
    out = []
    for (a, b) in WINDOWS:
        n = int(round((b - a) / DT))
        out += [a + i * DT for i in range(n)]
    return out


def render(var):
    art = Art(var)
    fnt, fnt2 = font(17), font(15)
    frames = []
    for t in times():
        im = art.frame(t).convert('RGB')
        dr = ImageDraw.Draw(im)
        lab = f"{var}  {NAMES[var]}    t = {max(0.0, t):.1f} sn".replace('.', ',')
        dr.text((11, 9), lab, fill=(20, 30, 14), font=fnt)
        dr.text((10, 8), lab, fill=(250, 246, 226), font=fnt)
        ph = phase(t)
        if WINDOWS[1][0] <= t < WINDOWS[1][0] + 0.6:
            ph = f'>> {WINDOWS[0][1]:.1f} - {WINDOWS[1][0]:.1f} sn atlandı'.replace('.', ',')
        dr.text((11, H - 27), ph, fill=(20, 30, 14), font=fnt2)
        dr.text((10, H - 28), ph, fill=(250, 246, 226), font=fnt2)
        frames.append((t, im))
    return art, frames


def save_gif(name, frames):
    pal = [fr.quantize(colors=200, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE) for (_, fr) in frames]
    path = os.path.join(OUT, name)
    pal[0].save(path, save_all=True, append_images=pal[1:], duration=int(DT * 1000), loop=0, disposal=1)
    return path


MOMENTS = [(T_LARGE + 0.07, 'açılış darbesi'), (2.75, 'kök dalgası + can tiki'), (FLOWER_T + 0.1, 'solma + 3 çiçek')]


def overview(arts):
    cw, ch = 340, 210
    x0, y0 = int(TREE[0] - 170), int(TREE[1] - 140)
    fnt = font(18)
    cells = []
    for var, art in arts:
        row = []
        for (t, lab) in MOMENTS:
            im = art.frame(t).convert('RGB').crop((x0, y0, x0 + cw, y0 + ch)).resize((cw * 2, ch * 2), Image.NEAREST)
            dr = ImageDraw.Draw(im)
            s = f"{var} {NAMES[var]} - {lab}"
            dr.text((11, 9), s, fill=(20, 30, 14), font=fnt)
            dr.text((10, 8), s, fill=(250, 246, 226), font=fnt)
            row.append(im)
        cells.append(row)
    gap = 6
    sheet = Image.new('RGB', (3 * cw * 2 + 2 * gap, len(cells) * ch * 2 + (len(cells) - 1) * gap), (20, 24, 18))
    for r, row in enumerate(cells):
        for c, im in enumerate(row):
            sheet.paste(im, (c * (cw * 2 + gap), r * (ch * 2 + gap)))
    path = os.path.join(OUT, 'hayat_agaci_ozet.png')
    sheet.save(path)
    return path


def main():
    os.makedirs(OUT, exist_ok=True)
    want = [a for a in sys.argv[1:] if a in NAMES] or list(NAMES)
    kare = [a for a in sys.argv[1:] if a.startswith('--kare=')]
    if kare:  ## hızlı kontrol: sadece verilen anlar, yan yana tek PNG
        ts = [float(v) for v in kare[0][7:].split(',')]
        ims = [Art(v).frame(t).convert('RGB') for v in want for t in ts]
        sheet = Image.new('RGB', (W * len(ts), H * len(want)))
        for i, im in enumerate(ims):
            sheet.paste(im, ((i % len(ts)) * W, (i // len(ts)) * H))
        sheet.save(os.path.join(OUT, 'kontrol.png'))
        print('kontrol:', os.path.join(OUT, 'kontrol.png'))
        return
    arts = []
    for var in want:
        art, frames = render(var)
        p = save_gif(f'hayat_agaci_{var}.gif', frames)
        print(var, len(frames), 'kare', round(os.path.getsize(p) / 1e6, 1), 'MB')
        arts.append((var, art))
    if len(arts) == len(NAMES):
        print('özet:', overview(arts))


if __name__ == '__main__':
    main()
