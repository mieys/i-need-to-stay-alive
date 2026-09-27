"""Menü arka planı (ana menü + tek/çok oyunculu karakter seçimi) -> assets/ui/menu_bg.png

Çalıştır:  python tools/gen_menu_bg.py [varyant] [çıktı_yolu]     (sonra Godot'ta `--headless --import`)
Varyantlar: orman (varsayılan, kullanıcının seçtiği), orman_koyu, seyrek, duz - hepsi prototip olarak gösterildi.

Kullanıcı isteği (2026-09-26): "başlangıç ve karakter seçim ekranlarının arkaplanı için daha sade bir arkaplan ...
ai gibi olmasın (sadece arkaplanlar, arayüz değil)". Eski assets/ui/lobby_bg.png kalabalık, yumuşak ışıklı bir
manzaraydı. Bunun yerine arka plan OYUNUN KENDİ harita tileset'lerinden (harita/...) kuruluyor: düz çim zemini +
kenarları saran ağaç halkası + halkanın hemen içinde seyrek çiçek/ot. Orta alan boş kalır (paneller orada).

Kurallar:
  - Her sanat pikseli TAM 3 ekran pikseli (menü kiti ve kart portreleriyle aynı ızgara) - 640x360 tuval -> 1920x1080.
  - Hiç yumuşak geçiş/gradyan/bulanıklık yok; renkler ya tileset'in kendi pikselleri ya da düz dolgu.
  - Sabit tohum: aynı komut hep aynı resmi üretir.
"""
import os
import random
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), '..')
W, H = 640, 360
SCALE = 3

TREES = os.path.join(ROOT, 'harita', 'köy insalar', 'Tiled_files', 'sade ağaç ve taş.png')
FLOWERS = os.path.join(ROOT, 'harita', 'köy insalar', 'Tiled_files', 'Flowers.png')
PLANTS = os.path.join(ROOT, 'harita', 'Çiftlik ve ev', 'Tiled_files', 'Plants.png')

GRASS = (122, 173, 85)  # Ground_grass.png'nin düz çim karosu (oyundaki zemin rengi)


