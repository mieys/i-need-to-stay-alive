"""Sicrayan Zehir (madde 592) gercek oyun cekimini GIF'e cevirir (yakala.gd ciktisi out/oyun/).

  python -I tools/proto_20261111/sicrayan_zehir/gif.py
Cikti out/: sicrayan_zehir.gif (GERCEK HIZ, oyun zamani; cekim x0,25 yavas alindi), sicrayan_zehir_yavas.gif (YARI HIZ).
Dither yok (piksel sanat), kareler oyun ms'sine gore STEP_MS aralikla secilir.
"""

import json
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "out", "oyun")
OUT = os.path.join(HERE, "out")
STEP_MS = 40
START_MS = 350  ## ikinci atis cikmadan biraz once


def pick(times):
    out = []
    t = START_MS
    while t <= times[-1]:
        i = min(range(len(times)), key=lambda k: abs(times[k] - t))
        out.append(i)
        t += STEP_MS
    return out


def save(idx, path, ms):
    frames = []
    for i in idx:
        im = Image.open(os.path.join(SRC, "kare_%03d.png" % i)).convert("RGB")
        frames.append(im.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE))
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=ms, loop=0, disposal=1)
    print(path, len(frames), "kare", os.path.getsize(path) // 1024, "KB")


def main():
    d = json.load(open(os.path.join(SRC, "zamanlar.json"), encoding="utf-8"))
    idx = pick(d["times"])
    save(idx, os.path.join(OUT, "sicrayan_zehir.gif"), STEP_MS)
    save(idx, os.path.join(OUT, "sicrayan_zehir_yavas.gif"), STEP_MS * 2)


if __name__ == "__main__":
    main()
