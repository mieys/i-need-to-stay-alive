"""Harita gölgeleri (2026-10-02, kullanıcı seçimi "B - Tepe gölgesi") - 2. ADIM: gölge dokusu.

tools/bake_map_shadows.gd'nin yakaladığı kategori maskelerinden (4096x4096, alfa = obje pikseli) yönsüz "tepe güneşi"
gölgesini hesaplar ve assets/map/harita_golgeleri.png'ye yazar (tek kanal, 0-255 = gölge yoğunluğu). Oyunda
scripts/map_shadows.gd bu dokuyu zemin katmanlarının hemen üstüne, objelerin altına çarpma (multiply) karışımıyla çizer:
renk = mix(beyaz, TINT, yoğunluk) - TINT ve sayılar orada.

Kurallar (gerçek oyun karesi üzerinde prototiplenip kullanıcıya onaylatıldı - bkz. sohbet 2026-10-02):
  * Ağaç (Ağaç 0/1/2, katman katman): tacın silueti dikine x0.45 ezilir, gövde dibinde merkezli "gölgelik" - ezilmiş
    yüksekliğin yarısı kadar zemine taşar.
  * Çalı katmanındaki bitkiler ve çiçekler (sallanan çalılar, >= 40 px): ağaç gibi küçük yaprak gölgeliği (0.26) - ince
    saplı oldukları için alt hat hilali sapın altında görünmez kalıyordu (kullanıcı: "animasyonlu çalıların neden gölgesi
    yok"). Sadece çok küçük çim tutamları (< 40 px) 1 texel hilal.
  * Ev, tarla, büyük orman/uçurum blokları: her sütunda en alt pikselin altına 4 texel düz şerit (son satır açık).
  * Yerdeki objeler (kaya, kütük, odun, varil, maden, çalı): gövdenin alt hattını izleyen 2-3 texel hilal (çim/filiz 1).
    Koyu gövdeli objelerde dipteki yeşil çim saçağı gölge düşürmez; saçak ayıklanınca birbirine değmeyen gövdeler
    (yan yana kayalar) ayrı gölge alır, hilal saçağın altından başlar.
  * Kenarlar düz piksel bantları: iç 0.30, dış kenar 0.21 (kullanıcı: kenarda "pixel parçacıkları" olmasın - dither YOK).

Kullanım: python tools/bake_map_shadows.py <maske klasörü> [çıktı png]
"""
import os
import sys

import numpy as np
from PIL import Image

INNER = 0.30
RIM_MULT = 0.7
PLANT = 0.18
PLANT_POOL = 0.26
TREE_SQUASH = 0.45
BLOCK_BAND = [0.30, 0.30, 0.30, 0.21]
FRINGE_MAX = 3


def load_mask(path):
    img = Image.open(path)
    a = np.array(img.getchannel("A") if "A" in img.getbands() else img.convert("L"))
    return a > 127


def label8(mask):
    """8-komşu bağlı bileşen etiketleri (satır koşuları + birleşim kümesi). Döner: (etiket dizisi, adet)."""
    h, w = mask.shape
    labels = np.zeros((h, w), np.int32)
    parent = [0]

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    prev = []
    for y in range(h):
        row = mask[y]
        if not row.any():
            prev = []
            continue
        d = np.diff(np.concatenate(([0], row.astype(np.int8), [0])))
        starts = np.flatnonzero(d == 1)
        ends = np.flatnonzero(d == -1)
        cur = []
        j = 0
        for s, e in zip(starts.tolist(), ends.tolist()):
            while j < len(prev) and prev[j][1] < s:
                j += 1
            lab = 0
            k = j
            while k < len(prev) and prev[k][0] <= e:
                pl = find(prev[k][2])
                if lab == 0:
                    lab = pl
                elif pl != lab:
                    parent[max(pl, lab)] = min(pl, lab)
                    lab = min(pl, lab)
                k += 1
            if lab == 0:
                lab = len(parent)
                parent.append(lab)
            labels[y, s:e] = lab
            cur.append((s, e, lab))
        prev = cur
    roots = np.array([find(i) for i in range(len(parent))], np.int32)
    _, compact = np.unique(roots, return_inverse=True)
    labels = compact[labels].astype(np.int32)
    return labels, int(compact.max())


