# -*- coding: utf-8 -*-
"""Bıçak "Kıvılcım Saplama" efekt sayfası (CLAUDE.md madde 231; prototip madde 228 B, kullanıcı seçimi 2026-10-17).

Çizim prototipin AYNI fonksiyonlarıyla (tools/proto_20261017/bicak_proto.py B_fx: hız çizgileri, 4 kollu yıldız, son saplamada
kırılan halka) + prototipte ekranda simüle edilen krem kırıntılar burada sayfaya gömülür (deterministik). Kareler 30 fps'te,
saldırı başından (t = 0) itibaren - bıçak ikonunun hareketi (scripts/dagger_stab_math.gd STEPS) ile aynı zaman çizelgesi:
temaslar 0,13 / 0,23 / 0,33 sn. Çerçeve: kare merkezi = vuruş merkezi (hedefin 8 dünya px önü), +x = saldırı yönü,
1 sanat px = 0,575 dünya px (dagger_stab_math.gd FX_WORLD_PX; sahne ölçeği 1, kod global_scale ile ayarlar).

Çıktılar: assets/fx/dagger_stab/stab_sheet.png + stab_frames.tres ("play", tek sefer, 30 fps).
Çalıştırma: python tools/gen_dagger_stab_fx.py   (sonra Godot --headless --import; kare boyu değişirse şart)
"""
import math
import os
import random
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools", "proto_20261017"))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import bicak_proto as BP  # noqa: E402
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

OUT = os.path.join(ROOT, "assets", "fx", "dagger_stab")
FPS = BP.FXFPS  # 30
CHIP_COLS = BP.cl("#fff2c4 #fbd27a #ee9c42")
CHIPS_PER_STAB = (4, 4, 7)
CHIP_TIP = 7.0  # prototip Lane.hit_point: ikon + 7 dünya px bıçak yönünde


def chips():
    """Her temasta ileri koniye saçılan krem kırıntılar (FX pikseli uzayında; prototipte 40-100 ekran px/sn = 35-87 FX px/sn)."""
    rng = random.Random(2290)
    out = []
    for (back, inn, _t0, tc, _r), n in zip(BP.B_STABS, CHIPS_PER_STAB):
        tip = BP._tip(back, inn, CHIP_TIP)
        x0, y0 = BP.fx_px(tip)
        for _ in range(n):
            th = rng.uniform(-0.9, 0.9)
            sp = rng.uniform(35.0, 87.0)
            out.append((tc, rng.uniform(0.12, 0.25), x0, y0, math.cos(th) * sp, math.sin(th) * sp))
    return out


def draw_chips(L, t, cs):
    for (t0, life, x0, y0, vx, vy) in cs:
        age = t - t0
        if age < 0.0 or age >= life:
            continue
        k = age / life
        col = CHIP_COLS[min(len(CHIP_COLS) - 1, int(k * len(CHIP_COLS)))]
        L.put(int(math.floor(x0 + vx * age)), int(math.floor(y0 + vy * age)), col, 1.0 - k * k)


def main():
    cs = chips()
    frames = []
    q = 0
    while True:
        t = q / float(FPS)
        L = BP.FxL()
        BP.B_fx(L, t)
        draw_chips(L, t, cs)
        empty = L.im.getbbox() is None
        if empty and t > max(c[0] + c[1] for c in cs) and t > 0.45:
            break
        frames.append(L.im)
        q += 1
    # Kare merkezi (vuruş merkezi) yerinde kalsın diye simetrik kırp.
    cx, cy = BP.FXW // 2, BP.FXH // 2
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
    png = os.path.join(OUT, "stab_sheet.png")
    sheet.save(png)
    print("wrote", png, sheet.size, "kare", len(frames), "boy", (w, h))
    write_sprite_frames(os.path.join(OUT, "stab_frames.tres"), "res://assets/fx/dagger_stab/stab_sheet.png", w, h,
                        [("play", (0, 0), len(frames), False, float(FPS))])


if __name__ == "__main__":
    main()
