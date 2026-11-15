# Cadı iksirleri (kullanıcının Transperent/IconN, 32x32 şeffaf) için sade zemin: "her iksirin kendine özgü, özneyi
# bozmayan, renk tonlarına uygun ve sade bir arkaplanı olsun". İksir pikselleri DEĞİŞMEZ (1:1, 48 ızgarada ortalı);
# zemin iksirin baskın tonundan, dither'sız düz bantlar; çerçeve ana Cadı R ikonundan ölçülen 2 px kahve halka.
# Biçim oyunun kuralı: 48x48 sanat x3 = 144.
import os
import colorsys
import math
import numpy as np
from PIL import Image

SRC = os.path.join(os.path.expanduser("~"), "Desktop", "Transperent")
ART = 48
FRAME_OUT = (78, 55, 47)   # ölçüm: cadi_iksir_icon 48'lik satır 0
FRAME_BEV = (106, 84, 74)  # satır 1 (açık kahve kabartma)

# no -> (iksir adı, Transperent IconN). Kullanıcının seçimi (7. tur).
SECIM = {61: ("Delilik İksiri", 11), 62: ("Don İksiri", 36), 63: ("Patlama İksiri", 35),
         64: ("Şifa İksiri", 19), 65: ("Korku İksiri", 27), 66: ("Kalkan İksiri", 9)}


def potion(n):
    return Image.open(os.path.join(SRC, "Icon%d.png" % n)).convert("RGBA")


def dominant_hue(img):
    """Opak ve doygun piksellerin dairesel ortalama tonu (0-1); doygun yoksa None."""
    p = np.asarray(img).astype(float)
    m = p[..., 3] > 200
    rgb = p[..., :3][m] / 255.0
    hsv = np.array([colorsys.rgb_to_hsv(*c) for c in rgb])
    sat = hsv[:, 1] > 0.35
    if not sat.any():
        return None
    z = np.exp(1j * 2 * np.pi * hsv[sat, 0]).mean()
    return (np.angle(z) / (2 * np.pi)) % 1.0


def _rgb(h, s, v):
    return tuple(int(round(c * 255)) for c in colorsys.hsv_to_rgb(h, s, v))


def _frame(a):
    a[0, :] = a[-1, :] = FRAME_OUT
    a[:, 0] = a[:, -1] = FRAME_OUT
    a[1, 1:-1] = a[-2, 1:-1] = FRAME_BEV
    a[1:-1, 1] = a[1:-1, -2] = FRAME_BEV


def background(h, style):
    """48x48 RGB zemin (çerçeve dahil). style: 'hale' | 'isin' | 'sade'."""
    a = np.zeros((ART, ART, 3), np.uint8)
    cx, cy = 23.5, 22.5  # iksirin gövdesi biraz yukarıda (32'lik kanvasta y 1..29)
    for y in range(ART):
        for x in range(ART):
            r = math.hypot(x - cx, y - cy)
            if style == "hale":
                v = 0.46 if r < 10 else 0.38 if r < 15 else 0.30 if r < 20 else 0.23
                s = 0.55
            elif style == "isin":
                ang = math.atan2(y - cy, x - cx)
                wedge = int((ang + math.pi) / (2 * math.pi) * 16) % 2
                base = 0.36 if wedge else 0.29
                v = base if r < 17 else base - 0.06
                v = 0.44 if r < 7 else v
                s = 0.6
            else:  # sade: düz dolgu + üstte 1 bant açık
                v = 0.33 if y < 14 else 0.28
                s = 0.45
            a[y, x] = _rgb(h, s, v)
    # çerçevenin hemen içi 1 px koyu (paket ikonlarındaki iç gölge)
    edge = np.zeros((ART, ART), bool)
    edge[2, 2:-2] = edge[-3, 2:-2] = True
    edge[2:-2, 2] = edge[2:-2, -3] = True
    a[edge] = (a[edge] * 0.72).astype(np.uint8)
    _frame(a)
    return a


