# ANA MENÜ kamp sahnesi için ELLE DÜZENLENMİŞ karakter kareleri (2026-11-15, menu_camp_scene.gd PARTY'de "res://..." klibi):
# 1) hadime_uzanik.png - Hadime YERDE OTURMUŞ, GERİYE YASLANMIŞ, BACAKLARI ÖNE UZANMIŞ tek kare.
# Kullanıcı: "hadimenin yere ayaklarını uzatıp oturma pozisyonunu (sit_right karesini) kendin düzelterek ayaklarını uzatıp yere yaslanıp
# ayaklarını uzatmış gibi göster". Oyunda böyle bir klip yok -> elle piksel kare: baş + saç = sit_right SON karesinin kendi pikselleri
# (2 px geriye, 4 px aşağı), gövde geriye eğik, sol kol arkada yere dayalı (el yerde), bacaklar cübbe altında sağa uzanır, çizmeler ucu yukarı.
# Palet Hadime'nin kendi renkleri (A-Q harfleri sheets/idle.png'den). 48x48, ayak tabanı y=39 (sit/idle ile aynı zemin).
# 2) (matthew_yemek.png - Matthew'in elinde tavuk budu - 2026-11-16 KALKTI, kullanıcı: "Matthew'in solundaki yiyeceği kaldır"; Matthew
#    artık kendi sit_down klibiyle oturur.)
#   python -I tools/proto_20261115/kamp_menu/gen_kamp_kareler.py  -> assets/ui/ana_menu/{hadime_uzanik,talon_olta,talon_olta_kamis,mesale_govde,mesale_alev,
#                                                                 gece_kamp_atesi(_alev),kamp_esya_*}.png + out/kamp_kareler_x10.png
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
PAL = {
    "A": (23, 18, 18), "B": (25, 25, 30), "C": (29, 29, 34), "D": (246, 226, 214), "E": (135, 77, 54), "F": (240, 204, 180),
    "G": (42, 60, 16), "H": (255, 240, 247), "I": (47, 91, 11), "J": (64, 124, 8), "K": (226, 171, 131), "L": (58, 45, 56),
    "M": (255, 200, 79), "N": (8, 31, 11), "O": (12, 44, 26), "P": (22, 66, 47), "Q": (34, 18, 16),
}
X0 = 8   # 0. sütun = karede x 8
Y0 = 13  # ilk satır = karede y 13
ART = [
    # baş + saç (sit_right son karesi satır 9-23, aynen)
    "......AAAAAA........",
    ".....ABCCCCBA.......",
    "....ABCCCCCCBA......",
    "...ABCCCCCBAAB......",
    "...ABCCCBBAAAA......",
    "..ABBBBBBADDDE......",
    "..ABBBBBBADDDE......",
    "..ABBBBBADDDDE......",
    "..ABBBBBAFGGFE......",
    "..ABBBBBAGHIFE......",
    "..ABBBBBAGHJDE......",
    "...ABBBBAFFFKE......",
    "....ABBBAKKKE.......",
    ".....ABBBAEE........",
    "......ABBBA.........",
    # gövde geriye eğik; kol omuzdan hafif geriye neredeyse dik iner (2 ton dolgu + dış hat), el yerde düz
    ".....ACCCBLB........",
    ".....ACLCBLLA.......",
    "...ALCCLCCBLA.......",
    "...ALCCLCCLLA.......",
    "..ALCAACLLCCLA......",
    "..ALCAACCMMCLA......",
    ".ALCA.ACLCCCLCA.....",
    ".ALCA.ACLCCLLCCAAAAA...NN...",
    "AFFKA.ACLLCCLCCCLCCLA.NPON..",
    "AFFFKAACCLCCCLLCCCLCANOPPN..",
    ".AAAA..ACCCLCCCLCCCCANOOON..",
    ".......AAAAAAAAAAAAAANNNNN..",
]


def build():
    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    px = img.load()
    for r, row in enumerate(ART):
        for c, ch in enumerate(row):
            if ch != ".":
                px[X0 + c, Y0 + r] = PAL[ch] + (255,)
    return img


