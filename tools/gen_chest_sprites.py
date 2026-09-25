"""Sandık sprite sayfaları (kullanıcı isteği 2026-09-25: "oyunumdaki sandıkları değiştirmeni ve sandık açarken daha iyi ve
ödüllendirici heyecan uyandırıcı sandık açma animasyonu eklemeni istiyorum pixel tarzda sprite sheet olarak" + "elite
sandıklar ve normal sandıklar olarak 2 ayrım").

Her sayfa 20 kare x 48x48 px yatay şerit (1 sanat pikseli = 1 doku pikseli; oyunda NEAREST ile büyütülür):
  0-3   bekleme (kapalı; normal: kilitte/kayışta gezen parıltı, elit: nabız atan mor taş + yükselen kıvılcımlar)
  4-7   heyecan: sandık sallanır, kapak 1-2 px aralanır, aralıktan ışık sızar (normalde ışığın rengi = çıkan eşyanın
        nadirliği: gri/mavi/mor/altın - "gacha" gibi, kart görünmeden ipucu verir)
  8     patlama: kapak arkaya fırlar, büyük ışık
  9-15  ışın yelpazesi + fırlayan altınlar/kıvılcımlar, sönerek
  16-19 açık bekleme döngüsü (içerideki ışık nabız atar)
Dünya sandığı (chest_drop.gd) 0-3 ve açılışta 4-12; ödül ekranı (chest_open_anim.gd) hepsini oynatır.

Çıktı: assets/sprites/chests/chest_normal_t1..t4.png, chest_elite.png, chest_shadow.png. Çalıştır: python tools/gen_chest_sprites.py
"""
import math
import os
import random

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'assets', 'sprites', 'chests')
F = 48          # kare boyu
N = 20          # kare sayısı
CX = 24         # sandığın yatay merkezi (karede)
BOTTOM = 42     # sandığın alt kenarı (karede) - altında gölge payı


def C(h, a=255):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (a[3],)


def with_a(c, a):
    return (c[0], c[1], c[2], int(a))


OUTL = C('#2a1a10')
INSIDE = C('#1c110a')
WHITE = C('#fffaf0')

# Normal sandık: sıcak ahşap + demir kayış + pirinç kilit
N_PAL = dict(
    w_hi=C('#d69656'), w_md=C('#b06e3a'), w_dk=C('#854e28'), w_dd=C('#5e341b'),
    m_hi=C('#c4ced6'), m_md=C('#8c99a6'), m_dk=C('#5e6976'), m_dd=C('#3e4650'),
    l_hi=C('#ffe39a'), l_md=C('#eab748'), l_dk=C('#b07a22'), l_dd=C('#7d5212'),
)
# Elit sandık: koyu mor ahşap + altın kaplama + parlayan mor taş
E_PAL = dict(
    w_hi=C('#7a569e'), w_md=C('#5a3c7a'), w_dk=C('#3e2858'), w_dd=C('#281a3c'),
    m_hi=C('#ffeca8'), m_md=C('#f0c04e'), m_dk=C('#b8862a'), m_dd=C('#7d5a18'),
    l_hi=C('#f6d6ff'), l_md=C('#c77dff'), l_dk=C('#8a3fd1'), l_dd=C('#54208c'),
)
COIN = dict(hi=C('#fff0a8'), md=C('#f0be46'), dk=C('#b47e24'))

# Işık renkleri: normal = ödül nadirliği (TierSystem 1-4, level satırlarının hale renkleriyle aynı), elit = mor
LIGHTS = {
    1: C('#e6ebf2'),
    2: C('#9cc4ff'),
    3: C('#dcb0ff'),
    4: C('#ffc65a'),
    'elite': C('#c77dff'),
}


