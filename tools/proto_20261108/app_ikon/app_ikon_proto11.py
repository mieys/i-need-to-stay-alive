"""UYGULAMA İKONU v11: v10 (C2 zemini, 14 karakter) YÜZ ODAKLI + biraz YAKIN (madde 488, oyuna bağlı DEĞİL).

Çalıştır:  python tools/proto_20261108/app_ikon/app_ikon_proto11.py     -> out/ozet_v11.png + out/ikon_v11_<karakter>.png

Kullanıcı (2026-11-10): "yüzleri odaklı olsun biraz yakınlaştır".
  - Zemin C2'nin BİREBİR aynısı, ekran uzayında sabit (256 px, 64 ızgara, 1 zemin pikseli = 4 ekran px): gök, çalılar, yıldızlar yerinde.
  - Karakter pikseli 8 -> 10 ekran px (%25 yakın): kanvas 25 x 10 = 250 (256'nın ortasında), büst 21x21 (eskisi 28x28), çerçeve aynı
    çizim kuralıyla 25 ızgarasında.
  - Yüz odağı: kırpım oyundaki yakın yüzle aynı kaynaktan - LobbyUI.face_texture (kullanılan alanın ortası, tepe - 1) + PortraitFace
    FACE_OY panel satırı + 10 = göz satırı; kırpımda gözler %53'te. Büyücü'nün şapka ucu bu yüzden kesilir.
  - Karaktere değen yıldız en yakın boş yere kayar (artı 12, nokta 6 zemin px), olmazsa düşer; boşluk 2 zemin px (8 ekran px).
"""
import os
import sys

from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
sys.path.insert(0, HERE)
import gen_app_icon as gai  # noqa: E402
import app_ikon_proto as v1  # noqa: E402
import app_ikon_proto5 as v5  # noqa: E402
import app_ikon_proto9 as v9  # noqa: E402
import app_ikon_proto10 as v10  # noqa: E402

SIZE = 256
BG_PX = 4                    # C2: 1 zemin pikseli = 4 ekran pikseli
N, S = 25, 10                # karakter ızgarası x ölçek = 250
CROP = N - 4                 # iç alan (kontur + iç hat iki yanda)
EYE_AT = 0.53                # gözler kırpımın üstünden bu oranda
GAP_PX = 2 * BG_PX

# portrait_face.gd FACE_OY (panel sütunu) + characters.gd kimlikleri
FACE_OY = {'talha': 0, 'oyku': 4, 'matthew': 2, 'buyucu': 6, 'assasin': 5, 'sovalye': 2, 'elara': 2, 'korsan': 2, 'melek': 4,
           'necromancer': 3, 'shaman': 4, 'vampir': 2, 'hadime': 2, 'cadi': 4}


# Kullanıcı (2026-11-10) Büyücü'yü seçti, önerim: yakınlık aynı, şapka ucu çerçevede kalsın -> kırpım 6 -> 3 (portre satır 2'deki
# tek piksellik uç iç hatta kesilir, v7 C ile aynı; gözler kırpımın %67'sinde).
TOP_OVERRIDE = {'buyucu': 3}


