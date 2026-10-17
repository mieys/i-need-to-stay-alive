"""Su maskesinden kıyıya uzaklık dokusu (2026-10-17, su shader prototipleri, oyuna bağlı DEĞİL).

Girdi : out/su_maske.png (L8, 2 dünya px/teksel, 0..252 = görünen su kaplaması) + out/su_maske.json
Çıktı : out/su_mesafe.png  R = kıyıya uzaklık (dünya px) / 64, G = kaplama (0..1), B = 0
        out/su_akis.png    RG = akış vektörü (0,5 + 0,5 * v; |v| = 0..1 hız oranı) - prototip F (2. set)
Akış: yumuşatılmış uzaklığın gradyanına dik (kıyıya paralel), işaret dere genel yönüne (batı -> kuzeydoğu, REF) göre seçilir
(kanalın iki yarısında gradyan zıt -> dik vektör de zıt olurdu), sonra bulanıklaştırılıp hız = kanal ortasında 1, kıyıda 0.
Uzaklık: 8 komşulu chamfer (1 / 1.4142), suyun dışı 0. Doğrusal süzgeçle örneklenince kıyı çizgisi ~1 dünya px'te.
Çalıştır: python tools/proto_20261017/su_shader/su_mesafe.py
"""
import json
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
TEXEL = 2.0
MAX_PX = 64.0


def chamfer(water: np.ndarray, iters: int) -> np.ndarray:
    big = 1e6
    d = np.where(water, big, 0.0).astype(np.float32)
    s2 = np.float32(np.sqrt(2.0))
    for _ in range(iters):
        p = np.pad(d, 1, mode="constant", constant_values=0.0)
        h, w = d.shape
        cand = [
            p[0:h, 1:w + 1] + 1, p[2:h + 2, 1:w + 1] + 1, p[1:h + 1, 0:w] + 1, p[1:h + 1, 2:w + 2] + 1,
            p[0:h, 0:w] + s2, p[0:h, 2:w + 2] + s2, p[2:h + 2, 0:w] + s2, p[2:h + 2, 2:w + 2] + s2,
        ]
        nd = d
        for c in cand:
            nd = np.minimum(nd, c)
        if np.array_equal(nd, d):
            break
        d = nd
    return d


REF = np.array([1.0, -0.5]) / np.hypot(1.0, 0.5)  # derenin genel akış yönü (x sağ, y aşağı)


def box(a: np.ndarray, r: int) -> np.ndarray:
    """(2r+1)^2 kutu bulanıklığı (kümülatif toplam, kenar sıfır)."""
    p = np.pad(a, r + 1)
    c = np.cumsum(np.cumsum(p, 0), 1)
    k = 2 * r + 1
    out = c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]
    return out[: a.shape[0], : a.shape[1]] / (k * k)


def flow(water: np.ndarray, d_px: np.ndarray) -> np.ndarray:
    ds = box(d_px.astype(np.float64), 3)
    gy, gx = np.gradient(ds)
    tx, ty = -gy, gx
    n = np.hypot(tx, ty) + 1e-9
    tx, ty = tx / n, ty / n
    sg = np.where(tx * REF[0] + ty * REF[1] < 0, -1.0, 1.0)
    tx, ty = tx * sg, ty * sg
    w = water.astype(np.float64)
    bx, by, bw = box(tx * w, 6), box(ty * w, 6), box(w, 6) + 1e-9
    fx, fy = bx / bw, by / bw
    n = np.hypot(fx, fy) + 1e-9
    fx, fy = fx / n, fy / n
    mag = np.clip(d_px / 14.0, 0, 1) ** 0.7 * (1.0 - np.clip((d_px - 30.0) / 20.0, 0, 1) * 0.7)
    mag = np.where(water, mag, 0.0)
    r = np.round((0.5 + 0.5 * fx * mag) * 255).astype(np.uint8)
    g = np.round((0.5 + 0.5 * fy * mag) * 255).astype(np.uint8)
    return np.dstack([r, g, np.zeros_like(r)])


def main() -> None:
    info = json.load(open(os.path.join(OUT, "su_maske.json"), encoding="utf-8"))
    cov = np.asarray(Image.open(os.path.join(OUT, "su_maske.png")).convert("L"), dtype=np.float32) / 252.0
    water = cov >= 0.5
    d_tex = chamfer(water, int(MAX_PX / TEXEL) + 2)
    d_px = np.clip(d_tex * TEXEL, 0, MAX_PX)
    r = np.round(d_px / MAX_PX * 255).astype(np.uint8)
    g = np.round(np.clip(cov, 0, 1) * 255).astype(np.uint8)
    rgb = np.dstack([r, g, np.zeros_like(r)])
    Image.fromarray(rgb, "RGB").save(os.path.join(OUT, "su_mesafe.png"))

    print("mesafe", rgb.shape, "maks", float(d_px.max()))
    Image.fromarray(flow(water, d_px), "RGB").save(os.path.join(OUT, "su_akis.png"))
    print("akis yazildi")


if __name__ == "__main__":
    main()
