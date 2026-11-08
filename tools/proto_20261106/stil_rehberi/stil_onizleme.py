# Stil rehberi onizlemesi (2026-11-06, madde 400; oyuna bagli DEGIL).
# "Tek stil rehberi uygulanirsa oyun nasil gorunur?" sorusu icin kaba taslak:
#  1) Ekranlar: 17 Ekim gercek oyun yakalamalari; kitin renk sabitleri HUD "Kisik Ahsap"
#     karsiliklarina kaydirilir (yerlesim/doku ayni, sadece renk ailesi tek olur).
#  2) Yazi: bugun kodda kullanilan 6 font ailesi vs tek aile (farkli kalinliklar).
#  3) Piksel: silah 0,5 dunya px, karakter 0,903 dunya px -> silah karakter izgarasina.
# Calistir: python tools/proto_20261106/stil_rehberi/stil_onizleme.py
import os, re, glob
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(os.path.dirname(__file__), "out")
os.makedirs(OUT, exist_ok=True)
P17 = os.path.join(ROOT, "tools", "proto_20261017", "out")

def hx(s):
    s = s.lstrip("#")
    return np.array([int(s[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)

# HUD "Kisik Ahsap" (scripts/hud_theme.gd) hedefleri
W_PANEL, W_PLATE, W_INSET, W_OUT = "#342316", "#3e2b1c", "#20150d", "#140e09"
W_RIM_LO, W_RIM, W_RIM_HI = "#4b3320", "#6a4a30", "#86623f"
W_TEXT, W_DIM, W_ACC, W_GOOD, W_BAD = "#f3e6cc", "#c4b090", "#f0c070", "#b5d98a", "#f09a80"

MAP_GECE = [  # scripts/menu_dark_kit.gd "Gece Sivasi"
    ("#1a1a2c", W_PANEL), ("#12121f", W_INSET), ("#3b3a5a", W_RIM_LO), ("#5f5c86", W_RIM),
    ("#a7a2c0", W_DIM), ("#efe6d6", W_TEXT), ("#f4c56e", W_ACC), ("#a8d69a", W_GOOD), ("#e38c7c", W_BAD)]
MAP_KAYRAK = [  # scripts/game_over_board.gd PAL_SLATE
    ("#1b212e", W_PANEL), ("#242c3b", W_PLATE), ("#2f3a4f", W_RIM_LO), ("#121722", W_INSET),
    ("#353f55", W_RIM), ("#56657f", W_RIM_HI), ("#0b0e15", W_OUT), ("#96a0b2", W_DIM),
    ("#ece6d7", W_TEXT), ("#d9b46a", W_ACC), ("#94c97e", W_GOOD), ("#dc8676", W_BAD)]
MAP_ATES = [  # scripts/fire_menu_kit.gd "Ates Isigi" (zaten sicak; kucuk kayma)
    ("#b09878", W_DIM), ("#3b2a1a", W_RIM_LO), ("#6a5440", W_RIM), ("#efe2c6", W_TEXT)]

def remap(img, pairs, T=42.0):
    a = np.asarray(img.convert("RGB"), dtype=np.float32)
    src = np.stack([hx(s) for s, _ in pairs])
    dst = np.stack([hx(t) for _, t in pairs])
    d = np.sqrt(((a[:, :, None, :] - src[None, None]) ** 2).sum(-1))
    i = d.argmin(-1)
    dm = np.take_along_axis(d, i[..., None], -1)[..., 0]
    w = np.clip(1.0 - (dm / T) ** 2, 0.0, 1.0)[..., None]
    out = a + w * (dst[i] - src[i])
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))

TW, TH, GAP = 420, 236, 14

def thumb(img):
    return img.convert("RGB").resize((TW, TH), Image.LANCZOS)

screens = [
    ("HUD (Kisik Ahsap)", "hud_tema/oyunda_D.png", None),
    ("Secim (Gece Sivasi)", "panel_renk/c_tek.png", MAP_GECE),
    ("Oyun Bitti (Kayrak)", "oyun_bitti/oyunda.png", MAP_KAYRAK),
    ("ESC (Ates Isigi)", "esc_ayar/oyunda_esc.png", MAP_ATES),
]

FONT_DIR = os.path.join(ROOT, "assets", "fonts")
def font(name, size):
    return ImageFont.truetype(os.path.join(FONT_DIR, name), size)

# hangi font ailesi kodda en cok geciyor -> "sonra" satiri onunla
fam_files = {
    "PixelifySans": "PixelifySans-Medium.ttf", "PixeloidSans": "PixeloidSans.ttf",
    "m5x7": "m5x7.ttf", "monogram": "monogram-extended.ttf",
    "VonwaonBitmap": "VonwaonBitmap-16px.ttf", "Nunito": "Nunito-SemiBold.ttf"}
counts = {k: 0 for k in fam_files}
for p in glob.glob(os.path.join(ROOT, "scripts", "**", "*.gd"), recursive=True):
    t = open(p, encoding="utf-8", errors="ignore").read()
    for k in counts:
        counts[k] += len(re.findall(re.escape(k), t))
theme = open(os.path.join(FONT_DIR, "theme.tres"), encoding="utf-8").read()
for k in counts:
    counts[k] += 100 * len(re.findall(re.escape(k), theme))  # tema fontu = varsayilan
print("font kullanimi:", counts)
main_fam = max(counts, key=counts.get)
fam_files = {k: v for k, v in fam_files.items() if counts[k] > 0}  # dosyasi olup hic kullanilmayanlar disarida

LABEL = font("PixelifySans-SemiBold.ttf", 22)
SMALL = font("PixelifySans-Regular.ttf", 18)
BG = (24, 17, 11)
INK = tuple(hx(W_TEXT).astype(int))
DIMC = tuple(hx(W_DIM).astype(int))
ACC = tuple(hx(W_ACC).astype(int))

W = GAP + 4 * (TW + GAP)
H = 1240
canvas = Image.new("RGB", (W, H), BG)
dr = ImageDraw.Draw(canvas)

y = GAP
dr.text((GAP, y), "SU AN  (oyun yakalamalari, 17 Ekim)", font=LABEL, fill=ACC)
y += 34
for k, (name, rel, _) in enumerate(screens):
    x = GAP + k * (TW + GAP)
    canvas.paste(thumb(Image.open(os.path.join(P17, rel))), (x, y))
    dr.text((x, y + TH + 4), name, font=SMALL, fill=DIMC)
y += TH + 40
dr.text((GAP, y), "TEK RENK AILESI  (kaba taslak: kit renkleri HUD ahsabina kaydirildi, yerlesim ayni)", font=LABEL, fill=ACC)
y += 34
for k, (name, rel, pairs) in enumerate(screens):
    x = GAP + k * (TW + GAP)
    img = Image.open(os.path.join(P17, rel))
    if pairs:
        img = remap(img, pairs)
    canvas.paste(thumb(img), (x, y))
    dr.text((x, y + TH + 4), name.split(" (")[0] + (" (ayni)" if not pairs else " -> ahsap"), font=SMALL, fill=DIMC)
y += TH + 48

# --- yazi satiri ---
col_w = W // 2
fy = y
dr.text((GAP, fy), "YAZI  su an: kodda %d aile" % len(fam_files), font=LABEL, fill=ACC)
fy += 34
SAMPLE = "KADEME III   +12 ALTIN   Şövalye Kalkanı"
sizes = {"PixelifySans": 24, "PixeloidSans": 18, "m5x7": 32, "monogram": 32, "VonwaonBitmap": 32, "Nunito": 24}
for fam, fn in fam_files.items():
    f = font(fn, sizes[fam])
    dr.text((GAP, fy), SAMPLE, font=f, fill=INK)
    dr.text((GAP + dr.textlength(SAMPLE, font=f) + 24, fy + 4), fam, font=SMALL, fill=DIMC)
    fy += 42
fy2 = y
x2 = col_w + GAP
dr.text((x2, fy2), "YAZI  rehberle: tek aile (" + main_fam + "), 3 seviye (boy + renk)", font=LABEL, fill=ACC)
fy2 += 34
if main_fam == "PixelifySans":
    tiers = [("PixelifySans-Bold.ttf", 32, ACC, "baslik"), ("PixelifySans-Medium.ttf", 24, INK, "govde"),
             ("PixelifySans-Regular.ttf", 20, DIMC, "ikincil")]
else:
    f = fam_files[main_fam]
    tiers = [(f, 48, ACC, "baslik"), (f, 32, INK, "govde"), (f, 32, DIMC, "ikincil")]
for fn, sz, col, role in tiers:
    f = font(fn, sz)
    dr.text((x2, fy2), SAMPLE, font=f, fill=col)
    dr.text((x2 + dr.textlength(SAMPLE, font=f) + 24, fy2 + max(0, sz // 2 - 12)), role, font=SMALL, fill=DIMC)
    fy2 += sz + 18

# --- piksel satiri ---
py = max(fy, fy2) + 26
dr.text((GAP, py), "PIKSEL  karakter 0,903 dunya px  /  silah 0,5 dunya px", font=LABEL, fill=ACC)
py += 34
K = 4.0  # ekran px / dunya px (gorunur olsun diye buyutuldu)
char = Image.open(os.path.join(ROOT, "assets/characters/talon/sheets/idle.png")).convert("RGBA").crop((0, 0, 48, 48))
cw = round(48 * 0.903 * K)
char_s = char.resize((cw, cw), Image.NEAREST)

def weapon_now(path):
    w = Image.open(path).convert("RGBA")
    return w.resize((round(w.width * 0.5 * K), round(w.height * 0.5 * K)), Image.NEAREST)

def weapon_regrid(path):
    w = Image.open(path).convert("RGBA")
    a = np.asarray(w).astype(np.float32)
    pal = np.unique(a[a[..., 3] > 128][:, :3], axis=0)
    f = 0.5 / 0.903
    nw, nh = max(1, round(w.width * f)), max(1, round(w.height * f))
    small = np.asarray(w.resize((nw, nh), Image.BOX)).astype(np.float32)
    rgb = small[..., :3] / np.maximum(small[..., 3:4] / 255.0, 1e-3)
    d = ((rgb[:, :, None, :] - pal[None, None]) ** 2).sum(-1)
    snapped = pal[d.argmin(-1)]
    alpha = np.where(small[..., 3] > 110, 255, 0)
    out = np.dstack([snapped, alpha]).astype(np.uint8)
    img = Image.fromarray(out, "RGBA")
    return img.resize((round(nw * 0.903 * K), round(nh * 0.903 * K)), Image.NEAREST)

wp = [os.path.join(ROOT, "assets/weapons/zanaat/uzunkilic_L3.png"),
      os.path.join(ROOT, "assets/weapons/zanaat/tabanca_L3.png")]
for half, (title, fn) in enumerate([("su an", weapon_now), ("rehberle (otomatik kucultme, gercekte yeniden cizilir)", weapon_regrid)]):
    x = GAP + half * col_w
    dr.text((x, py), title, font=SMALL, fill=DIMC)
    canvas.paste(char_s, (x, py + 28), char_s)
    xx = x + cw + 20
    for p in wp:
        im = fn(p)
        canvas.paste(im, (xx, py + 28 + (cw - im.height) // 2), im)
        xx += im.width + 20

canvas = canvas.crop((0, 0, W, py + 28 + cw + GAP))
dst = os.path.join(OUT, "stil_onizleme.png")
canvas.save(dst)
print("yazildi:", dst, canvas.size)
