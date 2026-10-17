"""2026-10-17 prototipi: KORSAN R "Bombardıman" için GEMİ GÖLGESİ efekti (kullanıcı: "korsanın ultisi hiç gösterişli değil.
gökyüzünden bir gemi gölgesi belirip yeri ateşliyormuş gibi görünsün"). MEKANİK AYNI (madde 178 dersi: "efekt" = sayılar
değişmez): 8 sn, saniyede 1 tik, tik başına 3 gülle (KorsanFxMath.STRIKES_PER_TICK), gülle 0,34 sn'de iner (STRIKE_FALL_TIME),
alan kullanıldığı yerde sabit, hasar yarıçapı 380 x 0,7 = 266 dünya (player.gd _korsan_bombardment_radius). OYUNA BAĞLI DEĞİL.

Ortak:
  * Korsan göğe kırmızı işaret fişeği atar, gemi gölgesi belirir. Alan = geminin altında hafifçe kararan zemin + yumuşak
    koyu kenar (eski kesikli turuncu halkanın yerine).
  * Gemi gölgesi (tepeden): sivri pruva, düz kıç, iki bordada 6'şar top namlusu, 3 direk + çapraz yelkenler (yelken bezi
    gövdeden AÇIK gölge), halatlar, gözcü sepeti, pruva direği, dalgalanan flama. Zemini soğuk tonla karartır, yaratıklar
    üstünde kalır; kenar kademeli, yüksekteyken bulanık + büyük.
  * Her tik 3 gülle GÖKTEN düşer (gölgeden ÇIKMAZ - kullanıcı 2. tur: "gökyüzünde bir gemi olduğunu ve ondan düşüyormuş gibi
    görünmesi gerekiyor gölge sadece hissiyat vermesi içindi"): hedefin 300 px üstünden, gemi tarafına hafif yatık, hızlanarak
    iner + duman izi; hedefte büyüyen kendi gölgesi + daralan uyarı halkası; inişte patlama + şok halkası + toprak + yanık izi
    + küçük alev.
  * Martı gölgeleri geminin çevresinde döner.
Yönler (sadece koreografi farklı):
  A Süzülen Gemi  alanın bir kenarında belirir, alanı düz bir çizgide geçer, öbür kenarda solar.
  B Dönen Gemi    yukarıdan alçalarak belirir, alanın üstünde bir tur atar, yükselerek kaybolur.
  C İnen Gemi     Korsan'ın tam üstüne alçalır, yavaşça sallanarak süzülür, iki bordadan ateş eder, yükselir.
Ölçek: 1 GIF px = 1 Korsan sanat pikseli = 2,2368375 x 0,8075 x 0,5 = 0,903 dünya. Tuval 960x540 = 1080p oyun görüntüsünün
~%90'ı (oyunda her piksel ~1,8 ekran pikseli; GIF gerçeğin ~yarısı). Kare 70 ms (gerçek zaman).
Çizim dili tools/pixfx.py (dolu kütleler, 5 ton, 1 px koyu kontur, uçlar incelir).
Çıktı: out/korsan_gemi/korsan_gemi_{A,B,C}.gif + korsan_gemi_detay.png (her yönün 3. borda anı, gemi çevresi x2)
Kullanım (proje kökünden): python -I tools/proto_20261017/korsan_gemi_proto.py [A|B|C]   (argümansız: hepsi)
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(PROJECT, 'tools'))
sys.path.insert(0, os.path.join(PROJECT, 'tools', 'proto_20261012'))
import pixfx as P  # noqa: E402
from gen_matthew_simsek import comp, font, ground_shadow, slime  # noqa: E402

OUT = os.path.join(HERE, 'out', 'korsan_gemi')
TAU = math.tau
W, H = 960, 540
DT = 0.07  ## GIF karesi 70 ms = gerçek zaman
PXW = 1.0 / 0.903  ## dünya birimi -> Korsan pikseli
ZONE_R = 380.0 * 0.7 * PXW  ## KorsanFxMath.BOMBARDMENT_RADIUS x EVO_KORSAN_BOMBARD_BASE_MULT (hasar yarıçapı)
DURATION = 8.0
TICK = 1.0
FALL = 0.34
STRIKES = 3
PRE = 0.5
APPEAR = 0.9
LEAVE = 1.2
SHIP_END = DURATION + LEAVE
TOTAL = PRE + SHIP_END + 0.6
ZX, ZY = 480, 292  ## Korsan ayağı = alan merkezi (alan sabit)
SQ = 0.8  ## zemin düzlemi basıklığı (gemi gölgesi; oyunun 2:1 zemin halkalarından biraz az, gemi okunsun)
SHADOW_RGB = np.array([0.50, 0.55, 0.70], dtype=np.float32)  ## tam gölgede zemin çarpanı (soğuk)
LEVELS = np.array([0.0, 0.2, 0.38, 0.55, 0.72, 0.9], dtype=np.float32)
ZLEVELS = np.array([0.0, 0.04, 0.08, 0.14, 0.2], dtype=np.float32)
HULL_D, SAIL_D, ROPE_D = 0.62, 0.9, 0.38  ## yelkenler gövdenin ÜSTÜNDEN geçen koyu çubuklar (aynı koyulukta bacak gibi okunuyordu)
NAMES = {'A': 'Süzülen Gemi', 'B': 'Dönen Gemi', 'C': 'İnen Gemi'}

IRON = [(18, 18, 24), (44, 46, 56), (78, 82, 96), (124, 130, 146), (186, 192, 206)]
RED = [(78, 10, 22), (172, 28, 40), (234, 70, 66), (255, 150, 136), (255, 236, 228)]
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 + 1.0 / 32.0


def quant(a, levels):
    return levels[np.abs(a[..., None] - levels).argmin(axis=-1)]


# ====================================================================== zemin
def background():
    rng = np.random.default_rng(7)
    img = np.zeros((H, W, 3), np.uint8)
    img[:] = (126, 176, 84)
    sp = rng.random((H, W)) < 1 / 14
    cols = np.array([(116, 166, 76), (134, 184, 92), (110, 158, 72)], np.uint8)
    img[sp] = cols[rng.integers(0, 3, (H, W))[sp]]
    for _ in range(320):  ## çimen tutamları
        x, y = int(rng.integers(3, W - 3)), int(rng.integers(3, H - 1))
        for dx, dy in ((0, 0), (-1, -1), (1, -1), (-2, -2), (2, -2)):
            img[y + dy, x + dx] = (104, 152, 68)
    X, Y = np.meshgrid(np.arange(W) + 0.5, np.arange(H) + 0.5)
    cy = 438 + 22 * np.sin(X / 150.0) + (X - 480) * 0.10
    half = 16 + 3 * np.sin(X / 37.0)
    d = np.abs(Y - cy)
    bay = np.tile(BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W]
    path = (d < half) | ((d < half + 2) & (bay < 0.5 - (d - half) / 4))
    img[path] = (184, 148, 98)
    sp2 = path & (rng.random((H, W)) < 1 / 9)
    img[sp2] = np.array([(168, 132, 86), (198, 164, 114)], np.uint8)[rng.integers(0, 2, (H, W))[sp2]]
    return img


_YY, _XX = np.mgrid[0:H, 0:W]
RR = np.hypot(_XX + 0.5 - ZX, _YY + 0.5 - ZY).astype(np.float32)


def zone_D(rad, st):
    D = np.zeros((H, W), np.float32)
    inside = RR <= rad
    rim = inside & (RR > rad - 18)
    D[rim] = 0.2 * ((RR[rim] - (rad - 18)) / 18) ** 1.6
    D[(RR > rad) & (RR <= rad + 1.5)] = 0.04
    return quant(D * st, ZLEVELS)


# ====================================================================== gemi gölgesi (gemi yerel: u pruvaya, v sancağa)
SS = 4
U0, U1, VR = -104, 136, 82
MW, MH = (U1 - U0) * SS, 2 * VR * SS
HULL_L, BEAM = 176.0, 58.0
PORT_U = [-56, -36, -16, 4, 24, 44]
MASTS = [(44, 124, 7.0, 16.0), (2, 148, 8.0, 19.0), (-40, 110, 6.0, 14.0)]  ## (u, yelken açıklığı, kavis, kalınlık)
SHIP_RAD = math.hypot(136, 82)


def hull_w(u):
    s = (u + HULL_L / 2) / HULL_L
    if s < 0 or s > 1:
        return 0.0
    stern = 0.86 + 0.14 * math.sin(min(s / 0.15, 1.0) * math.pi / 2)
    bow = 1.0 if s < 0.5 else max(0.0, math.cos(math.pi / 2 * (s - 0.5) / 0.5)) ** 0.7
    return BEAM / 2 * stern * bow


def ship_mask(ph):
    im = Image.new('L', (MW, MH), 0)
    d = ImageDraw.Draw(im)

    def p2(u, v):
        return ((u - U0) * SS, (v + VR) * SS)

    def line(a, b, w, val):
        (u0, v0), (u1, v1) = a, b
        L = math.hypot(u1 - u0, v1 - v0) or 1.0
        nu, nv = -(v1 - v0) / L * w / 2, (u1 - u0) / L * w / 2
        d.polygon([p2(u0 + nu, v0 + nv), p2(u1 + nu, v1 + nv), p2(u1 - nu, v1 - nv), p2(u0 - nu, v0 - nv)], fill=val)

    rope, sail, hull = int(ROPE_D * 255), int(SAIL_D * 255), int(HULL_D * 255)
    mid = int(0.72 * 255)
    for (um, S, bul, th) in MASTS:  ## halatlar: yelken uçlarından bordaya
        for sd in (-1, 1):
            for du in (-16, 12):
                line((um + bul * 0.1, sd * S / 2 * 0.97), (um + du, sd * hull_w(um + du) * 0.9), 1.0, rope)
    top, bot = [], []
    for j in range(81):
        u = -HULL_L / 2 + HULL_L * j / 80
        w = hull_w(u)
        top.append(p2(u, -w))
        bot.append(p2(u, w))
    d.polygon(top + bot[::-1], fill=sail)  ## koyu küpeşte kenarı + açık güverte (gövde biçimi okunsun)
    top, bot = [], []
    for j in range(81):
        u = -HULL_L / 2 + 3 + (HULL_L - 7) * j / 80
        w = max(0.0, hull_w(u) - 3.0)
        top.append(p2(u, -w))
        bot.append(p2(u, w))
    d.polygon(top + bot[::-1], fill=hull)
    for u in PORT_U:  ## top namluları
        w = hull_w(u)
        for sd in (-1, 1):
            d.polygon([p2(u - 1.6, sd * (w - 1)), p2(u + 1.6, sd * (w - 1)), p2(u + 1.6, sd * (w + 4.5)), p2(u - 1.6, sd * (w + 4.5))],
                      fill=sail)
    line((84, 0), (126, 0), 3.0, mid)  ## pruva direği
    line((-87, 0), (-95, 0), 5.0, sail)  ## dümen
    line((44, 0), (120, -1.5), 3.0, mid)  ## flok
    line((-40, 0), (-90, 2.0), 5.0, mid)  ## randa
    for i, (um, S, bul, th) in enumerate(MASTS):  ## çapraz yelkenler: hafif pruvaya kavisli, uçları küt
        b = bul + 1.0 * math.sin(ph * 0.7 + i * 1.9)
        front, back = [], []
        for j in range(33):
            v = -S / 2 + S * j / 32
            q = 2 * v / S
            c = um + b * (1 - q * q)
            aq = abs(q)
            t = th * 0.5 * (1.0 if aq < 0.9 else math.sqrt(max(0.0, 1 - ((aq - 0.9) / 0.1) ** 2))) + 0.5
            front.append(p2(c + t, v))
            back.append(p2(c - t, v))
        d.polygon(front + back[::-1], fill=sail)
    n, FL = 16, 50.0  ## flama (ana direkten kıça doğru dalgalanır)
    top, bot = [], []
    for i in range(n + 1):
        s = i / n
        uu = -4 - s * FL
        vv = 6.0 * s * math.sin(ph * 1.6 - s * 5.0)
        wv = 3.5 * (1 - s) + 0.5
        top.append(p2(uu, vv - wv))
        bot.append(p2(uu, vv + wv))
    d.polygon(top + bot[::-1], fill=sail)
    return np.asarray(im, dtype=np.float32) / 255.0


def box_blur(a, r):
    if r <= 0:
        return a
    p = np.pad(a, r)
    c = np.pad(np.cumsum(np.cumsum(p, 0), 1), ((1, 0), (1, 0)))
    n = 2 * r + 1
    return (c[n:, n:] - c[:-n, n:] - c[n:, :-n] + c[:-n, :-n]) / (n * n)


def ship_D(ps, mask):
    cx, cy, h, k, blur, st = ps
    R = SHIP_RAD * k + blur + 2
    x0, x1 = max(0, int(cx - R)), min(W, int(cx + R) + 1)
    y0, y1 = max(0, int(cy - R * SQ)), min(H, int(cy + R * SQ) + 1)
    if x1 <= x0 or y1 <= y0:
        return None
    ys, xs = np.mgrid[y0:y1, x0:x1].astype(np.float32)
    acc = np.zeros(xs.shape, np.float32)
    ch, sh = math.cos(h), math.sin(h)
    for oy in (1 / 6, 0.5, 5 / 6):
        for ox in (1 / 6, 0.5, 5 / 6):
            gx = (xs + ox - cx) / k
            gy = (ys + oy - cy) / (SQ * k)
            u = gx * ch + gy * sh
            v = -gx * sh + gy * ch
            mi = np.floor((u - U0) * SS).astype(np.int32)
            mj = np.floor((v + VR) * SS).astype(np.int32)
            ok = (mi >= 0) & (mi < MW) & (mj >= 0) & (mj < MH)
            val = np.zeros(xs.shape, np.float32)
            val[ok] = mask[mj[ok], mi[ok]]
            acc += val
    acc = box_blur(acc / 9.0, blur)
    return x0, y0, quant(acc * st, LEVELS)


def to_screen(ps, u, v):
    cx, cy, h, k = ps[:4]
    gx = (u * math.cos(h) - v * math.sin(h)) * k
    gy = (u * math.sin(h) + v * math.cos(h)) * k
    return cx + gx, cy + gy * SQ


def to_ship(ps, x, y):
    cx, cy, h, k = ps[:4]
    gx, gy = (x - cx) / k, (y - cy) / (SQ * k)
    return gx * math.cos(h) + gy * math.sin(h), -gx * math.sin(h) + gy * math.cos(h)


# ====================================================================== koreografi
A_P0 = (ZX - 0.92 * ZONE_R, ZY - 0.20 * ZONE_R)
A_P1 = (ZX + 0.92 * ZONE_R, ZY + 0.14 * ZONE_R)
A_H = math.atan2((A_P1[1] - A_P0[1]) / SQ, A_P1[0] - A_P0[0])
B_RO = 0.5 * ZONE_R
FALL_H = 300.0  ## gülle hedefin bu kadar üstünden (çoğu zaman ekran dışından) düşmeye başlar
LEAN = 0.3  ## başlangıç x'i gemi gölgesi tarafına bu oranda kayar (gemi o yönde, gökte)
B_W = TAU / 8.4


def pose(var, t):
    if t < 0.05 or t > SHIP_END:
        return None
    a = P.ease_out(min(1.0, (t - 0.05) / APPEAR))
    lv = max(0.0, (t - DURATION) / LEAVE) ** 2
    st = a * (1 - lv)
    if st <= 0.01:
        return None
    blur = 1 + int(round(3 * (1 - a) + 3 * lv))
    if var == 'A':  ## sabit irtifada süzülür: belirip solar, boyu hemen hemen sabit
        s = t / SHIP_END
        cx, cy = P.lerp(A_P0[0], A_P1[0], s), P.lerp(A_P0[1], A_P1[1], s)
        return (cx, cy, A_H + 0.035 * math.sin(1.3 * t), 1.0 + 0.12 * (1 - a) + 0.12 * lv, blur, st)
    k = 0.58 + 0.42 * a - 0.42 * lv  ## B/C: yukarıdan alçalır (küçük + bulanık -> tam boy + net), yükselerek gider
    if var == 'B':
        th = math.pi + B_W * t
        return (ZX + B_RO * math.cos(th), ZY - 8 + B_RO * SQ * math.sin(th), th + math.pi / 2, k, blur, st)
    return (ZX + 30 * math.sin(0.55 * t), ZY - 26 + 12 * math.sin(1.1 * t), 0.12 * math.sin(0.45 * t), k, blur, st)


# ====================================================================== sahne verisi
def place_slimes():
    rng = random.Random(11)
    pts = []
    while len([p for p in pts if p[2]]) < 11:
        a, r = rng.uniform(0, TAU), rng.uniform(0.3, 0.93) * ZONE_R
        x, y = ZX + math.cos(a) * r, ZY + math.sin(a) * r
        if 30 < x < W - 30 and 40 < y < H - 16 and all(math.hypot(x - q[0], y - q[1]) > 46 for q in pts):
            pts.append((x, y, True))
    for (a, r) in ((3.3, 1.12), (0.25, 1.1), (2.4, 1.05), (5.9, 1.15)):
        pts.append((ZX + math.cos(a) * r * ZONE_R, min(H - 16, ZY + math.sin(a) * r * ZONE_R), False))
    return pts


def plan_strikes(var, slimes):
    rng = random.Random({'A': 3, 'B': 5, 'C': 9}[var])
    inside = [s for s in slimes if s[2]]
    out = []
    for tk in range(1, int(DURATION / TICK) + 1):
        T = tk * TICK
        ps = pose(var, T)
        tg = inside[:]
        rng.shuffle(tg)
        for i in range(STRIKES):
            if i < len(tg):
                tx, ty = tg[i][0] + rng.uniform(-24, 24), tg[i][1] + rng.uniform(-24, 24)
            else:
                a, r = rng.uniform(0, TAU), rng.uniform(0, ZONE_R)
                tx, ty = ZX + math.cos(a) * r, ZY + math.sin(a) * r
            ## Gülle GÖLGEDEN çıkmaz (kullanıcı: "gökyüzünde bir gemi olduğunu ve ondan düşüyormuş gibi görünmesi gerekiyor"): hedefin
            ## FALL_H üstünden, gemi tarafına LEAN kadar yatık iner; gölge sadece hissiyat.
            sx = P.lerp(tx, ps[0], LEAN) + rng.uniform(-10, 10)
            out.append(dict(tf=T, tl=T + FALL, start=(sx, ty - FALL_H), tgt=(tx, ty), seed=tk * 7 + i))
    return out


# ====================================================================== çizim yardımcıları
def stamp(img, cv, x0, y0, alpha=1.0):
    im = cv.image()
    if alpha < 1.0:
        a = np.asarray(im).copy()
        a[:, :, 3] = (a[:, :, 3] * alpha).astype(np.uint8)
        im = Image.fromarray(a, 'RGBA')
    comp(img, im, x0, y0)


def local(S):
    return P.Canvas(S, S), S // 2


def fade_cv(cv, level):
    if level >= 1.0:
        return
    bay = np.tile(BAYER, (cv.h // 4 + 1, cv.w // 4 + 1))[:cv.h, :cv.w]
    cv.rgba[bay >= level, 3] = 0


def scorch(img, x, y, k, seed):
    if k < 1 or k > 46:
        return
    cv, c = local(40)
    m = P.blob_mask(cv, c, c, 11.0, 4.5, seed, wobble=0.2)
    for _ in range(max(0, (k - 26) // 4)):  ## sönerken kenardan aşınır (Bayer ızgarası koyu lekede kafes gibi okunuyordu)
        m = P.erode(m)
    if not m.any():
        return
    cv.put(m, (58, 46, 32))
    cv.put(m & P.erode(P.erode(m)), (40, 30, 22))
    cool = min(1.0, max(0.0, (k - 4) / 18.0))
    col = P.FIRE[3] if cool < 0.3 else (P.FIRE[1] if cool < 0.7 else (60, 46, 34))
    rng = random.Random(seed)
    for q in range(5):
        a = q * TAU / 5 + rng.uniform(-0.4, 0.4)
        for dd in range(1, 7):
            xx, yy = c + math.cos(a) * dd, c + math.sin(a) * dd * 0.42
            if m[cv.idx(xx, yy)]:
                cv.px(xx, yy, col)
    stamp(img, cv, int(round(x)) - c, int(round(y)) - c)


def flames(img, x, y, k, seed):
    if k < 2 or k > 22:
        return
    cv, c = local(32)
    grow = min(1.0, (k - 2) / 3.0) * (1.0 - max(0.0, (k - 15) / 7.0))
    items = []
    for j, (ox, oy) in enumerate(((-5, 0), (5, 1))):
        hh = (5.5 + 1.5 * j) * grow + (1 if (k + j + seed) % 3 == 0 else 0) * grow
        if hh < 1.2:
            continue
        items += [(c + ox, c + oy - hh * 0.45, max(1.0, hh * 0.55), 1.9, -math.pi / 2), (c + ox, c + oy - 0.5, 2.1, 1.6, 0.0)]
    if items:
        P.heat_fill(cv, P.ellipses_mask(cv, items), P.FIRE, levels=(1, 2, 3, 5))
        stamp(img, cv, int(round(x)) - c, int(round(y)) - c)


def explosion(img, x, y, k, seed):
    if k < 0 or k > 11:
        return
    cv, c = local(112)
    if k == 0:
        P.disc_flash(cv, c, c - 3, 8.0, core=P.CREAM, rim=P.FIRE[4], squash=0.6)
    if k < 4:
        P.shock_ring(cv, c, c, 8 + 34 * P.ease_out((k + 1) / 4.0), 1.6, k / 4.0, P.EMBER, 0.5, seed=seed, break_from=0.25)
    P.burst(cv, c, c - 4, 21.0, k / 11.0, P.FIRE, P.SMOKE, seed=seed, n_puffs=8, squash=0.8)
    if 1 <= k < 11:
        for q in range(6):
            a = q * TAU / 6 + seed * 0.7
            xx = c + math.cos(a) * 3.2 * k
            yy = c - 4 + math.sin(a) * 1.2 * k - 4.5 * k + 0.6 * k * k
            if yy < c + 2:
                P.chunk(cv, xx, yy, 2, P.EARTH)
    stamp(img, cv, int(round(x)) - c, int(round(y)) - c)


def warning(img, x, y, s):
    cv, c = local(40)
    r = 13.0 - 7.0 * s
    P.ring_band(cv, c, c, r, 1.4, [P.FIRE[0], P.FIRE[1], P.FIRE[1], P.FIRE[2], P.FIRE[3]], squash=0.5)
    if int(s * 10) % 2 == 0:
        cv.px(c, c, P.FIRE[3])
    stamp(img, cv, int(round(x)) - c, int(round(y)) - c)


def ball_path(st, s):
    """Gökten düşen güllenin ekran konumu: yerçekimi gibi hızlanarak (s^1,7) hedefe iner."""
    (px, py), (tx, ty) = st['start'], st['tgt']
    e = s ** 1.7
    return P.lerp(px, tx, e), P.lerp(py, ty, e)


def ball(img, st, s):
    S = 96
    bx, by = ball_path(st, s)
    cv, c = local(S)
    ox, oy = int(round(bx)) - c, int(round(by)) - c
    trail = []
    dist = math.hypot(st['tgt'][0] - st['start'][0], st['tgt'][1] - st['start'][1]) * 1.7 * max(s, 0.15) ** 0.7
    step = 2.2 / max(dist, 1.0)  ## iz örnekleri ~2 px arayla: üst üste binen dolu iz (seyrek puf noktalı çizgi okunuyordu)
    for i in range(1, 22):
        s2 = s - step * i
        if s2 < 0:
            break
        g2x, g2y = ball_path(st, s2)
        trail.append((g2x - ox, g2y - oy, 2.4 - 0.08 * i))
    if trail:
        P.puffs(cv, trail, P.SMOKE_LIGHT)
        stamp(img, cv, ox, oy, 0.8)
        cv, c = local(S)
    lx, ly = bx - ox, by - oy
    if trail:
        tx0, ty0 = trail[0][0], trail[0][1]
        for q, col in ((0.35, P.FIRE[4]), (0.6, P.FIRE[3])):
            cv.px(P.lerp(lx, tx0, q), P.lerp(ly, ty0, q), col)
    P.puffs(cv, [(lx, ly, 3.0)], IRON)
    cv.px(lx - 1, ly - 1, IRON[4])
    stamp(img, cv, ox, oy)


def flare(img, t):
    """Korsan'ın işaret fişeği: elinden göğe kırmızı çizgi + arkasında kalan ince duman."""
    if t < 0 or t > 1.1:
        return
    x0, y0 = ZX + 3, ZY - 24
    V = 950.0
    cv = P.Canvas(40, H)
    lx0 = 20 + (x0 - int(x0))
    puffs = []
    rng = random.Random(4)
    for i in range(0, 120):
        tb = i * 0.003  ## ~3 px arayla: dolu duman sütunu
        jit = rng.uniform(0.8, 1.2)
        if tb > t or tb > 0.33:
            break
        age = t - tb
        y = y0 - V * tb
        rr = jit * (1.0 + 1.8 * min(1.0, age / 0.45)) * (1.0 - max(0.0, (age - 0.4) / 0.5))
        if rr > 0.6:
            puffs.append((lx0 + math.sin(tb * 23) * 1.2 + age * 5, y - age * 8, rr))
    if puffs:
        P.puffs(cv, puffs, P.SMOKE_LIGHT)
        stamp(img, cv, int(x0) - 20, 0, 0.75)
        cv = P.Canvas(40, H)
    if t < 0.33:
        y = y0 - V * t
        for q in range(1, 9):
            cv.px(lx0, y + q * 2.2, RED[3] if q < 4 else RED[2])
            if q < 3:
                cv.px(lx0 + 1, y + q * 2.2, RED[2])
        P.disc_flash(cv, lx0, y, 2.6, core=RED[4], rim=RED[3])
        P.star(cv, lx0, y, 3, RED[4], RED[3])
        stamp(img, cv, int(x0) - 20, 0)
    if t < 0.08:
        cv, c = local(24)
        P.disc_flash(cv, c, c, 4.0, core=P.CREAM, rim=RED[3])
        stamp(img, cv, int(x0) - c, int(y0) - c)


