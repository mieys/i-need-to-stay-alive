# ANA MENÜ sade arka plan PROTOTİPLERİ (2026-10-16, oyuna bağlı DEĞİL).
# Kullanıcı: "arka planı hiç beğenmedim, direk haritanın bir parçası yerine yeni bir sade arka plan oluşturulsun; yapay zeka içermesin,
# oyunun içindeki asset'lerle hazırla". -> Her sahne oyunun KENDİ tileset sprite'larından (harita/...) elle dizilir:
#   A Tek Ağaç (gece çayırı)  B Kütük Kulübe (pencere ışığı)  C Ocak Başı (iç mekan, şömine)  D Orman Kıyısı (ağaç şeridi)
# Kurallar (Ruh Mağazası arka planı dersi, madde 173): ışık SADECE görünür kaynaktan (pencere / alev / mum), havuz tam kaynağın pikselinde;
# kodla çizilmiş desen/gradyan/parıltı yok (sadece basamaklı gece tonu + kenar karartma + nesne altı gölge elipsi);
# eşyalar arayüzün açık bıraktığı yerde: ana menü A yerleşiminde sol panel x < 150 (tuval px) -> sahne x 160..480.
# Karakterler BURADA çizilmez: Godot prototipi (menu_proto.gd) gerçek sprite'ları PARTY konumlarına koyar (oyunda canlı oynayabilir).
# Çıktı: tools/proto_20261016/out/menu/bg/bg_{a,b,c,d}.png (480x270, oyunda x4 en yakın komşu) + bg_ozet.png
#   python tools/proto_20261016/gen_ana_menu_bg.py          (prototipler)
#   python tools/proto_20261016/gen_ana_menu_bg.py --oyun   (seçilen C: assets/ui/ana_menu/ocak_basi.png + ocak_ates.png)
import os
import random
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from gen_menu_bg import sprites  # noqa: E402  (aynı bağlantılı-bileşen kesici)

HARITA = os.path.join(ROOT, "harita")
EV = os.path.join(HARITA, "Ev içi")
OUT = os.path.join(HERE, "out", "menu", "bg")
W, H = 480, 270
BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
GRASS = (122, 173, 85)  # oyundaki düz çim karosunun rengi (gen_menu_bg.py ile aynı)


def sheet(path):
    return Image.open(path).convert("RGBA")


def lit_pass(base, lights, ambient, vig=0.35):
    """Basamaklı (Bayer titreşimli) ışık haritası: renk = taban * (ortam + ışıklar), kenarlar basamaklı kararır."""
    px = base.load()
    out = Image.new("RGBA", base.size)
    po = out.load()
    for y in range(H):
        for x in range(W):
            r, g, bb, a = px[x, y]
            if a == 0:
                continue
            b = (BAYER[(y & 3) * 4 + (x & 3)] + 0.5) / 16.0 - 0.5
            lr, lg, lb = ambient
            for (cx, cy, rad, col, inten, squash) in lights:
                dx = x - cx
                dy = (y - cy) / squash
                d = (dx * dx + dy * dy) ** 0.5 / rad
                if d < 1.0:
                    k = (1.0 - d) ** 1.7 * inten
                    k = max(0.0, min(1.0, int(k * 7 + b + 0.5) / 7.0))
                    lr += col[0] * k
                    lg += col[1] * k
                    lb += col[2] * k
            vx = (x / W - 0.5) * 2
            vy = (y / H - 0.5) * 2
            v = max(0.0, vx * vx * 0.35 + vy * vy * 0.45 - 0.2)
            v = int(v * 5 + b + 0.5) / 5.0 * vig
            m = 1.0 - v
            po[x, y] = (min(255, int(r * min(lr, 1.35) * m)), min(255, int(g * min(lg, 1.3) * m)),
                        min(255, int(bb * min(lb, 1.3) * m)), a)
    return out


def shadow(img, cx, cy, rx, ry, k=0.62):
    """Nesne altı gölge elipsi: 2 basamak (iç koyu, dış dama), yönsüz."""
    px = img.load()
    for y in range(int(cy - ry), int(cy + ry) + 1):
        for x in range(int(cx - rx), int(cx + rx) + 1):
            if not (0 <= x < W and 0 <= y < H):
                continue
            d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            if d > 1.0:
                continue
            kk = k if d < 0.55 else (k + 0.18 if (x + y) % 2 == 0 else 1.0)
            r, g, b, a = px[x, y]
            px[x, y] = (int(r * kk), int(g * kk), int(b * kk), a)


