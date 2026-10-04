"""Buyucu Kiz yetenek evrimleri + yeni Don Nova (2026-10-04) - pixel-art sprite sayfalari -> assets/fx/evolution/

Kullanici istegi: "bazilari icin ozel efekt gerekiyor ornegin gokyuzune ucus veya yavaslatma icin yaratiklarin hafif mavimsi ve
donuyormus gibi gorunmesi gibi. (donma efekti oyunda zaten mevcut onu yapmana gerek yok)". Dil: tools/pixfx.py (ici dolu golgeli
kutleler, 5 ton rampa, 1 px koyu kontur, krem parlama, hilale asinarak sonme - hafiza "FX texel density + soft ends"); her sayfa
oyundaki boyutunda cizilir (1 sanat pikseli = 1.212 birim, sahnede olcek ~1). Kayit gen_enchant_fx.py gibi: genis tuvalde (PAD)
cizilip merkez korunarak simetrik kirpilir -> asagidaki "merkez" notlari oyun kodundaki capalarla birebir.

  buyucu_crater        (dongu, 6 kare)  "Ates ve Buz" (R finali): meteor cukuru - kul halesi, isikli tas kenar, kor/lav canak,
                                        alev dilleri, yukselen kivilcimlar. Merkez = zemin merkezi; dis kenar rx 44 px
                                        (evo_area.gd CRATER_ART_RADIUS).
  buyucu_levitate      (dongu, 8 kare)  "Yukselis" (R1): havadaki Buyucu'nun ayaginin altinda donen altin run halkasi, govdesinde
                                        goz kirpan parlak yildizlar, halkadan yere suzulen isik zerreleri. Merkez = govde ortasi;
                                        ayak +28 px (buyucu_levitate.gd SPARKLE_LOCAL).
  buyucu_enchant       (tek, 12 kare)   "Efsunlu Buyu" (Q finali): efsunlu dokum - ayak altinda acilan altin run cemberi + mor ic
                                        halka, krem parlama, disari savrulan elmas runler, yukselen kivilcimlar. Merkez = ayak.
  frost_chill_{s,m,l}_{back,front} (dongu, 6 kare) yeni Don Nova yavaslatmasi: arka = yaratigin ayagindaki kiragi/buz lekesi,
                                        on = ayak cevresinde buz kristalleri + yukselen kar zerreleri. Merkez = ayak noktasi
                                        (fx_frost_chill_status.gd). Boy yaratigin govde yaricapina gore (entangle gibi 3 boy).

Calistir: python tools/gen_buyucu_evo_fx.py [ad ...]   (sonra Godot --headless --import)
"""

import math
import os
import random
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402
from gen_hadime_fx import sheet  # noqa: E402
import pixfx as P  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx", "evolution")
RES = "res://assets/fx/evolution/"
TAU = P.TAU

GOLD = P.CHARGE  # [kontur, koyu, orta, acik, parlak] - krem-altin
ARC = P.VOID     # arcane moru


def save(name, frames, anim, loop, fps):
    """gen_enchant_fx.py save ile ayni: tum karelerin dolu alani bulunur, iki yandan ESIT kirpilir (merkez yerinde kalir)."""
    os.makedirs(OUT, exist_ok=True)
    imgs = [f.image() for f in frames]
    W, H = imgs[0].size
    used = np.zeros((H, W), dtype=bool)
    for f in frames:
        used |= f.rgba[:, :, 3] > 0
    ys, xs = np.nonzero(used)
    if len(xs):
        cx_ = max(0, min(int(xs.min()), W - 1 - int(xs.max())) - 1)
        cy_ = max(0, min(int(ys.min()), H - 1 - int(ys.max())) - 1)
        imgs = [im.crop((cx_, cy_, W - cx_, H - cy_)) for im in imgs]
    sheet(imgs).save(os.path.join(OUT, name + "_sheet.png"))
    w, h = imgs[0].size
    write_sprite_frames(os.path.join(OUT, name + "_frames.tres"), RES + name + "_sheet.png", w, h,
                        [(anim, (0, 0), len(imgs), loop, fps)])
    print("   %-24s %dx%d x %d kare (%s)" % (name, w, h, len(imgs), anim))


