# -*- coding: utf-8 -*-
"""YUVARLAK KALKAN görünüşleri (2026-11-13, kullanıcı: eski kalkan "ai", sayfadan altın çerçeveli perçinli yuvarlak tahta kalkanı seçti;
"farklı yönlere uyması gerekiyor, halihazırda kullandığımız kalkan gibi olsun, yoksa frizbi gibi olur").

Kaynak: assets/weapons/kalkan/kaynak/yuvarlak_kalkan.png (32x32 ön görünüş, kullanıcının seçtiği çizim, DOKUNMA).
Bu betik ondan scripts/kalkan_bash_math.gd'nin beklediği 5 görünüşü türetir (VIEW_YAWS 0 / 50 / 72 / 130 / 180; sola bakanları kod
flip_h ile aynalar):
  0   ön     = çizimin kendisi
  50  / 72   = ön yüz yatayda cos(yaw) kadar daralır, sol kenarda kalınlık (altın çember yanı) görünür
  130        = arka yüz daralır, kalınlık sağda (eski görünüşlerle aynı taraf)
  180 arka   = aynalanmış, koyulaştırılmış tahta + perçin arkaları + deri kulp
Sanat pikseli 1:1 (weapon_tier_art.gd WORLD_PX x SIZE_MULT, diğer 32 px silahlarla aynı yoğunluk); 48 px hücrenin ortasına (eskisiyle
aynı merkez ~(24,25)) oturur.

Çıktılar (5 kademe dosyasına AYNI sanat - görünüş kademeyle değişmez, madde 402):
  assets/weapons/zanaat/kalkan_L<1..5>.png  ikon = ön görünüş
  assets/weapons/kalkan/views_L<1..5>.png   5 görünüş yan yana (5 x 48)
  assets/fx/kalkan/ghost_L<1..5>.png        aynı görünüşlerin düz altın-krem silüeti (hayalet kalkan)
Çalıştırma: python tools/gen_kalkan_yuvarlak.py   (halka/duvar efektleri hâlâ tools/gen_kalkan_fx.py'de; o betik artık görünüş YAZMAZ)
"""
import math
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "weapons", "kalkan", "kaynak", "yuvarlak_kalkan.png")
ART_OUT = os.path.join(ROOT, "assets", "weapons", "zanaat")
VIEW_OUT = os.path.join(ROOT, "assets", "weapons", "kalkan")
FX_OUT = os.path.join(ROOT, "assets", "fx", "kalkan")

N = 48
YAWS = [0, 50, 72, 130, 180]  # scripts/kalkan_bash_math.gd VIEW_YAWS ile aynı sıra
THICK = 3.0  # kalkanın kalınlığı (sanat px); yanda sin(yaw) kadarı görünür
CENTER = (24, 25)  # eski görünüşlerin merkezi (hücre içinde)
GHOST_RGB = (255, 236, 168)  # gen_kalkan_fx.py ile aynı

OUTLINE = (13, 9, 0, 255)
EDGE_LIGHT = (172, 133, 26, 255)  # çemberin yanı (kaynaktaki altın tonları)
EDGE_DARK = (124, 78, 0, 255)
STRAP = (88, 35, 3, 255)  # kulp derisi (kaynaktaki koyu kahve)
STRAP_HI = (124, 60, 12, 255)
STRAP_OL = (26, 3, 0, 255)
RIVET = (219, 227, 232, 255)
RIVET_SH = (169, 199, 207, 255)
RIVET_BACK = (75, 60, 10, 255)


def load_src():
    im = Image.open(SRC).convert("RGBA")
    a = np.asarray(im).copy()
    a[a[..., 3] < 128] = 0
    a[a[..., 3] >= 128, 3] = 255
    x0, y0, x1, y1 = Image.fromarray(a).getbbox()
    return a[y0:y1, x0:x1]