class Scene:
    def __init__(self, ground):
        self.img = Image.new("RGBA", (W, H), ground + (255,))
        self.items = []  # (taban_y, sprite, x, y)

    def add(self, spr, foot_x, foot_y, shade=None):
        """Sprite'ı TABAN ORTASINDAN yerleştir; y-sıralı çizilir. shade = (rx, ry) gölge elipsi."""
        x = round(foot_x - spr.width / 2)
        y = round(foot_y - spr.height)
        self.items.append((foot_y, spr, x, y, shade, foot_x))

    def flatten(self):
        for foot_y, spr, x, y, sh, fx in sorted(self.items, key=lambda it: it[0]):
            if sh:
                shadow(self.img, fx, foot_y - 1, sh[0], sh[1])
            self.img.alpha_composite(spr, (x, y))
        self.items = []
        return self.img


def load_kit():
    obj = sprites(os.path.join(HARITA, "Objects.png"), gap=1, min_px=20)
    ext = sprites(os.path.join(HARITA, "Exterior_objects.png"), gap=1, min_px=20)
    sade = sprites(os.path.join(HARITA, "köy insalar", "Tiled_files", "sade ağaç ve taş.png"), gap=1, min_px=20)
    flowers = sprites(os.path.join(HARITA, "köy insalar", "Tiled_files", "Flowers.png"))
    plants = sprites(os.path.join(HARITA, "Çiftlik ve ev", "Tiled_files", "Plants.png"), box=(0, 120, 512, 240))
    tufts = [s for s in plants if s.width <= 14 and s.height <= 14]
    tiny_fl = [s for s in flowers if s.width <= 14 and s.height <= 14]
    return obj, ext, sade, tiny_fl, tufts


def scatter(sc, rnd, pool, n, x0, x1, y0, y1, avoid=()):
    k = 0
    tries = 0
    while k < n and tries < 2000:
        tries += 1
        x, y = rnd.uniform(x0, x1), rnd.uniform(y0, y1)
        if any(ax0 <= x <= ax1 and ay0 <= y <= ay1 for ax0, ay0, ax1, ay1 in avoid):
            continue
        sc.add(rnd.choice(pool), x, y)
        k += 1


def grass_scene(rnd, tufts, k=1.0):
    g = tuple(int(c * k) for c in GRASS)
    sc = Scene(g)
    # seyrek ot tutamları tüm çayıra (zemin dokusu; çok az)
    scatter(sc, rnd, tufts, 16, 150, W, 8, H + 6)
    return sc


def bg_a(kit):
    """Tek Ağaç: gece çayırında tek büyük ağaç + devrik kütük + birkaç mantar/çiçek. Işık kaynağı yok -> sadece ay ışığı tonu."""
    obj, ext, sade, fl, tufts = kit
    rnd = random.Random(1610)
    sc = grass_scene(rnd, tufts)
    sc.add(obj[1], 286, 124, (24, 5))          # arkada çam
    sc.add(obj[4], 334, 156, (30, 7))          # büyük ağaç (koru)
    sc.add(obj[13], 398, 134, (22, 5))         # sağ arkada küçük ağaç
    sc.add(obj[7], 262, 158, (16, 4))          # önde çalı
    sc.add(obj[8], 420, 162, (12, 3))
    sc.add(obj[28], 388, 204, (38, 5))         # devrik kütük (oturulan)
    sc.add(obj[30], 236, 196, (12, 3))         # kesik kütük
    sc.add(obj[64], 300, 170)                  # kırmızı mantar
    sc.add(obj[71], 366, 168)                  # kahve mantar
    sc.add(obj[54], 452, 228, (9, 3))          # küçük taş
    scatter(sc, rnd, fl, 9, 200, 470, 150, 250, avoid=[(250, 180, 430, 235)])
    img = sc.flatten()
    return lit_pass(img, [], ambient=(0.50, 0.56, 0.74))