class Canvas:
    def __init__(self):
        self.im = Image.new('RGBA', (F, F), (0, 0, 0, 0))
        self.px = self.im.load()

    def set(self, x, y, c):
        x, y = int(x), int(y)
        if 0 <= x < F and 0 <= y < F and c is not None:
            if c[3] >= 255:
                self.px[x, y] = c
            else:
                self.blend(x, y, c)

    def blend(self, x, y, c):
        x, y = int(x), int(y)
        if not (0 <= x < F and 0 <= y < F):
            return
        r, g, b, a = self.px[x, y]
        ca = c[3] / 255.0
        na = ca + (a / 255.0) * (1 - ca)
        if na <= 0:
            return
        nr = (c[0] * ca + r * (a / 255.0) * (1 - ca)) / na
        ng = (c[1] * ca + g * (a / 255.0) * (1 - ca)) / na
        nb = (c[2] * ca + b * (a / 255.0) * (1 - ca)) / na
        self.px[x, y] = (int(nr), int(ng), int(nb), int(na * 255))

    def add_light(self, x, y, col, k):
        """Işık: altındaki pikseli ışık rengine doğru aydınlatır (saydamsa yarı saydam ışık bırakır)."""
        x, y = int(x), int(y)
        if not (0 <= x < F and 0 <= y < F) or k <= 0:
            return
        r, g, b, a = self.px[x, y]
        if a == 0:
            self.px[x, y] = (col[0], col[1], col[2], int(255 * min(1.0, k)))
            return
        t = min(1.0, k)
        self.px[x, y] = (int(r + (col[0] - r) * t), int(g + (col[1] - g) * t), int(b + (col[2] - b) * t), max(a, int(255 * t)))


# ------------------------------------------------------------------ sandık çizimi
def chest_dims(kind):
    return (22, 8, 10) if kind == 'normal' else (26, 9, 12)   # genişlik, kapak yüksekliği, gövde yüksekliği


def draw_lid_closed(cv, kind, pal, x0, y0, glint=-1, rune=0.0):
    """Kapalı kapak (ön görünüş): yuvarlak üst, iki tahta, altta metal dudak. y0 = kapağın üst satırı."""
    W, LH, _ = chest_dims(kind)
    for y in range(LH):
        inset = 2 if y == 0 else 1 if y == 1 else 0
        for x in range(inset, W - inset):
            edge = x == inset or x == W - 1 - inset or y == 0
            if edge:
                c = OUTL
            elif y == LH - 1:
                c = pal['m_hi'] if x == 1 else pal['m_dk'] if x == W - 2 else pal['m_md']   # metal dudak
            elif y == LH // 2:
                c = pal['w_dd']                                                           # tahta aralığı
            elif y <= 2:
                c = pal['w_hi'] if x < W - 3 else pal['w_md']
            elif y >= LH - 2:
                c = pal['w_dk']
            else:
                c = pal['w_md'] if x < W - 2 else pal['w_dk']
            cv.set(x0 + x, y0 + y, c)
    straps = (4, W - 6) if kind == 'normal' else (3, W - 5)
    for sx in straps:
        for y in range(1, LH - 1):
            if y == 1 and (sx < 2 or sx > W - 3):
                continue
            cv.set(x0 + sx, y0 + y, pal['m_hi'])
            cv.set(x0 + sx + 1, y0 + y, pal['m_dk'])
        cv.set(x0 + sx, y0 + 2, WHITE if kind == 'normal' else pal['m_hi'])              # perçin
    cx = W // 2
    if kind == 'normal':
        for y in range(LH - 3, LH):                                                      # kilit dili
            cv.set(x0 + cx - 2, y0 + y, OUTL)
            cv.set(x0 + cx + 1, y0 + y, OUTL)
            cv.set(x0 + cx - 1, y0 + y, pal['l_hi'] if y == LH - 3 else pal['l_md'])
            cv.set(x0 + cx, y0 + y, pal['l_md'] if y == LH - 3 else pal['l_dk'])
    else:
        # altın köşe başlıkları
        for (ax, ay) in ((1, 2), (2, 2), (1, 3), (W - 2, 2), (W - 3, 2), (W - 2, 3)):
            cv.set(x0 + ax, y0 + ay, pal['m_md'])
        # kapakta parlayan rün
        rc = mix(pal['l_dk'], pal['l_hi'], rune)
        for (ax, ay) in ((cx - 1, 2), (cx, 2), (cx - 2, 3), (cx + 1, 3), (cx - 1, 4), (cx, 4)):
            cv.set(x0 + ax, y0 + ay, rc)
        # dudaktaki altın çiviler
        for sx in range(3, W - 3, 4):
            cv.set(x0 + sx, y0 + LH - 1, pal['m_hi'])
    if glint >= 0:
        # kayış/dudak boyunca kayan beyaz parıltı (2 px çapraz)
        gx = x0 + 2 + glint
        cv.set(gx, y0 + LH - 1, WHITE)
        cv.set(gx + 1, y0 + LH - 2, with_a(WHITE, 170))


