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


def save(a, name):
    a.save(out(name), scale=S3)


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


def tier_card(t, w=100, h=160):
    """Level atlama / sandık ödül kartı (300x480 px = 100x160 sanat px, bkz. level_up_screen.tscn Card*/Frame):
    dış ahşap çerçeve + TİER renginde emaye bant + parşömen iç (üst başlık bölgesi tier rengiyle hafif boyalı),
    üstte tier taşı, altta küçük taş, yanlarda çivi. Tier 3-4'te taşların yanında altın kıvrımlar. İç alan düz parşömen."""
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


def tier_slot(t, w=32, h=32):
    """Tier ikon slotu (satıcı mini kartı / envanter hücresi, genelde 96 px = 32x32 sanat px): tier renginde çerçeve +
    çukur bej iç (ikon üstüne çizilir). Tier 2-4 köşelerde küçük taş, tier 4 altın."""
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
