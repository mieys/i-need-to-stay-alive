# Oyuncu paneli "C Gomme Tepsi" (madde 454) DOKULARI - tek uretici:
#   1) hud_dock_tray.png (80x152) + hud_dock_tray_side.png (48x48): madde 391 prototipinin ozgun dokularindan
#      (tools/proto_20261031/dock_pencere/out/tex_C/{dock,side}.png) kopya + TEPSI ICI renk ayari (TRAY_INNER, asagida)
#   2) yan kutunun 9 dilimiyle TAM boyutta parcalar -> kenar, kose basamagi ve ic golge ana tepsiyle birebir:
#        hud_avatar_tray.png  84x84  = DOCK_PORTRAIT (portrenin ARKASINDA, yuz ustte)
#        hud_level_tray.png   54x39  = DOCK_BADGE_RECT boyu (seviye rakami ustte, LevelLabel)
#   4) madde 483 (sol ust konsol "B Tek Konsol"): hud_console_well.png (gomme kuyu, 9 dilim 9/9/9/12; alt satir ahsap dudagi),
#      hud_console_plate{,_hover,_pressed}.png (kabarik ahsap dugme, 9 dilim 9), hud_icon_bag.png (renkli canta 12x11 sanat px x3)
#   3) hud_minimap_tray.png 48x48 (9 dilim payi 12): yan kutunun yalniz CERCEVESI (dis hat + ahsap + koyu ic cizgi), ici SAYDAM -
#      masaustu kare minimapin cercevesi (madde 478; hud.gd _apply_tray_minimap, harita icini doldurur)
# Boyutlar hud.gd'deki dikdortgenlerle ayni (panel yereli, dock 0,92 olcekli; doku 1:1 cizilir).
#   python -I tools/gen_dock_tray_parts.py   (sonra Godot --headless --import)
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KIT = os.path.join(ROOT, "assets", "ui", "kit")
SRC = os.path.join(ROOT, "tools", "proto_20261031", "dock_pencere", "out", "tex_C")
M = 18  # 9 dilim payi (dock_side ile ayni)
FRAME = 12  # yan kutunun cercevesi: dis hat 3 + ahsap 6 + koyu ic cizgi 3 (ekran px); ici tepsi

## Tepsi ICI (kenar/cerceve degil): ozgun renk -> oyundaki renk. 2026-11-08 (madde 466, kullanici: "skil barinin rengi biraz koyu gibi acar
## misin biraz ic rengini"): dolgu, ic golge ve alt dudak birlikte, aralarindaki fark korunarak HUD levha icine (HudTheme.PANEL #5a4734)
## dogru ~%45 acildi. Ozgun degerlere donmek icin sag tarafi sol tarafla ayni yap.
TRAY_INNER = {
    (0x35, 0x26, 0x1a): (0x46, 0x35, 0x26),  # dolgu
    (0x2a, 0x1d, 0x13): (0x3a, 0x2b, 0x1e),  # ust/sol ic golge
    (0x43, 0x30, 0x20): (0x53, 0x3f, 0x2c),  # alt dudak
}


def recolor(im):
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            new = TRAY_INNER.get((r, g, b))
            if new and a > 0:
                px[x, y] = new + (a,)
    return out


def nine(src, w, h):
    sw, sh = src.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    xs = [(0, M, 0, M), (M, sw - M, M, w - M), (sw - M, sw, w - M, w)]
    ys = [(0, M, 0, M), (M, sh - M, M, h - M), (sh - M, sh, h - M, h)]
    for sx0, sx1, dx0, dx1 in xs:
        for sy0, sy1, dy0, dy1 in ys:
            if dx1 <= dx0 or dy1 <= dy0:
                continue
            part = src.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.NEAREST)
            out.paste(part, (dx0, dy0))
    return out


