# PİKSEL IZGARASI karşılaştırması (2026-11-06, madde 406, cila 5; oyuna bagli DEGIL).
# Olcum: karakter pikseli 0,903 dunya px; silah (weapon_tier_art.gd WORLD_PX) ve mermi (projectile_art.gd) 0,575; sandik (chest_art.gd TEXEL) 0,5.
# Satir 1 = oyunda bugunku yogunluk. Satir 2 = ayni dunya boyunda karakter izgarasina (0,903) OTOMATIK oturtma: kutu kucultme + orijinal
# palete oturtma + alfa esigi. Otomatik oldugu icin kaba; secilirse ureticiler (gen_mermi_sprites.py / gen_chest_sprites.py) elle yeniden cizer.
# Silahlar kullanicinin kendi cizimleri (assets/weapons/yeni, madde 402) - satir 2'deki hali yalniz "bu yogunlukta nasil durur" ornegi.
# Calistir: python tools/proto_20261106/stil_rehberi/piksel_izgara.py  -> out/piksel_izgara.png
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(os.path.dirname(__file__), "out")
os.makedirs(OUT, exist_ok=True)
CHAR_PX = 0.903
K = 6.0  # ekran px / dunya px (oyunda ~2; gorunsun diye x3 buyutuldu)

def load(rel):
    return Image.open(os.path.join(ROOT, rel)).convert("RGBA")

def frame(img, n):  # yatay seridin ilk karesi
    w = img.width // n
    return img.crop((0, 0, w, img.height))

def trim(img):
    bb = img.getbbox()
    return img.crop(bb) if bb else img

def show(img, texel):  # dunya boyunda, en yakin komsu
    s = texel * K
    return img.resize((max(1, round(img.width * s)), max(1, round(img.height * s))), Image.NEAREST)

def regrid(img, texel):
    """texel -> CHAR_PX: kutu kucultme, orijinal palete oturtma, alfa esigi."""
    a = np.asarray(img).astype(np.float32)
    opaque = a[..., 3] > 128
    if not opaque.any():
        return img
    pal = np.unique(a[opaque][:, :3], axis=0)
    f = texel / CHAR_PX
    nw, nh = max(1, round(img.width * f)), max(1, round(img.height * f))
    small = np.asarray(img.resize((nw, nh), Image.BOX)).astype(np.float32)
    al = small[..., 3:4] / 255.0
    rgb = small[..., :3] / np.maximum(al, 1e-3)
    d = ((rgb[:, :, None, :] - pal[None, None]) ** 2).sum(-1)
    out = np.dstack([pal[d.argmin(-1)], np.where(small[..., 3] > 100, 255, 0)]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")

char = trim(load("assets/characters/talon/sheets/idle.png").crop((0, 0, 48, 48)))
items = [
    ("Uzunkılıç *", trim(load("assets/weapons/yeni/uzunkilic.png")), 0.575),
    ("Ateş Asası *", trim(load("assets/weapons/yeni/fire_staff.png")), 0.575),
    ("Ok", trim(frame(load("assets/weapons/mermi/ok_govde.png"), 1)), 0.575),
    ("Tabanca", trim(frame(load("assets/weapons/mermi/tabanca_govde.png"), 1)), 0.575),
    ("Arcane", trim(frame(load("assets/weapons/mermi/arcane_govde.png"), 4)), 0.575),
    ("Buz", trim(frame(load("assets/weapons/mermi/buz_govde.png"), 4)), 0.575),
    ("Sandık", trim(frame(load("assets/sprites/chests/chest_normal.png"), 20)), 0.5),
]

FONT = os.path.join(ROOT, "assets/fonts/m5x7.ttf")
F32 = ImageFont.truetype(FONT, 32)
BG, INK, DIM, ACC = (39, 26, 17), (243, 230, 204), (196, 176, 144), (240, 192, 112)
GROUND = (74, 96, 52)

def row(regridded):
    cells = [("Karakter (0,903)", show(char, CHAR_PX))]
    for name, img, tx in items:
        cells.append((name, show(regrid(img, tx), CHAR_PX) if regridded else show(img, tx)))
    return cells

rows = [("ŞU AN: silah/mermi 0,575 - sandık 0,5 - karakter 0,903 dünya px", row(False)),
        ("KARAKTER IZGARASI (otomatik kaba taslak, seçilirse elle çizilir): hepsi 0,903", row(True))]
GAP, LH = 36, 44
W = GAP + sum(max(c[1].width, 170) + GAP for c in rows[0][1])
H_row = max(c[1].height for _, r in rows for c in r) + 40
H = GAP + len(rows) * (LH + H_row + 48) + 40
cv = Image.new("RGB", (W, H), BG)
dr = ImageDraw.Draw(cv)
y = GAP // 2
for title, cells in rows:
    dr.text((GAP, y), title, font=F32, fill=ACC)
    y += LH
    dr.rectangle([GAP // 2, y, W - GAP // 2, y + H_row], fill=GROUND)
    x = GAP
    for name, img in cells:
        cw = max(img.width, 170)
        cv.paste(img, (x + (cw - img.width) // 2, y + H_row - 20 - img.height), img)
        x += cw + GAP
    y += H_row + 4
    x = GAP
    for name, img in cells:
        cw = max(img.width, 170)
        dr.text((x, y), name, font=F32, fill=DIM)
        x += cw + GAP
    y += 44
dr.text((GAP, y), "* senin masaüstü çizimin (madde 402) - yeniden çizilecekse sen çizersin; ok/mermi/sandık üreticilerle çizilir.", font=F32, fill=DIM)
dst = os.path.join(OUT, "piksel_izgara.png")
cv.save(dst)
print("yazildi:", dst, cv.size)
