"""2026-10-16 prototipleri: ELARA - MEVCUT yeteneklere yeni efektler (kullanıcı: "elaranın yeteneklerini silip skill setiyle uyumlu
yeni yetenek efektleri üretmen istiyorum elara genel olarak çevik bir nişancı karakteridir. prototipi göster sonra oyuna monteleriz";
ardından düzeltme: "ben varolan yetenekleri için efekt istedim yeni yetenek üretmeni istemedim"). MEKANİKLER AYNI, sadece görsel.
OYUNA HENÜZ BAĞLI DEĞİL. Değişecek eski efektler: Q `_spawn_burst` + Matthew'in hız çizgileri, E `fx_elara_true.gd` (vektör
nişangâh + dikey lazerler), R `fx_elara_double.gd` (altın kanat + parçacık) - üçü de piksel olmayan `_draw` çizimleri.
  Q  Sıvışma      (3 sn hız + yaratıkların içinden geçme) - ayak altında rüzgâr girdabı + savrulan tüyler; hareket ederken turkuaz
                  ardıl görüntüler + bacaklarda rüzgâr çizgileri; bitişte hafif esinti
  E  Gerçek Hasar (6 sn saldırı hızı odağı) - kehribar nişangâh parantezleri Elara'nın üstüne kapanır, gözde parıltı, kilitlenince
                  ayak altında dönen 4 parçalı nişangâh halkası; süre boyunca omuzlardan yükselen küçük hız okları; bitişte halka kırılır
  R  Çift Tetik   (15 sn her saldırı 2 kez) - başının üstünde çapraz iki rüzgâr oku + krem parlama + yerde hilal halkası, oklar
                  ayrılıp belinin çevresinde KARŞILIKLI dönen iki rüzgâr okuna dönüşür (ikiz = çift tetik); bitişte dışa savrulur
                  (silah ikonlarının titremesi - madde 62 - aynen kalır)
Renk dili: RÜZGÂR turkuazı `RUZ` (eski Sıvışma rengi 0.4/0.85/1.0'ın yeşile kaymış, krem çekirdekli hali) = çeviklik (Q, R);
KEHRİBAR `AMB` (gömleğinin turuncusu, eski E'nin turuncusu) = nişancı odağı (E). Çizim dili tools/pixfx.py: dolu kütleler, 5 ton
[kontur, koyu, orta, açık, parlak], 1 px koyu kontur, uçlar incelerek biter. 1 GIF pikseli = 1 Elara sanat pikseli (0.903 dünya birimi).
Çıktı: out/elara_{q,e,r}.gif
Kullanım (proje kökünden): python -I tools/proto_20261016/gen_elara_nisanci.py
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(HERE, 'out')
os.makedirs(OUT, exist_ok=True)
sys.path.insert(0, os.path.join(PROJECT, 'tools'))
sys.path.insert(0, os.path.join(PROJECT, 'tools', 'proto_20261012'))
import pixfx as P  # noqa: E402
from gen_matthew_simsek import comp, font, grass, ground_shadow, put_slime  # noqa: E402

TAU = math.tau
## [kontur, koyu, orta, açık, parlak]
RUZ = [(22, 58, 70), (36, 116, 128), (78, 184, 182), (164, 234, 218), (236, 255, 246)]
AMB = [(92, 36, 10), (190, 86, 22), (242, 146, 40), (255, 206, 104), (255, 246, 208)]
CREAM = P.CREAM
FEET = 40  ## Elara karesinde ayak satırı (idle/run, ölçüldü)


# ====================================================================== karakter
def _sheet(name):
    return Image.open(os.path.join(PROJECT, 'assets', 'characters', 'elara', 'sheets', name + '.png')).convert('RGBA')


IDLE = _sheet('idle')  ## 4 sütun; satırlar: aşağı, sol, sağ, yukarı
RUN = _sheet('run')  ## 6 sütun


def elara(sh, col, row=2):
    return sh.crop((col * 48, row * 48, col * 48 + 48, row * 48 + 48))


def put_elara(dst, fr, cx, feet):
    ground_shadow(dst, cx, feet + 1)
    comp(dst, fr, cx - 24, feet - FEET)


BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 + 1.0 / 32.0


def ghost(fr, level):
    """Ardıl görüntü: siluet rüzgâr tonlarında (aydınlık kısımlar açık), level 1 -> 0 Bayer ile seyrelir (alfa yok)."""
    a = np.array(fr)
    m = a[:, :, 3] > 0
    lum = a[:, :, :3].astype(float).mean(axis=2)
    tone = np.where(lum > 150, 4, np.where(lum > 95, 3, 2))
    tone = np.where(m & ~P.erode(m), 1, tone)
    keep = m & (np.tile(BAYER, (a.shape[0] // 4 + 1, a.shape[1] // 4 + 1))[:a.shape[0], :a.shape[1]] < level)
    out = np.zeros_like(a)
    for t in range(1, 5):
        out[keep & (tone == t)] = RUZ[t] + (255,)
    return Image.fromarray(out, 'RGBA')


# ====================================================================== ilkeller
def seg_mask(cv, x0, y0, x1, y1, w):
    X, Y = cv.grid()
    ax, ay = x1 - x0, y1 - y0
    L2 = max(ax * ax + ay * ay, 1e-6)
    t = np.clip(((X - x0) * ax + (Y - y0) * ay) / L2, 0, 1)
    return np.hypot(X - (x0 + t * ax), Y - (y0 + t * ay)) <= w * 0.5


## ok renk stilleri: (tüy açık, tüy koyu, gövde, gövde çekirdek, uç açık, uç koyu, kontur)
ARROW_STYLE = {
    'wind': (RUZ[3], RUZ[2], RUZ[3], RUZ[4], RUZ[4], RUZ[3], RUZ[0]),
    'wood': (P.STEEL[4], P.STEEL[3], P.WOOD[3], P.WOOD[3], P.STEEL[4], P.STEEL[2], (40, 26, 20)),  ## Yay'ın normal oku
    'ghost': (RUZ[3], RUZ[2], RUZ[3], RUZ[3], RUZ[4], RUZ[3], RUZ[1]),  ## R ikizinin oku
}


def arrow(cv, x, y, ang, L=16.0, broken=0.0, seed=0, style='wind'):
    """Ok; (x, y) = uç. 'wind' = R'nin çapraz ikiz okları, 'wood'/'ghost' = silah okları. broken 0..1: kuyruktan sönme."""
    c, s = math.cos(ang), math.sin(ang)
    st = ARROW_STYLE[style]

    def W(px, py):
        return (x + px * c - py * s, y + px * s + py * c)
    hl, hw, sw = (5.5, 3.0, 1.6) if style == 'wind' else (3.5, 2.0, 1.2)
    X, Y = cv.grid()
    lower = ((X - x) * (-s) + (Y - y) * c) > 0.2
    fl = P.poly_mask(cv, [W(-L + 5.0, 0), W(-L + 0.5, -2.4), W(-L - 1.0, -2.4), W(-L + 1.5, 0),
                          W(-L - 1.0, 2.4), W(-L + 0.5, 2.4)])
    sx0, sy0 = W(-hl + 1.5, 0)
    sx1, sy1 = W(-L, 0)
    sh = seg_mask(cv, sx0, sy0, sx1, sy1, sw)
    hd = P.poly_mask(cv, [W(0.8, 0), W(-hl, -hw), W(-hl + 1.5, 0), W(-hl, hw)])
    if broken > 0:  ## kuyruktan sönme: eksen boyunca konum + gürültü eşiği
        along = ((X - x) * c + (Y - y) * s) / -L  ## 0 uç, 1 kuyruk
        keep = (along + 0.25 * np.sin((X * 1.7 + Y * 2.3) + seed)) < 1.15 - 1.4 * broken
        fl &= keep
        sh &= keep
        hd &= keep
    cv.put(fl & ~lower, st[0])
    cv.put(fl & lower, st[1])
    cv.put(sh, st[2])
    cv.put(sh & seg_mask(cv, sx0, sy0, sx1, sy1, 0.9), st[3])
    cv.put(hd & ~lower, st[4])
    cv.put(hd & lower, st[5])
    m = fl | sh | hd
    cv.put(P.outline_of(m) & ~cv.filled(), st[6])
    return m


