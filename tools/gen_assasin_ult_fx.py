#!/usr/bin/env python3
"""Assasin Cocuk ULTI (Golge Hucumu) YENI efektleri - pixel-art sprite sayfalari -> assets/fx/assasin/ult_*.

Kullanici istegi (2026-10-16): "ultisi icin yeni ozel efekt hazirla, suanki efektler cok gosterissiz ve o suikastci hizini
hissettirmiyor". Eski set: oyuncunun arkasinda koyu golge kopyalari (fx_assasin_dash.gd) + hedefte iki capraz hilal kesik
(shadow_hit, gen_assasin_hit_fx.py). Yeni dil (tools/pixfx.py - ici dolu kutle, 5 ton SHADOW rampasi, 1 px koyu kontur,
krem/beyaz parlama, uclari sivrilen hatlar):
  * ult_cut     hedefte UZUN, INCE, ANINDA tam boy beliren ana kesik (+x = hamle yonu, -22 derece) + bir kare sonra kisa
                ikinci capraz kesik; kesik ortadan ayrilip iki yana kayar, incelir, kesik kesik soner. Ileri (+x) savrulan
                golge kiymiklari + hamle yonunde ucan hiz cizgileri + arkada sonen golge dumani. 10 kare, 30 fps.
  * ult_streak  sicrayis yolu boyunca dosenen KARO (16 px, x'te periyodik): beyaz cekirdekli mor isik cizgisi + ust/alt
                hiz cizgileri, incelir -> kesik kesik -> zerre. ult_streak_cap: kuyruk/bas karosu (sola dogru sivrilir,
                bas tarafinda yatay aynasi kullanilir). 6 kare; oyunda her karo kendi gecikmesiyle oynar (kuyruktan basa
                "fermuar"), bkz. scripts/fx_assasin_ult_streak.gd.
  * ult_blink   cast ve donus aninda golge patlamasi: krem parlama -> disa acilan golge kumeleri + her yone firlayan hiz
                cizgileri -> hilale asinan duman. 9 kare, 30 fps.
1 sanat pikseli = oyunda TEXEL (1.212) dunya birimi. Tuval boyutlari/merkezler oyun koduna bagli DEGIL (sprite'lar
merkezli, kirpma simetrik) - karo genisligi (16) haric: fx_assasin_ult_streak.gd dokunun genisligini okur.

Calistir: python tools/gen_assasin_ult_fx.py [onizleme.png]
"""

import math
import os
import random
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402
import pixfx as P  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx", "assasin")
RES = "res://assets/fx/assasin/"

SH = P.SHADOW  # [kontur, koyu, orta, acik, parlak] mor golge rampasi
WHITE = P.WHITE
CREAM = P.CREAM
SMOKE = [SH[0], (22, 9, 36), SH[1], (50, 24, 80), SH[2]]


def sheet(imgs):
    w, h = imgs[0].size
    out = Image.new("RGBA", (w * len(imgs), h), (0, 0, 0, 0))
    for i, im in enumerate(imgs):
        out.paste(im, (i * w, 0))
    return out


def save(name, frames, anim, loop, fps, crop=True):
    """Kareleri yatay sayfaya dizer; crop: tum karelerin birlesik dolu alanina gore iki yandan ESIT kirpar (merkez yerinde
    kalir). Karolar kirpilmaz (genislik periyot)."""
    os.makedirs(OUT, exist_ok=True)
    imgs = [f.image() for f in frames]
    W, H = imgs[0].size
    if crop:
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
    print("   %-16s %dx%d x %d kare" % (name, w, h, len(imgs)))
    return imgs


def _hash(X, Y, seed):
    h = (X.astype(np.int64) * 73856093) ^ (Y.astype(np.int64) * 19349663) ^ (seed * 83492791)
    return (h & 0xFFFF) / 65535.0


