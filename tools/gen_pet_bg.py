# EVCILE OZEL ARKA PLANLAR (madde 585, 2026-11-11). Kullanici: "petlerin bu ikonlardaki ve secim ekranindaki gorunusleri icin arkaplanlarina
# kendilerine ozgu bir arkaplan tasarlar misin". Karakter portresi arka planlariyla (madde 464, tools/gen_portrait_bg.py) AYNI dil:
# 28x28 sanat pikseli, duz bantlar + hayvanin kitinden TEK basit motif, hayvanin baskin renginin KARSITI (turuncu kopek -> serin aksam,
# beyaz hayalet -> gece), dither / hale / parilti yok; sonra ayni bulaniklik (gen_portre_odak.blur: gauss r BLUR_R=0.7 - madde 621, eskiden 1.4, + kenar tekrari + x0.85),
# oyunda shader YOK, doku hazir. Cizim yardimcilari gen_portre_tema.py'den.
# Cikti: assets/ui/pet_bg/<anahtar>.png (28x28) + --onizleme: tools/proto_20261111/evcil_bg/out/ozet.png (gercek evcil karesiyle, HUD 1x + secim 2x)
#   python -I tools/gen_pet_bg.py [--onizleme]   (sonra Godot --headless --import)
import os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools", "proto_20261108", "portre_tema"))
import gen_portre_tema as G
import gen_portre_odak as Od
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(ROOT, "assets", "ui", "pet_bg")
BLUR_R = 0.7  # madde 621: 1.4 -> 0.7 (kullanici "bulanikligi biraz kis", B secildi)
N = G.N  # 28


def kopek():  # turuncu-kizil kopek -> serin aksam camgobegi + koyu tepe + soluk ay (gece gezintisi)
    im = G.bands(["#6f9aa6", "#5f8a98", "#507a88", "#426a78"], [3, 3, 3, 2])
    G.disc(im, 6, 6, 3.4, "#ece6c8")
    G.disc(im, 7, 5, 1.2, "#d6cfae")
    h = [6, 6, 7, 7, 8, 8, 9, 9, 9, 10, 10, 10, 10, 9, 9, 8, 8, 8, 7, 7, 7, 8, 8, 9, 9, 9, 10, 10]
    G.silhouette(im, h, "#2f5246")
    G.silhouette(im, [max(0, v - 4) for v in h[::-1]], "#244236")
    return im


def papagan():  # kirmizi-mavi papagan -> tropik yesil gok + koselerden sarkan palmiye yapraklari (agac gagalar)
    im = G.bands(["#d4e6a0", "#bcd88a", "#a2c674", "#88b060"], [3, 3, 3, 2])
    for sx, d in [(0, 1), (27, -1)]:  # iki ust koseden asagi kivrilan yaprak demetleri
        for k in range(11):
            x = sx + d * k
            y = 1 + (k * k) // 12
            G.px(im, [(x, y), (x, y + 1)], "#3e7034")
            if k % 2 == 0 and k > 1:
                G.px(im, [(x, y + 2), (x - d, y + 3)], "#4e8640")
    G.rect(im, 0, 24, N, 4, "#6a9a4c")
    return im


def kelebek():  # lavanta-pembe kelebek -> altin saat cayiri + polen + alt kenarda cicek saplari
    im = G.bands(["#f4dca4", "#ecc886", "#ddb06a", "#c89654"], [3, 3, 3, 2])
    for (x, y) in [(4, 5), (20, 3), (24, 11), (9, 13)]:
        G.px(im, [(x, y)], "#fff6d8")
    for x in [3, 8, 14, 19, 25]:
        h = 5 + (x * 7) % 4
        G.rect(im, x, N - h, 1, h, "#9a7036")
        G.star(im, x, N - h - 1, "#f6f0e0")
        G.px(im, [(x, N - h - 1)], "#e09a3a")
    return im


