# -*- coding: utf-8 -*-
"""YAY ÇEKİŞ KARELERİ (madde 413, 2026-11-06): kullanıcının yay çiziminden (assets/weapons/yeni/yay.png, masaüstü bow1.png, 32x32)
5 karelik "draw" animasyonu üretir -> assets/weapons/yeni/yay_d1..d5.png (aynı 32x32 tuval, aynı piksel ızgarası).

Çizim çapraz: kollar sağ-üst + sol-alt uçta, gövde (deri kabza) sağ-altta, ip sol-üstte x+y=28 köşegeni üzerinde siyah 1 px çizgi.
Ok sağ-alta uçar (weapon_tier_art.gd FORWARD["yay"] = +45).
- Kollar/kabza DEĞİŞMEZ (kullanıcının pikselleri); yalnız ip uçlardaki bağlantı pikselleri (24,4) / (4,24) arasında silinir ve iki düz
  çizgiyle geri çekilen "çentik" noktasına bağlanır. Kare 1 = çizimin kendisi (ip düz) + ipte duran ok.
- Ok karenin İÇİNDE (eski ayrı HeldArrow sprite'ı kullanılmaz; Zanaatkâr yayıyla aynı karar): köşegen 1 px gövde + siyah dış hat (yayın
  kollarıyla aynı dil), uçta çelik ok başı, çentikte beyaz/kırmızı tüy (uçan okun ok_govde.png renkleri). Ok yayın ALTINDA çizilir: kabzanın
  arkasından geçer, ucu gövdenin önünden çıkar.
- Geri çekiş adımları eski draw kareleriyle aynı oranda (held_arrow_offsets 0/12/24/38/58 -> 0/1/2/3/5 köşegen adım).
Çalıştırma: python tools/gen_yay_cekis.py [--onizleme <klasör>]
"""
import sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/weapons/yeni/yay.png"
OUT = ROOT / "assets/weapons/yeni"

STRING_SUM = 28            ## ip köşegeni: x + y = 28
STRING_ENDS = ((24, 4), (4, 24))  ## ipin kollara bağlandığı son pikseller (kalır)
NOCK0 = 14                 ## düz ipin ortası (14,14)
PULLS = (0, 1, 2, 3, 5)    ## kare başına çentiğin sol-üste köşegen adımı (kollar esnemediği için en çok 5)
ARROW_LEN = 16             ## çentikten ok ucuna köşegen adım

BLACK = (0, 0, 0, 255)
SHAFT = (147, 103, 63, 255)       ## ok_govde.png gövde
HEAD = (145, 141, 140, 255)       ## ok_govde.png ok başı açık
HEAD_DK = (54, 54, 60, 255)       ## ok başı koyu
FLETCH_A = (216, 208, 188, 255)   ## tüy açık
FLETCH_B = (162, 60, 50, 255)     ## tüy kırmızı


def line(x0, y0, x1, y1):
    pts = []
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        pts.append((x0, y0))
        if x0 == x1 and y0 == y1:
            return pts
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def arrow_layer(size, nock):
    """Çentik (nock,nock) -> uç (nock+L, nock+L) köşegen ok, ayrı katman."""
    lay = Image.new("RGBA", size, (0, 0, 0, 0))
    px = lay.load()
    w, h = size

    def put(x, y, c):
        if 0 <= x < w and 0 <= y < h:
            px[x, y] = c

    tip = nock + ARROW_LEN
    ## önce dış hat (gövdenin iki yanı), sonra çekirdek
    for i in range(nock, tip + 1):
        put(i + 1, i, BLACK)
        put(i, i + 1, BLACK)
    for i in range(nock, tip + 1):
        put(i, i, SHAFT)
    ## tüy: çentikten sonraki 3 adımın yanları
    for j, i in enumerate(range(nock + 1, nock + 4)):
        put(i + 1, i, FLETCH_A if j % 2 == 0 else FLETCH_B)
        put(i, i + 1, FLETCH_B if j % 2 == 0 else FLETCH_A)
    ## ok başı: son 3 adım çelik, yanlara taşan kanatçık + siyah uç hattı
    for i in range(tip - 2, tip + 1):
        put(i, i, HEAD)
    put(tip - 1, tip - 3 + 1, HEAD_DK)
    put(tip - 3 + 1, tip - 1, HEAD_DK)
    put(tip, tip - 2, BLACK)
    put(tip - 2, tip, BLACK)
    put(tip + 1, tip, BLACK)
    put(tip, tip + 1, BLACK)
    put(tip + 1, tip + 1, BLACK)
    return lay


def bow_without_string(src):
    im = src.copy()
    px = im.load()
    (ax, ay), (bx, by) = STRING_ENDS
    for x in range(bx + 1, ax):
        y = STRING_SUM - x
        if px[x, y][3] > 0 and px[x, y][:3] == (0, 0, 0):
            px[x, y] = (0, 0, 0, 0)
    return im


def make_frame(src, pull):
    nock = NOCK0 - pull
    bow = bow_without_string(src)
    px = bow.load()
    for end in STRING_ENDS:
        for (x, y) in line(end[0], end[1], nock, nock):
            px[x, y] = BLACK
    frame = arrow_layer(src.size, nock)
    frame.alpha_composite(bow)  ## yay okun ÜSTÜNDE: ok kabzanın arkasından geçer
    return frame


def main():
    src = Image.open(SRC).convert("RGBA")
    frames = [make_frame(src, p) for p in PULLS]
    for i, fr in enumerate(frames, 1):
        fr.save(OUT / ("yay_d%d.png" % i))
        print("yazıldı", OUT / ("yay_d%d.png" % i))
    if "--onizleme" in sys.argv:
        d = Path(sys.argv[sys.argv.index("--onizleme") + 1])
        k = 10
        sheet = Image.new("RGBA", ((32 * k + 8) * (len(frames) + 1), 32 * k), (58, 92, 58, 255))
        sheet.alpha_composite(src.resize((32 * k, 32 * k), Image.NEAREST), (0, 0))
        for i, fr in enumerate(frames, 1):
            sheet.alpha_composite(fr.resize((32 * k, 32 * k), Image.NEAREST), ((32 * k + 8) * i, 0))
        sheet.save(d / "yay_cekis_onizleme.png")
        print("önizleme", d / "yay_cekis_onizleme.png")


if __name__ == "__main__":
    main()
