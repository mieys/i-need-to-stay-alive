# Oyuncu paneli "C Gomme Tepsi" (madde 454) DOKULARI - tek uretici:
#   1) hud_dock_tray.png (80x152) + hud_dock_tray_side.png (48x48): madde 391 prototipinin ozgun dokularindan
#      (tools/proto_20261031/dock_pencere/out/tex_C/{dock,side}.png) kopya + TEPSI ICI renk ayari (TRAY_INNER, asagida)
#   2) yan kutunun 9 dilimiyle TAM boyutta parcalar -> kenar, kose basamagi ve ic golge ana tepsiyle birebir:
#        hud_avatar_tray.png  84x84  = DOCK_PORTRAIT (portrenin ARKASINDA, yuz ustte)
#        hud_level_tray.png   54x39  = DOCK_BADGE_RECT boyu (seviye rakami ustte, LevelLabel)
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


if __name__ == "__main__":
    main()
