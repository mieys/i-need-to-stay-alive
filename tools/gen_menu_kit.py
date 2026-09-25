"""Menü kiti (ana menü + tek/çok oyunculu karakter seçimi) -> assets/ui/menu/*.png

Çalıştır:  python tools/gen_menu_kit.py   (sonra Godot'ta `--headless --import`)

Kullanıcı isteği (2026-09-24): "ana menü, singleplayer ve multiplayer karakter menülerindeki tüm kartları ve arayüz
arkaplanlarını ... sıfırdan tasarla. pixel tarzda 48x48 pixel sanatı varyantlarında hafif cozy aşırı koyu veya açık
renkli olmayan hoş arayüzler ... tercihen bej/açık kahverengi tonlarında".

Tasarım kuralları:
  - Her sanat pikseli TAM 3 ekran pikseli (S3) - kartlardaki karakter portreleri de 3x çiziliyor (48x48 sprite'lar),
    yani çerçeve çizgileri ile karakter konturları AYNI piksel yoğunluğunda. m5x7 yazı tipi 48 px'te (3x) aynı ızgaraya
    oturur, gövde metni 32 px (2x).
  - Palet: bej parşömen iç + açık kahve ahşap çerçeve + yumuşak koyu kahve kontur (siyah yok), pirinç çiviler,
    adaçayı yeşili/kiremit vurgular. Metin koyu kahve (bej zeminde okunaklı).
  - 9-slice dokularda esneyen/karolanan orta bölgeler ya düz renk ya da karo periyoduna (12 sanat px) hizalı desen -
    MenuKit (scripts/menu_kit.gd) bunları TILE modunda çizer, hiçbir boyutta bulanıklık/bozulma olmaz.

İKİ PALET (kullanıcı isteği 2026-09-24, ikinci tur: "aynı arayüz değişikliklerini ... oyun içi tüm arayüzler için de tasarla
fakat biraz daha koyu olmalı ... tier bazlı kartların renkleri buna göre"): aynı çizim fonksiyonları iki paletle çalışır -
  menu -> assets/ui/menu (açık bej; MenuKit)          game -> assets/ui/game (bir ton koyu; UIKit, oyun içi tüm paneller)
Oyun paleti ek olarak tier kartlarını (level atlama / sandık), tier mini slotlarını (satıcı / envanter), koyu "bark" butonu,
mini butonları, eşya kartı panellerini ve başlık levhasını üretir. HUD çerçeveleri ayrı: tools/gen_ui_kit.py.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from ui_kit_lib import Art, rr_mask, depth_map, light_side, hexc, mix, lighten, darken, gray_mix, paste_mirror4  # noqa: E402

S3 = 3
OUTDIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'ui', 'menu')


def out(name):
    return os.path.join(OUTDIR, name)


# Tier savaş kartları/slotları + seçim halesi kendi paletleriyle ayrı tasarlandı (kullanıcı: "şuan yaptığın kart ve tier
# olaylarını ayrı tutarak") - arayüz koyulaştırma eğrisi (ui_kit_lib.deepen_rgb) bunlara UYGULANMAZ.
DEEPEN_EXEMPT_PREFIXES = ('tier_card_', 'tier_slot_', 'stat_', 'levelup_')   # stat_: vitrin istatistik ikonları (ikon rengi korunur)


def save(a, name):
    a.save(out(name), scale=S3, deepen=not name.startswith(DEEPEN_EXEMPT_PREFIXES))


# ------------------------------------------------------------------ palet
OUTL = hexc('#4a2c1a')      # kontur: yumuşak koyu kahve (siyah değil)
LINE = hexc('#6e4527')      # iç ayırıcı çizgi
W_HI = hexc('#ecbf86')      # ahşap: ışık
W_LT = hexc('#d29f63')
W_MD = hexc('#b3804b')
W_DK = hexc('#8f5f36')
W_DD = hexc('#6d4527')
P_HI = hexc('#f0dcb3')      # parşömen/bej
P = hexc('#e0c697')
P_SP = hexc('#d6ba89')      # benek (koyu)
P_SP2 = hexc('#e8d3a9')     # benek (açık)
P_SH = hexc('#c8aa78')      # iç gölge
IN = hexc('#d3b686')        # çukur alan (liste/metin/giriş)
IN_SH = hexc('#b99b69')
IN_HI = hexc('#e5d0a6')
IN_EDGE = hexc('#9a7a50')
GOLD_L = hexc('#ffe39a')
GOLD = hexc('#eab748')
GOLD_D = hexc('#b07a22')
GOLD_DD = hexc('#7d5212')
RUST = hexc('#b8693d')
RUST_D = hexc('#8c4b29')
RUST_L = hexc('#d48a5c')
LEAF_D = hexc('#56752f')
LEAF = hexc('#7f9f45')
LEAF_L = hexc('#a9c66a')
TRANSP = None

TILE = 12  # karo periyodu (sanat px)


# Menü paleti = yukarıdaki modül sabitleri. Oyun paleti: aynı adlar, bir ton koyu (parşömen ~%10, ahşap daha derin).
MENU_PAL = dict(OUTL=OUTL, LINE=LINE, W_HI=W_HI, W_LT=W_LT, W_MD=W_MD, W_DK=W_DK, W_DD=W_DD, P_HI=P_HI, P=P, P_SP=P_SP,
                P_SP2=P_SP2, P_SH=P_SH, IN=IN, IN_SH=IN_SH, IN_HI=IN_HI, IN_EDGE=IN_EDGE)
GAME_PAL = dict(
    OUTL=hexc('#3a2213'), LINE=hexc('#5a361d'),
    W_HI=hexc('#d8a56c'), W_LT=hexc('#b9844f'), W_MD=hexc('#976639'), W_DK=hexc('#734727'), W_DD=hexc('#55331b'),
    P_HI=hexc('#d9bd8f'), P=hexc('#c8a878'), P_SP=hexc('#bd9d6d'), P_SP2=hexc('#d1b485'), P_SH=hexc('#ae8e60'),
    IN=hexc('#b99a6b'), IN_SH=hexc('#9d7f55'), IN_HI=hexc('#cbad80'), IN_EDGE=hexc('#7f613b'),
)


def use_palette(pal, outdir):
    """Çizim fonksiyonlarının okuduğu modül sabitlerini (OUTL, W_*, P*, IN*) ve çıktı klasörünü değiştirir."""
    global OUTDIR
    globals().update(pal)
    OUTDIR = outdir


def _paper(x, y):
    """Parşömen dokusu: 12x12 periyotlu seyrek benekler (karo olarak dikişsiz tekrarlanır)."""
    px, py = x % TILE, y % TILE
    if (px, py) in ((2, 3), (7, 1), (10, 6), (4, 9), (8, 10)):
        return P_SP
    if (px, py) in ((5, 5), (11, 11), (1, 8)):
        return P_SP2
    return P


def nail(a, x, y):
    a.set(x, y, GOLD_L)
    a.set(x + 1, y, GOLD)
    a.set(x, y + 1, GOLD)
    a.set(x + 1, y + 1, GOLD_D)


LEAF_SPRIG = [
    "..lL..",
    ".lLLl.",
    "lLLl..",
    ".dd...",
]
LEAF_PAL = {'l': LEAF, 'L': LEAF_L, 'd': LEAF_D}


def blit(a, x0, y0, rows, pal, flip_x=False):
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in pal:
                xx = x0 + (len(row) - 1 - x if flip_x else x)
                a.set(xx, y0 + y, pal[ch])


# ------------------------------------------------------------------ panel (pencere)
def window(w=32, h=32, radius=4):
    """Açık kahve ahşap çerçeve (4 katman) + bej parşömen iç. 9-slice payı 10 sanat px."""
    a = Art(w, h)
    d = depth_map(rr_mask(w, h, radius))
    for y in range(h):
        for x in range(w):
            dd = d[y][x]
            if dd < 0:
                continue
            lt = light_side(x, y, w, h)
            if dd == 0:
                c = OUTL
            elif dd == 1:
                c = W_HI if lt else W_DK
            elif dd == 2:
                c = W_LT if lt else W_MD
            elif dd == 3:
                c = W_MD if lt else W_DD
            elif dd == 4:
                c = LINE
            elif dd == 5:
                c = P_SH if lt else _paper(x, y)
            else:
                c = _paper(x, y)
            a.set(x, y, c)
    for (x, y) in ((2, 2),):
        nail(a, x, y)
        nail(a, w - 4, y)
        nail(a, x, h - 4)
        nail(a, w - 4, h - 4)
    return a


def inset(w=12, h=12, radius=2, focus=False):
    """Çukur bej alan (listeler, metin kutuları, giriş alanları). Pay 4 sanat px."""
    a = Art(w, h)
    d = depth_map(rr_mask(w, h, radius))
    for y in range(h):
        for x in range(w):
            dd = d[y][x]
            if dd < 0:
                continue
            lt = light_side(x, y, w, h)
            if dd == 0:
                c = GOLD_D if focus else IN_EDGE
            elif dd == 1:
                c = (GOLD if focus else IN_SH) if lt else (GOLD_L if focus else IN_HI)
            else:
                c = IN
            a.set(x, y, c)
    return a


# ------------------------------------------------------------------ kurdele (ekran başlıkları)
def banner(w=40, h=24):
    """Parşömen kurdele: bej şerit (satır 1..16) + iki yanda şeridin ARKASINDAN çıkan kiremit kuyruklar (satır 6..21,
    dış uçta V çentik) + şerit ucundan kuyruğa inen koyu katlanma üçgeni. 9-slice: yatay pay 14 (kuyruk + şerit ucu),
    dikey pay dokunun tam boyu (başlık her zaman bu yükseklikte çizilir)."""
    a = Art(w, h)
    bt, bb = 1, 16            # şerit
    tt, tb = 6, 21            # kuyruk
    band_x0 = 6               # şeridin sol dış konturu
    mid = (tt + tb) / 2.0
    half = (tb - tt) / 2.0
    for side in (0, 1):
        def X(x):
            return x if side == 0 else w - 1 - x
        for y in range(tt, tb + 1):
            n = int(round(3 * (1.0 - abs(y - mid) / half)))  # V çentik derinliği (ortada 3)
            for x in range(n, band_x0 + 4):
                if y in (tt, tb) or x == n:
                    c = OUTL
                elif y == tt + 1:
                    c = RUST_L
                elif y >= tb - 1:
                    c = RUST_D
                else:
                    c = RUST
                a.set(X(x), y, c)
        # katlanma üçgeni: şeridin alt ucundan kuyruğa
        for k in range(tb - bb):
            y = bb + 1 + k
            for x in range(band_x0, band_x0 + 4):
                if x - band_x0 <= k:
                    a.set(X(x), y, OUTL if (x == band_x0 + 3 or y == tb) else darken(RUST_D, 0.30))
    for y in range(bt, bb + 1):
        for x in range(band_x0, w - band_x0):
            if y in (bt, bb) or x in (band_x0, w - band_x0 - 1):
                c = OUTL
            elif y == bt + 1:
                c = P_HI
            elif y >= bb - 2:
                c = P_SH if y == bb - 1 else mix(P, P_SH, 0.5)
            else:
                c = P
            a.set(x, y, c)
    nail(a, band_x0 + 2, 7)
    nail(a, w - band_x0 - 4, 7)
    return a


# ------------------------------------------------------------------ butonlar
BTN_PALS = {
    'tan': dict(hi=hexc('#f5d49c'), lt=hexc('#e2b273'), md=hexc('#cd9b5c'), dk=hexc('#a9773f'), dd=hexc('#83592c')),
    'sage': dict(hi=hexc('#dbe8a4'), lt=hexc('#b9d07b'), md=hexc('#9bb55e'), dk=hexc('#7a9446'), dd=hexc('#5b7233')),
    'rose': dict(hi=hexc('#f7c3a4'), lt=hexc('#e7a07c'), md=hexc('#d3845f'), dk=hexc('#ae6444'), dd=hexc('#884a31')),
}
GAME_BTN_PALS = {
    'tan': dict(hi=hexc('#e6c088'), lt=hexc('#cf9f62'), md=hexc('#b8874f'), dk=hexc('#936436'), dd=hexc('#6e4a26')),
    'sage': dict(hi=hexc('#c9d98e'), lt=hexc('#a6bf68'), md=hexc('#88a24f'), dk=hexc('#6a843c'), dd=hexc('#4f652d')),
    'rose': dict(hi=hexc('#eab092'), lt=hexc('#d68d6a'), md=hexc('#c0704e'), dk=hexc('#9c5439'), dd=hexc('#773c27')),
    'bark': dict(hi=hexc('#b48456'), lt=hexc('#93653c'), md=hexc('#7a5130'), dk=hexc('#5f3d23'), dd=hexc('#452b18')),
}


def _btn_state(pal, state):
    p = dict(pal)
    if state == 'hover':
        p = {k: lighten(v, 0.10) for k, v in p.items()}
    elif state == 'pressed':
        p = {k: darken(v, 0.07) for k, v in p.items()}
    elif state == 'disabled':
        p = {k: lighten(gray_mix(v, 0.65), 0.12) for k, v in p.items()}
    return p


def focus_ring(w=24, h=16, radius=3):
    """Klavye/gamepad odak halkası: SADECE altın kontur + iç ışık halkası, içi şeffaf. Godot 4 "focus" stilini normal/
    hover stilinin ÜSTÜNE çizer - dolu bir doku butonun hover/pressed görünümünü örterdi."""
    a = Art(w, h)
    d = depth_map(rr_mask(w, h, radius))
    for y in range(h):
        for x in range(w):
            if d[y][x] == 0:
                a.set(x, y, GOLD_DD)
            elif d[y][x] == 1:
                a.set(x, y, GOLD_L)
    return a


def button(pal, state='normal', w=24, h=16, radius=3):
    """Kabartma buton. Üst/alt 6 satır pay (ışık pahı, yüz degradesi, taban dudağı); orta satırlar TEK renk, orta
    sütunlar TEK renk -> hangi boyuta çizilirse çizilsin bozulmaz. Basılıyken dudak 1 satıra iner (yüz aşağı çöker)."""
    p = _btn_state(pal, state)
    pressed = state == 'pressed'
    a = Art(w, h)
    d = depth_map(rr_mask(w, h, radius))
    lip = 1 if pressed else 2
    outl = GOLD_DD if state == 'focus' else (mix(OUTL, (150, 130, 110, 255), 0.35) if state == 'disabled' else OUTL)
    for y in range(h):
        for x in range(w):
            dd = d[y][x]
            if dd < 0:
                continue
            fb = h - 1 - y  # alttan uzaklık
            if dd == 0:
                c = outl
            elif fb <= lip:
                c = p['dd']
            elif fb == lip + 1:
                c = p['dk']
            elif pressed and y == 1:
                c = p['dk']
            elif y == (2 if pressed else 1):
                c = p['hi']
            elif y == (3 if pressed else 2):
                c = p['lt']
            elif y == (4 if pressed else 3):
                c = p['lt'] if (x & 1) == 0 else p['md']
            else:
                c = p['md']
            a.set(x, y, c)
    # sol iç kenar ışık, sağ iç kenar gölge
    for y in range(2, h - lip - 2):
        if d[y][1] == 1:
            a.set(1, y, p['hi'] if not pressed else p['md'])
        if d[y][w - 2] == 1:
            a.set(w - 2, y, p['dk'])
    if state == 'focus':
        for y in range(h):
            for x in range(w):
                if d[y][x] == 1 and (y < 2 or x in (1, w - 2)):
                    a.set(x, y, GOLD_L)
    return a


# ------------------------------------------------------------------ karakter kartı
CARD_W, CARD_H = 58, 70   # gövde (sanat px); dokuda +1 px parıltı payı her yanda -> 60x72 (180x216 ekran px)
CARD_WIN_TOP, CARD_WIN_BOT = 4, 49     # portre penceresi satırları
CARD_GROUND_Y = 46                     # ayakların bastığı satır (gövde koordinatı)
CARD_PLATE_TOP, CARD_PLATE_BOT = 53, 65


def _window_bg(y, top, bot):
    """Portre penceresi arka planı: yukarıdan aşağı sıcak krem -> bej, 2 satırlık dither geçişli 4 bant."""
    cols = [hexc('#eedab4'), hexc('#e5cea3'), hexc('#dcc193'), hexc('#d2b585')]
    t = (y - top) / max(1.0, (bot - top))
    idx = min(len(cols) - 1, int(t * len(cols)))
    return cols, idx


def card(state='normal'):
    W, H = CARD_W + 2, CARD_H + 2
    a = Art(W, H)
    ox, oy = 1, 1
    d = depth_map(rr_mask(CARD_W, CARD_H, 4))
    if state == 'selected':
        f_hi, f_lt, f_md, f_dk, f_line = GOLD_L, GOLD, GOLD_D, GOLD_DD, hexc('#6a4312')
        outl = hexc('#5a3710')
    elif state == 'hover':
        f_hi, f_lt, f_md, f_dk, f_line = lighten(W_HI, 0.12), lighten(W_LT, 0.12), lighten(W_MD, 0.10), W_MD, LINE
        outl = OUTL
    else:
        f_hi, f_lt, f_md, f_dk, f_line = W_HI, W_LT, W_MD, W_DK, LINE
        outl = OUTL
    bg_lift = 0.10 if state == 'hover' else (0.06 if state == 'selected' else 0.0)
    for y in range(CARD_H):
        for x in range(CARD_W):
            dd = d[y][x]
            if dd < 0:
                continue
            lt = light_side(x, y, CARD_W, CARD_H)
            if dd == 0:
                c = outl
            elif dd == 1:
                c = f_hi if lt else f_md
            elif dd == 2:
                c = f_lt if lt else f_dk
            elif dd == 3:
                c = f_line
            elif CARD_WIN_TOP <= y <= CARD_WIN_BOT:
                cols, idx = _window_bg(y, CARD_WIN_TOP, CARD_WIN_BOT)
                c = cols[idx]
                # bant geçişlerinde 1 satır dama dither
                nxt = min(len(cols) - 1, idx + 1)
                t = (y + 1 - CARD_WIN_TOP) / max(1.0, (CARD_WIN_BOT - CARD_WIN_TOP))
                if int(t * len(cols)) != idx and ((x + y) & 1) == 0:
                    c = cols[nxt]
                if bg_lift:
                    c = lighten(c, bg_lift)
                # pencerenin üst/sol iç gölgesi
                if y == CARD_WIN_TOP or x == 4:
                    c = darken(c, 0.08)
            elif y == CARD_WIN_BOT + 1 or y == CARD_PLATE_TOP - 1:
                c = f_line
            elif CARD_WIN_BOT + 1 < y < CARD_PLATE_TOP - 1:
                c = f_lt if y == CARD_WIN_BOT + 2 else f_md
            else:  # isim plakası
                if y == CARD_PLATE_TOP:
                    c = P_HI
                elif y == CARD_PLATE_BOT:
                    c = P_SH
                else:
                    c = P
                if state == 'selected':
                    c = lighten(c, 0.05)
            a.set(ox + x, oy + y, c)
    # zemin: yumuşak çimen tümseği (karakter üstünde durur)
    cx = CARD_W / 2.0
    for y in range(CARD_GROUND_Y - 3, CARD_GROUND_Y + 4):
        for x in range(4, CARD_W - 4):
            dx = (x + 0.5 - cx) / 15.0
            dy = (y + 0.5 - (CARD_GROUND_Y + 0.5)) / 3.2
            r = dx * dx + dy * dy
            if r > 1.0:
                continue
            if y <= CARD_GROUND_Y - 2:
                c = hexc('#b8c67e')
            elif r > 0.72:
                c = hexc('#8fa25a')
            else:
                c = hexc('#a2b46a')
            if bg_lift:
                c = lighten(c, bg_lift * 0.6)
            a.set(ox + x, oy + y, c)
    # çimen püskülleri (tümseğin üst kenarında, 1 texel)
    for tx in (int(cx) - 12, int(cx) - 7, int(cx) + 6, int(cx) + 11):
        a.set(ox + tx, oy + CARD_GROUND_Y - 4, hexc('#8fa25a'))
    # ayırıcı şerit uçlarında pirinç çiviler
    sep_y = CARD_WIN_BOT + 2
    nail_c = (GOLD_L, GOLD_D) if state != 'selected' else (hexc('#fff4c8'), GOLD_DD)
    a.set(ox + 1, oy + sep_y, nail_c[0])
    a.set(ox + 2, oy + sep_y, nail_c[1])
    a.set(ox + CARD_W - 3, oy + sep_y, nail_c[0])
    a.set(ox + CARD_W - 2, oy + sep_y, nail_c[1])
    # seçili: dış parıltı halkası (1 texel, konturun hemen dışı)
    if state == 'selected':
        body = {(ox + x, oy + y) for y in range(CARD_H) for x in range(CARD_W) if d[y][x] >= 0}
        for y in range(H):
            for x in range(W):
                if (x, y) in body:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    if (x + dx, y + dy) in body:
                        a.set(x, y, GOLD_L)
                        break
    return a


# ------------------------------------------------------------------ vitrin sahnesi
def stage(w=112, h=100, ground_y=None, hills=True):
    """Karakter vitrini: yuvarlak köşeli çukur pencere, sıcak gökyüzü degradesi, uzak adaçayı tepeler,
    ortada çiçekli çimen tümseği (karakter onun üstünde durur). ground_y = ayakların bastığı satır."""
    if ground_y is None:
        ground_y = h - 14
    a = Art(w, h)
    d = depth_map(rr_mask(w, h, 5))
    sky = [hexc('#f2dfb8'), hexc('#ebd3a6'), hexc('#e4c797'), hexc('#dcba88')]
    horizon = ground_y - 6
    rnd = 7
    for y in range(h):
        for x in range(w):
            dd = d[y][x]
            if dd < 0:
                continue
            lt = light_side(x, y, w, h)
            if dd == 0:
                c = OUTL
            elif dd == 1:
                c = W_LT if lt else W_DK
            elif dd == 2:
                c = LINE
            else:
                t = y / max(1.0, horizon)
                idx = min(len(sky) - 1, int(t * len(sky)))
                c = sky[idx]
                if idx + 1 < len(sky) and int((y + 1) / max(1.0, horizon) * len(sky)) != idx and ((x + y) & 1) == 0:
                    c = sky[idx + 1]
                if dd == 3 and lt:
                    c = darken(c, 0.07)
            a.set(x, y, c)
    inner = lambda x, y: 0 <= x < w and 0 <= y < h and d[y][x] >= 3  # noqa: E731
    # güneş (sağ üst, soluk)
    sx, sy, sr = w - 24, 16, 7.5
    for y in range(h):
        for x in range(w):
            if inner(x, y) and math.hypot(x + 0.5 - sx, y + 0.5 - sy) <= sr:
                a.set(x, y, hexc('#fbefd3') if math.hypot(x + 0.5 - sx, y + 0.5 - sy) < sr - 1.5 else hexc('#f7e6c2'))
    # uzak tepeler
    if hills:
        for x in range(w):
            h1 = horizon - 4 - int(5 * (0.5 + 0.5 * math.sin(x / 9.0 + 1.3)) + 3 * (0.5 + 0.5 * math.sin(x / 4.3)))
            h2 = horizon - 1 - int(3 * (0.5 + 0.5 * math.sin(x / 6.5 + 4.0)))
            for y in range(h1, horizon + 2):
                if inner(x, y):
                    a.set(x, y, hexc('#c9c796') if y > h1 else hexc('#d6d3a4'))
            for y in range(h2, horizon + 2):
                if inner(x, y):
                    a.set(x, y, hexc('#b3b67f') if y > h2 else hexc('#c2c38c'))
    # yer: çimen
    for y in range(horizon + 1, h):
        for x in range(w):
            if not inner(x, y):
                continue
            c = hexc('#9eb465') if y < horizon + 3 else hexc('#91a95b')
            if y > ground_y + 6:
                c = hexc('#86a052')
            a.set(x, y, c)
    # tümsek (karakterin durduğu yer)
    cx = w / 2.0
    for y in range(ground_y - 4, ground_y + 6):
        for x in range(w):
            if not inner(x, y):
                continue
            dx = (x + 0.5 - cx) / 22.0
            dy = (y + 0.5 - (ground_y + 0.5)) / 4.6
            r = dx * dx + dy * dy
            if r > 1.0:
                continue
            if r > 0.78 and y > ground_y:
                c = hexc('#7d9548')
            elif y <= ground_y - 3:
                c = hexc('#c3d388')
            else:
                c = hexc('#adc274')
            a.set(x, y, c)
    # çiçekler + püsküller (deterministik)
    flowers = ((12, 3, hexc('#f4f0e2')), (20, 6, hexc('#f2b6b0')), (w - 16, 4, hexc('#f7da6a')), (w - 26, 8, hexc('#f4f0e2')),
               (30, 9, hexc('#f7da6a')), (w - 38, 10, hexc('#f2b6b0')))
    for (fx, fy, fc) in flowers:
        yy = ground_y + fy
        if inner(fx, yy) and inner(fx, yy - 1):
            a.set(fx, yy, fc)
            a.set(fx, yy + 1, hexc('#6f8a40'))
    for (tx, ty) in ((8, 1), (17, 4), (26, 2), (w - 10, 2), (w - 20, 5), (w - 31, 1), (40, 11), (w - 45, 12)):
        yy = ground_y + ty
        if inner(tx, yy) and inner(tx, yy - 1):
            a.set(tx, yy, hexc('#6f8a40'))
            a.set(tx, yy - 1, hexc('#8aa650'))
    del rnd
    # köşe yaprakları
    blit(a, 3, 2, LEAF_SPRIG, LEAF_PAL)
    blit(a, w - 9, 2, LEAF_SPRIG, LEAF_PAL, flip_x=True)
    return a


# ------------------------------------------------------------------ slot / tuş / küçük parçalar
def slot(state='normal', w=12, h=12):
    """İkon çerçevesi (yetenek + ruhani yetenek ikonları). İç kısım ŞEFFAF - ikon kendi zemini ile görünür."""
    a = Art(w, h)
    d = depth_map(rr_mask(w, h, 2))
    if state == 'selected':
        hi, lo, outl = GOLD_L, GOLD_D, hexc('#5a3710')
    elif state == 'hover':
        hi, lo, outl = lighten(W_HI, 0.12), W_MD, OUTL
    else:
        hi, lo, outl = W_HI, W_DK, OUTL
    for y in range(h):
        for x in range(w):
            dd = d[y][x]
            if dd < 0 or dd >= 2:
                continue
            a.set(x, y, outl if dd == 0 else (hi if light_side(x, y, w, h) else lo))
    return a


def keycap(w=10, h=10):
    a = Art(w, h)
    d = depth_map(rr_mask(w, h, 2))
    for y in range(h):
        for x in range(w):
            dd = d[y][x]
            if dd < 0:
                continue
            fb = h - 1 - y
            if dd == 0:
                c = OUTL
            elif fb <= 2:
                c = IN_SH if fb == 1 else P_SH
            elif y == 1:
                c = hexc('#fbf1da')
            else:
                c = P_HI
            a.set(x, y, c)
    return a


def tag(color, w=8, h=8):
    """Küçük yetenek türü etiketi (ULTİ/TEMEL/PASİF) zemini."""
    a = Art(w, h)
    d = depth_map(rr_mask(w, h, 2))
    for y in range(h):
        for x in range(w):
            dd = d[y][x]
            if dd < 0:
                continue
            a.set(x, y, darken(color, 0.45) if dd == 0 else (lighten(color, 0.18) if y == 1 else color))
    return a


def rope(w=4, h=6):
    """Dikey karolanan örgü ip (ana menü tabelası askısı)."""
    a = Art(w, h)
    c_hi, c_md, c_dk = hexc('#dcc08a'), hexc('#b8955c'), hexc('#7e6035')
    for y in range(h):
        for x in range(w):
            if x in (0, w - 1):
                c = c_dk
            else:
                c = c_hi if ((x + y) % 3 == 0) else (c_md if (x + y) % 3 == 1 else mix(c_md, c_dk, 0.5))
            a.set(x, y, c)
    return a


def sign(w=52, h=62):
    """Ana menü başlık tabelası: 3 yatay tahta, damar çizgileri (12 px periyot), uçlarda pirinç çiviler, köşelerde
    yaprak sarmaşığı. Dokunun 2 px şeffaf payı yaprakların dışa taşabilmesi için. 9-slice: yatay pay 14 -> orta karo 24
    sütun = damar periyodunun (12) tam 2 katı, dikişsiz; dikeyde tabela hep dokunun kendi boyunda (62) çizilir."""
    a = Art(w, h)
    m0 = 2
    bw, bh = w - 2 * m0, h - 2 * m0
    d = depth_map(rr_mask(bw, bh, 3))
    planks = [(1, 19), (20, 38), (39, bh - 2)]
    plank_tone = [(W_HI, W_LT, W_MD), (lighten(W_HI, 0.04), lighten(W_LT, 0.05), W_MD), (W_HI, W_LT, W_MD)]
    for y in range(bh):
        for x in range(bw):
            dd = d[y][x]
            if dd < 0:
                continue
            if dd == 0:
                c = OUTL
            else:
                c = None
                for i, (t0, t1) in enumerate(planks):
                    if t0 <= y <= t1:
                        hi, lt, md = plank_tone[i]
                        if y == t0:
                            c = hi
                        elif y == t1:
                            c = W_DK
                        elif y == t1 - 1:
                            c = md
                        else:
                            c = lt
                            ph = x % TILE
                            ry = y - t0
                            if ry == 5 and 2 <= ph <= 6:
                                c = mix(lt, W_DK, 0.35)
                            elif ry == 10 and 7 <= ph <= 10:
                                c = mix(lt, W_DK, 0.30)
                            elif ry == 14 and (ph <= 2 or ph == 11):
                                c = mix(lt, W_HI, 0.45)
                        break
                if c is None:
                    c = W_DD  # tahta arası derz
            a.set(m0 + x, m0 + y, c)
    # sol/sağ iç kenar gölgesi
    for y in range(1, bh - 1):
        if d[y][1] == 1:
            a.set(m0 + 1, m0 + y, W_HI)
        if d[y][bw - 2] == 1:
            a.set(m0 + bw - 2, m0 + y, W_DK)
    # tahta uçlarında çiviler
    for (t0, t1) in planks:
        cy = (t0 + t1) // 2
        nail(a, m0 + 4, m0 + cy - 1)
        nail(a, m0 + bw - 6, m0 + cy - 1)
    # yaprak sarmaşıkları (sol üst + sağ alt)
    blit(a, 0, 0, LEAF_SPRIG, LEAF_PAL)
    blit(a, 5, 1, ["lL", "Ll"], LEAF_PAL)
    blit(a, w - 7, h - 5, LEAF_SPRIG, LEAF_PAL, flip_x=True)
    return a


# ------------------------------------------------------------------ ayar kontrolleri
def slider_track(fill=False, w=8, h=6):
    a = Art(w, h)
    d = depth_map(rr_mask(w, h, 2))
    for y in range(h):
        for x in range(w):
            dd = d[y][x]
            if dd < 0:
                continue
            if dd == 0:
                c = IN_EDGE if not fill else hexc('#5b7233')
            elif fill:
                c = hexc('#b9d07b') if y == 1 else hexc('#9bb55e')
            else:
                c = IN_SH if y == 1 else IN
            a.set(x, y, c)
    return a


def knob(hover=False, w=7, h=10):
    a = Art(w, h)
    d = depth_map(rr_mask(w, h, 2))
    hi, lt, md, dk = (W_HI, W_LT, W_MD, W_DK)
    if hover:
        hi, lt, md, dk = lighten(hi, 0.12), lighten(lt, 0.12), lighten(md, 0.1), md
    for y in range(h):
        for x in range(w):
            dd = d[y][x]
            if dd < 0:
                continue
            if dd == 0:
                c = OUTL
            elif y == 1:
                c = hi
            elif y >= h - 3:
                c = dk
            else:
                c = lt if x < w // 2 else md
            a.set(x, y, c)
    nail(a, 2, 3)
    return a


def toggle(on, w=16, h=9):
    a = Art(w, h)
    d = depth_map(rr_mask(w, h, 4))
    for y in range(h):
        for x in range(w):
            dd = d[y][x]
            if dd < 0:
                continue
            if dd == 0:
                c = OUTL
            elif on:
                c = hexc('#b9d07b') if y <= 2 else hexc('#97b35a')
            else:
                c = IN_SH if y <= 2 else IN
            a.set(x, y, c)
    kx = w - 8 if on else 1
    kd = depth_map(rr_mask(7, 7, 3))
    for y in range(7):
        for x in range(7):
            if kd[y][x] < 0:
                continue
            c = OUTL if kd[y][x] == 0 else (W_HI if y <= 2 else (W_LT if y <= 4 else W_MD))
            a.set(kx + x, 1 + y, c)
    return a


def arrow_down(w=7, h=5):
    a = Art(w, h)
    for y in range(4):
        for x in range(y, w - y):
            a.set(x, y + 1, OUTL)
    return a


def scroll_grabber(hover=False, w=6, h=10):
    a = Art(w, h)
    d = depth_map(rr_mask(w, h, 2))
    lt, md = (W_LT, W_MD) if not hover else (lighten(W_LT, 0.12), lighten(W_MD, 0.10))
    for y in range(h):
        for x in range(w):
            dd = d[y][x]
            if dd < 0:
                continue
            a.set(x, y, OUTL if dd == 0 else (W_HI if x == 1 else (lt if x < w - 2 else md)))
    return a


# ------------------------------------------------------------------ stat ikonları (11x11)
STAT_ICONS = {
    'hp': ([
        "...........",
        ".oo...oo...",
        "oRRo.oRRo..",
        "oRhRoRRRo..",
        "oRhRRRRRo..",
        "oRRRRRRRo..",
        ".oRRRRRo...",
        "..oRRRo....",
        "...oRo.....",
        "....o......",
        "...........",
    ], {'o': OUTL, 'R': hexc('#d9544f'), 'h': hexc('#f7b0a0')}),
    'speed': ([
        "...........",
        "..ooooo....",
        "..oBBBo....",
        "..oBhBo....",
        "..oBBBo....",
        "..oBBBooo..",
        "..oBBBBBBo.",
        ".ooBBBBBBo.",
        ".oddddddddo",
        ".oooooooooo",
        "...........",
    ], {'o': OUTL, 'B': hexc('#a9773f'), 'h': hexc('#d9a86a'), 'd': hexc('#6d4527')}),
    'dmg': ([
        "........oo.",
        ".......oSo.",
        "......oSSo.",
        ".....oSSo..",
        ".o..oSSo...",
        ".oooSSo....",
        "..oGGo.....",
        "..oGoo.....",
        ".oGoo......",
        "oGo........",
        "oo.........",
    ], {'o': OUTL, 'S': hexc('#dfe3e8'), 'G': hexc('#d9a33b')}),
    'rate': ([
        ".ooooooooo.",
        ".oWWWWWWWo.",
        "..oSSSSSo..",
        "...oSSSo...",
        "....oSo....",
        "....oSo....",
        "...o.S.o...",
        "..o..S..o..",
        ".o..SSS..o.",
        ".oWWWWWWWo.",
        ".ooooooooo.",
    ], {'o': OUTL, 'W': hexc('#b3804b'), 'S': hexc('#e8c46a')}),
}


def stat_icon(key):
    rows, pal = STAT_ICONS[key]
    a = Art(11, 11)
    blit(a, 0, 0, rows, pal)
    return a


# ------------------------------------------------------------------ OYUN İÇİ: eşya kartı paneli / başlık levhası / tier kartları
def card_panel(state='normal', w=16, h=16):
    """Seyyar satıcı eşya kartı (9-slice, pay 5): ince ahşap çerçeve + parşömen iç. selected = altın çerçeve,
    sold = soluk (gri) kart."""
    a = Art(w, h)
    d = depth_map(rr_mask(w, h, 3))
    outl = OUTL
    ring = (W_HI, W_DK, W_LT, W_MD)
    if state == 'selected':
        ring = (GOLD_L, GOLD_D, GOLD, GOLD_DD)
        outl = hexc('#5a3710')
    for y in range(h):
        for x in range(w):
            dd = d[y][x]
            if dd < 0:
                continue
            lt = light_side(x, y, w, h)
            if dd == 0:
                c = outl
            elif dd == 1:
                c = ring[0] if lt else ring[1]
            elif dd == 2:
                c = ring[2] if lt else ring[3]
            elif dd == 3:
                c = LINE
            elif dd == 4 and lt:
                c = P_SH
            else:
                c = _paper(x, y)
            if state == 'sold':
                c = darken(gray_mix(c, 0.75), 0.18)
            a.set(x, y, c)
    return a


def plaque(w=20, h=14):
    """Başlık levhası (9-slice, yatay pay 6, dikey 5): ahşap kenarlı parşömen şerit, uçlarda pirinç çivi. Koyu yazı taşır."""
    a = Art(w, h)
    d = depth_map(rr_mask(w, h, 3))
    for y in range(h):
        for x in range(w):
            dd = d[y][x]
            if dd < 0:
                continue
            lt = light_side(x, y, w, h)
            if dd == 0:
                c = OUTL
            elif dd == 1:
                c = W_LT if lt else W_DK
            elif dd == 2:
                c = LINE
            elif y == 3:
                c = P_HI
            elif y >= h - 4:
                c = P_SH
            else:
                c = P
            a.set(x, y, c)
    nail(a, 3, h // 2 - 1)
    nail(a, w - 5, h // 2 - 1)
    return a


# Tier renkleri (TierSystem: 1 Sıradan / 2 Nadir / 3 Epik / 4 Efsanevi). Tier 1 = düz ahşap (çalışma anında paletten okunur).
TIER_PALS = {
    2: dict(hi=hexc('#a6c6f4'), lt=hexc('#5f8fd8'), md=hexc('#3f69b6'), dk=hexc('#2b4b8c'), dd=hexc('#1c3262')),
    3: dict(hi=hexc('#d8aef4'), lt=hexc('#a970d8'), md=hexc('#854ab8'), dk=hexc('#613290'), dd=hexc('#43216a')),
    4: dict(hi=hexc('#f8a890'), lt=hexc('#e2553e'), md=hexc('#bb352b'), dk=hexc('#88241d'), dd=hexc('#5e1712')),
}


def _tier_pal(t):
    if t == 1:
        return dict(hi=W_HI, lt=W_LT, md=W_MD, dk=W_DK, dd=W_DD)
    return TIER_PALS[t]


def _gem(a, cx, cy, r, tp, t):
    """Elmas taş (tier 2-4) ya da yuvarlak pirinç topuz (tier 1): 1 px kontur + sol-üst ışık + parıltı."""
    if t == 1:
        for y in range(cy - r - 1, cy + r + 2):
            for x in range(cx - r - 1, cx + r + 2):
                dist = math.hypot(x - cx, y - cy)
                if dist <= r + 0.6:
                    if dist > r - 0.4:
                        c = OUTL
                    elif x < cx and y < cy:
                        c = GOLD_L
                    elif dist < r - 1.2:
                        c = GOLD
                    else:
                        c = GOLD_D
                    a.set(x, y, c)
        a.set(cx - 1, cy - 1, hexc('#fff4c8'))
        return
    for y in range(cy - r - 1, cy + r + 2):
        for x in range(cx - r - 1, cx + r + 2):
            m = abs(x - cx) + abs(y - cy)
            if m > r + 1:
                continue
            if m == r + 1:
                c = OUTL
            elif x <= cx and y <= cy:
                c = tp['hi'] if m >= r - 1 else tp['lt']
            elif x >= cx and y >= cy:
                c = tp['dk'] if m >= r - 1 else tp['md']
            else:
                c = tp['lt'] if y < cy else tp['md']
            a.set(x, y, c)
    a.set(cx - 1, cy - 1, hexc('#ffffff'))
    a.set(cx - 2, cy, tp['hi'])


def tall_card(w=100, h=160):
    """Kademesiz uzun kart (silah/kalkan seçim kartları, 300x480 px): ahşap çerçeve + ahşap renkli bant + düz parşömen iç.
    Eski Sıradan tier kartının (2026-09-24) birebir aynısı - tier kartları savaş kartı tasarımına geçince (bkz. tier_card)
    serbest yerleşimli silah seçim kartları bu sade zemini korusun diye ayrıldı."""
    return _plain_tier_card(1, w, h)


def _plain_tier_card(t, w=100, h=160):
    tp = _tier_pal(t)
    a = Art(w, h)
    d = depth_map(rr_mask(w, h, 6))
    for y in range(h):
        for x in range(w):
            dd = d[y][x]
            if dd < 0:
                continue
            lt = light_side(x, y, w, h)
            if dd == 0:
                c = OUTL
            elif dd == 1:
                c = W_HI if lt else W_DK
            elif dd == 2:
                c = W_LT if lt else W_MD
            elif dd == 3:
                c = tp['hi'] if lt else tp['md']
            elif dd == 4:
                c = tp['lt'] if lt else tp['dk']
            elif dd == 5:
                c = tp['dd']
            elif dd == 6:
                c = LINE
            else:
                c = _paper(x, y)
                if dd == 7 and lt:
                    c = P_SH
            a.set(x, y, c)
    # İç alan tamamen düz parşömen: ilk sürümdeki tier renkli başlık bölgesi (mavi/mor bej ile karışıp griye dönüyordu) ve
    # sonraki başlık altı süs çizgileri kullanıcı isteğiyle kaldırıldı ("kartlar çok güzel ama çizgilerden hoşlanmadım") -
    # tier kimliği çerçevedeki emaye bant + taşlarda.
    # (İç köşe köşebentleri kullanıcı isteğiyle kaldırıldı: "iç köşelerdeki ayrıntılara da gerek yok".)
    nail(a, 2, h // 2 - 1)
    nail(a, w - 4, h // 2 - 1)
    cx = w // 2
    if t >= 3:
        for dx in range(6, 12):
            yy = 4 if dx < 9 else 5
            a.set(cx - dx, yy, GOLD if dx % 3 else GOLD_L)
            a.set(cx + dx - 1, yy, GOLD if dx % 3 else GOLD_L)
    if t == 4:
        for dx in range(6, 12):
            yy = h - 5 if dx < 9 else h - 6
            a.set(cx - dx, yy, GOLD)
            a.set(cx + dx - 1, yy, GOLD)
    _gem(a, cx, 4, 4, tp, t)
    _gem(a, cx, h - 5, 2, tp, t)
    return a


def slot_cell(w=32, h=32):
    """Kademesiz ikon hücresi (envanter yuvaları, 96 px): ahşap çerçeve + çukur bej iç. Eski Sıradan tier slotunun
    (2026-09-24) birebir aynısı - tier slotları tamamen tier rengine geçince (bkz. tier_slot) envanter bu sade hücreyi korur."""
    return _plain_tier_slot(1, w, h)


def _plain_tier_slot(t, w=32, h=32):
    tp = _tier_pal(t)
    a = Art(w, h)
    d = depth_map(rr_mask(w, h, 4))
    for y in range(h):
        for x in range(w):
            dd = d[y][x]
            if dd < 0:
                continue
            lt = light_side(x, y, w, h)
            if dd == 0:
                c = OUTL
            elif dd == 1:
                c = tp['hi'] if lt else tp['dk']
            elif dd == 2:
                c = tp['lt'] if lt else tp['md']
            elif dd == 3:
                c = LINE
            elif dd == 4:
                c = IN_SH if lt else IN
            else:
                c = IN
            a.set(x, y, c)
    if t > 1:
        gem = (GOLD_L, GOLD_D) if t == 4 else (tp['hi'], tp['dk'])
        for (x, y, c) in ((2, 2, gem[0]), (3, 2, gem[0]), (2, 3, gem[0]), (3, 3, gem[1])):
            paste_mirror4(a, x, y, c)
    return a


# ------------------------------------------------------------------ SAVAŞ KARTLARI (level atlama / sandık ödülü / tier slotu)
# Kullanıcı isteği (2026-09-25): "level atlama kartları ve tier bazlı mini kartlar oyunla uyumlu görünüyor ancak hiç heyecan
# verici ve savaşla alakalı şeyler gibi görünmüyorlar. diğer arayüzlerle uyumlu olmasını ancak renklerinin sadece dış
# çizgilerinin değil tamamen tier'a uygun hale olacak şekilde değiştirilmesini istiyorum."
# -> Kart GÖVDESİ artık tamamen tier renginde: tier metali çerçeve + perçinler, arma arkasından yayılan ışık hüzmeleri, çapraz
#    iki kılıç üstünde pirinç çerçeveli kalkan arması (stat/eşya ikonu onun parşömen yüzüne oturur), tier adını taşıyan
#    kurdele (kitin başlık kurdelesiyle aynı biçim) ve açıklama için parşömen levha (kitin koyu "mürekkep" yazıları + stat
#    renkleri bej zeminde okunmaya devam eder - bkz. UIKit.INK). Malzemeler kitle aynı: pirinç çivi, parşömen, koyu kontur.
# Yerleşim bölgeleri (sanat px, 3 ekran px = 1 sanat px) level_up_screen.gd / chest_menu.gd'deki CARD_* sabitleriyle eşleşir:
#   kategori/tier yazısı 7..18 | arma 21..66 (ikon merkezi y=42) | kurdele 67..79 | parşömen levha 83..151
TIER_FIELD = {
    1: dict(hi=hexc('#e0ad72'), lt=hexc('#b9824c'), md=hexc('#93613a'), dk=hexc('#704627'), dd=hexc('#52321b'), deep=hexc('#3a2212')),
    2: dict(hi=hexc('#a6c6f4'), lt=hexc('#5f8fd8'), md=hexc('#3f69b6'), dk=hexc('#2b4b8c'), dd=hexc('#1c3262'), deep=hexc('#13234a')),
    3: dict(hi=hexc('#d8aef4'), lt=hexc('#a970d8'), md=hexc('#854ab8'), dk=hexc('#613290'), dd=hexc('#43216a'), deep=hexc('#2e164c')),
    4: dict(hi=hexc('#f8a890'), lt=hexc('#e2553e'), md=hexc('#bb352b'), dk=hexc('#88241d'), dd=hexc('#5e1712'), deep=hexc('#420f0c')),
}
STEEL_HI = hexc('#f2f5f7')
STEEL = hexc('#c3ccd4')
STEEL_DK = hexc('#8a96a2')
GRIP = hexc('#6d4527')
GRIP_L = hexc('#8f5f36')
CARD_CREST_CX, CARD_CREST_CY = 50, 42   # arma (ve ikon) merkezi - ışık hüzmeleri buradan yayılır
CARD_RIBBON_Y0, CARD_RIBBON_Y1 = 67, 79
CARD_PLAQUE_Y0, CARD_PLAQUE_Y1 = 83, 151
CARD_PLAQUE_X0, CARD_PLAQUE_X1 = 9, 90


def _metal(t):
    """Çerçeve metali: tier 4 altın, diğerleri tier renginin kendisi (hi/lt/md/dk)."""
    if t == 4:
        return dict(hi=GOLD_L, lt=GOLD, md=GOLD_D, dk=GOLD_DD)
    f = TIER_FIELD[t]
    return dict(hi=f['hi'], lt=f['lt'], md=f['md'], dk=f['dk'])


def _field_color(fp, x, y, cx, cy, reach, rays=16, ray_len=0.0):
    """Tier zemini: merkezde hafif aydınlık hale + kenarlara doğru koyulaşma, ray_len > 0 ise merkezden yayılan dönüşümlü
    ışık hüzmeleri (uzaklaştıkça söner). Ton geçişlerinde tek satırlık dama (kitin portre penceresindeki bant geçişiyle aynı
    teknik), başka dither yok."""
    dx, dy = x + 0.5 - cx, (y + 0.5 - cy) * 0.92
    r = math.hypot(dx, dy)
    lvl = 2.75 - r / reach
    if ray_len > 0.0 and r > 4:
        ang = math.atan2(dy, dx) / (2 * math.pi) * rays + 0.25
        if (ang - math.floor(ang)) < 0.42:
            lvl = max(lvl, 0.0) + 1.15 * max(0.0, 1.0 - r / ray_len)
    tones = [fp['deep'], fp['dd'], fp['dk'], fp['md']]
    base = int(math.floor(lvl))
    frac = lvl - base
    if frac > 0.8 and ((x + y) & 1) == 0:
        base += 1
    return tones[max(0, min(len(tones) - 1, base))]


def _sword(a, cx, cy, ux, uy, t_tip, t_guard, t_grip, t_pommel, covered):
    """Çapraz kılıç (u = kabzaya doğru birim yön). Uç, kalkan armasının arkasından sol/sağ üstte, balçak + kabza altta çıkar.
    covered(x, y) True olan pikseller (arma) çizilmez."""
    vx, vy = -uy, ux
    for y in range(a.h):
        for x in range(a.w):
            if covered(x, y):
                continue
            px, py = x + 0.5 - cx, y + 0.5 - cy
            t = px * ux + py * uy
            s = px * vx + py * vy
            c = None
            if t_tip <= t <= t_guard:
                hw = 1.7 if t > t_tip + 5 else 1.7 * max(0.0, (t - t_tip)) / 5.0
                if abs(s) <= hw:
                    c = STEEL_HI if s < -0.55 else (STEEL_DK if s > 0.55 else STEEL)
                elif abs(s) <= hw + 1.0 and t >= t_tip - 0.6:
                    c = OUTL
            elif t_guard < t <= t_guard + 2.4:
                if abs(s) <= 6.5:
                    c = GOLD_L if t < t_guard + 1.2 else GOLD_D
                elif abs(s) <= 7.5:
                    c = OUTL
            elif t_guard + 2.4 < t <= t_grip:
                if abs(s) <= 1.2:
                    c = GRIP_L if int(t) % 3 else GRIP
                elif abs(s) <= 2.2:
                    c = OUTL
            if c is None:
                pd = math.hypot(t - t_pommel, s)
                if pd <= 1.9:
                    c = GOLD if (t < t_pommel and s < 0.5) else GOLD_D
                elif pd <= 2.9:
                    c = OUTL
            if c is None and t_guard - 0.6 < t <= t_guard + 3.0 and abs(s) <= 7.5:
                c = OUTL
            if c is not None:
                a.set(x, y, c)


def _crest_mask(x, y, cx=CARD_CREST_CX, top=21, straight=47, point=66, half=19):
    """Kalkan arması silueti: düz üst (köşeleri pahlı), düz yanlar, aşağıda sivri uca kıvrılan kenarlar."""
    if y < top or y > point:
        return False
    if y <= straight:
        hw = half - (1 if y == top else 0)
    else:
        k = (y - straight) / float(point - straight)
        hw = half * (math.cos(k * math.pi / 2) ** 0.75)
    return abs(x + 0.5 - cx) <= hw


def _draw_crest(a, t):
    cx = CARD_CREST_CX
    m = [[_crest_mask(x, y) for x in range(a.w)] for y in range(a.h)]
    d = depth_map(m)
    rim = dict(hi=GOLD_L, lt=GOLD, md=GOLD_D, dk=GOLD_DD) if t > 1 else dict(hi=hexc('#f0c890'), lt=hexc('#d29a5c'), md=hexc('#a8733f'), dk=hexc('#7a4f28'))
    for y in range(a.h):
        for x in range(a.w):
            dd = d[y][x]
            if dd < 0:
                continue
            lt = x + 0.5 <= cx and y < 58 or (y < 30)
            if dd == 0:
                c = OUTL
            elif dd == 1:
                c = rim['hi'] if lt else rim['md']
            elif dd == 2:
                c = rim['lt'] if lt else rim['dk']
            elif dd == 3:
                c = LINE
            elif dd == 4:
                c = P_SH if lt else _paper(x, y)
            else:
                c = P_HI if (y < 26 and x + 0.5 < cx) else _paper(x, y)
            a.set(x, y, c)
    return m


def _draw_ribbon(a, fp, y0=CARD_RIBBON_Y0, y1=CARD_RIBBON_Y1, x0=17):
    """Tier adı kurdelesi: kitin başlık kurdelesiyle (banner) aynı yapı - ön şerit + arkadan çıkan V çentikli kuyruklar +
    katlanma üçgeni - ama tier renginde."""
    w = a.w
    tt, tb = y0 + 3, y1 + 2          # kuyruk satırları
    mid, half = (tt + tb) / 2.0, (tb - tt) / 2.0
    for side in (0, 1):
        def X(x):
            return x if side == 0 else w - 1 - x
        for y in range(tt, tb + 1):
            n = x0 - 9 + int(round(3 * (1.0 - abs(y - mid) / half)))   # V çentik
            for x in range(n, x0 + 4):
                if y in (tt, tb) or x == n:
                    c = OUTL
                elif y == tt + 1:
                    c = fp['lt']
                elif y >= tb - 1:
                    c = fp['dd']
                else:
                    c = fp['dk']
                a.set(X(x), y, c)
        for k in range(tb - y1):
            y = y1 + 1 + k
            for x in range(x0, x0 + 4):
                if x - x0 <= k:
                    a.set(X(x), y, OUTL if (x == x0 + 3 or y == tb) else fp['deep'])
    for y in range(y0, y1 + 1):
        for x in range(x0, w - x0):
            if y in (y0, y1) or x in (x0, w - x0 - 1):
                c = OUTL
            elif y == y0 + 1:
                c = fp['hi']
            elif y == y0 + 2:
                c = fp['lt']
            elif y >= y1 - 2:
                c = fp['dk'] if y == y1 - 1 else fp['md']
            else:
                c = fp['md']
            a.set(x, y, c)


def _draw_plaque(a, t, x0=CARD_PLAQUE_X0, y0=CARD_PLAQUE_Y0, x1=CARD_PLAQUE_X1, y1=CARD_PLAQUE_Y1):
    """Açıklama levhası: tier metali kenarlı parşömen (koyu mürekkep yazılar burada okunur)."""
    mt = _metal(t)
    w, h = x1 - x0 + 1, y1 - y0 + 1
    d = depth_map(rr_mask(w, h, 3))
    for y in range(h):
        for x in range(w):
            dd = d[y][x]
            if dd < 0:
                continue
            lt = light_side(x, y, w, h)
            if dd == 0:
                c = OUTL
            elif dd == 1:
                c = mt['hi'] if lt else mt['md']
            elif dd == 2:
                c = mt['lt'] if lt else mt['dk']
            elif dd == 3:
                c = LINE
            elif dd == 4 and lt:
                c = P_SH
            else:
                c = _paper(x0 + x, y0 + y)
            a.set(x0 + x, y0 + y, c)


def tier_card(t, w=100, h=160):
    """Level atlama / sandık ödülü SAVAŞ kartı (300x480 px = 100x160 sanat px, bkz. yukarıdaki bölüm notu)."""
    fp = TIER_FIELD[t]
    mt = _metal(t)
    a = Art(w, h)
    d = depth_map(rr_mask(w, h, 5))
    reach = 30.0
    for y in range(h):
        for x in range(w):
            dd = d[y][x]
            if dd < 0:
                continue
            lt = light_side(x, y, w, h)
            if dd == 0:
                c = OUTL
            elif dd == 1:
                c = mt['hi'] if lt else mt['md']
            elif dd == 2:
                c = mt['lt'] if lt else mt['dk']
            elif dd == 3:
                c = mt['md'] if lt else mt['dk']
            elif dd == 4:
                c = fp['deep']
            else:
                c = _field_color(fp, x, y, CARD_CREST_CX, CARD_CREST_CY, reach, 14, 78.0)
                if dd == 5 and lt:
                    c = fp['deep'] if c == fp['dd'] else fp['dd']   # çerçevenin iç gölgesi
            a.set(x, y, c)
    covered = lambda x, y: _crest_mask(x, y)  # noqa: E731
    k = 0.7071
    _sword(a, CARD_CREST_CX, CARD_CREST_CY, k, k, -40, 17, 25, 28, covered)
    _sword(a, CARD_CREST_CX, CARD_CREST_CY, -k, k, -40, 17, 25, 28, covered)
    _draw_crest(a, t)
    _draw_ribbon(a, fp)
    _draw_plaque(a, t)
    # perçinler: çerçevenin yanlarında (orta + köşelere yakın) - kitin pencerelerindeki pirinç çivilerle aynı
    for yy in (12, h // 2 - 1, h - 14):
        nail(a, 1, yy)
        nail(a, w - 3, yy)
    cx = w // 2
    if t >= 3:
        for dx in range(5, 11):
            yy = 2 if dx < 8 else 3
            a.set(cx - dx, yy, GOLD if dx % 3 else GOLD_L)
            a.set(cx + dx - 1, yy, GOLD if dx % 3 else GOLD_L)
    _gem(a, cx, 3, 3, _tier_pal(t), t)
    _gem(a, cx, h - 3, 2, _tier_pal(t), t)
    return a


# ------------------------------------------------------------------ LEVEL ATLAMA SATIRLARI (2026-09-25)
# Kullanıcı isteği: savaş kartı yerine prototiplerden "A2 - Liste Satırları" (survivor-like yatay satır) seçildi; "soldaki
# düz uzun çizgi olmasın, çerçeve sola simetrik hizalansın", "genişlikleri %20 azalt". Bej/ahşap YOK ("oyunun panellerine
# benzetmene gerek yok"): koyu nötr gövde + tier renkli çerçeve; Tier 1 GRİ. 268x50 sanat px (3x = 804x150), ikon yuvası
# her kenardan 6 sanat px (18 px) - sol boşluk = üst = alt. Yazılar level_up_screen.gd'de kodla (_layout_rows).
LEVELUP_TIER = {
    1: dict(hi=hexc('#cdd1d6'), lt=hexc('#9ea4ac'), md=hexc('#767d87'), dk=hexc('#565c65'), dd=hexc('#3d4249'), deep=hexc('#2a2e33')),
}
LEVELUP_ROW_W, LEVELUP_ROW_H = 268, 50
LEVELUP_BODY = hexc('#2b2a30')


def levelup_row(t, w=LEVELUP_ROW_W, h=LEVELUP_ROW_H):
    f = LEVELUP_TIER.get(t, TIER_FIELD[t])
    body = mix(LEVELUP_BODY, f['deep'], 0.35)
    a = Art(w, h)
    for y in range(h):
        for x in range(w):
            if x in (0, w - 1) or y in (0, h - 1):
                c = OUTL
            elif x in (1, w - 2) or y in (1, h - 2):
                c = f['hi'] if y == 1 else f['dk'] if y == h - 2 else f['md']
            elif x in (2, w - 3) or y in (2, h - 3):
                c = f['deep']
            else:
                c = body
            a.set(x, y, c)
    # ikon yuvası: (6,6)..(43,43) = 38x38 (114 px): kontur + açık halka + koyu tier içi
    for y in range(6, 44):
        for x in range(6, 44):
            d = min(x - 6, 43 - x, y - 6, 43 - y)
            a.set(x, y, OUTL if d == 0 else f['lt'] if d == 1 else f['dd'])
    return a


# "Yeniden Karıştır" butonu (kullanıcı seçimi: "altın kenarlı + zar"): koyu gövde + altın kenar, 10x10 sanat px 9-slice
# (payı 3 sanat px = 9 px; level_up_screen.gd _apply_reroll_button_style). Pasif (altın yetmiyor) = gri kenar.
def levelup_reroll(state='normal', w=10, h=10):
    if state == 'disabled':
        rim = dict(hi=hexc('#9ea4ac'), md=hexc('#767d87'), dk=hexc('#565c65'))
        body, deep = hexc('#26252a'), hexc('#1c1b20')
    else:
        rim = dict(hi=GOLD_L, md=GOLD, dk=GOLD_D)
        body = {'normal': hexc('#2b2a30'), 'hover': hexc('#3a3842'), 'pressed': hexc('#222127')}[state]
        deep = hexc('#281e12')
    a = Art(w, h)
    for y in range(h):
        for x in range(w):
            d = min(x, y, w - 1 - x, h - 1 - y)
            if d == 0:
                c = OUTL
            elif d == 1:
                top = rim['dk'] if state == 'pressed' else rim['hi']
                c = top if y == 1 else rim['dk'] if y == h - 2 else rim['md']
            elif d == 2:
                c = deep
            else:
                c = body
            a.set(x, y, c)
    return a


def levelup_die():
    """Buton ikonu: 11x11 sanat px zar (33 px) - krem yüz, alt satır gölge, çapraz 3 kırmızı nokta."""
    a = Art(11, 11)
    for y in range(11):
        for x in range(11):
            if x in (0, 10) or y in (0, 10):
                c = OUTL
            elif y == 9:
                c = hexc('#beb4a0')
            else:
                c = hexc('#ece6d8')
            a.set(x, y, c)
    for (x, y) in ((3, 3), (5, 5), (7, 7)):
        a.set(x, y, hexc('#a02828'))
    return a


def tier_card_glow(w=100, h=160, pad=5, radius=5):
    """Seçim parıltısı: kart silüetinin dışına taşan beyaz hale (çalışma anında tier/altın renge boyanır, ADD karışım).
    Kartın her yanından `pad` sanat px taşar -> (w+2p)x(h+2p). Halka bantları tam texel (bulanık gradyan yok)."""
    W, H = w + 2 * pad, h + 2 * pad
    a = Art(W, H)
    card = rr_mask(w, h, radius)
    inside = [[False] * W for _ in range(H)]
    for y in range(h):
        for x in range(w):
            inside[y + pad][x + pad] = card[y][x]
    # 4-komşu BFS mesafesi (kart dışı)
    dist = [[-1] * W for _ in range(H)]
    cur = [(x, y) for y in range(H) for x in range(W) if inside[y][x]]
    for (x, y) in cur:
        dist[y][x] = 0
    lvl = 0
    while cur and lvl < pad:
        nxt = []
        for (x, y) in cur:
            for ddx, ddy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + ddx, y + ddy
                if 0 <= nx < W and 0 <= ny < H and dist[ny][nx] == -1:
                    dist[ny][nx] = lvl + 1
                    nxt.append((nx, ny))
        cur = nxt
        lvl += 1
    alphas = {1: 255, 2: 190, 3: 120, 4: 64, 5: 28}
    for y in range(H):
        for x in range(W):
            dd = dist[y][x]
            if dd <= 0:
                # kartın kendi kenarına da 1 texel ince iç parıltı (çerçevenin dış konturu parlasın)
                if dd == 0 and not inside[y][x]:
                    continue
                if dd == 0:
                    edge = any(not (0 <= x + ex < W and 0 <= y + ey < H) or not inside[y + ey][x + ex]
                               for ex, ey in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                    if edge:
                        a.set(x, y, (255, 255, 255, 150))
                continue
            al = alphas.get(dd)
            if al:
                a.set(x, y, (255, 255, 255, al))
    return a


def tier_slot(t, w=32, h=32):
    """Tier mini kartı / ikon slotu (satıcı kartı, satıcı ayrıntı paneli, satıcı envanter hücresi - 96..120 px = 32x32 sanat px):
    TAMAMEN tier renginde - tier metali çerçeve + ortası aydınlık, kenarlara doğru koyulaşan tier zemini (ikon ışığın
    üstüne oturur) + köşelerde perçin. Tier 4 çerçevesi altın."""
    fp = TIER_FIELD[t]
    mt = _metal(t)
    a = Art(w, h)
    d = depth_map(rr_mask(w, h, 4))
    for y in range(h):
        for x in range(w):
            dd = d[y][x]
            if dd < 0:
                continue
            lt = light_side(x, y, w, h)
            if dd == 0:
                c = OUTL
            elif dd == 1:
                c = mt['hi'] if lt else mt['dk']
            elif dd == 2:
                c = mt['lt'] if lt else mt['md']
            elif dd == 3:
                c = fp['deep']
            else:
                c = _field_color(fp, x, y, w / 2.0, h / 2.0, 6.5)
                if dd == 4 and lt:
                    c = fp['deep'] if c == fp['dd'] else fp['dd']
            a.set(x, y, c)
    rv = (GOLD_L, GOLD_D) if t > 1 else (hexc('#f0c890'), hexc('#a8733f'))
    for (x, y, c) in ((2, 2, rv[0]), (3, 2, rv[0]), (2, 3, rv[0]), (3, 3, rv[1])):
        paste_mirror4(a, x, y, c)
    return a


def build_menu():
    use_palette(MENU_PAL, os.path.join(os.path.dirname(__file__), '..', 'assets', 'ui', 'menu'))
    build()


def build_game():
    """Oyun içi kit -> assets/ui/game (UIKit). Menüyle AYNI çizimler, koyu palet + oyuna özel parçalar."""
    use_palette(GAME_PAL, os.path.join(os.path.dirname(__file__), '..', 'assets', 'ui', 'game'))
    os.makedirs(OUTDIR, exist_ok=True)
    save(window(), 'panel.png')
    save(inset(), 'inset.png')
    save(focus_ring(12, 12, 2), 'inset_focus.png')
    save(banner(), 'banner.png')
    save(plaque(), 'plaque.png')
    for v, pal in GAME_BTN_PALS.items():
        for st in ('normal', 'hover', 'pressed', 'disabled'):
            save(button(pal, st), 'btn_%s_%s.png' % (v, st))
            save(button(pal, st, w=12, h=12, radius=2), 'btn_mini_%s_%s.png' % (v, st))
    save(focus_ring(), 'btn_focus.png')
    save(focus_ring(12, 12, 2), 'btn_mini_focus.png')
    for st in ('normal', 'selected', 'sold'):
        save(card_panel(st), 'card_%s.png' % st)
    for t in (1, 2, 3, 4):
        save(tier_card(t), 'tier_card_%d.png' % t)
        save(tier_slot(t), 'tier_slot_%d.png' % t)
    save(tier_card_glow(), 'tier_card_glow.png')
    for t in range(1, 5):
        save(levelup_row(t), 'levelup_row_%d.png' % t)
    save(tier_card_glow(LEVELUP_ROW_W, LEVELUP_ROW_H, 5, 0), 'levelup_row_glow.png')
    for st in ('normal', 'hover', 'pressed', 'disabled'):
        save(levelup_reroll(st), 'levelup_reroll_%s.png' % st)
    save(levelup_die(), 'levelup_die.png')
    save(tall_card(), 'card_tall.png')     # kademesiz silah/kalkan seçim kartı (eski sade kart)
    save(slot_cell(), 'slot_cell.png')     # kademesiz envanter hücresi (eski sade slot)
    for st in ('normal', 'hover', 'selected'):
        save(slot(st), 'slot_%s.png' % st)
    save(keycap(), 'keycap.png')
    save(tag(RUST), 'tag_ulti.png')
    save(tag(hexc('#8d7a4c')), 'tag_temel.png')
    save(tag(hexc('#6f8a40')), 'tag_pasif.png')
    save(slider_track(False), 'slider_track.png')
    save(slider_track(True), 'slider_fill.png')
    save(knob(False), 'knob.png')
    save(knob(True), 'knob_hover.png')
    save(toggle(True), 'toggle_on.png')
    save(toggle(False), 'toggle_off.png')
    save(arrow_down(), 'arrow_down.png')
    save(scroll_grabber(False), 'scroll_grab.png')
    save(scroll_grabber(True), 'scroll_grab_hover.png')
    print('game kit written to', os.path.abspath(OUTDIR))


def build():
    os.makedirs(OUTDIR, exist_ok=True)
    save(window(), 'panel.png')
    save(inset(), 'inset.png')
    save(banner(), 'banner.png')
    for v, pal in BTN_PALS.items():
        for st in ('normal', 'hover', 'pressed', 'disabled'):
            save(button(pal, st), 'btn_%s_%s.png' % (v, st))
    save(focus_ring(), 'btn_focus.png')
    save(focus_ring(12, 12, 2), 'inset_focus.png')
    for st in ('normal', 'hover', 'selected'):
        save(card(st), 'card_%s.png' % st)
    save(stage(112, 140), 'stage_big.png')  # tek oyunculu sağ sütun: 336x420, karakter 6x
    save(stage(112, 62, ground_y=50), 'stage_small.png')
    for st in ('normal', 'hover', 'selected'):
        save(slot(st), 'slot_%s.png' % st)
    save(keycap(), 'keycap.png')
    save(tag(RUST), 'tag_ulti.png')
    save(tag(hexc('#8d7a4c')), 'tag_temel.png')
    save(tag(hexc('#6f8a40')), 'tag_pasif.png')
    save(rope(), 'rope.png')
    save(sign(), 'sign.png')
    save(slider_track(False), 'slider_track.png')
    save(slider_track(True), 'slider_fill.png')
    save(knob(False), 'knob.png')
    save(knob(True), 'knob_hover.png')
    save(toggle(True), 'toggle_on.png')
    save(toggle(False), 'toggle_off.png')
    save(arrow_down(), 'arrow_down.png')
    save(scroll_grabber(False), 'scroll_grab.png')
    save(scroll_grabber(True), 'scroll_grab_hover.png')
    for k in STAT_ICONS:
        save(stat_icon(k), 'stat_%s.png' % k)
    print('menu kit written to', os.path.abspath(OUTDIR))


if __name__ == '__main__':
    build_menu()
    build_game()
