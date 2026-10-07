"""Üst-orta boss çubuğu: 4 prototip. Sanat ızgarası: 1 art px = 3 ekran px (oyun kitiyle aynı)."""
import math
from art import *


def ticks(a, x, y, w, h, n, color=OUT, alpha=0.45):
    for i in range(1, n):
        tx = x + int(round(w * i / n))
        for yy in range(y, y + h):
            a.shade(tx, yy, color, alpha)


# ---------------------------------------------------------------- T1 Ahşap Plaket
def top_t1(name, hp, sh, W=224):
    H = 38
    a = Art(W, H)
    tw = a.text_width(name)
    sw = tw + 22
    sx = (W - sw) // 2
    # isim tabelası (parşömen, iki yanında altın çivi)
    a.rrect(sx, 0, sw, 13, OUT)
    a.rect(sx + 1, 1, sw - 2, 11, PARCH)
    a.hline(sx + 1, 1, sw - 2, PARCH_HI)
    a.hline(sx + 1, 11, sw - 2, PARCH_SH)
    for nx in (sx + 4, sx + sw - 5):
        a.set(nx, 5, GOLD_L)
        a.set(nx, 6, GOLD)
        a.set(nx, 7, GOLD_D)
    a.text(sx + 11, 3, name, INK)
    # ana ahşap plaket
    fy, fh = 11, 27
    a.rrect(0, fy, W, fh, OUT)
    a.rect(1, fy + 1, W - 2, fh - 2, W_FACE)
    a.hline(1, fy + 1, W - 2, W_HI)
    a.vline(1, fy + 1, fh - 2, W_HI)
    a.hline(1, fy + fh - 2, W - 2, W_DK)
    a.vline(W - 2, fy + 1, fh - 2, W_MD)
    for gx in range(6, W - 6, 11):          # ahşap damarı
        a.set(gx, fy + 6, W_MD)
        a.set(gx + 4, fy + 19, W_MD)
        a.set(gx + 7, fy + 12, W_SH)
    # köşe çivileri
    for (nx, ny) in ((3, fy + 3), (W - 5, fy + 3), (3, fy + fh - 5), (W - 5, fy + fh - 5)):
        a.set(nx, ny, GOLD_L)
        a.set(nx + 1, ny, GOLD)
        a.set(nx, ny + 1, GOLD)
        a.set(nx + 1, ny + 1, GOLD_D)
    # kafatası yuvası (HUD'daki kalp yuvası gibi)
    a.rrect(5, fy + 4, 19, 19, OUT)
    a.rect(6, fy + 5, 17, 17, RED_D)
    a.rect(6, fy + 5, 17, 1, RED_M)
    a.paste(skull(), 10, fy + 9)
    # çubuklar
    x0, w = 30, W - 30 - 6
    sy, hy = fy + 4, fy + 13
    a.rect(x0 - 1, sy - 1, w + 2, 6 + 2, OUT)
    fill_bar(a, x0, sy, w, 6, sh, SH_BANDS, EMPTY_BLUE)
    a.rect(x0 - 1, hy - 1, w + 2, 10 + 2, OUT)
    fill_bar(a, x0, hy, w, 10, hp, HP_BANDS, TRACK)
    ticks(a, x0, hy, w, 10, 10)
    return a


def top_t1_compact(name, hp, sh, W=176):
    H = 19
    a = Art(W, H)
    a.rrect(0, 0, W, H, OUT)
    a.rect(1, 1, W - 2, H - 2, W_FACE)
    a.hline(1, 1, W - 2, W_HI)
    a.hline(1, H - 2, W - 2, W_DK)
    a.paste(skull(), 3, 5)
    a.text(15, 6, name, INK)
    x0 = 52
    w = W - x0 - 4
    a.rect(x0 - 1, 2, w + 2, 4 + 2, OUT)
    fill_bar(a, x0, 3, w, 4, sh, SH_BANDS, EMPTY_BLUE)
    a.rect(x0 - 1, 8, w + 2, 8 + 2, OUT)
    fill_bar(a, x0, 9, w, 8, hp, HP_BANDS, TRACK)
    return a


