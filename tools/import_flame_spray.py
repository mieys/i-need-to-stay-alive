"""Kullanıcının yeni ateş püskürtme efektini (2026-10-03, "yeni ateş püskürtme efekti.zip": 61 kare 100x100, 1_<n>.png)
Destiny of Ice and Fire efsununun koni görseli olarak içe aktarır - ateş OLDUĞU GİBİ, buz ise renkleri buza çevrilmiş.

  python tools/import_flame_spray.py "<zip ya da klasör>"

Çıktı: assets/fx/enchant/flame_fire_sheet.png + flame_fire_frames.tres, flame_ice_sheet.png + flame_ice_frames.tres
(tek "loop" animasyonu, döngülü - kullanıcı: "oynatılıp kapatılıyordu, sürekli devam etmesini istiyorum").

Sanat ELLE çizilmiş, YENİDEN ÇİZİLMEZ (hafıza: kullanıcı sanatını yeniden çizme) - sadece:
  - yatay çevrilir: kareler arası ölçülen akış SOLA (her kare ~1 px; sarı sıcak çekirdek sağda = namlu), oyundaki
    sayfalar +x'e baktığı için namlu solda, akış +x olsun;
  - tüm karelerin ortak dolu alanına (1 px pay) kırpılır;
  - namlu noktası ölçülür (sol uçtaki sarı çekirdeğin dikey ortası) ve çıktı olarak yazdırılır -> destiny.gd FLAME_*.
Buz: piksel başına "sıcaklık" (sarı = 1, turuncu ~0.5, kırmızı = 0; koyu duman ayrı) buz rampasına eşlenir (beyaz ->
açık mavi -> derin mavi), duman soluk ayaz buharına döner; alfa aynen korunur.
"""
import os
import re
import sys
import tempfile
import zipfile

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

OUT = os.path.join(ROOT, "assets", "fx", "enchant")
RES = "res://assets/fx/enchant/"
FPS = 30

ICE_RAMP = [  # (sıcaklık, renk) - düşükten yükseğe
    (0.0, (38, 96, 206)),
    (0.35, (84, 162, 240)),
    (0.65, (160, 218, 255)),
    (1.0, (236, 250, 255)),
]
ICE_MIST_DARK = (120, 156, 200)   # koyu duman -> soluk ayaz buharı
ICE_MIST_LIGHT = (176, 206, 236)


def load_frames(src):
    if os.path.isfile(src) and src.lower().endswith(".zip"):
        tmp = tempfile.mkdtemp()
        with zipfile.ZipFile(src) as z:
            z.extractall(tmp)
        src = tmp
    files = []
    for dp, _, fs in os.walk(src):
        for f in fs:
            m = re.match(r"^\d+_(\d+)\.png$", f)
            if m:
                files.append((int(m.group(1)), os.path.join(dp, f)))
    files.sort()
    if not files:
        sys.exit("HATA: '<n>_<kare>.png' biçiminde kare bulunamadı: " + src)
    return [Image.open(p).convert("RGBA") for _, p in files]


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def ice_color(r, g, b):
    v = max(r, g, b)
    if v < 110:  # koyu duman / kor
        return lerp(ICE_MIST_DARK, ICE_MIST_LIGHT, v / 110.0)
    heat = min(1.0, g / float(max(r, 1)))  # sarı ~1, turuncu ~0.4-0.6, kırmızı ~0.1-0.3
    heat *= 0.55 + 0.45 * (v / 255.0)
    for i in range(len(ICE_RAMP) - 1):
        t0, c0 = ICE_RAMP[i]
        t1, c1 = ICE_RAMP[i + 1]
        if heat <= t1:
            return lerp(c0, c1, (heat - t0) / (t1 - t0))
    return ICE_RAMP[-1][1]


def recolor_ice(im):
    out = im.copy()
    px = out.load()
    w, h = out.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = ice_color(r, g, b) + (a,)
    return out


def write(name, frames):
    w, h = frames[0].size
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * w, 0))
    sheet.save(os.path.join(OUT, name + "_sheet.png"))
    write_sprite_frames(os.path.join(OUT, name + "_frames.tres"), RES + name + "_sheet.png", w, h,
                        [("loop", (0, 0), len(frames), True, FPS)])
    print("  %-11s %dx%d x %d kare, %d fps (loop)" % (name, w, h, len(frames), FPS))


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    frames = [f.transpose(Image.FLIP_LEFT_RIGHT) for f in load_frames(sys.argv[1])]
    x0 = y0 = 10 ** 9
    x1 = y1 = -1
    for f in frames:
        bb = f.getbbox()
        if bb:
            x0, y0, x1, y1 = min(x0, bb[0]), min(y0, bb[1]), max(x1, bb[2]), max(y1, bb[3])
    W, H = frames[0].size
    box = (max(0, x0 - 1), max(0, y0 - 1), min(W, x1 + 1), min(H, y1 + 1))
    frames = [f.crop(box) for f in frames]
    w, h = frames[0].size
    # namlu: sol uçtaki (ilk 6 sütun) sarı/sıcak piksellerin dikey ortası, tüm kareler boyunca
    ys = []
    for f in frames:
        px = f.load()
        for x in range(min(6, w)):
            for y in range(h):
                r, g, b, a = px[x, y]
                if a > 128 and r > 200 and g > 180:
                    ys.append(y)
    oy = sum(ys) / len(ys) if ys else h / 2.0
    ox = 0.0
    # en geniş yarı açı: namludan uzaklaştıkça dolu piksellerin namlu eksenine olan dikey uzaklığı
    import math
    half = 0.0
    for f in frames:
        px = f.load()
        for x in range(8, w):
            for y in range(h):
                if px[x, y][3] > 128:
                    half = max(half, math.degrees(math.atan2(abs(y - oy), x - ox)))
    os.makedirs(OUT, exist_ok=True)
    write("flame_fire", frames)
    write("flame_ice", [recolor_ice(f) for f in frames])
    print("FLAME_FRAME_SIZE = (%d, %d)" % (w, h))
    print("FLAME_ORIGIN (kare içinde namlu) = (%.1f, %.1f)  -> sprite offset (merkezden) = (%.1f, %.1f)"
          % (ox, oy, w / 2.0 - ox, h / 2.0 - oy))
    print("FLAME_LENGTH_PX = %d   en geniş yarı açı ~%.1f derece" % (w, half))


if __name__ == "__main__":
    main()
