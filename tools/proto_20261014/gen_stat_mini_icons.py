"""Mini stat paneli için 16x16 piksel simgeler (PROTOTİP, 2026-10-14).

Sıfırdan tasarım: LoL'den ve eski level-up ikonlarından referans alınmadı. 1 sanat pikseli = 1 ekran pikseli (HUD'daki
32 px eşya ikonlarıyla aynı yoğunluk). Dolgu 14x14 alanda çizilir, 1 px koyu kontur dışarıya kendiliğinden eklenir
(4 komşu -> köşeler yuvarlak). 'x' / 'z' harfleri konturSUZ (hız çizgisi, ışıltı).

Çıktı: out/stat_ikon/<id>.png (16x16) + out/stat_ikon_onizleme.png (x8, adlı) + out/stat_ikon_1x.png.
Kullanım: python tools/proto_20261014/gen_stat_mini_icons.py
"""
import math
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out", "stat_ikon")

PAL = {
    "o": "#1b1220",  # kontur
    "K": "#4f5a6e", "S": "#8e9bb2", "L": "#cfd8e6", "W": "#ffffff",  # çelik
    "w": "#4a2c16", "b": "#7a4c26", "B": "#b07a40",  # ahşap
    "l": "#5a3418", "m": "#8c5428", "q": "#c08048",  # deri
    "r": "#7a1426", "R": "#c4283a", "P": "#f0606a", "p": "#ffb8b8",  # kırmızı
    "g": "#1f5a2a", "G": "#3a9a3e", "H": "#7ad45a", "h": "#c8f59a",  # yeşil
    "y": "#8a5a10", "Y": "#d99a22", "Z": "#ffd34a", "a": "#fff3b0",  # altın
    "u": "#173a7a", "U": "#2f6fd0", "V": "#62a8f0", "v": "#bfe4ff",  # mavi
    "c": "#1f6f80", "C": "#3fb5c8", "D": "#9ae8f0",  # camgöbeği
    "n": "#8a3a10", "N": "#e86a1e", "M": "#ffa040",  # turuncu
    "k": "#2a2f45",  # koyu cam
    "x": "#ffffff", "z": "#fff3b0", "e": "#9ae8f0",  # konturSUZ çizgiler
}
NO_OUTLINE = set("xze")


def grid():
    return [["." for _ in range(14)] for _ in range(14)]


def from_rows(rows):
    assert len(rows) == 14, rows
    g = grid()
    for y, r in enumerate(rows):
        assert len(r) == 14, (y, r)
        for x, ch in enumerate(r):
            g[y][x] = ch
    return g


def put(g, x, y, ch):
    if 0 <= x < 14 and 0 <= y < 14:
        g[y][x] = ch


def shade_mask(g, mask, dark, mid, light, hi=None, hi_pts=()):
    """Maske içini 3 tonla boya: sol/üst kenar açık, sağ/alt kenar koyu."""
    def inside(x, y):
        return (x, y) in mask
    for (x, y) in mask:
        ch = mid
        if not inside(x + 1, y) or not inside(x, y + 1):
            ch = dark
        elif not inside(x - 1, y) or not inside(x, y - 1):
            ch = light
        put(g, x, y, ch)
    if hi:
        for (x, y) in hi_pts:
            put(g, x, y, hi)


def shield_mask(x0=1, x1=12, top=0, bottom=13, straight=6):
    m = set()
    cx = (x0 + x1) / 2.0
    half = (x1 - x0) / 2.0 + 0.5
    for y in range(top, bottom + 1):
        if y <= straight:
            w = half
        else:
            t = (y - straight) / float(bottom - straight + 0.6)
            w = half * math.sqrt(max(0.0, 1.0 - t * t))
        for x in range(14):
            if abs(x + 0.5 - (cx + 0.5)) <= w:
                m.add((x, y))
    return m


def heart_mask(scale=1.0, ox=0.0, oy=0.0):
    m = set()
    for y in range(14):
        for x in range(14):
            px = ((x + 0.5) - 7.0 - ox) / (6.6 * scale)
            py = -((y + 0.5) - 6.4 - oy) / (6.6 * scale)
            if (px * px + py * py - 1) ** 3 - px * px * py ** 3 * 1.0 <= 0 and py > -1.25:
                m.add((x, y))
    return m


# ---------------------------------------------------------------------------------------------- simgeler

