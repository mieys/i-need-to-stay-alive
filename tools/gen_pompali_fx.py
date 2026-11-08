"""Pompalı Tüfek efektleri (madde 448 yeniden tasarım, 2026-11-07; kullanıcı: "mermiler efektler v.s çok kötü, yeniden tasarla").

Çıktı:
  assets/fx/pompali/muzzle_sheet.png + muzzle_frames.tres  - NAMLU PATLAMASI: geniş alev konisi (krem çekirdek, 3 dil) -> diller kopup
        ileri savrulur -> kor + namlu dumanı (sol üst ışıklı dolu kütleler) ileri/yukarı süzülüp hilale aşınarak söner. 10 kare 72x48,
        28 fps, ucu +x; namlu noktası karede (AX, AY) - sahne `offset` bunu orijine taşır.
  assets/fx/pompali/hit_sheet.png + hit_frames.tres        - SAÇMA İSABETİ: küçük altın kıvılcım patlaması + toz, 5 kare 26x26, 30 fps.
  assets/weapons/mermi/pompali_govde.png                   - SAÇMA: 12x3 sıcak ışık çizgisi (krem baş, turuncu kuyruk, düz bantlı saydamlık).

Doku pikseli silah ızgarasında (weapon_tier_art.gd WORLD_PX 0,575 dünya px): sahneler bu ölçekte gösterilir (bkz. scenes/fx_pompali_*).
Dil tools/pixfx.py (dolu kütle, 5 tonlu rampa, 1 px kontur, krem parlama, hilale aşınarak sönme - noktalı/dither yok).
Kullanım: python -I tools/gen_pompali_fx.py
"""
import math
import os
import random
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixfx as P  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx", "pompali")
MERMI = os.path.join(ROOT, "assets", "weapons", "mermi")

MW, MH = 72, 48
AX, AY = 7.0, 24.0  # namlu noktası (karede)
MUZZLE_FRAMES = 10
MUZZLE_FPS = 28.0

HW = HH = 26
HIT_FRAMES = 5
HIT_FPS = 30.0

GOLD = [(86, 40, 14), (196, 110, 30), (246, 176, 56), (255, 226, 130), (255, 250, 220)]
SMOKE = P.SMOKE_LIGHT
SMOKE_DK = P.SMOKE


def _fan(cv, length, half_deg, spikes, phase, pal, hot, mouth=True):
    """Namludan açılan YELPAZE alev: ucu dişli (spikes diş), yanlara doğru kısalır. Ton namludan uzaklığa göre (hot: krem
    çekirdeğin oranı); 1 px koyu kontur. Döner: maske."""
    X, Y = cv.grid()
    dx, dy = X - AX, Y - AY
    r = np.hypot(dx, dy)
    th = np.arctan2(dy, dx)
    half = math.radians(half_deg)
    u = np.clip(np.abs(th) / half, 0.0, 1.5)
    teeth = 0.5 + 0.5 * np.cos(th / half * math.pi * spikes * 0.5 + phase)
    front = length * (0.70 + 0.30 * teeth) * (1.0 - 0.35 * u ** 3.0)
    m = (np.abs(th) <= half) & (r <= front) & (dx > -1.0)
    if mouth:
        m |= r <= 3.2  # namlu ağzı
    if not m.any():
        return m
    q = np.where(front > 0.1, r / np.maximum(front, 0.1), 1.0)
    tone = np.where(q < hot, 4, np.where(q < hot + 0.22, 3, np.where(q < hot + 0.5, 2, 1)))
    for t in (1, 2, 3, 4):
        cv.put(m & (tone == t), pal[t])
    cv.put(P.outline_of(m) & ~cv.filled(), pal[0])
    return m


def _tongues(cv, specs, pal, cut_k=0.0):
    """Kopmuş alev dilleri: (açı, uzaklık, boy, kalınlık) -> namlu yönünde uzamış dolu elipsler, kenardan içe ısı tonlu."""
    items = []
    for (a, d, ln, w) in specs:
        items.append((AX + math.cos(a) * d, AY + math.sin(a) * d, ln, w, a))
    m = P.ellipses_mask(cv, items)
    if cut_k > 0.0:
        X, Y = cv.grid()
        for (a, d, ln, w) in specs:
            cx = AX + math.cos(a) * (d - ln * (1.1 - cut_k))
            cy = AY + math.sin(a) * (d - ln * (1.1 - cut_k))
            m &= ((X - cx) ** 2 + (Y - cy) ** 2) > (ln * (0.4 + 0.7 * cut_k)) ** 2
    P.heat_fill(cv, m, pal, levels=(1, 2, 3, 9))
    return m


