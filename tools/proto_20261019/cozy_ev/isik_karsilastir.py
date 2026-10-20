# -*- coding: utf-8 -*-
"""Cozy ev iç ışığı: önizleme (gen_cozy_ev.render) ile oyun yakalaması (isik_capture.gd) yan yana + sayısal fark (madde 311).

Kullanım: python isik_karsilastir.py <yakalama klasörü>   (gece.png / gunduz.png, 1280x608 = ev x2)
Çıktı: <klasör>/karsilastirma.png (sol önizleme, sağ oyun; üst gece, alt gündüz) + ortalama parlaklık / fark satırları.
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_cozy_ev as g  # noqa: E402


def main():
    d = sys.argv[1]
    # gündüz camı maskesi (make_window_sheet Pencere.png'yi YAZAR - çağrılmaz): gündüz karesinde CAM_GUNDUZ renkleri
    gun = np.asarray(Image.open(g.WIN_PNG).convert("RGBA"))[:, 16:32, :3].astype(np.int32)
    g._cam_maske = np.isin(gun[..., 0] * 65536 + gun[..., 1] * 256 + gun[..., 2],
                           [r * 65536 + gg * 256 + b for r, gg, b in g.CAM_GUNDUZ.values()])
    m = g.build()
    rows = []
    for kip, ad in (("gece", "gece.png"), ("gunduz", "gunduz.png")):
        pre = g.render(m, 0, lit=kip)
        pre = pre.resize((pre.width * 2, pre.height * 2), Image.NEAREST)
        oyun = Image.open(os.path.join(d, ad)).convert("RGB").resize(pre.size, Image.NEAREST)
        a = np.asarray(pre, np.float32)
        b = np.asarray(oyun, np.float32)
        print("%-7s önizleme ort %s | oyun ort %s | ort |fark| %.1f" % (
            kip, np.round(a.mean(axis=(0, 1)), 1), np.round(b.mean(axis=(0, 1)), 1), np.abs(a - b).mean()))
        row = Image.new("RGB", (pre.width * 2 + 8, pre.height), (0, 0, 0))
        row.paste(pre, (0, 0))
        row.paste(oyun, (pre.width + 8, 0))
        rows.append(row)
    out = Image.new("RGB", (rows[0].width, rows[0].height * 2 + 8), (0, 0, 0))
    out.paste(rows[0], (0, 0))
    out.paste(rows[1], (0, rows[0].height + 8))
    out.save(os.path.join(d, "karsilastirma.png"))


if __name__ == "__main__":
    main()