# ====================================================================== R finali: meteor krateri
def crater():
    n = 6
    W, H = 112, 64
    cx, cy = W / 2, H / 2
    RX, RY = 44.0, 20.0
    rng = random.Random(77)
    embers = [(rng.uniform(-26, 26), rng.uniform(-7, 6), rng.randint(0, n - 1), rng.uniform(9, 17)) for _ in range(9)]
    tongues = [(rng.uniform(-22, 22), rng.uniform(-4, 6), rng.randint(0, n - 1), rng.uniform(0.8, 1.2)) for _ in range(6)]
    rocks = [(rng.uniform(0, TAU), rng.choice((2, 2, 3))) for _ in range(9)]
    frames = []
    for i in range(n):
        cv = P.Canvas(W, H)
        X, Y = cv.grid()
        ash = P.blob_mask(cv, cx, cy + 1, RX * 1.0, RY * 1.08, 71, wobble=0.14, lobes=7)
        rim = P.blob_mask(cv, cx, cy, RX * 0.84, RY * 0.86, 72, wobble=0.07, lobes=6)
        bowl = P.blob_mask(cv, cx, cy + 1, RX * 0.64, RY * 0.6, 73, wobble=0.1, lobes=5)
        # kavrulmus zemin halesi (tasin disi) - koyu kul, benekli
        halo = ash & ~rim
        cv.put(halo, P.SMOKE[0], 225)
        cv.put(halo & (P.value_noise(cv, 5, 74) > 0.6), P.SMOKE[1], 225)
        # tas kenar: ust yarisi isikli (sol ust isik), alt kenar koyu
        lip = rim & ~bowl
        cv.put(lip, P.STONE[1])
        cv.put(lip & (Y < cy - 1), P.STONE[2])
        cv.put(lip & (Y < cy - RY * 0.45) & (X < cx + RX * 0.3) & (P.value_noise(cv, 4, 75) > 0.5), P.STONE[3])
        cv.put(lip & ~P.erode(lip) & (Y > cy + 2), P.STONE[0])
        # canak: komurlesmis kabuk, catlaklarindan kor parlar (damarlar zamanla kayar), ortada sicak cekirdek
        nz = P.value_noise(cv, 14, 76, t=i / n)
        ridge = np.abs(nz - 0.5)
        hot_core = P.ellipse_mask(cv, cx, cy + 1, RX * 0.3, RY * 0.28)
        cv.put(bowl, P.EMBER[0])
        cv.put(bowl & (P.value_noise(cv, 5, 79) > 0.62), P.STONE[0])
        cv.put(bowl & ((ridge < 0.075) | hot_core), P.EMBER[1])
        cv.put(bowl & ((ridge < 0.045) | (hot_core & (nz < 0.55))), P.FIRE[2])
        cv.put(bowl & ((ridge < 0.02) | (hot_core & (ridge < 0.12))), P.FIRE[3])
        cv.put(bowl & hot_core & (ridge < 0.03), P.FIRE[4])
        # canagin ust ic kenari golgede (cukur derinligi)
        cv.put(bowl & ~P.erode(bowl) & (Y < cy), P.EMBER[0])
        # kenara saplanmis kaya parcalari
        for (a, sz) in rocks:
            P.chunk(cv, cx + math.cos(a) * RX * 0.8, cy + math.sin(a) * RY * 0.8 - 1, sz, P.STONE)
        # alev dilleri (kisa omurlu, dongude sirayla)
        for (tx, ty, ph, sc) in tongues:
            k = (i - ph) % n
            if k > 2:
                continue
            h = [4.0, 6.5, 3.5][k] * sc
            x, y = cx + tx, cy + ty
            m = P.ellipses_mask(cv, [(x, y - h * 0.5, h * 0.55, 1.7, -math.pi / 2 + 0.15 * math.sin(i + tx))])
            P.heat_fill(cv, m, P.FIRE, levels=(1, 2, 3, 4), outline=False)
        # yukselen kivilcimlar
        for (ex, ey, ph, hmax) in embers:
            k = ((i - ph) % n) / n
            x = cx + ex + math.sin(k * TAU + ex) * 1.2
            y = cy + ey - k * hmax
            cv.px(x, y, P.FIRE[4] if k < 0.35 else (P.FIRE[3] if k < 0.7 else P.EMBER[2]))
        frames.append(cv)
    save("buyucu_crater", frames, "loop", True, 8.0)


