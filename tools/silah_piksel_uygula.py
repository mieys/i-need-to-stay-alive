# -*- coding: utf-8 -*-
"""ESKİ SİLAH İKONLARINI PİKSEL IZGARASINA OTURTUR (madde 410, 2026-11-06; kullanıcı seçimi "B": kendi silah çizimlerinin ızgarası 0,575 dünya px).
Kaynak: madde 402'de geri gelen Zanaatkâr öncesi ikonlar (200-250 px, binlerce renk, yumuşatılmış; oyunda 1 doku px = 0,10-0,21 dünya px).
Her dosya YERİNDE yeniden yazılır, TUVAL BOYU AYNI: içerik n x n doku pikselli bloklardan oluşur (n = 0,575 / dünya doku pikseli, yuvarlanmış),
böylece sahnelerdeki ölçek / tutma noktası / duruş, kukla ve arayüz ikonları değişmeden kalır. Adımlar: çarpılmış-alfa kutu küçültme -> alfa
eşiği -> silah başına ORTAK en çok 14 renk (median cut; Yay'ın 5 çekme karesi aynı paletle, titremesin) -> saydama komşu açık pikseller koyu
dış hat -> n kat en yakın komşu büyütme, tuvale ortalı. Orijinaller ilk çalıştırmada YEDEK klasörüne kopyalanır; betik hep yedekten okur
(iki kez çalıştırmak aynı sonucu verir). Bumerang zaten gerçek piksel çizimi (7 renk) - dokunulmaz. Prototip: tools/proto_20261106/stil_rehberi/silah_piksel.py.
Dünya doku pikseli: asa dışı = sahne Icon.scale x 0,9 (weapon.gd) x 0,85 (WeaponOrbitMath.ICON_SIZE_MULT) x 0,5 (oyuncu kökü);
Yıldırım Asası = 0,99 x 0,85 x (0,5 x 0,3 asa ölçeği).
Çalıştır: python tools/silah_piksel_uygula.py   (sonra Godot --headless --path . --import)   Geri almak: --geri
"""
import os
import shutil
import sys

import numpy as np
from PIL import Image

GAME = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
BACKUP = os.path.join(GAME, "tools", "proto_20261106", "stil_rehberi", "out", "silah_eski_yedek")
GRID = 0.575
COLORS = 14
NONWAND = 0.9 * 0.85 * 0.5
WEAPONS = [  # (ad, [dosyalar], dünya doku pikseli)
    ("bicak", ["assets/weapons/base_knife/icon_v2.png"], 0.2805 * NONWAND),
    ("topuz", ["assets/weapons/topuz/icon.png"], 0.25900875 * NONWAND),
    ("pence", ["assets/weapons/pence/icon.png"], 0.2941125 * NONWAND),
    ("tabanca", ["assets/weapons/tabanca/icon_v2.png"], 0.28875 * NONWAND),
    ("tufek", ["assets/weapons/tufek/icon.png"], 0.35475 * NONWAND),
    ("arbalet", ["assets/weapons/crossbow/icon.png"], 0.396 * NONWAND),
    ("fisek", ["assets/weapons/fisek/icon.png"], 0.561 * NONWAND),
    ("yay", ["assets/weapons/yay/draw%d.png" % i for i in range(1, 6)], 0.307395 * NONWAND),
    ("yildirim", ["assets/weapons/lightning/icon_v3.png"], 0.99 * 0.85 * 0.5 * 0.3),
]


def backup_path(rel):
    return os.path.join(BACKUP, rel.replace("/", "__"))


def shrink(img, n):
    nw, nh = max(1, round(img.width / n)), max(1, round(img.height / n))
    a = np.asarray(img).astype(np.float32) / 255.0
    pm = a.copy()
    pm[..., :3] *= pm[..., 3:4]
    s = np.asarray(Image.fromarray((pm * 255).astype(np.uint8), "RGBA").resize((nw, nh), Image.BOX)).astype(np.float32) / 255.0
    al = s[..., 3]
    rgb = np.clip(s[..., :3] / np.maximum(al[..., None], 1e-4), 0, 1)
    return (rgb * 255).astype(np.uint8), al > 0.45


def outline_dark(rgb, mask):
    m = np.pad(mask, 1)
    inner = m[2:, 1:-1] & m[:-2, 1:-1] & m[1:-1, 2:] & m[1:-1, :-2]
    edge = mask & ~inner
    lum = rgb.astype(np.float32) @ np.array([0.3, 0.59, 0.11])
    dark = edge & (lum > 70)
    rgb = rgb.copy()
    rgb[dark] = (rgb[dark].astype(np.float32) * 0.45).astype(np.uint8)
    return rgb


def apply_weapon(name, files, texel):
    n = max(1, round(GRID / texel))
    srcs = []
    for rel in files:
        bp = backup_path(rel)
        if not os.path.exists(bp):
            shutil.copy2(os.path.join(GAME, rel), bp)
        srcs.append(Image.open(bp).convert("RGBA"))
    smalls = [shrink(im, n) for im in srcs]
    # ortak palet: tüm karelerin opak pikselleri tek şeritte
    pix = np.concatenate([rgb[mask] for rgb, mask in smalls if mask.any()])
    pal_img = Image.fromarray(pix.reshape(1, -1, 3), "RGB").quantize(colors=COLORS, method=Image.Quantize.MEDIANCUT)
    for rel, src, (rgb, mask) in zip(files, srcs, smalls):
        q = np.asarray(Image.fromarray(rgb, "RGB").quantize(palette=pal_img, dither=Image.Dither.NONE).convert("RGB"))
        q = outline_dark(q, mask)
        art = Image.fromarray(np.dstack([q, np.where(mask, 255, 0).astype(np.uint8)]), "RGBA")
        big = art.resize((art.width * n, art.height * n), Image.NEAREST)
        canvas = Image.new("RGBA", src.size, (0, 0, 0, 0))
        canvas.alpha_composite(big.crop((0, 0, min(big.width, src.width), min(big.height, src.height))),
                               ((src.width - min(big.width, src.width)) // 2, (src.height - min(big.height, src.height)) // 2))
        canvas.save(os.path.join(GAME, rel))
    print("%-9s n=%d  piksel=%.3f dünya px  sanat %dx%d" % (name, n, n * texel, smalls[0][0].shape[1], smalls[0][0].shape[0]))


def restore():
    for _, files, _ in WEAPONS:
        for rel in files:
            bp = backup_path(rel)
            if os.path.exists(bp):
                shutil.copy2(bp, os.path.join(GAME, rel))
    print("orijinaller geri konuldu")


if __name__ == "__main__":
    os.makedirs(BACKUP, exist_ok=True)
    if "--geri" in sys.argv:
        restore()
    else:
        for w in WEAPONS:
            apply_weapon(*w)
