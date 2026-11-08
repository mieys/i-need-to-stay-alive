# ESKİ SİLAH İKONLARI PİKSEL IZGARASINA (2026-11-06, madde 410 prototipi; oyuna bagli DEGIL).
# Kullanici: "silahlari eski gorunumlerine degistirdim ama onlar pixel kuralina uygun gorunmuyor kaliteleri cok yuksek".
# Olcum: eski ikonlar 200-250 px doku, Icon.scale x kok 0,5 -> 1 doku px = 0,14-0,28 dunya px (karakter 0,903, kullanicinin
# kendi cizimleri 0,575). Donusum: carpilmis-alfa kutu kucultme -> alfa esigi -> ikon basina en cok N renk (median cut) ->
# kenardaki acik pikseller koyu dis hatta. Iki yogunluk: A = karakter izgarasi 0,903, B = kullanicinin silah cizimleri 0,575.
# Calistir: python tools/proto_20261106/stil_rehberi/silah_piksel.py  -> out/silah_piksel.png (+ out/silah_piksel/<ad>_<A|B>.png)
import os, re
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(os.path.dirname(__file__), "out")
os.makedirs(os.path.join(OUT, "silah_piksel"), exist_ok=True)
ROOT_SCALE = 0.5
K = 6.0  # ekran px / dunya px (oyunda ~2, x3 buyutuldu)
GRIDS = {"A": 0.903, "B": 0.575}
COLORS = 14
NAMES = ["dagger", "topuz", "pence", "lightning", "tabanca", "tufek", "crossbow", "boomerang", "fisek"]
LABEL = {"dagger": "Bıçak", "topuz": "Topuz", "pence": "Pençe", "lightning": "Yıldırım", "tabanca": "Tabanca",
         "tufek": "Tüfek", "crossbow": "Arbalet", "boomerang": "Bumerang", "fisek": "Fişek"}


def scene_icon(name):
    s = open(os.path.join(ROOT, "scenes", "weapon_%s.tscn" % name), encoding="utf-8").read()
    tex = re.findall(r'path="(res://[^"]+\.png)"', s)[0].replace("res://", "")
    body = re.search(r'\[node name="Icon"[^\]]*\]\n((?:[^\[].*\n)*)', s).group(1)
    sc = float(re.search(r'scale = Vector2\(([-\d.e]+),', body).group(1))
    return Image.open(os.path.join(ROOT, tex)).convert("RGBA"), sc * ROOT_SCALE


def pixelate(img, texel, grid):
    f = texel / grid
    nw, nh = max(1, round(img.width * f)), max(1, round(img.height * f))
    a = np.asarray(img).astype(np.float32) / 255.0
    pm = a.copy()
    pm[..., :3] *= pm[..., 3:4]
    small = np.asarray(Image.fromarray((pm * 255).astype(np.uint8), "RGBA").resize((nw, nh), Image.BOX)).astype(np.float32) / 255.0
    al = small[..., 3]
    rgb = small[..., :3] / np.maximum(al[..., None], 1e-4)
    mask = al > 0.45
    rgb_img = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8), "RGB")
    q = rgb_img.quantize(colors=COLORS, method=Image.Quantize.MEDIANCUT).convert("RGB")
    qa = np.asarray(q).copy()
    # dis hat: saydama komsu opak piksel acik renkse koyulas (piksel cizimindeki koyu kontur)
    lum = qa.astype(np.float32) @ np.array([0.3, 0.59, 0.11])
    edge = mask & ~(np.pad(mask, 1)[2:, 1:-1] & np.pad(mask, 1)[:-2, 1:-1] & np.pad(mask, 1)[1:-1, 2:] & np.pad(mask, 1)[1:-1, :-2])
    dark = edge & (lum > 70)
    qa[dark] = (qa[dark].astype(np.float32) * 0.45).astype(np.uint8)
    out = np.dstack([qa, np.where(mask, 255, 0).astype(np.uint8)])
    return Image.fromarray(out, "RGBA")


def show(img, texel):
    s = texel * K
    return img.resize((max(1, round(img.width * s)), max(1, round(img.height * s))), Image.NEAREST)


def trim(img):
    bb = img.getbbox()
    return img.crop(bb) if bb else img


char = trim(Image.open(os.path.join(ROOT, "assets/characters/talon/sheets/idle.png")).convert("RGBA").crop((0, 0, 48, 48)))
sword = trim(Image.open(os.path.join(ROOT, "assets/weapons/yeni/uzunkilic.png")).convert("RGBA"))
rows = [("ŞU AN (eski ikonlar, 1 doku px = 0,14-0,28 dünya px)", None),
        ("A - KARAKTER IZGARASI (0,903 dünya px)", "A"),
        ("B - SENİN SİLAH ÇİZİMLERİNİN IZGARASI (0,575 dünya px)", "B")]
FONT = ImageFont.truetype(os.path.join(ROOT, "assets/fonts/m5x7.ttf"), 32)
BG, DIM, ACC, GROUND = (39, 26, 17), (196, 176, 144), (240, 192, 112), (74, 96, 52)
cells_all = []
for title, g in rows:
    cells = [("Karakter", show(char, 0.903)), ("Uzunkılıç (senin)", show(sword, 0.575))]
    for n in NAMES:
        img, texel = scene_icon(n)
        if g is None:
            cells.append((LABEL[n], show(trim(img), texel)))
        else:
            p = trim(pixelate(img, texel, GRIDS[g]))
            p.save(os.path.join(OUT, "silah_piksel", "%s_%s.png" % (n, g)))
            cells.append((LABEL[n], show(p, GRIDS[g])))
    cells_all.append((title, cells))
CW = [max(max(c[i][1].width for _, c in cells_all), 150) for i in range(len(cells_all[0][1]))]
RH = max(c[1].height for _, cs in cells_all for c in cs) + 30
W = 30 + sum(w + 24 for w in CW)
H = 20 + len(rows) * (44 + RH + 46)
cv = Image.new("RGB", (W, H), BG)
dr = ImageDraw.Draw(cv)
y = 14
for title, cells in cells_all:
    dr.text((24, y), title, font=FONT, fill=ACC)
    y += 44
    dr.rectangle([12, y, W - 12, y + RH], fill=GROUND)
    x = 24
    for i, (name, im) in enumerate(cells):
        cv.paste(im, (x + (CW[i] - im.width) // 2, y + RH - 15 - im.height), im)
        dr.text((x, y + RH + 6), name, font=FONT, fill=DIM)
        x += CW[i] + 24
    y += RH + 46
cv.save(os.path.join(OUT, "silah_piksel.png"))
print("yazildi", cv.size)
