"""Boss'un ÜSTÜNDEKİ can/kalkan çubuğu: 4 prototip. Dünya uzayı: 1 art px = 1 yerel birim = 2 ekran px (mevcut çubukla aynı)."""
from art import *
from protos_top import ticks


def horn_small(flip=False):
    rows = [
        "...XX",
        "..XBX",
        "..XBX",
        ".XBBX",
        ".XBBX",
        "XBBBX",
        "XXXXX",
    ]
    a = Art(5, 7)
    a.blit(rows, {"X": OUT2, "B": BONE}, 0, 0)
    a.set(1, 5, BONE_D)
    if flip:
        a.im = a.im.transpose(Image.FLIP_LEFT_RIGHT)
        a.px = a.im.load()
    return a


# ---------------------------------------------------------------- O1 Demir Çerçeve + Kafatası
def world_o1(hp, sh, name=""):
    W, H = 78, 20
    a = Art(W, H)
    bx, by, bw, bh = 9, 5, 68, 14
    a.rrect(bx, by, bw, bh, OUT2)
    a.rect(bx + 1, by + 1, bw - 2, bh - 2, IRON)
    a.hline(bx + 1, by + 1, bw - 2, IRON_HI)
    a.hline(bx + 1, by + bh - 2, bw - 2, IRON_D)
    # kalkan şeridi (üstte) + can (altta)
    ix, iw = bx + 8, bw - 12
    a.rect(ix - 1, by + 2, iw + 2, 5, OUT2)
    fill_bar(a, ix, by + 3, iw, 3, sh, SH_BANDS, EMPTY_BLUE)
    a.rect(ix - 1, by + 7, iw + 2, 7, OUT2)
    fill_bar(a, ix, by + 8, iw, 5, hp, HP_BANDS, TRACK)
    ticks(a, ix, by + 8, iw, 5, 10, OUT2, 0.5)
    # altın çiviler
    for (nx, ny) in ((bx + 15 - 8 + 8, by + 1),):
        pass
    a.set(bx + bw - 3, by + 1, GOLD_L)
    a.set(bx + bw - 3, by + bh - 3, GOLD)
    # kafatası plakası (sol uçta, çerçeveyi örter)
    a.rrect(0, 2, 15, 15, OUT2)
    a.rect(1, 3, 13, 13, IRON_D)
    a.box(1, 3, 13, 13, GOLD_D)
    a.set(1, 3, GOLD_L)
    a.set(13, 3, GOLD_L)
    a.rect(2, 4, 11, 11, RED_D)
    a.paste(skull(), 3, 5)
    return a


# ---------------------------------------------------------------- O2 Asma Tabela (isim + ahşap çubuk)
def world_o2(hp, sh, name="GOLEM"):
    tw = text_mask(name)[1]
    W = max(tw + 18, 76)
    H = 30
    a = Art(W, H)
    # tabela
    sw = tw + 14
    sx = (W - sw) // 2
    a.rrect(sx, 0, sw, 12, OUT)
    a.rect(sx + 1, 1, sw - 2, 10, PARCH)
    a.hline(sx + 1, 1, sw - 2, PARCH_HI)
    a.hline(sx + 1, 10, sw - 2, PARCH_SH)
    a.set(sx + 2, 5, GOLD)
    a.set(sx + sw - 3, 5, GOLD)
    a.text(sx + 7, 3, name, INK)
    # zincirler
    for cx in (sx + 5, sx + sw - 6):
        a.vline(cx, 12, 3, BONE_D)
    # ahşap çubuk
    bx, by, bw, bh = (W - 70) // 2, 15, 70, 15
    a.rrect(bx, by, bw, bh, OUT)
    a.rect(bx + 1, by + 1, bw - 2, bh - 2, W_FACE)
    a.hline(bx + 1, by + 1, bw - 2, W_HI)
    a.hline(bx + 1, by + bh - 2, bw - 2, W_DK)
    for (nx, ny) in ((bx + 2, by + 2), (bx + bw - 3, by + 2)):
        a.set(nx, ny, GOLD_L)
        a.set(nx, ny + 1, GOLD_D)
    ix, iw = bx + 5, bw - 10
    a.rect(ix - 1, by + 2, iw + 2, 7, OUT)
    fill_bar(a, ix, by + 3, iw, 5, hp, HP_BANDS, TRACK)
    ticks(a, ix, by + 3, iw, 5, 10, OUT, 0.5)
    a.rect(ix - 1, by + 9, iw + 2, 4, OUT)
    fill_bar(a, ix, by + 10, iw, 2, sh, SH_BANDS, EMPTY_BLUE)
    return a


