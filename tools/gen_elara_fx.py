"""Elara Q/E/R efekt sayfaları (2026-10-16, madde 178). Çizimler onaylanan prototipten (tools/proto_20261016/gen_elara_nisanci.py)
birebir alınır; burada sadece karakter merkezine göre sabit karelere dökülür.
Her sayfa yatay şerit (hframes = kare sayısı); karenin MERKEZİ = karakter düğümünün orijini (Elara sprite'ının offset'i dahil:
ayak = merkez + 14,2 sanat pikseli). 1 sayfa pikseli = 1 Elara sanat pikseli (oyunda sprite ölçeği = Elara'nın AnimatedSprite2D
ölçeği, bkz. scripts/elara_fx.gd). Kare hızı 16 fps (prototiplerle aynı).
Çıktı: assets/fx/elara/<ad>.png (+ kare sayıları scripts/elara_fx.gd SHEETS ile aynı olmalı - aşağıdaki NAMES).
Kullanım (proje kökünden): python -I tools/gen_elara_fx.py
"""
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..'))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, 'proto_20261016'))
import pixfx as P  # noqa: E402
import gen_elara_nisanci as E  # noqa: E402

OUT = os.path.join(PROJECT, 'assets', 'fx', 'elara')
os.makedirs(OUT, exist_ok=True)

CW, CH = 128, 128  ## çizim tuvali (sonra merkezden simetrik kırpılır)
OX, OY = CW // 2, CH // 2  ## karakter orijini
FEET = OY + 14.2  ## prototipteki "feet" koordinatı (ayak satırının üst kenarı)
EX = OX
FRAMES = {}


def canvas():
    return P.Canvas(CW, CH)


# ---------------------------------------------------------------- Q - Sıvışma
def q_cast():
    """Dünyada sabit: yere yatık rüzgâr girdabı (6 kare) + iki yana toz (1-4) + 3 savrulan tüy (0-8) + krem artı (0). Sağa koşu için
    çizildi; sola koşarken kod yatay aynalar."""
    out = []
    for i in range(9):
        cv = canvas()
        if i <= 5:
            k = i / 6.0
            for j in (0, 1):
                E.crescent(cv, EX, FEET, 11.0 + 10.0 * P.ease_out(k), 3.2 * (1 - k) + 0.8, j * math.pi + k * 3.0, 1.3,
                           P.break_mult(cv, EX, FEET, 0.5, (k - 0.45) / 0.55, 4) if k > 0.45 else None, squash=0.5)
        if 1 <= i <= 4:
            E.dust(cv, EX - 4, FEET, (i - 1) / 4.0, 1, seed=1)
        age = i / 8.0
        for j, (vx, vy, a0) in enumerate(((-9, -13, 2.4), (-14, -6, 2.9), (-5, -18, 2.0))):
            E.feather(cv, EX + vx * P.ease_out(age) - 2 * j, FEET - 14 + vy * P.ease_out(age) + age * 6,
                      a0 + age * 1.5 * (1 if j % 2 else -1), age)
        if i == 0:
            P.star(cv, EX, FEET - 16, 4, P.WHITE, E.RUZ[3])
        out.append(cv)
    return out


def q_end():
    """Dünyada sabit bitiş esintisi: koşunun tersine savrulan hilal, parçalanır (sağa koşu için; sola aynalanır)."""
    out = []
    for i in range(5):
        cv = canvas()
        k = i / 5.0
        E.crescent(cv, EX + 2, FEET, 9.0 + 9.0 * k, 3.0 * (1 - k) + 0.7, math.pi, 1.1,
                   P.break_mult(cv, EX + 2, FEET, 0.5, k, 6) if k > 0.3 else None, squash=0.5)
        out.append(cv)
    return out


# ---------------------------------------------------------------- E - Gerçek Hasar (odak)
E_ROT = (math.pi / 2) / 10.0  ## halka 10 karede bir simetri turu (4 parçalı) -> 10 karelik kusursuz döngü


def e_cast():
    """Üst katman: 4 kehribar parantez dönerek kapanır (0-5), krem kilit (6), sönen kilit (7); gözde parıltı (5-7)."""
    out = []
    cy = FEET - 17
    for i in range(8):
        cv = canvas()
        if i < 6:
            e = P.ease_out(min(1.0, i / 5.0))
            E.reticle(cv, EX, cy, 30.0 - 13.0 * e, (1 - e) * math.pi / 2)
        else:
            E.reticle(cv, EX, cy, 16.0 + (i - 6) * 2, 0.0, col=E.CREAM if i == 6 else E.AMB[4])
        if i >= 5:
            P.star(cv, EX + 3, FEET - 25, (2, 3, 1)[i - 5], P.WHITE, E.AMB[3], diag=i == 6)
        out.append(cv)
    return out


def _ring(cv, rot, radius):
    gaps = [(rot + q * math.pi / 2 - 0.2, rot + q * math.pi / 2 + 0.2) for q in range(4)]
    P.ring_band(cv, EX, FEET, radius, 2.2, E.AMB, squash=0.5, gaps=gaps)


def e_ring_in():
    out = []
    for i in range(3):
        cv = canvas()
        _ring(cv, i * E_ROT, 10.0 + 6.0 * P.ease_out((i + 1) / 3.0))
        out.append(cv)
    return out


def e_ring_loop():
    out = []
    for i in range(10):
        cv = canvas()
        _ring(cv, (3 + i) * E_ROT, 16.0)
        out.append(cv)
    return out


