"""UYGULAMA İKONU v10: seçilen C2 zemini (madde 488 v9) + HER KARAKTER için bir varyant (oyuna bağlı DEĞİL).

Çalıştır:  python tools/proto_20261108/app_ikon/app_ikon_proto10.py     -> out/ozet_v10.png + out/ikon_v10_<karakter>.png

Kullanıcı (2026-11-10): "arkaplanı c2 seçiyorum. şimdi senden isteğim büyücü kız yerine diğer karakterlerin olduğu birer varyant
hazırlayıp bana sunman liste halinde". Zemin birebir C2 (32 kanvas x 8 = 256, zemin 64 ızgara, yumuşak gün batımı, yuvarlak çalılar,
mor iç hat); değişen yalnız büst: 28x28 kırpım, baş tepesi Büyücü'nün şapka ucuyla aynı satırda (kırpım y = portre tepesi - 1),
yatayda başın ortasına (Korsan şapkası sağa taşkın). Bir yıldız bir karakterin saçına / şapkasına değerse (2 zemin px) en yakın
boş yere kayar, yer yoksa o varyantta düşer (çıktıda yazılır).
"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
sys.path.insert(0, HERE)
import gen_app_icon as gai  # noqa: E402
import app_ikon_proto as v1  # noqa: E402
import app_ikon_proto5 as v5  # noqa: E402
import app_ikon_proto8 as v8  # noqa: E402
import app_ikon_proto9 as v9  # noqa: E402

_, N, S, F, BUST_C2, _, STARS, BUSHES = v9.PROTOS['C2']
CROP = 28

# ad: (başlık, portre dosyası)
CHARS = {
    'buyucu': ('Büyücü Kız (seçilen)', 'buyucu'),
    'talon': ('Talon', 'talha'),
    'oakley': ('Oakley', 'oyku'),
    'matthew': ('Matthew', 'matthew'),
    'assasin': ('Assasin', 'assasin'),
    'sovalye': ('Şovalye', 'sovalye'),
    'elara': ('Elara', 'elara'),
    'korsan': ('Korsan', 'korsan'),
    'melek': ('Melek', 'melek'),
    'necromancer': ('Necromancer', 'necromancer'),
    'shaman': ('Shaman', 'shaman'),
    'vampir': ('Vampir', 'vampir'),
    'hadime': ('Hadime', 'hadime'),
    'cadi': ('Cadı', 'cadi'),
}


def portrait_path(name):
    return os.path.join(ROOT, 'assets', 'characters', name + '_portrait.png')


def bust_for(key, name):
    if key == 'buyucu':
        return BUST_C2
    im = Image.open(portrait_path(name)).convert('RGBA')
    p = im.load()
    w, h = im.size
    top = next(y for y in range(h) if any(p[x, y][3] > 0 for x in range(w)))
    cols = [x for x in range(w) if any(p[x, y][3] > 0 for y in range(top, min(h, top + 22)))]
    cx = (cols[0] + cols[-1] + 1) / 2
    x0 = max(0, min(w - CROP, round(cx - CROP / 2)))
    y0 = max(0, top - 1)
    return (x0, y0, x0 + CROP, y0 + CROP)


def blocked_grid(bust):
    """Karakter ızgarasında yıldızın yaklaşamayacağı hücreler: dış, kontur, iç hat, büst."""
    m, outline, light = gai._frame_rings(N)
    sprite = Image.open(gai.DUSK_PORTRAIT).convert('RGBA').crop(bust)
    layer = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    layer.alpha_composite(sprite, ((N - sprite.width) // 2, N - 2 - sprite.height))
    lp = layer.load()
    return [[not m[y][x] or outline[y][x] or light[y][x] or lp[x, y][3] > 0 for x in range(N)] for y in range(N)]


def star_pixels(x, y, kind):
    r = {'big': 2, 'plus': 1}.get(kind, 0)
    return [(x + dx, y + dy) for dx in range(-r, r + 1) for dy in range(-r, r + 1) if dx == 0 or dy == 0]


def fits(pxs, blocked, taken):
    for sx, sy in pxs:
        for dx in range(-v8.GAP, v8.GAP + 1):
            for dy in range(-v8.GAP, v8.GAP + 1):
                cx, cy = (sx + dx) // F, (sy + dy) // F
                if not (0 <= cx < N and 0 <= cy < N) or blocked[cy][cx] or (sx + dx, sy + dy) in taken:
                    return False
    return True


def place_stars(blocked):
    """C2 yıldızları; değen yıldız en yakın boş yere (artı yıldız en çok 12, nokta 6 zemin px) kayar, olmazsa düşer."""
    offsets = sorted(((dx, dy) for dx in range(-12, 13) for dy in range(-12, 13)), key=lambda d: d[0] ** 2 + d[1] ** 2)
    placed, taken, notes = [], set(), []
    for x, y, kind in STARS:
        lim = 12 if kind == 'big' else 6
        for dx, dy in (d for d in offsets if max(abs(d[0]), abs(d[1])) <= lim):
            pxs = star_pixels(x + dx, y + dy, kind)
            if fits(pxs, blocked, taken):
                placed.append((x + dx, y + dy, kind))
                taken.update(pxs)
                if dx or dy:
                    notes.append(f'{kind}({x},{y}) {dx:+d},{dy:+d} kaydı')
                break
        else:
            notes.append(f'{kind}({x},{y}) düştü')
    return placed, notes


def main():
    os.makedirs(v1.OUT, exist_ok=True)
    arts, titles = {}, {}
    for key, (title, name) in CHARS.items():
        gai.DUSK_PORTRAIT = portrait_path(name)
        bust = bust_for(key, name)
        stars, notes = place_stars(blocked_grid(bust))
        arts[key], bad = v9.build(N, S, F, bust, True, stars, BUSHES)
        print(f'{key:12s} kırpım {bust} yıldız teması {bad}', '; '.join(notes))
        out = Image.new('RGBA', (256, 256), (0, 0, 0, 0))
        out.alpha_composite(arts[key], ((256 - arts[key].width) // 2, (256 - arts[key].height) // 2))
        out.save(os.path.join(v1.OUT, f'ikon_v10_{key}.png'))
        titles[key] = (title,)
    v5.PROTOS = titles
    out = os.path.join(v1.OUT, 'ozet_v10.png')
    v5.grid(arts).save(out)
    print(out)


if __name__ == '__main__':
    main()