# ---------------------------------------------------------------- T2 Zırh Dilimleri
HORN = [
    "..........XX",
    ".........XDBX",
    "........XDBHX",
    ".......XDBBX.",
    "......XDBBBX.",
    ".....XDBBBX..",
    "....XDBBBBX..",
    "...XDBBBBX...",
    "..XDBBBBBX...",
    "..XDBBBBX....",
    ".XDBBBBBX....",
    ".XDBBBBX.....",
    "XDBBBBBBXXXXX",
    "XDBBBBBBBBBBX",
    "XXXXXXXXXXXXX",
]


def horn(flip=False):
    rows = HORN
    wmax = max(len(r) for r in rows)
    a = Art(wmax, len(rows))
    a.blit([r.ljust(wmax, ".") for r in rows], {"X": OUT2, "B": BONE, "D": BONE_D, "H": hexc("#fff6e0")}, 0, 0)
    if flip:
        a.im = a.im.transpose(Image.FLIP_LEFT_RIGHT)
        a.px = a.im.load()
    return a


def top_t2(name, hp, sh, W=236):
    H = 42
    a = Art(W, H)
    by, bh = 12, 28
    # boynuzlar (çerçevenin iki ucunda)
    a.paste(horn(False), 0, by - 5)
    a.paste(horn(True), W - 13, by - 5)
    # demir gövde
    a.rrect(8, by, W - 16, bh, OUT2)
    a.rect(9, by + 1, W - 18, bh - 2, IRON)
    a.hline(9, by + 1, W - 18, IRON_HI)
    a.hline(9, by + bh - 2, W - 18, IRON_D)
    a.hline(11, by + 3, W - 22, GOLD_D)      # ince altın şerit
    a.hline(11, by + bh - 4, W - 22, GOLD_D)
    for (nx, ny) in ((11, by + 6), (W - 13, by + 6), (11, by + bh - 9), (W - 13, by + bh - 9)):
        a.rect(nx, ny, 2, 2, GOLD)
        a.set(nx, ny, GOLD_L)
    # isim plakası (üstte çıkıntı)
    tw = a.text_width(name)
    pw = tw + 20
    px = (W - pw) // 2
    a.rrect(px, 2, pw, 12, OUT2)
    a.rect(px + 1, 3, pw - 2, 10, IRON_D)
    a.hline(px + 1, 3, pw - 2, GOLD_D)
    a.hline(px + 1, 12, pw - 2, GOLD_D)
    a.text(px + 10, 4, name, CREAM)
    # kalkan plakaları
    n = 10
    gap = 2
    inner = W - 2 * 17
    pwid = (inner - gap * (n - 1)) // n
    total = pwid * n + gap * (n - 1)
    x0 = (W - total) // 2
    for i in range(n):
        x = x0 + i * (pwid + gap)
        seg_lo, seg_hi = i / n, (i + 1) / n
        fill = 0.0 if sh <= seg_lo else (1.0 if sh >= seg_hi else (sh - seg_lo) * n)
        a.rrect(x, by + 6, pwid, 8, OUT2)
        a.rrect(x + 1, by + 7, pwid - 2, 6, EMPTY_BLUE)
        fw = int(round((pwid - 2) * fill))
        if fw > 0:
            for yy, c in enumerate([BLUE_HI, BLUE_L, BLUE, BLUE, BLUE, BLUE_D]):
                for xx in range(fw):
                    if not ((xx == 0 or xx == pwid - 3) and yy in (0, 5) and fw == pwid - 2):
                        a.set(x + 1 + xx, by + 7 + yy, c)
    # can çubuğu
    hx, hw = x0, total
    a.rect(hx - 1, by + 15, hw + 2, 10 + 2, OUT2)
    fill_bar(a, hx, by + 16, hw, 10, hp, HP_BANDS, TRACK)
    ticks(a, hx, by + 16, hw, 10, 10, OUT2, 0.5)
    return a


