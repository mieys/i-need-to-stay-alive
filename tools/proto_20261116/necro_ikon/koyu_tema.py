# Necro 4 skill ikonu (Q/E/R/P) için KOYU tema seçenekleri: yalnız zemin/parıltı tonları (ikon başına ton penceresi, doygun pikseller)
# hedef tona çevrilir ve karartılır; iskelet/el/yüz gibi az doygun figürler ve pasifteki kukulete/eller korunur. Luma oranı korunur.
# python -I koyu_tema.py  -> out/koyu_<secenek>_<ikon>.png + out/koyu_onizleme.png
import colorsys
from PIL import Image, ImageDraw
SK = "../../../assets/skills/necromancer_%s_icon.png"
# ikon: (dosya, ton penceresi merkez, yarı genişlik) - derece
# + doygunluk eşiği (s0, s1) ve parlaklık eşiği v0: Q/R kafatası-el (s<=.35) ve koyu konturlar korunur; E pembe parıltı s~.12 (iskelet tonu pencere dışında)
ICONS = [("Q", "iskelet_cagir", 28, 50, .4, .62, .25), ("E", "hortlak_cagir", 320, 45, .06, .15, 0),
         ("R", "lanetli_kafatasi", 28, 50, .4, .62, .25), ("P", "passive", 115, 70, .22, .5, 0)]
OPTS = [("A", "koyu zehir yesili", 112, 0.55), ("B", "koyu mor", 278, 0.55), ("C", "koyu ruh turkuazi", 168, 0.55)]

def ss(x, a, b):
    t = min(1, max(0, (x - a) / (b - a))); return t * t * (3 - 2 * t)

def recolor(im, center, half, target, dark, s0, s1, v0):
    im = im.convert("RGBA").copy(); px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            dh = (h * 360 - center + 180) % 360 - 180
            w = ss(s, s0, s1) * (1 - ss(abs(dh), half - 12, half + 6)) * (ss(v, v0, v0 + .2) if v0 > 0 else 1)
            if w <= 0: continue
            nh = ((center + dh) * (1 - w) + (target + dh * .35) * w) % 360 / 360  # ton çeşitliliği %35'e sıkışır
            nr, ng, nb = [c * 255 for c in colorsys.hsv_to_rgb(nh, s * (1 - .15 * w), v)]  # zemin %15 daha az doygun (neon değil)
            l0 = .299 * r + .587 * g + .114 * b; l1 = .299 * nr + .587 * ng + .114 * nb
            k = (l0 / l1 if l1 > .5 else 1) * (1 - dark * w)
            px[x, y] = tuple(int(min(255, max(0, c * k))) for c in (nr, ng, nb)) + (a,)
    return im

rows = [("simdi", [Image.open(SK % f).convert("RGBA") for _, f, *_ in ICONS])]
for code, name, tgt, dark in OPTS:
    lst = []
    for key, f, c, hw, s0, s1, v0 in ICONS:
        im = recolor(Image.open(SK % f), c, hw, tgt, dark, s0, s1, v0); im.save("out/koyu_%s_%s.png" % (code, key)); lst.append(im)
    rows.append(("%s %s" % (code, name), lst))
# HUD görünümü: ikon 64 px (oyundaki liste boyu) + büyük 144
W = 4 * 154 + 30 + 4 * 72 + 20
out = Image.new("RGBA", (W, len(rows) * 172 + 8), (34, 30, 38, 255)); d = ImageDraw.Draw(out)
for r, (title, ims) in enumerate(rows):
    y0 = r * 172 + 8; d.text((10, y0), title, fill=(255, 220, 120, 255))
    for c, im in enumerate(ims):
        out.alpha_composite(im, (10 + c * 154, y0 + 16))
        out.alpha_composite(im.resize((64, 64), Image.NEAREST), (10 + 4 * 154 + 20 + c * 72, y0 + 16))
        d.text((10 + c * 154, y0 + 162), "QERP"[c], fill=(200, 200, 200, 255))
out.save("out/koyu_onizleme.png")
