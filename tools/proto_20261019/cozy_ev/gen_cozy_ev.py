# COZY EV prototipi v3 (2026-10-19, oyuna bağlı DEĞİL).
# Kullanıcı: "ev içi assetleriyle cozy huzur verici bir ev tasarla; ayrı 2 yatak odası, ana odada mutfak + kanepe + şömine".
# v1 geri bildirimi: "yeterince cozy değil, her köşede bitki şart değil, oda kapıları açılıp kapanabilen normal kapılar olsun".
#   -> v2: ev küçüldü, boş zemin yerine eşya/yiyecek/mum/pencere; boncuk perde yerine KÜTÜK KAPI; sıcak akşam ışığı önizlemesi.
# v2 geri bildirimi: "ışıklar piksel piksel olmasın" -> YUMUŞAK ışık; "bazı eşyalar kesik (alttaki halı, orta alttaki masa),
#   mutfak mutfak gibi durmuyor - kazanla ilgili bir asset vardı, mutfağı büyüt, ışığını iyileştir"
#   -> v3: kesik eşya bloğu düzeltildi + üretici artık her eşyada KESİK DENETİMİ yapar (sprite blok kenarında sayfada devam
#      ediyorsa uyarı); mutfak KANADI (evin solunda kendi arka duvarı: erzak rafı + animasyonlu KAZAN OCAĞI + tezgah + pencere +
#      asılı et/sarımsak, ortada iş tezgahı, kilerde fıçı/çuval/sandık) + sol yatak odasının önünde yemek köşesi (tabak rafı,
#      şişe rafı, mumlu yemek masası); kazan ateşi titreyen ışık kaynağı.
#   Yeni sayfalar oyunun kendi "Harita içerikleri" paketlerinden harita/Ev içi/'ne kopyalanır: eski ev/Boiler.png -> Kazan_ocak
#   (12 kare animasyon; yeşil iksir kırmızımsı-turuncu ÇORBAYA boyanır, corba_rengi), yeni başlangıç evi/Interior_objects.png -> Avci_esyalari, cafe/Interior_1st_floor.png -> Taverna_esyalari.
# Sadece oyunun KENDİ tilesetleri; Tiled'da düzenlenebilir harita/cozy_ev.tmx. Katman adları house_interior.gd kuralıyla uyumlu.
# TUZAK 1: aynı Tiled katmanında üst üste binen iki eşya birbirinin karolarını SİLER -> "ressam sırası" katman dağıtımı (allocate).
# TUZAK 2: paket sayfalarında eşyalar 16'lık ızgaraya oturmaz; sprite blok kenarında kesilirse oyunda yarım görünür (v2'de paspas,
#   oval masa, sehpa bacakları, yatak ucu...) -> check_cuts() her yerleştirilen eşyayı sayfadaki komşu piksellerle denetler.
# KÜTÜK KAPI: Walls_floor.png'deki kapı (karo 22,23/50,51/78,79) paketin kendi taş kapı animasyonunun açılma düzeniyle türetilir;
#   açık karelerde aralıktan odanın tahta zemini görünür (lento gölgesiyle üstte loş).
# Çıktı: harita/cozy_ev.tmx, harita/Ev içi/{Kutuk_kapi,Kazan_ocak,Avci_esyalari,Taverna_esyalari}.png + .tsx,
#        out/cozy_ev.png (düz, x3), out/cozy_ev_aksam.png (gece ışığı, x3), out/cozy_ev_gunduz.png (gündüz ışığı, x3),
#        out/cozy_ev_karsilastirma.png (düz/gündüz/gece alt alta), --gif ile out/cozy_ev.webp (gece) + out/cozy_ev_gunduz.webp (gündüz)
#   python tools/proto_20261019/cozy_ev/gen_cozy_ev.py [--gif]
import math
import os
import random
import shutil
import sys
import xml.etree.ElementTree as ET

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
HARITA = os.path.join(ROOT, "harita")
EV = os.path.join(HARITA, "Ev içi")
PAKET = os.path.abspath(os.path.join(ROOT, "..", "Harita içerikleri"))   # oyunun dış asset klasörü (proje dışında)
OUT = os.path.join(HERE, "out")
TMX_OUT = os.path.join(HARITA, "cozy_ev.tmx")
DOOR_PNG = os.path.join(EV, "Kutuk_kapi.png")
DOOR_TSX = os.path.join(EV, "Kutuk_kapi.tsx")

# tileset: (firstgid, tsx yolu (harita/'ya göre), sütun sayısı) - ilk 7'si ev içi.tmx ile birebir
TS = {
    "IWF": (1, "Ev içi/Interior_walls_floor.tsx", 10),
    "HI": (181, "Ev içi/House_interior.tsx", 17),
    "IN": (334, "Ev içi/Interior.tsx", 14),
    "WF": (712, "Ev içi/Walls_floor.tsx", 28),
    "CA": (852, "Ev içi/Candles.tsx", 12),
    "IO": (900, "Ev içi/Interior_objects.tsx", 40),
    "FP": (1260, "Ev içi/Fireplace.tsx", 6),
    "KK": (1266, "Ev içi/Kutuk_kapi.tsx", 8),          # 4 kare x (2x3 karo) = 24
    "KZ": (1290, "Ev içi/Kazan_ocak.tsx", 24),         # 12 kare x (2x3 karo) = 72
    "AV": (1362, "Ev içi/Avci_esyalari.tsx", 21),      # 21x19 = 399
    "TV": (1761, "Ev içi/Taverna_esyalari.tsx", 21),   # 21x22 = 462
    "PN": (2223, "Ev içi/Pencere.tsx", 2),              # kütük pencere: kare 0 gece (Walls_floor 49), kare 1 gündüz (parlak cam)
    "YM": (2225, "Ev içi/Yatak_mavi.tsx", 2),           # mavi tek kişilik yatak, kırmızı yatağın derinliğine oturtulmuş (2x4 = 8)
    "KM": (2233, "Ev içi/Kitap_masa.tsx", 2),           # salon sehpasında açık kitap, masanın üst yüzüne kaydırılmış (2x2 = 4, make_book_sheet)
}
# dış paketten kopyalanan sayfalar: anahtar -> (kaynak, hedef png adı, kare animasyonu (genişlik karo, kare sayısı, ms) ya da None,
# boyama işlevi ya da None)
def corba_rengi(img):
    """Kazandaki YEŞİL iksiri kırmızımsı-turuncu çorbaya çevirir (kullanıcı: "normal bir çorba rengi, kırmızımsı turuncumsu").
    Sayfadaki 15 yeşil ton (renk tonu 75..124 derece) ışık sırası korunarak eşlenir: açık sarımsı yeşil kabarcık -> turuncu
    (~28 derece), koyu yeşil dip -> kırmızı (~5 derece); doygunluk x1,25, parlaklık x1,12. Ateş/kor/taş renklerine dokunmaz."""
    import colorsys
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, sat, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            hd = h * 360
            if 70 <= hd <= 130 and sat > 0.15:
                t = min(max((hd - 75) / 49.0, 0.0), 1.0)
                nh = (28 - 23 * t) / 360
                nr, ng, nb = colorsys.hsv_to_rgb(nh, min(sat * 1.25, 0.85), min(v * 1.12, 1.0))
                px[x, y] = (int(nr * 255 + 0.5), int(ng * 255 + 0.5), int(nb * 255 + 0.5), a)
    return img