def damage():  # Savaş baltası (hilal ağız, arka diken)
    return from_rows([
        "....Bw..LW....",
        "....BbKSSLW...",
        "....BbKSSSLW..",
        "...SBbKSSSSLW.",
        "..LSBbKSSSSLW.",
        "...KBbKSSSSLW.",
        "....BbKSSSLW..",
        "....BbKSSLW...",
        "....Bb..LW....",
        "....Bb........",
        "....Bb........",
        "....Bb........",
        "....Yy........",
        "....Yy........",
    ])


def fire_rate():  # Hızla saplanan hançer
    return from_rows([
        "..............",
        "..............",
        "zz.zzzz.......",
        ".....Y........",
        ".....Y........",
        ".YqqqYLLLLLLW.",
        ".ylllySSSSSSKW",
        ".....y........",
        ".....y........",
        "..............",
        "zzz.zzzz......",
        "..............",
        "..............",
        "..............",
    ])


def crit_chance():  # Okun saplandığı hedef
    g = grid()
    cx, cy = 6.0, 7.5
    for y in range(14):
        for x in range(14):
            d = math.hypot(x + 0.5 - (cx + 0.5), y + 0.5 - cy)
            if d <= 1.6:
                put(g, x, y, "R")
            elif d <= 3.0:
                put(g, x, y, "W")
            elif d <= 4.5:
                put(g, x, y, "R")
            elif d <= 6.0:
                put(g, x, y, "L")
    for (x, y) in [(2, 9), (3, 10), (4, 11)]:  # alt sağ gölge kuşağı
        pass
    # ok: merkezden sağ üste
    for i, (x, y) in enumerate([(7, 7), (8, 6), (9, 5), (10, 4), (11, 3), (12, 2)]):
        put(g, x, y, "o" if i == 0 else "b")
    for (x, y, ch) in [(12, 0, "P"), (13, 1, "P"), (13, 0, "R"), (11, 1, "P"), (13, 2, "R"), (12, 1, "R")]:
        put(g, x, y, ch)
    put(g, 6, 7, "P")
    return g


def crit_damage():  # Patlama yıldızı + ünlem
    g = grid()
    cx, cy = 7.0, 7.0
    for y in range(14):
        for x in range(14):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            a = math.atan2(dy, dx) + math.pi / 8.0
            r = math.hypot(dx, dy)
            spike = abs(math.cos(4 * a))
            if r <= 4.6 + 2.6 * spike ** 4:
                put(g, x, y, "a" if r < 2.6 else ("Z" if r < 4.0 else ("M" if r < 5.4 else "N")))
    for (x, y) in [(6, 3), (7, 3), (6, 4), (7, 4), (6, 5), (7, 5), (6, 6), (7, 6), (6, 7), (7, 7), (6, 9), (7, 9), (6, 10), (7, 10)]:
        put(g, x, y, "o")
    return g


def cooldown():  # Camgöbeği kumlu kum saati
    return from_rows([
        ".wBBBBBBBBBBw.",
        "..bbbbbbbbbb..",
        "..SkkkkkkkkL..",
        "...SDDCCCCL...",
        "....SDCCCL....",
        ".....SCCL.....",
        "......SL......",
        "......SL......",
        ".....SkeL.....",
        "....SkkekL....",
        "...SkkDCkkL...",
        "..SDCCCCCCCL..",
        "..bbbbbbbbbb..",
        ".wBBBBBBBBBBw.",
    ])


def lifesteal():  # Vampir dişleri + damlayan kan
    return from_rows([
        "...rRRRRRRr...",
        ".rRPPPPPPPPRr.",
        ".rRRRRRRRRRRr.",
        "..WL......WL..",
        "..WL......WL..",
        "..WS......WS..",
        "...S......S...",
        "..........P...",
        ".........PRr..",
        "........PRRRr.",
        "........PpRRr.",
        "........PRRRr.",
        ".........rrr..",
        "..............",
    ])


def dodge():  # Rüzgâr esintisi (konturSUZ çizgiler, koyu levhada)
    return from_rows([
        "..............",
        ".........ee...",
        "........e..e..",
        "...........e..",
        "xxxxxxxxxxe...",
        "..............",
        "..xxxxxxxxxxx.",
        "..............",
        "xxxxxxxxxe....",
        "..........e...",
        ".....e....e...",
        "......eeee....",
        "..............",
        "..............",
    ])


def speed():  # Hız çizgili çizme
    return from_rows([
        "..............",
        "...YYYYYY.....",
        "...qqmmml.....",
        "x..qqmmml.....",
        "...qqmmml.....",
        "xx.qqmmml.....",
        "...qqmmml.....",
        "x..qqmmml.....",
        "...qqmmmmll...",
        "xx.qqqmmmmml..",
        "...qqqqmmmmml.",
        "..KKKKKKKKKKK.",
        "..............",
        "..............",
    ])