def strip(cv, p0, p1, w0, w1, pal, keep=None, outline=True):
    """p0 -> p1 incelen bant (mermi izi): ortası parlak, kenarı orta ton, açık konturu pal[1]."""
    X, Y = cv.grid()
    ax, ay = p1[0] - p0[0], p1[1] - p0[1]
    L2 = max(ax * ax + ay * ay, 1e-6)
    tr = ((X - p0[0]) * ax + (Y - p0[1]) * ay) / L2
    t = np.clip(tr, 0, 1)
    d = np.hypot(X - (p0[0] + t * ax), Y - (p0[1] + t * ay))
    hw = (w0 + (w1 - w0) * t) * 0.5
    m = (tr >= 0) & (tr <= 1) & (d <= hw) & (hw > 0.3)
    if keep is not None:
        m &= keep(t)
    k = d / np.maximum(hw, 0.5)
    tone = np.where(k < 0.36, 4, np.where(k < 0.72, 3, 2))
    for tt in (2, 3, 4):
        cv.put(m & (tone == tt), pal[tt])
    if outline:
        cv.put(P.outline_of(m) & ~cv.filled(), pal[1])
    return m


def dust(cv, x, y, t, dirx, seed, size=1.0):
    """Toz (t 0..1): küçük toplar hareketin tersine savrulur, yükselir, hilale aşınıp söner."""
    if t >= 1.0:
        return
    rng = random.Random(seed)
    circles, cuts = [], []
    for k in range(4):
        ox = -dirx * (1.5 + k * 2.6) * (0.5 + t) * size + rng.uniform(-1.0, 1.0)
        oy = -1.0 - (k % 2) * 1.4 - t * 2.5
        r = (3.0 - k * 0.45) * (1.0 - 0.55 * t) * size
        circles.append((x + ox, y + oy, r))
        if t > 0.3:
            cuts.append((x + ox + r * 0.45, y + oy - r * 0.45, r * (0.3 + 0.8 * (t - 0.3))))
    P.puffs(cv, circles, P.DUST, cut=cuts or None, squash=0.8)