IMPORTS = {
    "KZ": (os.path.join(PAKET, "eski ev", "Tiled_files", "Boiler.png"), "Kazan_ocak.png", (2, 12, 100), corba_rengi),
    "AV": (os.path.join(PAKET, "yeni başlangıç evi", "PNG", "Interior_objects.png"), "Avci_esyalari.png", None, None),
    "TV": (os.path.join(PAKET, "cafe", "Tiled_files", "Interior_1st_floor.png"), "Taverna_esyalari.png", None, None),
}
FH, FV, FD = 0x80000000, 0x40000000, 0x20000000
W, H = 40, 21
DOOR_FRAMES = 4


# ---------------------------------------------------------------- dış paket sayfalarını içeri al
def import_sheets():
    for key, (src, dst, anim, paint) in IMPORTS.items():
        dpath = os.path.join(EV, dst)
        want = Image.open(src).convert("RGBA")
        if paint:
            want = paint(want)
        have = Image.open(dpath).convert("RGBA") if os.path.exists(dpath) else None
        if have is None or have.size != want.size or have.tobytes() != want.tobytes():
            if paint:
                want.save(dpath)
            else:
                shutil.copyfile(src, dpath)
        img = Image.open(dpath)
        cols, rows = img.width // 16, img.height // 16
        assert cols == TS[key][2], (key, cols)
        lines = ['<?xml version="1.0" encoding="UTF-8"?>',
                 f'<tileset version="1.10" tiledversion="1.12.2" name="{dst[:-4]}" tilewidth="16" tileheight="16" '
                 f'tilecount="{cols * rows}" columns="{cols}">',
                 f' <image source="{dst}" width="{img.width}" height="{img.height}"/>']
        if anim:   # her karenin sol üst bloğundaki karolar, sonraki karelere (genişlik kadar sağa) döner
            fw, nfr, ms = anim
            for r in range(rows):
                for i in range(fw):
                    base = r * cols + i
                    lines.append(f' <tile id="{base}">')
                    lines.append('  <animation>')
                    for k in range(nfr):
                        lines.append(f'   <frame tileid="{base + k * fw}" duration="{ms}"/>')
                    lines.append('  </animation>')
                    lines.append(' </tile>')
        lines.append('</tileset>')
        with open(os.path.join(EV, dst[:-4] + ".tsx"), "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lines) + "\n")


# ---------------------------------------------------------------- kütük kapı kareleri
# Pencere camı: Walls_floor karo 49'un camı gece renginde (koyu mor-mavi) çizilmiş; kullanıcı: "pencereden ışık geliyor ama pencere
# hiç aydınlık görünmüyor" -> gündüz karesinde cam tonları açık gök mavisine / beyaza yakın parlamaya eşlenir, gündüz render'ında
# cam pikselleri IŞIKSIZ (kendi parlaklığında) çizilir. Oyunda gün-gece kareyi değiştirir (karo 0 <-> 1).
CAM_GUNDUZ = {(101, 88, 128): (156, 196, 222), (112, 103, 155): (196, 224, 238), (113, 123, 192): (240, 249, 253)}
WIN_PNG = os.path.join(EV, "Pencere.png")
_cam_maske = None


def make_window_sheet():
    global _cam_maske
    gece = Image.open(os.path.join(EV, "Walls_floor.png")).convert("RGBA").crop((21 * 16, 16, 22 * 16, 32))
    gunduz = gece.copy()
    px = gunduz.load()
    maske = np.zeros((16, 16), bool)
    for y in range(16):
        for x in range(16):
            c = px[x, y]
            if c[:3] in CAM_GUNDUZ:
                px[x, y] = CAM_GUNDUZ[c[:3]] + (c[3],)
                maske[y, x] = True
    _cam_maske = maske
    sheet = Image.new("RGBA", (32, 16))
    sheet.paste(gece, (0, 0))
    sheet.paste(gunduz, (16, 0))
    sheet.save(WIN_PNG)
    with open(os.path.join(EV, "Pencere.tsx"), "w", encoding="utf-8", newline="\n") as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n'
                '<tileset version="1.10" tiledversion="1.12.2" name="Pencere" tilewidth="16" tileheight="16" tilecount="2" columns="2">\n'
                ' <image source="Pencere.png" width="32" height="16"/>\n'
                '</tileset>\n')


# Mavi tek kişilik yatak (Interior 4,1 2x3; sprite y 0..39) kırmızı yataktan (Interior_objects 23,0 2x4; sprite y 11..50) 5 px önde
# duruyordu (16'lık ızgarada kaydırılamaz) - kullanıcı: "mavi yatak biraz önde, kırmızı yatak gibi olmalı" -> pikselleri aynı,
# 2x4 karoluk sayfada 11 px aşağıdan başlar: kırmızıyla aynı satıra konunca ikisinin başı/ayak ucu aynı hizada.
def make_bed_sheet():
    src = Image.open(os.path.join(HARITA, "Ev", "Tiled_files", "Interior.png")).convert("RGBA").crop((4 * 16, 16, 6 * 16, 64))
    sheet = Image.new("RGBA", (32, 64))
    sheet.alpha_composite(src, (0, 11))
    sheet.save(os.path.join(EV, "Yatak_mavi.png"))
    with open(os.path.join(EV, "Yatak_mavi.tsx"), "w", encoding="utf-8", newline="\n") as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n'
                '<tileset version="1.10" tiledversion="1.12.2" name="Yatak_mavi" tilewidth="16" tileheight="16" tilecount="8" columns="2">\n'
                ' <image source="Yatak_mavi.png" width="32" height="64"/>\n'
                '</tileset>\n')


## Salon sehpasındaki açık kitap (IO 22,7): eskiden sehpa bloğunun sol üst karosunda masanın kenarından taşıyordu (kullanıcı 2026-10-19:
## "masanın üstündeki kitap yere düşecek gibi duruyor"). Karo ızgarası piksel kaydırmaya izin vermediği için kitap 2x2'lik kendi sayfasına,
## blok sol üstüne göre BOOK_OFFSET'e çizilir: masanın üst yüzünün sol yarısı, masa sanatındaki kupanın altı.
BOOK_OFFSET = (12, 13)


def make_book_sheet():
    book = _tile_img("IO", 7 * TS["IO"][2] + 22)
    art = book.crop(book.getbbox())
    sheet = Image.new("RGBA", (32, 32))
    sheet.alpha_composite(art, BOOK_OFFSET)
    sheet.save(os.path.join(EV, "Kitap_masa.png"))
    with open(os.path.join(EV, "Kitap_masa.tsx"), "w", encoding="utf-8", newline="\n") as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n'
                '<tileset version="1.10" tiledversion="1.12.2" name="Kitap_masa" tilewidth="16" tileheight="16" tilecount="4" columns="2">\n'
                ' <image source="Kitap_masa.png" width="32" height="32"/>\n'
                '</tileset>\n')


