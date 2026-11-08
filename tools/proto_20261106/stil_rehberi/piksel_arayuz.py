# PİKSEL ARAYÜZ örneği (2026-11-06, madde 403; oyuna bagli DEGIL).
# Kullanici: "arayuzlerin de pixel gorunmesini istiyorum, bir ornek goster". Oyun Bitti penceresinin AYNI yerlesimi,
# "Kisik Ahsap" HUD'unun KENDI piksel dokulariyla (hud_plaque_clean / hud_inset / btn_hud_normal, 9 dilim, HUD'daki gibi
# 1 sanat pikseli = 3 ekran pikseli, MenuKit.T) + elle cizilen her sey (cubuk, cerceve, ayrac) ayni 3 px izgarada.
# Yazi m5x7 yerel boyutunun tam katlarinda (32 = x2, 48 = x3), yumusatmasiz (esik). Duz StyleBoxFlat + ince 1-2 px cizgi YOK.
# Calistir: python tools/proto_20261106/stil_rehberi/piksel_arayuz.py [simdi.png]
#   simdi.png verilirse (ayni pencerenin gercek oyun yakalamasi) yan yana karsilastirma da yazilir.
import os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(os.path.dirname(__file__), "out")
os.makedirs(OUT, exist_ok=True)
T = 3  # 1 sanat pikseli = 3 ekran pikseli (menu_kit.gd T)

def hx(s, a=255):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (a,)

# scripts/hud_theme.gd
DEEP, WIN_INSET, OUTLINE = hx("#140e09"), hx("#1a110a"), hx("#20150d")
INSET, STRIPE, PLATE_ON = hx("#271a11"), hx("#342316"), hx("#3e2b1c")
RIM_LO, PANEL, RIM, RIM_HI = hx("#4b3320"), hx("#5a4734"), hx("#6a4a30"), hx("#86623f")
TEXT, DIM, ACCENT, PRICE = hx("#f3e6cc"), hx("#c4b090"), hx("#f0c070"), hx("#f6d27e")
DMG, TANK, SOUL = hx("#e8885a"), hx("#8cc0e6"), hx("#e6dcff")

def tex(rel):
    return Image.open(os.path.join(ROOT, rel)).convert("RGBA")

PLAQUE = tex("assets/ui/game/hud_plaque_clean.png")
WELL = tex("assets/ui/game/hud_inset.png")
BTN = tex("assets/ui/game/btn_hud_normal.png")

def snap(v):
    return int(round(v / T)) * T

def nine(src, m, w, h):
    """9 dilim (m sanat pikseli, x T doku pikseli). Kenar/orta en yakin komsuyla uzar (duz bolgeler)."""
    l, t, r, b = [x * T for x in m]
    W, H = src.size
    w, h = snap(w), snap(h)
    out = Image.new("RGBA", (w, h))
    xs = [(0, l, 0, l), (l, W - r, l, w - r), (W - r, W, w - r, w)]
    ys = [(0, t, 0, t), (t, H - b, t, h - b), (H - b, H, h - b, h)]
    for sx0, sx1, dx0, dx1 in xs:
        for sy0, sy1, dy0, dy1 in ys:
            if dx1 > dx0 and dy1 > dy0:
                out.paste(src.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.NEAREST), (dx0, dy0))
    return out

def put(cv, img, x, y):
    cv.alpha_composite(img, (snap(x), snap(y)))

FONT = os.path.join(ROOT, "assets/fonts/m5x7.ttf")
F32, F48 = ImageFont.truetype(FONT, 32), ImageFont.truetype(FONT, 48)

def text(cv, xy, s, font, col, anchor="la", shadow=True):
    """Yumusatmasiz piksel yazi (alfa esigi) + 1 yazi pikseli kadar koyu golge."""
    m = Image.new("L", cv.size, 0)
    ImageDraw.Draw(m).text(xy, s, font=font, fill=255, anchor=anchor)
    m = m.point(lambda v: 255 if v > 110 else 0)
    if shadow:
        px = 2 if font is F32 else 3
        cv.paste(Image.new("RGBA", cv.size, DEEP), (0, px), m)
    cv.paste(Image.new("RGBA", cv.size, col), (0, 0), m)

