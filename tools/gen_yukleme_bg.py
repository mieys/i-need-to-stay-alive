# YÜKLEME EKRANI arka planı "Eve Dönüş" (2026-10-17). Kullanıcı: "yükleme ekranının arkaplanı için daha iyi bir sahne hazırla".
# Eski arka plan = menü arka planı (menu_bg.png) + düz gece örtüsü; hikâyesi yoktu. Yeni sahne kovalamacaya (loading_screen.gd: doluluk
# çubuğu = yol, kahraman çubuğun ucunda koşar, Kademe yaratıkları peşinde) bir YER verir: karanlık ormandan çıkan toprak yol, yolun
# sonunda pencereleri yanan kütük kulübe - bar dolunca kahraman kapının önüne varır.
# Kurallar (madde 173/187 dersleri): SADECE oyunun kendi tileset sanatı (harita/...); ışık sadece görünür kaynaktan (kulübe camları),
# havuz tam camın pikselinde; kodla desen/gradyan/parıltı yok (basamaklı gece tonu + kenar karartma + nesne altı gölge elipsi).
# Izgara: 640x360 tuval, oyunda x3 = 1920x1080 (kahraman/yaratıklar da sanat pikseli başına 3 ekran pikseli - aynı ızgara).
# Yerleşim loading_screen.gd ile EŞLENİK: PATH_RECT (ekran ortasına göre -720..720, 99..141) = tuval x 80..560, y 213..227 -> yol tam
# o bandın altında. Arayüz yazıları tuval y 235..265'te (yolun alt kenarı + çayır): orada uzun nesne yok.
# Canlı parçalar (Godot'ta oynar, loading_screen.gd LIVE_PARTS): harita/Ev/PNG/Trees_animation.png'deki rüzgârda sallanan ağaçlar
# (13 kare, 10 fps) + Smoke_animation.png'nin baca dumanı (6 kare) - her karesi sahneyle AYNI ışık geçişinden geçer, yatay şerit.
# Çıktı: assets/ui/yukleme/{yukleme_bg.png, agac_*.png, duman.png} + scripts/loading_scene_parts.gd (canlı parça yerleşimi; JSON
# export filtresine girmediği için GDScript sabiti); sonra Godot `--headless --import`.
#   python tools/gen_yukleme_bg.py            (oyun dosyaları)
#   python tools/gen_yukleme_bg.py --onizle <png>   (ek olarak canlı parçaları 0. karede yerleştirilmiş x2 önizleme)
import os
import random
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "proto_20261016"))
import gen_ana_menu_bg as gm  # noqa: E402  (kit kesici, pencere bulucu, Bayer)

W, H = 640, 360
K = 3
HARITA = os.path.join(ROOT, "harita")
OUT = os.path.join(ROOT, "assets", "ui", "yukleme")
BAYER = gm.BAYER
GRASS = gm.GRASS
AMBIENT = (0.36, 0.41, 0.62)      # ay ışığı (kulübe prototipi B ile aynı ton ailesi)
WARM = (1.0, 0.70, 0.40)          # cam ışığı
ROAD_Y = 198                      # yolun üst kenar karosu (198..214 kenar, 214..230 dolgu, 230..246 alt kenar)
TREE_FPS = 10.0                   # Animasyonlu_agac tsx: kare başı 100 ms
SMOKE_FPS = 8.0


# ------------------------------------------------------------------ ışık (gm.lit_pass'ın bölgeli, 640x360 kopyası)
def light_at(x, y, lights, b):
    lr, lg, lb = AMBIENT
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
    # kenar karartma: sol (orman) biraz daha koyu - yaratıklar karanlıktan çıkar
    vx = (x / W - 0.5) * 2
    vy = (y / H - 0.5) * 2
    v = max(0.0, vx * vx * 0.35 + vy * vy * 0.45 - 0.2) + max(0.0, -vx - 0.55) * 0.55
    v = min(1.0, int(v * 5 + b + 0.5) / 5.0 * 0.4)
    return lr, lg, lb, 1.0 - v