def peri():  # camgobegi kanat, mavi elbise -> gul-seftali alacakaranlik + mantar halkasi (peri cemberi)
    im = G.bands(["#ecc0b4", "#e2aaa0", "#d4958e", "#bc7e7c"], [3, 3, 3, 2])
    for (x, w, h) in [(3, 5, 5), (11, 4, 4), (20, 5, 6)]:
        G.rect(im, x + w // 2 - 1, N - h + 2, 2, h - 2, "#f2e4cc")  # sap
        G.rect(im, x, N - h, w, 2, "#b0403a")  # sapka
        G.rect(im, x + 1, N - h - 1, w - 2, 1, "#b0403a")
        G.px(im, [(x + 1, N - h), (x + w - 2, N - h + 1)], "#f8ece0")  # benekler
    for (x, y) in [(6, 6), (22, 4), (15, 10)]:
        G.px(im, [(x, y)], "#fff4ea")
    return im


def kirpi():  # kahve kirpi -> serin gri-mavi gok + yosun zemin + dokulmus turuncu yapraklar (sonbahar orman tabani)
    im = G.bands(["#b8c6cc", "#a2b4bc", "#8aa28c", "#72906e"], [3, 3, 3, 3])
    for (x, y, c) in [(3, 23, "#d88a3e"), (9, 25, "#c0662e"), (17, 22, "#e0a04a"), (23, 25, "#d88a3e"), (13, 26, "#c0662e")]:
        G.px(im, [(x, y), (x + 1, y), (x + 1, y - 1)], c)
    for (x, y, c) in [(6, 6, "#d88a3e"), (21, 10, "#e0a04a")]:  # dusen yapraklar
        G.px(im, [(x, y), (x + 1, y + 1)], c)
    return im


def slime():  # acik yesil govde, pembe kulak -> mor buyu gecesi + altin yildizlar + kucuk iksir sisesi
    im = G.bands(["#3c2c5c", "#47346c", "#543e7c", "#302448"], [3, 3, 3, 2])
    for (x, y) in [(4, 4), (22, 6), (13, 2), (25, 16)]:
        G.star(im, x, y, "#f2d27a")
    G.rect(im, 3, 21, 5, 5, "#7a4a9a")  # sise govdesi
    G.rect(im, 4, 19, 3, 2, "#7a4a9a")
    G.rect(im, 4, 18, 3, 1, "#a07848")  # mantar tipa
    G.rect(im, 4, 23, 3, 2, "#c86ab8")  # iksir
    return im


def hayalet():  # beyaz hayalet -> gece mavisi + yerde sis bandi + uzakta sicak isikli perili pencere
    im = G.bands(["#2a3448", "#303c54", "#38465e", "#242c3e"], [3, 3, 3, 2])
    G.rect(im, 19, 4, 6, 7, "#e6b45c")
    G.rect(im, 21, 4, 1, 7, "#3a2c2a")
    G.rect(im, 19, 7, 6, 1, "#3a2c2a")
    G.rect(im, 18, 3, 8, 1, "#1c2232")
    G.rect(im, 18, 11, 8, 1, "#1c2232")
    for x in range(N):
        if x % 5 in (0, 1, 2):
            G.px(im, [(x, 21)], "#5a6a84")
    G.rect(im, 0, 22, N, 2, "#4a5872")
    return im


PETS = [
    ("kopek", kopek, "Akşam camgöbeği + tepe + ay"),
    ("papagan", papagan, "Tropik yeşil + palmiye yaprakları"),
    ("kelebek", kelebek, "Altın saat çayırı + polen + çiçekler"),
    ("peri", peri, "Gül-şeftali alacakaranlık + mantar halkası"),
    ("kirpi", kirpi, "Gri-mavi gök + yosun + dökülmüş yapraklar"),
    ("slime", slime, "Mor büyü gecesi + altın yıldızlar + iksir"),
    ("hayalet", hayalet, "Gece mavisi + sis + ışıklı perili pencere"),
]


def build():
    os.makedirs(OUT, exist_ok=True)
    out = {}
    for key, fn, _ in PETS:
        b = Od.blur(fn(), BLUR_R)
        b.save(os.path.join(OUT, "%s.png" % key))
        out[key] = b
    return out


def preview(bgs, pet_dir):
    # Her evcil: HUD yuvasi (28 ic alan, 1x, x3 sunum) + secim karosu (56 = 2x, x2 sunum). Evcil kareleri pet_dir/<anahtar>.png (Godot dokumu).
    here = os.path.join(ROOT, "tools", "proto_20261111", "evcil_bg", "out")
    os.makedirs(here, exist_ok=True)
    font = ImageFont.truetype(os.path.join(ROOT, "assets/fonts/m5x7.ttf"), 32)
    cw, ch = 260, 250
    sheet = Image.new("RGBA", (len(PETS) * cw + 24, ch + 60), G.C("#17110c"))
    d = ImageDraw.Draw(sheet)
    d.fontmode = "1"
    for i, (key, fn, desc) in enumerate(PETS):
        pet = Image.open(os.path.join(pet_dir, key + ".png")).convert("RGBA")
        x0 = 24 + i * cw
        d.text((x0, 8), key, font=font, fill=G.C("#f0c070"))
        # HUD 1x (28) -> x3
        hud = Image.new("RGBA", (36, 36), G.C("#2a1d14"))
        hud.alpha_composite(bgs[key], (4, 4))
        s = max(1, 32 // max(pet.size))
        p = pet.resize((pet.width * s, pet.height * s), Image.NEAREST)
        hud.alpha_composite(p, ((36 - p.width) // 2, (36 - p.height) // 2))
        sheet.alpha_composite(hud.resize((108, 108), Image.NEAREST), (x0, 50))
        # secim 56 (bg 2x) -> x2
        sel = bgs[key].resize((56, 56), Image.NEAREST)
        s2 = max(1, 56 // max(pet.size))
        p2 = pet.resize((pet.width * s2, pet.height * s2), Image.NEAREST)
        sel.alpha_composite(p2, ((56 - p2.width) // 2, (56 - p2.height) // 2))
        sheet.alpha_composite(sel.resize((112, 112), Image.NEAREST), (x0 + 120, 50))
        sheet.alpha_composite(fn().resize((112, 112), Image.NEAREST), (x0 + 120, 170))
        sheet.alpha_composite(bgs[key].resize((112, 112), Image.NEAREST), (x0, 170))
    sheet.save(os.path.join(here, "ozet.png"))
    print("onizleme", os.path.join(here, "ozet.png"))


if __name__ == "__main__":
    bgs = build()
    if "--onizleme" in sys.argv:
        preview(bgs, sys.argv[sys.argv.index("--onizleme") + 1])
    print("ok", len(bgs))