def _smoke(cv, k, seed):
    """Namlu dumanı evresi k (0..1): kümeler ileri + yukarı süzülür, büyür, sonra hilale aşınıp küçülür."""
    rng = random.Random(seed)
    base = [(9, 24, 4.0), (16, 22, 5.0), (24, 25, 4.6), (31, 22, 4.2), (38, 24, 3.4)]
    circles, cuts = [], []
    grow = min(1.0, k * 1.7)
    fade = max(0.0, (k - 0.4) / 0.6)
    for i, (x, y, r) in enumerate(base):
        cx = x + 8.0 * k + i * 1.6 * k + rng.uniform(-1.0, 1.0)
        cy = y - 6.0 * k - rng.uniform(0.0, 2.0) * k
        rr = r * (0.55 + 0.75 * grow) * (1.0 - 0.55 * fade)
        circles.append((cx, cy, rr))
        if fade > 0.0:
            cuts.append((cx + rr * 0.5, cy - rr * 0.4, rr * (0.25 + 0.85 * fade)))
    P.puffs(cv, circles, SMOKE if fade < 0.55 else SMOKE_DK, cut=cuts or None)


def _embers(cv, k, seed, n=6):
    rng = random.Random(seed)
    for i in range(n):
        a = rng.uniform(-0.5, 0.5)
        d = 22 + 28 * k + rng.uniform(-3, 5)
        if rng.random() < 1.0 - k * 0.7:
            cv.px(AX + math.cos(a) * d, AY + math.sin(a) * d - 4 * k, GOLD[3] if i % 2 else GOLD[4])


TONGUES = [(-0.36, 30.0, 8.0, 2.4), (-0.12, 36.0, 10.0, 2.8), (0.14, 34.0, 9.0, 2.6), (0.38, 28.0, 7.0, 2.2)]


def muzzle_frame(f):
    cv = P.Canvas(MW, MH)
    if f == 0:
        _fan(cv, 18, 30, 3, 0.0, P.FIRE, hot=0.45)
        P.disc_flash(cv, AX + 2, AY, 4.0, core=P.WHITE, rim=P.CREAM)
        P.star(cv, AX + 2, AY, 6, core=P.WHITE, arm=P.FIRE[4])
    elif f == 1:
        _fan(cv, 36, 28, 5, 0.0, P.FIRE, hot=0.28)
        P.disc_flash(cv, AX + 2, AY, 3.0, core=P.WHITE)
    elif f == 2:
        _fan(cv, 44, 26, 5, 0.6, P.FIRE, hot=0.12, mouth=False)
        for i, a in enumerate((-0.30, -0.10, 0.10, 0.28)):  # önden fırlayan saçma kıvılcımları
            for s in range(3):
                cv.px(AX + math.cos(a) * (52 + s + i), AY + math.sin(a) * (52 + s + i), P.CREAM if s == 2 else GOLD[3])
    elif f == 3:
        _smoke(cv, 0.0, 7)
        _tongues(cv, TONGUES, P.FIRE)
        _embers(cv, 0.1, 11)
    elif f == 4:
        _smoke(cv, 0.12, 7)
        _tongues(cv, [(a, d + 6, ln * 0.8, w * 0.8) for (a, d, ln, w) in TONGUES], P.EMBER, cut_k=0.45)
        _embers(cv, 0.3, 11)
    elif f == 5:
        _smoke(cv, 0.26, 7)
        _tongues(cv, [(a, d + 10, ln * 0.55, w * 0.6) for (a, d, ln, w) in TONGUES[1:3]], P.EMBER, cut_k=0.8)
        _embers(cv, 0.45, 11, n=4)
    else:
        k = (f - 5) / (MUZZLE_FRAMES - 5.0)
        _smoke(cv, 0.26 + 0.74 * k, 7)
    return cv.image()


