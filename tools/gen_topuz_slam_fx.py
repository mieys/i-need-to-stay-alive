# -*- coding: utf-8 -*-
"""Topuz "Yer Sarsıntısı" efekt sayfaları (CLAUDE.md madde 235; prototip madde 232 A, kullanıcı seçimi 2026-10-17).

Çizim prototipin AYNI fonksiyonlarıyla (tools/proto_20261017/topuz_proto.py A_fx + A_live), deterministik. Çerçeve: kare
merkezi = hedefin saldırı anındaki konumu, sağa saldırı (sola saldırıda kod flip_h verir - kareler merkeze göre simetrik
kırpılır), 1 sanat px = 0,575 dünya px (topuz_slam_math.gd FX_WORLD_PX; sahne ölçeği 1, kod global_scale ile ayarlar).
Üç sayfa (scripts/topuz_slam_math.gd zaman çizelgesi):
  - ground: çukur + çatlaklar + toz dalgası (alan sınırına kadar), 30 fps, TEMAS anından (0,27 sn) - yaratıkların ALTINDA
  - top:    çarpma yıldızı + toz bulutu + taş kırıntıları, 30 fps, temas anından - her şeyin üstünde
  - smear:  iniş izi, 60 fps (iniş 0,06 sn sürüyor, 30 fps'te 2 kare kalıyordu), inişin başından (0,21 sn) - topuzun altında

Çıktılar: assets/fx/topuz_slam/{ground,top,smear}_sheet.png + *_frames.tres ("play", tek sefer).
Çalıştırma: python tools/gen_topuz_slam_fx.py   (sonra Godot --headless --import; kare boyu değişirse şart)
"""
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools", "proto_20261017"))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import topuz_proto as T  # noqa: E402
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

OUT = os.path.join(ROOT, "assets", "fx", "topuz_slam")
SMEAR_FPS = 60.0
SMEAR_T0 = 0.21  # inişin başı (topuz_slam_math.gd SMEAR_AT)


def to_im(lay):
    return Image.fromarray(np.clip(lay.a, 0, 255).astype(np.uint8), "RGBA")


def ground_top_frames():
    ground, top = [], []
    q = 0
    while True:
        Ls = {"g": T.Lay(), "b": T.Lay(), "f": T.Lay()}
        T.A_fx(Ls, T.A_HIT + q / float(T.FXFPS))
        g, f = to_im(Ls["g"]), to_im(Ls["f"])
        if g.getbbox() is None and f.getbbox() is None and q > 3:
            break
        ground.append(g)
        top.append(f)
        q += 1
    return ground, top


def smear_frames(tr):
    out = []
    q = 1  # t = SMEAR_T0 karesi boş (iz henüz yok)
    while True:
        L = T.Lay()
        T.A_live(L, tr, SMEAR_T0 + q / SMEAR_FPS)
        im = to_im(L)
        if im.getbbox() is None:
            break
        out.append(im)
        q += 1
    return out


def save_sheet(frames, name, fps):
    """Kare merkezi (hedef) yerinde kalsın diye merkeze göre simetrik kırp, yan yana diz, .tres yaz."""
    # Sondaki boş kareler kalsın (zaman çizelgesi bozulmasın) ama baştaki/ortadakiler de - sadece kırpma ortak.
    cx, cy = T.FXW // 2, T.FXH // 2
    hx = hy = 0
    for im in frames:
        bb = im.getbbox()
        if bb:
            hx = max(hx, cx - bb[0], bb[2] - cx)
            hy = max(hy, cy - bb[1], bb[3] - cy)
    hx, hy = hx + 1, hy + 1
    frames = [im.crop((cx - hx, cy - hy, cx + hx, cy + hy)) for im in frames]
    w, h = frames[0].size
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, im in enumerate(frames):
        sheet.paste(im, (i * w, 0))
    os.makedirs(OUT, exist_ok=True)
    png = os.path.join(OUT, "%s_sheet.png" % name)
    sheet.save(png)
    print("wrote", png, sheet.size, "kare", len(frames), "boy", (w, h), "%.0f fps" % fps)
    write_sprite_frames(os.path.join(OUT, "%s_frames.tres" % name), "res://assets/fx/topuz_slam/%s_sheet.png" % name, w, h,
                        [("play", (0, 0), len(frames), False, float(fps))])


def main():
    ground, top = ground_top_frames()
    # Yer ve üst katman aynı anda başlar ama boyları farklı: her biri kendi son dolu karesinde biter.
    for frames, name in ((ground, "ground"), (top, "top")):
        last = max(i for i, im in enumerate(frames) if im.getbbox() is not None)
        save_sheet(frames[:last + 1], name, T.FXFPS)
    save_sheet(smear_frames(T.A_track()), "smear", SMEAR_FPS)


if __name__ == "__main__":
    main()
