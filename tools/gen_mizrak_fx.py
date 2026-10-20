# -*- coding: utf-8 -*-
"""MIZRAK sanatı + efekt sayfaları (madde 305; prototip madde 300, kullanıcı seçimi 2026-10-19: görünüş D "Püsküllü", efekt A "Işık Hattı").

Çizim prototipin AYNI fonksiyonlarıyla (tools/proto_20261019/mizrak_sanat.py D_spear, mizrak_proto.py A_fx_t / A_live_t / A_live_c),
deterministik. Prototip saldırıyı ~7 derece aşağı-sağa çiziyor; burada çerçeve SAĞA (0 derece) kurulur - oyunda kod efekti saldırı yönüyle
döndürür (sola saldırıda flip_v). Kare merkezi = hedef + ANCHOR (scripts/mizrak_thrust_math.gd), 1 sanat px = 0,575 dünya px (FX_WORLD_PX).

Çıktılar:
  assets/weapons/zanaat/mizrak_L<1..5>.png    silah ikonu (Zanaatkâr seviyeleri, weapon_tier_art.gd)
  assets/fx/mizrak/line_sheet.png  + frames    saplama: ucun hız izi + uçtan hattın sonuna krem ışık çizgisi, 60 fps, saplamanın başından (SMEAR_AT)
  assets/fx/mizrak/hit_sheet.png   + frames    delinen her yaratıkta yıldız + yana kırıntı, 30 fps (mızrak yeniden belirirken de)
  assets/fx/mizrak/trail_sheet.png + frames    cirit: uçan mızrağın arkasındaki krem iz (döngü, uç sağ kenarda), 30 fps
  assets/fx/mizrak/end_sheet.png   + frames    cirit sonu: yıldız + ileri saçılan kırıntı, 30 fps
Çalıştırma: python tools/gen_mizrak_fx.py   (sonra Godot --headless --import)
"""
import math
import os
import shutil
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools", "proto_20261019"))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import mizrak_proto as M  # noqa: E402  (tuvali de kurar: topuz_proto Lay/FXW)
import topuz_proto as T  # noqa: E402
import bicak_proto as BP  # noqa: E402
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

OUT = os.path.join(ROOT, "assets", "fx", "mizrak")
ART_OUT = os.path.join(ROOT, "assets", "weapons", "zanaat")
SMEAR_FPS = 60.0

## Çerçeveyi sağa çevir: prototipin modül değişkenleri çağrı anında okunur (LW/LO), kırıntı açıları yeniden kurulur.
M.CA, M.SA, M.DIR_ANG = 1.0, 0.0, 0.0
M.A_SHARDS = {i: M._sparks(30 + i, 4, 65.0, 115.0, (40.0, 90.0), (0.10, 0.20), both=True) for i in range(5)}
M.A_END = M._sparks(41, 7, -35.0, 35.0, (50.0, 120.0), (0.12, 0.24))
M.ENEMIES = []  # hat sayfasında yaratık yıldızı yok (ayrı "hit" sayfası, yaratığın kendi konumunda çıkar)


def to_im(lay):
    return Image.fromarray(np.clip(lay.a, 0, 255).astype(np.uint8), "RGBA")