def make_door_sheet():
    wf = Image.open(os.path.join(EV, "Walls_floor.png")).convert("RGBA")
    closed = wf.crop((352, 0, 384, 48))                      # 2x3 karo: kütük + kapı
    # açıklıktan görünen yatak odası zemini: odadaki dikey tahta karoları (Interior_walls_floor 44 | 45), 32x48'e döşenir.
    # v3'te açıklık koyu dolguydu (WF29) - kullanıcı: "kapılar açılınca içerisi görünmek yerine koyu görünüyor".
    iwf = Image.open(os.path.join(EV, "Interior_walls_floor.png")).convert("RGBA")
    floor = Image.new("RGBA", (32, 48))
    for ty in range(3):
        floor.paste(iwf.crop((64, 64, 80, 80)), (0, ty * 16))
        floor.paste(iwf.crop((80, 64, 96, 80)), (16, ty * 16))
    LX0, LX1, LY0, LY1 = 9, 24, 15, 40                       # kanat (menteşe LX0 tarafında)
    sheet = Image.new("RGBA", (32 * DOOR_FRAMES, 48))
    widths = [15, 10, 6, 3]
    for k, wdt in enumerate(widths):
        fr = closed.copy()
        if k:
            px = fr.load()
            for y in range(LY0, LY1):
                # lentonun gölgesi: üstte loş (0,58), aşağı indikçe odanın kendi aydınlığına (0,95) yumuşakça açılır
                t = 0.58 + 0.37 * min(1.0, (y - LY0) / 14.0) ** 0.8
                for x in range(LX0, LX1):
                    fc = floor.getpixel((x, y))
                    px[x, y] = (int(fc[0] * t), int(fc[1] * t), int(fc[2] * t), 255)
            leaf = closed.crop((LX0, LY0, LX1, LY1)).resize((wdt, LY1 - LY0), Image.NEAREST)
            shade = (0.86, 0.74, 0.62)[k - 1]                # içe döndükçe ışıktan uzaklaşır
            lp = leaf.load()
            for y in range(leaf.height):
                for x in range(leaf.width):
                    r, g, b, a = lp[x, y]
                    lp[x, y] = (int(r * shade), int(g * shade), int(b * shade), a)
                lp[wdt - 1, y] = (67, 35, 30, 255)          # kanadın serbest kenarı (kalınlık çizgisi)
            fr.alpha_composite(leaf, (LX0, LY0))
        sheet.alpha_composite(fr, (32 * k, 0))
    # kare k'nın 2x3 bloğu: sayfada sütun 2k..2k+1 -> karo kimliği = satır*8 + 2k + i
    sheet.save(DOOR_PNG)
    with open(DOOR_TSX, "w", encoding="utf-8", newline="\n") as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n'
                f'<tileset version="1.10" tiledversion="1.12.2" name="Kutuk_kapi" tilewidth="16" tileheight="16" '
                f'tilecount="{DOOR_FRAMES * 6}" columns="{DOOR_FRAMES * 2}">\n'
                f' <image source="Kutuk_kapi.png" width="{32 * DOOR_FRAMES}" height="48"/>\n'
                '</tileset>\n')


# ---------------------------------------------------------------- tileset okuma
_sheets = {}


def _sheet(key):
    if key not in _sheets:
        p = os.path.join(HARITA, TS[key][1])
        txt = open(p, encoding="utf-8").read()
        t = ET.fromstring(txt[:txt.rfind("</tileset>") + len("</tileset>")])  # Interior*.tsx sonunda fazladan ">" var
        img = t.find("image")
        anims = {}
        for tile in t.findall("tile"):
            a = tile.find("animation")
            if a is not None:
                anims[int(tile.get("id"))] = [(int(f.get("tileid")), int(f.get("duration"))) for f in a.findall("frame")]
        _sheets[key] = dict(img=Image.open(os.path.normpath(os.path.join(os.path.dirname(p), img.get("source")))).convert("RGBA"),
                            tw=int(t.get("tilewidth")), th=int(t.get("tileheight")), cols=int(t.get("columns")), anims=anims)
    return _sheets[key]


def _tile_img(key, local):
    s = _sheet(key)
    c, r = local % s["cols"], local // s["cols"]
    return s["img"].crop((c * s["tw"], r * s["th"], (c + 1) * s["tw"], (r + 1) * s["th"]))


def _key_of(g):
    gg = g & 0x0FFFFFFF
    return [k for k in sorted(TS, key=lambda k: TS[k][0]) if TS[k][0] <= gg][-1]


def _empty(g):
    k = _key_of(g)
    return _tile_img(k, (g & 0x0FFFFFFF) - TS[k][0]).getbbox() is None