def lit(img, lights, ox=0, oy=0):
    """img'yi (tuvalde ox,oy'de duruyormuş gibi) basamaklı gece ışığından geçirir; alfa korunur."""
    px = img.load()
    out = Image.new("RGBA", img.size)
    po = out.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, bb, a = px[x, y]
            if a == 0:
                continue
            cx, cy = x + ox, y + oy
            b = (BAYER[(cy & 3) * 4 + (cx & 3)] + 0.5) / 16.0 - 0.5
            lr, lg, lb, m = light_at(cx, cy, lights, b)
            po[x, y] = (min(255, int(r * min(lr, 1.35) * m)), min(255, int(g * min(lg, 1.3) * m)),
                        min(255, int(bb * min(lb, 1.3) * m)), a)
    return out


def shadow(img, cx, cy, rx, ry, k=0.62):
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
        self.items = []

    def add(self, spr, foot_x, foot_y, shade=None):
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


# ------------------------------------------------------------------ yol (Yol parçaları.tsx wang karoları)
def road(img, rnd):
    tiles = Image.open(os.path.join(HARITA, "yalı", "Tiled_foles", "Exterior_tiles.png")).convert("RGBA")

    def t(i):
        return tiles.crop(((i % 14) * 16, (i // 14) * 16, (i % 14) * 16 + 16, (i // 14) * 16 + 16))
    top = [t(i) for i in (165, 216, 217)]       # wangid 0,0,0,1,1,1,0,0: yol altta
    fill = t(179)
    bottom = [t(i) for i in (193, 258, 259)]    # wangid 1,1,0,0,0,0,0,1: yol üstte
    for x in range(0, W, 16):
        img.alpha_composite(rnd.choice(top), (x, ROAD_Y))
        img.alpha_composite(fill, (x, ROAD_Y + 16))
        img.alpha_composite(rnd.choice(bottom), (x, ROAD_Y + 32))


# ------------------------------------------------------------------ canlı parçalar
def tree_strips():
    """Trees_animation.png: 13 kare alt alta (her biri 576x80), her karede 9 ağaç yan yana. Tüm karelerin birleşik alfasıyla
    ağaç sütunlarını bulur; her ağaç için 13 karelik kare listesi (aynı kutu) döndürür."""
    sh = Image.open(os.path.join(HARITA, "Ev", "PNG", "Trees_animation.png")).convert("RGBA")
    n = sh.height // 80
    frames = [sh.crop((0, i * 80, sh.width, i * 80 + 80)) for i in range(n)]
    union = Image.new("L", (sh.width, 80), 0)
    for f in frames:
        union = Image.composite(Image.new("L", union.size, 255), union, f.getchannel("A"))
    up = union.load()
    cols = [any(up[x, y] for y in range(80)) for x in range(sh.width)]
    segs = []
    x = 0
    while x < sh.width:
        if cols[x]:
            x0 = x
            while x < sh.width and cols[x]:
                x += 1
            segs.append((x0, x))
        x += 1
    trees = []
    for x0, x1 in segs:
        ys = [y for y in range(80) if any(up[xx, y] for xx in range(x0, x1))]
        box = (x0, ys[0], x1, ys[-1] + 1)
        trees.append([f.crop(box) for f in frames])
    return trees


def smoke_frames():
    """Smoke_animation.png (6 x 48x48): sadece duman pikselleri (baca + kırmızı çatı bu kulübeye ait değil), baca ağzı y 30."""
    sh = Image.open(os.path.join(HARITA, "Ev", "PNG", "Smoke_animation.png")).convert("RGBA")
    pal = {(103, 95, 93), (116, 106, 101), (88, 82, 81), (75, 71, 71)}
    out = []
    for i in range(sh.width // 48):
        f = sh.crop((i * 48, 0, i * 48 + 48, 30))
        px = f.load()
        for y in range(f.height):
            for x in range(f.width):
                if px[x, y][:3] not in pal:
                    px[x, y] = (0, 0, 0, 0)
        out.append(f)
    return out


def strip(frames):
    w, h = frames[0].size
    s = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        s.alpha_composite(f, (i * w, 0))
    return s


# ------------------------------------------------------------------ sahne
def build():
    obj, ext, sade, fl, tufts = gm.load_kit()
    rnd = random.Random(1717)
    sc = Scene(tuple(int(c * 0.95) for c in GRASS))
    road(sc.img, rnd)
    gm.scatter(sc, rnd, tufts, 30, 0, W, 6, H + 6, avoid=[(0, ROAD_Y - 4, W, ROAD_Y + 50)])

    # Kulübe: yolun sonunda (bar x 560'ta biter -> kahraman kapının önüne varır), pencereleri yanar.
    cabin = ext[2].copy()
    cab_foot = (548, ROAD_Y + 2)   # kapı ortası ~ayak x: bar %97'de (loading_screen HANDOFF_VALUE) kahraman tuval x ~544
    cx0 = round(cab_foot[0] - cabin.width / 2)
    cy0 = round(cab_foot[1] - cabin.height)
    wins = gm.window_lights(cabin, cx0, cy0)
    sc.add(cabin, cab_foot[0], cab_foot[1], (72, 6))
    sc.add(ext[21], 458, ROAD_Y - 4, (11, 3))     # sandıklar kulübenin solunda
    sc.add(ext[22], 446, ROAD_Y + 1, (10, 3))
    sc.add(ext[20], 632, 186, (11, 3))            # saman demeti kulübenin sağında
    sc.add(ext[24], 420, 180, (11, 3))            # balta saplı kütük
    sc.add(obj[12], 628, 48, (22, 5))            # kulübenin arkasında iki ağaç (çatının üstü boş kalmasın)
    sc.add(sade[3], 458, 40, (16, 4))

    # Üst bant: orman duvarı - solda sık ve koyu, kulübeye doğru seyrek.
    trees = [obj[i] for i in (0, 1, 2, 4, 5, 11, 12, 13, 15, 17)] + [sade[i] for i in (0, 2, 3, 4, 5)]
    x = -10.0
    row = 0
    while x < 440:
        t = rnd.choice(trees)
        base = 72 + (28 if x < 120 else 0)
        foot = rnd.uniform(base - 6, base + 26) if row % 2 == 0 else rnd.uniform(base - 24, base + 4)
        sc.add(t, x, foot, (t.width * 0.4, 4))
        x += rnd.uniform(22, 34) if x < 160 else rnd.uniform(34, 52)
        row += 1
    # Sol kenar: yolun iki yanında koyu orman (yol ağaçların arasından çıkar).
    for fx, fy in ((14, 186), (44, 174), (-4, 160), (30, 140), (8, 300), (40, 330), (-6, 360), (70, 362), (16, 268)):
        t = rnd.choice(trees)
        sc.add(t, fx, fy, (t.width * 0.4, 4))
    for x2, y2 in ((120, 168), (250, 150), (360, 164), (430, 120)):      # şeridin önünde seyrek çalı
        sc.add(rnd.choice([obj[6], obj[7], obj[8], sade[7], sade[12]]), x2 + rnd.uniform(-8, 8), y2, (10, 3))
    sc.add(obj[30], 196, 178, (12, 3))           # kesik kütük
    sc.add(obj[64], 210, 186)                    # kırmızı mantar
    sc.add(obj[54], 318, 184, (9, 3))            # küçük taş

    # Alt bant: çayır + sağ altta kaya, mantar; yazı bandı (y 232..270, x 70..570) boş.
    sc.add(obj[36], 592, 336, (22, 5))           # kaya sütunu
    sc.add(obj[65], 572, 342)
    sc.add(obj[28], 300, 334, (38, 5))           # devrik kütük
    sc.add(obj[71], 336, 330)
    sc.add(obj[8], 470, 320, (12, 3))
    sc.add(obj[7], 150, 312, (16, 4))
    gm.scatter(sc, rnd, fl, 26, 0, W, 252, H, avoid=[(60, 230, 580, 272)])
    gm.scatter(sc, rnd, fl, 10, 120, 470, 120, 192, avoid=[(440, 40, 640, 200)])

    # Canlı ağaçlar (Godot'ta oynar): statik sahnede yer tutmazlar, önlerinde/üstlerinde başka nesne yok.
    tstrips = tree_strips()
    live_trees = [  # (ağaç no, ayak x, ayak y)
        (0, 400, 84),     # büyük yeşil, kulübenin solu arkası
        (6, 150, 352),    # meşe, sol alt (yazı bandının altında)
        (1, 532, 312),    # orta yeşil, sağ alt
        (7, 236, 62),     # meşe (küçük), üst şerit
    ]
    img = sc.flatten()
    lights = [(x, y + 6, 58, WARM, 0.95, 0.85) for x, y in wins]
    bg = lit(img, lights)

    os.makedirs(OUT, exist_ok=True)
    parts = []
    for n, (ti, fx, fy) in enumerate(live_trees):
        frames = tstrips[ti]
        w, h = frames[0].size
        x0 = round(fx - w / 2)
        y0 = fy - h
        shadow(bg, fx, fy - 2, w * 0.36, 4)   # gölge statik zemine (ışıklanmış)
        litf = [lit(f, lights, x0, y0) for f in frames]
        name = "agac_%d.png" % n
        strip(litf).save(os.path.join(OUT, name))
        parts.append({"file": name, "x": x0, "y": y0, "w": w, "h": h, "frames": len(frames), "fps": TREE_FPS, "foot": fy})
    # Baca dumanı: kulübe bacasının ağzı (sprite'ta en üstteki gri taş sıra).
    chim = chimney_top(cabin, cx0, cy0)
    if chim:
        sm = smoke_frames()
        sx = round(chim[0]) - 24
        sy = chim[1] - 30
        litf = [lit(f, lights, sx, sy) for f in sm]
        strip(litf).save(os.path.join(OUT, "duman.png"))
        parts.append({"file": "duman.png", "x": sx, "y": sy, "w": 48, "h": 30, "frames": len(sm), "fps": SMOKE_FPS, "foot": 0})
    bg.convert("RGB").save(os.path.join(OUT, "yukleme_bg.png"))
    write_parts_gd(parts)
    print("pencereler:", [(round(x), round(y)) for x, y in wins], "baca:", chim)
    return bg, parts


def write_parts_gd(parts):
    lines = [
        "## OTOMATİK ÜRETİLİR: python tools/gen_yukleme_bg.py - elle düzenleme (sahne değişince yeniden üret).",
        "## Yükleme ekranı sahnesinin (assets/ui/yukleme/yukleme_bg.png, %dx%d tuval, oyunda x%d) canlı parçaları: yatay kare şeritleri." % (W, H, K),
        "## [dosya, tuvalde sol üst, kare boyutu, kare sayısı, fps, ayak y (çizim sırası)]",
        "",
        "const CANVAS := Vector2(%d, %d)" % (W, H),
        "const PARTS: Array = [",
    ]
    for p in sorted(parts, key=lambda q: q["foot"]):
        lines.append('\t["%s", Vector2(%d, %d), Vector2(%d, %d), %d, %.1f, %d],' % (
            p["file"], p["x"], p["y"], p["w"], p["h"], p["frames"], p["fps"], p["foot"]))
    lines.append("]")
    with open(os.path.join(ROOT, "scripts", "loading_scene_parts.gd"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


def chimney_top(cabin, ox, oy):
    """Kulübe sprite'ında bacayı bulur: çatının üstünden taşan gri-mavi taş piksellerin en üst satırının ortası (tuval koordinatı)."""
    px = cabin.load()
    for y in range(cabin.height // 2):
        xs = [x for x in range(cabin.width) if px[x, y][3] and abs(px[x, y][0] - px[x, y][2]) < 30 and 70 < px[x, y][0] < 200]
        if len(xs) >= 4:
            return (ox + (xs[0] + xs[-1]) / 2.0, oy + y)
    return None


def preview(bg, parts):
    img = bg.copy().convert("RGBA")
    for p in sorted(parts, key=lambda q: q["foot"]):
        s = Image.open(os.path.join(OUT, p["file"])).convert("RGBA").crop((0, 0, p["w"], p["h"]))
        img.alpha_composite(s, (p["x"], p["y"]))
    dst = sys.argv[sys.argv.index("--onizle") + 1] if len(sys.argv) > sys.argv.index("--onizle") + 1 else "yukleme_onizleme.png"
    img.resize((W * 2, H * 2), Image.NEAREST).save(dst)


if __name__ == "__main__":
    b, ps = build()
    if "--onizle" in sys.argv:
        preview(b, ps)
    print("ok", OUT)