def e_ring_out():
    out = []
    for i in range(5):
        cv = canvas()
        k = i / 5.0
        P.ring_band(cv, EX, FEET, 16.0 + 4.0 * k, 2.2 * (1 - k) + 0.6, E.AMB, squash=0.5, mult=P.break_mult(cv, EX, FEET, 0.5, k, 7))
        out.append(cv)
    return out


def e_chev():
    """Omuzlardan sırayla yükselen hız okları: 0-4 sol omuz, 5-9 sağ omuz (10 karelik döngü)."""
    out = []
    for i in range(10):
        cv = canvas()
        side = -1 if i < 5 else 1
        E.chevron(cv, EX + side * 8, FEET - 22, (i % 5) / 5.0)
        out.append(cv)
    return out


# ---------------------------------------------------------------- R - Çift Tetik
TOP = (EX, FEET - 44)
ORX, ORY = 17.0, 7.0
OCY = FEET - 12
R_STEP = math.tau / 15.0  ## ikiz oklar 15 karede bir tur


def r_cast_top():
    """Başın üstünde çapraz (X) iki rüzgâr oku + krem parlama; son karede oklar sönmeye başlar (yörüngeye iner)."""
    out = []
    for k in range(5):
        cv = canvas()
        spread = (0.0, 2.0, 3.0, 3.0, 3.0)[k]
        br = 0.6 if k == 4 else 0.0
        for (ad, sd) in ((-math.pi / 4, 1), (-3 * math.pi / 4, 2)):
            d = 8.0 + spread
            E.arrow(cv, TOP[0] + math.cos(ad) * d, TOP[1] + math.sin(ad) * d, ad, broken=br, seed=sd)
        if k <= 1:
            P.disc_flash(cv, TOP[0], TOP[1], (4.0, 2.5)[k], core=E.CREAM, rim=E.RUZ[4])
            P.star(cv, TOP[0], TOP[1], (7, 4)[k], P.WHITE, E.RUZ[3], diag=k == 0)
        out.append(cv)
    return out


def r_cast_ring():
    out = []
    for i in range(6):
        cv = canvas()
        k = i / 6.0
        P.shock_ring(cv, EX, FEET, 9.0 + 12.0 * P.ease_out(k), 2.6, k, E.RUZ, 0.5, seed=21, break_from=0.35)
        out.append(cv)
    return out


def _wisps(a, cy, rx, ry, brk):
    back, front = canvas(), canvas()
    for j in (0, 1):
        aj = a + j * math.pi
        E.wisp(front if math.sin(aj) > 0 else back, EX, cy, aj, rx, ry, 1, trail=0.95, broken=brk, seed=j * 2.0)
    return back, front


def r_wisps():
    """Bel çevresinde karşılıklı dönen iki rüzgâr oku: giriş (başın üstünden sarmal iniş, 3), döngü (15), çıkış (dışa savrulma, 6).
    Arka katman Elara'nın arkasında, ön katman önünde çizilir. Çıkış döngünün 0. karesine denk gelen açıdan başlar."""
    res = {}
    for name, n in (('in', 3), ('loop', 15), ('out', 6)):
        b_list, f_list = [], []
        for i in range(n):
            if name == 'in':
                k = (i + 1) / 3.0
                a = i * R_STEP
                cy = TOP[1] + (OCY - TOP[1]) * P.ease_out(k)
                bk, fr = _wisps(a, cy, ORX * k, ORY * k, 0.0)
            elif name == 'loop':
                bk, fr = _wisps((3 + i) * R_STEP, OCY, ORX, ORY, 0.0)
            else:
                k = i / 6.0
                bk, fr = _wisps((18 + i) * R_STEP, OCY - 4 * k, ORX * (1 + 0.8 * k), ORY * (1 + 0.8 * k), k)
            b_list.append(bk)
            f_list.append(fr)
        res['r_wisp_back_' + name] = b_list
        res['r_wisp_front_' + name] = f_list
    return res


# ---------------------------------------------------------------- kaydet
def save_strip(name, frames):
    arrs = [cv.rgba for cv in frames]
    alpha = np.zeros((CH, CW), dtype=bool)
    for a in arrs:
        alpha |= a[:, :, 3] > 0
    if not alpha.any():
        raise SystemExit('bos sayfa: ' + name)
    ys, xs = np.nonzero(alpha)
    hw = max(OX - xs.min(), xs.max() + 1 - OX) + 1
    hh = max(OY - ys.min(), ys.max() + 1 - OY) + 1
    if xs.min() == 0 or ys.min() == 0 or xs.max() == CW - 1 or ys.max() == CH - 1:
        raise SystemExit('tuval kenarina degiyor: ' + name)
    w, h = hw * 2, hh * 2
    strip = Image.new('RGBA', (w * len(arrs), h))
    for i, a in enumerate(arrs):
        im = Image.fromarray(a, 'RGBA').crop((OX - hw, OY - hh, OX + hw, OY + hh))
        strip.paste(im, (i * w, 0))
    strip.save(os.path.join(OUT, name + '.png'))
    FRAMES[name] = (len(arrs), w, h)


def main():
    save_strip('q_cast', q_cast())
    save_strip('q_end', q_end())
    save_strip('e_cast', e_cast())
    save_strip('e_ring_in', e_ring_in())
    save_strip('e_ring_loop', e_ring_loop())
    save_strip('e_ring_out', e_ring_out())
    save_strip('e_chev', e_chev())
    save_strip('r_cast_top', r_cast_top())
    save_strip('r_cast_ring', r_cast_ring())
    for name, frames in r_wisps().items():
        save_strip(name, frames)
    for k in sorted(FRAMES):
        print('%-20s %2d kare  %dx%d' % ((k,) + FRAMES[k]))


if __name__ == '__main__':
    main()