# ====================================================================== R1: havada suzulme parilitisi
def levitate():
    n = 8
    W, H = 72, 104
    cx, cy = W / 2, H / 2
    fy = cy + 28  # ayak hizasi (havadaki)
    rng = random.Random(91)
    stars = [(rng.uniform(-19, 19), rng.uniform(-30, 20), rng.randint(0, n - 1), rng.choice((1, 2, 2, 3))) for _ in range(10)]
    motes = [(rng.uniform(-13, 13), rng.randint(0, n - 1), rng.uniform(10, 18)) for _ in range(7)]
    frames = []
    for i in range(n):
        cv = P.Canvas(W, H)
        rot = TAU * i / n
        # ayak altinda donen altin run halkasi (kesik dolu bant) + ters donen ince mor halka
        P.ring_band(cv, cx, fy, 17, 3, GOLD, squash=0.34,
                    gaps=[(rot + q * TAU / 4, rot + q * TAU / 4 + 0.5) for q in range(4)])
        P.ring_band(cv, cx, fy, 11, 2, ARC, squash=0.34, outline=False,
                    gaps=[(-rot + q * TAU / 3, -rot + q * TAU / 3 + 0.7) for q in range(3)])
        for q in range(4):  # halkadaki run parlamalari
            a = rot + q * TAU / 4 + 0.95
            P.star(cv, cx + math.cos(a) * 15.5, fy + math.sin(a) * 15.5 * 0.34, 1, core=P.WHITE, arm=GOLD[3])
        # govdede goz kirpan yildizlar (boy dongude 1 -> tam -> kucul -> nokta)
        for (sx, sy, ph, sz) in stars:
            k = (i - ph) % n
            if k >= 4:
                continue
            s = [1, sz, max(1, sz - 1), 0][k]
            if s == 0:
                cv.px(cx + sx, cy + sy, GOLD[3])
                continue
            P.star(cv, cx + sx, cy + sy, s, core=P.WHITE, arm=GOLD[3] if k else GOLD[4], diag=(s >= 2 and k == 1))
        # halkadan yere suzulen zerreler
        for (mx, ph, fall) in motes:
            k = ((i - ph) % n) / n
            y = fy + 2 + k * fall
            x = cx + mx + math.sin(k * TAU * 1.5 + mx)
            cv.px(x, y, GOLD[3] if k < 0.5 else GOLD[2])
            if k < 0.3:
                cv.px(x, y - 1, GOLD[2])
        frames.append(cv)
    save("buyucu_levitate", frames, "loop", True, 10.0)


# ====================================================================== Q finali: efsunlu dokum
def enchant():
    n = 12
    W, H = 80, 112
    cx, cy = W / 2, H / 2
    sq = 0.4
    frames = []
    for i in range(n):
        t = i / (n - 1)
        cv = P.Canvas(W, H)
        R = 8 + 22 * P.ease_out(min(1.0, t * 1.5))
        mult = None
        if t > 0.55:
            mult = P.break_mult(cv, cx, cy, sq, (t - 0.55) / 0.45, 3)
        if t < 0.18:
            P.disc_flash(cv, cx, cy, 5 + 26 * t, core=P.CREAM, rim=GOLD[3], squash=sq)
        P.ring_band(cv, cx, cy, R, 3, GOLD, squash=sq, mult=mult,
                    gaps=[(q * TAU / 6 + t * 2.0, q * TAU / 6 + t * 2.0 + 0.32) for q in range(6)])
        P.ring_band(cv, cx, cy, R * 0.62, 2, ARC, squash=sq, mult=mult)
        # disari savrulan elmas runler (uclar kuculerek biter)
        for q in range(4):
            a = q * TAU / 4 + math.pi / 4 + t * 1.2
            d = R + 4 + 10 * t
            x, y = cx + math.cos(a) * d, cy + math.sin(a) * d * sq - 7 * t
            s = 3.2 * (1.0 - max(0.0, (t - 0.6) / 0.4))
            if s < 0.8:
                continue
            P.facets(cv, [([(x, y - s), (x + s * 0.7, y), (x, y + s), (x - s * 0.7, y)], 3),
                          ([(x, y - s), (x, y + s), (x - s * 0.7, y)], 4)], ARC)
        # govde boyunca yukselen kivilcimlar
        for k in range(10):
            ph = (k * 0.37) % 1.0
            hgt = t * 70 * (0.5 + 0.5 * ph)
            if hgt < 2 or (t > 0.85 and k % 2):
                continue
            a = TAU * k / 10 + t * 4.0
            x = cx + math.cos(a) * 10 * (1.0 - t * 0.5)
            y = cy - hgt + math.sin(a) * 3
            P.star(cv, x, y, 2 if k % 3 == 0 else 1, core=P.WHITE, arm=GOLD[3] if k % 2 else ARC[3])
        frames.append(cv)
    save("buyucu_enchant", frames, "play", False, 18.0)


# ====================================================================== Don Nova: buz yavaslatmasi (yaratigin uzerinde)
## boy -> (kiragi rx, ry, zerrelerin yukselecegi yukseklik) sanat px. fx_frost_chill_status.gd SIZES ile ayni anahtarlar.
FROST_SIZES = {"s": (13.0, 5.0, 26.0), "m": (20.0, 8.0, 40.0), "l": (31.0, 12.0, 58.0)}