def rect(cv, x, y, w, h, col):
    ImageDraw.Draw(cv).rectangle([snap(x), snap(y), snap(x) + snap(w) - 1, snap(y) + snap(h) - 1], fill=col)

def bar(cv, x, y, w, h, frac, col):
    rect(cv, x, y, w, h, OUTLINE)
    rect(cv, x + T, y + T, w - 2 * T, h - 2 * T, WIN_INSET)
    fw = snap((w - 2 * T) * frac)
    if fw:
        rect(cv, x + T, y + T, fw, h - 2 * T, col)
        rect(cv, x + T, y + T, fw, T, tuple(min(255, int(c * 1.2)) for c in col[:3]) + (255,))

def diamond(cv, cx, cy, col):
    for j, row in enumerate(["..#..", ".###.", "#####", ".###.", "..#.."]):
        for i, ch in enumerate(row):
            if ch == "#":
                rect(cv, cx + (i - 2) * T, cy + (j - 2) * T, T, T, col)

SKULL = ["..XXXXX..", ".XWWWWWX.", "XWWWWWWWX", "XWKKWKKWX", "XWKKWKKWX", ".XWWXWWX.", "..XWWWX..", "..XWXWX..", "...XXX..."]

def skull(cv, cx, cy):  # boss_bar_art.gd SKULL_ROWS, 1 piksel = T
    cols = {"X": OUTLINE, "W": hx("#e9dcc0"), "K": DEEP}
    for j, row in enumerate(SKULL):
        for i, ch in enumerate(row):
            if ch in cols:
                rect(cv, cx + (i - 4) * T, cy + (j - 4) * T, T, T, cols[ch])

def face(char_dir):
    fr = tex("assets/characters/%s/sheets/idle.png" % char_dir).crop((0, 0, 48, 48))
    a = np.asarray(fr)[..., 3]
    ys, xs = np.nonzero(a > 0)
    top, cx = ys.min(), int(xs.mean())
    f = fr.crop((cx - 9, top, cx + 9, top + 18))  # kafa 18x18
    return f.resize((54, 54), Image.NEAREST)  # x3: karakter pikseli = arayuz pikseli

TEAM = [("Sen", "talon", 48210, 9870, 561, True), ("Kerem", "korsan", 61930, 12380, 537, False),
        ("Deniz", "cadi", 35080, 15920, 296, False), ("Mira", "elara", 21540, 6120, 158, False)]

def fmt(n):
    return "{:,}".format(n).replace(",", ".")