# ---------------------------------------------------------------- eşya kataloğu (tileset, sütun, satır, en, boy[, atlanacak hücreler])
B = {
    # Interior.tsx (14 sütun)
    "yatak_mavi": ("YM", 0, 0, 2, 4),                               # kırmızı yatak hizasında (make_bed_sheet)
    "komodin": ("IN", 8, 1, 2, 2),
    "fici": ("IN", 10, 1, 2, 2),
    "dolap_kucuk": ("IN", 12, 1, 1, 2),
    "fici2": ("IN", 10, 3, 1, 2),
    "sandik": ("IN", 11, 3, 1, 2),
    "erzak_rafi": ("IN", 1, 6, 4, 4),
    "kitaplik": ("IN", 11, 6, 2, 3),
    "kanepe": ("IN", 1, 10, 2, 3),                                   # mavi koltuk, SOLA bakar (flip = sağa)
    "yemek_masasi": ("IN", 8, 9, 5, 4, ((0, 3), (4, 3))),          # 4 sandalye + vazo + testi (komşu sandalye/sarımsak atılır)
    "oval_masa": ("IN", 1, 13, 3, 3),                               # v2'de 2 satırdı: bacaklar kesikti
    "sarimsak": ("IN", 11, 12, 2, 4, ((0, 0),)),                    # v2'de 1x3: tepesi + sol dişleri kesikti; (0,0) masa setinin ucu
    "cuval": ("IN", 8, 23, 1, 1),
    "elma": ("IN", 8, 24, 1, 1),
    "hali_mavi_oval": ("IN", 1, 16, 7, 6, ((0, 0), (6, 0), (0, 5), (6, 5))),
    "hali_kirmizi_oval": ("IN", 8, 16, 5, 5),
    # House_interior.tsx (17 sütun)
    "yatak_cift": ("HI", 6, 0, 3, 4),                               # v2'de satır 1'den: başlığın tepesi kesikti
    "yuvarlak_sehpa": ("HI", 6, 4, 3, 3),
    "tezgah_lahana": ("HI", 3, 7, 3, 2),
    "tezgah": ("HI", 6, 7, 3, 2),
    "kitap": ("HI", 13, 7, 1, 2),                                   # v2'de 1 satır: alt yarısı kesikti
    "ekmek": ("HI", 14, 7, 1, 1),
    "tencere": ("HI", 15, 7, 1, 1),
    "tabaklar": ("HI", 15, 8, 1, 1),
    # Interior_objects.tsx (40 sütun)
    "iksir_rafi": ("IO", 0, 0, 6, 4),                               # v2'de 4 sütun: iki yandaki yapraklar kesikti
    "lamba": ("IO", 5, 4, 3, 3),
    "hali_kirmizi": ("IO", 8, 4, 5, 3),
    "gardirop": ("IO", 16, 4, 2, 3),
    "yatak_kirmizi": ("IO", 23, 0, 2, 4),                           # v2'de 3 satır: ayak ucu kesikti
    "hali_kucuk": ("IO", 25, 0, 3, 4),                              # v2'de 3 satır: alt kenarı kesikti (paspas)
    "saksi_cicek": ("IO", 7, 7, 1, 2),
    "fener": ("IO", 30, 6, 2, 2),
    "kitap_acik": ("IO", 22, 7, 1, 1),
    "kitap_masa": ("KM", 0, 0, 2, 2),                               # salon sehpasının üstünde (make_book_sheet)
    # Candles.tsx: animasyonlu mum (0,1,12,13 karoları 3 kare döner)
    "mum": ("CA", 0, 0, 2, 2),
    # Kazan_ocak (eski ev/Boiler.png): taş ocakta fokurdayan kazan, 12 kare
    "kazan_ocak": ("KZ", 0, 0, 2, 3),
    # Avci_esyalari (yeni başlangıç evi/Interior_objects.png, 21 sütun)
    "tabak_rafi": ("AV", 16, 0, 2, 4),                              # tabak, ekmek, şişe, ot
    "et_buyuk": ("AV", 15, 12, 2, 3),                               # duvarda asılı but
    "et_ikili": ("AV", 13, 12, 2, 2),                               # iki küçük asılı et
    "balik": ("AV", 3, 17, 1, 2),
    "kase": ("AV", 19, 4, 1, 1),
    "ekmek_sepet": ("AV", 20, 4, 1, 1),
    "sise": ("AV", 18, 4, 1, 1),
    "testi": ("AV", 18, 12, 1, 1),
    "sandik_cuval": ("AV", 8, 9, 3, 3),
    "cuval_ikili": ("AV", 3, 13, 2, 2),
    "ayi_postu": ("AV", 0, 0, 5, 5),
    "kucuk_masa": ("AV", 11, 0, 4, 4),                              # testi + tabak + 4 tabure
    # Taverna_esyalari (cafe/Interior_1st_floor.png, 21 sütun)
    "sise_rafi": ("TV", 9, 0, 4, 4),
    "sarap_fici": ("TV", 4, 6, 2, 3),
}
# check_cuts için bilerek kabul edilen kenar temasları (komşu AYRI eşya, sprite değil): ad -> kenarlar
CUT_OK = {
    "fici2": "R", "sandik": "L", "yemek_masasi": "A", "hali_mavi_oval": "A", "sarimsak": "UL", "cuval_ikili": "U",
    "sise_rafi": "R", "kucuk_masa": "R",
}

# ışık kaynakları: eşya adı -> (sprite içi dx, dy, yarıçap, renk, şiddet, basıklık, titreme evresi|None)
WARM = (1.0, 0.68, 0.38)
EMIT = {
    "mum": (12, 14, 46, WARM, 0.85, 0.85, None),
    "fener": (16, 13, 60, WARM, 0.95, 0.85, None),
    "lamba": (22, 16, 74, (1.0, 0.72, 0.42), 0.95, 0.85, None),
    "kazan_ocak": (16, 36, 140, (1.0, 0.56, 0.28), 1.3, 0.78, 2.1),   # ocak ateşi: titrer (şömineden farklı evre)
}

STACKS = {   # tür -> sırayla denenen katmanlar (çizim sırası = ORDER)
    "rug": ["Eşya alt"],
    "wall": ["Duvar süsü", "Duvar süsü 2"],
    "furn": ["ekstra", "ekstra 2", "ekstra 3", "ekstra 4"],
    "top": ["Eşya üst", "Eşya üst 2"],
}
FIXED = ["zemin", "Duvar yüzü", "Duvarlar", "Oda kapıları", "Kapı"]
ORDER = ["zemin", "Eşya alt", "Duvar yüzü", "Duvarlar", "Oda kapıları", "Kapı", "Duvar süsü", "Duvar süsü 2",
         "ekstra", "ekstra 2", "ekstra 3", "ekstra 4", "Eşya üst", "Eşya üst 2"]


def check_cuts(names):
    """Sprite blok kenarına değiyor VE sayfada hemen dışında da dolu piksel varsa (kesik) uyarı; CUT_OK hariç."""
    bad = []
    for name in sorted(names):
        ts, c, r, w, h = B[name][:5]
        img = _sheet(ts)["img"]
        px = img.load()
        iw, ih = img.size
        x0, y0, x1, y1 = c * 16, r * 16, (c + w) * 16, (r + h) * 16

        def op(x, y):
            return 0 <= x < iw and 0 <= y < ih and px[x, y][3] > 0
        e = ""
        if any(op(x, y0 - 1) and op(x, y0) for x in range(x0, x1)):
            e += "U"
        if any(op(x, y1) and op(x, y1 - 1) for x in range(x0, x1)):
            e += "A"
        if any(op(x0 - 1, y) and op(x0, y) for y in range(y0, y1)):
            e += "L"
        if any(op(x1, y) and op(x1 - 1, y) for y in range(y0, y1)):
            e += "R"
        e = "".join(ch for ch in e if ch not in CUT_OK.get(name, ""))
        if e:
            bad.append((name, e))
    for name, e in bad:
        print(f"UYARI kesik olabilir: {name} kenar {e}")
    return bad