def shield_pen():  # Mızrak ucu delip geçmiş kalkan
    g = grid()
    m = shield_mask(0, 10, 1, 13, 6)
    shade_mask(g, m, "K", "S", "L")
    for (x, y) in [(6, 1), (5, 2), (5, 3), (4, 4), (4, 5), (3, 6), (3, 7), (2, 8)]:
        put(g, x, y, "o")
    # mızrak: sağ üstten sola aşağı, ucu kalkanın içinden çıkar
    for (x, y) in [(13, 0), (12, 1), (11, 2), (10, 3), (9, 4)]:
        put(g, x, y, "b")
    for (x, y, ch) in [(8, 5, "Z"), (7, 6, "Z"), (8, 6, "Y"), (7, 5, "a"), (6, 7, "Z"), (7, 7, "Y"), (5, 8, "Y"), (6, 8, "y")]:
        put(g, x, y, ch)
    return g


def range_():  # Gerili yay + ok
    g = grid()
    # yay kolu (sağa doğru kavis)
    for y in range(14):
        t = y / 13.0
        x = 4 + 5.2 * math.sin(math.pi * t)
        xi = int(round(x))
        put(g, xi, y, "B")
        put(g, xi + 1, y, "b")
    # kiriş (konturSUZ, geriye çekilmiş)
    for y in range(14):
        t = abs(y - 6.5) / 6.5
        put(g, int(round(1 + 3 * t)), y, "x")
    # ok
    for x in range(1, 12):
        put(g, x, 6, "b")
        put(g, x, 7, "w") if False else None
    for (x, y, ch) in [(12, 6, "L"), (13, 6, "W"), (11, 5, "S"), (12, 5, "L"), (11, 7, "K"), (12, 7, "S"), (0, 5, "R"), (1, 5, "R"), (0, 7, "r"), (1, 7, "r")]:
        put(g, x, y, ch)
    return g


def _blue_shield():
    g = grid()
    m = shield_mask(1, 12, 0, 13, 6)
    shade_mask(g, m, "u", "U", "V")
    for (x, y) in [(2, 1), (3, 1), (2, 2)]:
        put(g, x, y, "v")
    return g


def shield_prot():  # Büyülü kalkan: ortada dört köşeli ışıltı
    g = _blue_shield()
    for (x, y, ch) in [(6, 2, "v"), (6, 3, "W"), (6, 4, "W"), (3, 5, "v"), (4, 5, "W"), (5, 5, "W"), (6, 5, "W"),
                       (7, 5, "W"), (8, 5, "W"), (9, 5, "v"), (6, 6, "W"), (6, 7, "W"), (6, 8, "v"), (5, 4, "v"), (7, 4, "v"),
                       (5, 6, "v"), (7, 6, "v")]:
        put(g, x, y, ch)
    return g


def shield_amount():  # Artı işaretli kalkan
    g = _blue_shield()
    for (x, y) in [(6, 2), (7, 2), (6, 3), (7, 3), (4, 4), (5, 4), (6, 4), (7, 4), (8, 4), (9, 4),
                   (4, 5), (5, 5), (6, 5), (7, 5), (8, 5), (9, 5), (6, 6), (7, 6), (6, 7), (7, 7)]:
        put(g, x, y, "W")
    return g


def shield_regen():  # Döngü oklu kalkan
    g = _blue_shield()
    for (x, y) in [(5, 2), (6, 2), (7, 2), (4, 3), (3, 4), (3, 5), (3, 6), (4, 7), (5, 8), (6, 8), (7, 8),
                   (8, 7), (9, 6), (8, 1), (8, 2), (8, 3), (9, 2), (10, 2), (9, 3)]:
        put(g, x, y, "W")
    return g


def health_regen():  # Kalp + yeşil yükselen ok
    g = from_rows([
        "..............",
        "..PPRr..PRRr..",
        ".PpPRRrPRRRRr.",
        ".PpPRRRRRRRRr.",
        ".PPRRRRRRRRRr.",
        ".PRRRRRRRRRRr.",
        "..RRRRRRRRRr..",
        "...RRRRRRRr...",
        "....RRRRRr....",
        ".....RRRr.....",
        "......Rr......",
        "..............",
        "..............",
        "..............",
    ])
    arrow = {(11, 7): "H", (10, 8): "H", (11, 8): "H", (12, 8): "G", (9, 9): "H", (10, 9): "H", (11, 9): "H",
             (12, 9): "G", (13, 9): "G", (11, 10): "H", (12, 10): "G", (11, 11): "H", (12, 11): "G", (11, 12): "H", (12, 12): "g"}
    for (x, y) in list(arrow):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if q not in arrow:
                put(g, q[0], q[1], "o")
    for (x, y), ch in arrow.items():
        put(g, x, y, ch)
    return g


