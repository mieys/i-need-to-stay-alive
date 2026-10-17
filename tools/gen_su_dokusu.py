"""Su dokuları (madde 214, 2026-10-17) - 2. ADIM: maske -> kıyıya uzaklık + akış.

tools/gen_su_dokusu.gd görünen su maskesini (L8, 2 dünya px/teksel, 0..252 = kaplama) yazar ve bu betiği çağırır:
  python tools/gen_su_dokusu.py <maske png> <çıktı klasörü (assets/map)>
Çıktı (doku alanı = scripts/water_fx.gd TEX_ORIGIN / TEX_WORLD_SIZE; oyunda scenes/su.gdshader okur):
  su_mesafe.png  L8, 2 dünya px/teksel: kıyıya uzaklık (dünya px) / 64. 8 komşulu chamfer (1 / 1,4142), suyun dışı 0; doğrusal
                 süzgeçle örneklenince kıyı çizgisi ~1 dünya px'te (shader -1 çıkarır).
  su_akis.png    RGB8, 4 dünya px/teksel: RG = 0,5 + 0,5 * akış (|akış| = hız oranı), B = dalgacık doğabilir (shader'da kıyıya >= 5 px).
                 Akış: yumuşatılmış uzaklığın gradyanına dik (kıyıya paralel); kanalın iki yarısında dik vektör zıt çıkacağından işaret
                 derenin genel yönüne (REF: batı -> kuzeydoğu) göre seçilir, sonra bulanıklaştırılır; hız kanal ortasında 1, kıyıda 0,
                 çok geniş suda (göl/deniz ortası) azalır.
Prototip: tools/proto_20261017/su_shader/su_mesafe.py (aynı hesap, 2 px akış).
"""
import os
import sys

import numpy as np
from PIL import Image

TEXEL = 2.0
MAX_PX = 64.0
REF = np.array([1.0, -0.5]) / np.hypot(1.0, 0.5)  # derenin genel akış yönü (x sağ, y aşağı)
BIRTH_MIN_PX = 6.0  # shader kıyı = R*64 - 1 -> kıyıya >= 5 px


def chamfer(water: np.ndarray, iters: int) -> np.ndarray:
    d = np.where(water, 1e6, 0.0).astype(np.float32)
    s2 = np.float32(np.sqrt(2.0))
    h, w = d.shape
    for _ in range(iters):
        p = np.pad(d, 1, mode="constant", constant_values=0.0)
        nd = d
        for c in (
            p[0:h, 1:w + 1] + 1, p[2:h + 2, 1:w + 1] + 1, p[1:h + 1, 0:w] + 1, p[1:h + 1, 2:w + 2] + 1,
            p[0:h, 0:w] + s2, p[0:h, 2:w + 2] + s2, p[2:h + 2, 0:w] + s2, p[2:h + 2, 2:w + 2] + s2,
        ):
            nd = np.minimum(nd, c)
        if np.array_equal(nd, d):
            break
        d = nd
    return d


def box(a: np.ndarray, r: int) -> np.ndarray:
    """(2r+1)^2 kutu bulanıklığı (kümülatif toplam, kenar sıfır)."""
    p = np.pad(a, r + 1)
    c = np.cumsum(np.cumsum(p, 0), 1)
    k = 2 * r + 1
    out = c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]
    return out[: a.shape[0], : a.shape[1]] / (k * k)


def flow(water: np.ndarray, d_px: np.ndarray):
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
    return fx * mag, fy * mag


def half(a: np.ndarray) -> np.ndarray:
    h, w = a.shape[0] // 2 * 2, a.shape[1] // 2 * 2
    a = a[:h, :w]
    return (a[0::2, 0::2] + a[1::2, 0::2] + a[0::2, 1::2] + a[1::2, 1::2]) / 4.0


def main() -> None:
    mask_path, out_dir = sys.argv[1], sys.argv[2]
    cov = np.asarray(Image.open(mask_path).convert("L"), dtype=np.float32) / 252.0
    water = cov >= 0.5
    d_px = np.clip(chamfer(water, int(MAX_PX / TEXEL) + 2) * TEXEL, 0, MAX_PX)
    Image.fromarray(np.round(d_px / MAX_PX * 255).astype(np.uint8), "L").save(os.path.join(out_dir, "su_mesafe.png"))

    fx, fy = flow(water, d_px)
    fx, fy = half(fx), half(fy)
    birth = half((d_px >= BIRTH_MIN_PX).astype(np.float64))
    rgb = np.dstack([
        np.round((0.5 + 0.5 * fx) * 255), np.round((0.5 + 0.5 * fy) * 255), np.round(birth * 255),
    ]).clip(0, 255).astype(np.uint8)
    Image.fromarray(rgb, "RGB").save(os.path.join(out_dir, "su_akis.png"))
    os.remove(mask_path)
    for extra in (mask_path + ".import",):
        if os.path.exists(extra):
            os.remove(extra)
    print("su_mesafe.png", d_px.shape[::-1], "su_akis.png", rgb.shape[1::-1], "su teksel", int(water.sum()))


if __name__ == "__main__":
    main()