def build_window(size):
    cv = Image.new("RGBA", size, (0, 0, 0, 0))
    W, H = 1200, 912 ## gercek pencereyle ayni kutu (360,72 - 1560,984)
    x0, y0 = 360, 72
    put(cv, nine(PLAQUE, (6, 5, 6, 5), W, H), x0, y0)
    put(cv, nine(BTN, (4, 4, 4, 4), 66, 66), x0 + W / 2 - 33, y0 - 30)
    skull(cv, x0 + W // 2, y0 + 3)
    text(cv, (x0 + W // 2, y0 + 81), "OYUN BİTTİ", F48, ACCENT, "mm")
    text(cv, (x0 + W // 2, y0 + 126), "Takım dağıldı - 18:51'de son kişi düştü", F32, DIM, "mm")
    stats = [("SÜRE", "18:51", TEXT), ("KADEME", "VI", PRICE), ("SEVİYE", "23", TEXT), ("ÖLDÜRME", "1.552", TEXT)]
    bw, bh, gap = 264, 108, 18
    sx = x0 + (W - (4 * bw + 3 * gap)) / 2
    for i, (lab, val, col) in enumerate(stats):
        bx = snap(sx + i * (bw + gap))
        put(cv, nine(WELL, (4, 4, 4, 4), bw, bh), bx, y0 + 162)
        text(cv, (bx + bw // 2, y0 + 195), lab, F32, DIM, "mm", shadow=False)
        text(cv, (bx + bw // 2, y0 + 237), val, F32, col, "mm", shadow=False)
    ty, RH = y0 + 297, 72
    tw, th = W - 84, 48 + RH * 4 + 12
    tx = x0 + 42
    put(cv, nine(WELL, (4, 4, 4, 4), tw, th), tx, ty)
    cols = [tx + 24, tx + 330, tx + 690, tx + 930]
    for c, lab in zip(cols, ["OYUNCU", "VERİLEN HASAR", "ALINAN", "ÖLDÜRME"]):
        text(cv, (c, ty + 12), lab, F32, DIM, shadow=False)
    mx, my = max(t[2] for t in TEAM), max(t[3] for t in TEAM)
    for r, (name, cdir, dealt, taken, kills, me) in enumerate(TEAM):
        ry = ty + 48 + r * RH
        if r % 2 == 0:
            rect(cv, tx + 12, ry, tw - 24, RH, STRIPE)
        if me:
            rect(cv, tx + 12, ry, T, RH, ACCENT)
        fx = tx + 24
        rect(cv, fx, ry + 6, 60, 60, OUTLINE)
        rect(cv, fx + T, ry + 9, 54, 54, RIM_LO)
        put(cv, face(cdir), fx + T, ry + 9)
        text(cv, (fx + 78, ry + 21), name, F32, ACCENT if me else TEXT, shadow=False)
        bar(cv, cols[1], ry + 27, 240, 21, dealt / mx, DMG)
        text(cv, (cols[1] + 255, ry + 21), fmt(dealt), F32, TEXT, shadow=False)
        bar(cv, cols[2], ry + 27, 132, 21, taken / my, TANK)
        text(cv, (cols[2] + 147, ry + 21), fmt(taken), F32, TEXT, shadow=False)
        text(cv, (tx + tw - 30, ry + 21), str(kills), F32, TEXT, "ra", shadow=False)
    ky = ty + th + 15
    put(cv, nine(WELL, (4, 4, 4, 4), tw, 102), tx, ky)
    diamond(cv, tx + 33, ky + 30, SOUL)
    text(cv, (tx + 54, ky + 15), "+47 Ruh Kıymığı", F32, SOUL, shadow=False)
    diamond(cv, tx + 453, ky + 30, PRICE)
    text(cv, (tx + 474, ky + 15), "Yeni rekor: en yüksek kademe VI", F32, TEXT, shadow=False)
    text(cv, (tx + 54, ky + 51), "Başarım: Ağacı Koru x10", F32, DIM, shadow=False)
    by = y0 + H - 102
    for i, (lab, col) in enumerate([("YENİDEN BAŞLA", ACCENT), ("ANA MENÜYE DÖN", TEXT)]):
        bx = snap(x0 + W / 2 - 9 - 300 + i * 318)
        put(cv, nine(BTN, (4, 4, 4, 4), 300, 66), bx, by)
        text(cv, (bx + 150, by + 31), lab, F32, col, "mm")
    return cv

def main():
    ## arka plan = gercek Oyun Bitti yakalamasi (HUD gizli, oyunun kendi karartmasi); pencerenin ustune cizilir
    bg_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(OUT, "simdi_oyun_bitti.png")
    bg = Image.open(bg_path).convert("RGBA")
    full = Image.alpha_composite(bg, build_window(bg.size))
    full.convert("RGB").save(os.path.join(OUT, "piksel_arayuz.png"))
    full.crop((372, 270, 852, 540)).resize((960, 540), Image.NEAREST).convert("RGB").save(os.path.join(OUT, "piksel_arayuz_yakin.png"))
    if len(sys.argv) > 1:
        a = Image.open(sys.argv[1]).convert("RGB").resize((960, 540), Image.LANCZOS)
        b = full.convert("RGB").resize((960, 540), Image.LANCZOS)
        c = Image.new("RGB", (1940, 590), DEEP[:3])
        c.paste(a, (0, 44)); c.paste(b, (980, 44))
        dr = ImageDraw.Draw(c)
        dr.text((8, 4), "ŞİMDİ (renk ahşaba geçti, düz kenar)", font=F32, fill=ACCENT[:3])
        dr.text((988, 4), "PİKSEL AHŞAP (HUD dokuları, 1 piksel = 3 ekran px)", font=F32, fill=ACCENT[:3])
        c.save(os.path.join(OUT, "piksel_karsilastirma.png"))
    print("yazildi:", OUT)

main()