class House:
    def __init__(self):
        self.L = {n: [[0] * W for _ in range(H)] for n in ORDER}
        self.objs = []      # (tür, hücreler [(x,y,gid)], kapsam, taban_px, sıra)
        self.lights = []    # (x, y, yarıçap, renk, şiddet, basıklık, titreme evresi|None)
        self.emissive = set()   # (x, y, gid): ışıksız çizilecek karolar
        self.doors = []     # (x, y) kapı bloklarının sol üst hücresi
        self.used = set()

    def set(self, layer, x, y, g):
        if 0 <= x < W and 0 <= y < H:
            self.L[layer][y][x] = g

    def wf(self, layer, x, y, local):
        self.set(layer, x, y, TS["WF"][0] + local)

    def obj(self, name, x, y, kind="furn", flip=False):
        ts, c, r, w, h = B[name][:5]
        skip = B[name][5] if len(B[name]) > 5 else ()
        cols = TS[ts][2]
        cells = []
        for j in range(h):
            for i in range(w):
                if (i, j) in skip:
                    continue
                si = (w - 1 - i) if flip else i
                g = TS[ts][0] + (r + j) * cols + c + si
                if _empty(g):
                    continue
                cells.append((x + i, y + j, g | (FH if flip else 0)))
        blk = _sheet(ts)["img"].crop((c * 16, r * 16, (c + w) * 16, (r + h) * 16))
        bottom = y * 16 + blk.getbbox()[3]
        self.objs.append((kind, cells, {(cx, cy) for cx, cy, _ in cells}, bottom, len(self.objs)))
        self.used.add(name)
        if name in EMIT:
            dx, dy, rad, col, inten, sq, ph = EMIT[name]
            self.lights.append((x * 16 + dx, y * 16 + dy, rad, col, inten, sq, ph, "kaynak"))
            self.emissive |= {(cx, cy, g) for cx, cy, g in cells}

    def big(self, ts, local, x, y, wcells, hcells, kind="furn", bottom_px=None):
        """48x64 gibi büyük karo: TEK hücreye yazılır (sol alt), kapladığı hücreler çakışma için sayılır."""
        g = TS[ts][0] + local
        cover = {(x + i, y - j) for i in range(wcells) for j in range(hcells)}
        self.objs.append((kind, [(x, y, g)], cover, bottom_px or (y + 1) * 16, len(self.objs)))
        self.emissive.add((x, y, g))

    def stamp_ev_ici(self, layer_src, x0, y0, w, h, x, y, kind="rug"):
        """ev içi.tmx'teki hazır bir karo öbeğini (döndürülmüş kırmızı oval halı) olduğu gibi kopyala."""
        r = ET.parse(os.path.join(HARITA, "ev içi.tmx")).getroot()
        sw = int(r.get("width"))
        for lay in r.findall("layer"):
            if lay.get("name") != layer_src:
                continue
            vals = [int(v) for v in lay.find("data").text.replace("\n", "").split(",")]
            cells = [(x + i, y + j, vals[(y0 + j) * sw + x0 + i]) for j in range(h) for i in range(w) if vals[(y0 + j) * sw + x0 + i]]
            self.objs.append((kind, cells, {(cx, cy) for cx, cy, _ in cells}, (y + h) * 16, len(self.objs)))

    def door(self, x, y):
        """Kütük kapı (2x3, kare 0 = kapalı) ön duvara; 'Oda kapıları' katmanı (oyunda açılıp kapanacak olan)."""
        for j in range(3):
            for i in range(2):
                self.set("Oda kapıları", x + i, y + j, TS["KK"][0] + j * TS["KK"][2] + i)
        self.doors.append((x, y))

    def window(self, x, y):
        self.set("Duvar süsü", x, y, TS["PN"][0])   # kare 0 (gece); gündüz kare 1
        # pencere ışığı: gece soğuk ay ışığı, gündüz ılık gün ışığı (renk/boy IŞIK_KIPLERI'nden), aşağı yayılır
        self.lights.append((x * 16 + 8, y * 16 + 22, 34, (0.55, 0.66, 0.95), 0.45, 1.6, None, "pencere"))

    def allocate(self):
        for kind, stack in STACKS.items():
            placed = []   # (kapsam, katman indeksi)
            for _, cells, cover, bottom, _ in sorted((o for o in self.objs if o[0] == kind), key=lambda o: (o[3], o[4])):
                li = 0
                for pc, pli in placed:
                    if pc & cover:
                        li = max(li, pli + 1)
                if li >= len(stack):
                    raise SystemExit(f"{kind}: katman yetmedi {sorted(cover)[:3]}")
                for cx, cy, g in cells:
                    self.set(stack[li], cx, cy, g)
                placed.append((cover, li))


# ---------------------------------------------------------------- yerleşim (yorumlarda sprite piksel aralıkları: x a..b)
TOP = 2               # çatı kirişi
FACE = (3, 4, 5)      # kuzey duvar yüzü (y 48..96)
FRONT = (11, 12, 13)  # yatak odası ön duvarları (y 176..224)
BOTTOM = 20           # alt duvar kirişi (alt oda y 224..320)
K = 11                # mutfak kanadı genişliği: v2 yerleşimi 11 sütun sağa kaydı
KITCHEN_PART = 11     # mutfak / sol yatak odası bölme direği WF28 (x 184..192) + ön duvarın köşe kütük uçları WF56
LEFT_PART = 20        # sol yatak odası bölme direği WF30 (x 320..328) + köşe kütük uçları WF58
RIGHT_PART = 30       # sağ yatak odası bölme direği WF28 (x 488..496) + köşe kütük uçları WF56
ENTRY = (24, 25, 26)  # giriş: x 384..432, ortası 408 = şömine ekseni
LEFT_DOOR = 17        # sol yatak odası kapısı sütun 17-18 (kanat x 281..296)
ALT_PENCERE = (112, 296, 462, 552)   # alt duvardan ışık giren yerlerin x'i: mutfak, ayı postu yanı, girişin sağı, okuma köşesi
RIGHT_DOOR = 31       # sağ yatak odası kapısı sütun 31-32 (kanat x 505..520), köşe kütüklerinin hemen yanında: okuma köşesine yer