def window_lights(img, ox, oy):
    """Kulübe sprite'ındaki mavi cam piksellerini sıcak 'yanan pencere'ye çevirir; her pencerenin merkezini döndürür."""
    px = img.load()
    pts = []
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a and b > r + 40 and b > 110:
                v = (r + g + b) / 3
                px[x, y] = (255, 214, 120, a) if v > 120 else (236, 164, 72, a)
                pts.append((x, y))
    # basit kümeleme: 6 px yakınlık
    clusters = []
    for p in pts:
        for c in clusters:
            if abs(c[0] / c[2] - p[0]) < 7 and abs(c[1] / c[2] - p[1]) < 7:
                c[0] += p[0]
                c[1] += p[1]
                c[2] += 1
                break
        else:
            clusters.append([p[0], p[1], 1])
    return [(ox + c[0] / c[2], oy + c[1] / c[2]) for c in clusters if c[2] >= 3]


def bg_b(kit):
    """Kütük Kulübe: kulübe sağda, pencereleri yanıyor (ışık havuzu tam camda); sandık, odun, balta saplı kütük, iki ağaç."""
    obj, ext, sade, fl, tufts = kit
    rnd = random.Random(1611)
    sc = grass_scene(rnd, tufts, 0.96)
    cabin = ext[2].copy()
    foot_x, foot_y = 372, 178
    cx0 = round(foot_x - cabin.width / 2)
    cy0 = round(foot_y - cabin.height)
    wins = window_lights(cabin, cx0, cy0)
    sc.add(cabin, foot_x, foot_y, (70, 6))
    sc.add(obj[0], 262, 156, (26, 6))          # solda ağaç
    sc.add(obj[12], 474, 118, (22, 5))         # sağ kenarda ağaç (yarım)
    sc.add(ext[21], 300, 184, (11, 3))         # sandık
    sc.add(ext[22], 288, 190, (10, 3))
    sc.add(ext[20], 452, 186, (11, 3))         # odun/saman demeti
    sc.add(ext[24], 214, 214, (11, 3))         # kütük
    scatter(sc, rnd, fl, 8, 200, 470, 196, 255, avoid=[(280, 196, 440, 240)])
    img = sc.flatten()
    warm = (1.0, 0.70, 0.40)
    lights = [(x, y + 6, 46, warm, 0.95, 0.9) for x, y in wins]
    return lit_pass(img, lights, ambient=(0.42, 0.46, 0.64)), wins


