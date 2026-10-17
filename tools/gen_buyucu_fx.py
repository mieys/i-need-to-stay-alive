"""Büyücü Kız efekt sayfaları (madde 188; kullanıcı prototipleri onayladı: "meteor efekti eskisi gibi olsun ... diğerleri harika").
Çizimler onaylanan prototipten: tools/proto_20261016/gen_buyucu_buyu.py (mote/grimoire/eye/base_swirl + pixfx). MEKANİK AYNI.
Çıktı assets/fx/buyucu/<ad>.png - yatay şerit (Sprite2D hframes), scripts/buyucu_fx.gd SHEETS ile aynı adlar/kare sayıları.
1 sayfa pikseli = 1 Büyücü sanat pikseli (0,903 dünya). KARAKTERE BAĞLI sayfalarda (q_*, hortum_cast, surge_wave) karenin merkezi =
karakterin 48x48 karesinin merkezi (BuyucuFx.char_layer AnimatedSprite2D'nin konum/offset/ölçeğini kopyalar); ayak satırı = merkez + 16.
Kullanım (proje kökünden): python -I tools/gen_buyucu_fx.py [onizleme.png]   -> sonra Godot --headless --path . --import
"""
import math
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..'))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, 'proto_20261016'))
sys.path.insert(0, os.path.join(HERE, 'proto_20261012'))
import pixfx as P  # noqa: E402
import gen_buyucu_buyu as B  # noqa: E402

OUT = os.path.join(PROJECT, 'assets', 'fx', 'buyucu')
TAU = math.tau
ARC, HEX, HOR = B.ARC, B.HEX, B.HOR


def strip_png(name, frames):
    w, h = frames[0].w, frames[0].h
    im = Image.new('RGBA', (w * len(frames), h))
    for i, cv in enumerate(frames):
        im.paste(cv.image(), (i * w, 0))
    im.save(os.path.join(OUT, name + '.png'))
    return name, len(frames), w, h


# ====================================================================== Q - Büyü Değişimi (karaktere bağlı, 64x64, 15 fps)
QW = QH = 64
QX, QFEET = 32, 48  ## kare merkezi = karakter karesinin merkezi -> ayak = 32 + 16


