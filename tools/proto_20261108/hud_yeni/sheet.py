# OYUN ICI ARAYUZ prototipleri ozet sayfasi (2026-11-08). Girdi: out/simdi.png + out/proto_{A,B,C,D}.png (run.ps1).
#   python -I tools/proto_20261108/hud_yeni/sheet.py
# Cikti: out/ozet.png (5 kare yarim boy, kucuk boyda siluet karsilastirmasi) + out/yakin_<X>.png (alt / ust seritler 1:1).
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
FONT = os.path.join(HERE, "..", "..", "..", "assets", "fonts", "m5x7.ttf")
BG = (20, 14, 9)
INK = (243, 230, 204)
GOLD = (240, 192, 112)

NAMES = [
    ("simdi", "ŞU AN"),
    ("proto_A", "A - Araç Çubuğu (açık meşe)"),
    ("proto_B", "B - Üst Kuşak (koyu ceviz, kutusuz)"),
    ("proto_C", "C - Kartlar (parşömen bej)"),
    ("proto_D", "D - Kütük Kiriş (ekran boyu)"),
]


def font(sz):
    return ImageFont.truetype(FONT, sz)


def label(d, xy, text, sz=32, col=INK):
    d.fontmode = "1"
    d.text(xy, text, font=font(sz), fill=col)


def ozet(lines=None):
    tw, th = 960, 540
    pad, lab = 12, 40
    cols, rows = 2, 3
    W = cols * tw + (cols + 1) * pad
    H = rows * (th + lab) + (rows + 1) * pad
    sheet = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(sheet)
    for i, (fn, title) in enumerate(NAMES):
        p = os.path.join(OUT, fn + ".png")
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGB").resize((tw, th), Image.LANCZOS)
        c, r = i % cols, i // cols
        x = pad + c * (tw + pad)
        y = pad + r * (th + lab + pad)
        label(d, (x, y + 2), title, 32, GOLD if fn != "simdi" else INK)
        sheet.paste(im, (x, y + lab))
    # bos hucre: kisa aciklama
    x, y = pad + 1 * (tw + pad), pad + 2 * (th + lab + pad)
    lines = lines or [
        "Oyunun gerçek görüntüsü, gerçek minimap, gerçek yetenek/eşya simgeleri.",
        "Altın, parçacık, çanta, kalp, kalkan, stat, görev simgeleri yeni piksel çizimi.",
        "Hepsi kahverengi-bej, 1 sanat pikseli = 3 ekran pikseli.",
        "Örnek durum: Seviye 12, can 96/130, kalkan 113/150, E 4 sn beklemede,",
        "2/3 diriltme kalbi (4:12), 3 efsanevi + 2 boş yuva, Peri, 1.240 altın, 3 parçacık.",
        "",
        "Yakın çekimler: out/yakin_A.png ... yakin_D.png (1:1).",
    ]
    for j, t in enumerate(lines):
        label(d, (x + 12, y + 20 + j * 34), t, 32, INK)
    sheet.save(os.path.join(OUT, "ozet.png"))


def yakin():
    # 1:1 seritler: ust 330 px + alt 330 px (HUD'un oldugu yerler), arada ince ayrac
    for fn, title in NAMES:
        p = os.path.join(OUT, fn + ".png")
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGB")
        top = im.crop((0, 0, 1920, 330))
        bot = im.crop((0, 750, 1920, 1080))
        sheet = Image.new("RGB", (1920, 330 + 330 + 48 + 6), BG)
        d = ImageDraw.Draw(sheet)
        label(d, (12, 6), title + "  (1:1, üst ve alt şerit)", 32, GOLD)
        sheet.paste(top, (0, 48))
        sheet.paste(bot, (0, 48 + 330 + 6))
        key = fn.replace("proto_", "")
        sheet.save(os.path.join(OUT, "yakin_%s.png" % key))


NAMES_V2 = [
    ("simdi", "ŞU AN"),
    ("proto_A2", "A2 - açık meşe"),
    ("proto_B2", "B2 - koyu ceviz, yarı saydam"),
    ("proto_C2", "C2 - parşömen bej"),
    ("proto_D2", "D2 - kütük"),
]


def v2():
    # V2 (bugunku yerlesim + A-D kaplamasi): ozet_v2.png yarim boy + yakin_v2.png (panel, sol ust, sag ust 1:1)
    global NAMES
    keep = NAMES
    NAMES = NAMES_V2
    ozet([
        "Yerleşim bugünküyle birebir: konumlar gerçek HUD düğümlerinden",
        "okunur, 3 px ızgaraya oturtulur. Değişen yalnız kaplama:",
        "kutu, kuyu, çubuk, tuş kapağı, seviye rozeti, harita halkası, yazı rengi.",
        "Altın, parçacık, kalp, kalkan, görev simgeleri yeni piksel çizimi.",
        "Aynı durum: Seviye 12, 96/130 can, 113/150 kalkan, 1.240 altın, 3 parçacık.",
        "",
        "1:1 yakın çekim: out/yakin_v2.png (panel, sol üst, sağ üst).",
    ])
    os.replace(os.path.join(OUT, "ozet.png"), os.path.join(OUT, "ozet_v2.png"))
    NAMES = keep
    ozet()  # v1 ozetini geri yaz
    dock = (600, 900, 1300, 1062)
    tl = (0, 0, 210, 222)
    tr = (1600, 0, 1904, 480)
    lab, pad = 40, 12
    W = (dock[2] - dock[0]) + pad + (tl[2] - tl[0]) + pad + (tr[2] - tr[0]) + 2 * pad
    rowh = max(dock[3] - dock[1], tl[3] - tl[1], tr[3] - tr[1])
    H = len(NAMES_V2) * (rowh + lab + pad) + pad
    sheet = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(sheet)
    for i, (fn, title) in enumerate(NAMES_V2):
        p = os.path.join(OUT, fn + ".png")
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGB")
        y = pad + i * (rowh + lab + pad)
        label(d, (pad, y + 2), title + "  (1:1)", 32, GOLD if fn != "simdi" else INK)
        x = pad
        for box in (dock, tl, tr):
            sheet.paste(im.crop(box), (x, y + lab))
            x += (box[2] - box[0]) + pad
    sheet.save(os.path.join(OUT, "yakin_v2.png"))


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "v2":
        v2()
    else:
        ozet()
        yakin()
    print("ok")
