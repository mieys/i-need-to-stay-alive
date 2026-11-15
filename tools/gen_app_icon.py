"""Uygulama ikonu (exe + pencere + Android başlatıcı) -> assets/app_icon.png (256x256) + assets/app_icon.ico (16..256)

Çalıştır:  python tools/gen_app_icon.py [varyant] [çıktı_klasörü]      (sonra Godot `--headless --import`, sonra export)

GÜNCEL İKON (2026-11-10, madde 488): varyant "alacakaranlik" (varsayılan) = Büyücü Kız / Alacakaranlık, prototip v12
(tools/proto_20261108/app_ikon/: v7 C kırpımı -> v9 C2 ince + yumuşak gök zemini -> v12 9x). Büyük resim doğrudan 256 px
ekran pikselinde kurulur, küçük boylar ondan yumuşak küçültülür. Ayrıntı: `art_dusk`.
Eski Hadime çayırı ikonu `python tools/gen_app_icon.py cayir` ile birebir geri gelir.

İlk ikon - kullanıcı isteği (2026-09-26): "oyunumun ikonunu suriyeli hadime karakteri yap (uygulama ikonunu kastettim)".
Kaynak: karakterin kendi 48x48 portresi (assets/characters/hadime_portrait.png) - yeniden ÇİZİLMEZ, sadece büst
kırpılıp tam sayı katında (nearest) büyütülür. Zemin (kullanıcının seçimi "cayir"): menü arka planıyla aynı çayır -
başın arkasında açık açıklık (siyah çarşaf koyu görev çubuğunda kaybolmasın), köşelerde çalı taçları, iki küçük çiçek.
Diğer varyantlar (tabela / kara_delik / gece / cayir_agacsiz) prototip olarak gösterildi, istenirse argümanla üretilir.
Küçük boyutlar (16/24/32/48) büyük resimden küçültülmez: her boy kendi tam sayı ölçeğinde ayrı üretilir (ICO'nun içinde).
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
ROOT = os.path.join(os.path.dirname(__file__), '..')
PORTRAIT = os.path.join(ROOT, 'assets', 'characters', 'hadime_portrait.png')

OUTL = (74, 44, 26, 255)  # menü kiti konturu (#4a2c1a)
BUST = (12, 6, 36, 30)     # portreden büst kırpımı (baş + omuzlar)
N = 26                     # sanat kanvası (256 px'te 9x)


def _grass(img, clearing=True, trees=True, flowers=True):
    """Menü arka planıyla (orman açıklığı) aynı çayır, ikon boyunda: menüdeki çim tonu, başın arkasında güneş alan daha
    açık yuvarlak bir açıklık (düz iki ton, gradyan yok), üst köşelerden taşan gerçek ağaç taçları, omuzların yanında
    koyu çarşafla zıtlaşan açık renkli iki çiçek. Hepsi harita tileset'lerinin kendi pikselleri."""
    import gen_menu_bg as mb
    f = mb.shade(0.80, (44, 32, 22), 0.16)
    img.paste(f(*mb.GRASS) + (255,), (0, 0, N, N))
    px = img.load()
    if clearing:
        lit = mb.shade(0.96, (255, 240, 200), 0.06)(*mb.GRASS) + (255,)
        cx, cy, r = 12.5, 10.5, 10.2
        for y in range(N):
            for x in range(N):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                    px[x, y] = lit
    if trees:
        # Köşelerde iki yuvarlak çalı tacının çeyreği (merkezleri tam köşede) - büyük ağaçlar ikonu boğuyordu.
        tr = [t for t in mb.sprites(mb.TREES) if t.height <= 100]
        left, right = tr[14], tr[12].transpose(Image.FLIP_LEFT_RIGHT)
        img.alpha_composite(mb.recolor(left, f), (-left.width // 2 - 3, -left.height // 2 - 3))
        img.alpha_composite(mb.recolor(right, f), (N - right.width // 2 + 3, -right.height // 2 - 3))
    if flowers:
        fl = mb.sprites(mb.FLOWERS)
        img.alpha_composite(fl[14], (0, N - 10))          # küçük mor çiçek (9x8)
        img.alpha_composite(fl[37], (N - 8, N - 12))      # küçük mavi çiçek (8x11)


def _sign(img):
    """Ana menü başlık tabelasının ahşap tahtaları (assets/ui/menu/sign.png, sanat pikseline geri indirgenmiş)."""
    sg = Image.open(os.path.join(ROOT, 'assets', 'ui', 'menu', 'sign.png')).convert('RGBA')
    sg = sg.resize((sg.width // 3, sg.height // 3), Image.NEAREST)
    img.alpha_composite(sg.crop((14, 12, 14 + N, 12 + N)))


def _void(img):
    """Hadime E'si Kara Delik: koyu mor gece + efektin en dolu karesi (yarı ölçek), halkası başının arkasından taşar."""
    img.paste((34, 24, 48, 255), (0, 0, N, N))
    sh = Image.open(os.path.join(ROOT, 'assets', 'fx', 'hadime', 'black_hole_sheet.png')).convert('RGBA')
    fr = sh.crop((11 * 192, 96, 12 * 192, 192))
    fr = fr.resize((96, 48), Image.NEAREST)
    img.alpha_composite(fr, (N // 2 - 48, 9 - 24))


def _night(img):
    """Gece çayırı + Hadime'nin lanet zerreleri (curse_mote) etrafında uçuşuyor."""
    import gen_menu_bg as mb
    f = mb.shade(0.52, (30, 24, 34), 0.30)
    img.paste(f(*mb.GRASS) + (255,), (0, 0, N, N))
    mote = Image.open(os.path.join(ROOT, 'assets', 'fx', 'hadime', 'curse_mote_sheet.png')).convert('RGBA')
    frames = [mote.crop((i * 8, 0, i * 8 + 8, 8)) for i in range(mote.width // 8)]
    for i, (x, y) in enumerate(((1, 3), (N - 8, 2), (0, 13), (N - 7, 14), (6, -1))):
        img.alpha_composite(frames[i % len(frames)], (x, y))


# ad: (zemin çizici, zemin üst ışık rengi (kenar içi 1 px), None = ışık yok)
VARIANTS = {
    'cayir': (_grass, None),
    'cayir_agacsiz': (lambda im: _grass(im, trees=False), None),
    'tabela': (_sign, None),
    'kara_delik': (_void, (120, 90, 170, 255)),
    'gece': (_night, (110, 120, 150, 255)),
}


def rounded_mask(n, r):
    def inside(x, y):
        cx = min(max(x, r), n - 1 - r)
        cy = min(max(y, r), n - 1 - r)
        return (x - cx) ** 2 + (y - cy) ** 2 <= r * r + r * 0.6
    return [[inside(x, y) for x in range(n)] for y in range(n)]


def art(variant):
    paint, light = VARIANTS[variant]
    n = N
    m = rounded_mask(n, 3)
    bg = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    paint(bg)
    bp = bg.load()
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    px = img.load()
    for y in range(n):
        for x in range(n):
            if not m[y][x]:
                continue
            edge = any(not (0 <= x + dx < n and 0 <= y + dy < n and m[y + dy][x + dx])
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if edge:
                px[x, y] = OUTL
            elif light and (y < 2 or not m[y - 2][x] or x < 2 or not m[y][x - 2] or x > n - 3 or not m[y][x + 2]):
                px[x, y] = light  # iç kenarda 1 px açık hat: koyu görev çubuğunda da ikon kenarı seçilsin
            else:
                px[x, y] = bp[x, y]
    sprite = Image.open(PORTRAIT).convert('RGBA').crop(BUST)
    layer = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    layer.alpha_composite(sprite, ((n - sprite.width) // 2, n - 1 - sprite.height))
    lp = layer.load()
    for y in range(n):
        for x in range(n):
            if not m[y][x] or px[x, y] == OUTL:
                lp[x, y] = (0, 0, 0, 0)  # büst çerçevenin içinde kalır, alt kenara oturur
    img.alpha_composite(layer)
    return img


# ---------------------------------------------------------------- GÜNCEL: Büyücü Kız / Alacakaranlık (madde 488 v12)
# İki ızgara: karakter + çerçeve 28'lik ızgarada 9x (252 px, 256'nın ortasında); gök zemini EKRAN uzayında 64'lük ızgara (1 zemin
# pikseli = 4 ekran pikseli, karakter pikselinin ~yarısı - kullanıcı: "daha net dursun ... 32x32 ise 64x64 yap gibi"). Gök bant değil
# ekran pikselinde düz dikey geçiş (kullanıcı: "katman katman değil smooth"; dither yok). Prototip zinciri tools/proto_20261108/app_ikon/
# v8 (ince zemin) -> v9 C2 (yumuşak gök, yuvarlak çalılar) -> v11 (yüz odaklı) -> v12 (ara yakınlık 9x).
DUSK_SIZE = 256
DUSK_N = 28                     # karakter ızgarası
DUSK_S = 9                      # karakter pikseli = 9 ekran px
DUSK_BG_PX = 4                  # zemin pikseli = 4 ekran px (64 ızgara)
DUSK_PORTRAIT = os.path.join(ROOT, 'assets', 'characters', 'buyucu_portrait.png')
DUSK_BUST = (12, 3, 36, 27)     # 24x24: yüz ortada (gözler %58), şapka ucunun 1 pikseli iç hatta kesilir
DUSK_LIGHT = (150, 124, 176, 255)  # çerçeve içi açık hat (koyu görev çubuğunda kenar seçilsin)
DUSK_BANDS = ['#252c5c', '#33386e', '#4e4280', '#7a4c82', '#a8587a', '#d0745e', '#e8a064']  # gök geçiş durakları, üstten alta
DUSK_STAR = '#e8e4f6'
DUSK_STAR_DIM = '#b8b8dc'
# zemin ızgarasında (x, y, tür): big = 5x5 artı (merkez + iç kollar parlak, uçlar sönük), dot = tek parlak, dim = tek sönük.
# İki yan ayna DEĞİL (kullanıcı 2026-11-10: birebir ayna "hiç doğal durmuyor"); hepsi iç hattan / büstten en az 8 ekran px uzak.
DUSK_STARS = [(11, 11, 'big'), (52, 17, 'big'), (19, 7, 'dot'), (7, 20, 'dim'), (17, 17, 'dim'), (45, 7, 'dot'),
              (56, 10, 'dim'), (56, 26, 'dim')]
# alt köşe çalıları (gen_menu_bg TREES sprite'ı, zemin ızgarasında sol üst x, y, parlaklık), arkadakiler önce, haritadaki kendi
# piksel boyunda; sol yuvarlak tr[15] + tr[7] (sivri tr[12] "keskin" bulundu), sağ tr[10] + tr[15]; iki yan da kenarda yüksek.
DUSK_BUSHES = [(15, -12, 39, 0.36), (7, 2, 48, 0.46), (10, 44, 38, 0.36), (15, 38, 48, 0.46)]
DUSK_STAR_GAP = 8               # ekran px


def _hex(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def _dusk_sky():
    """Ekran boyunda gök: düz dikey geçiş (satır başına tek renk) + zemin ızgarasında yıldızlar ve çalılar (4x nearest)."""
    import gen_menu_bg as mb
    size, cols = DUSK_SIZE, [_hex(c) for c in DUSK_BANDS]
    sky = Image.new('RGBA', (size, size))
    p = sky.load()
    for y in range(size):
        t = y / (size - 1) * (len(cols) - 1)
        i = min(int(t), len(cols) - 2)
        u = t - i
        c = tuple(round(cols[i][k] + (cols[i + 1][k] - cols[i][k]) * u) for k in range(3)) + (255,)
        for x in range(size):
            p[x, y] = c
    g = size // DUSK_BG_PX
    ov = Image.new('RGBA', (g, g), (0, 0, 0, 0))
    op = ov.load()

    def put(pts, col):
        for x, y in pts:
            if 0 <= x < g and 0 <= y < g:
                op[x, y] = _hex(col)
    for x, y, kind in DUSK_STARS:
        if kind == 'big':
            put([(x, y), (x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)], DUSK_STAR)
            put([(x - 2, y), (x + 2, y), (x, y - 2), (x, y + 2)], DUSK_STAR_DIM)
        else:
            put([(x, y)], DUSK_STAR if kind == 'dot' else DUSK_STAR_DIM)
    tr = [t for t in mb.sprites(mb.TREES) if t.height <= 100]
    for idx, x, y, k in DUSK_BUSHES:
        ov.alpha_composite(mb.recolor(tr[idx], mb.shade(k, (52, 30, 70), 0.55)), (x, y))
    sky.alpha_composite(ov.resize((size, size), Image.NEAREST))
    return sky


def _frame_rings(n, r=3):
    """Yuvarlak köşeli maske, dış kontur (4 komşulu dış halka) ve iç hat (konturun 8 komşulu iç halkası: dört kenar + köşeler
    kesintisiz). Eski `art` iç hattı 'y-2' kuralıyla çizip alt kenarı atlıyordu."""
    m = rounded_mask(n, r)

    def inside(x, y):
        return 0 <= x < n and 0 <= y < n and m[y][x]

    outline = [[inside(x, y) and any(not inside(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                for x in range(n)] for y in range(n)]
    light = [[inside(x, y) and not outline[y][x] and any(
        0 <= x + dx < n and 0 <= y + dy < n and outline[y + dy][x + dx]
        for dx in (-1, 0, 1) for dy in (-1, 0, 1) if dx or dy)
        for x in range(n)] for y in range(n)]
    return m, outline, light


def _dusk_char_layers():
    """Karakter ızgarasında: çerçeve (kontur + iç hat), iç hattın içine kırpılmış büst (alttan iç hatta oturur), maske."""
    n = DUSK_N
    m, outline, light = _frame_rings(n)
    frame = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    mask = Image.new('L', (n, n), 0)
    fp, mp = frame.load(), mask.load()
    for y in range(n):
        for x in range(n):
            mp[x, y] = 255 if m[y][x] else 0
            if outline[y][x]:
                fp[x, y] = OUTL
            elif light[y][x]:
                fp[x, y] = DUSK_LIGHT
    sprite = Image.open(DUSK_PORTRAIT).convert('RGBA').crop(DUSK_BUST)
    bust = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    bust.alpha_composite(sprite, ((n - sprite.width) // 2, n - 2 - sprite.height))
    bp = bust.load()
    for y in range(n):
        for x in range(n):
            if not m[y][x] or outline[y][x] or light[y][x]:
                bp[x, y] = (0, 0, 0, 0)
    return frame, bust, mask


def art_dusk():
    """256x256 son ikon (ekran pikselinde): gök + ortada 9x çerçeve ve büst, maskenin dışı saydam."""
    frame, bust, mask = _dusk_char_layers()
    side = DUSK_N * DUSK_S
    off = (DUSK_SIZE - side) // 2
    img = _dusk_sky()
    for layer in (frame, bust):
        img.alpha_composite(layer.resize((side, side), Image.NEAREST), (off, off))
    alpha = Image.new('L', (DUSK_SIZE, DUSK_SIZE), 0)
    alpha.paste(mask.resize((side, side), Image.NEAREST), (off, off))
    img.putalpha(alpha)
    return img


def dusk_star_contacts():
    """Denetim: yıldız pikseli (4x4 blok) çerçeveye / büste / dışa DUSK_STAR_GAP ekran px'ten yakın olmamalı -> 0."""
    from PIL import ImageFilter
    frame, bust, mask = _dusk_char_layers()
    n, side = DUSK_N, DUSK_N * DUSK_S
    off = (DUSK_SIZE - side) // 2
    inner = Image.new('L', (n, n), 0)
    ip, fp, bp, mp = inner.load(), frame.load(), bust.load(), mask.load()
    for y in range(n):
        for x in range(n):
            ip[x, y] = 0 if (mp[x, y] and fp[x, y][3] == 0 and bp[x, y][3] == 0) else 255
    blocked = Image.new('L', (DUSK_SIZE, DUSK_SIZE), 255)
    blocked.paste(inner.resize((side, side), Image.NEAREST), (off, off))
    near = blocked.filter(ImageFilter.MaxFilter(2 * DUSK_STAR_GAP + 1)).load()
    bad = 0
    for x, y, kind in DUSK_STARS:
        r = 2 if kind == 'big' else 0
        for sx, sy in [(x + d, y) for d in range(-r, r + 1)] + [(x, y + d) for d in range(-r, r + 1) if d]:
            bad += sum(1 for i in range(DUSK_BG_PX) for j in range(DUSK_BG_PX)
                       if near[sx * DUSK_BG_PX + i, sy * DUSK_BG_PX + j])
    return bad


def at_size(a, size):
    """`size` px'lik kare: en büyük tam sayı ölçek, ortalanmış. Tam sayı ölçek kareyi yeterince doldurmuyorsa (ör. 26 px
    sanat 48 px'te 1x kalırdı) ya da hiç sığmıyorsa büyük hâlden yumuşak küçültme - sadece 16..48 px'lik minik boylar."""
    k = size // a.width
    if k >= 1 and a.width * k >= size * 0.8:
        big = a.resize((a.width * k, a.height * k), Image.NEAREST)
        out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        out.alpha_composite(big, ((size - big.width) // 2, (size - big.height) // 2))
        return out
    return at_size(a, 256).resize((size, size), Image.LANCZOS)


def build(variant, outdir):
    a = art_dusk() if variant == 'alacakaranlik' else art(variant)
    sizes = [256, 128, 64, 48, 32, 24, 16]
    frames = [at_size(a, s) for s in sizes]
    png = os.path.join(outdir, 'app_icon.png')
    ico = os.path.join(outdir, 'app_icon.ico')
    frames[0].save(png)
    frames[0].save(ico, sizes=[(s, s) for s in sizes], append_images=frames[1:])
    return png, ico


if __name__ == '__main__':
    variant = sys.argv[1] if len(sys.argv) > 1 else 'alacakaranlik'
    outdir = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, 'assets')
    print(*build(variant, outdir))
    if variant == 'alacakaranlik':
        print('yıldız teması (0 olmalı):', dusk_star_contacts())
