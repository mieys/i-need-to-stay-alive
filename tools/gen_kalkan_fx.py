# -*- coding: utf-8 -*-
"""KALKAN sanatı + efekt sayfaları (madde 338; prototip madde 330/333, kullanıcı seçimi 2026-10-20: görünüş B "Şövalye", efekt D
"Hayalet Kalkan").

Çizim prototipin AYNI fonksiyonlarıyla (tools/proto_20261020/kalkan_yon.py draw_view, kalkan_proto.py D efekti), deterministik.
Görünüş sırası (scripts/kalkan_bash_math.gd VIEWS ile aynı): 0 ön (hedef aşağı) / 1 50° / 2 72° (yan) / 3 130° / 4 arka (hedef yukarı);
sola bakanlar flip_h ile ayna. 1 sanat px = 0,575 dünya px (Zanaatkâr silahlarıyla aynı).

Çıktılar:
  assets/weapons/zanaat/kalkan_L<1..5>.png   silah ikonu = ön görünüş (dükkan/envanter/kart + dinlenme, weapon_tier_art.gd)
  assets/weapons/kalkan/views_L<1..5>.png    5 görünüş yan yana (5 x 48 px), kod AtlasTexture ile keser
  assets/fx/kalkan/ghost_L<1..5>.png         aynı 5 görünüşün düz altın-krem silüeti (hayalet kalkan, alfa koddan)
  assets/fx/kalkan/ring_sheet.png  + frames  vurulan yaratığın ayağında kırık halka (30 fps)
  assets/fx/kalkan/wall_sheet.png  + frames  Final "Yıkılmaz Duvar": karakterin çevresinde büyük kırık halka (30 fps)
Çalıştırma: python tools/gen_kalkan_fx.py   (sonra Godot --headless --import)
"""
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools", "proto_20261020"))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import kalkan_proto as KP  # noqa: E402  (topuz_proto tuvalini kurar)
import kalkan_yon as KY  # noqa: E402
import topuz_proto as TP  # noqa: E402
import mermi_proto as MP  # noqa: E402
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

N = 48
ART_OUT = os.path.join(ROOT, "assets", "weapons", "zanaat")
VIEW_OUT = os.path.join(ROOT, "assets", "weapons", "kalkan")
FX_OUT = os.path.join(ROOT, "assets", "fx", "kalkan")
GHOST_RGB = (255, 236, 168)  # prototip D silüet rengi (kalkan_proto.py)
FPS = 30.0

## Final halkası (70 dünya px) için tuval büyür.
TP.FXW, TP.FXH = 300, 170
TP._YY, TP._XX = np.mgrid[0:TP.FXH, 0:TP.FXW]
TP.BAYT = (np.array(MP.BAY, np.float32)[TP._YY & 3, TP._XX & 3] + 0.5) / 16.0


def to_im(lay):
    return Image.fromarray(np.clip(lay.a, 0, 255).astype(np.uint8), "RGBA")


def save_sheet(frames, name):
    cx, cy = TP.FXW // 2, TP.FXH // 2
    hx = hy = 0
    for im in frames:
        bb = im.getbbox()
        if bb:
            hx = max(hx, cx - bb[0], bb[2] - cx)
            hy = max(hy, cy - bb[1], bb[3] - cy)
    hx, hy = hx + 1, hy + 1
    box = (cx - hx, cy - hy, cx + hx, cy + hy)
    frames = [im.crop(box) for im in frames]
    w, h = frames[0].size
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, im in enumerate(frames):
        sheet.paste(im, (i * w, 0))
    os.makedirs(FX_OUT, exist_ok=True)
    png = os.path.join(FX_OUT, "%s_sheet.png" % name)
    sheet.save(png)
    print("wrote", png, sheet.size, "kare", len(frames), "boy", (w, h))
    write_sprite_frames(os.path.join(FX_OUT, "%s_frames.tres" % name), "res://assets/fx/kalkan/%s_sheet.png" % name, w, h,
                        [("play", (0, 0), len(frames), False, FPS)])


def ring_frames(rx0, ry0, rx1, ry1, w, life, nbreak, brk):
    out = []
    q = 0
    while True:
        L = TP.Lay()
        TP.np_ring(L, (0.0, 0.0), rx0, ry0, rx1, ry1, w, KP.GHOST, (q / FPS) / life, nbreak=nbreak, phase=0.0, ol=KP.GHOST_OL,
                   fade=1.0, brk=brk)
        im = to_im(L)
        if im.getbbox() is None and q > 1:
            break
        out.append(im)
        q += 1
    return out


def ghost(img):
    a = np.asarray(img.convert("RGBA")).copy()
    m = a[..., 3] > 0
    a[m, 0:3] = GHOST_RGB
    a[m, 3] = 255
    return Image.fromarray(a, "RGBA")


def main():
    views = KY.build()
    os.makedirs(VIEW_OUT, exist_ok=True)
    os.makedirs(FX_OUT, exist_ok=True)
    for lv in range(1, 6):
        views[(lv, 0)].save(os.path.join(ART_OUT, "kalkan_L%d.png" % lv))
        vs = Image.new("RGBA", (N * len(KY.ANGLES), N), (0, 0, 0, 0))
        gs = Image.new("RGBA", (N * len(KY.ANGLES), N), (0, 0, 0, 0))
        for i, yaw in enumerate(KY.ANGLES):
            vs.paste(views[(lv, yaw)], (i * N, 0))
            gs.paste(ghost(views[(lv, yaw)]), (i * N, 0))
        vs.save(os.path.join(VIEW_OUT, "views_L%d.png" % lv))
        gs.save(os.path.join(FX_OUT, "ghost_L%d.png" % lv))
    print("görünüşler + hayaletler yazıldı", KY.ANGLES)
    ## prototip D_fx: np_ring(foot, 3, 1.5 -> 12, 6, w 2, ömür 0,3 sn, 5 kırık, brk 0,5)
    save_sheet(ring_frames(3.0, 1.5, 12.0, 6.0, 2.0, 0.3, 5, 0.5), "ring")
    ## Final: karakterin çevresinde (140 birimlik darbe alanını göstermez, sadece duvar hissi) 0,4 sn
    save_sheet(ring_frames(10.0, 5.0, 70.0, 35.0, 4.0, 0.4, 7, 0.4), "wall")


if __name__ == "__main__":
    main()
