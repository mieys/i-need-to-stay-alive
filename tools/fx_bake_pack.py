"""Efekt PİŞİRİCİ - 2. aşama (madde 215). Kullanım: python fx_bake_pack.py <ad> <kare klasörü> <fps> <texel> [yol_ön_eki]

Siyah (b_###.png) ve beyaz (w_###.png) zeminde çekilmiş kareleri birleştirir: alfa = 1 - (beyaz - siyah), renk = siyah / alfa
(normal karışımlı çizimler için kayıpsız). Tüm karelerin ortak sınır kutusuna kırpar, ızgara sayfası
assets/fx/baked/<ad>_sheet.png + SpriteFrames assets/fx/baked/<ad>_frames.tres yazar. Her kare bir AtlasTexture;
`margin` içeriği sanal tam boyuta (merkez = efekt orijini) oturtur, böylece AnimatedSprite2D(centered) orijinde durur.
Kullanım yeri: scripts/baked_fx.gd."""
import sys, os, math, glob
import numpy as np
from PIL import Image

name, d, fps, texel = sys.argv[1], sys.argv[2], int(sys.argv[3]), float(sys.argv[4])
root = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
out_dir = os.path.join(root, "assets", "fx", "baked")
os.makedirs(out_dir, exist_ok=True)

bs = sorted(glob.glob(os.path.join(d, "b_*.png")))
ws = sorted(glob.glob(os.path.join(d, "w_*.png")))
assert bs and len(bs) == len(ws), "kare sayıları eşleşmiyor"
frames = []
for bp, wp in zip(bs, ws):
    b = np.asarray(Image.open(bp).convert("RGB")).astype(np.float64) / 255.0
    w = np.asarray(Image.open(wp).convert("RGB")).astype(np.float64) / 255.0
    a = np.clip(1.0 - (w - b).mean(axis=2), 0.0, 1.0)
    a[a < 0.02] = 0.0
    c = np.where(a[..., None] > 0, b / np.maximum(a[..., None], 1e-6), 0.0)
    c = np.clip(c, 0.0, 1.0)
    rgba = np.dstack([c, a])
    frames.append((rgba * 255.0 + 0.5).astype(np.uint8))

H, W = frames[0].shape[:2]
ys, xs = [], []
for f in frames:
    nz = np.argwhere(f[..., 3] > 0)
    if len(nz):
        ys += [nz[:, 0].min(), nz[:, 0].max()]
        xs += [nz[:, 1].min(), nz[:, 1].max()]
if not xs:
    raise SystemExit("boş efekt")
x0, x1, y0, y1 = min(xs), max(xs) + 1, min(ys), max(ys) + 1
if x0 == 0 or y0 == 0 or x1 == W or y1 == H:
    print("UYARI: efekt görünüm kutusunun kenarına değiyor - BAKE_VIEW büyüt")
w, h = x1 - x0, y1 - y0
cx, cy = W // 2, H // 2
hx = max(cx - x0, x1 - cx)  # orijine göre sanal yarı genişlik (simetrik)
hy = max(cy - y0, y1 - cy)
vw, vh = 2 * hx, 2 * hy
n = len(frames)
cols = min(n, max(1, 4096 // w))
rows = math.ceil(n / cols)
sheet = np.zeros((rows * h, cols * w, 4), np.uint8)
for i, f in enumerate(frames):
    r, c = divmod(i, cols)
    sheet[r * h:(r + 1) * h, c * w:(c + 1) * w] = f[y0:y1, x0:x1]
Image.fromarray(sheet, "RGBA").save(os.path.join(out_dir, f"{name}_sheet.png"), optimize=True)

mx, my = x0 - (cx - hx), y0 - (cy - hy)  # içeriğin sanal doku içindeki konumu
res = f"res://assets/fx/baked/{name}_sheet.png"
lines = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (n + 2), "",
         f'[ext_resource type="Texture2D" path="{res}" id="1"]', ""]
for i in range(n):
    r, c = divmod(i, cols)
    lines += [f'[sub_resource type="AtlasTexture" id="a{i}"]', 'atlas = ExtResource("1")',
              f"region = Rect2({c * w}, {r * h}, {w}, {h})",
              f"margin = Rect2({mx}, {my}, {vw - w}, {vh - h})", ""]
fr = ", ".join('{"duration": 1.0, "texture": SubResource("a%d")}' % i for i in range(n))
lines += ["[resource]", 'animations = [{', f'"frames": [{fr}],', '"loop": false,', f'"name": &"play",', f'"speed": {float(fps)}', "}]", ""]
open(os.path.join(out_dir, f"{name}_frames.tres"), "w", newline="\n").write("\n".join(lines))
print(f"BAKED {name}: {n} kare, hücre {w}x{h}, sanal {vw}x{vh}, sayfa {cols * w}x{rows * h}, "
      f"~{cols * w * rows * h * 4 / 1048576:.1f} MB VRAM, dünya boyu (texel {texel}) {vw * texel:.0f}x{vh * texel:.0f}")
