"""Şovalye Q (Kışkırtma, id 45) efekti - "A Kalkan Darbesi" (kullanıcı seçimi 2026-11-16, madde 726/740) -> assets/fx/sovalye/

Prototip: tools/proto_20261116/sovalye_q/q_proto.py (A/B/C). Bu dosya onun A çizimini AYNEN taşır (B/C silindi).
  q_cast  (20 kare, 20 fps, döngüsüz): ayak altından dolu mavi şok dalgası + sıçrayan kalkan kırıntıları + ayak ışığının açılışı.
  q_loop  (20 kare, 20 fps, döngü = 1 sn): ayak ışığı + kare 0'da (her saniye = kalkan yenileme tiki) ayaktan göğse yükselen
          halka + 3 zerre. Arka yarısı "back" (karakterin arkasında), ön yarısı "front" (önünde).
  q_taunt (24 kare, 20 fps, döngüsüz; yalnız back): "Meydan Okuma" evrimi - dış kırmızı dalga + içeri çekilen çizgiler.
Çizim: 1 sanat px = karakter pikseli (0,903 dünya; kök 0,5 -> 1,806 yerel, fx_sovalye_taunt.gd TEXEL), dither YOK,
alfa 1 / 0,8 / 0,55 / 0,3. Her klip kendi içerik kutusuna kırpılır (x kökene göre simetrik); köken (ayak) klibin
KIRPILMIŞ karesindeki yeri fx_sovalye_taunt.gd *_ORIGIN sabitleri - bu betik değişince yazdırdığı değerlerle güncelle.

Çalıştır: python -I tools/gen_sovalye_q_fx.py   (sonra Godot import: editör ya da --headless --import)
"""
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx", "sovalye")
RES = "res://assets/fx/sovalye/"
FPS = 20
W, H = 144, 112
OX, OY = 72, 80  # ayak altı (zemin merkezi)
K = 0.42  # zemin elipsi ry/rx

BLUE = [(26, 40, 96), (50, 92, 186), (84, 150, 236), (146, 208, 255), (214, 244, 255)]
RED = [(92, 20, 32), (176, 40, 48), (230, 76, 68), (255, 138, 116), (255, 206, 186)]
CREAM = (255, 250, 232)
LEVELS = np.array([0.0, 0.3, 0.55, 0.8, 1.0])

XX = np.arange(W, dtype=float)[None, :].repeat(H, 0) - OX
YY = np.arange(H, dtype=float)[:, None].repeat(W, 1) - OY


def q(a):
    """Düz alfa basamağına yuvarla."""
    a = float(np.clip(a, 0.0, 1.0))
    return float(LEVELS[np.abs(LEVELS - a).argmin()])


def down(a, n=1):
    i = int(np.abs(LEVELS - a).argmin())
    return float(LEVELS[max(0, i - n)])


class Layer:
    def __init__(self):
        self.rgb = np.zeros((H, W, 3))
        self.a = np.zeros((H, W))

    def over(self, mask, rgb, alpha):
        A = np.where(mask, alpha, 0.0)
        if A.max() <= 0:
            return
        col = np.array(rgb, float)
        oa = A + self.a * (1 - A)
        safe = np.maximum(oa, 1e-6)[..., None]
        self.rgb = np.where(oa[..., None] > 0, (col * A[..., None] + self.rgb * (self.a * (1 - A))[..., None]) / safe, self.rgb)
        self.a = oa

    def px(self, x, y, rgb, alpha):
        x, y = int(round(x)) + OX, int(round(y)) + OY
        if 0 <= x < W and 0 <= y < H and alpha > 0:
            a0 = self.a[y, x]
            oa = alpha + a0 * (1 - alpha)
            self.rgb[y, x] = (np.array(rgb, float) * alpha + self.rgb[y, x] * a0 * (1 - alpha)) / oa
            self.a[y, x] = oa

    def image(self):
        a = self.a.copy()
        idx = np.abs(a[..., None] - LEVELS).argmin(-1)
        a = LEVELS[idx]
        out = np.zeros((H, W, 4), np.uint8)
        out[..., :3] = np.clip(self.rgb, 0, 255).astype(np.uint8)
        out[..., 3] = (a * 255).astype(np.uint8)
        out[a <= 0] = 0
        return Image.fromarray(out, "RGBA")


