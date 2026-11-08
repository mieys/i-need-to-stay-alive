# YUZ YAKINLASTIRMA onizlemesi (2026-11-08, madde 459 devami; oyuna bagli DEGIL). Kullanici: "arkaplanlarini begendim ancak karakterin
# odakli gorunmesi icin birsey yapmamiz lazim yuzlerini yakinlastirmayi dene once" + "bazilari yuze degil de alt vucuda daha odakli gibi
# yuzlere odakli olmalı".
# Kaynak: 24x24 bas kirpimi (LobbyUI.face_texture). Kirpim GOZ SATIRINA gore yerlesir: gozler kirpim yuksekliginin EYE_AT'inde (portre
# kurali ~%42), yatayda yuz ortada. Iki yakinlik:
#   3x: panel 18x18 (54 px), grup 16x16 (48 px)     4x: panel 14x14 (56 px), grup 12x12 (48 px)
# Arka plan ayni katla (ayni piksel izgarasi), 28x28 tasarimin ortasi.
# EYES: 24'luk kirpimda goz satiri (out/../cetvel olcumu, 2026-11-08).
#   python -I tools/proto_20261108/portre_tema/gen_portre_zoom.py
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_portre_tema as G
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(HERE, "out")
ROOT = G.ROOT
EYES = {1: 10.5, 2: 14, 3: 12, 4: 16, 5: 15, 7: 12, 8: 11.5, 9: 12, 10: 14, 11: 13, 12: 14.5, 13: 12, 14: 12.5, 15: 14}
EYE_AT = 0.42
## Kullanici (2026-11-08): "buyucu kizin su hali gibi olsa cok iyi olur ... digerleri de bunun gibi olmali yuz konumlandirmasinda":
## Buyucu 3x'te alttan kirpildigi icin gozleri panelde 10/18 (~%56), grupta 8/16 (%50) satirdaydi -> herkes ayni oranla.
EYE_AT_PANEL = 10.0 / 18.0
EYE_AT_PARTY = 8.0 / 16.0


def crop_box(eye: float, n: int, at: float = EYE_AT) -> tuple:
    """24'luk kirpim icinde n x n kare: gozler n*at satirinda, yatay orta."""
    oy = int(round(eye - at * n))
    oy = max(0, min(24 - n, oy))
    ox = (24 - n) // 2
    return (ox, oy, ox + n, oy + n)


def bg_box(n: int) -> tuple:
    """28'lik arka planda n x n orta (biraz yukari: motifler ust yarida)."""
    ox = (28 - n) // 2
    oy = max(0, (28 - n) // 2 - 1)
    return (ox, oy, ox + n, oy + n)


def main():
    tray = Image.open(os.path.join(ROOT, "assets/ui/kit/hud_avatar_tray.png")).convert("RGBA")
    plaque = Image.open(os.path.join(ROOT, "assets/ui/kit/hud_level_tray.png")).convert("RGBA")
    font = ImageFont.truetype(os.path.join(ROOT, "assets/fonts/m5x7.ttf"), 32)
    Z = 2
    cw, ch = 300, 100  # kart: [panel 3x | panel 4x] [grup 3x | grup 4x]
    cols = 4
    lab = 36
    W = cols * (cw * Z + 24) + 24
    cell = lab + ch * Z + 24
    rows = (len(G.CHARS) + cols - 1) // cols
    sheet = Image.new("RGBA", (W, rows * cell + 24 + 40), G.C("#17110c"))
    d = ImageDraw.Draw(sheet)
    d.fontmode = "1"
    d.text((24, 8), "Her kartta: panel ÖNCEKİ | panel YENİ (Büyücü gibi)     grup ÖNCEKİ | grup YENİ   (hepsi 3x)", font=font, fill=G.C("#c4b090"))
    for i, (cid, name, key, fn, desc) in enumerate(G.CHARS):
        bg = fn()
        f = G.face(os.path.join(ROOT, "assets/characters/%s_portrait.png" % key))
        eye = EYES.get(cid, 12.0)
        card = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        cd = ImageDraw.Draw(card)
        cd.fontmode = "1"

        def panel(x0, k, at_override=None):
            n = 18 if k == 3 else 14
            card.alpha_composite(tray, (x0, 0))
            px = n * k
            off = 12 + (60 - px) // 2
            card.alpha_composite(bg.crop(bg_box(n)).resize((px, px), Image.NEAREST), (x0 + off, off))
            card.alpha_composite(f.crop(crop_box(eye, n, at_override if at_override is not None else (EYE_AT_PANEL if k == 3 else EYE_AT))).resize((px, px), Image.NEAREST), (x0 + off, off))
            card.alpha_composite(plaque, (x0 + 15, 65))
            cd.text((x0 + 15 + 17, 65 + 9), "12", font=font, fill=G.C("#f3e6cc"))

        def party(x0, k, at_override=None):
            n = 16 if k == 3 else 12
            cd.rectangle((x0, 10, x0 + 51, 61), fill=G.C("#20150d"))
            card.alpha_composite(bg.crop(bg_box(n)).resize((48, 48), Image.NEAREST), (x0 + 2, 12))
            card.alpha_composite(f.crop(crop_box(eye, n, at_override if at_override is not None else (EYE_AT_PARTY if k == 3 else EYE_AT))).resize((48, 48), Image.NEAREST), (x0 + 2, 12))

        panel(0, 3, EYE_AT)   # onceki 3x (%42)
        panel(88, 3)          # yeni: Buyucu orani
        party(184, 3, EYE_AT)
        party(242, 3)
        big = card.resize((cw * Z, ch * Z), Image.NEAREST)
        x = 24 + (i % cols) * (cw * Z + 24)
        y = 24 + 40 + (i // cols) * cell
        d.text((x, y), name, font=font, fill=G.C("#f0c070"))
        sheet.alpha_composite(big, (x, y + lab))
    sheet.save(os.path.join(OUT, "yakin_ozet.png"))
    print("ok", sheet.size)


if __name__ == "__main__":
    main()