def frost_chill(key):
    rx, ry, hgt = FROST_SIZES[key]
    n = 6
    W = int(rx * 2 + 20)
    H = int(hgt * 2 + 12)
    cx, cy = W / 2, H / 2  # ayak noktasi
    seed = {"s": 3, "m": 5, "l": 7}[key]
    rng = random.Random(seed * 101)
    # on yarim elipste (asagi bakan taraf) + yanlarda kristal kumeleri
    shards = []
    count = int(4 + rx / 5)
    for q in range(count):
        ## on yarim elips boyunca (0..pi = asagi bakan taraf, uclar yanlara tasar) esit aralikli + kucuk sapma
        a = -0.12 * math.pi + 1.24 * math.pi * (q + 0.5) / count + rng.uniform(-0.12, 0.12)
        shards.append((a, rng.uniform(0.85, 1.05), rng.uniform(3.0, 4.0 + rx / 7.0), rng.uniform(-1.2, 1.2)))
    shards.sort(key=lambda s: math.sin(s[0]))  # arkadakiler once
    flecks = [(rng.uniform(-rx * 0.8, rx * 0.8), rng.randint(0, n - 1), rng.uniform(0.55, 1.0)) for _ in range(int(4 + rx / 4))]
    back_frames = []
    front_frames = []
    for i in range(n):
        # ---- arka: kiragi lekesi
        cv = P.Canvas(W, H)
        X, Y = cv.grid()
        outer = P.blob_mask(cv, cx, cy, rx, ry, seed, wobble=0.12, lobes=6)
        inner = P.blob_mask(cv, cx, cy + 0.3, rx * 0.78, ry * 0.72, seed + 1, wobble=0.14, lobes=5)
        snow = outer & ~inner
        cv.put(snow, P.WIND[3])
        cv.put(snow & (P.value_noise(cv, 4, seed + 2) > 0.62), P.WIND[4])
        cv.put(snow & ~P.erode(snow) & (Y > cy + 1), P.WIND[1])
        nz = P.value_noise(cv, max(5.0, rx * 0.5), seed + 3)
        cv.put(inner, P.ICE[2])
        cv.put(inner & (nz > 0.6), P.ICE[3])
        cv.put(inner & (np.abs(nz - 0.45) < 0.035), P.ICE[4])  # catlak cizgileri
        cv.put(inner & ~P.erode(inner) & (Y > cy), P.ICE[1])
        cv.put(P.outline_of(outer) & ~cv.filled(), P.ICE[0])
        tw = rng.random()  # parilti: her karede baska bir noktada (tohumla sabit)
        tx = cx + math.cos(i * 2.3 + seed) * rx * 0.55
        ty = cy + math.sin(i * 1.7 + seed) * ry * 0.5
        P.star(cv, tx, ty, 1 + (i % 2), core=P.WHITE, arm=P.ICE[4])
        back_frames.append(cv)
        # ---- on: buz kristalleri + yukselen kar zerreleri
        cf = P.Canvas(W, H)
        for (a, rk, h, lean) in shards:
            bx = cx + math.cos(a) * rx * rk
            by = cy + math.sin(a) * ry * rk
            if math.sin(a) < -0.1:  # tamamen arkadakiler govdenin arkasinda kalsin (on katmana cizilmez)
                continue
            w = 1.6 + h * 0.18
            tip = (bx + lean, by - h)
            P.facets(cf, [([(bx - w, by), (bx + w, by), tip], 2), ([(bx - w, by), (bx, by), tip], 3)], P.ICE)
            if (i + int(bx)) % n == 0:  # kristalin ucundan kayan parilti
                cf.px(tip[0], tip[1] + 1, P.ICE[4])
        for (fx, ph, sp) in flecks:
            k = ((i - ph) % n) / n
            y = cy - 3 - k * hgt * sp
            x = cx + fx + math.sin(k * TAU + fx) * 1.5
            if k < 0.85:
                cf.px(x, y, P.WHITE if k < 0.4 else P.ICE[4])
                if k < 0.2:
                    cf.px(x, y + 1, P.ICE[3])
        front_frames.append(cf)
    save("frost_chill_%s_back" % key, back_frames, "loop", True, 8.0)
    save("frost_chill_%s_front" % key, front_frames, "loop", True, 8.0)


ALL = {
    "buyucu_crater": crater,
    "buyucu_levitate": levitate,
    "buyucu_enchant": enchant,
    "frost_chill_s": lambda: frost_chill("s"),
    "frost_chill_m": lambda: frost_chill("m"),
    "frost_chill_l": lambda: frost_chill("l"),
}

if __name__ == "__main__":
    names = sys.argv[1:] or list(ALL.keys())
    print("Buyucu evrim FX ->", os.path.relpath(OUT, ROOT))
    for nm in names:
        P.PAD[:] = [48, 48]
        ALL[nm]()
