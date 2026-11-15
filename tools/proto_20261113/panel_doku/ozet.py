# Panel dokusu prototip özeti: out/ozet.png + out/yakin.png (python ozet.py) ya da 2. set out/ozet2.png + out/yakin2.png (python ozet.py efgh). Önce run.ps1.
import os
import sys
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
FONT = ImageFont.truetype(os.path.join(HERE, "..", "..", "..", "assets", "fonts", "m5x7.ttf"), 32)
BG = (0x14, 0x0E, 0x09)
ACCENT = (0xF0, 0xC0, 0x70)
DIM = (0xC4, 0xB0, 0x90)
NAMES = {
    "simdi": ("ŞİMDİ", "düz zemin"),
    "doku_a": ("A  AHŞAP TAHTA", "geniş tahta, damar, budak"),
    "doku_b": ("B  TAŞ DUVAR", "sıralı taş, derz, ışık/gölge"),
    "doku_c": ("C  KİLİM", "kabartma baklava kafes"),
    "doku_d": ("D  ESKİ DERİ", "bantlı leke, kırışık, kenar gölgesi"),
    "doku_e": ("E  AKAN DAMAR", "tek parça levha, budak halkaları"),
    "doku_f": ("F  HASIR ÖRGÜ", "sepet örgüsü şeritler"),
    "doku_g": ("G  ÇİÇEK DESENİ", "ton üstü ton kabartma çiçek"),
    "doku_h": ("H  OYMA PANO", "oyma çerçeve + köşe yayı, hafif damar"),
    "doku_e_opak": ("E  OPAK", "pencere zemini %100"),
    "doku_eh_opak": ("E + OYMA ÇERÇEVE, OPAK", "çerçeve yalnız büyük pencerede"),
}
## python ozet.py opak -> out/opak.png (saydamlık karşılaştırması; önce run.ps1 -Set "e,e_opak,eh_opak")
SET = sys.argv[1] if len(sys.argv) > 1 else "abcd"
SUFFIX = "" if SET == "abcd" else "2"
if SET == "opak":
    NAMES["doku_e"] = ("E  ŞİMDİKİ SAYDAMLIK", "pencere zemini %88")
## python ozet.py abcd opak / efgh opak -> out/ozet_opak.png, yakin_opak.png / ozet2_opak.png, yakin2_opak.png (önce run.ps1 -Opak)
OPAK_ALL = len(sys.argv) > 2 and sys.argv[2] == "opak"
KS = "_opak" if OPAK_ALL else ""
if OPAK_ALL:
    for _k in "abcdefgh":
        NAMES["doku_%s_opak" % _k] = NAMES["doku_" + _k]


def label(draw, x, y, key):
    t, sub = NAMES[key]
    draw.text((x, y), t, font=FONT, fill=ACCENT)
    w = draw.textlength(t, font=FONT)
    draw.text((x + w + 24, y), sub, font=FONT, fill=DIM)


def ozet():
    keys = ["simdi", "doku_e", "doku_e_opak", "doku_eh_opak"] if SET == "opak" else ["doku_" + k + KS for k in SET]
    cw, ch, lh, gap = 960, 540, 44, 12
    sheet = Image.new("RGB", (cw * 2 + gap, (ch + lh) * 2 + gap), BG)
    d = ImageDraw.Draw(sheet)
    for i, k in enumerate(keys):
        x = (i % 2) * (cw + gap)
        y = (i // 2) * (ch + lh + gap)
        label(d, x + 8, y + 2, k)
        im = Image.open(os.path.join(OUT, k + ".png")).convert("RGB").resize((cw, ch), Image.LANCZOS)
        sheet.paste(im, (x, y + lh))
    sheet.save(os.path.join(OUT, "opak.png" if SET == "opak" else "ozet%s%s.png" % (SUFFIX, KS)))


def yakin():
    keys = ["simdi"] + ["doku_" + k + KS for k in SET]
    crop = (250, 300, 730, 760)  # sol "ODA KUR" kutusu + sağdaki oda listesi zemini, 1:1
    cw, ch = crop[2] - crop[0], crop[3] - crop[1]
    lh, gap = 44, 10
    sheet = Image.new("RGB", (cw * 3 + gap * 2, (ch + lh) * 2 + gap), BG)
    d = ImageDraw.Draw(sheet)
    for i, k in enumerate(keys):
        x = (i % 3) * (cw + gap)
        y = (i // 3) * (ch + lh + gap)
        d.text((x + 6, y + 2), NAMES[k][0], font=FONT, fill=ACCENT)
        sheet.paste(Image.open(os.path.join(OUT, k + ".png")).convert("RGB").crop(crop), (x, y + lh))
    d.text((2 * (cw + gap) + 16, (ch + lh + gap) + lh + 16), "1:1 piksel\n(oyunda 1920x1080)", font=FONT, fill=DIM)
    sheet.save(os.path.join(OUT, "yakin%s%s.png" % (SUFFIX, KS)))


if __name__ == "__main__":
    ozet()
    if SET != "opak":
        yakin()
    print("ok")