def streak(cv, x0, x1, y, fade=0.0):
    """Yatay rüzgâr çizgisi x0 (kuyruk) -> x1 (baş); kuyruk yarısı seyrek; fade kuyruktan kısaltır."""
    L = x1 - x0
    if abs(L) < 2:
        return
    sgn = 1 if L > 0 else -1
    start = x0 + L * fade
    n = int(abs(x1 - start))
    for i in range(n):
        u = i / max(n, 1)
        if u < 0.45 and i % 2:
            continue
        cv.px(start + sgn * i, y, RUZ[4] if u > 0.8 else (RUZ[3] if u > 0.4 else RUZ[2]))


def crescent(cv, x, y, radius, thick, a_mid, half, mult=None, pal=RUZ, squash=1.0):
    """Ortası kalın, iki ucu sıfıra incelen hilal (ring_band + açısal zarf); squash 0.5 = yere yatık."""
    X, Y = cv.grid()
    d = np.mod(np.arctan2((Y - y) / squash, X - x) - a_mid + math.pi, TAU) - math.pi
    env = np.where(np.abs(d) < half, np.cos(d / half * math.pi / 2), 0.0)
    if mult is not None:
        env = env * mult
    return P.ring_band(cv, x, y, radius, thick, pal, squash=squash, mult=env)


def feather(cv, x, y, ang, age):
    """Savrulan tüy (7 px: krem uç, turkuaz gövde, koyu sap, 1 px kontur); age 0..1 ile Bayer seyrelir."""
    c, s = math.cos(ang), math.sin(ang)
    m = np.zeros((cv.h, cv.w), dtype=bool)
    cols = []
    for i in range(7):
        col = RUZ[4] if i < 2 else (RUZ[3] if i < 5 else RUZ[1])
        cols.append((x + c * i, y + s * i, col))
        if 1 <= i <= 4:
            cols.append((x + c * i - s, y + s * i + c, RUZ[2]))
    for (px, py, col) in cols:
        if BAYER[int(py) % 4, int(px) % 4] < age * 1.1 - 0.1:
            continue
        r, cc = cv.idx(px, py)
        if 0 <= r < cv.h and 0 <= cc < cv.w:
            cv.rgba[r, cc] = col + (255,)
            m[r, cc] = True
    cv.put(P.outline_of(m) & ~cv.filled(), RUZ[0])


def reticle(cv, x, y, r, k_rot, col=None, arm=4.5):
    """Kehribar nişangâh: 4 köşe parantezi (yarıçap r, dönüş k_rot radyan)."""
    m = np.zeros((cv.h, cv.w), dtype=bool)
    for q in range(4):
        a = k_rot + math.pi / 4 + q * math.pi / 2
        px, py = x + math.cos(a) * r, y + math.sin(a) * r * 1.15
        for da in (3 * math.pi / 4, -3 * math.pi / 4):
            b = a + da
            m |= seg_mask(cv, px, py, px + math.cos(b) * arm, py + math.sin(b) * arm, 1.4)
    cv.put(m, col or AMB[3])
    cv.put(P.outline_of(m) & ~cv.filled(), AMB[0])


def box_brackets(cv, cx, cy, hw, hh, col=None, arm=3):
    """Silah ikonunu saran düz köşe parantezleri (yarı genişlik hw, yarı yükseklik hh)."""
    m = np.zeros((cv.h, cv.w), dtype=bool)
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = cx + sx * hw, cy + sy * hh
            m |= seg_mask(cv, x, y, x - sx * arm, y, 1.3)
            m |= seg_mask(cv, x, y, x, y - sy * arm, 1.3)
    cv.put(m, col or AMB[3])
    cv.put(P.outline_of(m) & ~cv.filled(), AMB[0])


def chevron(cv, x, y, age):
    """Omuzdan yükselen küçük hız oku '^' (5 px geniş): age 0..1 yükselir ve uçtan seyrelir."""
    yy = y - age * 7.0
    pts = [(0, 0, AMB[4]), (-1, 1, AMB[3]), (1, 1, AMB[3]), (-2, 2, AMB[2]), (2, 2, AMB[2])]
    for (dx, dy, col) in pts:
        if BAYER[(dy + 1) % 4, (dx + 2) % 4] < age * 1.2 - 0.15:
            continue
        cv.px(x + dx, yy + dy, col)
    m = np.zeros((cv.h, cv.w), dtype=bool)
    for (dx, dy, _c) in pts:
        r, c = cv.idx(x + dx, yy + dy)
        if 0 <= r < cv.h and 0 <= c < cv.w and cv.rgba[r, c, 3] > 0:
            m[r, c] = True
    if age < 0.6:
        cv.put(P.outline_of(m) & ~cv.filled(), AMB[0])