def build():
    m = House()
    rnd = random.Random(7)
    # --- zemin: dikey tahta şeritleri (ev içi.tmx gibi sütun sütun, ara ara değişen)
    for x in range(1, W - 1):
        base = rnd.choice((44, 45, 46))
        for y in range(FACE[0], BOTTOM + 1):
            if rnd.random() < 0.12:
                base = rnd.choice((44, 45, 46))
            m.set("zemin", x, y, TS["IWF"][0] + base)
    # --- çatı kirişi + kuzey duvar yüzü
    m.wf("Duvarlar", 0, TOP, 0)
    for x in range(1, W - 1):
        m.wf("Duvarlar", x, TOP, 1)
    m.wf("Duvarlar", W - 1, TOP, 2)
    for x in range(1, W - 1):
        v = 1 if x % 7 == 3 else 0   # arada bir ikinci kütük deseni (ev içi.tmx 18/19)
        for k, y in enumerate(FACE):
            m.wf("Duvar yüzü", x, y, (18, 46, 74)[k] + v)
    # --- dış yan duvarlar
    for y in range(TOP + 1, BOTTOM):
        m.wf("Duvarlar", 0, y, 28)
        m.wf("Duvarlar", W - 1, y, 30)
    # --- alt duvar + ortada 3 karoluk giriş
    m.wf("Duvarlar", 0, BOTTOM, 65)
    for x in range(1, W - 1):
        if x in ENTRY:
            m.wf("Kapı", x, BOTTOM, 121)
        elif x == ENTRY[0] - 1 or x == W - 2:
            m.wf("Duvarlar", x, BOTTOM, 120)
        elif x == ENTRY[-1] + 1:
            m.wf("Duvarlar", x, BOTTOM, 122)
        else:
            m.wf("Duvarlar", x, BOTTOM, 117 if x % 3 == 0 else 119)
    m.wf("Duvarlar", W - 1, BOTTOM, 30)
    # --- bölme direkleri (duvar yüzünden ön duvara kadar)
    for y in range(FACE[0], FRONT[0]):
        m.wf("Duvarlar", KITCHEN_PART, y, 28)
        m.wf("Duvarlar", LEFT_PART, y, 30)
        m.wf("Duvarlar", RIGHT_PART, y, 28)
    # --- ön duvarlar (kütük) + kütük kapılar; mutfak kanadının önü AÇIK
    for k, y in enumerate(FRONT):
        m.wf("Duvarlar", KITCHEN_PART, y, (56, 84, 112)[k])
        for x in range(KITCHEN_PART + 1, LEFT_PART):
            if x not in (LEFT_DOOR, LEFT_DOOR + 1):
                m.wf("Duvarlar", x, y, (57, 85, 113)[k])
        m.wf("Duvarlar", LEFT_PART, y, (58, 86, 114)[k])
        m.wf("Duvarlar", RIGHT_PART, y, (56, 84, 112)[k])
        for x in range(RIGHT_PART + 1, W - 1):
            if x not in (RIGHT_DOOR, RIGHT_DOOR + 1):
                m.wf("Duvarlar", x, y, (57, 85, 113)[k])
        m.wf("Duvarlar", W - 1, y, (30, 38, 30)[k])
    m.door(LEFT_DOOR, FRONT[0])
    m.door(RIGHT_DOOR, FRONT[0])

    # ================= MUTFAK KANADI (x 16..184): arka duvarda erzak rafı + KAZAN OCAĞI + tezgah + pencere + asılı et/sarımsak
    m.obj("erzak_rafi", 1, 3)                     # x 22..73, sebze/sarımsak/ekmek/çuval
    m.obj("kazan_ocak", 5, 5)                     # x 80..111, taş ocakta fokurdayan kazan (ateşi ışık kaynağı); y 80..128 - bir karo
    # aşağıda (kullanıcı 2026-10-19: "duvarın üstüne çıkmış"), önündeki 8. satır boş: babaanne kazanın ÖNÜNDE yukarı dönük karıştırır
    # (babaanne_npc.gd STIR_FEET); kazanın sağı (x 112..130) da boş, asılı sarımsak dizisi kalktı (erzak rafında zaten sarımsak var)
    m.obj("tezgah_lahana", 8, 5)                  # x 130..174, lahana/ekmek/bıçak
    m.window(9, 4)                                # tezgahın üstünde pencere
    m.obj("et_buyuk", 10, 3, kind="wall")         # x 162..182, duvarda asılı but
    m.obj("tabaklar", 10, 5, kind="top")
    m.obj("mum", 8, 4, kind="top")                # tezgahta mum
    # orta: iş tezgahı (ekmek, tencere, testi, mum)
    m.obj("tezgah", 4, 9)                         # x 66..110
    m.obj("ekmek", 4, 9, kind="top")
    m.obj("tencere", 5, 9, kind="top")
    m.obj("testi", 6, 9, kind="top")
    m.obj("mum", 5, 8, kind="top")
    # alt: mavi halıda mumlu yemek masası + yanında ayaklı lamba (mutfağın alt yarısının ışığı)
    m.obj("hali_mavi_oval", 2, 13, kind="rug")    # x 46..133
    m.obj("yemek_masasi", 3, 14)                  # x 50..120
    m.obj("mum", 5, 14, kind="top")
    m.obj("ekmek_sepet", 4, 15, kind="top")
    m.obj("lamba", 8, 12)                         # x 140..167
    # kiler: sol duvar boyunca şarap fıçısı + fıçı (köşelerdeki sandık/çuval/tek fıçı kalktı - kullanıcı: "gereksiz kutular")
    m.obj("sarap_fici", 1, 8)                     # x 18..47
    m.obj("fici", 1, 11)

    # ================= İÇKİ KÖŞESİ (sol yatak odasının önü, x 192..320): tabak + şişe rafı, önünde ayı postu
    # (v3'teki testili küçük masa kalktı - kullanıcı: "gereksiz, solda zaten yemek masası var")
    m.obj("tabak_rafi", 12, 11)                   # x 195..224
    m.obj("sise_rafi", 14, 11)                    # x 230..276
    m.obj("ayi_postu", 12, 14, kind="rug")        # x 195..272

    # ================= SOL YATAK ODASI (x 192..320): yatak başında pencere, iki komodin + mum, ayak ucunda halı ve sandık
    m.window(4 + K, 4)
    m.obj("komodin", 1 + K, 5)
    m.obj("yatak_cift", 3 + K, 4)                 # blok artık satır 0'dan: bir satır yukarıdan yerleşir
    m.obj("komodin", 6 + K, 5)
    m.obj("mum", 1 + K, 4, kind="top")
    m.obj("mum", 6 + K, 4, kind="top")
    m.obj("gardirop", 7 + K, 4)
    m.obj("hali_kucuk", 3 + K, 7, kind="rug")

    # ================= SAĞ YATAK ODASI (x 496..624): iki tek kişilik yatak, ortada komodin + mum, başlarında pencere
    m.window(21 + K, 4)
    m.window(26 + K, 4)
    m.obj("yatak_mavi", 21 + K, 4)                # kırmızı yatakla aynı satır: sprite y 75..114
    m.obj("komodin", 23 + K, 5)
    m.obj("mum", 23 + K, 4, kind="top")
    m.obj("yatak_kirmizi", 25 + K, 4)
    m.obj("hali_kirmizi", 22 + K, 7, kind="rug")

    # ================= OCAK BAŞI (x 328..488, eksen 408): şömine, iki fener, pencere, kitaplık, karşılıklı koltuklar, sehpa, lamba
    m.big("FP", 0, 13 + K, 6, 3, 4, bottom_px=7 * 16)   # 48x64 animasyonlu şömine
    m.lights.append((232 + K * 16, 96, 178, (1.0, 0.64, 0.34), 1.3, 0.72, 0.0, "kaynak"))   # alev (titrer)
    m.window(18 + K, 4)
    m.obj("fener", 11 + K, 3, kind="wall")
    m.obj("fener", 16 + K, 3, kind="wall")
    m.obj("kitaplik", 10 + K, 4)
    m.stamp_ev_ici("Eşya alt", 13, 8, 5, 6, 12 + K, 8)   # kırmızı oval halı (ev içi.tmx'teki döndürülmüş hâli)
    m.obj("kanepe", 11 + K, 9, flip=True)         # sağa (ateşe/sehpaya) bakar
    m.obj("kanepe", 16 + K, 9)                    # sola bakar
    m.obj("yuvarlak_sehpa", 13 + K, 9)            # v2'nin sehpası bacakları kesik olduğu için yuvarlak sehpa
    m.obj("kitap_masa", 13 + K, 9, kind="top")         # masanın üst yüzünde, kupanın sol altında (eskiden kenardan taşıyordu)
    m.obj("tencere", 14 + K, 9, kind="top")       # kupa
    m.obj("lamba", 17 + K, 7)

    # ================= GİRİŞ: sadece paspas (mumlu çiçekli masa + sol yatak odası kapısının yanındaki fener kalktı -
    # kullanıcı: "girişteki masayı kaldır", fener "yere düşmüş gibi duruyor")
    m.obj("hali_kucuk", 13 + K, 17, kind="rug")

    # ================= OKUMA KÖŞESİ (sağ alt, x 528..624): iki kitaplık, halıda koltuk + kitaplı/kupalı yuvarlak sehpa,
    # lamba KOLTUĞUN HEMEN ÜSTÜNDE (kullanıcı: "ışık koltuğun yanında, üst tarafta"); v3'ün iksir rafı + altındaki kasalar kalktı
    m.obj("kitaplik", 33, 12)                     # x 531..557
    m.obj("kitaplik", 35, 12)                     # x 563..589
    m.obj("lamba", 36, 12)                        # x 588..615: kütük duvarın önünde, tabanı koltuğun tepesinde
    m.obj("hali_kirmizi_oval", 34, 15, kind="rug")   # x 558..610
    m.obj("yuvarlak_sehpa", 35, 15)               # x 568..600
    m.obj("kitap", 36, 15, kind="top")
    m.obj("kanepe", 37, 15)                       # x 603..621, sola (sehpaya) bakar
    # alt duvardaki görünmeyen pencereler (kullanıcı: "alt tarafta da pencere varmış da oradan ışık geliyormuş gibi olsun bazı
    # yerlerde"): sadece gündüz, alt duvardan yukarı ışık lekesi; giriş kapısının (x 384..432) önüne denk gelmez
    for ax in ALT_PENCERE:
        m.lights.append((ax, BOTTOM * 16 + 8, 0, (0, 0, 0), 0, 1.0, None, "alt_pencere"))
    m.allocate()
    check_cuts(m.used)
    return m