# ====================================================================== kesik (hedefte)
def blade(cv, cx, cy, ang, L, w, core, gap, brk, seed, light=None):
    """Duz, iki ucu sivri kesik. w: ortadaki yari kalinlik (px), core: cekirdek orani (0 = beyaz cekirdek yok), gap: kesigin
    ortadan iki yana kayma miktari (px; 0 = tek parca), brk: 0..1 kesik kesik parcalanma (uclardan baslar)."""
    X, Y = cv.grid()
    ca, sa = math.cos(ang), math.sin(ang)
    u = (X - cx) * ca + (Y - cy) * sa
    v = -(X - cx) * sa + (Y - cy) * ca
    half = L * 0.5
    if gap <= 0.0:
        t = np.clip(np.abs(u) / half, 0.0, 1.0)
        hw = w * (1.0 - t ** 2.2) ** 0.8
        inside = np.abs(u) <= half
    else:
        # iki yari: her biri kendi [gap, gap + half] araliginda, ic ucu da (kayma buyudukce) sivrilir
        s = (np.abs(u) - gap) / half
        inside = (s >= 0.0) & (s <= 1.0)
        s = np.clip(s, 0.0, 1.0)
        inner = np.clip(s * half / (1.5 + gap * 1.6), 0.0, 1.0) ** 0.6
        hw = w * (1.0 - s ** 2.2) ** 0.8 * inner
        t = s
    m = inside & (np.abs(v) <= hw) & (hw >= 0.42)
    if brk > 0.0:
        # parcalanma: hat boyunca seyrek bosluklar, uclardan merkeze ilerler (zerre degil, kisalan cizgiler)
        pat = 0.5 + 0.5 * np.sin(u * 0.9 + seed) * np.cos(u * 0.37 + seed * 1.7)
        m &= pat > brk * (0.35 + 0.9 * t)
    if not m.any():
        return m
    d = np.abs(v) / np.maximum(hw, 0.5)
    hi = light or SH[4]
    cv.put(m & (d > 0.62), SH[3])
    cv.put(m & (d <= 0.62), hi)
    if core > 0.0:
        cv.put(m & (d <= core) & (t < 0.82), WHITE)
    cv.put(P.outline_of(m) & ~cv.filled(), SH[0])
    return m


def make_cut():
    P.PAD[:] = [10, 10]
    W, H, CX, CY = 100, 72, 50, 36
    N = 10
    rng = random.Random(1016)
    A1, L1 = -0.38, 76.0   # ana kesik
    A2, L2 = 1.08, 42.0    # ikinci kesik
    main = [(2.6, 0.55, 0, 0.0), (2.3, 0.42, 0, 0.0), (1.9, 0.3, 0, 0.0), (1.6, 0.0, 1, 0.08), (1.35, 0.0, 2, 0.22),
            (1.15, 0.0, 3, 0.38), (0.95, 0.0, 4, 0.52), (0.75, 0.0, 5, 0.66), (0.58, 0.0, 6, 0.8), None]
    second = [None, (2.0, 0.5, 0, 0.0), (1.7, 0.35, 0, 0.0), (1.4, 0.0, 0, 0.1), (1.15, 0.0, 1, 0.28), (0.95, 0.0, 2, 0.46),
              (0.7, 0.0, 3, 0.64), (0.5, 0.0, 4, 0.8), None, None]
    # ileri savrulan kiymiklar (aci, hiz, boy)
    shards = [(rng.uniform(-0.75, 0.75), rng.uniform(3.4, 6.2), rng.choice((2, 2, 3))) for _ in range(7)]
    # hamle yonunde ucan hiz cizgileri (y, x0, boy, hiz)
    flecks = [(rng.uniform(-11, 11), rng.uniform(-14, 4), rng.randint(5, 9), rng.uniform(7.0, 10.0)) for _ in range(6)]
    frames = []
    for f in range(N):
        cv = P.Canvas(W, H)
        k = f / (N - 1)
        # arkada (hamlenin geldigi yon, -x) sonen golge dumani - en altta
        if 2 <= f <= 8:
            u = (f - 2) / 6.0
            circles = [(CX - 7 - 5 * u, CY + 1, 4.2 * (1 - 0.5 * u)), (CX - 12 - 7 * u, CY - 2, 3.4 * (1 - 0.45 * u)),
                       (CX - 3 - 3 * u, CY + 3, 3.0 * (1 - 0.6 * u))]
            cuts = [(x + r * 0.5, y - r * 0.4, r * (0.3 + 0.9 * u)) for (x, y, r) in circles] if u > 0.15 else None
            P.puffs(cv, circles, SMOKE, cut=cuts, hi=False)
        if second[f]:
            w, core, gap, brk = second[f]
            blade(cv, CX - 1, CY + 1, A2, L2, w, core, gap, brk, seed=3)
        if main[f]:
            w, core, gap, brk = main[f]
            blade(cv, CX + 2, CY, A1, L1, w, core, gap, brk, seed=7)
        # isabet parlamasi
        if f == 0:
            P.disc_flash(cv, CX + 1, CY, 5.2, core=CREAM, rim=SH[4])
            P.star(cv, CX + 1, CY, 7, core=WHITE, arm=SH[4])
        elif f == 1:
            P.disc_flash(cv, CX + 1, CY, 3.0, core=WHITE, rim=SH[4])
            P.star(cv, CX + 1, CY, 4, core=WHITE, arm=SH[3], diag=True)
        # kiymiklar
        if 1 <= f <= 8:
            u = (f - 1) / 7.0
            for (a, sp, size) in shards:
                d = 4 + sp * 7.0 * P.ease_out(u)
                sz = max(1, size - int(u * 2.2))
                x = CX + math.cos(a) * d
                y = CY + math.sin(a) * d + u * u * 3.0
                if sz >= 2:
                    P.chunk(cv, x, y, sz, SH)
                elif u < 0.95:
                    cv.px(x, y, SH[3])
        # hiz cizgileri (+x)
        if 1 <= f <= 5:
            u = (f - 1) / 4.0
            for (fy, x0, ln, sp) in flecks:
                L = max(1, int(round(ln * (1 - 0.7 * u))))
                xs = x0 + sp * (f - 1) + CX
                for i in range(L):
                    cv.px(xs + i, CY + fy, WHITE if (i == L - 1 and u < 0.5) else (SH[4] if i > L * 0.4 else SH[3]))
        frames.append(cv)
    return save("ult_cut", frames, "hit", False, 30.0)


