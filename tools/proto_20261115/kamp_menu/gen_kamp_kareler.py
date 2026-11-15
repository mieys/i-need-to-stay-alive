# ANA MENÜ kamp sahnesi için ELLE DÜZENLENMİŞ karakter kareleri (2026-11-15, menu_camp_scene.gd PARTY'de "res://..." klibi):
# 1) hadime_uzanik.png - Hadime YERDE OTURMUŞ, GERİYE YASLANMIŞ, BACAKLARI ÖNE UZANMIŞ tek kare.
# Kullanıcı: "hadimenin yere ayaklarını uzatıp oturma pozisyonunu (sit_right karesini) kendin düzelterek ayaklarını uzatıp yere yaslanıp
# ayaklarını uzatmış gibi göster". Oyunda böyle bir klip yok -> elle piksel kare: baş + saç = sit_right SON karesinin kendi pikselleri
# (2 px geriye, 4 px aşağı), gövde geriye eğik, sol kol arkada yere dayalı (el yerde), bacaklar cübbe altında sağa uzanır, çizmeler ucu yukarı.
# Palet Hadime'nin kendi renkleri (A-Q harfleri sheets/idle.png'den). 48x48, ayak tabanı y=39 (sit/idle ile aynı zemin).
# 2) matthew_yemek.png - Matthew sit_down SON karesi + elinde tavuk budu (kullanıcı: "matthew'in elinde yiyecek olsun"; eat_ klibindeki
#    yiyecek beyaz top gibi okunuyor ve klip ayakta). Kemiği sol yumruğunda (karede x 19-20, y 28-30), et dışarıda yatay.
#   python -I tools/proto_20261115/kamp_menu/gen_kamp_kareler.py  -> assets/ui/ana_menu/{hadime_uzanik,matthew_yemek,talon_olta}.png + out/kamp_kareler_x10.png
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


# Tavuk budu YATAY, kemiği Matthew'in sol yumruğunda (el karede x 19-20, y 28-30): et x 10-16 (kolun DIŞINDA, el hizasında), kemik
# x 17-18 satır 29 yumruğa girer (x 18'deki el dış hattının yerine; parmaklar = mevcut el pikselleri). İlk sürümde et kolun yanında
# yukarıdaydı ("yemek elinde değil kolunda duruyor").
# O dış hat, H parlak, L açık et, M et, D koyu et, W kemik, w kemik gölgesi.
BUT_PAL = {"O": (70, 30, 15), "H": (240, 180, 110), "L": (205, 120, 60), "M": (170, 85, 40), "D": (125, 55, 25), "W": (240, 235, 220), "w": (196, 186, 166)}
BUT_XY = (10, 26)
BUT = [
    "..OOO....",
    ".OHLMO...",
    "OHLMMDO..",
    "OLMMDDOWW",
    ".ODDDOww.",
    "..OOO....",
]


def matthew_yemek():
    img = Image.open(os.path.join(ROOT, "assets", "characters", "matthew", "sheets", "sit.png")).convert("RGBA").crop((144, 0, 192, 48))
    px = img.load()
    for r, row in enumerate(BUT):
        for c, ch in enumerate(row):
            if ch != ".":
                px[BUT_XY[0] + c, BUT_XY[1] + r] = BUT_PAL[ch] + (255,)
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


def main():
    out = os.path.join(ROOT, "assets", "ui", "ana_menu")
    img = build()
    img.save(os.path.join(out, "hadime_uzanik.png"))
    mt = matthew_yemek()
    mt.save(os.path.join(out, "matthew_yemek.png"))
    tl = talon_olta()
    tl.save(os.path.join(out, "talon_olta.png"))
    prev = Image.new("RGBA", (288, 48), (110, 140, 80, 255))
    prev.alpha_composite(img, (0, 0))
    prev.alpha_composite(mt, (48, 0))
    prev.alpha_composite(tl, (96, 0))
    prev.resize((2016, 336), Image.NEAREST).save(os.path.join(HERE, "out", "kamp_kareler_x10.png"))


if __name__ == "__main__":
    main()