def top_t2_compact(name, hp, sh, W=176):
    H = 18
    a = Art(W, H)
    a.rrect(0, 0, W, H, OUT2)
    a.rect(1, 1, W - 2, H - 2, IRON)
    a.hline(1, 1, W - 2, IRON_HI)
    a.hline(2, H - 3, W - 4, GOLD_D)
    a.text(5, 6, name, CREAM)
    x0 = 46
    total = W - x0 - 5
    n, gap = 5, 1
    pwid = (total - gap * (n - 1)) // n
    for i in range(n):
        x = x0 + i * (pwid + gap)
        lo, hi = i / n, (i + 1) / n
        fill = 0.0 if sh <= lo else (1.0 if sh >= hi else (sh - lo) * n)
        a.rect(x, 3, pwid, 4, EMPTY_BLUE)
        if fill > 0:
            a.rect(x, 3, int(round(pwid * fill)), 4, BLUE_L)
            a.hline(x, 3, int(round(pwid * fill)), BLUE_HI)
    a.rect(x0 - 1, 8, total + 2, 8, OUT2)
    fill_bar(a, x0, 9, total, 6, hp, HP_BANDS, TRACK)
    return a


# ---------------------------------------------------------------- T3 Madalyon (kalkan halkası)
def top_t3(name, hp, sh, W=236):
    H = 40
    a = Art(W, H)
    R = 19.5
    cx, cy = 20.0, 20.0
    # can çubuğu çerçevesi (madalyonun arkasından sağa)
    bx, by, bh = 30, 17, 14
    bw = W - bx - 3
    a.rrect(bx, by, bw, bh, OUT2)
    a.rect(bx + 1, by + 1, bw - 2, bh - 2, GOLD_D)
    a.hline(bx + 1, by + 1, bw - 2, GOLD_L)
    a.rect(bx + 3, by + 3, bw - 6, bh - 6, TRACK)
    a.rect(bx + 2, by + 2, bw - 4, bh - 4, OUT2)
    fill_bar(a, bx + 3, by + 3, bw - 6, bh - 6, hp, HP_BANDS, TRACK)
    ticks(a, bx + 3, by + 3, bw - 6, bh - 6, 10, OUT2, 0.5)
    # isim
    a.text(bx + 14, 5, name, CREAM, outline=OUT)
    # madalyon: dış anahat, kalkan halkası, altın çerçeve, koyu iç + taçlı kafatası
    for (x, y, d) in circle_points(cx, cy, R):
        if d > R + 1:
            continue
        if d > R:
            a.set(x, y, OUT2)
        elif d > R - 4:          # kalkan halkası
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            frac = (math.atan2(dx, -dy) % (2 * math.pi)) / (2 * math.pi)
            if frac <= sh and sh > 0:
                t = (R - d) / 4
                a.set(x, y, BLUE_HI if t < 0.25 else BLUE_L if t < 0.5 else BLUE if t < 0.8 else BLUE_D)
            else:
                a.set(x, y, EMPTY_BLUE)
        elif d > R - 6.2:        # altın çerçeve
            a.set(x, y, GOLD_L if (y + 0.5) < cy - 4 else GOLD if (y + 0.5) < cy + 4 else GOLD_D)
        elif d > R - 7.2:
            a.set(x, y, OUT2)
        else:                    # iç: koyu zemin
            a.set(x, y, RED_D if d < 5 else TRACK2)
    # taç sivri uçları + kafatası
    for sx2 in (-5, 0, 5):
        a.set(int(cx) + sx2, int(cy) - 11, GOLD_L)
        a.set(int(cx) + sx2, int(cy) - 10, GOLD)
    a.hline(int(cx) - 6, int(cy) - 9, 13, GOLD)
    a.hline(int(cx) - 6, int(cy) - 8, 13, GOLD_D)
    a.paste(skull(), int(cx) - 4, int(cy) - 6)
    return a


