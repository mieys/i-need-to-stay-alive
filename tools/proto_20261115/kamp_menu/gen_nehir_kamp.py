# ANA MENÜ "Nehir Kenarı Kampı" arka planı (2026-11-15). Kullanıcı: "Şovalye, Oakley, Hadime, Matthew, Talon ve Elara'nın ana haritanın cozy
# nehir kenarı bir kısmında, hafif loş günbatımı olmak üzere olan havada kamp yapıp bazılarının oturduğu, iyi vakit geçirdiği; kamp ateşi ve birkaç
# yiyeceğin olduğu cozy bir sahne. Hava hep günbatımı tadında kalacak."
#
# Taban = ANA HARİTANIN gerçek çizici yakalaması (kamp_capture.gd, kadraj "kadrajA" = hücre (140.6, 111.2) merkezli 320x180 DÜNYA px: sol üstten
# çapraz akan nehir, sağ üstte pembe ağaçlar + mantarlar, ortada açık çayır). Üstüne oyunun KENDİ sanatından yer eşyaları pişirilir (kütük,
# minder, yastık, örtü, yiyecekler). Ateş çukuru (kazanlı, kor animasyonlu; korları ayrıca kamp_ates_kor.png) + karakterler Godot'ta canlı
# çizilir (menu_camp_scene.gd);
# günbatımı tonu + ateş ışığı + sudaki yansıma shader'da (shaders/kamp_gunbatimi.gdshader) - BURADA ışık/ton YOK (ışıksız taban).
# Oyunda x6 (1920x1080). Yer eşyalarının konumları burada; ateş/karakter konumları menu_camp_scene.gd'de (ikisi aynı dünya px uzayında).
#
#   python -I tools/proto_20261115/kamp_menu/gen_nehir_kamp.py           -> out/nehir_kamp_onizleme.png (x3)
#   python -I tools/proto_20261115/kamp_menu/gen_nehir_kamp.py --oyun    -> assets/ui/ana_menu/nehir_kamp.png + nehir_kamp_su.png + kamp_ates_kor.png
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
EV = os.path.join(ROOT, "harita", "Ev içi")
KAMP = os.path.join(ROOT, "tools", "kamp", "kaynak")
W, H = 320, 180

# (kaynak, kutu) - kutu sayfa pikselinde; kırpılıp alfa sınırına daraltılır.
SRC = {
    "kutuk_yatay": (os.path.join(KAMP, "Tents_n_objects.png"), (202, 613, 247, 626)),
    "kutuk_yatay2": (os.path.join(KAMP, "Tents_n_objects.png"), (285, 636, 330, 649)),
    "hasir": (os.path.join(KAMP, "Tents_n_objects.png"), (74, 690, 105, 715)),
    "hasir2": (os.path.join(KAMP, "Tents_n_objects.png"), (224, 724, 255, 749)),
    "kutuk_tabure": (os.path.join(ROOT, "harita", "Exterior_objects.png"), (190, 430, 222, 462)),
    "kirmizi_ortu": (os.path.join(EV, "Interior_objects.png"), (409, 13, 439, 50)),
    "yastik": (os.path.join(KAMP, "Tents_n_objects.png"), (206, 656, 229, 681)),
    "elma_cuvali": (os.path.join(KAMP, "Tents_n_objects.png"), (179, 694, 195, 713)),
    "sebze_kasesi": (os.path.join(EV, "Interior.png"), (8, 375, 24, 392)),
    "domates": (os.path.join(EV, "Interior.png"), (164, 370, 174, 381)),
    "sarimsak": (os.path.join(EV, "Interior.png"), (180, 371, 189, 382)),
    "ekmek": (os.path.join(EV, "Interior.png"), (163, 387, 173, 397)),
    "testi": (os.path.join(EV, "Interior.png"), (82, 376, 96, 392)),
    "tabaklar": (os.path.join(EV, "Avci_esyalari.png"), (242, 65, 254, 79)),
    "tahil_kasesi": (os.path.join(EV, "Avci_esyalari.png"), (321, 66, 334, 79)),
    "kase": (os.path.join(EV, "Avci_esyalari.png"), (306, 68, 318, 78)),
    "sise": (os.path.join(EV, "Avci_esyalari.png"), (292, 65, 301, 79)),
}