def q_frames(old, new):
    """prototip scene_q'nun bir değişimi (k 0..20): back = yer halkası + arkadaki zerreler, front = öndeki zerreler + kitap."""
    ex, feet = QX, QFEET
    ocx, ocy, ORX, ORY = ex, feet - 13, 15.0, 5.0
    bx, by = ex + 14, feet - 22
    pal_new, pal_old = B.SET_PAL[new], B.SET_PAL[old]
    backs, fronts = [], []
    for k in range(21):
        back, front, top = P.Canvas(QW, QH), P.Canvas(QW, QH), P.Canvas(QW, QH)
        kk = k - 4
        if 0 <= kk < 8:
            r = 8.0 + 14.0 * P.ease_out(kk / 8.0)
            P.shock_ring(back, ex, feet, r, 2.4, kk / 8.0, pal_new, 0.5, seed=6 + new, break_from=0.4)
            if kk < 3:
                for q in range(6):
                    a = q * TAU / 6 + kk * 0.4
                    back.px(ex + math.cos(a) * (r + 3), feet + math.sin(a) * (r + 3) * 0.5, pal_new[4])
        a = k * 0.45 + 1.3
        if k < 4:
            t = B.ease_in((k + 1) / 4.5)
            for j, kind in enumerate(B.SET_PAIR[old]):
                aj = a + j * math.pi
                ox, oy = ocx + math.cos(aj) * ORX * (1 - t), ocy + math.sin(aj) * ORY * (1 - t)
                B.mote(front if (math.sin(aj) > 0 or t > 0.4) else back, kind, P.lerp(ox, bx, t), P.lerp(oy, by, t), k)
        elif k < 20:
            grow = P.ease_out(min(1.0, (k - 4) / 3.0))
            rise = max(0, k - 14) * 1.6
            mb, mf = P.Canvas(QW, QH), P.Canvas(QW, QH)
            for j, kind in enumerate(B.SET_PAIR[new]):
                aj = a + j * math.pi
                ox, oy = ocx + math.cos(aj) * ORX, ocy + math.sin(aj) * ORY - rise
                tgt = mf if math.sin(aj) > 0 else mb
                for tr in (1, 2):
                    ap = aj - tr * 0.45
                    tgt.px(P.lerp(bx, ocx + math.cos(ap) * ORX, grow), P.lerp(by, ocy + math.sin(ap) * ORY - rise, grow), pal_new[3 if tr == 1 else 2])
                B.mote(tgt, kind, P.lerp(bx, ox, grow), P.lerp(by, oy, grow), k)
            if k >= 15:
                B.fade_cv(mf, 1.0 - (k - 14) / 6.0)
                B.fade_cv(mb, 1.0 - (k - 14) / 6.0)
            for src, dst in ((mb, back), (mf, front)):
                m = src.filled()
                dst.rgba[m] = src.rgba[m]
        if k == 0:
            B.grimoire(top, bx, by, 0.0, [], pal_new)
            P.star(top, bx, by - 6, 2, P.WHITE, ARC[3])
        elif 1 <= k <= 9:
            pages = [((k - 1 - i) + 1) / 3.0 for i in range(3) if 0 <= k - 1 - i < 2]
            B.grimoire(top, bx, by, 1.0, pages, pal_new if k >= 3 else pal_old)
            if k == 4:
                P.disc_flash(top, bx, by - 1, 5.0, core=P.CREAM, rim=pal_new[4])
                P.star(top, bx, by - 1, 7, P.WHITE, pal_new[3], diag=True)
            elif k == 5:
                P.star(top, bx, by - 1, 4, pal_new[4], pal_new[3])
        elif k == 10:
            B.grimoire(top, bx, by, 0.0, [], pal_new)
        elif 11 <= k <= 13:
            u = (k - 11) / 3.0
            P.puffs(top, [(bx - 2, by, 3.2 * (1 - u * 0.5)), (bx + 2, by - 1, 2.8 * (1 - u * 0.5))], ARC,
                    cut=[(bx + 1.5, by - 2, 2.5 * u + 0.5)] if u > 0 else None)
        m = top.filled()
        front.rgba[m] = top.rgba[m]
        backs.append(back)
        fronts.append(front)
    return backs, fronts


# ====================================================================== Arcane Lanet (dünyada, 20 fps)
def lanet_sheets():
    out = []
    eyes = []
    for d in range(16):  ## 16 yön: kare d = açı d * 22,5 derece (0 = sağa)
        cv = P.Canvas(16, 16)
        B.eye(cv, 8, 8, d * TAU / 16, 1.0)
        eyes.append(cv)
    out.append(strip_png('lanet_eye', eyes))
    cast = []
    for k in range(3):  ## elde (ilk kalkış noktasında) belirip kırılan lanet mührü
        cv = P.Canvas(24, 24)
        P.ring_band(cv, 12, 12, 5.0 + k, 1.4, HEX, gaps=[(k * 0.8, k * 0.8 + 0.9), (k * 0.8 + 3.1, k * 0.8 + 4.0)])
        if k == 0:
            P.disc_flash(cv, 12, 12, 2.5, core=P.CREAM, rim=HEX[4])
            P.star(cv, 12, 12, 4, P.WHITE, HEX[3], diag=True)
        cast.append(cv)
    out.append(strip_png('lanet_cast', cast))
    out.append(strip_png('lanet_burst', [_burst(32, 9.0, k / 7.0, HEX, 7) for k in range(7)]))
    brand = []
    for k in range(12):  ## yaratığın ayağına basılan 2:1 lanet mührü
        cv = P.Canvas(40, 24)
        R = 10.0
        P.shock_ring(cv, 20, 12, R * (1.08 - 0.08 * min(k, 3) / 3.0), 1.8, k / 12.0, HEX, 0.5, seed=3.0, break_from=0.45)
        if k < 7:
            for q in range(4):
                aq = q * TAU / 4 + 0.3 + k * 0.18
                for d in (R + 2.0, R + 3.0):
                    cv.px(20 + math.cos(aq) * d, 12 + math.sin(aq) * d * 0.5, HEX[3] if k < 4 else HEX[2])
        if k < 2:
            P.disc_flash(cv, 20, 12, 4.0, core=HEX[4], rim=HEX[3], squash=0.5)
        brand.append(cv)
    out.append(strip_png('lanet_brand', brand))
    return out


