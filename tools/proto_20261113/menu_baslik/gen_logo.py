"""Ana menü POTPOURRI piksel logosu (2026-11-13). Yapay zekâ YOK: harfler aşağıda elle çizilmiş piksel ızgaraları,
renkler hud_theme.gd paletinden. Çıktı sanat çözünürlüğünde (1 px = 1 sanat pikseli), oyunda NEAREST x6 gösterilir
(eski m5x7 96 başlığının piksel yoğunluğu = 6 ekran px).

python tools/proto_20261113/menu_baslik/gen_logo.py [cikti_klasoru]
python tools/proto_20261113/menu_baslik/gen_logo.py --oyun   -> assets/ui/ana_menu/logo_potpourri.png (oyundaki logo = logo_petal, kuru çiçek)
"""
import sys
from pathlib import Path
from PIL import Image

# --- palet (scripts/hud_theme.gd) ---
def hx(s):
    s = s.lstrip('#')
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)

DEEP = hx('140e09')
OUTLINE = hx('20150d')
WIN_LINE = hx('4b3320')
ACCENT_DK = hx('6a4416')
SPOT = hx('c0803a')
ACCENT = hx('f0c070')
PRICE = hx('f6d27e')
TEXT = hx('f3e6cc')

# --- harfler: 11 satır, 2 px vuruş ---
G = {
    'P': ["#######.",
          "########",
          "##....##",
          "##....##",
          "########",
          "#######.",
          "##......",
          "##......",
          "##......",
          "##......",
          "##......"],
    'O': [".######.",
          "########",
          "##....##",
          "##....##",
          "##....##",
          "##....##",
          "##....##",
          "##....##",
          "##....##",
          "########",
          ".######."],
    'T': ["########",
          "########"] + ["...##..."] * 9,
    'U': ["##....##"] * 9 + ["########", ".######."],
    'R': ["#######.",
          "########",
          "##....##",
          "##....##",
          "########",
          "#######.",
          "##.##...",
          "##..##..",
          "##...##.",
          "##....##",
          "##....##"],
    'I': ["##"] * 11,
}
H = 11
GAP = 2
EXTRUDE = 2
PAD = 1  # dış hat


def word_mask(word):
    cols = []
    xs = []
    x = 0
    for i, ch in enumerate(word):
        g = G[ch]
        xs.append(x)
        x += len(g[0]) + (GAP if i < len(word) - 1 else 0)
    w = x
    m = [[0] * w for _ in range(H)]
    owner = [[-1] * w for _ in range(H)]
    for i, ch in enumerate(word):
        g = G[ch]
        for r in range(H):
            for c, v in enumerate(g[r]):
                if v == '#':
                    m[r][xs[i] + c] = 1
                    owner[r][xs[i] + c] = i
    return m, owner, w


def face_bands(base_hi, base, base_lo):
    """satır -> renk: üst 2 satır açık, orta, alt 3 satır koyu."""
    out = []
    for r in range(H):
        if r <= 1:
            out.append(base_hi)
        elif r <= 7:
            out.append(base)
        else:
            out.append(base_lo)
    return out


def render(word, letter_bands, hilite, ext_cols, outline=OUTLINE, bounce=None):
    m, owner, w = word_mask(word)
    bounce = bounce or [0] * len(word)
    top = PAD + max(0, -min(bounce))
    W = w + PAD * 2
    Hh = H + EXTRUDE + PAD * 2 + (max(bounce) - min(bounce))
    img = Image.new('RGBA', (W, Hh), (0, 0, 0, 0))
    face = {}
    for r in range(H):
        for c in range(w):
            if m[r][c]:
                i = owner[r][c]
                y = r + top + bounce[i]
                x = c + PAD
                bands = letter_bands[i % len(letter_bands)]
                col = bands[r]
                # üst kenar parlaması yalnız dış üst kenarda (harf içi boşlukların alt kenarı yanmaz, v1'de O/U içi çizgi gibi duruyordu)
                if r == 0:
                    col = hilite[i % len(hilite)]
                face[(x, y)] = col
    solid = set(face)
    ext = {}
    for (x, y) in face:
        for d in range(1, EXTRUDE + 1):
            p = (x, y + d)
            if p not in solid and p not in ext:
                ext[p] = ext_cols[d - 1]
    solid |= set(ext)
    for p, col in ext.items():
        img.putpixel(p, col)
    for p, col in face.items():
        img.putpixel(p, col)
    for (x, y) in list(solid):
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                q = (x + dx, y + dy)
                if q not in solid and 0 <= q[0] < W and 0 <= q[1] < Hh:
                    if img.getpixel(q)[3] == 0:
                        img.putpixel(q, outline)
    return img


def main():
    word = 'POTPOURRI'
    gold = face_bands(PRICE, ACCENT, SPOT)
    img = render(word, [gold], [TEXT], [ACCENT_DK, WIN_LINE])
    # "kuru çiçek" (potpourri = kurutulmuş taç yaprağı karışımı): harf başına sönük taç yaprağı tonu + hafif zıplama.
    # OYUNDAKİ LOGO BU (kullanıcı seçimi 2026-11-13: "alternatif B kuru çiçek renkleri", madde 660).
    rose = face_bands(hx('e8a493'), hx('d48474'), hx('a85e55'))
    sage = face_bands(hx('c9d79a'), hx('a9bb78'), hx('7f9156'))
    lav = face_bands(hx('cdb7dc'), hx('a993c2'), hx('7d6a98'))
    gld = gold
    img2 = render(word, [rose, gld, sage, lav, gld, rose, lav, sage, gld],
                  [hx('f6d0c4'), TEXT, hx('e4ecc4'), hx('e6daee'), TEXT, hx('f6d0c4'), hx('e6daee'), hx('e4ecc4'), TEXT],
                  [ACCENT_DK, WIN_LINE], bounce=[0, -1, 0, 1, 0, -1, 0, 1, 0])
    if len(sys.argv) > 1 and sys.argv[1] == '--oyun':
        # Oyundaki doku ZIPLAMASIZ (84x15): harfleri scripts/potpourri_logo.gd sütun dilimleriyle ayrı ayrı oynatır (dalga).
        # Dilimler LETTER_W/GAP/PAD sabitlerine bağlı - harf/aralık değişirse potpourri_logo.gd'yi de güncelle.
        game = render(word, [rose, gld, sage, lav, gld, rose, lav, sage, gld],
                      [hx('f6d0c4'), TEXT, hx('e4ecc4'), hx('e6daee'), TEXT, hx('f6d0c4'), hx('e6daee'), hx('e4ecc4'), TEXT],
                      [ACCENT_DK, WIN_LINE])
        dst = Path(__file__).resolve().parents[3] / 'assets' / 'ui' / 'ana_menu' / 'logo_potpourri.png'
        game.save(dst)
        print('oyun logosu (kuru cicek, zıplamasız)', dst, game.size, 'harf genişlikleri', [len(G[c][0]) for c in word])
        return
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).parent / 'out'
    out.mkdir(parents=True, exist_ok=True)
    img.save(out / 'logo_gold.png')
    img2.save(out / 'logo_petal.png')
    for name, im in (('logo_gold', img), ('logo_petal', img2)):
        im.resize((im.width * 6, im.height * 6), Image.NEAREST).save(out / (name + '_x6.png'))
        print(name, im.size)


if __name__ == '__main__':
    main()
