"""UYGULAMA İKONU v5: HER KARAKTER İÇİN BİR prototip (madde 488, oyuna bağlı DEĞİL).

Çalıştır:  python tools/proto_20261108/app_ikon/app_ikon_proto5.py      -> out/ozet_v5.png + out/ikon_v5_<karakter>.png

Kullanıcı (2026-11-08): v4 yüz odaklı D'den vazgeçti ("önceki hali D daha iyi"), "ama hemen eklemeyelim biraz daha prototip
istiyorum her karakter için 1 prototip hazırla". Dil = beğenilen v3 D (Büyücü / Alacakaranlık): 26x26 sanat kanvası (256'da 9x),
24x24 büst, karakterin portre temasından (tools/proto_20261108/portre_tema, madde 464) düz bantlar + tek motif, dither / hale /
parıltı yok; koyu zeminlilerde çerçeve içi 1 px açık hat. Büyücü = v3 D, Melek / Shaman / Vampir = v2 C / D / B aynen;
Hadime bu sette kendi teması (lanet sayfası + rün halkası), diğerleri yeni. Yüz koyu (Hadime çarşafı, Cadı) -> zemin açık ya da
başın arkasında açıklık.
"""
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
sys.path.insert(0, HERE)
import gen_app_icon as gai  # noqa: E402
import gen_menu_bg as mb  # noqa: E402
import app_ikon_proto as v1  # noqa: E402
import app_ikon_proto2 as v2  # noqa: E402
import app_ikon_proto3 as v3  # noqa: E402
from app_ikon_proto2 import bands, px, rect, disc, star, bat, silhouette, C  # noqa: E402

N = gai.N


def ring(img, cx, cy, r, col, w=0.55):
    px(img, [(x, y) for x in range(N) for y in range(N)
             if abs(((x - cx + 0.5) ** 2 + (y - cy + 0.5) ** 2) ** 0.5 - r) <= w], col)


def line(img, pts, col):
    px(img, pts, col)


# ---------------------------------------------------------------- yeni zeminler
def talon(img):
    """Ayna Formu: koyu kızıl bantlar + kırık ayna kıymıkları (açık pembe kısa çapraz çizgiler, tek beyaz uç)."""
    bands(img, ['#3a1a20', '#4c2026', '#5e262a', '#702c2e', '#3a1618'], [3, 3, 3, 2, 2])
    v3._clearing(img, C('#93484a'))   # kahve saç koyu kızılda kayboluyordu: başın arkasında açık kızıl açıklık
    for (x, y, n) in [(1, 8, 4), (20, 2, 5), (22, 12, 3), (3, 1, 3)]:
        line(img, [(x + k, y + n - 1 - k) for k in range(n)], '#d88a8a')
        px(img, [(x + n - 1, y)], '#f6dede')
    v2._crowns(img, mb.shade(0.30, (60, 10, 16), 0.5))


def oakley(img):
    """Çiçekli çayır: bugünkü çayırın daha açık bahar tonu + köşelerde pembe/sarı küçük çiçekler + bir arı."""
    v3._meadow(img,
               base=mb.shade(0.90, (255, 240, 170), 0.08),
               lit=mb.shade(1.04, (255, 250, 210), 0.10),
               crowns=mb.shade(0.82, (40, 60, 20), 0.12), flowers=False)
    for (x, y, petal) in [(2, 19, '#f2a6c0'), (5, 23, '#f6d860'), (22, 20, '#f2a6c0'), (19, 23, '#f6d860'), (24, 15, '#f6d860')]:
        px(img, [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)], petal)
        px(img, [(x, y)], '#fff4c8')
    px(img, [(20, 7), (22, 7)], '#f6d860')   # arı: sarı-siyah gövde + kanat
    px(img, [(21, 7)], '#2a2018')
    px(img, [(21, 6)], '#e8f4fc')


