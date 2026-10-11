"""2026-10-10 yeni eşyaların ikonları (kullanıcının "Yeni eşyalar.txt"i ikon vermedi) -> assets/items/<anahtar>.png, 32x32.
Stil ve yardımcılar tools/gen_item_icons.py'den (1 px koyu kontur, 4-6 tonlu rampa, ışık sol üstten).
Çalıştır: python -I tools/gen_item_icons_2.py [--preview <png>]
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_item_icons as G  # noqa: E402

N = G.N
Icon, ramp, ellipse, ring, poly, thick_line, rect = G.Icon, G.ramp, G.ellipse, G.ring, G.poly, G.thick_line, G.rect


def savasci_bileyi():  ## bileği taşı + üstünde parlayan kılıç ağzı
    ic = Icon()
    stone = ramp("#8a8f99", 6)
    blade = ramp("#d8e2ee", 6)
    ic.shade_mask(poly([(4, 22), (24, 12), (28, 18), (8, 28)]), stone, "stone")
    ic.shade_mask(thick_line(9, 9, 25, 2, 4), blade, "blade", gloss=[(12, 7), (15, 6), (18, 5)])
    ic.shade_mask(rect(5, 10, 9, 12), ramp("#7a4a22", 5), "hilt")
    for (x, y) in [(26, 6), (27, 4), (24, 9), (28, 8)]:
        ic.put(x, y, (255, 230, 140), "spark")
    ic.outline({"stone": (24, 26, 32), "blade": (30, 38, 52), "hilt": (34, 18, 6), "spark": (70, 50, 10)})
    return ic


def sifa_feneri():  ## yeşil-altın ışık saçan fener
    ic = Icon()
    brass = ramp("#c99a3a", 6)
    glow = ramp("#9ff0a8", 6, dark=0.6, light=1.25)
    ic.shade_mask(ring(16, 4, 3.5, 3.0, 1.4), brass, "brass")
    ic.shade_mask(rect(10, 7, 22, 9), brass, "brass")
    ic.shade_mask(rect(11, 10, 21, 23), glow, "glass", gloss=[(13, 12), (13, 13), (13, 14)])
    for x in (11, 16, 21):
        ic.shade_mask(rect(x, 10, x, 23), brass, "brass")
    ic.shade_mask(rect(9, 24, 23, 27), brass, "brass")
    for (x, y) in [(6, 14), (26, 15), (5, 19), (27, 20), (16, 30)]:
        ic.put(x, y, (200, 255, 200), "spark")
    ic.outline({"brass": (44, 26, 6), "glass": (20, 60, 30), "spark": (30, 70, 40)})
    return ic


def anka_muhru():  ## kırmızı mühür mumu üstünde turuncu anka silüeti
    ic = Icon()
    wax = ramp("#b8322a", 6)
    bird = ramp("#ffb040", 6, dark=0.55, light=1.3)
    ic.shade_mask(ellipse(16, 17, 12.5, 12.0), wax, "wax", gloss=[(9, 9), (10, 8)])
    ic.shade_mask(poly([(16, 9), (18, 14), (25, 11), (21, 17), (24, 23), (17, 20), (16, 26), (15, 20), (8, 23), (11, 17), (7, 11), (14, 14)]),
                  bird, "bird")
    ic.outline({"wax": (50, 8, 6), "bird": (90, 40, 6)})
    return ic


def bilgenin_pusulasi():  ## pirinç pusula, mavi kadran, kırmızı-beyaz iğne
    ic = Icon()
    brass = ramp("#c99a3a", 6)
    dial = ramp("#2e5f9a", 6)
    ic.shade_mask(ellipse(16, 17, 13, 13), brass, "brass")
    ic.shade_mask(ellipse(16, 17, 10, 10), dial, "dial")
    ic.shade_mask(ring(16, 2, 3, 2.4, 1.2), brass, "brass")
    ic.shade_mask(poly([(16, 9), (18, 17), (16, 17), (14, 17)]), ramp("#e04040", 5), "needle")
    ic.shade_mask(poly([(16, 25), (14, 17), (16, 17), (18, 17)]), ramp("#e8e8f0", 5), "needle_w")
    for (x, y) in [(16, 8), (25, 17), (16, 26), (7, 17)]:
        ic.put(x, y, (240, 220, 140), "mark")
    ic.put(16, 17, (255, 240, 180), "mark")
    ic.outline({"brass": (44, 26, 6), "dial": (10, 22, 44), "needle": (60, 10, 10), "needle_w": (40, 40, 50), "mark": (60, 50, 20)})
    return ic


def ruzgar_yuruyen_cizmeleri():  ## turkuaz çizme + rüzgar çizgileri
    ic = Icon()
    boot = ramp("#2fa8a0", 6)
    sole = ramp("#4a3020", 5)
    ic.shade_mask(poly([(12, 3), (21, 3), (21, 19), (27, 21), (28, 26), (11, 26)]), boot, "boot", gloss=[(14, 6), (14, 8), (14, 10)])
    ic.shade_mask(rect(11, 26, 28, 28), sole, "sole")
    ic.shade_mask(rect(12, 3, 21, 5), ramp("#e8d27a", 5), "cuff")
    wind = ramp("#cff4ff", 5)
    for (x0, y, ln) in [(1, 9, 7), (3, 14, 6), (0, 19, 8), (2, 24, 6)]:
        for i in range(ln):
            ic.put(x0 + i, y, wind[1 + min(3, i)], "wind")
    ic.outline({"boot": (6, 40, 38), "sole": (20, 10, 4), "cuff": (60, 46, 6), "wind": (30, 60, 80)})
    return ic


def kanli_bicer():  ## kızıl ağızlı tırpan
    ic = Icon()
    shaft = ramp("#5a3a24", 5)
    blade = ramp("#c23434", 6, dark=0.35, light=1.3)
    ic.shade_mask(thick_line(7, 29, 22, 4, 2.6), shaft, "shaft")
    ic.shade_mask(poly([(20, 3), (30, 8), (28, 13), (22, 9), (12, 9), (16, 5)]), blade, "blade", gloss=[(18, 6), (21, 5), (24, 6)])
    for (x, y) in [(13, 12), (12, 15), (14, 17)]:
        ic.put(x, y, (200, 30, 30), "drop")
    ic.outline({"shaft": (24, 12, 4), "blade": (50, 6, 8), "drop": (60, 6, 6)})
    return ic


def ahenk_bastiyonu():  ## mavi-altın kule kalkanı
    ic = Icon()
    face = ramp("#3d6fb8", 6)
    rim = ramp("#d9b04a", 6)
    outer = poly([(6, 3), (26, 3), (26, 18), (16, 30), (6, 18)])
    inner = poly([(9, 6), (23, 6), (23, 17), (16, 26), (9, 17)])
    ic.shade_mask(outer - inner, rim, "rim")
    ic.shade_mask(inner, face, "face", gloss=[(11, 8), (12, 8), (11, 9)])
    ic.shade_mask(rect(15, 8, 17, 23), rim, "rim")
    ic.shade_mask(rect(10, 13, 22, 15), rim, "rim")
    ic.outline({"rim": (48, 30, 6), "face": (10, 24, 50)})
    return ic


def kiyamet_bicagi():  ## kara kılıç, kızıl çatlaklı ağız ve parıltı
    ic = Icon()
    blade = ramp("#3a3442", 6)
    hilt = ramp("#8a1e1e", 5)
    ic.shade_mask(poly([(27, 2), (30, 5), (12, 23), (9, 20)]), blade, "blade", gloss=[(25, 5), (22, 8), (19, 11)])
    ic.shade_mask(thick_line(6, 17, 15, 26, 3), ramp("#b8a050", 5), "guard")
    ic.shade_mask(thick_line(4, 28, 9, 23, 3), hilt, "hilt")
    for (x, y) in [(24, 6), (21, 9), (18, 12), (15, 15)]:
        ic.put(x, y, (255, 70, 40), "crack")
    for (x, y) in [(29, 1), (28, 9), (20, 4)]:
        ic.put(x, y, (255, 120, 80), "glow")
    ic.outline({"blade": (10, 6, 14), "guard": (40, 30, 6), "hilt": (30, 4, 4), "crack": (70, 10, 6), "glow": (70, 20, 10)})
    return ic


ICONS = {
    "savasci_bileyi": savasci_bileyi, "sifa_feneri": sifa_feneri, "anka_muhru": anka_muhru, "bilgenin_pusulasi": bilgenin_pusulasi,
    "ruzgar_yuruyen_cizmeleri": ruzgar_yuruyen_cizmeleri, "kanli_bicer": kanli_bicer, "ahenk_bastiyonu": ahenk_bastiyonu,
    "kiyamet_bicagi": kiyamet_bicagi,
}


def main():
    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "items")
    ims = {}
    for key, fn in ICONS.items():
        im = fn().image()
        im.save(os.path.join(out_dir, key + ".png"))
        ims[key] = im
    if "--preview" in sys.argv:
        path = sys.argv[sys.argv.index("--preview") + 1]
        sc = 8
        out = Image.new("RGBA", (4 * (N * sc + 8), 2 * (N * sc + 8)), (60, 60, 70, 255))
        for i, k in enumerate(ims):
            out.alpha_composite(ims[k].resize((N * sc, N * sc), Image.NEAREST), ((i % 4) * (N * sc + 8), (i // 4) * (N * sc + 8)))
        out.save(path)
    print("ok", len(ims))


if __name__ == "__main__":
    main()