def sprites(path, gap=1, min_px=6, box=None):
    """Sayfadaki ayrı nesneleri (alfa bağlantılı bileşenler, `gap` px yakınlık birleşir) kırpıp döndürür."""
    im = Image.open(path).convert('RGBA')
    if box:
        im = im.crop(box)
    w, h = im.size
    a = im.getchannel('A').load()
    seen = [[False] * w for _ in range(h)]
    out = []
    for y0 in range(h):
        for x0 in range(w):
            if seen[y0][x0] or a[x0, y0] == 0:
                continue
            stack = [(x0, y0)]
            seen[y0][x0] = True
            x1 = x2 = x0
            y1 = y2 = y0
            n = 0
            while stack:
                x, y = stack.pop()
                n += 1
                x1, x2, y1, y2 = min(x1, x), max(x2, x), min(y1, y), max(y2, y)
                for dy in range(-gap, gap + 1):
                    for dx in range(-gap, gap + 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and a[nx, ny] > 0:
                            seen[ny][nx] = True
                            stack.append((nx, ny))
            if n >= min_px:
                out.append(im.crop((x1, y1, x2 + 1, y2 + 1)))
    return out


def recolor(im, fn):
    im = im.copy()
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = fn(r, g, b) + (a,)
    return im


def shade(k, tint=(0, 0, 0), t=0.0):
    """Düz çarpan + isteğe bağlı renk karışımı (piksel sayısı/deseni değişmez, sadece ton)."""
    def f(r, g, b):
        return tuple(int(round((c * k) * (1 - t) + tc * t)) for c, tc in zip((r, g, b), tint))
    return f


def build(variant):
    rnd = random.Random(26092026)
    trees = sprites(TREES)
    flowers = sprites(FLOWERS)
    plants = sprites(PLANTS, box=(0, 120, 512, 240))  # alt yarı: toprak çukursuz kopyalar
    rocks = [s for s in trees if s.height < s.width * 0.8 and s.width < 40 and s.height < 30]
    trees = [s for s in trees if s not in rocks]
    big = [s for s in trees if s.width >= 48]          # büyük ağaçlar
    mid = [s for s in trees if 26 <= s.width < 48]      # küçük ağaç / büyük çalı
    tiny_fl = [s for s in flowers if s.width <= 14 and s.height <= 14]
    tufts = [s for s in plants if s.width <= 14 and s.height <= 14]

    trees = [s for s in trees if s.height <= 100]      # sayfada üst üste yapışık iki ağaç tek parça çıkıyor: at
    big = [s for s in trees if s.width >= 48]
    mid = [s for s in trees if 26 <= s.width < 48]

    if variant == 'duz':
        # En sade: sıcak koyu kahve düz zemin + 2x2 sanat pikselinde seyrek dama noktaları (keçe/masa örtüsü hissi).
        img = Image.new('RGB', (W, H), (74, 52, 38))
        px = img.load()
        for y in range(0, H, 8):
            for x in range((y // 8 % 2) * 4, W, 8):
                px[x, y] = (84, 60, 44)
        return img.resize((W * SCALE, H * SCALE), Image.NEAREST)

    f = shade(0.80, (44, 32, 22), 0.16)                 # çim bir ton kısık: bej paneller öne çıksın
    img = Image.new('RGBA', (W, H), f(*GRASS) + (255,))

    def put(s, x, y):
        img.alpha_composite(recolor(s, f), (int(x), int(y)))

    def edge(cx, cy):
        """0 = ekran ortası, 1 = kenar (süper-elips; köşeler > 1)."""
        u, v = (cx - W / 2) / (W / 2), (cy - H / 2) / (H / 2)
        return (u ** 4 + v ** 4) ** 0.25

    if variant == 'orman':
        ring, fl_count = 0.80, 60                        # açıklık: kenarları saran ağaç halkası
    elif variant == 'orman_koyu':
        ring, fl_count = 0.80, 60
        f = shade(0.58, (28, 22, 30), 0.22)              # aynı halka, alacakaranlık tonu
        img = Image.new('RGBA', (W, H), f(*GRASS) + (255,))
    elif variant == 'seyrek':
        ring, fl_count = 0.93, 40                        # sadece köşelerde birkaç ağaç
    else:
        raise SystemExit('bilinmeyen varyant: ' + variant)

    items = []
    bases = []
    for _ in range(4000):
        cx, cy = rnd.uniform(-30, W + 30), rnd.uniform(-10, H + 70)
        e = edge(cx, cy)
        if e < ring:
            continue
        if variant == 'seyrek' and (abs(cx - W / 2) < W * 0.30 or abs(cy - H / 2) < H * 0.22):
            continue                                     # sadece dört köşe
        s = rnd.choice(big if e > ring + 0.12 else mid + big)
        if cy < s.height * 0.6:
            continue                                     # üst kenarda sadece kök görünmesin: taç en az yarı görünür
        r = s.width * 0.5
        if any((cx - bx) ** 2 + (cy - by) ** 2 < (r + br) ** 2 * 0.45 for bx, by, br in bases):
            continue
        bases.append((cx, cy, r))
        items.append((cy, s, round(cx - s.width / 2), round(cy - s.height)))
    # Seyrek çiçek/ot: sadece halkanın hemen içi (orta alan boş, paneller orada).
    n = 0
    while n < fl_count:
        cx, cy = rnd.uniform(0, W), rnd.uniform(0, H)
        e = edge(cx, cy)
        if not (ring - 0.28 < e < ring + 0.02):
            continue
        if variant == 'seyrek' and (abs(cx - W / 2) < W * 0.25 or abs(cy - H / 2) < H * 0.15):
            continue
        s = rnd.choice(tiny_fl + tufts)
        items.append((cy, s, round(cx - s.width / 2), round(cy - s.height)))
        n += 1
    for _, s, x, y in sorted(items, key=lambda it: it[0]):
        put(s, x, y)
    return img.convert('RGB').resize((W * SCALE, H * SCALE), Image.NEAREST)


if __name__ == '__main__':
    variant = sys.argv[1] if len(sys.argv) > 1 else 'orman'
    path = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, 'assets', 'ui', 'menu_bg.png')
    build(variant).save(path)
    print('yazıldı:', path)