def save_sheet(frames, name, fps, loop=False, sym=True):
    """sym: kare merkezi (çerçeve orijini) yerinde kalsın diye merkeze göre simetrik kırp; değilse sıkı kırp."""
    cx, cy = T.FXW // 2, T.FXH // 2
    if sym:
        hx = hy = 0
        for im in frames:
            bb = im.getbbox()
            if bb:
                hx = max(hx, cx - bb[0], bb[2] - cx)
                hy = max(hy, cy - bb[1], bb[3] - cy)
        hx, hy = hx + 1, hy + 1
        box = (cx - hx, cy - hy, cx + hx, cy + hy)
    else:
        bbs = [im.getbbox() for im in frames if im.getbbox()]
        box = (min(b[0] for b in bbs), min(b[1] for b in bbs), max(b[2] for b in bbs), max(b[3] for b in bbs))
        hy = max(cy - box[1], box[3] - cy) + 1
        box = (box[0], cy - hy, box[2], cy + hy)  # dikeyde merkez korunur
    frames = [im.crop(box) for im in frames]
    w, h = frames[0].size
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, im in enumerate(frames):
        sheet.paste(im, (i * w, 0))
    os.makedirs(OUT, exist_ok=True)
    png = os.path.join(OUT, "%s_sheet.png" % name)
    sheet.save(png)
    print("wrote", png, sheet.size, "kare", len(frames), "boy", (w, h), "%.0f fps" % fps, "kutu", box)
    write_sprite_frames(os.path.join(OUT, "%s_frames.tres" % name), "res://assets/fx/mizrak/%s_sheet.png" % name, w, h,
                        [("play", (0, 0), len(frames), loop, float(fps))])
    return box


def line_frames(d):
    out = []
    q = 1  # SMEAR_AT karesi boş (iz henüz yok)
    while True:
        Ls = {"g": T.Lay(), "f": T.Lay()}
        t = d.t_thr0 + q / SMEAR_FPS
        M.A_live_t(d, Ls["f"], t)
        M.A_fx_t(d, Ls, t)
        im = to_im(Ls["f"])
        if im.getbbox() is None and t > d.hit + 0.05:
            break
        out.append(im)
        q += 1
    return out


def oneshot_frames(fn, n_max=40):
    out = []
    for q in range(n_max):
        L = T.Lay()
        fn(L, q / float(M.FXFPS))
        im = to_im(L)
        if im.getbbox() is None and q > 1:
            break
        out.append(im)
    return out


def hit_fx(L, age):
    if age < 0.10:
        BP.star(L, (0.0, 0.0), 6.5, M.CREAM, age / 0.10)
    T.draw_sparks(L, (0.0, 0.0), M.A_SHARDS[1], age, M.CREAM_L, g=120.0)


def end_fx(L, age):
    if age < 0.12:
        BP.star(L, (0.0, 0.0), 7.0, M.CREAM, age / 0.12)
    T.draw_sparks(L, (0.0, 0.0), M.A_END, age, M.CREAM_L, g=90.0)


TRAIL_LEN = 52.0  # dünya px (k = 1): ~0,07 sn x 760 px/sn


def trail_frames():
    """Uç tuval merkezinde (0, 0), iz -x yönünde; 3 kare hafif nefes (kalınlık/boy) - döngü."""
    out = []
    for i, (w, ln) in enumerate(((5.0, 1.0), (4.6, 0.94), (4.8, 0.97))):
        L = T.Lay()
        n = 12
        pts = [(-TRAIL_LEN * ln * j / (n - 1), 0.0) for j in range(n)]
        T.np_trail(L, pts, w, M.CREAM_W, M.CREAM_W_OL)
        out.append(to_im(L))
    return out


def main():
    M.setup()  # sanatı üretir + yönleri kurar
    ## oyun ikonları: D "Püsküllü"
    for lv in range(1, 6):
        shutil.copyfile(os.path.join(M.MS.ART, "mizrak_D_L%d.png" % lv), os.path.join(ART_OUT, "mizrak_L%d.png" % lv))
    print("ikonlar", ART_OUT, "mizrak_L1..5.png")
    d = M.DIRS["A"]  # hareket = A (Işık Hattı); uç ofseti D ile aynı (27,2)
    print("temas %.4f  saplama başı %.3f  uç %.3f" % (d.hit, d.t_thr0, d.tipd))
    save_sheet(line_frames(d), "line", SMEAR_FPS)
    save_sheet(oneshot_frames(hit_fx), "hit", M.FXFPS)
    save_sheet(oneshot_frames(end_fx), "end", M.FXFPS)
    box = save_sheet(trail_frames(), "trail", M.FXFPS, loop=True, sym=False)
    print("iz: uç sağ kenarda değil, kutunun sağ kenarı merkezden %d px sağda" % (box[2] - T.FXW // 2))


if __name__ == "__main__":
    main()