def _burst(size, R, t, pal, seed):
    cv = P.Canvas(size, size)
    P.burst(cv, size / 2, size / 2, R, t, pal, P.SMOKE if pal is HOR else P.SHADOW, seed=seed, n_puffs=6)
    return cv


# ====================================================================== Hortum (dünyada, 15 fps, kusursuz döngü)
HN = 28  ## döngü kare sayısı - bütün fazlar bu sürede tam tur atar
TW, TH, TGROUND = 48, 72, 64  ## zemin satırı 64 (düğüm orijini)


def tornado_frame(cv, x, gy, f, h, sc=1.0, cut=0.0):
    """Prototip B.tornado'nun DÖNGÜLÜ hali: her faz HN karede tam sayıda tur (eğilme 1, bant 6, yırtık kenar 8/10, kırıntı 4, tutam 3)."""
    import numpy as np
    if h < 2:
        return
    ph = TAU * f / HN
    X, Y = cv.grid()
    base_y = gy - 2.0
    r0, r1 = 2.2 * sc, 13.0 * sc

    def rad(s):
        return r0 + (r1 - r0) * np.clip(s, 0, 1) ** 1.25

    def sway(s):
        return 3.5 * sc * np.clip(s, 0, 1) ** 1.4 * np.sin(ph + s * 2.4)

    s = (base_y - Y) / h
    xc = x + sway(s)
    rr = rad(s) * (1.0 + 0.1 * np.sin(s * 22.0 - ph * 8)) + 0.6 * np.sin(s * 37.0 + ph * 10)
    body = (s >= cut) & (s <= 1.0) & (np.abs(X - xc) <= rr)
    xt, top_y, ryr = x + float(sway(1.0)), base_y - h, r1 * 0.32
    rim = ((X - xt) / r1) ** 2 + ((Y - top_y) / ryr) ** 2 <= 1.0
    mouth = ((X - xt) / max(r1 - 2.2, 0.5)) ** 2 + ((Y - top_y + 0.4) / max(ryr - 1.1, 0.5)) ** 2 <= 1.0

    def bits(front):
        for q in range(5):
            a = ph * 4 + q * 1.9
            sq = (f / HN + q * 0.21) % 1.0
            if sq < cut or (math.cos(a) > 0) != front:
                continue
            yy = base_y - sq * h
            xx = x + float(sway(sq)) + (float(rad(sq)) + 1.5) * math.sin(a)
            if q < 3:
                cv.px(xx, yy, ARC[4] if front else ARC[2])
                if front:
                    cv.px(xx - 1, yy, ARC[3])
                    cv.px(xx + 1, yy, ARC[3])
            elif q == 3:
                cv.px(xx, yy, B.LEAF[3] if front else B.LEAF[1])
                cv.px(xx + 1, yy - 1, B.LEAF[2] if front else B.LEAF[1])
            else:
                cv.px(xx, yy, P.STONE[3] if front else P.STONE[1])

    bits(False)
    u = np.clip((X - xc) / np.maximum(rr, 0.5), -1, 1)
    th = np.arcsin(u)
    band = s * 13.0 - ph * 6
    stripe = np.sin(th * 2.0 + band)
    gap = body & (stripe < -0.4) & (s < 0.9)
    front = (body & ~gap) | rim
    cv.put(gap & (np.sin((math.pi - th) * 2.0 + band) > -0.1), HOR[1])
    tone = np.where(u < -0.35, 3, np.where(u > 0.6, 1, 2))
    tone = np.where(stripe > 0.55, np.minimum(tone + 1, 4), tone)
    tone = np.where(rim & ~body, 3, tone)
    for tt in range(1, 5):
        cv.put(front & (tone == tt), HOR[tt])
    cv.put(mouth & ~body | (mouth & (Y < top_y)), HOR[1])
    cv.put(P.outline_of(front) & ~front & ~(mouth & rim), HOR[0])
    for side in (-1, 1):
        a0 = ph * 3 + (0 if side > 0 else math.pi)
        P.arc_band(cv, xt + side * (r1 + 1.5), top_y - 1.0, 3.2 * sc, a0, a0 + 2.6, 1.6, 0.5, HOR)
    bits(True)