def compose(no, style, big=False):
    """48x48 RGBA ikon: zemin + iksir. big=False: 1:1 ortalı (pikseller birebir); big=True: iksirin kendi
    sınırları 4/3 en yakın komşuyla büyür (karoyu doldurur, pikseller hafif eşitsiz)."""
    _, n = SECIM[no]
    p = potion(n)
    h = dominant_hue(p)
    if h is None:
        h = 0.75
    img = Image.fromarray(background(h, style), "RGB").convert("RGBA")
    if big:
        q = p.crop(p.getbbox())
        q = q.resize((round(q.width * 4 / 3), round(q.height * 4 / 3)), Image.NEAREST)
        img.alpha_composite(q, ((ART - q.width) // 2, (ART - q.height) // 2))
    else:
        off = (ART - p.width) // 2
        img.alpha_composite(p, (off, off))
    return img


STYLES = [("hale", "ışık halesi"), ("isin", "ışınlar"), ("sade", "sade")]


# --- 9. tur: "bu prototipleri beğenmedim, skill ikonlarındaki arkaplanlara benzer, doğal dursun" ---------------
# Zemin artık PAKETİN KENDİ zemin sanatı: konusuz, neredeyse saf zemin olan üç ikon (önizlemeden kırpım, paket
# çerçevesi dahil), iksirin tonuna YALNIZ TON döndürülür (renk_ayar.rotate_hue, parlaklık/ışık deseni aynı).
# İksir öteki yetenek ikonlarındaki konular kadar büyük (karonun ~%78'i) ve aynı boru hattından geçer:
# 192 (48x4) bileşim -> LANCZOS 48 -> en yakın x3 = 144. Paket konularındaki açık kontur ayrı seçenek.
BG_TEMPLATES = [("PRI-C1", "ışın patlaması"), ("PRI-C2", "ışık perdesi"), ("PRI-A7", "ince ışınlar")]
WORK = 192


def potion_rgb(p):
    h = dominant_hue(p)
    return _rgb(0.75 if h is None else h, 0.8, 0.85)


def compose_pack(no, icons, template, outline):
    import renk_ayar as R
    _, n = SECIM[no]
    p = potion(n)
    bg = icons[template].convert("RGB").resize((WORK, WORK), Image.LANCZOS)
    bg = R.rotate_hue(bg, potion_rgb(p)).convert("RGBA")
    q = p.crop(p.getbbox())
    k = 8  # önce en yakın x8 (pikseller keskin kalır), sonra hedef boya yumuşak iniş
    q = q.resize((q.width * k, q.height * k), Image.NEAREST)
    th = round(WORK * 0.78)
    q = q.resize((round(q.width * th / q.height), th), Image.LANCZOS)
    x, y = (WORK - q.width) // 2, (WORK - q.height) // 2 + 2
    if outline:
        a = np.asarray(q.split()[-1]) > 96
        r = max(2, WORK // 48)  # ~1 sanat pikseli
        grown = a.copy()
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if dx * dx + dy * dy <= r * r:
                    grown |= np.roll(np.roll(a, dy, 0), dx, 1)
        ring = Image.new("RGBA", q.size, (0, 0, 0, 0))
        pr, pg, pb = potion_rgb(p)
        light = (int(pr * 0.35 + 255 * 0.65), int(pg * 0.35 + 255 * 0.65), int(pb * 0.35 + 255 * 0.65), 235)
        ring.putalpha(Image.fromarray((grown * 255).astype(np.uint8)))
        solid = Image.new("RGBA", q.size, light)
        solid.putalpha(Image.fromarray((grown * 235).astype(np.uint8)))
        bg.alpha_composite(solid, (x, y))
    bg.alpha_composite(q, (x, y))
    return bg.resize((ART, ART), Image.LANCZOS)


# sayfadaki seçenekler: kimlik -> (şablon, kontur, etiket)
OPTIONS = [("%s" % t.lower().replace("-", ""), (t, False, ad)) for t, ad in BG_TEMPLATES] + \
          [("%s_k" % t.lower().replace("-", ""), (t, True, ad + ", konturlu")) for t, ad in BG_TEMPLATES]
