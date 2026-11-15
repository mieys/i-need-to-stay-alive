"""Hadime E "Lanet Çukuru" (eski Kara Delik, madde 561) için masaüstü 'Genel iconlar' paketlerinden ikon önerileri (2026-11-11).

Her satır Hadime'nin seti: Pasif | Q | E (aday) | R, oyundaki biçimde (LANCZOS 48 + en yakın x3 = 144, uygula.make_icon gibi).
Mevcut E ikonu (UND-A2, mor girdap) kara deliğe göre seçilmişti. Renk: yalnız ton (renk_ayar.rotate_hue, parlaklık aynı).
  python -I tools/proto_20261109/yetenek_ikon/hadime_e_oneri.py   ->  out/hadime_e/oneri.png
"""

import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ikon_secim as K  # noqa: E402
import renk_ayar as RA  # noqa: E402

SKILLS = os.path.join(HERE, "..", "..", "..", "assets", "skills")
OUT = os.path.join(HERE, "out", "hadime_e")
CURSE_GREEN = (111, 220, 74)   # efektteki lanet ışığı (gen_hadime_cukur_fx.py CG2)

# (kimlik, paket anahtarı, yeşile çevir mi, açıklama)
ADAYLAR = [
    ("a", "DM2-E8", False, "kara cukur + yayilan catlaklar"),
    ("a_yesil", "DM2-E8", True, "ayni, isik efektteki lanet yesili"),
    ("b", "WAR-E6", False, "yesil isikli catlaklar"),
    ("c", "CUR-B6", False, "kuru toprak catlaklari"),
    ("d", "EAR-A7", False, "catlayan zemine dusen kaya"),
    ("e", "WAR-F2", False, "yesil kenarli cukur, ortada run"),
]


# Set uyumu (kullanıcı: "Q mor, R yeşil tonlara; pasifin arka planı sarı yerine hafif koyu mor"): no -> [(kimlik, açıklama, işlev)].
# İşlev 144'lük LANCZOS kırpımı alır (uygula.make_icon gibi). bg_behind_outline: figür konturun içinde kilitli, yalnız zemin
# döner (PIL HSV ton 0-255: mor 196, lanet yeşili 72); rotate_hue: yalnız ton, parlaklık aynı.
PURPLE = (150, 92, 204)    # Hadime lanet moru (gen_hadime_fx V_LIGHT)
DARK_PURPLE = (92, 50, 130)


def warm_band(im):
    """Paket zeminlerinin sıcak tonları (PIL ton 0-55, doygun); soluk figürler (gri hayalet) ağırlık almaz."""
    return RA.hue_band(im, -20, 55, min_sat=60, soft=14)


def outside_figure(im, lo=140, hi=225):
    """Mor/koyu figür (ton lo..hi ya da V<90) + figürün ÇEVRELEDİĞİ her şey (ağız, göz) korunur: kenardan figüre değmeden ulaşılan
    piksel = zemin. bg_behind_outline bu ikonlarda kontur bulamayıp figürü zemine sızdırıyordu."""
    hsv = np.asarray(im.convert("HSV")).astype(int)
    h, sat, val = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    # figür = mor + KOYU pikseller (iblisin siyah gövdesi/dişleri ağzı çevreler; turuncu zeminin en koyusu bile V ~140)
    fig = ((h >= lo) & (h <= hi) & (sat >= 40)) | (val < 90)
    fig = RA._dilate(fig, 1)
    H, W = fig.shape
    out = np.zeros((H, W), bool)
    # dolgu paketin koyu ÇERÇEVESİNİN içindeki halkadan başlar (çerçeve de koyu = "figür" sayılır)
    m = 8
    stack = [(y, x) for y in range(m, H - m) for x in (m, W - 1 - m)] + [(y, x) for x in range(m, W - m) for y in (m, H - 1 - m)]
    stack = [(y, x) for y, x in stack if not fig[y, x]]
    for y, x in stack:
        out[y, x] = True
    while stack:
        y, x = stack.pop()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < H and 0 <= nx < W and not out[ny, nx] and not fig[ny, nx]:
                out[ny, nx] = True
                stack.append((ny, nx))
    return out.astype(float)


SET_RENK = {
    # Pasif: sarı zemin -> hafif koyu mor (yalnız ton + parlaklık; gri hayalet doygun olmadığı için değişmez)
    49: [("a", "zemin hafif koyu mor", lambda im: RA.rotate_hue(im, DARK_PURPLE, weight=warm_band(im), luma=0.68)),
         ("b", "zemin daha koyu mor", lambda im: RA.rotate_hue(im, DARK_PURPLE, weight=warm_band(im), luma=0.52))],
    # Q: kırmızı zemin + sayfalar mor, mavi kol aynı
    50: [("a", "mor, biraz koyu", lambda im: RA.rotate_hue(im, PURPLE, weight=warm_band(im), luma=0.82)),
         ("b", "mor", lambda im: RA.rotate_hue(im, PURPLE, weight=warm_band(im)))],
    # R: turuncu zemin -> lanet yeşili; mor iblis + ağzı/gözleri korunur
    52: [("a", "zemin lanet yesili", lambda im: RA.rotate_hue(im, CURSE_GREEN, weight=warm_band(im) * outside_figure(im))),
         ("b", "zemin koyu yesil", lambda im: RA.rotate_hue(im, CURSE_GREEN, weight=warm_band(im) * outside_figure(im), luma=0.75))],
}
SET_KEYS = {49: "CUR-C3", 50: "UND-F8", 52: "CUR-E8"}