def swirl_frame(cv, x, gy, f, sc=1.0, level=1.0):
    if level < 0.25:
        return
    for j in (0, 1):
        a0 = TAU * f / HN * 3 + j * math.pi
        P.arc_band(cv, x, gy, 8.0 + 3.0 * sc, a0, a0 + 2.3, 2.2 * level, 0.6, P.DUST, squash=0.45)


def hortum_sheets():
    x, gy = TW / 2, TGROUND
    loop, grow, out = [], [], []
    for f in range(HN):
        cv = P.Canvas(TW, TH)
        swirl_frame(cv, x, gy, f)
        tornado_frame(cv, x, gy, f, B.HMAX)
        loop.append(cv)
    for i in range(6):  ## doğuş: küçük girdaptan huniye; faz döngünün sonuna denk gelir -> döngüye dikişsiz geçer
        g = P.ease_out((i + 1) / 6.0)
        f = HN - 6 + i
        cv = P.Canvas(TW, TH)
        swirl_frame(cv, x, gy, f, (i + 1) / 6.0)
        tornado_frame(cv, x, gy, f, B.HMAX * g, sc=0.55 + 0.45 * g)
        grow.append(cv)
    for i in range(12):  ## bitiş: alttan çözülüp yükselir, seyrelir
        u = i / 12.0
        tv, cv = P.Canvas(TW, TH), P.Canvas(TW, TH)
        swirl_frame(cv, x, gy, i, 1.0, 1.0 - u)
        tornado_frame(tv, x, gy - u * 10.0, i, B.HMAX, cut=u * 0.9)
        B.fade_cv(tv, 1.0 - u * 0.85)
        m = tv.filled()
        cv.rgba[m] = tv.rgba[m]
        out.append(cv)
    res = [strip_png('hortum_loop', loop), strip_png('hortum_in', grow), strip_png('hortum_out', out)]
    cast = []
    for k in range(5):  ## ayak altında açılan girdap (karaktere bağlı 64x64)
        cv = P.Canvas(QW, QH)
        kk = k / 5.0
        for j in (0, 1):
            a0 = k * 0.8 + j * math.pi
            P.arc_band(cv, QX, QFEET, 8.0 + 6.0 * kk, a0, a0 + 2.4, 2.2 * (1 - kk * 0.6), 0.6, HOR, squash=0.45)
        cast.append(cv)
    res.append(strip_png('hortum_cast', cast))
    hit = []
    for k in range(4):  ## temas: yaratığın gövdesinde rüzgâr kesikleri
        cv = P.Canvas(40, 40)
        for q in (0, 1):
            a0 = k * 1.1 + q * math.pi
            P.arc_band(cv, 20, 20, 10.0 + k, a0, a0 + 1.6, 2.0 * (1 - k / 4.0) + 0.4, 0.5, HOR)
        if k == 0:
            P.star(cv, 20, 19, 4, P.WHITE, HOR[3], diag=True)
        hit.append(cv)
    res.append(strip_png('hortum_hit', hit))
    return res


# ====================================================================== Pasif - Büyü Dalgası
SW, SFEET = 128, 80  ## 128x128, merkez = karakter karesinin merkezi -> ayak 64 + 16
ORIGIN_UP = 15.5  ## karakter düğümü merkezi ayaktan bu kadar yukarıda (prototip ile aynı)


