# -*- coding: utf-8 -*-
"""Cozy ev İÇ IŞIĞI dokuları (madde 311): oyundaki PointLight2D'lerin yumuşak gradyan dokuları.

Tek kaynak tools/proto_20261019/cozy_ev/gen_cozy_ev.py (IŞIK_KIPLERI, light_map, _huzme): kullanıcının seçtiği önizleme
("ışıklandırma olarak bunu seçiyorum, en doğalı bu oldu"). Formüller AYNI, yalnız daha ince ızgarada (Godot ışık dokusunu
ışıklanan karonun süzgeciyle - burada NEAREST - örnekler; 1 doku pikseli = 1 dünya pikseli olsaydı ışık 2,25 ekran pikselli
basamaklar gibi görünürdü, kullanıcı "ışıkların piksel piksel olmasını istemiyorum").

Çıktı assets/fx/cozy_ev_isik/:
  hale.png             512x512 (1-d)^2.2 yuvarlak hale (light_map'teki kaynak halesi; elips/yarıçap düğüm ölçeğiyle)
  pencere_yelpaze.png  kuzey pencerelerinden AŞAĞI yelpaze (gündüz huzme), 2 doku pikseli / dünya pikseli, tepe = başlangıç kenarı
  alt_yelpaze.png      alt duvardan YUKARI geniş yelpaze (gündüz alt_huzme), 2 doku pikseli / dünya pikseli, alt = başlangıç kenarı
Değerler şiddetsiz (tepe 1): şiddet = PointLight2D.energy, renk = PointLight2D.color (scripts/cozy_ev_light.gd).
Doku RGB = değer, alfa 255 (Godot ışık rengini doku RGB'si VE alfasıyla çarpar - ikisine de değer yazmak karesini alırdı).

Çalıştır: python tools/gen_cozy_ev_isik.py
"""
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "proto_20261019", "cozy_ev"))
import gen_cozy_ev as cozy  # noqa: E402  (IŞIK_KIPLERI tek kaynak)

OUT = os.path.join(ROOT, "assets", "fx", "cozy_ev_isik")
HALE = 512          # hale dokusu kenarı (yarıçap 256 doku pikseli)
YOGUNLUK = 2        # yelpaze: doku pikseli / dünya pikseli (oyunda texture_scale 0.5)


def _kaydet(v, ad):
    g = (np.clip(v, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)
    rgba = np.dstack([g, g, g, np.full_like(g, 255)])
    Image.fromarray(rgba, "RGBA").save(os.path.join(OUT, ad))
    print("yazildi:", ad, g.shape[1], "x", g.shape[0])


def hale():
    """light_map: d = mesafe / yarıçap, k = (1 - d)^2.2 (basıklık oyunda düğümün dikey ölçeği)."""
    c = (np.arange(HALE, dtype=np.float32) + 0.5 - HALE / 2) / (HALE / 2)
    yy, xx = np.meshgrid(c, c, indexing="ij")
    d = np.clip(np.sqrt(xx * xx + yy * yy), 0.0, 1.0)
    _kaydet((1.0 - d) ** 2.2, "hale.png")


def yelpaze(h, ad, yukari):
    """_huzme ile aynı: dy = başlangıç kenarından uzaklık, yanca (1-r^2)^1.5, boyca (1-t)^1.4, ilk 6 px'te açılır,
    en + genisleme x dy genişler. Dikey ters (yukari) = alt duvar pencereleri."""
    genislik = int(np.ceil(h["en"] + h["boy"] * h["genisleme"])) + 2
    genislik += genislik % 2
    w, hh = genislik * YOGUNLUK, int(h["boy"]) * YOGUNLUK
    xs = (np.arange(w, dtype=np.float32) + 0.5) / YOGUNLUK - genislik / 2   # ortadan yatay uzaklık (dünya px)
    dys = (np.arange(hh, dtype=np.float32) + 0.5) / YOGUNLUK                  # başlangıç kenarından uzaklık (dünya px)
    dy, xx = np.meshgrid(dys, xs, indexing="ij")
    t = dy / h["boy"]
    yari = (h["en"] + dy * h["genisleme"]) / 2
    r = np.abs(xx) / yari
    yanca = np.clip(1 - r * r, 0, 1) ** 1.5
    boyca = np.clip(1 - t, 0, 1) ** 1.4 * np.clip(dy / 6.0, 0, 1)
    v = yanca * boyca
    _kaydet(v[::-1] if yukari else v, ad)


def main():
    os.makedirs(OUT, exist_ok=True)
    gun = cozy.IŞIK_KIPLERI["gunduz"]
    hale()
    yelpaze(gun["huzme"], "pencere_yelpaze.png", False)
    yelpaze(gun["alt_huzme"], "alt_yelpaze.png", True)


if __name__ == "__main__":
    main()
