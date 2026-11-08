# PORTRE ODAK onizlemesi (2026-11-08, madde 459 devami; oyuna bagli DEGIL). Kullanici: "arkaplanlari biraz daha koyu veya blurlu olabilir mi
# karakterlerin ozne olmasi gerekiyor". Cerceveleme Buyucu orani (gen_portre_zoom.py EYE_AT_PANEL / EYE_AT_PARTY, 3x).
# Arka plan islemleri (28x28 sanat pikseli uzerinde, oyunda yuzle ayni 3x):
#   A Koyu       : deger %40 dusuk + %30 soluk (gri yerine bandin kendi koyusu)
#   B Bulanik    : sanat pikselinde gauss bulaniklik (r 1.4) + %15 kisik -> odak disi; keskin yuz ondunde
#   C Koyu+Bulanik
# Cikti: out/odak_ozet.png (her kartta panel SU AN | A | B | C, altinda grup SU AN | A | B | C, 2x buyutulmus)
#   python -I tools/proto_20261108/portre_tema/gen_portre_odak.py
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_portre_tema as G
import gen_portre_zoom as Zm
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT = os.path.join(HERE, "out")
ROOT = G.ROOT


def darken(im, value=0.60, sat=0.70):
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            l = 0.299 * r + 0.587 * g + 0.114 * b
            r, g, b = (l + (r - l) * sat, l + (g - l) * sat, l + (b - l) * sat)
            px[x, y] = (int(r * value), int(g * value), int(b * value), a)
    return out


def blur(im, radius=1.4, dim=0.85):
    # kenar tekrari: bulaniklik kenarda siyaha akmasin
    pad = 4
    big = Image.new("RGBA", (im.width + 2 * pad, im.height + 2 * pad))
    big.paste(im.resize((im.width + 2 * pad, im.height + 2 * pad), Image.NEAREST), (0, 0))
    big.paste(im, (pad, pad))
    b = big.filter(ImageFilter.GaussianBlur(radius)).crop((pad, pad, pad + im.width, pad + im.height))
    return darken(b, dim, 1.0)


MODES = [
    ("ŞU AN", lambda b: b),
    ("A Koyu", lambda b: darken(b)),
    ("B Bulanık", lambda b: blur(b)),
    ("C Koyu + Bulanık", lambda b: darken(blur(b, 1.4, 1.0), 0.66, 0.75)),
]


def main():
    tray = Image.open(os.path.join(ROOT, "assets/ui/kit/hud_avatar_tray.png")).convert("RGBA")
    plaque = Image.open(os.path.join(ROOT, "assets/ui/kit/hud_level_tray.png")).convert("RGBA")
    font = ImageFont.truetype(os.path.join(ROOT, "assets/fonts/m5x7.ttf"), 32)
    Z = 2
    n_modes = len(MODES)
    cw, ch = n_modes * 88, 104 + 62
    cols = 3
    lab = 36
    W = cols * (cw * Z + 32) + 32
    cell = lab + ch * Z + 28
    rows = (len(G.CHARS) + cols - 1) // cols
    sheet = Image.new("RGBA", (W, rows * cell + 32 + 44), G.C("#17110c"))
    d = ImageDraw.Draw(sheet)
    d.fontmode = "1"
    d.text((32, 10), "Her kartta soldan sağa: " + "  |  ".join(m[0] for m in MODES) + "   (üstte panel, altta grup paneli; hepsi 3x, Büyücü çerçevesi)",
           font=font, fill=G.C("#c4b090"))
    for i, (cid, name, key, fn, desc) in enumerate(G.CHARS):
        bg0 = fn()
        f = G.face(os.path.join(ROOT, "assets/characters/%s_portrait.png" % key))
        eye = Zm.EYES.get(cid, 12.0)
        card = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        cd = ImageDraw.Draw(card)
        cd.fontmode = "1"
        for m, (mname, op) in enumerate(MODES):
            bg = op(bg0)
            x0 = m * 88
            # panel: 18x18 yuz 3x = 54 px, tepsinin ic 60 alanina ortali
            card.alpha_composite(tray, (x0, 0))
            card.alpha_composite(bg.crop(Zm.bg_box(18)).resize((54, 54), Image.NEAREST), (x0 + 15, 15))
            card.alpha_composite(f.crop(Zm.crop_box(eye, 18, Zm.EYE_AT_PANEL)).resize((54, 54), Image.NEAREST), (x0 + 15, 15))
            card.alpha_composite(plaque, (x0 + 15, 65))
            cd.text((x0 + 15 + 17, 65 + 9), "12", font=font, fill=G.C("#f3e6cc"))
            # grup avatari: 16x16 yuz 3x = 48 px
            gx, gy = x0 + 16, 110
            cd.rectangle((gx, gy, gx + 51, gy + 51), fill=G.C("#20150d"))
            card.alpha_composite(bg.crop(Zm.bg_box(16)).resize((48, 48), Image.NEAREST), (gx + 2, gy + 2))
            card.alpha_composite(f.crop(Zm.crop_box(eye, 16, Zm.EYE_AT_PARTY)).resize((48, 48), Image.NEAREST), (gx + 2, gy + 2))
        x = 32 + (i % cols) * (cw * Z + 32)
        y = 32 + 44 + (i // cols) * cell
        d.text((x, y), name, font=font, fill=G.C("#f0c070"))
        sheet.alpha_composite(card.resize((cw * Z, ch * Z), Image.NEAREST), (x, y + lab))
    sheet.save(os.path.join(OUT, "odak_ozet.png"))
    print("ok", sheet.size)


if __name__ == "__main__":
    main()