def draw_body(cv, kind, pal, x0, y0, glint=-1, gem=0.0, open_=False):
    """Gövde: üstte metal ağız, 2 tahta, altta metal şerit. y0 = gövdenin üst (ağız) satırı."""
    W, _, BH = chest_dims(kind)
    for y in range(BH):
        for x in range(W):
            last = y == BH - 1
            if last and x in (0, W - 1):
                continue
            if x in (0, W - 1) or last:
                c = OUTL
            elif y == 0:
                c = pal['m_hi'] if x < 3 else pal['m_dk'] if x > W - 4 else pal['m_md']      # ağız
            elif y == BH - 2:
                c = pal['m_dk'] if kind == 'normal' else pal['m_md']                           # alt şerit
            elif y == BH // 2 + 1:
                c = pal['w_dd']
            elif y <= 2:
                c = pal['w_md'] if x > 1 else pal['w_hi']
            else:
                c = pal['w_dk'] if (y >= BH - 4 or x >= W - 3) else pal['w_md']
            cv.set(x0 + x, y0 + y, c)
    straps = (4, W - 6) if kind == 'normal' else (3, W - 5)
    for sx in straps:
        for y in range(1, BH - 1):
            cv.set(x0 + sx, y0 + y, pal['m_hi'])
            cv.set(x0 + sx + 1, y0 + y, pal['m_dk'])
        cv.set(x0 + sx, y0 + BH - 3, WHITE if kind == 'normal' else pal['m_hi'])
    cx = W // 2
    if kind == 'normal':
        # pirinç kilit plakası + anahtar deliği
        for y in range(0, 6):
            for x in range(cx - 3, cx + 3):
                edge = x in (cx - 3, cx + 2) or y == 5
                if edge:
                    c = OUTL
                elif y == 0:
                    c = pal['l_hi']
                else:
                    c = pal['l_dk'] if x == cx + 1 else pal['l_md']
                cv.set(x0 + x, y0 + y, c)
        if not open_:
            for (kx, ky) in ((cx - 1, 2), (cx, 2), (cx - 1, 3), (cx, 3)):
                cv.set(x0 + kx, y0 + ky, OUTL)
        if glint >= 0:
            cv.set(x0 + cx - 2 + glint % 4, y0 + 1, WHITE)
    else:
        # altın alt köşeler
        for (ax, ay) in ((1, BH - 3), (2, BH - 3), (1, BH - 4), (W - 2, BH - 3), (W - 3, BH - 3), (W - 2, BH - 4)):
            cv.set(x0 + ax, y0 + ay, pal['m_md'])
        # mor taş: altın yuvada elmas
        for y in range(-1, 6):
            for x in range(cx - 4, cx + 4):
                dx = abs(x + 0.5 - cx)
                dy = abs(y - 2)
                d = dx + dy
                if d <= 2.6:
                    t = max(0.0, 1.0 - d / 2.6)
                    c = mix(pal['l_dk'], pal['l_md'], min(1.0, t * 1.4))
                    if gem > 0:
                        c = mix(c, pal['l_hi'], gem * t)
                    if x == cx - 1 and y == 1:
                        c = pal['l_hi']
                elif d <= 3.6:
                    c = pal['m_md'] if y < 3 else pal['m_dk']
                elif d <= 4.4:
                    c = OUTL
                else:
                    continue
                cv.set(x0 + x, y0 + y, c)


def draw_open_lid(cv, kind, pal, x0, y_mouth, height, light=None, glow=0.0):
    """Arkaya açılmış kapak (ön görünüş): ağzın ardında dik duran kapağın İÇ yüzü - üstte metal dudak, açık renkli iç
    kenar, ortada tahta aralığı. İçerideki ışık kapağın alt yarısını aydınlatır (ışık yukarı vuruyormuş gibi)."""
    W, _, _ = chest_dims(kind)
    top = y_mouth - height
    for y in range(top, y_mouth):
        rel = y - top
        inset = 1 if rel == 0 else 0
        for x in range(inset, W - inset):
            if x in (inset, W - 1 - inset) or rel == 0:
                c = OUTL
            elif rel == 1:
                c = pal['m_hi'] if x < 3 else pal['m_dk'] if x > W - 4 else pal['m_md']
            elif x == 1 or rel == 2:
                c = pal['w_hi']                                   # iç kenar (açık)
            elif x == W - 2:
                c = pal['w_dk']
            elif rel == (height + 2) // 2:
                c = pal['w_dd']
            else:
                c = pal['w_md']
            cv.set(x0 + x, y, c)
            if light is not None and glow > 0 and rel >= 2 and 0 < x < W - 1:
                k = (rel - 2) / max(1, height - 3)
                cv.add_light(x0 + x, y, light, glow * 0.45 * k)


