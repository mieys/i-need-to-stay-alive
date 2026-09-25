"""Sovalye Adam R (Koruma Baloncugu) kubbesi -> assets/fx/paladin_dome/{loop,flash}_sheet.png + _frames.tres

Kullanici istegi (2026-09-25): "sovalye adamin kalkan baloncugunun efektini de pixel tarzda yeniden tasarlamani istiyorum
yine onceki hali gibi hasar alinca ozel efektler ve bariyer hasar aliyormus gibi hafif parildamali gorunmeli ...
spritesheete donustur ki performans kaybi yasanmasin".

Eskiden kubbe her karede bir shader'la (shaders/shield_dome.gdshader, ColorRect) ciziliyordu. Artik:
  loop  (264x264, 16 kare, 8 fps, dongu): mavi enerji kubbesi - 3 piksellik kenar (dis koyu / orta / ic acik), sol ustte
        ve sag altta cam yansimasi yaylari, kenar bandinda dither'li yari saydam dolgu, ici neredeyse bos (oyun alani
        gorunur kalsin); altigen orgu SADECE kenar bandinda soluk, kubbenin uzerinden capraz gecen bir parilti bandinin
        altinda belirginlesir (enerji akisi). Kenar parlakligi dongu boyunca hafifce nabiz atar.
  flash (264x264, 6 kare, 24 fps, tek sefer): her isabette kubbe hafifce parlar - kenar beyazlasir, kenar bandi ve orgu
        aydinlanip soner (loop'un USTUNE ayri sprite olarak oynar).
Yonlu catlak efekti (fx_shield_hit.gd, zaten sprite) aynen kalir.

Olcek: 1 sanat pikseli = 1 dunya birimi (fx_paladin_barrier.gd kok olcegi ebeveyni notrler) - kubbe yaricapi 126
(player.gd PALADIN_ULTI_ZONE_RADIUS) sanat pikseli; karakterin 1 sanat pikseli ~1.12 dunya birimi, ayni yogunluk.
Calistir: python tools/gen_paladin_dome_fx.py
"""

import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx", "paladin_dome")
RES = "res://assets/fx/paladin_dome/"

R = 126
SIZE = 264
C0 = SIZE / 2.0

PALETTES = {
    # Sovalye R: mavi enerji kubbesi
    "": ((27, 79, 156), (58, 142, 230), (124, 200, 255), (200, 236, 255)),
    # Seyyar saticinin guvenli bolgesi AYNI script'i altin renkle kullanir (traveling_merchant.gd variant = "gold")
    "gold": ((140, 86, 18), (222, 160, 46), (255, 210, 104), (255, 238, 186)),
}
DEEP, MID, LIGHT, PALE = PALETTES[""]
WHITE = (255, 255, 255)

HEX = 10.0  # altigen hucre yaricapi (sanat pikseli)


def qa(a):
    for lv in (1.0, 0.8, 0.55, 0.3):
        if a >= lv - 0.12:
            return lv
    return 0.0


def put(px, x, y, col, a):
    a = qa(a)
    if a <= 0 or not (0 <= x < SIZE and 0 <= y < SIZE):
        return
    old = px[x, y]
    if old[3] >= int(255 * a):
        return
    px[x, y] = col + (int(255 * a),)


def hex_edge_dist(x, y):
    """(x, y) noktasinin en yakin sivri-tepeli altigen kenarina uzakligi (0 = kenar ustu)."""
    # eksenel koordinatlara cevir, en yakin hucre merkezini bul, altigen mesafesi
    q = (math.sqrt(3) / 3 * x - 1.0 / 3 * y) / HEX
    r = (2.0 / 3 * y) / HEX
    s = -q - r
    rq, rr, rs = round(q), round(r), round(s)
    dq, dr, ds = abs(rq - q), abs(rr - r), abs(rs - s)
    if dq > dr and dq > ds:
        rq = -rr - rs
    elif dr > ds:
        rr = -rq - rs
    cx = HEX * math.sqrt(3) * (rq + rr / 2.0)
    cy = HEX * 1.5 * rr
    lx, ly = abs(x - cx), abs(y - cy)
    # sivri tepeli altigen: ic yaricap HEX*sqrt(3)/2
    inner = HEX * math.sqrt(3) / 2.0
    d = max(lx, (lx * 0.5 + ly * math.sqrt(3) / 2.0))
    return inner - d


