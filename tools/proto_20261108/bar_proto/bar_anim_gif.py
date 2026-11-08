# Can/kalkan cubugu LoL animasyonu GIF'i (madde 470): hud_capture.gd BAR_ANIM=1 karelerinden (hud_yeni/out/anim/f_###.png + zaman.txt),
# gercek zamanlamayla, 2x en yakin komsu. Cikti: bar_proto/out/bar_anim.gif + bar_proto/out/bar_anim_kareler.png (ana anlar)
#   python -I tools/proto_20261108/bar_proto/bar_anim_gif.py
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "hud_yeni", "out", "anim")
OUT = os.path.join(HERE, "out")
K = 2


def main():
    stamps = [int(x) for x in open(os.path.join(SRC, "zaman.txt")).read().split()]
    frames = []
    for i in range(len(stamps)):
        im = Image.open(os.path.join(SRC, "f_%03d.png" % i)).convert("RGB")
        frames.append(im.resize((im.width * K, im.height * K), Image.NEAREST))
    durs = [max(20, stamps[i + 1] - stamps[i]) for i in range(len(stamps) - 1)] + [600]
    frames[0].save(os.path.join(OUT, "bar_anim.gif"), save_all=True, append_images=frames[1:], duration=durs, loop=0, optimize=False)
    # ana anlar: hasardan once, hemen sonra, erirken, iyilesirken, sonda
    want = [200, 500, 1100, 1700, 2350, 2700, 3500]
    picks = [min(range(len(stamps)), key=lambda i: abs(stamps[i] - t)) for t in want]
    w, h = frames[0].size
    sheet = Image.new("RGB", (w, (h + 6) * len(picks)), (23, 17, 12))
    for j, i in enumerate(picks):
        sheet.paste(frames[i], (0, j * (h + 6)))
    sheet.save(os.path.join(OUT, "bar_anim_kareler.png"))
    print("ok", len(frames), "kare", stamps[-1], "ms")


if __name__ == "__main__":
    main()