def draw_interior(cv, kind, pal, x0, y_mouth, light, glow):
    """Ağzın içi: karanlık iç + ağızdan taşan altın/ışık."""
    W, _, _ = chest_dims(kind)
    for x in range(1, W - 1):
        cv.set(x0 + x, y_mouth - 1, INSIDE)
        cv.set(x0 + x, y_mouth - 2, INSIDE)
    # hazine tepeciği (normal: altın, elit: mor kristal + altın)
    rnd = random.Random(7 if kind == 'normal' else 11)
    for x in range(2, W - 2):
        h = 1 + (1 if rnd.random() < 0.55 else 0) + (1 if 5 < x < W - 6 and rnd.random() < 0.5 else 0)
        for k in range(h):
            y = y_mouth - 1 - k
            if kind == 'elite' and x % 5 == 2 and k == h - 1:
                c = pal['l_hi'] if k == 2 else pal['l_md']
            else:
                c = COIN['hi'] if k == h - 1 else COIN['md'] if k == h - 2 else COIN['dk']
            cv.set(x0 + x, y, c)
    if glow > 0:
        for x in range(1, W - 1):
            for k in range(3):
                cv.add_light(x0 + x, y_mouth - 1 - k, light, glow * (0.55 - 0.15 * k))


# ------------------------------------------------------------------ ışık, ışın, parçacık
def glow_ellipse(cv, cx, cy, rx, ry, col, alpha):
    """Basamaklı (dither YOK) yumuşak hale: 3 bant, dıştan içe artan saydamlık."""
    for band, (sx, a) in enumerate(((1.0, 0.28), (0.68, 0.5), (0.38, 0.8))):
        for y in range(int(cy - ry * sx) - 1, int(cy + ry * sx) + 2):
            for x in range(int(cx - rx * sx) - 1, int(cx + rx * sx) + 2):
                d = ((x + 0.5 - cx) / (rx * sx)) ** 2 + ((y + 0.5 - cy) / (ry * sx)) ** 2
                if d <= 1.0:
                    c = col if band < 2 else mix(col, WHITE, 0.55)
                    cv.blend(x, y, with_a(c, 255 * a * alpha * (0.55 if band == 0 else 0.45 if band == 1 else 0.6)))


def ray(cv, x0, y0, ang, length, col, alpha, width=1):
    """Ağızdan çıkan tek ışın: uca doğru incelip söner."""
    dx, dy = math.sin(ang), -math.cos(ang)
    steps = int(length)
    for i in range(steps):
        t = i / max(1, steps - 1)
        a = alpha * (1.0 - t) ** 0.8
        x, y = x0 + dx * i, y0 + dy * i
        c = mix(WHITE, col, min(1.0, t * 1.6))
        cv.blend(x, y, with_a(c, 255 * a))
        if width > 1 and t < 0.6:
            cv.blend(x + (1 if dx >= 0 else -1), y, with_a(col, 255 * a * 0.55))


def sparkle(cv, x, y, col, size):
    """size 2: artı (+) 5 px, 1: artı 3 px, 0: tek nokta."""
    x, y = int(round(x)), int(round(y))
    if size >= 2:
        for (dx, dy) in ((-2, 0), (2, 0), (0, -2), (0, 2)):
            cv.blend(x + dx, y + dy, with_a(col, 150))
    if size >= 1:
        for (dx, dy) in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            cv.set(x + dx, y + dy, col)
    cv.set(x, y, WHITE)


def coin(cv, x, y, spin):
    x, y = int(round(x)), int(round(y))
    if spin % 3 == 2:        # kenardan (ince) görünüm
        cv.set(x, y, COIN['hi'])
        cv.set(x, y + 1, COIN['dk'])
        return
    cv.set(x, y, COIN['hi'])
    cv.set(x + 1, y, COIN['md'])
    cv.set(x, y + 1, COIN['md'])
    cv.set(x + 1, y + 1, COIN['dk'])


