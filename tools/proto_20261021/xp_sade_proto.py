# -*- coding: utf-8 -*-
"""XP kristali SADE prototipleri (2026-10-21; oyuna bağlı DEĞİL).

Kullanıcı: "exp orblarının parıldamasını istemiyorum daha sade görünmelerini istiyorum şekillerinin korunarak".
Bugünkü kristalin (tools/gen_xp_orb_sprites.py draw_diamond) parıltı kaynakları: 3 halkalı NABIZLI hale, yıldız çakması
(kare 1-5), kayan çapraz ışık çizgisi (kare 6-10), beyaza yakın sırt pikseli + xp_orb.gd'deki 1,0-1,16 "nefes" ölçeği.
Dört yön de ŞEKLİ (dikey elmas, kademe boyu 10/10/14/14/16, 1 px dış hat), RENK SIRASINI ve paleti AYNEN korur:
  A Sakin Kristal - bugünkü 4 yüzlü gölgelendirme, tüm efektler + nefes kalkar, tamamen durağan (en az değişiklik)
  B Mat Taş       - 2 ton (sol-üst yüz açık, gerisi orta), beyaz parlama yok, durağan (en sade)
  C Yere Basan    - 3 ton (beyaz yok) + altında küçük yumuşak yer gölgesi, 1 px yavaş süzülme (gölge yükselince daralır)
  D Kısık Hale    - A gölgelendirmesi + bugünkü halenin iç 2 halkası SABİT ve kısık (nabız/yıldız/ışık çizgisi yok)

Çıktı tools/proto_20261021/out/xp_sade/:
  sheets/<P>_<renk>.png       - 32x32 kareli sayfalar (yakalama betiği yükler; P = A/B/C/D)
  xp_sade_yakin.png           - büyük çizim (x6): ŞU AN + A-D, 5 kademe
  xp_sade_oyun.gif / _oyun.png - GERÇEK oyun yakalaması (1080p, kamera 2,67, x2 büyütme), satır = yön, sağda öldürme yığını
Çalıştır: python tools/proto_20261021/xp_sade_proto.py
          powershell -ExecutionPolicy Bypass -File tools/proto_20261021/xp_sade_run.ps1 -Env "XS_X=3340;XS_Y=2015"
          python tools/proto_20261021/xp_sade_proto.py --compose
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from gen_xp_orb_sprites import TIERS, hexc  # noqa: E402  (aynı palet + boylar)

OUT = os.path.join(ROOT, "tools", "proto_20261021", "out", "xp_sade")
SHEETS = os.path.join(OUT, "sheets")
CUR_DIR = os.path.join(ROOT, "assets", "pickups", "xp_orb")
FONT = "C:/Windows/Fonts/segoeuib.ttf"  # Türkçe harfler (m5x7'de ş/ı yok)
CELL = 32

## Yön -> (kare sayısı, fps); yakalama betiği aynı tabloyu kullanır (xp_sade_capture.gd VARIANTS).
VARIANTS = {"A": (1, 1.0), "B": (1, 1.0), "C": (16, 6.0), "D": (1, 1.0)}
NAMES = {"SU AN": "ŞU AN", "A": "A  Sakin Kristal", "B": "B  Mat Taş", "C": "C  Yere Basan", "D": "D  Kısık Hale"}
TIER_TR = ["yeşil", "mavi", "mor", "altın", "kırmızı"]


def _mask(size, bob):
    cx = cy = CELL / 2.0
    w, h = size * 0.42, size * 0.66
    return [[abs(x + 0.5 - cx) / w + abs(y + 0.5 - cy - bob) / h <= 1.0 for x in range(CELL)] for y in range(CELL)], w, h


def _grow(src):
    out = [row[:] for row in src]
    for y in range(CELL):
        for x in range(CELL):
            if not src[y][x] and any(0 <= y + oy < CELL and 0 <= x + ox < CELL and src[y + oy][x + ox]
                                     for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out[y][x] = True
    return out


def _blend(img, x, y, col):
    if not (0 <= x < CELL and 0 <= y < CELL) or col[3] <= 0:
        return
    if col[3] >= 255:
        img.putpixel((x, y), col)
        return
    bg = img.getpixel((x, y))
    a, ba = col[3] / 255.0, bg[3] / 255.0
    oa = a + ba * (1 - a)
    rgb = tuple(int((col[i] * a + bg[i] * ba * (1 - a)) / oa) for i in range(3))
    img.putpixel((x, y), rgb + (int(oa * 255),))


def draw(variant, size, pal, frame, frames):
    img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    outline, dark, mid, light, hi = [hexc(c) for c in pal]
    bob = 0
    if variant == "C":
        bob = -round(0.5 + 0.5 * math.sin(frame / frames * math.tau))  # 0 / -1: yalnız YUKARI süzülür, taban yerinde
    mask, w, h = _mask(size, bob)
    cx = cy = CELL / 2.0

    if variant == "C":
        # Yer gölgesi: kristalin dibinin 1 px altında 2 satırlık yumuşak elips; yükseldikçe 1 px daralır.
        gy = int(cy + h) + 1
        half = max(2, round(w * 0.95)) - (1 if bob < 0 else 0)
        for x in range(-half, half):
            edge = abs(x + 0.5) / half
            _blend(img, int(cx) + x, gy, (12, 18, 10, int(95 * (1.0 - edge * edge))))
            if edge < 0.6:
                _blend(img, int(cx) + x, gy + 1, (12, 18, 10, int(45 * (1.0 - edge / 0.6))))

    if variant == "D":
        # Bugünkü halenin iç iki halkası, NABIZSIZ ve kısık (açık ton 120 / 40 opaklık; bugün 170-255 / 60-120 nabızlı).
        ring1 = _grow(mask)
        ring2 = _grow(ring1)
        for y in range(CELL):
            for x in range(CELL):
                if ring1[y][x] and not mask[y][x]:
                    _blend(img, x, y, (light[0], light[1], light[2], 120))
                elif ring2[y][x] and not ring1[y][x]:
                    _blend(img, x, y, (light[0], light[1], light[2], 40))

    for y in range(CELL):
        for x in range(CELL):
            if not mask[y][x]:
                continue
            edge = any(not (0 <= y + oy < CELL and 0 <= x + ox < CELL and mask[y + oy][x + ox])
                       for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if edge:
                _blend(img, x, y, outline)
                continue
            dx, dy = x + 0.5 - cx, y + 0.5 - cy - bob
            ridge = abs(dx) < 0.6 and dy < 0
            if variant == "B":
                col = light if (dy < 0 and dx < 0) else mid
            elif variant == "C":
                if ridge:
                    col = light
                elif dy < 0:
                    col = light if dx < 0 else mid
                else:
                    col = mid if dx < 0 else dark
            else:  # A / D: bugünkü yüzler, sırt üstte parlama tonu (tek piksel sütunu) - efektsiz
                if ridge:
                    col = hi if dy < -h * 0.35 else light
                elif dy < 0:
                    col = light if dx < 0 else mid
                else:
                    col = mid if dx < 0 else dark
            _blend(img, x, y, col)
    return img


def build_sheets():
    os.makedirs(SHEETS, exist_ok=True)
    for v, (frames, _fps) in VARIANTS.items():
        for name, size, pal in TIERS:
            sheet = Image.new("RGBA", (CELL * frames, CELL), (0, 0, 0, 0))
            for f in range(frames):
                sheet.paste(draw(v, size, pal, f, frames), (f * CELL, 0))
            sheet.save(os.path.join(SHEETS, f"{v}_{name}.png"))
    print("sayfalar:", SHEETS)


def build_closeup():
    """x8 yakın çizim: satır = ŞU AN (en parlak karesi) + A-D, sütun = 5 kademe; çimen tonu zemin."""
    Z = 6
    pad, lab = 10, 150
    rows = ["SU AN"] + list(VARIANTS)
    cw = CELL * Z
    img = Image.new("RGB", (lab + len(TIERS) * cw + pad, len(rows) * cw + pad * 2 + 20), (92, 116, 58))
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype(FONT, 20)
    for c in range(len(TIERS)):
        d.text((lab + c * cw + cw // 2, 14), f"{c + 1}. {TIER_TR[c]}", fill=(240, 236, 210), font=font, anchor="mm")
    for r, v in enumerate(rows):
        y0 = 24 + r * cw
        d.text((8, y0 + cw // 2), NAMES[v], fill=(240, 236, 210), font=font, anchor="lm")
        for c, (name, size, pal) in enumerate(TIERS):
            if v == "SU AN":
                sheet = Image.open(os.path.join(CUR_DIR, f"xp_orb_{name}.png")).convert("RGBA")
                tile = sheet.crop((3 * CELL, 0, 4 * CELL, CELL))  # yıldızın en büyük karesi
            else:
                tile = Image.open(os.path.join(SHEETS, f"{v}_{name}.png")).convert("RGBA").crop((0, 0, CELL, CELL))
            img.paste(tile.resize((cw, cw), Image.NEAREST), (lab + c * cw, y0), tile.resize((cw, cw), Image.NEAREST))
    img.save(os.path.join(OUT, "xp_sade_yakin.png"))
    print("yakin:", os.path.join(OUT, "xp_sade_yakin.png"))


def compose():
    """Yakalama kareleri (cap/gun_XX.png, meta.json) -> x2 büyütülmüş, sol etiket sütunlu GIF + durağan PNG."""
    import json
    cap = os.path.join(OUT, "cap")
    meta = json.load(open(os.path.join(cap, "meta.json"), encoding="utf-8"))
    Z, lab = 2, 190
    font = ImageFont.truetype(FONT, 22)
    small = ImageFont.truetype(FONT, 15)
    rows = ["SU AN"] + list(VARIANTS)
    frames = []
    i = 0
    while os.path.exists(os.path.join(cap, f"gun_{i:02d}.png")):
        shot = Image.open(os.path.join(cap, f"gun_{i:02d}.png")).convert("RGB")
        big = shot.resize((shot.width * Z, shot.height * Z), Image.NEAREST)
        img = Image.new("RGB", (lab + big.width, big.height + 30), (34, 30, 26))
        img.paste(big, (lab, 30))
        d = ImageDraw.Draw(img)
        d.text((8, 15), "Gerçek oyun (1080p, x2 büyütüldü)", fill=(200, 190, 160), font=small, anchor="lm")
        for r, v in enumerate(rows):
            d.text((10, 30 + meta["rows_y"][r] * Z), NAMES[v], fill=(240, 228, 190), font=font, anchor="lm")
        frames.append(img)
        i += 1
    frames[0].save(os.path.join(OUT, "xp_sade_oyun.png"))
    pal = frames[0].quantize(colors=255, method=Image.Quantize.MEDIANCUT)
    q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
    q[0].save(os.path.join(OUT, "xp_sade_oyun.gif"), save_all=True, append_images=q[1:], duration=100, loop=0)
    print("oyun:", os.path.join(OUT, "xp_sade_oyun.gif"), len(frames), "kare")


if __name__ == "__main__":
    if "--compose" in sys.argv:
        compose()
    else:
        build_sheets()
        build_closeup()