def dilate(m):
    r = m.copy()
    r[1:, :] |= m[:-1, :]
    r[:-1, :] |= m[1:, :]
    r[:, 1:] |= m[:, :-1]
    r[:, :-1] |= m[:, 1:]
    return r


def erode(m):
    return ~dilate(~m)


# ---------------------------------------------------------------- ilkel çizimler

def ring(L, R, th, pal, alpha, cx=0.0, cy=0.0, k=K, angm=None, clip=None, outline=True, edge=CREAM):
    """Dolu bant halka (dış kenar açık, iç kuyruk koyu+saydam). angm(theta)->0..1 kalınlık çarpanı (hilal/yay)."""
    if R <= 0.5 or alpha <= 0:
        return
    dx = XX - cx
    dy = (YY - cy) / k
    d = np.sqrt(dx * dx + dy * dy)
    m = np.ones_like(d)
    if angm is not None:
        m = angm(np.arctan2(dy, dx))
    t = th * m
    band = (d <= R) & (d >= R - t) & (m > 0.04)
    if clip is not None:
        band &= clip
    if not band.any():
        return
    u = (R - d) / np.maximum(t, 1e-6)
    L.over(band & (u >= 0.67), pal[2], down(alpha))
    L.over(band & (u >= 0.34) & (u < 0.67), pal[3], alpha)
    L.over(band & (u < 0.34), edge, alpha)
    if outline:
        ol = dilate(band) & ~band & (d > R - 0.5)
        if clip is not None:
            ol &= clip
        L.over(ol, pal[1], down(alpha, 2))


def gaps(n, phase, thr):
    """thr -1 = tam halka; büyüdükçe n hilale bölünür (uçlar incelerek)."""
    def f(th):
        if thr <= -1:
            return np.ones_like(th)
        if thr >= 0.98:  # tamamen söndü (thr > 1 iken bölen eksi olup halkayı geri getiriyordu)
            return np.zeros_like(th)
        c = np.cos(n * th + phase)
        return np.clip((c - thr) / (1 - thr + 1e-6), 0, 1) ** 0.5
    return f


def window(centers, hw):
    def f(th):
        m = np.zeros_like(th)
        for c in centers:
            dd = np.abs((th - c + math.pi) % (2 * math.pi) - math.pi)
            m = np.maximum(m, np.clip(1 - dd / hw, 0, 1) ** 0.6)
        return m
    return f


def disc(L, rx, pal, alpha, cx=0.0, cy=0.0, k=K, core=True):
    if rx <= 0 or alpha <= 0:
        return
    d = np.sqrt((XX - cx) ** 2 + ((YY - cy) / k) ** 2)
    L.over(d <= rx, pal[3], alpha)
    L.over(d <= rx * 0.66, pal[4], alpha)
    if core:
        L.over(d <= rx * 0.33, CREAM, alpha)


def sparkle(L, x, y, pal, alpha, big=False):
    L.px(x, y, CREAM, alpha)
    if big:
        for ddx, ddy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            L.px(x + ddx, y + ddy, pal[3], down(alpha))


def mote(L, x, y, pal, alpha):
    L.px(x, y, pal[4], alpha)


def comet(L_back, L_front, ang, rx, ry, cy, pal, alpha, n=8, step=0.11, head_big=False):
    for i in range(n, -1, -1):
        a = ang - i * step
        x, y = rx * math.cos(a), cy + ry * math.sin(a)
        L = L_back if math.sin(a) < 0 else L_front
        if i == 0:
            sparkle(L, x, y, pal, alpha, big=True)
            if head_big:
                for ddx, ddy in ((1, 1), (-1, -1), (1, -1), (-1, 1)):
                    L.px(x + ddx, y + ddy, pal[4], down(alpha))
                L.px(x + 2, y, CREAM, down(alpha)); L.px(x - 2, y, CREAM, down(alpha))
        else:
            col = pal[4] if i < 3 else (pal[3] if i < 5 else pal[2])
            al = alpha if i < 3 else (down(alpha) if i < 5 else down(alpha, 2))
            L.px(x, y, col, al)
            if i < 4:
                L.px(x, y + 1, pal[3], down(al))