def make_particles(kind):
    rnd = random.Random(1234 if kind == 'normal' else 4321)
    ps = []
    n_coin = 9 if kind == 'normal' else 6
    n_spark = 9 if kind == 'normal' else 14
    for i in range(n_coin + n_spark):
        is_coin = i < n_coin
        ang = rnd.uniform(-1.05, 1.05)
        speed = rnd.uniform(4.2, 7.0) if is_coin else rnd.uniform(3.2, 6.2)
        ps.append(dict(coin=is_coin, vx=math.sin(ang) * speed * 0.9, vy=-math.cos(ang) * speed,
                       spin=rnd.randint(0, 2), life=rnd.uniform(5.5, 7.5), gold=rnd.random() < 0.5))
    return ps


# ------------------------------------------------------------------ kare kurgusu
def frame(kind, fi, light):
    cv = Canvas()
    pal = N_PAL if kind == 'normal' else E_PAL
    W, LH, BH = chest_dims(kind)
    x0 = CX - W // 2
    body_top = BOTTOM - BH
    lid_top = body_top - LH
    shake = 0
    lift = 0
    seam = 0.0
    glint = -1
    gem = 0.0
    rune = 0.0
    if fi <= 3:                                     # bekleme
        if kind == 'normal':
            glint = {2: 4, 3: 12}.get(fi, -1)
        else:
            gem = (0.0, 0.35, 0.8, 0.35)[fi]
            rune = (0.2, 0.5, 1.0, 0.5)[fi]
    elif fi <= 7:                                   # heyecan
        shake = (-1, 1, -1, 1)[fi - 4]
        lift = (0, 1, 1, 2)[fi - 4]
        seam = (0.35, 0.6, 0.85, 1.0)[fi - 4]
        gem = rune = 1.0
    x0 += shake

    is_open = fi >= 8
    glow_k = 0.0
    if is_open:
        glow_k = {8: 1.6, 9: 1.35, 10: 1.15, 11: 1.0, 12: 0.9, 13: 0.8, 14: 0.72, 15: 0.66}.get(fi, 0.0)
        if fi >= 16:
            glow_k = (0.55, 0.65, 0.72, 0.65)[fi - 16]

    # elit: bekleme aurası + yükselen kıvılcımlar (kapalıyken)
    if kind == 'elite' and not is_open:
        glow_ellipse(cv, CX, BOTTOM - 1, 15, 3.2, light, 0.55 + 0.35 * gem)
        for k, (sx, phase) in enumerate(((-11, 0), (10, 2), (-4, 1), (13, 3))):
            h = ((fi + phase) % 4) * 3
            if fi <= 7 or k < 3:
                sparkle(cv, CX + sx + shake, lid_top + 4 - h, light if k % 2 else pal['m_hi'], 1 if h < 6 else 0)

    if is_open:
        mouth_y = body_top
        # arka hale
        ## Kare 48 px: hale yarıçapı karenin kenarına taşıp kesilmesin diye sınırlı.
        glow_ellipse(cv, CX, mouth_y - 4, min(21.0, 15 * glow_k), min(14.0, 10 * glow_k), light, min(1.0, glow_k))
        ## Kapak fırlar ve seker: 8. karede 3 px yukarıda, 9'da 1 px, sonra yerinde.
        bounce = {8: 3, 9: 1}.get(fi, 0)
        draw_open_lid(cv, kind, pal, x0, mouth_y - 1 - bounce, 9 if kind == 'normal' else 10, light, min(1.0, glow_k))
        # ışın yelpazesi
        if fi <= 15:
            rl = {8: 16, 9: 26, 10: 30, 11: 28, 12: 24, 13: 18, 14: 12, 15: 7}[fi]
            ra = {8: 0.9, 9: 1.0, 10: 0.9, 11: 0.75, 12: 0.6, 13: 0.45, 14: 0.3, 15: 0.18}[fi]
            angs = (-0.95, -0.55, -0.2, 0.2, 0.55, 0.95) if kind == 'normal' else (-1.0, -0.66, -0.33, 0.0, 0.33, 0.66, 1.0)
            for i, a in enumerate(angs):
                ray(cv, CX + (a * 5), mouth_y - 3, a + (0.08 if fi % 2 else -0.08) * (i % 2), rl * (0.85 + 0.3 * ((i * 7) % 3) / 2),
                    light, ra, 2 if abs(a) < 0.4 else 1)
        else:
            # açık bekleme: ağızdan yükselen yumuşak ışık sütunu
            for y in range(mouth_y - 16, mouth_y - 2):
                t = (mouth_y - 2 - y) / 14.0
                for x in range(CX - 5, CX + 5):
                    cv.blend(x, y, with_a(light, 90 * (1 - t) * glow_k * (1.0 if abs(x + 0.5 - CX) < 3 else 0.5)))
        draw_interior(cv, kind, pal, x0, mouth_y, light, min(1.0, glow_k))
        draw_body(cv, kind, pal, x0, mouth_y, open_=True)
        # patlama anı: ağızdan beyaz flaş
        if fi == 8:
            glow_ellipse(cv, CX, mouth_y - 2, 12, 6, WHITE, 1.0)
        # parçacıklar
        if 8 <= fi <= 15:
            t = (fi - 8) + 0.6
            for p in make_particles(kind):
                if t > p['life']:
                    continue
                px = CX + p['vx'] * t
                py = mouth_y - 3 + p['vy'] * t + 0.5 * 0.95 * t * t
                if py > BOTTOM + 2:
                    continue
                if p['coin']:
                    coin(cv, px, py, p['spin'] + fi)
                else:
                    life_t = t / p['life']
                    col = pal['m_hi'] if (kind == 'elite' and p['gold']) else light
                    sparkle(cv, px, py, col, 2 if life_t < 0.35 else 1 if life_t < 0.7 else 0)
        elif fi >= 16:
            # açık beklemede ara ara parlayan birkaç kıvılcım
            for k, (sx, sy) in enumerate(((-9, -12), (8, -15), (-3, -19), (11, -8))):
                if (fi + k) % 4 < 2:
                    sparkle(cv, CX + sx, mouth_y + sy, light if k % 2 else COIN['hi'], 1 if (fi + k) % 4 == 0 else 0)
    else:
        # kapalı / aralanmış: önce gövde, sonra (kalkmış) kapak, arada ışık sızıntısı
        draw_body(cv, kind, pal, x0, body_top, glint=glint if kind == 'normal' else -1, gem=gem)
        if seam > 0:
            # aralıktan sızan ışık: kapak ile gövde arası (lift+1 satır) + yanlara kaçan kısa ışınlar
            gap_rows = lift + 1
            for k in range(gap_rows):
                y = body_top - 1 - k
                for x in range(1, W - 1):
                    cv.set(x0 + x, y, mix(light, WHITE, 0.5 * seam) if k == 0 else with_a(light, 255))
            glow_ellipse(cv, CX, body_top - 1 - lift * 0.5, 16 + 4 * seam, 3 + 2 * seam, light, seam * 0.9)
            for i, a in enumerate((-1.35, -1.15, 1.15, 1.35)):
                ray(cv, CX + (W // 2 - 2) * (1 if a > 0 else -1), body_top - 1, a, 5 + 5 * seam, light, 0.6 * seam)
        draw_lid_closed(cv, kind, pal, x0, lid_top - lift, glint=glint if kind == 'normal' else -1, rune=rune)
    return cv.im


def sheet(kind, light):
    im = Image.new('RGBA', (F * N, F), (0, 0, 0, 0))
    for fi in range(N):
        im.alpha_composite(frame(kind, fi, light), (fi * F, 0))
    return im


def shadow():
    """Zemin gölgesi (sandık sprite'ı sallanırken yerde sabit kalır): 28x6 elips, yarı saydam."""
    im = Image.new('RGBA', (28, 6), (0, 0, 0, 0))
    px = im.load()
    for y in range(6):
        for x in range(28):
            d = ((x + 0.5 - 14) / 14) ** 2 + ((y + 0.5 - 3) / 3) ** 2
            if d <= 1.0:
                px[x, y] = (20, 12, 8, 70 if d > 0.55 else 100)
    return im


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for t in (1, 2, 3, 4):
        sheet('normal', LIGHTS[t]).save(os.path.join(OUT, 'chest_normal_t%d.png' % t))
    sheet('elite', LIGHTS['elite']).save(os.path.join(OUT, 'chest_elite.png'))
    shadow().save(os.path.join(OUT, 'chest_shadow.png'))
    print('chest sheets written to', os.path.abspath(OUT))