def render(frame_t, flash=None):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    px = img.load()
    pulse = 0.5 + 0.5 * math.cos(2 * math.pi * frame_t)
    # capraz parilti bandi: sol usten sag alta akar (dongu boyunca bir kez)
    band_c = -R * 1.5 + frame_t * R * 3.0
    band_w = 26.0
    for y in range(SIZE):
        for x in range(SIZE):
            dx, dy = x + 0.5 - C0, y + 0.5 - C0
            d = math.hypot(dx, dy)
            if d > R + 0.5:
                continue
            ang = math.atan2(dy, dx)
            edge = R - d  # 0 = kenar
            diag = (dx + dy) / math.sqrt(2)
            band = max(0.0, 1.0 - abs(diag - band_c) / band_w) if flash is None else 0.0
            f = 0.0 if flash is None else flash
            # 1) kenar: dis koyu, orta, ic acik
            if edge < 1.0:
                put(px, x, y, WHITE if f > 0.6 else DEEP, 0.8 + 0.2 * f)
                continue
            if edge < 2.0:
                put(px, x, y, PALE if f > 0.3 else MID, 0.8 + 0.2 * max(pulse * 0.5, f))
                continue
            if edge < 3.0:
                put(px, x, y, WHITE if f > 0.3 else LIGHT, 0.55 + 0.25 * pulse + 0.4 * f)
                continue
            # 2) cam yansimalari (ic kenar boyunca)
            deg = math.degrees(ang) % 360
            if edge < 6.0 and (200 <= deg <= 250):
                put(px, x, y, WHITE if edge < 4.5 else PALE, 0.8 if 212 <= deg <= 238 else 0.55)
                continue
            if edge < 5.0 and (25 <= deg <= 50):
                put(px, x, y, PALE, 0.55)
                continue
            # 3) kenar bandinda dither'li yari saydam dolgu (kubbe hacmi)
            if edge < 16.0 and (x + y) % 2 == 0:
                a = 0.3 + (0.25 if band > 0.2 else 0.0) + 0.3 * f
                put(px, x, y, LIGHT if (band > 0.2 or f > 0.3) else MID, a * (1.0 if edge < 10.0 else 0.75))
            # 4) altigen orgu: kenar bandinda soluk, parilti bandinin altinda belirgin, flasta tamami
            he = hex_edge_dist(dx, dy)
            if he < 0.9:
                if f > 0:
                    ## "hafif parilti": orgu sadece kenar bandinda (ic 44 px) aydinlanir, icerisi bos kalir
                    if edge < 44.0:
                        put(px, x, y, PALE, (0.3 + 0.5 * f) * (1.0 - edge / 60.0))
                elif band > 0.0:
                    put(px, x, y, PALE if band > 0.5 else LIGHT, 0.3 + 0.5 * band)
                elif edge < 22.0:
                    put(px, x, y, LIGHT, 0.3)
    # 5) kenarda gezinen minik parilti (dongu)
    if flash is None:
        a = math.radians(215) + frame_t * 2 * math.pi
        sx, sy = int(C0 + (R - 2) * math.cos(a)), int(C0 + (R - 2) * math.sin(a))
        for ox, oy, col in ((0, 0, WHITE), (1, 0, PALE), (-1, 0, PALE), (0, 1, PALE), (0, -1, PALE)):
            px[sx + ox, sy + oy] = col + (255,)
    return img


def save(name, frames, anim, loop, fps):
    os.makedirs(OUT, exist_ok=True)
    sheet = Image.new("RGBA", (SIZE * len(frames), SIZE), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * SIZE, 0))
    sheet.save(os.path.join(OUT, name + "_sheet.png"), optimize=True)
    write_sprite_frames(os.path.join(OUT, name + "_frames.tres"), RES + name + "_sheet.png", SIZE, SIZE,
                        [(anim, (0, 0), len(frames), loop, fps)])


if __name__ == "__main__":
    for variant, pal in PALETTES.items():
        DEEP, MID, LIGHT, PALE = pal
        suffix = ("_" + variant) if variant else ""
        loop = [render(i / 16.0) for i in range(16)]
        save("loop" + suffix, loop, "loop", True, 8)
        # flash: sadece "ek" parlama katmani - loop'un ustune biner, kendisi kenar/orgu/dolguyu aydinlatir
        flash = [render(0.0, f) for f in (0.85, 0.7, 0.55, 0.4, 0.25, 0.1)]
        save("flash" + suffix, flash, "flash", False, 24)