def kite(L, s, pal, alpha, cx=0.0, cy=-17.0, rim_pal=None, flash=False):
    """Yarı saydam ışık kalkanı (kalkan biçimi + haç), göğüs önünde."""
    if alpha <= 0:
        return
    u = (XX - cx) / (7.5 * s)
    v = (YY - cy) / (9.0 * s)
    wv = np.where(v <= 0.15, 1.0, 1.0 - (v - 0.15) / 0.85)
    wv = np.where(v < -0.8, wv - ((-0.8 - v) / 0.2) * 0.25, wv)
    inside = (v >= -1) & (v <= 1) & (np.abs(u) <= wv)
    rim = inside & ~erode(inside)
    cross = inside & (((np.abs(u) < 0.16) & (v > -0.72) & (v < 0.62)) | ((np.abs(v + 0.22) < 0.13) & (np.abs(u) < 0.62)))
    if flash:
        L.over(inside, CREAM, alpha)
        return
    L.over(inside & ~rim, pal[4], down(alpha))
    L.over(cross, CREAM, alpha)
    rp = rim_pal or pal
    L.over(rim, rp[3], alpha)
    L.over(dilate(inside) & ~inside, rp[1], down(alpha, 2))


def pillar(L, w, hgt, pal, alpha):
    if w <= 0 or alpha <= 0:
        return
    ax = np.abs(XX)
    col = (YY <= 0) & (YY >= -hgt)
    yf = -YY / max(hgt, 1)
    for lo, hi, mul in ((0.0, 0.5, 0), (0.5, 0.72, 1), (0.72, 0.88, 2), (0.88, 1.01, 3)):
        band = col & (yf >= lo) & (yf < hi)
        al = down(alpha, mul)
        L.over(band & (ax <= w + 1), pal[2], down(al))
        L.over(band & (ax <= w), pal[3], al)
        L.over(band & (ax <= w * 0.6), pal[4], al)
        L.over(band & (ax <= w * 0.25), CREAM, al)


# ---------------------------------------------------------------- yardımcı zaman eğrileri

def ease_out(p, e=2.2):
    p = min(max(p, 0.0), 1.0)
    return 1 - (1 - p) ** e


def steps(p, marks=(0.35, 0.6, 0.8)):
    """İlerlemeye göre 1 -> 0,8 -> 0,55 -> 0,3 düz basamak."""
    if p < marks[0]:
        return 1.0
    if p < marks[1]:
        return 0.8
    if p < marks[2]:
        return 0.55
    return 0.3


def fade_in(t, t0, t1):
    if t <= t0:
        return 0.0
    if t >= t1:
        return 1.0
    return q((t - t0) / (t1 - t0))


RNG = np.random.default_rng(7)
SHARDS = [(RNG.uniform(0, 2 * math.pi), RNG.uniform(38, 66), RNG.uniform(55, 85)) for _ in range(10)]
MOTES = [(RNG.uniform(-8, 8), RNG.uniform(0, 0.25)) for _ in range(3)]


# ---------------------------------------------------------------- A Kalkan Darbesi

def a_steady(b, f, t, pal):
    """Kalıcı kısım (1 sn periyot): ayak ışığı + tikte yükselen halka + zerreler. t = yetenek zamanı."""
    fi = fade_in(t, 0.45, 0.7)
    if fi <= 0:
        return
    tl = t % 1.0
    pulse = 1.0 if tl < 0.1 else 0.0
    ring(b, 11 + pulse, 2.6, pal, q(0.55 * fi + 0.25 * pulse), outline=False, edge=pal[4])
    disc(b, 9, pal, q(0.3 * fi), core=False)
    if t >= 0.95:  # tik halkası (ilk tik t=1)
        p = tl / 0.65
        if p < 1:
            h = 24 * ease_out(p, 1.6)
            rx = 11 - 2 * p
            al = q(steps(p, (0.25, 0.5, 0.75)) * fi)
            ring(b, rx, 3.2, pal, al, cy=-h, clip=(YY < -h), outline=False)
            ring(f, rx, 3.2, pal, down(al), cy=-h, clip=(YY >= -h), outline=False)
        for x0, d0 in MOTES:
            p2 = (tl - d0) / 0.75
            if 0 <= p2 < 1:
                mote(f, x0, -2 - 30 * p2, pal, q(steps(p2, (0.4, 0.7, 0.9)) * fi))