def main():
    dock = recolor(Image.open(os.path.join(SRC, "dock.png")).convert("RGBA"))
    side = recolor(Image.open(os.path.join(SRC, "side.png")).convert("RGBA"))
    dock.save(os.path.join(KIT, "hud_dock_tray.png"))
    side.save(os.path.join(KIT, "hud_dock_tray_side.png"))
    print("yazildi hud_dock_tray.png / hud_dock_tray_side.png")
    for name, w, h in (("hud_avatar_tray.png", 84, 84), ("hud_level_tray.png", 54, 39)):
        nine(side, w, h).save(os.path.join(KIT, name))
        print("yazildi", name, w, h)
    mm = side.copy()
    px = mm.load()
    for y in range(FRAME, side.height - FRAME):
        for x in range(FRAME, side.width - FRAME):
            px[x, y] = (0, 0, 0, 0)
    mm.save(os.path.join(KIT, "hud_minimap_tray.png"))
    print("yazildi hud_minimap_tray.png")
    console_parts()


# --- madde 483: sol ust konsol parcalari (renkler scripts/hud_theme.gd ile AYNI) -------------------------------------------------------
OUTLINE = (0x20, 0x15, 0x0d, 255)
RIM = (0x6a, 0x4a, 0x30, 255)
RIM_HI = (0x86, 0x62, 0x3f, 255)
RIM_LO = (0x4b, 0x33, 0x20, 255)
DOCK_INSET = (0x1c, 0x12, 0x0b, 255)
DEEP = (0x14, 0x0e, 0x09, 255)
PROF = {0: [], 1: [1], 2: [2, 1]}
BAG = ["...oooooo...", "..o......o..", "..o......o..", ".oooooooooo.", "o1111111112o", "o1222222223o", "ooooo44ooooo",
       "o1222442223o", "o1222222223o", "o2333333333o", ".oooooooooo."]
BAG_PAL = {"o": (0x2e, 0x1b, 0x0c, 255), "1": (0xe8, 0xc4, 0x8c, 255), "2": (0xc0, 0x8a, 0x50, 255), "3": (0x8a, 0x5a, 0x30, 255),
           "4": (0xf6, 0xd2, 0x7e, 255)}


def rr(px, x0, y0, w, h, col, k):
    prof = PROF[k]
    for y in range(h):
        ins = 0
        if y < len(prof):
            ins = prof[y]
        elif h - 1 - y < len(prof):
            ins = prof[h - 1 - y]
        for x in range(x0 + ins, x0 + w - ins):
            px[x, y0 + y] = col


def x3(art):
    return art.resize((art.width * 3, art.height * 3), Image.NEAREST)


def console_parts():
    # gomme kuyu: 9x9 sanat + altta 1 satir ahsap dudagi (RIM_HI %55)
    art = Image.new("RGBA", (9, 10), (0, 0, 0, 0))
    px = art.load()
    rr(px, 0, 0, 9, 9, OUTLINE, 2)
    rr(px, 1, 1, 7, 7, DOCK_INSET, 1)
    for x in range(2, 7):
        px[x, 1] = DEEP
        px[x, 9] = RIM_HI[:3] + (140,)
    x3(art).save(os.path.join(KIT, "hud_console_well.png"))
    # kabarik ahsap dugme: normal / ustunde (bir ton acik) / basili (koyu, isik altta)
    for name, fill, hi, lo in (("", RIM, RIM_HI, RIM_LO), ("_hover", RIM_HI, (0xa0, 0x7a, 0x52, 255), RIM),
                               ("_pressed", RIM_LO, RIM_LO, RIM)):
        art = Image.new("RGBA", (9, 9), (0, 0, 0, 0))
        px = art.load()
        rr(px, 0, 0, 9, 9, OUTLINE, 2)
        rr(px, 1, 1, 7, 7, fill, 1)
        for x in range(2, 7):
            px[x, 1] = hi
            px[x, 7] = lo
        for y in range(2, 6):
            px[1, y] = hi
        x3(art).save(os.path.join(KIT, "hud_console_plate%s.png" % name))
    art = Image.new("RGBA", (12, 11), (0, 0, 0, 0))
    px = art.load()
    for y, row in enumerate(BAG):
        for x, ch in enumerate(row):
            if ch in BAG_PAL:
                px[x, y] = BAG_PAL[ch]
    x3(art).save(os.path.join(KIT, "hud_icon_bag.png"))
    print("yazildi hud_console_well / plate / plate_hover / plate_pressed / hud_icon_bag")


if __name__ == "__main__":
    main()