def wisp(cv, cx, cy, a, rx, ry, dirn, trail=0.9, scale=1.0, broken=0.0, seed=0):
    """Yörüngede dönen rüzgâr oku başı + arkasında incelen iz (R ikizleri). a: yörünge açısı, dirn +1/-1 dönüş yönü."""
    pts = []
    n = 9
    for i in range(n + 1):
        t = i / n  ## 0 kuyruk ... 1 baş
        aa = a - dirn * trail * (1 - t)
        pts.append((cx + math.cos(aa) * rx, cy + math.sin(aa) * ry, t))
    X, Y = cv.grid()
    full = np.zeros((cv.h, cv.w), dtype=bool)
    core = np.zeros((cv.h, cv.w), dtype=bool)
    for (x, y, t) in pts[:-1]:
        w = (0.4 + 2.2 * t ** 1.2) * scale
        d2 = (X - x) ** 2 + (Y - y) ** 2
        full |= d2 <= (w * 0.5) ** 2
        core |= d2 <= (w * 0.22) ** 2
    if broken > 0:
        keep = (np.sin(X * 1.3 + Y * 2.1 + seed) * 0.5 + 0.5) > broken * 1.2 - 0.1
        full &= keep
        core &= keep
    cv.put(full, RUZ[3])
    cv.put(core, RUZ[4])
    cv.put(P.outline_of(full) & ~cv.filled(), RUZ[1])
    hx, hy, _t = pts[-1]
    tx, ty = -math.sin(a) * rx * dirn, math.cos(a) * ry * dirn  ## teğet
    L = math.hypot(tx, ty) or 1.0
    ang = math.atan2(ty / L, tx / L)
    if broken < 0.6:
        c, s = math.cos(ang), math.sin(ang)
        hd = P.poly_mask(cv, [(hx + c * 3.5 * scale, hy + s * 3.5 * scale),
                              (hx - c * 1.5 * scale - s * 2.6 * scale, hy - s * 1.5 * scale + c * 2.6 * scale),
                              (hx - c * 0.3, hy - s * 0.3),
                              (hx - c * 1.5 * scale + s * 2.6 * scale, hy - s * 1.5 * scale - c * 2.6 * scale)])
        lower = ((X - hx) * (-s) + (Y - hy) * c) > 0.2
        cv.put(hd & ~lower, RUZ[4])
        cv.put(hd & lower, RUZ[3])
        cv.put(P.outline_of(hd) & ~cv.filled(), RUZ[0])


# ====================================================================== kaydet
def save_gif(name, frames, scale, ms, labels=None):
    f = font(15)
    big = []
    for fr in frames:
        im = fr.convert('RGB').resize((fr.width * scale, fr.height * scale), Image.NEAREST)
        if labels:
            d = ImageDraw.Draw(im)
            for (x, y, text) in labels:
                d.text((x + 1, y + 1), text, fill=(20, 30, 14), font=f)
                d.text((x, y), text, fill=(250, 246, 226), font=f)
        big.append(im.quantize(colors=200, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE))
    big[0].save(os.path.join(OUT, name), save_all=True, append_images=big[1:], duration=ms, loop=0, disposal=1)


def layer(W, H):
    return P.Canvas(W, H)