# 3) talon_olta.png - Talon'un KENDİ idle_left kareleri (uzama karesi hariç, 4 slotluk yatay şerit 192x48) + her karede öne uzanmış
#    kol ve yumruk (kullanıcı: "talon elinde oltayı tutmuyor"; idle karesinde kol pelerinin altında, el görünmüyor). Kol göğüs hizasında
#    (y 26-29) gövdenin önünden sola uzanır, yumruk x 16-17. Gövde idle'da 1 px iner-kalkar ama KOL + YUMRUK HER KAREDE AYNI YERDE
#    (kullanıcı: "olta elinde sabit durmuyor" - kol önce gövdeyle kayıyordu). Kolla gövde arasındaki saydam sütunlar her karede gövdeye
#    kadar doldurulur (ilk sürümde x 20 boş kalınca "eli kesik" duruyordu).
#    Olta (menu_camp_scene.gd FishingRod) Talon'dan ÖNCE çizilir ve TALON_FIST'ten başlar -> kamış yumruğun arkasından geçer.
TALON_PAL = {"A": (26, 14, 3), "F": (221, 178, 119), "G": (205, 150, 90), "I": (29, 29, 34), "S": (58, 45, 56)}
TALON_XY = (15, 26)
TALON_KOL = [
    ".AAAA",   # üst hat
    "AFGSS",   # yumruk (F/G) + yen (S açık)
    "AGGII",   # yen (I koyu)
    ".AAAA",   # alt hat
]
TALON_FILL = ["A", "S", "I", "A"]  # kolun sağındaki boşluğu gövdeye kadar dolduran renk (satır başına)


# 4) DİKİLİ MEŞALE (kullanıcı 2026-11-15: el meşalesi denemeleri olmadı -> "yanına meşale falan ekle; elle taşınan kutu gibi meşaleler var
#    ya, onları yere bırakmış olsun" -> Şifa Feneri ikonu konuldu -> "bu şifa fenerinin ikonu, bunu kullanamazsın"). Oyunun DÜNYA sanatında
#    taşınan kutu fener yok (ev/köy/kamp/zindan/kış setleri tarandı: meşale, mangal, kamp ateşi, duvar kandili, mum var). Ayaz Dağı haritasının
#    KENDİ dikili meşalesi (harita/kis/k_nesne.png, atlas "mesale": döşeme (4, 0), 10x56, 6 kare DİKEY 80 px arayla, 150 ms) Talon'un yanında
#    yere dikili; haritadaki boyu Talon'un ~2,5 katı -> YARIM boyut (2x2 öbekte alev pikseli varsa en parlak alev rengi, yoksa çoğunluk) 5x28,
#    menüde dünya ölçeğinde (x MAP_K, kütükle aynı piksel). mesale_govde.png = sargı + direk + taban (alevsiz, kare 0), mesale_alev.png =
#    6 kare yalnız alev (ışık katmanının üstünde) - menu_camp_scene.gd LANTERN_*.
MESALE_PATH = os.path.join(ROOT, "harita", "kis", "k_nesne.png")
MESALE_FLAME = {(194, 119, 73), (216, 146, 77), (252, 183, 87), (255, 219, 119)}


def _lum(c):
    return c[0] * 0.3 + c[1] * 0.59 + c[2] * 0.11


