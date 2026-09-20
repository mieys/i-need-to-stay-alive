#!/usr/bin/env python3
"""CraftPix "Magic Buff Effects" (Life/Mana Recovery) -> oyun icin piksel-art spritesheet.

Kaynak kareler 640x800 vektor kalitesinde, kenarlari cok yumusak (piksellerin
~%40'i yari saydam) - oyunda "nearest" filtreyle bile piksel gibi gorunmuyordu.
Bu arac her kareyi:
  1. halka merkezi kareyi ORTALAYACAK sekilde (Godot'ta node konumu = halka
     merkezi olsun diye) dusuk cozunurluge indirir (premultiplied alpha ile
     alan ortalamasi - kenarlarda renk bulasmasi olmaz),
  2. TUM karelerde ortak, az renkli bir palete (k-means) sabitler (kareler
     arasi ton titremesi olmasin),
  3. yari saydamligi az sayida seviyeye indirip aralarini sabit bir Bayer
     desenle "dither" eder (yumusak isik = pikselli nokta deseni).
Sonuc: tek satirlik PNG sheet + Godot SpriteFrames (.tres).

Kullanim (repo kokunden; --src = zip'in acilmis klasoru, icinde
"Life Recovery/PNG" ve "Mana Recovery/PNG" olmali):
    python tools/pixelate_recovery_fx.py --src <acilmis_klasor>

Ciktilar assets/fx/recovery/ altina yazilir. Boyut/renk ayarlari asagidaki
VARIANTS ve sabitlerden degistirilip komut yeniden calistirilabilir.
"""
import argparse
import glob
import os

import numpy as np
from PIL import Image

## Kaynak karelerde (640x800) OLCULEN degerler - her iki efekt icin de ayni:
## kareler boyunca her zaman opak kalan (sabit) halkanin sinirlari
## x 92..547, y 441..721 -> merkez (319.5, 581), genislik 455.
SRC_RING_CENTER = (319.5, 581.0)
SRC_RING_WIDTH = 455.0
## Halka merkezinden kaynak kenarina kadar olan en uzak mesafeler (yukari
## kivilcimlar y=9'a kadar cikiyor -> 572 piksel yukari). Kare, merkezin
## etrafinda SIMETRIK tutuluyor (Godot'ta ortalanmis sprite = halka merkezi).
SRC_HALF_W = 300.0
SRC_HALF_H = 580.0

## name -> halka genisligi (cikti pikseli). Godot'ta kullanilacak sprite scale'i
## .tscn'lerde/script'te tutulur (bkz. asagidaki yorumlar).
## "large": karakter/Melek ustu, "small": Oakley'nin cicegi.
VARIANTS = {
    "large": 68,  ## sprite scale = karakter sprite'iyle ayni (1.27575 * EntityScale.SIZE) -> halka ~82 ekran px
    "small": 52,  ## sprite scale = 1.0 -> halka capi 52 birim = Oakley cicegi alim capi (PICKUP_RADIUS 26 * 2)
}

PALETTE_COLORS = 10          ## efekt basina ortak palet boyutu
ALPHA_LEVELS = np.array([0.0, 0.34, 0.67, 1.0])  ## yari saydamlik seviyeleri
ALPHA_FLOOR = 0.10           ## bunun altindaki alfa tamamen silinir
ALPHA_GAIN = 1.25            ## silik isiklarin fazla sonmemesi icin alfa carpani (yumusak parlamayi biraz guclendirir)
FPS = 25.0                   ## kaynak GIF onizlemesi 40 ms/kare = 25 fps

BAYER4 = (
    np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32) + 0.5
) / 16.0


def load_frames(folder):
    files = sorted(glob.glob(os.path.join(folder, "PNG", "*_Frame_*.png")))
    if not files:
        raise SystemExit("Kare bulunamadi: %s" % folder)
    return [Image.open(f).convert("RGBA") for f in files]


def downscale(frame, ring_texels):
    """Halka merkezi cikti karesinin tam ortasina gelecek sekilde kucultur."""
    f = SRC_RING_WIDTH / float(ring_texels)  ## bir cikti pikseli = f kaynak piksel
    out_w = int(round(2.0 * SRC_HALF_W / f / 2.0)) * 2  ## cift sayi: merkez piksel sinirina denk gelsin
    out_h = int(round(2.0 * SRC_HALF_H / f / 2.0)) * 2
    ## Kaynagi buyuk bir tuvale ortalayip float 'box' ile alan-ortalamali resize.
    canvas_size = 1600
    cx = cy = canvas_size / 2.0
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    canvas.paste(frame, (int(round(cx - SRC_RING_CENTER[0])), int(round(cy - SRC_RING_CENTER[1]))))
    box = (cx - out_w * f / 2.0, cy - out_h * f / 2.0, cx + out_w * f / 2.0, cy + out_h * f / 2.0)
    small = canvas.convert("RGBa").resize((out_w, out_h), Image.BOX, box=box).convert("RGBA")
    return np.array(small).astype(np.float32) / 255.0, (out_w, out_h)