def components(mask):
    """[(ys, xs)] - her bileşenin piksel koordinatları."""
    labels, n = label8(mask)
    ys, xs = np.nonzero(labels)
    if len(ys) == 0:
        return []
    labs = labels[ys, xs]
    order = np.argsort(labs, kind="stable")
    ys, xs, labs = ys[order], xs[order], labs[order]
    cuts = np.flatnonzero(np.diff(labs)) + 1
    return list(zip(np.split(ys, cuts), np.split(xs, cuts)))


def put(a, sil, y0, x0, val):
    """sil (yerel bool pencere) -> iç piksel val, dış kenar val*RIM_MULT; a'ya max ile yazılır."""
    if not sil.any():
        return
    inner = sil.copy()
    inner[1:, :] &= sil[:-1, :]
    inner[:-1, :] &= sil[1:, :]
    inner[:, 1:] &= sil[:, :-1]
    inner[:, :-1] &= sil[:, 1:]
    inner[0, :] = False
    inner[-1, :] = False
    inner[:, 0] = False
    inner[:, -1] = False
    v = np.where(inner, val, np.where(sil, val * RIM_MULT, 0.0)).astype(np.float32)
    h, w = v.shape
    H, W = a.shape
    ya, xa = max(0, y0), max(0, x0)
    yb, xb = min(H, y0 + h), min(W, x0 + w)
    if ya >= yb or xa >= xb:
        return
    sub = v[ya - y0:yb - y0, xa - x0:xb - x0]
    np.maximum(a[ya:yb, xa:xb], sub, out=a[ya:yb, xa:xb])


def tree_shadow(a, ys, xs, val=INNER):
    y0, y1 = ys.min(), ys.max()
    h = y1 - y0 + 1
    hh = h * TREE_SQUASH
    bottom = y1 + 1.0 + hh * 0.5
    ny = np.floor(bottom - (y0 + h - (ys + 0.5)) * TREE_SQUASH).astype(np.int64)
    oy0, ox0 = int(ny.min()) - 1, int(xs.min()) - 1
    sil = np.zeros((int(ny.max()) - oy0 + 2, int(xs.max()) - ox0 + 2), bool)
    sil[ny - oy0, xs - ox0] = True
    ## ezmeden doğan küçük satır boşlukları (<=3) kapanır, atlanan satırlar doldurulur
    for r in np.flatnonzero(sil.any(1)):
        cols = np.flatnonzero(sil[r])
        gaps = np.diff(cols)
        for i in np.flatnonzero((gaps > 1) & (gaps <= 3)):
            sil[r, cols[i]:cols[i + 1]] = True
    sil[1:-1, :] |= sil[:-2, :] & sil[2:, :]
    put(a, sil, oy0, ox0, val)


def column_bottoms(ys, xs, x0, width):
    b = np.full(width, -1, np.int64)
    np.maximum.at(b, xs - x0, ys)
    return b


def block_shadow(a, ys, xs):
    x0 = xs.min()
    b = column_bottoms(ys, xs, x0, xs.max() - x0 + 1)
    H, W = a.shape
    for i in np.flatnonzero(b >= 0):
        x = x0 + i
        for k, v in enumerate(BLOCK_BAND, start=1):
            y = b[i] + k
            if 0 <= y < H and a[y, x] < v:
                a[y, x] = v


