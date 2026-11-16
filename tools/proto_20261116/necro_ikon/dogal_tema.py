# Necro 4 skill ikonu için DOĞAL tema: zemin renkleri elle karartılmaz; Necromancer paketinin KENDİ yeşil/mor/turkuaz
# ikonlarından parlaklık sırasına göre renk rampası çıkarılır ve ikonun zemin pikselleri aynı sıradaki (yüzdelik) renge
# eşlenir (histogram eşleme). Böylece ton kayması (koyuda soğuk, açıkta sıcak) ve parlaklık paketin kendi sanatıyla aynı olur.
# Figür maskesi koyu_tema.py ile aynı (ton penceresi + doygunluk + parlaklık eşiği).
# python -I dogal_tema.py -> out/dogal_<secenek>_<ikon>.png + out/dogal_onizleme.png
import colorsys, os, sys
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import genel_cikar as g
NE = "Necromancer-Skill-Pixel-Art-Icons2-720x480.webp"
SK = "../../../assets/skills/necromancer_%s_icon.png"
ICONS = [("Q", "iskelet_cagir", 28, 50, .4, .62, .25), ("E", "hortlak_cagir", 320, 45, .06, .15, 0),
         ("R", "lanetli_kafatasi", 28, 50, .4, .62, .25), ("P", "passive", 115, 70, .22, .5, 0)]
# seçenek: (kod, ad, referans hücreler [(satır, sütun)], referans ton merkezi, yarı genişlik)
OPTS = [("A", "zehir yesili", [(0, 3), (0, 5), (2, 2), (0, 6)], 105, 45),
        ("B", "mor", [(2, 3), (3, 1), (1, 1), (4, 4)], 285, 40),
        ("C", "ruh turkuazi", [(4, 0), (3, 6), (4, 4)], 175, 30)]
BINS = 64

def ss(x, a, b):
    t = np.clip((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)

def hsv(a):  # a: (...,3) 0-255 -> h derece, s, v
    f = a / 255.0; mx = f.max(-1); mn = f.min(-1); d = mx - mn
    s = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0)
    r, gg, b = f[..., 0], f[..., 1], f[..., 2]
    h = np.where(mx == r, (gg - b) / np.maximum(d, 1e-6) % 6, np.where(mx == gg, (b - r) / np.maximum(d, 1e-6) + 2, (r - gg) / np.maximum(d, 1e-6) + 4)) * 60
    return np.where(d > 0, h, 0), s, mx

def luma(a): return a[..., 0] * .299 + a[..., 1] * .587 + a[..., 2] * .114

def mask(a, center, half, s0, s1, v0):
    h, s, v = hsv(a)
    dh = (h - center + 180) % 360 - 180
    w = ss(s, s0, s1) * (1 - ss(np.abs(dh), half - 12, half + 6))
    if v0 > 0: w = w * ss(v, v0, v0 + .2)
    return w

def ramp(cells, center, half):
    px = []
    for r, c in cells:
        a = np.asarray(g.icon(NE, r, c).convert("RGB").resize((48, 48), Image.NEAREST)).astype(float).reshape(-1, 3)
        h, s, v = hsv(a); dh = (h - center + 180) % 360 - 180
        px.append(a[(s > .35) & (np.abs(dh) < half)])
    px = np.concatenate(px); px = px[np.argsort(luma(px))]
    n = len(px); out = np.zeros((BINS, 3))
    for k in range(BINS):  # her yüzdelik dilimin ortalaması (webp gürültüsü söner)
        out[k] = px[int(k * n / BINS):max(int((k + 1) * n / BINS), int(k * n / BINS) + 1)].mean(0)
    return out

def remap(path, ic, rmp):
    _, _, c, hw, s0, s1, v0 = ic
    im = Image.open(path).convert("RGBA"); a = np.asarray(im).astype(float); rgb = a[..., :3]
    w = mask(rgb, c, hw, s0, s1, v0)
    l = luma(rgb); sel = w > .05
    order = np.argsort(np.argsort(l[sel])); q = order / max(1, sel.sum() - 1)  # zemindeki parlaklık sırası 0..1
    qq = np.zeros_like(l); qq[sel] = q
    # rampadan doğrusal ara değer
    x = qq * (BINS - 1); i0 = np.floor(x).astype(int); i1 = np.minimum(i0 + 1, BINS - 1); f = (x - i0)[..., None]
    col = rmp[i0] * (1 - f) + rmp[i1] * f
    out = rgb * (1 - w[..., None]) + col * w[..., None]
    a[..., :3] = np.clip(out, 0, 255)
    return Image.fromarray(a.astype(np.uint8), "RGBA")

rows = [("simdi", [Image.open(SK % ic[1]).convert("RGBA") for ic in ICONS])]
for code, name, cells, rc, rh in OPTS:
    rmp = ramp(cells, rc, rh); lst = []
    for ic in ICONS:
        im = remap(SK % ic[1], ic, rmp); im.save("out/dogal_%s_%s.png" % (code, ic[0])); lst.append(im)
    rows.append(("%s %s" % (code, name), lst))
out = Image.new("RGBA", (4 * 154 + 30 + 4 * 72 + 20, len(rows) * 172 + 8), (34, 30, 38, 255)); d = ImageDraw.Draw(out)
for r, (title, ims) in enumerate(rows):
    y0 = r * 172 + 8; d.text((10, y0), title, fill=(255, 220, 120, 255))
    for c, im in enumerate(ims):
        out.alpha_composite(im, (10 + c * 154, y0 + 16))
        out.alpha_composite(im.resize((64, 64), Image.NEAREST), (10 + 4 * 154 + 20 + c * 72, y0 + 16))
out.save("out/dogal_onizleme.png")