# ====================================================================== Q - Sıvışma
def scene_q():
    """Kamera Elara'yı izler (çim kayar). 3 sn = 48 kare -> burada 30 karelik koşu (GIF kısa kalsın), bir slime'ın içinden geçer."""
    W, H = 250, 104
    feet = 74
    SCR = 96  ## Elara'nın ekran x'i
    CAST = 4
    RUN0, RUN1 = CAST + 1, CAST + 31
    SPD = 7.0  ## %30 hızlı koşu (oyunda 82 x 1,15 x 1,3 dünya/sn ~ 7 px/kare @16 fps)
    slime_wx = SCR + 150
    frames = []
    hist = []  ## ardıl görüntü kayıtları: (dünya x, kare görüntüsü, doğduğu kare)
    for f in range(RUN1 + 10):
        wx = SCR + SPD * max(0, min(f, RUN1) - CAST)
        cam = wx - SCR
        img = grass(W, H, int(cam) + 400)
        moving = RUN0 <= f <= RUN1
        fr = elara(RUN, f % 6) if moving else elara(IDLE, (f // 4) % 4)
        if moving and f % 2 == 0:
            hist.append((wx, fr, f))
        gv = layer(W, H)
        if CAST <= f <= CAST + 5:  ## yere yatık rüzgâr girdabı (iki hilal döner, genişler, parçalanır)
            k = (f - CAST) / 6.0
            cx = SCR - cam  ## girdap dünyada sabit (kullanıldığı yerde kalır)
            for j in (0, 1):
                crescent(gv, cx, feet, 11.0 + 10.0 * P.ease_out(k), 3.2 * (1 - k) + 0.8, j * math.pi + k * 3.0, 1.3,
                         P.break_mult(gv, cx, feet, 0.5, (k - 0.45) / 0.55, 4) if k > 0.45 else None, squash=0.5)
        if RUN0 <= f <= RUN0 + 3:
            dust(gv, SCR - 4 - cam, feet, (f - RUN0) / 4.0, 1, seed=1)
        if RUN1 + 1 <= f <= RUN1 + 5:  ## bitiş esintisi
            k = (f - RUN1 - 1) / 5.0
            crescent(gv, SCR + 2, feet, 9.0 + 9.0 * k, 3.0 * (1 - k) + 0.7, math.pi, 1.1,
                     P.break_mult(gv, SCR + 2, feet, 0.5, k, 6) if k > 0.3 else None, squash=0.5)
        comp(img, gv.image())
        for (hx, hfr, hf) in hist:  ## ardıl görüntüler: 2 karede bir, 4 karede seyrelip söner
            age = f - hf
            if 1 <= age <= 4:
                comp(img, ghost(hfr, (0.62, 0.45, 0.28, 0.12)[age - 1]), hx - cam - 24, feet - FEET)
        sx = slime_wx - cam
        through = abs(sx - SCR) < 12 and moving
        put_slime(img, sx, feet - 2)
        put_elara(img, fr, SCR, feet)
        cv = layer(W, H)
        if moving:  ## bacaklarda ve belde rüzgâr çizgileri
            for (dy, ln, off) in ((-3, 16, 0), (-9, 12, 3), (-20, 9, 5)):
                if (f + off) % 3 != 2:
                    streak(cv, SCR - 8 - ln - (f + off) % 3 * 2, SCR - 7, feet + dy)
        if through:  ## yaratığın içinden geçerken rüzgâr kabuğu (siluet turkuaz kontur)
            comp(img, ghost(fr, 0.5), SCR - 24, feet - FEET)
        if CAST <= f <= CAST + 8:  ## savrulan tüyler
            age = (f - CAST) / 8.0
            for j, (vx, vy, a0) in enumerate(((-9, -13, 2.4), (-14, -6, 2.9), (-5, -18, 2.0))):
                feather(cv, SCR + vx * P.ease_out(age) - 2 * j, feet - 14 + vy * P.ease_out(age) + age * 6, a0 + age * 1.5 * (1 if j % 2 else -1), age)
        if f == CAST:
            P.star(cv, SCR, feet - 16, 4, P.WHITE, RUZ[3])
        comp(img, cv.image())
        frames.append(img)
    return frames


# ====================================================================== silahlar (E/R'nin silah tarafı)
PX = 1.0 / 0.903  ## dünya birimi -> Elara pikseli
ORIGIN_UP = 15.5  ## karakter düğümü merkezi ayaktan bu kadar yukarıda (Elara px)
BRASS = [(57, 42, 28), (165, 98, 67), (239, 183, 117), (255, 226, 170), (255, 246, 220)]


def _icon(path, tscn_scale):
    """Silah ikonu oyundaki boyutunda: tscn ölçeği x 0,9 x 0,85 (weapon.gd) x 0,5 (oyuncu kökü) dünya -> Elara pikseli; alfa eşikli."""
    im = Image.open(os.path.join(PROJECT, path)).convert('RGBA')
    im = im.crop(im.getbbox())
    k = tscn_scale * 0.9 * 0.85 * 0.5 * PX
    small = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.BOX)
    a = np.array(small)
    a[:, :, 3] = np.where(a[:, :, 3] > 110, 255, 0)
    return Image.fromarray(a, 'RGBA')


## yuvalar player.gd WEAPON_ICON_SLOTS x 0,5 (dünya) -> Elara pikseli; namlu ucu ikon merkezine göre
WEAPONS = [
    dict(icon=_icon('assets/weapons/yay/draw1.png', 0.307395), slot=(0, -69), kind='arrow', period=12, tgt=0, phase=0.0, first=3),
    dict(icon=_icon('assets/weapons/tabanca/icon_v2.png', 0.28875), slot=(34, -39), kind='bullet', period=9, tgt=1, phase=2.1, first=6),
    dict(icon=_icon('assets/weapons/tufek/icon.png', 0.35475), slot=(-34, -39), kind='bullet', period=14, tgt=2, phase=4.2, first=1),
]
for _w in WEAPONS:
    _w['muzzle'] = (3.0, 0.0) if _w['kind'] == 'arrow' else (_w['icon'].width / 2.0 - 1.0, -_w['icon'].height / 2.0 + 3.0)


def echo_icon(icon, level):
    """Çift Tetik ikizi: silah ikonunun turkuaz silueti (açık yerler parlak) + 1 px açık kenar; ince silah çizgileri de okunsun
    diye ghost()'tan dolu, level 1 -> 0 Bayer ile seyrelir."""
    a = np.array(icon)
    h, w = a.shape[:2]
    pad = 1
    m0 = a[:, :, 3] > 0
    m = np.zeros((h + 2 * pad, w + 2 * pad), dtype=bool)
    m[pad:pad + h, pad:pad + w] = m0
    lum = np.zeros(m.shape)
    lum[pad:pad + h, pad:pad + w] = a[:, :, :3].astype(float).mean(axis=2)
    bay = np.tile(BAYER, (m.shape[0] // 4 + 1, m.shape[1] // 4 + 1))[:m.shape[0], :m.shape[1]]
    out = np.zeros(m.shape + (4,), dtype=np.uint8)
    edge = P.dilate(m) & ~m
    out[edge & (bay < level * 0.8)] = RUZ[2] + (255,)
    tone = np.where(lum > 120, 4, 3)
    for t in (3, 4):
        out[m & (tone == t) & (bay < level)] = RUZ[t] + (255,)
    return Image.fromarray(out, 'RGBA')


def weapon_center(w, ex, feet, f, jitter=False):
    bob = math.sin(f * 0.35 + w['phase']) * 2.0
    x, y = ex + w['slot'][0], feet - ORIGIN_UP + w['slot'][1] + bob
    if jitter:  ## Çift Tetik titremesi (madde 62, aynen kalır)
        r = random.Random(f * 31 + int(w['phase'] * 10))
        x += r.choice((-1, 0, 1))
        y += r.choice((-1, 0, 1))
    return x, y


def put_icon(img, icon, cx, cy):
    comp(img, icon, cx - icon.width / 2.0, cy - icon.height / 2.0)


def glint(icon, k):
    """İkonun üstünden çapraz kayan kehribar parıltı bandı (k 0..1)."""
    a = np.array(icon).copy()
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    d = xx + yy * 0.7
    pos = -0.7 * h + (w + 1.4 * h) * k
    band = (a[:, :, 3] > 0) & (d >= pos) & (d < pos + 3.0)
    for c in range(3):
        a[:, :, c] = np.where(band, (a[:, :, c] * 0.25 + AMB[4][c] * 0.75).astype(np.uint8), a[:, :, c])
    return Image.fromarray(a, 'RGBA')


def bullet(cv, x, y, ang, pal):
    c, s = math.cos(ang), math.sin(ang)
    m = seg_mask(cv, x - c * 3.0, y - s * 3.0, x, y, 2.0)
    cv.put(m, pal[2])
    cv.px(x, y, pal[3])
    cv.put(P.outline_of(m) & ~cv.filled(), pal[0])


SHOT_COLS = {  ## (namlu/isabet parıltısı çekirdek, kol, iz paleti)
    'normal': (CREAM, (226, 220, 204), None),
    'amber': (P.WHITE, AMB[3], AMB),
    'ghost': (P.WHITE, RUZ[3], RUZ),
}


def fire_frames(w, F, fast_window):
    out, f = [], w['first']
    while f < F:
        out.append(f)
        per = w['period']
        if fast_window and fast_window[0] <= f < fast_window[1]:
            per = int(round(per / 1.3))  ## E: normal saldırı hızının %30'u kadar hızlı
        f += per
    return out


def draw_shots(cv, f, shots, targets):
    """shots: (ateş karesi, namlu noktası, hedef indeksi, tür, stil). Mermi + iz + namlu parıltısı + isabet; doner: bu karede vurulan hedefler."""
    hit_now = set()
    for (f0, p0, ti, kind, style) in shots:
        dt = f - f0
        if dt < 0:
            continue
        tx, tsf = targets[ti]
        p1 = (tx + 0.5, tsf - 8.0)
        dx, dy = p1[0] - p0[0], p1[1] - p0[1]
        dist = math.hypot(dx, dy)
        ang = math.atan2(dy, dx)
        n = max(1, int(math.ceil(dist / (22.0 if kind == 'arrow' else 30.0))))
        core, arm, tpal = SHOT_COLS[style]
        if dt == 0:
            P.star(cv, p0[0], p0[1], 2, core, arm)
        if dt < n:
            k = (dt + 0.6) / n
            hx, hy = p0[0] + dx * k, p0[1] + dy * k
            tail = 12.0 if kind == 'arrow' else 3.0
            if tpal is not None:
                L = min(14.0, dist * k)
                tx0, ty0 = hx - math.cos(ang) * (tail + L), hy - math.sin(ang) * (tail + L)
                tx1, ty1 = hx - math.cos(ang) * tail, hy - math.sin(ang) * tail
                strip(cv, (tx0, ty0), (tx1, ty1), 0.0, 2.2, tpal)
            if kind == 'arrow':
                arrow(cv, hx, hy, ang, L=12.0, style='ghost' if style == 'ghost' else 'wood')
            else:
                bullet(cv, hx, hy, ang, RUZ if style == 'ghost' else BRASS)
        elif dt in (n, n + 1):
            P.star(cv, p1[0] - math.cos(ang) * 5, p1[1] - math.sin(ang) * 5, 3 if dt == n else 1, core, arm, diag=dt == n)
            if dt == n:
                hit_now.add(ti)
    return hit_now


TARGETS = [(236, 60), (266, 100), (226, 136)]  ## slime (x, ayak)


def put_targets(img, f, hit_log):
    for i, (x, sf) in enumerate(TARGETS):
        sq = 0.5 if any(f - hf in (0, 1) for hf in hit_log.get(i, [])) else 0.0
        put_slime(img, x, sf, squash=sq)


# ====================================================================== E - Gerçek Hasar (odak)
def scene_e():
    W, H = 300, 156
    ex, feet = 72, 132
    CAST = 10
    LOCK = CAST + 6
    END = LOCK + 30  ## 6 sn burada 30 kare
    F = END + 10
    shots = []
    for w in WEAPONS:
        for f0 in fire_frames(w, F, (LOCK, END)):
            cx, cy = weapon_center(w, ex, feet, f0)
            shots.append((f0, (cx + w['muzzle'][0], cy + w['muzzle'][1]), w['tgt'], w['kind'], 'amber' if LOCK <= f0 < END else 'normal'))
    hit_log = {}
    frames = []
    for f in range(F):
        img = grass(W, H, 260)
        gv = layer(W, H)
        rot = (f - LOCK) * 0.13
        if LOCK <= f < END:  ## ayak altında dönen 4 parçalı nişangâh halkası (yere yatık)
            gaps = [(rot + q * math.pi / 2 - 0.2, rot + q * math.pi / 2 + 0.2) for q in range(4)]
            grow = min(1.0, (f - LOCK + 1) / 3.0)
            P.ring_band(gv, ex, feet, 10.0 + 6.0 * P.ease_out(grow), 2.2, AMB, squash=0.5, gaps=gaps)
        elif END <= f < END + 5:  ## halka kırılır
            k = (f - END) / 5.0
            P.ring_band(gv, ex, feet, 16.0 + 4.0 * k, 2.2 * (1 - k) + 0.6, AMB, squash=0.5,
                        mult=P.break_mult(gv, ex, feet, 0.5, k, 7))
        comp(img, gv.image())
        put_targets(img, f, hit_log)
        put_elara(img, elara(IDLE, (f // 4) % 4), ex, feet)
        for j, w in enumerate(WEAPONS):  ## silahlar: süre boyunca 8 karede bir kehribar parıltı kayar
            cx, cy = weapon_center(w, ex, feet, f)
            icon = w['icon']
            if LOCK <= f < END:
                g = (f - LOCK - j * 2) % 8
                if g <= 3:
                    icon = glint(icon, g / 3.0)
            put_icon(img, icon, cx, cy)
        cv = layer(W, H)
        cy = feet - 17
        if CAST <= f < LOCK:  ## parantezler dönerek Elara'nın ve HER SİLAHIN üstüne kapanır
            k = (f - CAST) / (LOCK - CAST - 1)
            e = P.ease_out(min(1.0, k))
            reticle(cv, ex, cy, 30.0 - 13.0 * e, (1 - e) * math.pi / 2)
            for w in WEAPONS:
                wx, wy = weapon_center(w, ex, feet, f)
                pad = 2.5 + 7.0 * (1 - e)
                box_brackets(cv, wx, wy, w['icon'].width / 2.0 + pad, w['icon'].height / 2.0 + pad)
        elif f in (LOCK, LOCK + 1):  ## kilit: krem parlama
            col = CREAM if f == LOCK else AMB[4]
            reticle(cv, ex, cy, 16.0 + (f - LOCK) * 2, 0.0, col=col)
            for w in WEAPONS:
                wx, wy = weapon_center(w, ex, feet, f)
                pad = 2.5 + (f - LOCK) * 1.5
                box_brackets(cv, wx, wy, w['icon'].width / 2.0 + pad, w['icon'].height / 2.0 + pad, col=col)
        if f in (LOCK - 1, LOCK, LOCK + 1):  ## gözde nişancı parıltısı
            P.star(cv, ex + 3, feet - 25, (2, 3, 1)[f - LOCK + 1], P.WHITE, AMB[3], diag=f == LOCK)
        if LOCK + 2 <= f < END:  ## omuzlardan yükselen hız okları (her 5 karede bir, iki yana sırayla)
            for born in range(LOCK + 2, f + 1, 5):
                age = (f - born) / 5.0
                side = -1 if ((born - LOCK) // 5) % 2 == 0 else 1
                if age < 1.0:
                    chevron(cv, ex + side * 8, feet - 22, age)
        for ti in draw_shots(cv, f, shots, TARGETS):
            hit_log.setdefault(ti, []).append(f)
        comp(img, cv.image())
        frames.append(img)
    return frames


# ====================================================================== R - Çift Tetik
ECHO_OFF = (-5.0, 3.0)  ## ikiz yansımanın ikona göre kayması (arka-sol-alt)
ECHO_DELAY = 2  ## ikinci tetik 2 kare (~0,13 sn) sonra ikizden çıkar


def scene_r():
    W, H = 300, 156
    ex, feet = 72, 132
    CAST = 10
    SPLIT = CAST + 4
    END = SPLIT + 32  ## 15 sn burada 32 kare
    F = END + 10
    ORX, ORY = 17.0, 7.0  ## bel çevresi yörüngesi (yere yatık elips)
    ocy = feet - 12
    top = (ex, feet - 44)  ## çapraz okların kesişimi (başın üstü)
    shots = []
    for w in WEAPONS:
        for f0 in fire_frames(w, F, None):
            on = SPLIT <= f0 < END
            cx, cy = weapon_center(w, ex, feet, f0, jitter=on)
            shots.append((f0, (cx + w['muzzle'][0], cy + w['muzzle'][1]), w['tgt'], w['kind'], 'normal'))
            if on:  ## ikinci tetik: ikiz yansımanın namlusundan turkuaz kopya
                g0 = f0 + ECHO_DELAY
                gx, gy = weapon_center(w, ex, feet, g0, jitter=True)
                shots.append((g0, (gx + ECHO_OFF[0] + w['muzzle'][0], gy + ECHO_OFF[1] + w['muzzle'][1]), w['tgt'], w['kind'], 'ghost'))
    hit_log = {}
    frames = []
    for f in range(F):
        img = grass(W, H, 330)
        gv = layer(W, H)
        if CAST + 1 <= f <= CAST + 6:  ## yerde iki hilalli halka açılıp parçalanır
            k = (f - CAST - 1) / 6.0
            P.shock_ring(gv, ex, feet, 9.0 + 12.0 * P.ease_out(k), 2.6, k, RUZ, 0.5, seed=21, break_from=0.35)
        comp(img, gv.image())
        put_targets(img, f, hit_log)
        back, front = layer(W, H), layer(W, H)
        if SPLIT <= f < END + 6:
            a = (f - SPLIT) * 0.42  ## ~15 karede bir tur
            if f < SPLIT + 3:  ## kesişimden yörüngeye spiral iniş
                k = (f - SPLIT + 1) / 3.0
                cyk = top[1] + (ocy - top[1]) * P.ease_out(k)
                rxk, ryk = ORX * k, ORY * k
            elif f >= END:  ## bitiş: dışa savrulup söner
                k = (f - END) / 6.0
                cyk, rxk, ryk = ocy - 4 * k, ORX * (1 + 0.8 * k), ORY * (1 + 0.8 * k)
            else:
                cyk, rxk, ryk = ocy, ORX, ORY
            brk = (f - END) / 6.0 if f >= END else 0.0
            for j in (0, 1):
                aj = a + j * math.pi
                tgt = front if math.sin(aj) > 0 else back
                wisp(tgt, ex, cyk, aj, rxk, ryk, 1, trail=0.95, broken=brk, seed=j * 2.0)
        comp(img, back.image())
        put_elara(img, elara(IDLE, (f // 4) % 4), ex, feet)
        comp(img, front.image())
        on = SPLIT <= f < END
        for w in WEAPONS:  ## silahlar + arkalarında turkuaz ikiz yansıma (belirir / titrer / söner)
            cx, cy = weapon_center(w, ex, feet, f, jitter=on)
            lvl = 0.0
            if SPLIT <= f < SPLIT + 3:
                lvl = (0.3, 0.6, 0.85)[f - SPLIT]
            elif on:
                lvl = 0.85
            elif END <= f < END + 3:
                lvl = (0.6, 0.35, 0.15)[f - END]
            if lvl > 0:
                put_icon(img, echo_icon(w['icon'], lvl), cx + ECHO_OFF[0], cy + ECHO_OFF[1])
            put_icon(img, w['icon'], cx, cy)
        cv = layer(W, H)
        if SPLIT <= f < SPLIT + 2:  ## ikizin doğuşu: her silahta küçük turkuaz parıltı
            for w in WEAPONS:
                cx, cy = weapon_center(w, ex, feet, f, jitter=True)
                P.star(cv, cx + ECHO_OFF[0], cy + ECHO_OFF[1], 3 if f == SPLIT else 2, P.WHITE, RUZ[3])
        if CAST <= f < SPLIT + 1:  ## başın üstünde çapraz iki rüzgâr oku (X) + krem parlama
            k = f - CAST
            br = 0.0 if f < SPLIT else 0.6
            spread = (0.0, 2.0, 3.0, 3.0, 3.0)[min(k, 4)]
            for (ad, sd) in ((-math.pi / 4, 1), (-3 * math.pi / 4, 2)):  ## orta noktalar kesişimde: X
                d = 8.0 + spread
                arrow(cv, top[0] + math.cos(ad) * d, top[1] + math.sin(ad) * d, ad, broken=br, seed=sd)
            if k <= 1:
                P.disc_flash(cv, top[0], top[1], (4.0, 2.5)[k], core=CREAM, rim=RUZ[4])
                P.star(cv, top[0], top[1], (7, 4)[k], P.WHITE, RUZ[3], diag=k == 0)
        for ti in draw_shots(cv, f, shots, TARGETS):
            hit_log.setdefault(ti, []).append(f)
        comp(img, cv.image())
        frames.append(img)
    return frames


def main():
    for old in ('elara_pasif.gif',):  ## yanlış anlaşılan "yeni kit" prototipinden kalan
        p = os.path.join(OUT, old)
        if os.path.exists(p):
            os.remove(p)
    save_gif('elara_q.gif', scene_q(), 3, 62, [(8, 6, 'Q  Sıvışma - girdap + tüy, ardıl görüntü, içinden geçiş')])
    save_gif('elara_e.gif', scene_e(), 3, 66, [(8, 6, 'E  odak: Elara + silahlara kehribar kilit, parıltı, hızlı atışta kehribar iz')])
    save_gif('elara_r.gif', scene_r(), 3, 66, [(8, 6, 'R  Çift Tetik: silahların turkuaz ikizi her atışı tekrarlar')])
    print('tamam:', sorted(n for n in os.listdir(OUT) if n.startswith('elara')))


if __name__ == '__main__':
    main()