def heal_power():  # Şifa iksiri
    return from_rows([
        ".....wbbw.....",
        ".....bBBb.....",
        "......LS......",
        "......LS......",
        ".....LLSS.....",
        "...LLkkkkSS...",
        "..LkkkkkkkkS..",
        "..LhHHHHHHGS..",
        ".LhHHaHHHHGGS.",
        ".LHHHHHHHGGgS.",
        ".LHHHHHHGGGgS.",
        "..LGGGGGGGgS..",
        "...SgggggggS..",
        ".....SSSS.....",
    ])


def luck():  # Uğurlu nal
    return from_rows([
        "..............",
        "...aZY..YZZy..",
        "..aZYo..oZZy..",
        "..ZZy....YZy..",
        ".aZYo....oZZy.",
        ".aZY......ZZy.",
        ".aZY......YZy.",
        ".aZY......YZy.",
        ".aZZY....YZZy.",
        "..aZZY..YZZy..",
        "..aZZZYYZZZy..",
        "...aZZZZZZy...",
        "....YYyyyy....",
        "..............",
    ])


ICONS = [
    ("damage", "Saldırı Gücü", damage),
    ("fire_rate", "Saldırı Hızı", fire_rate),
    ("crit_chance", "Kritik Şansı", crit_chance),
    ("crit_damage", "Kritik Hasarı", crit_damage),
    ("cooldown_reduction", "Bekleme Azaltma", cooldown),
    ("lifesteal", "Can Çalma", lifesteal),
    ("dodge", "Sıvışma", dodge),
    ("speed", "Hareket Hızı", speed),
    ("shield_pen_percent", "Kalkan Delme", shield_pen),
    ("range", "Menzil", range_),
    ("shield_protection", "MK Soğurma", shield_prot),
    ("shield_amount", "MK Miktarı", shield_amount),
    ("shield_regen", "MK Yenilenmesi", shield_regen),
    ("health_regen", "Can Yenilenmesi", health_regen),
    ("heal_power", "İyileştirme Gücü", heal_power),
    ("luck", "Şans", luck),
]


def render(g):
    """14x14 dolgu -> 16x16 RGBA, dışa 4 komşu kontur."""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    filled = set()
    for y in range(14):
        for x in range(14):
            ch = g[y][x]
            if ch != ".":
                img.putpixel((x + 1, y + 1), Image.new("RGBA", (1, 1), PAL[ch]).getpixel((0, 0)))
                if ch not in NO_OUTLINE:
                    filled.add((x + 1, y + 1))
    for y in range(16):
        for x in range(16):
            if (x, y) in filled or img.getpixel((x, y))[3] > 0:
                continue
            if any((x + dx, y + dy) in filled for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                img.putpixel((x, y), Image.new("RGBA", (1, 1), PAL["o"]).getpixel((0, 0)))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    imgs = []
    for key, name, fn in ICONS:
        im = render(fn())
        im.save(os.path.join(OUT, key + ".png"))
        imgs.append((name, im))
    z = 8
    cols = 8
    cell_w, cell_h = 16 * z + 40, 16 * z + 34
    sheet = Image.new("RGBA", (cols * cell_w + 20, 2 * cell_h + 20), "#2a1a10")
    d = ImageDraw.Draw(sheet)
    for i, (name, im) in enumerate(imgs):
        x = 20 + (i % cols) * cell_w
        y = 14 + (i // cols) * cell_h
        d.rectangle([x - 4, y - 4, x + 16 * z + 3, y + 16 * z + 3], fill="#211409")
        sheet.alpha_composite(im.resize((16 * z, 16 * z), Image.NEAREST), (x, y))
        d.text((x, y + 16 * z + 8), name, fill="#f7eed6")
    sheet.save(os.path.join(HERE, "out", "stat_ikon_onizleme.png"))
    strip = Image.new("RGBA", (16 * 20 + 8, 28), "#211409")
    for i, (_, im) in enumerate(imgs):
        strip.alpha_composite(im, (4 + i * 20, 6))
    strip = strip.resize((strip.width * 3, strip.height * 3), Image.NEAREST)
    strip.save(os.path.join(HERE, "out", "stat_ikon_1x.png"))


if __name__ == "__main__":
    main()