def bg_c(kit, with_fire=True):
    """Ocak Başı: ahşap kirişli mavi sıva duvar + tahta zemin, ortada yanan şömine (ışık TAM alevde), önünde kırmızı oval halı,
    yanda kitaplık + silah rafı + sarkan otlar, sağda ayaklı lamba (ikinci ışık, lamba başında), saksı. Parti halıda ateşe dönük oturur."""
    wf = sheet(os.path.join(EV, "Interior_walls_floor.png"))
    inter = sheet(os.path.join(EV, "Interior.png"))
    iobj = sheet(os.path.join(EV, "Interior_objects.png"))
    fire = sheet(os.path.join(EV, "Fireplace.png"))
    WALL_Y = 6
    WALL_H = 120
    base_y = WALL_Y + WALL_H
    scene = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    floor = wf.crop((80, 16, 96, 32))
    for y in range(base_y - 8, H, 16):
        for x in range(0, W, 16):
            scene.alpha_composite(floor, (x, y))
    beam = wf.crop((0, 80, 64, 96))            # ahşap kiriş şeridi
    plaster = wf.crop((0, 96, 64, 120))        # mavi sıva (süpürgeliksiz)
    skirt = wf.crop((0, 120, 64, 128))         # süpürgelik
    plaster_flat = wf.crop((0, 100, 64, 120))  # gölge çizgisiz sıva (tekrar için)
    for x in range(0, W, 64):
        scene.alpha_composite(beam, (x, WALL_Y))
        scene.alpha_composite(plaster, (x, WALL_Y + 16))      # kirişin hemen altı (gölge çizgisiyle)
        for k in range(4):                                     # sonrası düz sıva: gölge çizgisi tekrarlanmasın
            scene.alpha_composite(plaster_flat, (x, WALL_Y + 40 + k * 20))
        scene.alpha_composite(skirt, (x, WALL_Y + WALL_H - 8))
    for y in range(WALL_Y):
        for x in range(W):
            scene.putpixel((x, y), (38, 26, 24, 255) if y < WALL_Y - 1 else (60, 40, 30, 255))
    for y in range(base_y, base_y + 4):        # duvar dibi gölgesi (2 basamak)
        for x in range(W):
            r, g, b, a = scene.getpixel((x, y))
            k = 0.6 if y < base_y + 2 else (0.78 if (x + y) % 2 else 0.9)
            scene.putpixel((x, y), (int(r * k), int(g * k), int(b * k), 255))
    props = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    def put(src, rect, x, y):
        props.alpha_composite(src.crop(rect), (x, y))

    FIRE_X, FIRE_Y = 300, base_y - 56                                 # şömine sol üstü (48x64 kare), tabanı zemine 8 px taşar
    FLAME = (FIRE_X + 24, FIRE_Y + 46)                                # alevin pikseli
    rug = inter.crop((12, 280, 102, 359))                             # yuvarlak mavi halı (şöminenin önü; parti üstünde oturur)
    rp = rug.load()                                                   # köşelerdeki komşu karo parçalarını at: sadece elips içi
    for yy in range(rug.height):
        for xx in range(rug.width):
            if ((xx + 0.5 - rug.width / 2) / (rug.width / 2)) ** 2 + ((yy + 0.5 - rug.height / 2) / (rug.height / 2)) ** 2 > 1.0:
                rp[xx, yy] = (0, 0, 0, 0)
    props.alpha_composite(rug, (FLAME[0] - rug.width // 2, base_y + 10))
    put(inter, (146, 136, 180, 168), 244, base_y - 26)                # kılıçlı silah rafı (şöminenin solu)
    put(inter, (163, 81, 189, 125), 368, base_y - 42)                 # kitaplık (şöminenin sağı)
    put(inter, (6, 85, 57, 140), 400, base_y - 50)                    # erzak rafı
    put(inter, (157, 2, 173, 26), 458, base_y - 20)                   # fıçı
    put(inter, (83, 202, 105, 233), 206, WALL_Y)                      # tavandan sarkan kuru ot
    put(inter, (173, 188, 187, 228), 432, WALL_Y)                     # sarkan sarımsak dizisi
    put(inter, (8, 375, 24, 392), 222, base_y + 64)                   # saksı (lambanın yanında)
    put(inter, (21, 146, 60, 201), 418, base_y + 44)                          # yemek masası + sandalyeler (sağ alt)
    # Şovalye'nin sandalyesi (kullanıcı: "sandalyeye oturmuş halde durmalı, havada görünüyor"): yan görünüş, arkalık sağda (sola, ateşe bakar).
    # Şovalye ayak ortası main_menu.gd PARTY (374, 164); sit_left son karesinin dolu alanı x 21..36 -> sprite tuvalde floor(374 - 28.5) = 345'te,
    # sandalye sol kenarı 345 + 28 = 373, bacakları ayakla aynı zeminde (alt satır 163).
    put(inter, (61, 159, 72, 184), 373, 164 - 25)
    LAMP_X, LAMP_Y = 192, base_y + 40                                 # ayaklı lamba sol üstü (Interior_objects 27x43)
    LAMP_HEAD = (LAMP_X + 10, LAMP_Y + 11)
    lights = [(FLAME[0], FLAME[1], 190, (1.0, 0.66, 0.36), 1.15, 0.72),
              (LAMP_HEAD[0], LAMP_HEAD[1], 70, (1.0, 0.72, 0.42), 0.9, 0.85)]
    amb = (0.30, 0.27, 0.36)
    lit = lit_pass(scene, lights, ambient=amb)
    lit.alpha_composite(lit_pass(props, lights, ambient=amb))
    if with_fire:  # oyunda ateş CANLI oynar (main_menu.gd): arka plana basılmaz, 6 kare ayrı dosyada
        lit.alpha_composite(fire.crop((96, 0, 144, 64)), (FIRE_X, FIRE_Y))  # şömine kendi alevli karesi (ışıksız)
    lit.alpha_composite(iobj.crop((92, 69, 119, 112)), (LAMP_X, LAMP_Y))
    return lit


def bg_d(kit):
    """Orman Kıyısı: üstte üst üste binen ağaç şeridi (orman duvarı), altta açık çayır, kenarda kaya + mantar; yol yok."""
    obj, ext, sade, fl, tufts = kit
    rnd = random.Random(1613)
    sc = grass_scene(rnd, tufts, 0.94)
    trees = [obj[i] for i in (0, 1, 2, 4, 5, 11, 12, 13, 15, 17)] + [sade[i] for i in (0, 2, 3, 4, 5)]
    x = 150
    row = 0
    while x < W + 30:
        t = rnd.choice(trees)
        foot = rnd.uniform(70, 104) if row % 2 == 0 else rnd.uniform(52, 80)
        sc.add(t, x, foot, (t.width * 0.4, 4))
        x += rnd.uniform(24, 36)
        row += 1
    for x2 in (176, 300, 420):                 # şeridin önünde seyrek çalı
        sc.add(rnd.choice([obj[6], obj[7], obj[8], sade[7], sade[12]]), x2 + rnd.uniform(-10, 10), rnd.uniform(112, 124), (10, 3))
    sc.add(obj[36], 452, 200, (22, 5))         # sağda kaya sütunu
    sc.add(obj[65], 438, 210)                  # dibinde mantar
    sc.add(obj[72], 244, 132)
    scatter(sc, rnd, fl, 12, 170, 470, 130, 255, avoid=[(230, 180, 400, 230)])
    img = sc.flatten()
    return lit_pass(img, [], ambient=(0.56, 0.50, 0.70))


GAME_OUT = os.path.join(ROOT, "assets", "ui", "ana_menu")


def export_game(kit):
    """Kullanıcı C'yi (Ocak Başı) seçti (2026-10-16): oyunun kullandığı dosyalar. main_menu.gd ateşi FIRE_POS'ta (tuval px) 6 kareyle oynatır."""
    os.makedirs(GAME_OUT, exist_ok=True)
    bg_c(kit, with_fire=False).convert("RGB").save(os.path.join(GAME_OUT, "ocak_basi.png"))
    sheet(os.path.join(EV, "Fireplace.png")).save(os.path.join(GAME_OUT, "ocak_ates.png"))  # 288x64 = 6 kare x 48x64
    # Sol menü D "Panelsiz Ateş Işığı" (kullanıcı seçti): sol taraf basamaklı karartma (okunurluk; ışık değil) + zikzak kiriş süsü ayracı.
    shade = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sp = shade.load()
    for y in range(H):
        for x in range(W):
            b = (BAYER[(y & 3) * 4 + (x & 3)] + 0.5) / 16.0 - 0.5
            t = max(0.0, min(1.0, 1.0 - x / 250.0))
            a = max(0.0, min(0.92, int(t * 1.05 * 6.0 + b + 0.5) / 6.0))
            sp[x, y] = (15, 10, 8, int(a * 255))
    shade.save(os.path.join(GAME_OUT, "sol_golge.png"))  # 480x270, oyunda sahneyle birlikte x4
    trim = sheet(os.path.join(EV, "Interior_walls_floor.png")).crop((0, 80, 64, 96))  # oda duvarının kiriş şeridi
    tp = trim.load()
    for y in range(trim.height):
        for x in range(trim.width):
            r, g, bb, a = tp[x, y]
            tp[x, y] = (int(r * 0.55), int(g * 0.55), int(bb * 0.55), a)
    trim.resize((trim.width * 3, trim.height * 3), Image.NEAREST).save(os.path.join(GAME_OUT, "kiris_suslu.png"))  # 192x48, yatay döşenir
    print("oyun:", GAME_OUT)


def main():
    os.makedirs(OUT, exist_ok=True)
    if "--oyun" in sys.argv:
        export_game(load_kit())
        return
    kit = load_kit()
    a = bg_a(kit)
    b, wins = bg_b(kit)
    c = bg_c(kit)
    d = bg_d(kit)
    print("pencereler:", [(round(x), round(y)) for x, y in wins])
    imgs = {"a": a, "b": b, "c": c, "d": d}
    for k, im in imgs.items():
        im.convert("RGB").save(os.path.join(OUT, "bg_%s.png" % k))
    sheet_img = Image.new("RGB", (W * 4 + 12, H * 4 + 12), (12, 12, 14))
    for i, k in enumerate("abcd"):
        sheet_img.paste(imgs[k].convert("RGB").resize((W * 2, H * 2), Image.NEAREST), ((i % 2) * (W * 2 + 12), (i // 2) * (H * 2 + 12)))
    sheet_img.save(os.path.join(OUT, "bg_ozet.png"))
    print("ok", OUT)


if __name__ == "__main__":
    main()