# ---------------------------------------------------------------- TMX yazımı
def used_layers(m):
    return [n for n in ORDER if n in FIXED or any(any(row) for row in m.L[n])]


def write_tmx(m, path):
    names = used_layers(m)
    lines = ['<?xml version="1.0" encoding="UTF-8"?>',
             f'<map version="1.10" tiledversion="1.12.2" orientation="orthogonal" renderorder="right-down" width="{W}" height="{H}" '
             f'tilewidth="16" tileheight="16" infinite="0" nextlayerid="{len(names) + 1}" nextobjectid="1">']
    for key in sorted(TS, key=lambda k: TS[k][0]):
        lines.append(f' <tileset firstgid="{TS[key][0]}" source="{TS[key][1]}"/>')
    for i, name in enumerate(names):
        lines.append(f' <layer id="{i + 1}" name="{name}" width="{W}" height="{H}">')
        lines.append('  <data encoding="csv">')
        lines.append(",\n".join(",".join(str(v) for v in row) for row in m.L[name]))
        lines.append('</data>')
        lines.append(' </layer>')
    lines.append('</map>')
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


# ---------------------------------------------------------------- çizim
# Işık kipleri. "gece" = v3 akşam önizlemesi. "gunduz" (kullanıcı: "gündüz ışıklandırma gece ışıklandırmasına benzesin,
# içerideki ışıklar hissedilsin, ikisinin karışımı gibi; gece gibi hissettirmesin ama ışıklar da etkisiz olmasın"):
# ortam açık ve nötr ama düz render'dan biraz loş (iç mekân), sıcak kaynaklar kısık ama belirgin.
# Gündüz pencere ışığı (kullanıcı: "gündüz pencereden biraz ışık gelir gibi olsun, stardew valleydeki gibi"): pencereden düz öne,
# iki yana eşit genişleyen yumuşak YELPAZE (önce sağa eğik şeritti: "doğal durmuyor").
IŞIK_KIPLERI = {
    "gece": dict(ortam=(0.42, 0.37, 0.48), kaynak=1.0, pencere=None, huzme=None, parilti=None, alt_huzme=None,
                 tavan=(1.35, 1.3, 1.3)),
    "gunduz": dict(ortam=(0.72, 0.68, 0.66), kaynak=0.6, pencere=None,
                   huzme=dict(renk=(1.0, 0.94, 0.78), siddet=0.6, bas=74, boy=100, en=18, genisleme=0.95),
                   parilti=((1.0, 0.95, 0.85), 20, 0.45, -14),   # camın çevresinde küçük ılık aydınlık (renk, yarıçap, şiddet, dy)
                   # alt duvardaki (görünmeyen) pencerelerden giren ışık: alt duvardan yukarı uzanan, biraz daha geniş/kısa leke
                   alt_huzme=dict(renk=(1.0, 0.94, 0.78), siddet=0.42, boy=92, en=44, genisleme=0.8),   # geniş başlar: görünmeyen pencere
                   tavan=(1.32, 1.26, 1.18)),
}


def _huzme(acc, xx, yy, cx, h, bas=None, yon=1):
    """Pencere ışığı YELPAZESİ: başlangıç kenarı y = bas (yoksa h['bas'], pencerenin alt yarısı), yon=1 aşağı (kuzey duvar
    pencereleri), yon=-1 yukarı (alt duvar pencereleri); pencerenin ortasından DÜZ öne, iki yana eşit genişleyen (en +
    genisleme x mesafe), yanlara doğru yumuşak (1-r^2)^1.5, boyunca (1-t)^1.4 sönen ve ilk 6 px'te yavaşça açılan ışık.
    Geçmiş: sağa eğik dar şerit ("düz bir çizgi hâlinde bir yöne doğru değil, eşit şekilde öne doğru geniş, soft bir ışık yaysın")
    -> bu yumuşak yelpaze -> içi dolu + 3 px kenarlı yelpaze denendi ("önceki gibi ışık saçsın") -> kullanıcı yumuşak yelpazeyi
    SEÇTİ: "ışıklandırma olarak bunu seçiyorum, en doğalı bu oldu"."""
    dy = (yy - (h["bas"] if bas is None else bas)) * yon
    t = dy / h["boy"]
    on = (t >= 0) & (t <= 1)
    yari = (h["en"] + np.clip(dy, 0, None) * h["genisleme"]) / 2
    r = np.abs(xx - cx) / yari
    yanca = np.clip(1 - r * r, 0, 1) ** 1.5
    boyca = np.clip(1 - t, 0, 1) ** 1.4 * np.clip(dy / 6.0, 0, 1)
    k = np.where(on, yanca * boyca * h["siddet"], 0).astype(np.float32)
    acc += k[..., None] * np.array(h["renk"], np.float32)