GULL = [["x.......x", ".xx...xx.", "...x.x...", "....x...."],
        [".........", "xxx...xxx", "...x.x...", "....x...."]]


def gulls(D, ps, f, t):
    cx, cy, h, k, blur, st = ps
    for i, (r0, ph0) in enumerate(((112, 0.0), (134, math.pi))):
        a = 1.7 * t + ph0
        x = cx + r0 * k * math.cos(a)
        y = cy + r0 * k * SQ * math.sin(a) + 2 * math.sin(t * 3 + i)
        pat = GULL[((f + i * 2) // 3) % 2]
        for yy, row in enumerate(pat):
            for xx, ch in enumerate(row):
                if ch == 'x':
                    X, Y = int(x) + xx - 4, int(y) + yy - 2
                    if 0 <= X < W and 0 <= Y < H:
                        D[Y, X] = max(D[Y, X], quant(np.array(0.38 * st), LEVELS))


def _korsan_idle():
    sh = Image.open(os.path.join(PROJECT, 'assets', 'characters', 'korsan', 'sheets', 'idle.png')).convert('RGBA')
    return [sh.crop((c * 48, 0, c * 48 + 48, 48)) for c in range(4)]


KORSAN = _korsan_idle()


def put_slime(img, x, y, tint, squash):
    ground_shadow(img, x, y, 8, 2.5)
    s = slime(False, squash).img()
    if tint:
        a = np.array(s)
        m = a[:, :, 3] > 0
        lum = a[:, :, :3].astype(float).mean(axis=2)
        for cond, col in ((m & (lum > 110), P.FIRE[4]), (m & (lum > 60) & (lum <= 110), P.FIRE[3]), (m & (lum <= 60), P.FIRE[1])):
            a[cond, 0], a[cond, 1], a[cond, 2] = col
        s = Image.fromarray(a, 'RGBA')
    comp(img, s, x - 14, y - 20)


# ====================================================================== sahne
def render(var):
    bg = background()
    slimes = place_slimes()
    strikes = plan_strikes(var, slimes)
    nf = int(math.ceil(TOTAL / DT))
    fnt = font(16)
    frames = []
    for f in range(nf):
        t = f * DT - PRE
        ps = pose(var, t)
        ground = Image.fromarray(bg).convert('RGBA')
        for st in strikes:
            scorch(ground, st['tgt'][0], st['tgt'][1], int(math.floor((t - st['tl']) / DT)), st['seed'])
        D = np.zeros((H, W), np.float32)
        if 0 <= t <= DURATION + 0.5:
            op = P.ease_out(min(1.0, t / 0.35))
            D = zone_D(ZONE_R * (0.45 + 0.55 * op), op * (1.0 - max(0.0, (t - DURATION) / 0.5)))
        if ps is not None:
            sd = ship_D(ps, ship_mask(t * 6.0))
            if sd is not None:
                x0, y0, Ds = sd
                hh, ww = Ds.shape
                sub = D[y0:y0 + hh, x0:x0 + ww]
                D[y0:y0 + hh, x0:x0 + ww] = 1 - (1 - sub) * (1 - Ds)
            gulls(D, ps, f, t)
        for st in strikes:
            if st['tf'] <= t < st['tl']:
                q = (t - st['tf']) / FALL  ## güllenin kendi gölgesi hedefte büyür + koyulaşır
                gx, gy = st['tgt']
                rx = 1.5 + 3.5 * q
                m = ((_XX + 0.5 - gx) / rx) ** 2 + ((_YY + 0.5 - gy) / (rx * 0.45)) ** 2 <= 1.0
                D[m] = np.maximum(D[m], 0.38 if q < 0.6 else 0.55)
        g = np.asarray(ground)[:, :, :3].astype(np.float32)
        g *= 1.0 - D[..., None] * (1.0 - SHADOW_RGB)
        img = Image.fromarray(np.clip(g, 0, 255).astype(np.uint8)).convert('RGBA')
        for st in strikes:
            if st['tf'] <= t < st['tl']:
                warning(img, st['tgt'][0], st['tgt'][1], (t - st['tf']) / FALL)
        draw = [(ZY, 'k', None)]
        for (x, y, _) in slimes:
            hitk = None
            for st in strikes:
                k = int(math.floor((t - st['tl']) / DT))
                if 0 <= k < 2 and math.hypot(st['tgt'][0] - x, st['tgt'][1] - y) < 30:
                    hitk = k
            draw.append((y, 's', (x, hitk)))
        for st in strikes:
            draw.append((st['tgt'][1] + 1, 'f', st))
        draw.sort(key=lambda d: d[0])
        for (y, kind, data) in draw:
            if kind == 'k':
                ground_shadow(img, ZX, ZY + 1)
                comp(img, KORSAN[(f // 3) % 4], ZX - 24, ZY - 40)
            elif kind == 's':
                put_slime(img, int(round(data[0])), int(round(y)), data[1] is not None, 0.5 if data[1] == 0 else 0.0)
            else:
                flames(img, data['tgt'][0], data['tgt'][1], int(math.floor((t - data['tl']) / DT)), data['seed'])
        for st in strikes:
            if st['tf'] <= t < st['tl']:
                ball(img, st, (t - st['tf']) / FALL)
            explosion(img, st['tgt'][0], st['tgt'][1], int(math.floor((t - st['tl']) / DT)), st['seed'])
        flare(img, t)
        rgb = img.convert('RGB')
        dr = ImageDraw.Draw(rgb)
        label = f"{var}  {NAMES[var]}    t = {max(0.0, t):.1f} sn"
        dr.text((11, 9), label, fill=(20, 30, 14), font=fnt)
        dr.text((10, 8), label, fill=(250, 246, 226), font=fnt)
        frames.append((t, ps, rgb))
    return frames


def save_gif(name, frames):
    pal = [fr.quantize(colors=200, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE) for (_, _, fr) in frames]
    path = os.path.join(OUT, name)
    pal[0].save(path, save_all=True, append_images=pal[1:], duration=int(DT * 1000), loop=0, disposal=1)
    return path


def detail(all_frames):
    """Her yönün 3. borda anı (iniş + 1 kare), geminin çevresi x2, alt alta."""
    rows = []
    fnt = font(18)
    for var, frames in all_frames:
        T = 3.0 + FALL + DT
        t, ps, fr = min(frames, key=lambda q: abs(q[0] - T))
        cx, cy = (ps[0], ps[1]) if ps else (ZX, ZY)
        x0 = int(min(max(cx - 240, 0), W - 480))
        y0 = int(min(max(cy - 135, 0), H - 270))
        im = fr.crop((x0, y0, x0 + 480, y0 + 270)).resize((960, 540), Image.NEAREST)
        dr = ImageDraw.Draw(im)
        lab = f"{var}  {NAMES[var]}  (3. borda, x2)"
        dr.text((13, 11), lab, fill=(20, 30, 14), font=fnt)
        dr.text((12, 10), lab, fill=(250, 246, 226), font=fnt)
        rows.append(im)
    sheet = Image.new('RGB', (960, 540 * len(rows) + 6 * (len(rows) - 1)), (20, 24, 18))
    for i, im in enumerate(rows):
        sheet.paste(im, (0, i * 546))
    path = os.path.join(OUT, 'korsan_gemi_detay.png')
    sheet.save(path)
    return path


def main():
    os.makedirs(OUT, exist_ok=True)
    want = [a for a in sys.argv[1:] if a in NAMES] or list(NAMES)
    done = []
    for var in want:
        frames = render(var)
        p = save_gif(f'korsan_gemi_{var}.gif', frames)
        print(var, len(frames), 'kare', round(os.path.getsize(p) / 1e6, 1), 'MB')
        done.append((var, frames))
    if len(done) == len(NAMES):
        print('detay:', detail(done))


if __name__ == '__main__':
    main()
