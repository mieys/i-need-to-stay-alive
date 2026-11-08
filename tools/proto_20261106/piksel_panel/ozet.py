# PIKSEL KENARLI PANEL ozeti (2026-11-06): piksel_panel_capture.gd yakalamalarindan yakin (x2, en yakin komsu) karsilastirma.
#   python tools/proto_20261106/piksel_panel/ozet.py
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
FONT = os.path.join(HERE, "..", "..", "..", "assets", "fonts", "m5x7.ttf")
BG = (20, 14, 9)
GOLD = (240, 192, 112)
DIM = (196, 176, 144)
TEXT = (243, 230, 204)
NAMES = {
    "simdi": "ŞU AN (düz kutu, ince pah)",
    "A": "A - Basamaklı Köşe",
    "B": "B - Kabartma",
    "C": "C - Çift Çerçeve",
    "D": "D - Oyma Köşe",
}
DESC = [
    ("A - Basamaklı Köşe", "kenar 1 piksel, köşe piksel basamak"),
    ("B - Kabartma", "A + üstte ışık, altta gölge çizgisi"),
    ("C - Çift Çerçeve", "koyu dış hat + kenar + sert alt gölge"),
    ("D - Oyma Köşe", "köşede kare oyuk, kenar içeri döner"),
    ("", "renkler AYNI (Kısık Ahşap), doku/dither yok"),
    ("", "1 piksel = 3 ekran px (karakterle aynı ızgara)"),
]
CROPS = {
    "pazar": (560, 165, 940, 470),
    "bitti": (355, 58, 735, 392),
}
SCALE = 2
f32 = ImageFont.truetype(FONT, 32)
f48 = ImageFont.truetype(FONT, 48)

for screen, box in CROPS.items():
    cw, ch = (box[2] - box[0]) * SCALE, (box[3] - box[1]) * SCALE
    pad, lab = 16, 40
    cols, rows = 3, 2
    W = cols * cw + (cols + 1) * pad
    H = rows * (ch + lab) + (rows + 1) * pad
    sheet = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(sheet)
    for i, v in enumerate(["simdi", "A", "B", "C", "D"]):
        src = Image.open(os.path.join(OUT, f"{screen}_{v}.png")).convert("RGB")
        crop = src.crop(box).resize((cw, ch), Image.NEAREST)
        cx = pad + (i % cols) * (cw + pad)
        cy = pad + (i // cols) * (ch + lab + pad)
        d.text((cx, cy), NAMES[v], font=f32, fill=GOLD if v != "simdi" else DIM)
        sheet.paste(crop, (cx, cy + lab))
    # 6. hucre: aciklama
    cx = pad + 2 * (cw + pad)
    cy = pad + (ch + lab + pad)
    d.text((cx, cy), "PİKSEL KENAR", font=f48, fill=GOLD)
    y = cy + 70
    for t, s in DESC:
        if t:
            d.text((cx, y), t, font=f32, fill=TEXT)
            y += 34
        d.text((cx + (16 if t else 0), y), s, font=f32, fill=DIM)
        y += 48
    d.text((cx, cy + lab + ch - 40), "yakın görünüş x2", font=f32, fill=DIM)
    p = os.path.join(OUT, f"ozet_{screen}.png")
    sheet.save(p)
    print(p, sheet.size)

# Köşe yakını (x4): her varyant bir sütun, üstte pazar penceresi + kart köşesi, altta Oyun Bitti kuyusu.
ZOOM = 4
KOSE = [("pazar", (626, 168, 686, 252)), ("bitti", (394, 268, 454, 352))]
cw, pad, lab = 60 * ZOOM, 16, 40
W = 5 * cw + 6 * pad
H = lab + sum((b[3] - b[1]) * ZOOM for _, b in KOSE) + (len(KOSE) + 1) * pad + 50
sheet = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(sheet)
for i, v in enumerate(["simdi", "A", "B", "C", "D"]):
    x = pad + i * (cw + pad)
    d.text((x, pad), NAMES[v].split(" (")[0], font=f32, fill=GOLD if v != "simdi" else DIM)
    y = pad + lab
    for screen, box in KOSE:
        src = Image.open(os.path.join(OUT, f"{screen}_{v}.png")).convert("RGB")
        c = src.crop(box)
        c = c.resize((c.width * ZOOM, c.height * ZOOM), Image.NEAREST)
        sheet.paste(c, (x, y))
        y += c.height + pad
d.text((pad, H - 44), "köşe yakını x4 - üst: pazar penceresi + kart, alt: Oyun Bitti kutusu", font=f32, fill=DIM)
p = os.path.join(OUT, "ozet_kose.png")
sheet.save(p)
print(p, sheet.size)