def light_map(m, t_ms, kip="gece"):
    """YUMUŞAK ışık haritası: her kaynak sürekli azalan bir hale (oyunda PointLight2D + yumuşak gradyan dokusu karşılığı).
    v2'nin ilk hâli ana menü lit_pass'i gibi Bayer titreşimli 7 basamaktı - kullanıcı: "ışıkların piksel piksel olmasını
    istemiyorum" -> basamak ve titreşim YOK."""
    hh, ww = H * 16, W * 16
    yy, xx = np.mgrid[0:hh, 0:ww].astype(np.float32)
    acc = np.zeros((hh, ww, 3), np.float32)
    ayar = IŞIK_KIPLERI[kip]
    acc[:] = ayar["ortam"]
    for (cx, cy, rad, col, inten, sq, ph, tur) in m.lights:
        if tur == "alt_pencere":
            if ayar["alt_huzme"]:
                _huzme(acc, xx, yy, cx, ayar["alt_huzme"], bas=cy, yon=-1)
            continue
        if tur == "pencere" and ayar["huzme"]:
            _huzme(acc, xx, yy, cx, ayar["huzme"])
            if not ayar["parilti"]:
                continue
            col, rad, inten, dy = ayar["parilti"]
            cy, sq = cy + dy, 1.0
        if tur == "pencere" and ayar["pencere"]:
            col, rad, inten, sq = ayar["pencere"]
        elif tur == "kaynak":
            inten = inten * ayar["kaynak"]
        if ph is not None:   # ateş: yavaş + hızlı iki dalga, yarıçap ve şiddet birlikte
            f = 0.06 * math.sin(t_ms / 260.0 + ph) + 0.04 * math.sin(t_ms / 97.0 + 1.3 + ph * 1.7)
            rad, inten = rad * (1 + f), inten * (1 + 1.4 * f)
        d = np.clip(np.sqrt((xx - cx) ** 2 + ((yy - cy) / sq) ** 2) / rad, 0, 1)
        k = (1.0 - d) ** 2.2 * inten            # sürekli, kenara doğru hızlı sönen hale (ışık havuzu + karanlık karşıtlığı)
        acc += k[..., None] * np.array(col, np.float32)
    return np.minimum(acc, np.array(ayar["tavan"], np.float32))


def render(m, t_ms=0, lit=False, door_frame=0):
    """lit: False (Tiled'daki düz görünüş) ya da IŞIK_KIPLERI anahtarı ("gece" / "gunduz")."""
    hh, ww = H * 16, W * 16
    canvas = np.zeros((hh, ww, 3), np.float32)
    canvas[:] = (16, 12, 14)
    lm = light_map(m, t_ms, lit) if lit else None
    door_cells = {(dx + i, dy + j) for dx, dy in m.doors for i in range(2) for j in range(3)}
    for name in used_layers(m):
        for y in range(H):
            for x in range(W):
                g = m.L[name][y][x]
                if not g:
                    continue
                key = _key_of(g)
                s = _sheet(key)
                local = (g & 0x0FFFFFFF) - TS[key][0]
                if key == "KK" and (x, y) in door_cells:
                    local += door_frame * 2
                if key == "PN" and lit == "gunduz":
                    local = 1
                if local in s["anims"]:
                    fr = s["anims"][local]
                    tt = t_ms % sum(d for _, d in fr)
                    for tid, d in fr:
                        if tt < d:
                            local = tid
                            break
                        tt -= d
                tile = _tile_img(key, local)
                if g & FD:
                    tile = tile.transpose(Image.TRANSPOSE)
                if g & FH:
                    tile = tile.transpose(Image.FLIP_LEFT_RIGHT)
                if g & FV:
                    tile = tile.transpose(Image.FLIP_TOP_BOTTOM)
                ox, oy = x * 16, y * 16 + 16 - tile.height
                a = np.asarray(tile, np.float32)
                y0, x0 = max(oy, 0), ox
                a = a[y0 - oy:, :, :]
                th, tw = a.shape[0], a.shape[1]
                rgb, al = a[..., :3], a[..., 3:4] / 255.0
                if lit and (x, y, g) not in m.emissive:
                    lit_rgb = rgb * lm[y0:y0 + th, x0:x0 + tw]
                    if key == "PN" and lit == "gunduz":   # gündüz camı kendi parlaklığında, çerçeve ışıkla
                        rgb = np.where(_cam_maske[..., None], rgb, lit_rgb)
                    else:
                        rgb = lit_rgb
                dst = canvas[y0:y0 + th, x0:x0 + tw]
                canvas[y0:y0 + th, x0:x0 + tw] = rgb * al + dst * (1 - al)
    img = Image.fromarray(np.clip(canvas, 0, 255).astype(np.uint8), "RGB")
    return img.crop((0, TOP * 16, W * 16, H * 16))


def karsilastirma():
    """Aynı bölge (mutfak + sol yatak odası + ocak başı) düz / gündüz / gece alt alta: out/cozy_ev_karsilastirma.png."""
    from PIL import ImageDraw, ImageFont
    try:
        font = ImageFont.truetype("arial.ttf", 13)   # varsayılan PIL yazısında ü/ğ yok
    except OSError:
        font = ImageFont.load_default()
    rows = []
    for fn, lab in (("cozy_ev.png", "Düz (Tiled)"), ("cozy_ev_gunduz.png", "Gündüz"), ("cozy_ev_aksam.png", "Gece")):
        im = Image.open(os.path.join(OUT, fn)).crop((0, 0, 1500, 600)).resize((750, 300), Image.NEAREST)
        d = ImageDraw.Draw(im)
        d.rectangle([0, 0, 96, 19], fill=(20, 16, 18))
        d.text((6, 2), lab, fill=(255, 230, 180), font=font)
        rows.append(im)
    out = Image.new("RGB", (750, 3 * 304 - 4), (20, 16, 18))
    for i, im in enumerate(rows):
        out.paste(im, (0, i * 304))
    out.save(os.path.join(OUT, "cozy_ev_karsilastirma.png"))


def main():
    os.makedirs(OUT, exist_ok=True)
    import_sheets()
    make_door_sheet()
    make_window_sheet()
    make_bed_sheet()
    make_book_sheet()
    m = build()
    write_tmx(m, TMX_OUT)
    sc = 3
    for lit, fn in ((False, "cozy_ev.png"), ("gece", "cozy_ev_aksam.png"), ("gunduz", "cozy_ev_gunduz.png")):
        im = render(m, 0, lit=lit)
        im.resize((im.width * sc, im.height * sc), Image.NEAREST).save(os.path.join(OUT, fn))
    karsilastirma()
    if "--gif" in sys.argv:
        # 60 x 100 ms = 6 sn: şömine (6x120=720), mum (3x300=900), kazan (12x100=1200) tam döngü;
        # kapılar 0-7 kapalı, 8-11 açılır, 12-41 açık, 42-45 kapanır
        seq = [0] * 8 + [1, 2, 3, 3] + [3] * 30 + [2, 1, 0, 0] + [0] * 14
        # yumuşak ışık GIF'in 256 rengine sığmaz (ortak palet bantlıyor, kare başı palet 14 MB) -> yalnız tam renkli WebP
        for kip, fn in (("gece", "cozy_ev.webp"), ("gunduz", "cozy_ev_gunduz.webp")):
            frames = []
            for i, dfr in enumerate(seq):
                f = render(m, i * 100, lit=kip, door_frame=dfr)
                frames.append(f.resize((f.width * 2, f.height * 2), Image.NEAREST))
            frames[0].save(os.path.join(OUT, fn), save_all=True, append_images=frames[1:], duration=100, loop=0,
                           lossless=False, quality=92, method=4)
    print("katmanlar:", used_layers(m))
    print("yazildi:", TMX_OUT)


if __name__ == "__main__":
    main()