def matthew(img):
    """Fırtına arduvazı + altın yıldırım (sağda büyük zikzak, solda küçük)."""
    bands(img, ['#3e4656', '#4a5364', '#566072', '#626d7e', '#363d4a'], [3, 3, 3, 2, 2])
    bolt = [(22, 0), (21, 1), (21, 2), (20, 3), (21, 4), (22, 4), (21, 5), (20, 6), (20, 7), (19, 8), (20, 9), (19, 10)]
    px(img, bolt, '#f2c442')
    px(img, [(x + 1, y) for (x, y) in bolt[:6]], '#c08a2a')
    px(img, [(3, 4), (2, 5), (3, 6), (2, 7), (2, 8)], '#f2c442')
    px(img, [(24, 14), (1, 13)], '#8a94a8')  # yağmur damlası benekleri
    v2._crowns(img, mb.shade(0.36, (20, 26, 40), 0.45))


def assasin(img):
    """Ay ışığı: açık soğuk gök (siyah sivri saç silüet olur) + sol üstte ay (kesik ayın üstünden geçiyordu) + kızıl çapraz kesik
    (sol alttan sağ üste, başın arkasından)."""
    bands(img, ['#c4ccdc', '#b2bcd0', '#a0acc4', '#8e9cb8', '#6a7894'], [3, 3, 3, 2, 2])
    disc(img, 4, 4, 3.2, '#eef0f6')
    for k in range(26):
        x, y = k, 25 - k
        px(img, [(x, y)], '#b8262e')
        px(img, [(x + 1, y)], '#e85a5a')
    v2._crowns(img, mb.shade(0.40, (30, 30, 50), 0.45))