def back_face(face):
    """Arka yüz: perçinler arkadan koyu düğme, tahta koyulaşır ve ters çapraz (ayna), ortada deri kulp."""
    h, w = face.shape[:2]
    b = face[:, ::-1].copy()
    cy, cx = (h - 1) / 2.0, (w - 1) / 2.0
    R = min(h, w) / 2.0
    yy, xx = np.mgrid[0:h, 0:w]
    r = np.hypot(yy - cy, xx - cx)
    rgb = b[..., :3].astype(np.int32)
    opaque = b[..., 3] > 0
    stud = opaque & (rgb[..., 2] >= rgb[..., 0])  # perçinler mavimsi-gümüş / gri (altın/tahta tonlarında mavi < kırmızı)
    b[stud] = RIVET_BACK
    wood = opaque & (r < R - 4.0) & ~stud
    b[wood, :3] = (b[wood, :3].astype(np.float32) * 0.72).astype(np.uint8)
    # deri kulp: yatay şerit + uçlarda perçin
    gy = int(round(cy))
    x0, x1 = int(round(cx - R * 0.48)), int(round(cx + R * 0.48))
    for x in range(x0, x1 + 1):
        b[gy - 2, x] = STRAP_OL
        b[gy - 1, x] = STRAP_HI
        b[gy, x] = STRAP
        b[gy + 1, x] = STRAP
        b[gy + 2, x] = STRAP_OL
    for x in (x0, x1):
        b[gy - 1, x] = RIVET
        b[gy, x] = RIVET_SH
    for y in range(gy - 2, gy + 3):
        b[y, x0 - 1] = STRAP_OL
        b[y, x1 + 1] = STRAP_OL
    return b


def squeeze(face, w_new):
    h, w = face.shape[:2]
    cols = [min(w - 1, int((x + 0.5) * w / w_new)) for x in range(w_new)]
    return face[:, cols].copy()


def boundary(mask):
    p = np.pad(mask, 1)
    inner = p[1:-1, 1:-1] & p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:]
    return mask & ~inner


def view(front, back, yaw):
    if yaw == 0:
        return front.copy()
    if yaw == 180:
        return back.copy()
    c = abs(math.cos(math.radians(yaw)))
    src = front if yaw < 90 else back
    h, w = src.shape[:2]
    fw = max(3, int(round(w * c)))
    t = max(1, int(round(THICK * math.sin(math.radians(yaw)))))
    face = squeeze(src, fw)
    W = fw + t
    out = np.zeros((h, W, 4), np.uint8)
    fx = t if yaw < 90 else 0  # ön yüz sağa döner -> kalınlık solda; arka yüzde sağda
    sx = 0 if yaw < 90 else t  # kalınlık (yüzün kaydırılmış silüeti)
    fm = face[..., 3] > 0
    em = np.zeros((h, W), bool)
    em[:, sx:sx + fw] = fm
    out[em] = EDGE_DARK
    # yanın ortası açık (çember parlaması)
    for y in range(h):
        xs = np.nonzero(em[y])[0]
        if len(xs) and y < h * 0.6:
            out[y, xs[len(xs) // 2]] = EDGE_LIGHT
    face_mask = np.zeros((h, W), bool)
    face_mask[:, fx:fx + fw] = fm
    out[:, fx:fx + fw][fm] = face[fm]
    allm = em | face_mask
    out[boundary(allm)] = OUTLINE
    # ön yüzün kalınlığa bakan kenarı da çizgi (yüz ile yan ayrışsın)
    out[face_mask & boundary(face_mask)] = OUTLINE
    return out


def place(arr):
    cell = np.zeros((N, N, 4), np.uint8)
    h, w = arr.shape[:2]
    x0 = CENTER[0] - w // 2
    y0 = CENTER[1] - h // 2
    cell[y0:y0 + h, x0:x0 + w] = arr
    return Image.fromarray(cell, "RGBA")


def ghost(img):
    a = np.asarray(img).copy()
    m = a[..., 3] > 0
    a[m, 0:3] = GHOST_RGB
    a[m, 3] = 255
    return Image.fromarray(a, "RGBA")


def build():
    front = load_src()
    back = back_face(front)
    return [place(view(front, back, y)) for y in YAWS]


def main():
    views = build()
    for d in (ART_OUT, VIEW_OUT, FX_OUT):
        os.makedirs(d, exist_ok=True)
    vs = Image.new("RGBA", (N * len(YAWS), N), (0, 0, 0, 0))
    gs = Image.new("RGBA", (N * len(YAWS), N), (0, 0, 0, 0))
    for i, v in enumerate(views):
        vs.paste(v, (i * N, 0))
        gs.paste(ghost(v), (i * N, 0))
    for lv in range(1, 6):
        views[0].save(os.path.join(ART_OUT, "kalkan_L%d.png" % lv))
        vs.save(os.path.join(VIEW_OUT, "views_L%d.png" % lv))
        gs.save(os.path.join(FX_OUT, "ghost_L%d.png" % lv))
    print("yuvarlak kalkan: ikon + görünüş + hayalet yazıldı (L1-L5)", YAWS)


if __name__ == "__main__":
    main()
