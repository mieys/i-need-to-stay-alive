# -*- coding: utf-8 -*-
"""Tırpan "Kara Hasat" efekt sayfaları (madde 512; prototip madde 507 v2 D3, kullanıcı seçimi 2026-11-09 + "dumanlar daha çabuk solsun").

Çizim prototipin AYNI fonksiyonlarıyla (tools/proto_20261109/tirpan_proto.py D3_live / D3_fx), deterministik. Prototip saldırıyı
~25 derece aşağı-sağa çiziyor; burada çerçeve SAĞA (0 derece) kurulur - oyunda kod efekti saldırı yönüyle döndürür (sola saldırıda
ayrıca flip_v; kareler merkeze göre simetrik kırpılır). Kare merkezi = hedef + ANCHOR (tirpan_reap_math.gd), 1 sanat px = 0,575
dünya px (FX_WORLD_PX; sahne ölçeği 1, kod global_scale ile ayarlar). Üç sayfa da biçme ÖNCESİ gerilmenin başında (SPAWN_AT =
tirpan_reap_math.gd FX_AT, 1. adımın sonu) çıkar; baştaki boş kareler zamanlamanın parçası, kırpılmaz:
  - trail:  koyu hilal iz + hayalet bıçak + gerçek bıçağın kızıl izi, 60 fps (biçme 0,10 sn: 30 fps'te bıçakla iz arası açılıyordu),
            tırpanın altında (z 0)
  - top:    hedefteki kesik + kızıl korlar, 30 fps, her şeyin üstünde (z 60)
  - ground: saydam mor duman, 30 fps, yaratıkların altında (z -1)

Çıktılar: assets/fx/tirpan/{trail,top,ground}_sheet.png + *_frames.tres ("play", tek sefer).
Çalıştırma: python -I tools/gen_tirpan_fx.py   (sonra Godot --headless --import; kare boyu değişirse şart)
"""
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools", "proto_20261109"))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import tirpan_proto as P  # noqa: E402
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

TP, PP = P.TP, P.PP
OUT = os.path.join(ROOT, "assets", "fx", "tirpan")
SPAWN_AT = P.A_WIND  # = tirpan_reap_math.gd FX_AT
TRAIL_FPS = 60.0
FX_FPS = 30.0

## Çerçeveyi sağa çevir: prototipin modül değişkenleri çağrı anında okunur; yöne bağlı türetilmişler yeniden kurulur.
P.DIR_ANG, P.DIRV, P.PERP = 0.0, (1.0, 0.0), (0.0, 1.0)
PP.DIR_ANG, PP.DIRV = 0.0, (1.0, 0.0)
P.V_TR = P.big_track()
P.V_HIT1 = P.angle_time(P.V_TR, -36.0, P.A_T0, P.A_T1)
P.D3_EMBERS, P.D3_PUFFS = P.d3_particles(P.V_TR)


def to_im(lay):
    return Image.fromarray(np.clip(lay.a, 0, 255).astype(np.uint8), "RGBA")


def collect(fps, draw):
    out = []
    q = 0
    seen = False
    while q < 400:
        im = draw(SPAWN_AT + q / fps)
        empty = im.getbbox() is None
        if seen and empty:
            break
        seen = seen or not empty
        out.append(im)
        q += 1
    return out


def trail_frame(t):
    L = P.Lay2()
    P.D3_live(L, P.V_TR, t)
    return to_im(L)


def fx_frame(key):
    def f(t):
        Ls = {"g": P.Lay2(), "f": P.Lay2()}
        P.D3_fx(Ls, P.V_TR, t)
        return to_im(Ls[key])
    return f


def save_sheet(frames, name, fps):
    """Kare merkezi (çerçeve orijini) yerinde kalsın diye merkeze göre simetrik kırp (dönme + flip_v merkez etrafında), yan
    yana diz, .tres yaz."""
    cx, cy = TP.FXW // 2, TP.FXH // 2
    hx = hy = 0
    for im in frames:
        bb = im.getbbox()
        if bb:
            hx = max(hx, cx - bb[0], bb[2] - cx)
            hy = max(hy, cy - bb[1], bb[3] - cy)
            assert bb[0] > 0 and bb[1] > 0 and bb[2] < TP.FXW and bb[3] < TP.FXH, "%s efekt tuvaline sığmıyor: %s" % (name, bb)
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
    write_sprite_frames(os.path.join(OUT, "%s_frames.tres" % name), "res://assets/fx/tirpan/%s_sheet.png" % name, w, h,
                        [("play", (0, 0), len(frames), False, float(fps))])


def main():
    print("temas 1 = %.4f sn, temas 2 = %.4f sn (tirpan_reap_math.gd CONTACTS ile aynı olmalı)" % (P.V_HIT1, P.V_HIT2))
    save_sheet(collect(TRAIL_FPS, trail_frame), "trail", TRAIL_FPS)
    save_sheet(collect(FX_FPS, fx_frame("f")), "top", FX_FPS)
    save_sheet(collect(FX_FPS, fx_frame("g")), "ground", FX_FPS)


if __name__ == "__main__":
    main()