def surge_sheets():
    wave = []
    for k in range(6):
        cv = P.Canvas(SW, SW)
        P.shock_ring(cv, SW / 2, SFEET, 6.0 + 18.0 * P.ease_out(k / 6.0), 2.0, k / 6.0, ARC, 0.5, seed=16, break_from=0.4)
        if k < 5:
            P.shock_ring(cv, SW / 2, SFEET - ORIGIN_UP - 14, 8.0 + 52.0 * P.ease_out((k + 1) / 5.0), 2.2, k / 5.0, ARC, 0.78,
                         seed=17, break_from=0.45)
        wave.append(cv)
    muzzle = []
    for k in range(2):
        cv = P.Canvas(16, 16)
        if k == 0:
            P.disc_flash(cv, 8, 8, 3.0, core=P.CREAM, rim=ARC[4])
            P.star(cv, 8, 8, 5, P.WHITE, ARC[3], diag=True)
        else:
            P.star(cv, 8, 8, 2, P.CREAM, ARC[3])
        muzzle.append(cv)
    return [strip_png('surge_wave', wave), strip_png('surge_muzzle', muzzle),
            strip_png('surge_hit', [_burst(32, 10.0, k / 7.0, ARC, 5) for k in range(7)])]


# ====================================================================== R Meteor Patlaması (kullanıcı 2026-10-17: "sadece havaya uçma
# geliştirmesi eskisi gibi olsun ... yeni hazırladığın meteorlar iyiydi onlar kalsın") - prototip scene_r
FIRE = P.FIRE
RW, RH = 80, 72  ## kanal çemberi: karaktere bağlı, merkez = karakter karesinin merkezi -> ayak 36 + 16
RX, RFEET = 40, 52
R0 = 22.0
RCH = 45  ## 3 sn kanal = 45 kare (oyunda fps = 45 / kanal süresi)
EW, EH = 48, 112  ## korlar: merkez (24, 56) = karakter karesinin merkezi


