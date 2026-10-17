# -*- coding: utf-8 -*-
"""Pençe "Kanca Çekiş" efekt sayfaları (CLAUDE.md madde 237; prototip madde 236 B, kullanıcı seçimi 2026-10-17).

Çizim prototipin AYNI fonksiyonlarıyla (tools/proto_20261017/pence_proto.py B_fx + B_live), deterministik. Prototip saldırıyı
~25 derece aşağı-sağa çiziyor; burada çerçeve SAĞA (0 derece) kurulur - oyunda kod efekti saldırı yönüyle döndürür (sola
saldırıda ayrıca flip_v, kareler merkeze göre simetrik kırpılır). Kare merkezi = hedef + ANCHOR (pence_hook_math.gd), 1 sanat
px = 0,575 dünya px (FX_WORLD_PX; sahne ölçeği 1, kod global_scale ile ayarlar).
Üç sayfa (scripts/pence_hook_math.gd zaman çizelgesi):
  - smear:  atılışta tırnak uçlarının hız izi, 60 fps (atılış 0,045 sn), atılışın başından (SMEAR_AT 0,10) - pençenin altında
  - top:    saplanma yıldızı + darbe çizgileri + 3 yırtık + geri saçılan kıvılcım, 30 fps, 1. temastan (0,145) - her şeyin üstünde
  - ground: ayak dibinde toz, 30 fps, 2. temastan (0,235) - yaratıkların altında

Çıktılar: assets/fx/pence_hook/{smear,top,ground}_sheet.png + *_frames.tres ("play", tek sefer).
Çalıştırma: python tools/gen_pence_hook_fx.py   (sonra Godot --headless --import; kare boyu değişirse şart)
"""
import math
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools", "proto_20261017"))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import pence_proto as P  # noqa: E402
import topuz_proto as T  # noqa: E402
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

OUT = os.path.join(ROOT, "assets", "fx", "pence_hook")
SMEAR_FPS = 60.0
SMEAR_T0 = 0.10  # atılışın başı (pence_hook_math.gd SMEAR_AT)

## Çerçeveyi sağa çevir: prototipin modül değişkenleri çağrı anında okunur (L2W/LP/B_fx), kıvılcım açıları yeniden kurulur.
P.DIRV = (1.0, 0.0)
P.DIR_ANG = 0.0
P.SC = (P.TGT[0] - 8.0, P.TGT[1])
P.B_SPARKS = P._sparks(9, 9, 135.0, 225.0, (70.0, 150.0), (0.16, 0.30))


def to_im(lay):
    return Image.fromarray(np.clip(lay.a, 0, 255).astype(np.uint8), "RGBA")


def fx_frames(tr, t0, key):
    out = []
    q = 0
    while True:
        Ls = {"g": T.Lay(), "f": T.Lay()}
        P.B_fx(Ls, tr, t0 + q / float(P.FXFPS))
        im = to_im(Ls[key])
        if im.getbbox() is None and q > 3:
            break
        out.append(im)
        q += 1
    last = max(i for i, im in enumerate(out) if im.getbbox() is not None)
    return out[:last + 1]


def smear_frames(tr):
    out = []
    q = 1  # t = SMEAR_T0 karesi boş (iz henüz yok)
    while True:
        L = T.Lay()
        P.B_live(L, tr, SMEAR_T0 + q / SMEAR_FPS)
        im = to_im(L)
        if im.getbbox() is None:
            break
        out.append(im)
        q += 1
    return out


def save_sheet(frames, name, fps):
    """Kare merkezi (çerçeve orijini) yerinde kalsın diye merkeze göre simetrik kırp (dönme + flip_v merkez etrafında), yan
    yana diz, .tres yaz."""
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
    write_sprite_frames(os.path.join(OUT, "%s_frames.tres" % name), "res://assets/fx/pence_hook/%s_sheet.png" % name, w, h,
                        [("play", (0, 0), len(frames), False, float(fps))])


def main():
    tr = P.B_track()
    ## temas noktası kontrolü: saplanmada ikon merkezi çerçevede (4, 0) (pence_hook_math.gd STEPS[1])
    x, y = tr.pose(P.B_HIT1 - 1e-4)[:2]
    assert math.hypot(x - (P.TGT[0] + 4.0), y - P.TGT[1]) < 0.2, (x, y)
    save_sheet(smear_frames(tr), "smear", SMEAR_FPS)
    save_sheet(fx_frames(tr, P.B_HIT1, "f"), "top", P.FXFPS)
    save_sheet(fx_frames(tr, P.B_HIT2, "g"), "ground", P.FXFPS)


if __name__ == "__main__":
    main()