def _half(fr):
    w, h = fr.size
    out = Image.new("RGBA", (w // 2, h // 2), (0, 0, 0, 0))
    sp, op = fr.load(), out.load()
    for y in range(h // 2):
        for x in range(w // 2):
            blk = [sp[2 * x + i, 2 * y + j] for i in (0, 1) for j in (0, 1)]
            solid = [c for c in blk if c[3] > 0]
            flame = [c for c in solid if c[:3] in MESALE_FLAME]
            if len(solid) < 2:
                if flame and _lum(flame[0]) > 200:  # tek parlak kıvılcım kalsın
                    op[x, y] = flame[0]
                continue
            op[x, y] = max(flame, key=_lum) if flame else max(set(solid), key=solid.count)
    return out


def dikili_mesale():
    """(gövde, 6 kare alev şeridi) - yarım boy, 5x28."""
    im = Image.open(MESALE_PATH).convert("RGBA")
    halves = [_half(im.crop((4 * 16 + 3, f * 80 + 8, 4 * 16 + 3 + 10, f * 80 + 8 + 56))) for f in range(6)]
    w, h = halves[0].size
    govde = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    alev = Image.new("RGBA", (w * 6, h), (0, 0, 0, 0))
    for f, hf in enumerate(halves):
        hp = hf.load()
        for y in range(h):
            for x in range(w):
                c = hp[x, y]
                if c[3] == 0:
                    continue
                if c[:3] in MESALE_FLAME:
                    alev.putpixel((f * w + x, y), c)
                elif f == 0:
                    govde.putpixel((x, y), c)
    return govde, alev


# 5) GECE KAMP ATEŞİ + EŞYALAR (kullanıcı 2026-11-15: "bu attığım arşivde kamp ateşi var, bununla değiştirir misin, ekrandaki kamp ateşini
#    sevmedim; çanta, kılıç falan da var, ufak tefek ayrıntı ekleyebilirsin minimal düzeyde"): Craftpix Night Camp paketi (tools/kamp_gece/
#    kaynak, KAYNAK.txt). Bonfire.png = 6 kare x 48x80; gece_kamp_atesi.png = aynısı (ortam ışığını alır), gece_kamp_atesi_alev.png = yalnız
#    alev + çevresindeki yarı saydam parıltı (r >= 170, b <= 80; taşlar daha mavimsi) -> ışık katmanının üstünde. Eşyalar Objects.png'den:
#    kılıç, yeşil sırt çantası, küçük kırmızı kese (kamp_esya_*.png). Menüde karakter pikseli ölçeğinde (x CHAR_K): paketin karakter/ateş
#    oranı ancak böyle oturuyor (x MAP_K'da alev Talon'un ~2,5 katı).
GECE_KAYNAK = os.path.join(ROOT, "tools", "kamp_gece", "kaynak")
GECE_ESYA = {"kilic": (178, 37, 188, 58), "canta": (164, 14, 179, 28), "kese": (114, 2, 125, 15)}


def gece_ates():
    src = Image.open(os.path.join(GECE_KAYNAK, "Bonfire.png")).convert("RGBA")
    alev = Image.new("RGBA", src.size, (0, 0, 0, 0))
    sp, ap = src.load(), alev.load()
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = sp[x, y]
            # Paketin gömülü YÖNLÜ gölgesi (sağ + alt, (30,36,55) a=89): menünün ışık katmanında halkanın sağında kopuk bir şerit
            # gibi görünüyordu (kullanıcı: "kamp ateşinde kesiklik var") + yönlü gölge kuralı (hafıza: no directional shadows) -> silinir.
            if (r, g, b, a) == (30, 36, 55, 89):
                sp[x, y] = (0, 0, 0, 0)
                continue
            if a > 0 and r >= 170 and b <= 80:
                ap[x, y] = (r, g, b, a)
    return src, alev


def gece_esyalar():
    im = Image.open(os.path.join(GECE_KAYNAK, "Objects.png")).convert("RGBA")
    return {ad: im.crop(box) for ad, box in GECE_ESYA.items()}


def talon_olta():
    sheet = Image.open(os.path.join(ROOT, "assets", "characters", "talon", "sheets", "idle.png")).convert("RGBA")
    strip = Image.new("RGBA", (192, 48), (0, 0, 0, 0))
    # UZAMA KARESİ YOK (kullanıcı: "idle esnasında çok gereksiz uzuyor"): idle 8/7/8/9 tepe satırıyla gövdeyi 1 px uzatıp kısaltıyor; menüde
    # x4 büyük olunca uzama belirgin -> tepe satırı kare 0'dan YUKARI çıkan kare atlanır, kalanlar gidip-gelir (0, 2, 3, 2).
    tops = [sheet.crop((f * 48, 48, f * 48 + 48, 96)).getbbox()[1] for f in range(4)]
    keep = [f for f in range(4) if tops[f] >= tops[0]]
    order = (keep + keep[-2:0:-1])[:4] if len(keep) > 2 else (keep * 4)[:4]
    for slot, f in enumerate(order):
        img = sheet.crop((f * 48, 48, f * 48 + 48, 96))
        dy = 0  # kol sabit: olta yumrukta kıpırdamasın
        px = img.load()
        for r, row in enumerate(TALON_KOL):
            y = TALON_XY[1] + r + dy
            for c, ch in enumerate(row):
                if ch != ".":
                    px[TALON_XY[0] + c, y] = TALON_PAL[ch] + (255,)
            x = TALON_XY[0] + len(row)
            while x < 30 and px[x, y][3] == 0:
                px[x, y] = TALON_PAL[TALON_FILL[r]] + (255,)
                x += 1
        strip.alpha_composite(img, (slot * 48, 0))
    return strip


# 5) talon_olta_kamis.png - Talon'un OLTASI paketten (kullanıcı 2026-11-16: "şu anki koyduğun olta AI; arşivdeki oltayı çıkarıp ipini suyun
#    içine uzanacak şekilde düzeltip Talon'un eline ver"): Craftpix Fishing Game Icons Icon37 (tools/kamp_olta/kaynak). İkonda ip
#    uçtan kamışın sağına sarkıp makaraya geri dönen bir döngü -> ipin KAMIŞA YAPIŞIK pikselleri (kılavuzlar + kamış boyunca giden ip,
#    8-komşuluğunda kamış pikseli olanlar) kalır, sarkan döngü silinir; yeni ip uçtan suya menu_camp_scene.gd FishingRod'da ikonun ip
#    renkleriyle çizilir. Talon sola (nehre) bakar -> ikon YATAY çevrilir (sap sağ altta yumrukta, uç sol üstte). Karakter pikseli ölçeği
#    (x CHAR_K), açı ikonun kendisi (piksel sanatı döndürülmez).
OLTA_PATH = os.path.join(ROOT, "tools", "kamp_olta", "kaynak", "Icon37.png")


def _olta_ip_mi(c):
    # ip pikselleri koyu lacivert/siyah (mavi >= kırmızı); kamış kahve-altın (kırmızı > mavi)
    return c[3] > 0 and c[2] >= c[0]


def paket_olta():
    im = Image.open(OLTA_PATH).convert("RGBA")
    w, h = im.size
    px = im.load()
    kamis = {(x, y) for y in range(h) for x in range(w) if px[x, y][3] > 0 and not _olta_ip_mi(px[x, y])}
    ip = {(x, y) for y in range(h) for x in range(w) if _olta_ip_mi(px[x, y])}
    k8 = [(dx, dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1) if dx or dy]
    yapisik = {p for p in ip if any((p[0] + dx, p[1] + dy) in kamis for dx, dy in k8)}
    # döngünün kamışa çapraz değen uçları tek başına benek kalır: kamışa yalnız ÇAPRAZ değen ve yanında başka yapışık ip pikseli olmayan atılır
    k4 = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    yapisik = {p for p in yapisik if any((p[0] + dx, p[1] + dy) in kamis for dx, dy in k4)
               or any((p[0] + dx, p[1] + dy) in yapisik for dx, dy in k8)}
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    po = out.load()
    for (x, y) in kamis | yapisik:
        po[w - 1 - x, y] = px[x, y]
    uc = min(kamis, key=lambda p: (p[1], p[0]))
    print("paket_olta: uc (cevrilmis) =", (w - 1 - uc[0], uc[1]))
    return out


def main():
    out = os.path.join(ROOT, "assets", "ui", "ana_menu")
    paket_olta().save(os.path.join(out, "talon_olta_kamis.png"))
    img = build()
    img.save(os.path.join(out, "hadime_uzanik.png"))
    tl = talon_olta()
    tl.save(os.path.join(out, "talon_olta.png"))
    ates, ates_alev = gece_ates()
    ates.save(os.path.join(out, "gece_kamp_atesi.png"))
    ates_alev.save(os.path.join(out, "gece_kamp_atesi_alev.png"))
    for ad, im in gece_esyalar().items():
        im.save(os.path.join(out, "kamp_esya_%s.png" % ad))
    govde, alev = dikili_mesale()
    govde.save(os.path.join(out, "mesale_govde.png"))
    alev.save(os.path.join(out, "mesale_alev.png"))
    prev = Image.new("RGBA", (288, 48), (110, 140, 80, 255))
    prev.alpha_composite(img, (0, 0))
    prev.alpha_composite(tl, (96, 0))
    prev.resize((2016, 336), Image.NEAREST).save(os.path.join(HERE, "out", "kamp_kareler_x10.png"))


if __name__ == "__main__":
    main()