def face_crop(name):
    im = Image.open(v10.portrait_path(name)).convert('RGBA')
    x0, y0, x1, y1 = im.getbbox()
    w, h = im.size
    fx = max(0, min(w - 24, x0 + (x1 - x0) // 2 - 12))   # LobbyUI.face_texture (24x24)
    fy = max(0, min(h - 24, y0 - 1))
    eye = fy + FACE_OY[name] + 10                        # panel 18'liğinde gözler ~%56 = satır 10
    cx = fx + 12
    left = max(0, min(w - CROP, cx - CROP // 2))
    top = max(0, min(h - CROP, eye - round(EYE_AT * CROP)))
    top = TOP_OVERRIDE.get(name, top)
    return (left, top, left + CROP, top + CROP)


def char_layers(bust):
    """Karakter ızgarasında çerçeve (kontur + iç hat), büst ve maske."""
    m, outline, light = gai._frame_rings(N)
    frame = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    mask = Image.new('L', (N, N), 0)
    fp, mp = frame.load(), mask.load()
    for y in range(N):
        for x in range(N):
            mp[x, y] = 255 if m[y][x] else 0
            if outline[y][x]:
                fp[x, y] = gai.OUTL
            elif light[y][x]:
                fp[x, y] = gai.DUSK_LIGHT
    sprite = Image.open(gai.DUSK_PORTRAIT).convert('RGBA').crop(bust)
    layer = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    layer.alpha_composite(sprite, ((N - sprite.width) // 2, N - 2 - sprite.height))
    lp = layer.load()
    for y in range(N):
        for x in range(N):
            if not m[y][x] or outline[y][x] or light[y][x]:
                lp[x, y] = (0, 0, 0, 0)
    return frame, layer, mask


def place_stars(blocked_screen):
    """v10.place_stars'ın ekran uzayı sürümü: yıldızın 4x4 piksel blokları, karaktere / çerçeveye GAP_PX'ten yakın değil."""
    near = blocked_screen.filter(ImageFilter.MaxFilter(2 * GAP_PX + 1)).load()
    offsets = sorted(((dx, dy) for dx in range(-12, 13) for dy in range(-12, 13)), key=lambda d: d[0] ** 2 + d[1] ** 2)
    placed, taken, notes = [], set(), []
    for x, y, kind in v10.STARS:
        lim = 12 if kind == 'big' else 6
        for dx, dy in (d for d in offsets if max(abs(d[0]), abs(d[1])) <= lim):
            pxs = v10.star_pixels(x + dx, y + dy, kind)
            ok = all(0 <= px_ * BG_PX and (px_ + 1) * BG_PX <= SIZE and 0 <= py * BG_PX and (py + 1) * BG_PX <= SIZE
                     and not any(near[px_ * BG_PX + i, py * BG_PX + j] for i in range(BG_PX) for j in range(BG_PX))
                     and all((px_ + a, py + b) not in taken for a in (-2, -1, 0, 1, 2) for b in (-2, -1, 0, 1, 2))
                     for px_, py in pxs)
            if ok:
                placed.append((x + dx, y + dy, kind))
                taken.update(pxs)
                if dx or dy:
                    notes.append(f'{kind}({x},{y}) {dx:+d},{dy:+d}')
                break
        else:
            notes.append(f'{kind}({x},{y}) düştü')
    return placed, notes


def build(name):
    gai.DUSK_PORTRAIT = v10.portrait_path(name)
    bust = face_crop(name)
    frame, layer, mask = char_layers(bust)
    side = N * S
    off = (SIZE - side) // 2
    # yıldızın yaklaşamayacağı yer (ekran uzayı): maskenin dışı, kontur, iç hat, büst
    blocked = Image.new('L', (SIZE, SIZE), 255)
    inner = Image.new('L', (N, N), 0)
    ip, fp, lp, mp = inner.load(), frame.load(), layer.load(), mask.load()
    for y in range(N):
        for x in range(N):
            ip[x, y] = 0 if (mp[x, y] and fp[x, y][3] == 0 and lp[x, y][3] == 0) else 255
    blocked.paste(inner.resize((side, side), Image.NEAREST), (off, off))
    stars, notes = place_stars(blocked)
    ov, _ = v9.overlay(SIZE // BG_PX, stars, v10.BUSHES)
    sky = v9.gradient(SIZE, gai.DUSK_BANDS)   # C2 ile aynı: 256 satırlık geçiş
    sky.alpha_composite(ov.resize((SIZE, SIZE), Image.NEAREST))
    char = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    char.alpha_composite(frame.resize((side, side), Image.NEAREST), (off, off))
    char.alpha_composite(layer.resize((side, side), Image.NEAREST), (off, off))
    sky.alpha_composite(char)
    full = Image.new('L', (SIZE, SIZE), 0)
    full.paste(mask.resize((side, side), Image.NEAREST), (off, off))
    sky.putalpha(full)
    return sky, bust, notes


def main():
    os.makedirs(v1.OUT, exist_ok=True)
    arts, titles = {}, {}
    for key, (title, name) in v10.CHARS.items():
        arts[key], bust, notes = build(name)
        print(f'{key:12s} kırpım {bust}', '; '.join(notes))
        arts[key].save(os.path.join(v1.OUT, f'ikon_v11_{key}.png'))
        titles[key] = (title.replace(' (seçilen)', ''),)
    v5.PROTOS = titles
    out = os.path.join(v1.OUT, 'ozet_v11.png')
    v5.grid(arts).save(out)
    print(out)


if __name__ == '__main__':
    main()