# ---------------------------------------------------------------- O3 Boynuzlu Taç
def world_o3(hp, sh, name=""):
    from protos_top import horn
    W, H = 84, 28
    a = Art(W, H)
    bx, by, bw, bh = 6, 13, 72, 14
    # boynuzlar çerçevenin iki ucundan yükselir
    a.paste(horn(False), 0, by - 10)
    a.paste(horn(True), W - 13, by - 10)
    # kalkan plakası: boynuzların arasında, çerçevenin üstünde
    sx, sw = 18, W - 36
    a.rrect(sx - 1, 6, sw + 2, 8, OUT2)
    a.rect(sx, 7, sw, 6, IRON_D)
    fill_bar(a, sx + 1, 8, sw - 2, 4, sh, SH_BANDS, EMPTY_BLUE)
    # çerçeve
    a.rrect(bx, by, bw, bh, OUT2)
    a.rect(bx + 1, by + 1, bw - 2, bh - 2, IRON_L)
    a.hline(bx + 1, by + 1, bw - 2, IRON_HI)
    a.hline(bx + 1, by + bh - 2, bw - 2, IRON_D)
    a.rect(bx + 4, by + 3, bw - 8, bh - 6, OUT2)
    fill_bar(a, bx + 5, by + 4, bw - 10, bh - 8, hp, HP_BANDS, TRACK)
    ticks(a, bx + 5, by + 4, bw - 10, bh - 8, 10, OUT2, 0.5)
    for nx in (bx + 2, bx + bw - 3):
        a.set(nx, by + 2, GOLD_L)
        a.set(nx, by + bh - 3, GOLD_D)
    return a


# ---------------------------------------------------------------- O4 Sade + Kalkan Noktaları
def world_o4(hp, sh, name=""):
    W, H = 76, 20
    a = Art(W, H)
    a.paste(skull(), 0, 7)
    bx, bw = 12, 62
    # kalkan noktaları (5 hap)
    n, gap = 5, 2
    pw = (bw - gap * (n - 1)) // n
    for i in range(n):
        x = bx + i * (pw + gap)
        lo, hi = i / n, (i + 1) / n
        fill = 0.0 if sh <= lo else (1.0 if sh >= hi else (sh - lo) * n)
        a.rrect(x, 3, pw, 5, OUT2)
        a.rrect(x + 1, 4, pw - 2, 3, EMPTY_BLUE)
        fw = int(round((pw - 2) * fill))
        if fw:
            a.rect(x + 1, 4, fw, 1, BLUE_HI)
            a.rect(x + 1, 5, fw, 2, BLUE)
    # can çubuğu (çift anahat: koyu + kırmızı parıltı)
    a.rect(bx - 2, 8, bw + 4, 9, RED_D)
    a.rect(bx - 1, 9, bw + 2, 7, OUT2)
    fill_bar(a, bx, 10, bw, 5, hp, HP_BANDS, TRACK)
    ticks(a, bx, 10, bw, 5, 4, OUT2, 0.55)
    return a


WORLDS = {
    "O1": ("Demir + Kafatası", world_o1),
    "O2": ("Asma Tabela", world_o2),
    "O3": ("Boynuzlu Taç", world_o3),
    "O4": ("Sade + Kalkan Noktaları", world_o4),
}

if __name__ == "__main__":
    import sys
    out = sys.argv[1]
    bg = Image.new("RGBA", (260 * 2, 4 * 70 * 2), hexc("#5b7a3a"))
    y = 6
    for key, (title, fn) in WORLDS.items():
        art = fn(0.72, 0.55)
        bg.alpha_composite(art.scaled(4), (10, y))
        y += art.h * 4 + 8
    bg = bg.crop((0, 0, 520, y))
    bg.save(out)
    print("ok", bg.size)