def top_t3_compact(name, hp, sh, W=176):
    H = 24
    a = Art(W, H)
    R = 11.0
    cx, cy = 11.5, 12.0
    bx, by, bh = 18, 12, 9
    a.rrect(bx, by, W - bx, bh, OUT2)
    a.rect(bx + 1, by + 1, W - bx - 2, bh - 2, GOLD_D)
    a.rect(bx + 2, by + 2, W - bx - 4, bh - 4, TRACK)
    fill_bar(a, bx + 2, by + 2, W - bx - 4, bh - 4, hp, HP_BANDS, TRACK)
    a.text(26, 4, name, CREAM, outline=OUT)
    for (x, y, d) in circle_points(cx, cy, R):
        if d > R + 0.5:
            continue
        if d > R - 0.5:
            a.set(x, y, OUT2)
        elif d > R - 3.0:
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            frac = (math.atan2(dx, -dy) % (2 * math.pi)) / (2 * math.pi)
            a.set(x, y, BLUE_L if (frac <= sh and sh > 0) else EMPTY_BLUE)
        elif d > R - 4.0:
            a.set(x, y, GOLD)
        else:
            a.set(x, y, RED_D)
    a.paste(skull(), int(cx) - 4, int(cy) - 4)
    return a


# ---------------------------------------------------------------- T4 Sade Çizgi
def top_t4(name, hp, sh, W=224, show_pct=True):
    H = 27
    a = Art(W + 6, H)
    ox = 3
    a.paste(skull(), ox, 1)
    a.text(ox + 12, 3, name, CREAM, outline=OUT)
    if show_pct:
        t = "%%%d" % int(round(hp * 100))
        a.text(ox + W - a.text_width(t), 3, t, BONE, outline=OUT)
    x0, w = ox, W
    a.rect(x0 - 1, 13, w + 2, 5, OUT)
    fill_bar(a, x0, 14, w, 3, sh, SH_BANDS, EMPTY_BLUE)
    a.rect(x0 - 1, 18, w + 2, 8, OUT)
    fill_bar(a, x0, 19, w, 6, hp, HP_BANDS, TRACK)
    ticks(a, x0, 19, w, 6, 4, OUT, 0.55)
    for ex in (ox - 2, ox + W + 1):             # uç altın elmaslar
        a.set(ex, 20, GOLD_L)
        a.set(ex - 1, 21, GOLD)
        a.set(ex + 1, 21, GOLD)
        a.set(ex, 22, GOLD_D)
    return a


def top_t4_compact(name, hp, sh, W=150):
    H = 18
    a = Art(W, H)
    a.text(0, 2, name, CREAM, outline=OUT)
    a.rect(-1, 10, W + 2, 3, OUT)
    fill_bar(a, 0, 11, W, 1, sh, SH_BANDS, EMPTY_BLUE)
    a.rect(-1, 12, W + 2, 6, OUT)
    fill_bar(a, 0, 13, W, 4, hp, HP_BANDS, TRACK)
    return a


TOPS = {
    "T1": ("Ahşap Plaket", top_t1, top_t1_compact),
    "T2": ("Zırh Dilimleri", top_t2, top_t2_compact),
    "T3": ("Madalyon", top_t3, top_t3_compact),
    "T4": ("Sade Çizgi", top_t4, top_t4_compact),
}


if __name__ == "__main__":
    import sys
    out = sys.argv[1]
    bg = Image.new("RGBA", (260 * 3, 4 * 150), hexc("#5b7a3a"))
    y = 6
    for key, (title, fn, cfn) in TOPS.items():
        art = fn("KADİM GOLEM", 0.72, 0.55)
        bg.alpha_composite(art.scaled(3), (10, y))
        y += art.h * 3 + 10
    bg.save(out)
    print("ok", bg.size)