def ground_shadow(a, ys, xs, obj_mask_full, color, plant):
    """Hilal: gövde sütunlarının en alt (saçak dahil) pikselinin altına 2-3 texel."""
    y0, x0 = ys.min(), xs.min()
    h, w = ys.max() - y0 + 1, xs.max() - x0 + 1
    body_y, body_x = ys, xs
    if color is not None and not plant:
        col = color[ys, xs].astype(np.int32)
        green = (col[:, 1] > col[:, 0] * 1.12) & (col[:, 1] > col[:, 2] * 1.12)
        if green.mean() <= 0.6:
            body_y, body_x = ys[~green], xs[~green]
    if len(body_y) < 3:
        return
    om = np.zeros((h + FRINGE_MAX + 1, w), bool)
    om[ys - y0, xs - x0] = True
    bm = np.zeros((h, w), bool)
    bm[body_y - y0, body_x - x0] = True
    for cy, cx in components(bm):
        if len(cy) < 3:
            continue
        hb = cy.max() - cy.min() + 1
        depth = 1 if plant else (2 if hb < 12 else 3)
        cx0 = cx.min()
        b = column_bottoms(cy, cx, cx0, cx.max() - cx0 + 1)
        cols = np.flatnonzero(b >= 0)
        sil = np.zeros((h + FRINGE_MAX + depth + 2, w), bool)
        for n, i in enumerate(cols):
            x = cx0 + i
            yb = b[i]
            while yb + 1 < om.shape[0] and yb + 1 <= b[i] + FRINGE_MAX and om[yb + 1, x]:
                yb += 1
            d = depth - (1 if (n == 0 or n == len(cols) - 1) and depth > 1 else 0)
            sil[yb + 1:yb + 1 + d, x] = True
        put(a, sil, y0, x0, PLANT if plant else INNER)


def is_plant(cat, area, w, h):
    return cat == "bush" and (area < 40 or area / float(w * h) < 0.35)


def main():
    src = sys.argv[1]
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(root, "assets", "map", "harita_golgeleri.png")
    masks = {}
    for cat in ["tree0", "tree1", "tree2", "bush", "house", "farm", "rock", "cliff"]:
        masks[cat] = load_mask(os.path.join(src, cat + ".png"))
    colors = {}
    for cat in ["rock", "cliff"]:
        p = os.path.join(src, cat + "_color.png")
        colors[cat] = np.array(Image.open(p).convert("RGB")) if os.path.exists(p) else None
    H, W = masks["tree0"].shape
    a = np.zeros((H, W), np.float32)
    counts = {}
    for cat, m in masks.items():
        if cat == "house":
            ## evin parçaları (çatı/duvar/kapı arası 1 texel boşluk) tek blok sayılsın
            d = m.copy()
            d[1:, :] |= m[:-1, :]
            d[:-1, :] |= m[1:, :]
            d[:, 1:] |= m[:, :-1]
            d[:, :-1] |= m[:, 1:]
            comps = [(ys, xs) for ys, xs in components(d)]
            comps = [(ys[m[ys, xs]], xs[m[ys, xs]]) for ys, xs in comps]
        else:
            comps = components(m)
        counts[cat] = len(comps)
        for ys, xs in comps:
            if len(ys) < 3:
                continue
            w = xs.max() - xs.min() + 1
            h = ys.max() - ys.min() + 1
            area = len(ys)
            if cat.startswith("tree"):
                tree_shadow(a, ys, xs)
            elif cat == "bush" and area >= 40:
                tree_shadow(a, ys, xs, PLANT_POOL)
            elif cat in ("house", "farm") or (cat == "cliff" and (w > 40 or area > 900)):
                block_shadow(a, ys, xs)
            else:
                ground_shadow(a, ys, xs, m, colors.get(cat), is_plant(cat, area, w, h))
    img = Image.fromarray(np.clip(np.round(a * 255.0), 0, 255).astype(np.uint8), "L")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    img.save(out, optimize=True)
    print("objects:", counts)
    print("written:", out, "covered px:", int((a > 0).sum()))


if __name__ == "__main__":
    main()
