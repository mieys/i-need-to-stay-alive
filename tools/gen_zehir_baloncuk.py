"""Yaratıktaki ZEHİR DURUM baloncukları (scenes/fx_poison_status.tscn) - KÜÇÜK sürüm (2026-11-11, kullanıcı: "yaratıklar zehirlenince
üstlerinde çıkan baloncuğu küçült, çok dikkat çekiyor").

  python -I tools/gen_zehir_baloncuk.py            -> assets/fx/poison/poison_status_sheet.png (üzerine yazar)
  python -I tools/gen_zehir_baloncuk.py --onizleme -> tools/proto_20261111/sicrayan_zehir/out/baloncuk_onizleme.png (eski | yeni, x6)

Eski sayfanın (üreticisi yoktu; yedek tools/proto_20261111/sicrayan_zehir/out/baloncuk_eski/) DÜZENİ ve PALETİ aynı: 256x256, 48x48 hücre,
satırda 5, 24 kare, 12 fps döngü (poison_status_frames.tres değişmez), iki renk ailesi (sarı-yeşil / nane). Piksel boyu AYNI (sayfa ölçeklenmez,
1 sanat pikseli = eskisiyle aynı dünya birimi - FX yoğunluk kuralı). Değişen: baloncuk çapı 3-7 piksel (eskisi 7-16), aynı anda en çok 2
baloncuk (eskisi 3), yayılım hücrenin ortasında ~18 piksel (eskisi ~40), yükselme ~11 piksel. Döngü dikişsiz: her baloncuk kare (f - başlangıç) mod 24'te.
"""

import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "fx", "poison", "poison_status_sheet.png")
OLD = os.path.join(ROOT, "tools", "proto_20261111", "sicrayan_zehir", "out", "baloncuk_eski", "poison_status_sheet.png")
PREVIEW = os.path.join(ROOT, "tools", "proto_20261111", "sicrayan_zehir", "out", "baloncuk_onizleme.png")

CELL = 48
COLS = 5
FRAMES = 24
SHEET = 256

## Eski sayfadan örneklenen palet: (halka, gölgeli alt-sağ yay, parlama)
FAMILIES = {
    "sari": ((0x9B, 0xD9, 0x2E, 255), (0x4E, 0xB1, 0x34, 255), (0xE9, 0xF9, 0x93, 255)),
    "nane": ((0x53, 0xD9, 0x7F, 255), (0x48, 0xAD, 0x7C, 255), (0xA6, 0xF1, 0x85, 255)),
}

## Elle çizilmiş küçük halkalar (# halka, d gölge yayı, h parlama).
RINGS = {
    3: [".#.",
        "#.#",
        ".d."],
    4: [".##.",
        "#h.#",
        "#..d",
        ".dd."],
    5: [".###.",
        "#h..#",
        "#...d",
        "#...d",
        ".ddd."],
    6: [".####.",
        "#h...#",
        "#....#",
        "#....d",
        "#...dd",
        ".ddd.."],
    7: ["..###..",
        ".#h..#.",
        "#.....#",
        "#.....d",
        "#.....d",
        ".d...d.",
        "..ddd.."],
}
## Patlama: halkanın bir piksel dışında seyrek noktalar (1 kare), sonra iki nokta (1 kare).
POP1 = [(-1, -4), (3, -3), (4, 1), (1, 4), (-3, 3), (-4, -1)]
POP2 = [(-2, -4), (4, 3)]

## (başlangıç karesi, x, aile, [ömür boyunca çap], yükselme pikseli). Ömür = len(çaplar) kare + 2 patlama karesi.
BUBBLES = [
    (0, -5, "sari", [3, 4, 4, 5, 5, 5, 6, 6, 6, 6, 7, 7], 11),
    (8, 5, "nane", [3, 4, 4, 4, 5, 5, 5, 5, 6, 6, 6, 6], 10),
    (16, -1, "nane", [3, 4, 4, 5, 5, 5, 5, 6, 6, 6, 6, 6], 11),
]
BASE_Y = 31  ## doğuş (hücre içi, merkez 24 = yaratığın gövde ortası)


def draw_ring(img, cx, cy, d, fam):
    ring, dark, hi = FAMILIES[fam]
    rows = RINGS[d]
    ox = cx - d // 2
    oy = cy - d // 2
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            col = {"#": ring, "d": dark, "h": hi}.get(ch)
            if col is not None:
                img.putpixel((ox + i, oy + j), col)


def draw_pop(img, cx, cy, pts, fam):
    ring, _dark, hi = FAMILIES[fam]
    for k, (dx, dy) in enumerate(pts):
        img.putpixel((cx + dx, cy + dy), hi if k % 2 == 0 else ring)


def frame(f):
    img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    for start, x, fam, sizes, rise in BUBBLES:
        age = (f - start) % FRAMES
        life = len(sizes)
        cx = CELL // 2 + x
        if age < life:
            cy = BASE_Y - round(rise * age / (life - 1))
            ## hafif yalpalama (1 piksel), yükselen baloncuk düz çizgide gitmesin
            cx += (0, 0, 1, 1, 0, 0, -1, -1)[age % 8] if age > 2 else 0
            draw_ring(img, cx, cy, sizes[age], fam)
        elif age < life + 2:
            cy = BASE_Y - rise - 1
            draw_pop(img, cx, cy, POP1 if age == life else POP2, fam)
    return img


def build():
    sheet = Image.new("RGBA", (SHEET, SHEET), (0, 0, 0, 0))
    for f in range(FRAMES):
        fr = frame(f)
        b = fr.getbbox()
        assert b is None or (b[0] > 0 and b[1] > 0 and b[2] < CELL and b[3] < CELL), "hücre kenarına değiyor: kare %d %s" % (f, b)
        sheet.paste(fr, ((f % COLS) * CELL, (f // COLS) * CELL))
    return sheet


def preview(new):
    old = Image.open(OLD).convert("RGBA")
    k = 6
    bg = (60, 50, 40, 255)
    out = Image.new("RGBA", (CELL * 6 * k, CELL * 2 * k + 8), (30, 26, 22, 255))
    for row, src in enumerate((old, new)):
        for n, f in enumerate((0, 4, 8, 12, 16, 20)):
            cell = src.crop(((f % COLS) * CELL, (f // COLS) * CELL, (f % COLS + 1) * CELL, (f // COLS + 1) * CELL))
            tile = Image.new("RGBA", (CELL, CELL), bg)
            tile.alpha_composite(cell)
            out.paste(tile.resize((CELL * k, CELL * k), Image.NEAREST), (n * CELL * k, row * (CELL * k + 8)))
    out.save(PREVIEW)
    print(PREVIEW)


def main():
    new = build()
    if "--onizleme" in sys.argv:
        preview(new)
        return
    new.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
