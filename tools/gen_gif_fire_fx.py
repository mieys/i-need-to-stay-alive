# Kullanıcının gönderdiği iki 32x32 / 10 kare / 60 ms GIF'ten oyun sayfaları (2026-11-13, madde: INDEX "GIF yanma + Şaman Q ateş topu").
#   tools/fx_kaynak/yanma_alevi_yan.gif  -> YANMA efekti; GIF'te yan yatık (kuyruk solda) -> 90 derece SAAT YÖNÜNDE: taban altta, alev yukarı.
#   tools/fx_kaynak/ates_topu_dikey.gif  -> Şaman Q ateş topu; GIF'te dik (baş altta) -> 90 derece SAAT TERSİNE: baş SAĞDA (+x = uçuş yönü).
# Arka plan (34,32,52) lacivert dolu geliyor -> saydam yapılır. Kareler ortak sınır kutusuna kırpılır (kare kare zıplamasın).
# Çıktı:
#   assets/fx/burn/yanma_gif_sheet.png + yanma_gif_frames.tres   "ignite" kare 0-1 (tek sefer) / "burn" kare 0-9 (döngü)
#   assets/fx/shaman_kor/ates_topu_sheet.png + ates_topu_frames.tres  "fly" kare 0-9 (döngü)
# Tutunma noktaları (yanma: taban ortası, top: baş merkezi) ekrana basılır -> fx_burn_status.gd / fx_totem_fire_bolt.gd sabitleri.
# Çalıştır: python -I tools/gen_gif_fire_fx.py
import os, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

ROOT = os.path.dirname(HERE)
SRC = os.path.join(HERE, "fx_kaynak")
BG = (34, 32, 52)
FPS = 1000.0 / 60.0


def frames(path, transpose):
    im = Image.open(path)
    out = []
    for k in range(im.n_frames):
        im.seek(k)
        f = im.convert("RGBA")
        px = f.load()
        for y in range(f.height):
            for x in range(f.width):
                r, g, b, a = px[x, y]
                if (r, g, b) == BG:
                    px[x, y] = (0, 0, 0, 0)
        out.append(f.transpose(transpose))
    return out


def union_bbox(fr):
    bb = None
    for f in fr:
        b = f.getbbox()
        if b is None:
            continue
        bb = b if bb is None else (min(bb[0], b[0]), min(bb[1], b[1]), max(bb[2], b[2]), max(bb[3], b[3]))
    return bb


def sheet(fr, bb, path):
    w, h = bb[2] - bb[0], bb[3] - bb[1]
    s = Image.new("RGBA", (w * len(fr), h))
    for i, f in enumerate(fr):
        s.paste(f.crop(bb), (i * w, 0))
    s.save(path)
    return w, h


def bright_center(fr, bb):
    # Sıcak çekirdeğin (en açık ton) ortalama konumu, kırpılmış kare koordinatında.
    sx = sy = n = 0
    for f in fr:
        c = f.crop(bb)
        px = c.load()
        for y in range(c.height):
            for x in range(c.width):
                r, g, b, a = px[x, y]
                if a > 0 and r > 240 and g > 230 and b > 150:
                    sx += x; sy += y; n += 1
    if n == 0:
        return ((bb[2] - bb[0]) / 2, (bb[3] - bb[1]) / 2)
    return (sx / n + 0.5, sy / n + 0.5)


def main():
    # YANMA: saat yönünde 90 (PIL ROTATE_270 = saat yönü)
    burn = frames(os.path.join(SRC, "yanma_alevi_yan.gif"), Image.Transpose.ROTATE_270)
    bb = union_bbox(burn)
    out = os.path.join(ROOT, "assets", "fx", "burn")
    w, h = sheet(burn, bb, os.path.join(out, "yanma_gif_sheet.png"))
    write_sprite_frames(os.path.join(out, "yanma_gif_frames.tres"), "res://assets/fx/burn/yanma_gif_sheet.png", w, h,
                        [("ignite", (0, 0), 2, False, FPS), ("burn", (0, 0), len(burn), True, FPS)])
    cx, _ = bright_center(burn, bb)
    print("yanma kare %dx%d, taban ortasi (%.1f, %d) -> ofset (%.1f, %.1f)" % (w, h, cx, h, w / 2 - cx, h / 2 - h))

    # ATEŞ TOPU: saat tersine 90 (PIL ROTATE_90)
    ball = frames(os.path.join(SRC, "ates_topu_dikey.gif"), Image.Transpose.ROTATE_90)
    bb = union_bbox(ball)
    out = os.path.join(ROOT, "assets", "fx", "shaman_kor")
    w, h = sheet(ball, bb, os.path.join(out, "ates_topu_sheet.png"))
    write_sprite_frames(os.path.join(out, "ates_topu_frames.tres"), "res://assets/fx/shaman_kor/ates_topu_sheet.png", w, h,
                        [("fly", (0, 0), len(ball), True, FPS)])
    cx, cy = bright_center(ball, bb)
    print("top kare %dx%d, bas merkezi (%.1f, %.1f) -> ofset (%.1f, %.1f)" % (w, h, cx, cy, w / 2 - cx, h / 2 - cy))


if __name__ == "__main__":
    main()