# ====================================================================== sicrayis cizgisi karolari
TW, TH = 16, 11
MID = 5


## Govde karosunun hiz cizgisi varyantlari (satir, baslangic x, boy) - ayni karo tekrar edince ust/alt cizgiler duzenli noktali
## hat gibi okunmasin diye sayfada 3 satir; oyun her karoya konumundan turetilen bir satir secer.
FLECKS = [((1, 3, 5), (9, 10, 4)), ((1, 9, 4), (9, 1, 6)), ((1, 13, 3), (9, 6, 3))]


def _streak_frame(f, cap, var=0):
    """Bir karo karesi. cap: sola dogru sivrilen uc karo (x=0 en ince). var: hiz cizgisi varyanti (FLECKS)."""
    P.PAD[:] = [0, 0]
    cv = P.Canvas(TW, TH)
    X, Y = cv.grid()
    xi = np.floor(X).astype(int)
    dy = np.abs(np.floor(Y).astype(int) - MID)
    # kare basina: (yari kalinlik, cekirdek beyaz mi, parlak satir rengi, kenar rengi, desen: acik x araliklari ya da None)
    ## Sonme: kalin isik -> 1 px cizgi -> KISALAN tek parcalar (2026-10-16 ilk denemede kesik desen + yari satirlar oyunda
    ## "boncuk dizisi" gibi okundu; artik her karede tek satir, parcalar sadece kisalir).
    spec = [
        (1, True, SH[4], SH[4], None),
        (1, False, SH[4], SH[3], None),
        (0, False, SH[4], SH[4], None),
        (0, False, SH[3], SH[3], [(0, 11)]),
        (0, False, SH[3], SH[3], [(1, 6)]),
        (0, False, SH[2], SH[2], [(3, 4)]),
    ][f]
    hh, white, c_mid, c_edge, pat = spec
    band = dy <= hh
    if pat is not None:
        on = np.zeros_like(band)
        for (a, b) in pat:
            on |= (xi >= a) & (xi <= b)
        band &= on
    if cap:
        # kuyruk: x=0'da bos, x 1..10 arasi tek satir, sonra tam kalinlik; cekirdek sadece genis kisimda
        reach = np.clip((xi - 0.5) / 9.0, 0.0, 1.0)
        band &= (xi >= 1) & (dy <= np.floor(reach * (hh + 0.99)))
    cv.put(band & (dy > 0), c_edge)
    cv.put(band & (dy == 0), c_mid)
    if white:
        cv.put(band & (dy == 0) & ((xi >= 5) if cap else True), WHITE)
    if f <= 2:
        cv.put(P.outline_of(band) & ~cv.filled() & ((Y > 0.99) & (Y < TH - 0.99)), SH[0] if f <= 1 else SH[1])
    # hiz cizgileri: ust (satir 1) ve alt (satir 9), her karede +x'e kayar (karo periyodik -> sarmali)
    if f <= 2:
        for (row, x0, ln) in FLECKS[var]:
            ln2 = max(1, ln - f * 2)
            for i in range(ln2):
                x = (x0 + f * 3 + i) % TW
                if cap and x < 6:
                    continue
                cv.px(x, row, SH[4] if i == ln2 - 1 else SH[3])
    return cv


