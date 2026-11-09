"""Harita karmasa olculeri: <dir>/<harita>_<p>_dunya.png (+ _dunya2 hareket icin). 960x540, 1 px = 1 dunya pikseli."""
import sys, glob, os, re
import numpy as np
from PIL import Image

D = sys.argv[1]
MAPS = ["ana", "bataklik", "col", "batik_nekropol", "taskin_hisar", "lagim_agi"]


def load(p):
    return np.asarray(Image.open(p).convert("RGB"), dtype=np.float32) / 255.0


def box(a, r):
    # ayrik kutu bulaniklik (kenar yansitma)
    k = 2 * r + 1
    p = np.pad(a, ((r, r), (r, r)), mode="reflect")
    c = p.cumsum(0).cumsum(1)
    c = np.pad(c, ((1, 0), (1, 0)))
    return (c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]) / (k * k)


def metrics(img, img2):
    h, w, _ = img.shape
    mask = np.ones((h, w), bool)
    mask[270 - 45:270 + 25, 480 - 22:480 + 22] = False  # oyuncu
    r, g, b = img[..., 0], img[..., 1], img[..., 2]
    L = 0.2126 * r + 0.7152 * g + 0.0722 * b
    mx, mn = img.max(2), img.min(2)
    S = np.where(mx > 1e-4, (mx - mn) / np.maximum(mx, 1e-4), 0)
    # Hasler-Susstrunk renklilik
    rg, yb = r - g, 0.5 * (r + g) - b
    m = mask
    colorful = np.sqrt(rg[m].std() ** 2 + yb[m].std() ** 2) + 0.3 * np.sqrt(rg[m].mean() ** 2 + yb[m].mean() ** 2)
    # 1 tekselde komsu farki (benek)
    gx = np.abs(np.diff(L, axis=1))[:, :-0 or None]
    gy = np.abs(np.diff(L, axis=0))
    grad = np.zeros_like(L)
    grad[:, :-1] += gx
    grad[:-1, :] += gy
    edge = (grad > 0.10)[m].mean()
    texel = grad[m].mean()
    # frekans bantlari
    b1, b7 = box(L, 1), box(L, 7)
    fine = np.abs(L - b1)[m].mean()
    mid = np.abs(b1 - b7)[m].mean()
    # dinlenme alani: 16x16 blok luma std < 0.035
    bs = 16
    hh, ww = (h // bs) * bs, (w // bs) * bs
    blk = L[:hh, :ww].reshape(hh // bs, bs, ww // bs, bs).std(axis=(1, 3))
    rest = (blk < 0.035).mean()
    busy = (blk > 0.10).mean()
    # ton entropisi (doygun pikseller)
    hue = np.zeros_like(L)
    d = np.maximum(mx - mn, 1e-6)
    hr = ((g - b) / d) % 6
    hg = (b - r) / d + 2
    hb = (r - g) / d + 4
    hue = np.where(mx == r, hr, np.where(mx == g, hg, hb)) / 6.0
    sel = m & (S > 0.25) & (mx > 0.15)
    hist, _ = np.histogram(hue[sel], bins=24, range=(0, 1))
    pr = hist / max(1, hist.sum())
    pr = pr[pr > 0]
    hue_ent = float(-(pr * np.log2(pr)).sum())
    out = {
        "L": L[m].mean(), "Lstd": L[m].std(), "parlak": (L > 0.62)[m].mean(),
        "S": S[m].mean(), "renk": colorful, "kenar": edge, "teksel": texel,
        "ince": fine, "orta": mid, "dinlen": rest, "yogun": busy, "ton_ent": hue_ent,
        "doygun": sel.mean(),
    }
    if img2 is not None:
        L2 = 0.2126 * img2[..., 0] + 0.7152 * img2[..., 1] + 0.0722 * img2[..., 2]
        out["hareket"] = (np.abs(L2 - L) > 0.03)[m].mean()
    return out


rows = {}
for mp in MAPS:
    fs = sorted(glob.glob(os.path.join(D, f"{mp}_p*_dunya.png")))
    acc = []
    for f in fs:
        f2 = f.replace("_dunya.png", "_dunya2.png")
        acc.append(metrics(load(f), load(f2) if os.path.exists(f2) else None))
    if not acc:
        continue
    rows[mp] = {k: float(np.mean([a[k] for a in acc if k in a])) for k in acc[0]}
    rows[mp]["n"] = len(acc)

keys = ["n", "L", "Lstd", "parlak", "S", "renk", "doygun", "ton_ent", "teksel", "kenar", "ince", "orta", "dinlen", "yogun", "hareket"]
print("harita".ljust(16) + "".join(k.rjust(9) for k in keys))
for mp, v in rows.items():
    print(mp.ljust(16) + "".join(("%9.3f" % v.get(k, float("nan"))) if k != "n" else ("%9d" % v[k]) for k in keys))