def set_tone(icons, no, kid):
    im = icons[SET_KEYS[no]].convert("RGB").resize((144, 144), Image.LANCZOS)
    fn = next(f for k, _, f in SET_RENK[no] if k == kid)
    return game_icon(fn(im))


def set_sheet(icons):
    """Satır = yuva (Pasif / Q / R): şu an | a | b; altta önerilen tam set (a'lar + yeni E)."""
    T, G, LAB = 144, 10, 230
    names = {49: "Pasif (Ruh Gocu)", 50: "Q Lanet Kitabi", 52: "R Karabasan"}
    files = {49: "hadime_passive_icon", 50: "hadime_lanet_kitabi_icon", 52: "hadime_karabasan_icon"}
    rows = list(SET_RENK)
    H = 34 + len(rows) * (T + 40) + 60 + T + 20
    sheet = Image.new("RGB", (LAB + 3 * (T + G) + 20, H), K.BG)
    d = ImageDraw.Draw(sheet)
    fb, fs = K.font(18, True), K.font(15)
    for n, t in enumerate(("SU AN", "a", "b")):
        d.text((LAB + n * (T + G) + 4, 6), t, fill=K.GOLD if n else (240, 90, 80), font=fb)
    for i, no in enumerate(rows):
        y = 34 + i * (T + 40)
        d.text((10, y + 50), names[no], fill=K.INK, font=fb)
        sheet.paste(own(files[no]), (LAB, y))
        for n, (kid, why, _) in enumerate(SET_RENK[no]):
            x = LAB + (n + 1) * (T + G)
            sheet.paste(set_tone(icons, no, kid), (x, y))
            d.text((x, y + T + 4), why, fill=K.DIM, font=fs)
    y = 34 + len(rows) * (T + 40) + 20
    d.text((10, y), "Onerilen set: Pasif b, Q b, yeni E, R a", fill=K.GOLD, font=fb)
    y += 30
    e = own("hadime_kara_delik_icon")
    for n, im in enumerate((set_tone(icons, 49, "b"), set_tone(icons, 50, "b"), e, set_tone(icons, 52, "a"))):
        sheet.paste(im, (10 + n * (T + 4), y))
    os.makedirs(OUT, exist_ok=True)
    sheet.save(os.path.join(OUT, "set_renk.png"))
    print("set_renk", sheet.size)


def game_icon(img):
    im = img.convert("RGB").resize((144, 144), Image.LANCZOS)
    return im.resize((48, 48), Image.LANCZOS).resize((144, 144), Image.NEAREST)


def to_green(img):
    """Sıcak ışık (kırmızı-turuncu-sarı) -> lanet yeşili; koyu çatlaklar ve kara merkez aynı kalır (düşük doygunluk)."""
    im = img.convert("RGB").resize((144, 144), Image.LANCZOS)
    w = RA.hue_band(im, -20, 48, min_sat=40, soft=14)
    return RA.rotate_hue(im, CURSE_GREEN, weight=w)


def own(name):
    return Image.open(os.path.join(SKILLS, name + ".png")).convert("RGB").resize((144, 144), Image.NEAREST)


def main():
    icons = K.load_icons()
    p, q, r = own("hadime_passive_icon"), own("hadime_lanet_kitabi_icon"), own("hadime_karabasan_icon")
    rows = [("SU AN (UND-A2)", "mor girdap - kara delik icin secilmisti", own("hadime_kara_delik_icon"))]
    for kid, key, green, why in ADAYLAR:
        src = to_green(icons[key]) if green else icons[key]
        rows.append(("%s  %s%s" % (kid, key, " yesil" if green else ""), why, game_icon(src)))
    T, G, LAB = 144, 8, 300
    head = 30
    W = LAB + 4 * (T + G)
    H = head + len(rows) * (T + G)
    sheet = Image.new("RGB", (W, H), K.BG)
    d = ImageDraw.Draw(sheet)
    fb, fs = K.font(20, True), K.font(16)
    for n, t in enumerate(("Pasif", "Q Lanet Kitabi", "E Lanet Cukuru", "R Karabasan")):
        d.text((LAB + n * (T + G) + 4, 4), t, fill=K.GOLD if n == 2 else K.DIM, font=fs)
    for i, (title, why, e_icon) in enumerate(rows):
        y = head + i * (T + G)
        d.text((10, y + 40), title, fill=K.GOLD if i else (240, 90, 80), font=fb)
        d.text((10, y + 70), why, fill=K.DIM, font=fs)
        for n, im in enumerate((p, q, e_icon, r)):
            x = LAB + n * (T + G)
            sheet.paste(im, (x, y))
            if n == 2:
                d.rectangle((x - 3, y - 3, x + T + 2, y + T + 2), outline=K.GOLD, width=2)
    os.makedirs(OUT, exist_ok=True)
    sheet.save(os.path.join(OUT, "oneri.png"))
    print("tamam", sheet.size)


if __name__ == "__main__":
    if "--set" in sys.argv:
        set_sheet(K.load_icons())
    else:
        main()