def a_cast(b, f, t, pal):
    if t < 0.12:
        disc(b, 5 + 30 * t, pal, 1.0 if t < 0.06 else 0.8)
    p = (t - 0.04) / 0.7
    if 0 <= p < 1:
        R = 8 + 38 * ease_out(p)
        ring(b, R, max(3.2, 6 * (1 - p) + 2.5), pal, steps(p, (0.3, 0.55, 0.75)), angm=gaps(5, 0.3, -1 + 2.4 * max(0.0, p - 0.22) / 0.78))
    p = (t - 0.14) / 0.6
    if 0 <= p < 1:
        ring(b, 6 + 22 * ease_out(p), 3.2, pal, down(steps(p, (0.3, 0.55, 0.75))), angm=gaps(4, 1.1, -1 + 2.4 * max(0.0, p - 0.15) / 0.85), outline=False)
    for ang, sp, vz in SHARDS:
        tt = t - 0.03
        tl = 2 * vz / 260.0
        if 0 <= tt < tl + 0.1:
            tt2 = min(tt, tl)
            r = sp * tt2
            gx, gy = r * math.cos(ang), r * math.sin(ang) * K
            z = max(0.0, vz * tt2 - 130 * tt2 * tt2)
            al = 1.0 if tt < tl * 0.6 else (0.8 if tt < tl else 0.3)
            sparkle(f if gy >= 0 else b, gx, gy - z, pal, al, big=tt < tl * 0.5)
    a_steady(b, f, t, pal)


def a_taunt(b, f, t):
    pal = RED
    p = (t - 0.1) / 0.85
    if 0 <= p < 1:
        ring(b, 12 + 48 * ease_out(p, 1.8), max(3.2, 4.5 * (1 - p) + 2.5), pal, down(steps(p, (0.3, 0.55, 0.75))), angm=gaps(8, 0.0, -1 + 2.4 * max(0.0, p - 0.2) / 0.8))
    for i in range(10):
        ang = i * (2 * math.pi / 10) + 0.31
        p = (t - 0.35 - 0.03 * (i % 3)) / 0.6
        if 0 <= p < 1:
            r0 = 62 - 46 * ease_out(p, 1.4)
            al = down(steps(p, (0.5, 0.75, 0.9)))
            for j in range(7):
                r = r0 + j * 1.1
                col = pal[4] if j < 2 else (pal[3] if j < 4 else pal[2])
                b.px(r * math.cos(ang), r * math.sin(ang) * K, CREAM if j == 0 else col, al if j < 4 else down(al))



def render(fn, n, t0=0.0, **kw):
    backs, fronts = [], []
    for i in range(n):
        b, f = Layer(), Layer()
        fn(b, f, t0 + i / FPS, **kw)
        backs.append(b.image())
        fronts.append(f.image())
    return backs, fronts


def crop_box(frames):
    x0, y0, x1, y1 = W, H, 0, 0
    for fr in frames:
        bb = fr.getbbox()
        if bb:
            x0, y0, x1, y1 = min(x0, bb[0]), min(y0, bb[1]), max(x1, bb[2]), max(y1, bb[3])
    hw = max(OX - x0, x1 - OX) + 1
    return (OX - hw, max(0, y0 - 1), OX + hw, min(H, y1 + 1))


def save(name, frames, box, loop):
    cw, ch = box[2] - box[0], box[3] - box[1]
    s = Image.new("RGBA", (cw * len(frames), ch), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        s.paste(fr.crop(box), (i * cw, 0))
    s.save(os.path.join(OUT, name + "_sheet.png"))
    write_sprite_frames(os.path.join(OUT, name + "_frames.tres"), RES + name + "_sheet.png", cw, ch,
                        [("play", (0, 0), len(frames), loop, FPS)])


def main():
    clips = {
        "q_cast": (render(a_cast, FPS, 0.0, pal=BLUE), False),
        "q_loop": (render(a_steady, FPS, 1.0, pal=BLUE), True),  # t 1..2: kare 0 = her saniyenin tiki
        "q_taunt": (render(lambda b, f, t: a_taunt(b, f, t), int(FPS * 1.2)), False),
    }
    for name, ((backs, fronts), loop) in clips.items():
        has_front = any(fr.getbbox() for fr in fronts)
        box = crop_box(backs + (fronts if has_front else []))
        save(name + "_back", backs, box, loop)
        if has_front:
            save(name + "_front", fronts, box, loop)
        print('%s: kare %dx%d x%d, köken (ayak) kırpılmış karede Vector2(%d, %d), ön katman: %s' % (
            name, box[2] - box[0], box[3] - box[1], len(backs), OX - box[0], OY - box[1], has_front))


if __name__ == "__main__":
    main()
