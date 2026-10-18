"""kart_proto.gd karelerini (PNG) GIF'e çevirir (madde 263).
Kullanım: python kart_gif.py <kare_klasoru> <cikti_klasoru> [fps]
Her alt klasör (A_level, A_sandik, ...) bir GIF olur; son kare 0,9 sn bekler."""
import os
import sys

from PIL import Image


def main() -> None:
    src, dst = sys.argv[1], sys.argv[2]
    fps = float(sys.argv[3]) if len(sys.argv) > 3 else 15.0
    for name in sorted(os.listdir(src)):
        d = os.path.join(src, name)
        if not os.path.isdir(d):
            continue
        files = sorted(f for f in os.listdir(d) if f.endswith(".png"))
        if not files:
            continue
        rgb = [Image.open(os.path.join(d, f)).convert("RGB") for f in files]
        # tek ortak palet (ortadaki kareden): arka plan her karede aynı piksellere düşer, GIF yalnız değişen bölgeyi saklar
        pal = rgb[len(rgb) // 2].quantize(colors=192, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
        frames = [im.quantize(palette=pal, dither=Image.Dither.NONE) for im in rgb]
        durs = [int(round(1000 / fps))] * len(frames)
        durs[-1] = 900
        out = os.path.join(dst, name + ".gif")
        frames[0].save(out, save_all=True, append_images=frames[1:], duration=durs, loop=0, disposal=1)
        print(out, len(frames), os.path.getsize(out) // 1024, "KB")


if __name__ == "__main__":
    main()