def kmeans_palette(colors, weights, k, iters=25):
    """Agirlikli k-means (sabit tohum) - dondurulmus, tekrarlanabilir palet."""
    rng = np.random.default_rng(7)
    ## Parlaklik siralamasina gore esit araliklardan baslat (deterministik, dengeli)
    lum = colors @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    order = np.argsort(lum)
    centers = colors[order[np.linspace(0, len(order) - 1, k).astype(int)]].copy()
    for _ in range(iters):
        d = ((colors[:, None, :] - centers[None, :, :]) ** 2).sum(-1)
        idx = d.argmin(1)
        for c in range(k):
            m = idx == c
            if m.any():
                centers[c] = (colors[m] * weights[m, None]).sum(0) / weights[m].sum()
            else:
                centers[c] = colors[rng.integers(len(colors))]
    return centers


def pixelate(frames_rgba, ring_texels):
    arrs, size = [], None
    for fr in frames_rgba:
        a, size = downscale(fr, ring_texels)
        arrs.append(a)
    ## Premultiplied kucultmeden cikan rgb zaten "duz" renk: alfa>0 pikselleri topla.
    rgb_all, w_all = [], []
    for a in arrs:
        m = a[..., 3] > ALPHA_FLOOR
        rgb_all.append(a[..., :3][m])
        w_all.append(a[..., 3][m])
    palette = kmeans_palette(np.concatenate(rgb_all), np.concatenate(w_all), PALETTE_COLORS)
    out = []
    h, w = arrs[0].shape[:2]
    bayer = np.tile(BAYER4, (h // 4 + 1, w // 4 + 1))[:h, :w]
    for a in arrs:
        rgb, alpha = a[..., :3], a[..., 3]
        idx = ((rgb[:, :, None, :] - palette[None, None, :, :]) ** 2).sum(-1).argmin(-1)
        rgb_q = palette[idx]
        alpha = np.clip(alpha * ALPHA_GAIN, 0.0, 1.0)
        alpha[alpha < ALPHA_FLOOR] = 0.0
        ## Iki komsu seviye arasinda sabit Bayer deseniyle dither.
        lvl = np.searchsorted(ALPHA_LEVELS, alpha, side="right") - 1
        lvl = np.clip(lvl, 0, len(ALPHA_LEVELS) - 2)
        lo, hi = ALPHA_LEVELS[lvl], ALPHA_LEVELS[lvl + 1]
        frac = (alpha - lo) / (hi - lo)
        alpha_q = np.where(frac > bayer, hi, lo)
        alpha_q[alpha == 0.0] = 0.0
        res = np.zeros((h, w, 4), dtype=np.uint8)
        res[..., :3] = np.round(rgb_q * 255.0).astype(np.uint8)
        res[..., 3] = np.round(alpha_q * 255.0).astype(np.uint8)
        res[res[..., 3] == 0] = 0
        out.append(res)
    return out, (w, h), palette


def write_tres(path, png_res_path, frame_w, frame_h, count):
    lines = ['[gd_resource type="SpriteFrames" format=3]', "",
             '[ext_resource type="Texture2D" path="%s" id="1"]' % png_res_path, ""]
    for i in range(count):
        lines += ['[sub_resource type="AtlasTexture" id="AtlasTexture_%d"]' % (i + 1),
                  'atlas = ExtResource("1")',
                  "region = Rect2(%d, 0, %d, %d)" % (i * frame_w, frame_w, frame_h), ""]
    frames = ",\n".join('{\n"duration": 1.0,\n"texture": SubResource("AtlasTexture_%d")\n}' % (i + 1) for i in range(count))
    lines += ["[resource]", "animations = [{", '"frames": [%s],' % frames, '"loop": true,',
              '"name": &"loop",', '"speed": %.1f' % FPS, "}]", ""]
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True, help="zip'in acilmis klasoru")
    ap.add_argument("--out", default=os.path.join("assets", "fx", "recovery"))
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    effects = {"life": "Life Recovery", "mana": "Mana Recovery"}
    ## Oakley'nin cicegi SADECE Life kullaniyor -> "small" sadece life icin uretilir.
    jobs = [("life", "large"), ("mana", "large"), ("life", "small")]
    for key, variant in jobs:
        frames = load_frames(os.path.join(args.src, effects[key]))
        sheets, (w, h), palette = pixelate(frames, VARIANTS[variant])
        sheet = Image.new("RGBA", (w * len(sheets), h), (0, 0, 0, 0))
        for i, s in enumerate(sheets):
            sheet.paste(Image.fromarray(s, "RGBA"), (i * w, 0))
        name = "%s_recovery_%s" % (key, variant)
        png_path = os.path.join(args.out, name + ".png")
        sheet.save(png_path)
        res_png = "res://" + png_path.replace(os.sep, "/")
        write_tres(os.path.join(args.out, name + "_frames.tres"), res_png, w, h, len(sheets))
        print("%s: kare %dx%d, %d kare, %d renk -> %s" % (name, w, h, len(sheets), PALETTE_COLORS, png_path))


if __name__ == "__main__":
    main()
