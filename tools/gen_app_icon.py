"""Uygulama ikonu (exe + pencere) -> assets/app_icon.png (256x256) + assets/app_icon.ico (16..256)

Çalıştır:  python tools/gen_app_icon.py [varyant] [çıktı_klasörü]

Kullanıcı isteği (2026-09-26): "oyunumun ikonunu suriyeli hadime karakteri yap (uygulama ikonunu kastettim)".
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
    a = art(variant)
    sizes = [256, 128, 64, 48, 32, 24, 16]
    frames = [at_size(a, s) for s in sizes]
    png = os.path.join(outdir, 'app_icon.png')
    ico = os.path.join(outdir, 'app_icon.ico')
    frames[0].save(png)
    frames[0].save(ico, sizes=[(s, s) for s in sizes], append_images=frames[1:])
    return png, ico


if __name__ == '__main__':
    variant = sys.argv[1] if len(sys.argv) > 1 else 'cayir'
    outdir = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, 'assets')
    print(*build(variant, outdir))