def sovalye(img):
    """Kale duvarı: gri taş tuğla dizisi (3 satırlık sıralar, kaydırmalı) + sağ üstte kırmızı sancak."""
    img.paste(C('#8c867a'), (0, 0, N, N))
    for row in range(0, N, 4):
        rect(img, 0, row + 3, N, 1, '#6c675d')
        off = 0 if (row // 4) % 2 == 0 else 3
        for x in range(off, N, 6):
            rect(img, x, row, 1, 3, '#6c675d')
        rect(img, 0, row, N, 1, '#9a9488')       # tuğla üst ışığı
    rect(img, 19, 0, 5, 9, '#b0302c')
    rect(img, 20, 0, 1, 9, '#c84a3e')
    px(img, [(21, 9), (21, 8), (20, 9), (22, 9)], '#8c867a')  # V çentik
    px(img, [(19, 9), (23, 9)], '#b0302c')
    rect(img, 18, 0, 7, 1, '#6a4a2a')             # sancak direği


def elara(img):
    """Nane gök + çam ormanı silüetleri + turkuaz rüzgâr çizgisi."""
    bands(img, ['#d4ece2', '#c2e2d6', '#aed6c6', '#9acab6'], [3, 3, 3, 2])
    for (x0, x1, y) in [(1, 7, 4), (17, 24, 7)]:
        rect(img, x0, y, x1 - x0, 1, '#4ab0a8')
        px(img, [(x1, y - 1)], '#4ab0a8')
    def pine(cx, base, h, col):
        for i in range(h):
            w = 1 + (i * 2) // 3
            rect(img, cx - w // 2 - (w % 2 == 0), base - h + i, w + (w % 2 == 0), 1, col)
    for (cx, h) in [(1, 12), (5, 9), (21, 10), (25, 13)]:
        pine(cx, N, h, '#3e7a52')
    for (cx, h) in [(3, 7), (23, 7)]:
        pine(cx, N, h, '#2c5e40')


def korsan(img):
    """Açık gök + ufuk + deniz bantları, beyaz dalga sırtları, uzakta küçük yelken."""
    bands(img, ['#b4d4ee', '#c4dcf2', '#d4e6f6', '#4a84b4', '#3c74a4', '#2e6292'], [3, 3, 2, 2, 2, 2])
    for (x, y) in [(2, 19), (6, 22), (20, 18), (23, 21), (1, 24)]:
        px(img, [(x, y), (x + 1, y), (x + 1, y - 1)], '#e8f2fa')
    rect(img, 21, 11, 1, 3, '#5a3e2a')   # direk
    px(img, [(22, 11), (22, 12), (23, 12)], '#f4f0e6')  # yelken
    rect(img, 20, 14, 4, 1, '#4a3424')   # tekne


def necromancer(img):
    """Mezarlık sisi: gri-yeşil gece + soluk ay + mezar taşı silüetleri + sis çizgisi."""
    bands(img, ['#38443e', '#404e46', '#4a5a50', '#56685a', '#2a3630'], [3, 3, 3, 2, 2])
    disc(img, 21, 5, 3.6, '#d8dcc4')
    disc(img, 22, 4, 1.0, '#c4c8ae')
    for (x, h) in [(0, 9), (5, 7), (19, 8), (23, 10)]:
        rect(img, x, N - h, 3, h, '#202a24')
        rect(img, x, N - h - 1, 3, 1, '#202a24')
        px(img, [(x, N - h - 1), (x + 2, N - h - 1)], '#4a5a50')  # yuvarlak tepe
    rect(img, 0, 17, N, 1, '#788c78')
    px(img, [(3, 3), (8, 1)], '#a8b4a0')


def cadi(img):
    """Bataklık gecesi: koyu deniz yeşili + başın arkasında daha açık sis açıklığı (koyu saç kaybolmasın) + yeşil zehir
    dumanı bandı + soluk hilal."""
    bands(img, ['#1e2e2e', '#243838', '#2c4442', '#34504c', '#22302e'], [3, 3, 3, 2, 2])
    v3._clearing(img, C('#45685f'))
    disc(img, 21, 4, 3.0, '#e8e2b0')
    disc(img, 22, 3, 2.4, '#2a3e3c')      # hilal
    for x in range(N):
        y = 19 + (1 if (x // 3) % 2 else 0)
        px(img, [(x, y)], '#7ab04e')
        px(img, [(x, y + 1)], '#5a8a3c')
    px(img, [(3, 3), (6, 8)], '#b8c8a8')
    v2._crowns(img, mb.shade(0.34, (16, 40, 30), 0.45))


def hadime(img):
    """Lanet kitabının eski sayfası (açık parşömen: siyah çarşaf en net burada) + başın çevresinde mor rün halkası."""
    bands(img, ['#f0e2c0', '#e8d6ae', '#dfca9c', '#d4bc8a'], [3, 3, 3, 2])
    ring(img, 12.5, 9.5, 9.6, '#8a62a8')
    for (x, y) in [(12, 0), (2, 9), (22, 9)]:
        rect(img, x, y, 2, 2, '#6a4688')
    px(img, [(4, 2), (20, 2), (1, 16), (24, 16)], '#c4a878')  # sayfa lekeleri
    rect(img, 0, 22, N, 1, '#c8ae7c')


# ad: (başlık, portre dosyası, büst kırpımı, zemin, açık hat)
LIGHT_RED = (196, 120, 124, 255)
LIGHT_GREY = (150, 160, 180, 255)
LIGHT_GREEN = (140, 170, 150, 255)
PROTOS = {
    'talon': ('Talon - Kızıl Ayna', 'talha', (12, 6, 36, 30), talon, LIGHT_RED),
    'oakley': ('Oakley - Bahar Çayırı', 'oyku', (12, 3, 36, 27), oakley, None),
    'matthew': ('Matthew - Fırtına', 'matthew', (12, 6, 36, 30), matthew, LIGHT_GREY),
    'buyucu': ('Büyücü - Alacakaranlık', 'buyucu', (12, 2, 36, 26), v3.buyucu_alacakaranlik, (150, 124, 176, 255)),
    'assasin': ('Assasin - Ay Kesiği', 'assasin', (12, 2, 36, 26), assasin, None),
    'sovalye': ('Şovalye - Kale Duvarı', 'sovalye', (12, 6, 36, 30), sovalye, None),
    'elara': ('Elara - Çam Ormanı', 'elara', (12, 6, 36, 30), elara, None),
    'korsan': ('Korsan - Deniz', 'korsan', (13, 5, 37, 29), korsan, None),
    'melek': ('Melek - Gök', 'melek', (12, 1, 36, 25), v2.gok, None),
    'necromancer': ('Necro - Mezarlık', 'necromancer', (12, 4, 36, 28), necromancer, LIGHT_GREEN),
    'shaman': ('Shaman - Gün Batımı', 'shaman', (12, 3, 36, 27), v2.gun_batimi, None),
    'vampir': ('Vampir - Dolunay', 'vampir', (12, 6, 36, 30), v2.dolunay, (150, 124, 176, 255)),
    'hadime': ('Hadime - Lanet Sayfası', 'hadime', (12, 6, 36, 30), hadime, None),
    'cadi': ('Cadı - Bataklık', 'cadi', (12, 5, 36, 29), cadi, LIGHT_GREEN),
    'simdi': ('ŞU AN (Hadime çayır)', 'hadime', (12, 6, 36, 30), None, None),
}


def grid(arts, cols=5):
    keys = list(PROTOS)
    cell, gap, pad, title_h, strip_h = 256, 24, 24, 38, 56
    rows = (len(keys) + cols - 1) // cols
    ch = title_h + cell + 8 + strip_h
    bar_s = 32
    W = pad * 2 + cols * cell + (cols - 1) * gap
    H = pad + rows * (ch + gap) + 40 + 2 * (bar_s + 16) + pad
    sheet = Image.new('RGBA', (W, H), (52, 38, 28, 255))
    d = ImageDraw.Draw(sheet)
    f = v1._font(32)
    for i, k in enumerate(keys):
        x = pad + (i % cols) * (cell + gap)
        y = pad + (i // cols) * (ch + gap)
        d.text((x, y), PROTOS[k][0], font=f, fill=(240, 222, 186, 255))
        sheet.alpha_composite(gai.at_size(arts[k], 256), (x, y + title_h))
        sy = y + title_h + cell + 8
        d.rectangle((x, sy, x + cell - 1, sy + strip_h - 1), fill=(32, 32, 32, 255))
        sx = x + 8
        for s in (48, 32, 24, 16):
            sheet.alpha_composite(gai.at_size(arts[k], s), (sx, sy + (strip_h - s) // 2))
            sx += s + 14
    # hepsi yan yana görev çubuğunda (32 px): koyu + açık
    y = pad + rows * (ch + gap)
    d.text((pad, y), 'Görev çubuğunda yan yana (32 px)', font=f, fill=(240, 222, 186, 255))
    for r, bg in enumerate(((32, 32, 32, 255), (238, 238, 238, 255))):
        by = y + 40 + r * (bar_s + 16)
        d.rectangle((pad, by, W - pad - 1, by + bar_s + 15), fill=bg)
        for i, k in enumerate(keys):
            sheet.alpha_composite(gai.at_size(arts[k], bar_s), (pad + 12 + i * (bar_s + 20), by + 8))
    return sheet


def main():
    os.makedirs(v1.OUT, exist_ok=True)
    arts = {}
    for k, (_, portrait, bust, paint, light) in PROTOS.items():
        gai.PORTRAIT = os.path.join(ROOT, 'assets', 'characters', portrait + '_portrait.png')
        gai.BUST = bust
        if paint is None:
            arts[k] = gai.art('cayir')
            continue
        gai.VARIANTS['v5_' + k] = (paint, light)
        arts[k] = gai.art('v5_' + k)
        gai.at_size(arts[k], 256).save(os.path.join(v1.OUT, f'ikon_v5_{k}.png'))
    out = os.path.join(v1.OUT, 'ozet_v5.png')
    grid(arts).save(out)
    print(out)


if __name__ == '__main__':
    main()