def hit_frame(f):
    cv = P.Canvas(HW, HH)
    cx, cy = HW / 2.0, HH / 2.0
    if f == 0:
        P.disc_flash(cv, cx, cy, 2.5, core=P.CREAM, rim=GOLD[4])
        P.star(cv, cx, cy, 4, core=P.WHITE, arm=GOLD[3])
    elif f == 1:
        P.disc_flash(cv, cx, cy, 2.0, core=P.CREAM)
        P.star(cv, cx, cy, 6, core=P.CREAM, arm=GOLD[3], diag=True)
        for a in (-0.7, 0.0, 0.7):  # isabet yönüne (+x) savrulan kıvılcımlar
            for s in range(2):
                cv.px(cx + math.cos(a) * (6 + s), cy + math.sin(a) * (6 + s), GOLD[4] if s else GOLD[3])
    elif f == 2:
        P.puffs(cv, [(cx - 1, cy, 2.6), (cx + 2, cy - 1.5, 2.2), (cx + 1.5, cy + 2, 2.0)], GOLD)
        for a, d in ((-0.8, 7), (0.1, 8), (0.9, 7)):
            cv.px(cx + math.cos(a) * d, cy + math.sin(a) * d, GOLD[4])
    elif f == 3:
        P.puffs(cv, [(cx, cy - 1, 2.8), (cx + 2.5, cy - 2, 2.2)], P.DUST, cut=[(cx + 1.5, cy - 2.5, 2.0)])
        for a, d in ((-0.8, 9), (0.1, 10), (0.9, 9)):
            cv.px(cx + math.cos(a) * d, cy + math.sin(a) * d + 1, GOLD[3])
    else:
        P.puffs(cv, [(cx + 1, cy - 2.5, 2.2), (cx + 3.5, cy - 3, 1.6)], P.DUST, cut=[(cx + 2.5, cy - 3.5, 2.2)])
    return cv.image()


def pellet():
    """13x3 ışık çizgisi: baş (sağ) krem, kuyruk turuncu-kırmızı; saydamlık düz bantlar (dither yok).
    Boyutlar TEK (test_projectile_art: pivot pikseli tam ortada) - 12 genişlik 0,5 px kaydırıyordu, kuyruğa en soluk bir piksel eklendi."""
    from PIL import Image
    im = Image.new("RGBA", (13, 3), (0, 0, 0, 0))
    mid = [(0, (182, 44, 28, 40)), (1, (182, 44, 28, 70)), (2, (182, 44, 28, 110)), (3, (220, 90, 32, 150)), (4, (220, 90, 32, 190)),
           (5, (236, 112, 36, 230)), (6, (246, 146, 48, 255)), (7, (246, 176, 56, 255)), (8, (255, 206, 96, 255)),
           (9, (255, 226, 130, 255)), (10, (255, 242, 178, 255)), (11, (255, 250, 228, 255)), (12, (255, 250, 228, 255))]
    for x, c in mid:
        im.putpixel((x, 1), c)
    for x, c in ((7, (236, 112, 36, 150)), (8, (246, 146, 48, 200)), (9, (246, 176, 56, 230)), (10, (255, 206, 96, 230)),
                 (11, (246, 176, 56, 170))):
        im.putpixel((x, 0), c)
        im.putpixel((x, 2), c)
    return im


def _strip(frames):
    from PIL import Image
    w, h = frames[0].size
    out = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        out.paste(fr, (i * w, 0))
    return out


def _border_ok(frames, name):
    for i, fr in enumerate(frames):
        a = np.array(fr)[:, :, 3]
        if a[0, :].any() or a[-1, :].any() or a[:, 0].any() or a[:, -1].any():
            print("UYARI: %s kare %d tuval kenarına değiyor" % (name, i))


def _write_tres(path, png_res, w, h, n, fps):
    lines = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (n + 2), "",
             '[ext_resource type="Texture2D" path="%s" id="1"]' % png_res, ""]
    for i in range(n):
        lines += ['[sub_resource type="AtlasTexture" id="AT_%d"]' % i, 'atlas = ExtResource("1")',
                  "region = Rect2(%d, 0, %d, %d)" % (i * w, w, h), ""]
    fr = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("AT_%d")\n}' % i for i in range(n))
    lines += ["[resource]", "animations = [{", '"frames": [%s],' % fr, '"loop": false,', '"name": &"play",',
              '"speed": %.1f' % fps, "}]", ""]
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))


def main():
    os.makedirs(OUT, exist_ok=True)
    mz = [muzzle_frame(i) for i in range(MUZZLE_FRAMES)]
    _border_ok(mz, "muzzle")
    _strip(mz).save(os.path.join(OUT, "muzzle_sheet.png"))
    _write_tres(os.path.join(OUT, "muzzle_frames.tres"), "res://assets/fx/pompali/muzzle_sheet.png", MW, MH, MUZZLE_FRAMES, MUZZLE_FPS)
    ht = [hit_frame(i) for i in range(HIT_FRAMES)]
    _border_ok(ht, "hit")
    _strip(ht).save(os.path.join(OUT, "hit_sheet.png"))
    _write_tres(os.path.join(OUT, "hit_frames.tres"), "res://assets/fx/pompali/hit_sheet.png", HW, HH, HIT_FRAMES, HIT_FPS)
    pellet().save(os.path.join(MERMI, "pompali_govde.png"))
    print("ok", OUT)


if __name__ == "__main__":
    main()