def meteor_sheets():
    res = []
    ring = []
    dim = [ARC[0], ARC[1], ARC[1], ARC[2], ARC[2]]
    for k in range(RCH):  ## soluk halka + 3 sn'de dolan ateş yayı + dönen rün çentikleri (ilerlemeye göre yanar)
        cv = P.Canvas(RW, RH)
        p = (k + 1) / RCH
        R = R0 * (0.4 + 0.6 * P.ease_out(min(1.0, (k + 1) / 4.0)))
        P.ring_band(cv, RX, RFEET, R, 2.0, dim, squash=0.5)
        P.arc_band(cv, RX, RFEET, R + 0.2, -math.pi / 2, -math.pi / 2 + p * TAU * 0.999, 2.6, 2.2, FIRE, squash=0.5, round_head=False)
        for q in range(6):
            a = q * TAU / 6 + k * 0.08
            lit = ((a + math.pi / 2) % TAU) / TAU < p
            for d in (R - 4.0, R - 5.0):
                cv.px(RX + math.cos(a) * d, RFEET + math.sin(a) * d * 0.5, FIRE[3] if lit else ARC[2])
        ring.append(cv)
    res.append(strip_png('r_ring', ring))
    end = []
    for k in range(7):  ## kanal biter: çember parlayıp parçalanır
        cv = P.Canvas(RW, RH)
        kk = k / 7.0
        P.shock_ring(cv, RX, RFEET, R0 + 10.0 * P.ease_out(kk), 2.6, kk, FIRE, 0.5, seed=3, break_from=0.2)
        if k == 0:
            P.disc_flash(cv, RX, RFEET - 1, 5.0, core=P.CREAM, rim=FIRE[4], squash=0.5)
        end.append(cv)
    res.append(strip_png('r_ring_end', end))
    import random as _r
    tip = (EW / 2 + B.HAT_DX, EH / 2 + B.HAT_DY + 16)
    embers = []
    for f in range(20):  ## şapka ucundan göğe yükselen korlar (20 karede dikişsiz döngü)
        cv = P.Canvas(EW, EH)
        P.star(cv, tip[0], tip[1] - 1, 1 + (f // 2) % 2, FIRE[4], FIRE[3])
        for born in range(f - 9, f + 1):
            if born % 2:
                continue
            age = f - born
            r2 = _r.Random(born % 20)
            x = tip[0] + r2.uniform(-2.5, 2.5) + math.sin(age * 0.7 + (born % 20)) * 1.5
            y = tip[1] - 2 - age * 2.4
            cv.px(x, y, FIRE[4] if age < 2 else (FIRE[3] if age < 5 else FIRE[2]))
            if age < 3:
                cv.px(x, y + 1, FIRE[2])
        embers.append(cv)
    res.append(strip_png('r_embers', embers))
    fall = []
    for f in range(4):  ## korlu kaya + alev kuyruğu (yön sabit: fx_meteor_strike (-120, -420)'den düşer); kaya karede (24, 38)
        cv = P.Canvas(48, 48)
        B.meteor(cv, 24, 38, f, 1.7)
        fall.append(cv)
    res.append(strip_png('meteor_fall', fall))
    warn = []
    for dt in range(7):  ## düşüş boyunca: büyüyen gölge + daralan uyarı halkası
        cv = P.Canvas(32, 20)
        t = (dt + 1) / 7.0
        X, Y = cv.grid()
        rx = 2.0 + 7.0 * t
        ry = rx * 0.4
        cv.put(((X - 16) / rx) ** 2 + ((Y - 10) / ry) ** 2 <= 1.0, (24, 16, 20), 100)
        P.ring_band(cv, 16, 10, 13.0 - 6.0 * t, 1.3, [FIRE[0], FIRE[1], FIRE[2], FIRE[2], FIRE[3]], squash=0.5)
        warn.append(cv)
    res.append(strip_png('meteor_warn', warn))
    burst = []
    for k in range(10):  ## isabet: dolu patlama + savrulan kaya parçaları (zemin noktası karede (32, 32))
        cv = P.Canvas(64, 64)
        P.burst(cv, 32, 28, 16.0, k / 10.0, FIRE, P.SMOKE, seed=17, n_puffs=8, squash=0.8)
        if k >= 1:
            for q in range(6):
                a = q * TAU / 6 + 1.7
                x = 32 + math.cos(a) * 3.0 * k
                y = 28 + math.sin(a) * 1.2 * k - 4.0 * k + 0.55 * k * k
                if y < 34:
                    P.chunk(cv, x, y, 2, B.ROCK)
        burst.append(cv)
    res.append(strip_png('meteor_burst', burst))
    ring2 = []
    for k in range(4):  ## hasar yarıçapında (BUYUCU_METEOR_IMPACT_RADIUS 70 dünya) ince, hızlı şok halkası
        cv = P.Canvas(164, 84)
        P.shock_ring(cv, 82, 42, 10.0 + (B.IMPACT_R - 10.0) * P.ease_out((k + 1) / 4.0), 1.3, k / 4.0, P.EMBER, 0.5, seed=1.7,
                     break_from=0.25)
        ring2.append(cv)
    res.append(strip_png('meteor_ring', ring2))
    crater = []
    for i in range(20):  ## soğuyan krater izi (7,5 fps, ~2,7 sn)
        cv = P.Canvas(24, 12)
        B.crater(cv, 12, 6, 1 + 2 * i, 17)
        crater.append(cv)
    res.append(strip_png('meteor_crater', crater))
    return res


def main():
    os.makedirs(OUT, exist_ok=True)
    made = []
    for new in (0, 1):  ## q_*_<hedef set>: 0 = Set 1'e (soğuk) geçiş, 1 = Set 2'ye (sıcak) geçiş
        backs, fronts = q_frames(1 - new, new)
        made.append(strip_png('q_back_%d' % new, backs))
        made.append(strip_png('q_front_%d' % new, fronts))
    made += lanet_sheets()
    made += hortum_sheets()
    made += surge_sheets()
    made += meteor_sheets()
    for (n, c, w, h) in made:
        print('%-14s %2d kare  %dx%d' % (n, c, w, h))
    if len(sys.argv) > 1:  ## önizleme: her sayfa bir satır, x3
        rows = [Image.open(os.path.join(OUT, n + '.png')) for (n, _, _, _) in made]
        W = max(r.width for r in rows)
        H = sum(r.height + 2 for r in rows)
        pv = Image.new('RGBA', (W, H), (126, 176, 84, 255))
        y = 0
        for r in rows:
            pv.alpha_composite(r, (0, y))
            y += r.height + 2
        pv.resize((W * 2, H * 2), Image.NEAREST).save(sys.argv[1])


if __name__ == '__main__':
    main()