# Düz yer örtüleri (önce, sırasız) + eşyalar (ayak y'ye göre sıralı). (parça, ayak ortası x, ayak y) - dünya px (kadraj içi).
# Ateş çukuru ayağı menu_camp_scene.gd FIRE_FOOT = (170, 141); karakterler PARTY.
FLATS = [
    ("yastik", 139, 138),             # batı: Talon'un yastıkları
    ("kirmizi_ortu", 205, 177),       # güneydoğu: yiyecek örtüsü
]
PROPS = [
    ("kutuk_yatay", 170, 108),        # kuzey: Şovalye + Matthew'in oturduğu kütük
    ("kutuk_tabure", 209, 139),       # doğu: Elara'nın oturduğu ağaç kütüğü (tabure)
    ("ekmek", 197, 152),
    ("tabaklar", 212, 153),
    ("sebze_kasesi", 204, 158),
    ("domates", 196, 162),
    ("tahil_kasesi", 214, 165),
    ("testi", 199, 172),
    ("elma_cuvali", 211, 175),
    ("sise", 222, 160),
]


def cut(name):
    path, box = SRC[name]
    im = Image.open(path).convert("RGBA").crop(box)
    bb = im.getbbox()
    return im.crop(bb) if bb else im


def compose(base):
    img = base.copy()
    for name, fx, fy in FLATS + sorted(PROPS, key=lambda p: p[2]):
        spr = cut(name)
        img.alpha_composite(spr, (round(fx - spr.width / 2), round(fy - spr.height)))
    return img


def water_mask(base):
    """Su pikselleri (nehir mavisi) = beyaz; kıyı köpüğü/nilüfer hariç. Shader yansımayı yalnız burada çizer."""
    m = Image.new("L", base.size, 0)
    src = base.load()
    dst = m.load()
    for y in range(base.height):
        for x in range(base.width):
            r, g, b, a = src[x, y]
            if b > g + 6 and b > r + 25 and g < 150:
                dst[x, y] = 255
    return m


def fire_embers():
    """Ateş çukurunun (assets/map/kamp/ates.png, 12 kare) KENDİ ateşi = kazanın altındaki sıcak kor pikselleri (tek renk). Yalnız onlar
    kalır: menu_camp_scene.gd bu şeridi günbatımı katmanının ÜSTÜNDE çukurla aynı karede çizer (loşlukta sönmesin)."""
    src = Image.open(os.path.join(ROOT, "assets", "map", "kamp", "ates.png")).convert("RGBA")
    out = Image.new("RGBA", src.size, (0, 0, 0, 0))
    sp = src.load()
    op = out.load()
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = sp[x, y]
            if a > 0 and r > 200 and r > b + 100:
                op[x, y] = (r, g, b, a)
    return out


def main():
    base = Image.open(os.path.join(HERE, "out", "kadrajA.png")).convert("RGBA")
    assert base.size == (W, H), base.size
    img = compose(base)
    mask = water_mask(base)
    if "--oyun" in sys.argv:
        out = os.path.join(ROOT, "assets", "ui", "ana_menu")
        img.save(os.path.join(out, "nehir_kamp.png"))
        mask.save(os.path.join(out, "nehir_kamp_su.png"))
        fire_embers().save(os.path.join(out, "kamp_ates_kor.png"))
        print("yazildi:", out)
    prev = img.resize((W * 3, H * 3), Image.NEAREST)
    prev.save(os.path.join(HERE, "out", "nehir_kamp_onizleme.png"))
    mask.resize((W * 2, H * 2), Image.NEAREST).save(os.path.join(HERE, "out", "nehir_kamp_su_onizleme.png"))


if __name__ == "__main__":
    main()