def make_streak():
    """Karo sayfalari .tres'siz: oyun Sprite2D hframes (6 kare) / vframes (govde: 3 varyant satiri) ile okur."""
    os.makedirs(OUT, exist_ok=True)
    body_rows = [[_streak_frame(f, False, v) for f in range(6)] for v in range(len(FLECKS))]
    out = Image.new("RGBA", (TW * 6, TH * len(body_rows)), (0, 0, 0, 0))
    for r, row in enumerate(body_rows):
        out.paste(sheet([c.image() for c in row]), (0, r * TH))
    out.save(os.path.join(OUT, "ult_streak_sheet.png"))
    cap = [_streak_frame(f, True) for f in range(6)]
    sheet([c.image() for c in cap]).save(os.path.join(OUT, "ult_streak_cap_sheet.png"))
    print("   %-16s %dx%d x 6 kare (govde %d satir + uc)" % ("ult_streak", TW, TH, len(body_rows)))
    return body_rows[0], cap


# ====================================================================== cast / donus golge patlamasi
def make_blink():
    P.PAD[:] = [10, 10]
    W, H, CX, CY = 72, 64, 36, 32
    N = 9
    rng = random.Random(77)
    rays = [(TAU_ * q / 10 + rng.uniform(-0.15, 0.15), rng.uniform(0.85, 1.2)) for q in range(10)]
    frames = []
    for f in range(N):
        cv = P.Canvas(W, H)
        t = f / (N - 1)
        P.burst(cv, CX, CY, 17.0, t, SH, SMOKE, seed=12, n_puffs=7, squash=0.85, shards=False)
        # her yone firlayan hiz cizgileri
        if 1 <= f <= 5:
            u = (f - 1) / 4.0
            for (a, sp) in rays:
                r0 = (9 + 16 * P.ease_out(u)) * sp
                ln = max(1, int(round((9 - 6 * u) * sp)))
                for i in range(ln):
                    r = r0 + i
                    col = WHITE if (i == ln - 1 and u < 0.3) else (SH[4] if i >= ln * 0.5 else SH[3])
                    cv.px(CX + math.cos(a) * r, CY + math.sin(a) * r * 0.85, col)
        frames.append(cv)
    return save("ult_blink", frames, "play", False, 30.0)


TAU_ = 2 * math.pi


def preview(path, cut, streak, blink):
    """Onizleme: her sayfa 4x buyutulmus, koyu cimen zemininde."""
    body, cap = streak
    rows = []
    for imgs in (cut, [b.image() for b in body], [c.image() for c in cap], blink):
        rows.append(sheet(imgs))
    Wd = max(r.size[0] for r in rows)
    Hd = sum(r.size[1] + 4 for r in rows)
    out = Image.new("RGBA", (Wd, Hd), (58, 86, 52, 255))
    y = 0
    for r in rows:
        out.alpha_composite(r, (0, y))
        y += r.size[1] + 4
    out = out.resize((Wd * 4, Hd * 4), Image.NEAREST)
    out.save(path)
    print("onizleme:", path)


def main():
    print("Assasin ulti efektleri ->", OUT)
    cut = make_cut()
    streak = make_streak()
    blink = make_blink()
    if len(sys.argv) > 1:
        preview(sys.argv[1], cut, streak, blink)


if __name__ == "__main__":
    main()
