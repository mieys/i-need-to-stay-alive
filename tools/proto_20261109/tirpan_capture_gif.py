"""tirpan_capture.ps1 karelerini (f_<ms>.png) gerçek zamanlı GIF'e çevirir: python -I tirpan_capture_gif.py <kare klasörü> <çıktı.gif>"""
import os
import sys

from PIL import Image

src, out = sys.argv[1], sys.argv[2]
names = sorted(f for f in os.listdir(src) if f.startswith("f_") and f.endswith(".png"))
frames, ts = [], []
for n in names:
    frames.append(Image.open(os.path.join(src, n)).convert("RGB"))
    ts.append(int(n[2:7]))
durs = [max(20, ts[i + 1] - ts[i]) for i in range(len(ts) - 1)] + [40]
pal = frames[len(frames) // 3].quantize(255, method=Image.Quantize.MEDIANCUT)
q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
os.makedirs(os.path.dirname(out), exist_ok=True)
q[0].save(out, save_all=True, append_images=q[1:], duration=durs, loop=0, disposal=1)
print("gif", out, len(q))
