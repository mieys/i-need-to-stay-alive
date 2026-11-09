"""Vampir Cocuk Yarasa Formu gecis efekti "C - Kizil Girdap" sayfalari (madde 516, kullanici secimi 2026-11-09).

Cizim prototipteki ile BIREBIR ayni: tools/proto_20261109/vampir_donusum_proto.py (c_in / c_out). Bu betik sadece C'yi oyunun
klasorune yazar:
  assets/fx/vampir_donusum/in_front.png  in_ground.png   (insan -> yarasa, 16 kare)
  assets/fx/vampir_donusum/out_front.png out_ground.png  (yarasa -> insan, 14 kare)
Her sayfa yatay serit, kare 136x136, capa (68, 60) = oyunun dogum noktasi (oyuncu + VampirMath.BODY_CENTER), 1 piksel = 0,847
dunya (Vampir karakter pikseli). front = karakterin ustu (z 20), ground = girdabin ARKA yarisi + yer halkasi (z 0: haritanin
ustu, oyuncularin (z 1) alti). Sabitler scripts/vampir_fx.gd BAT_* ile ayni olmali.

  python -I tools/gen_vampir_donusum_fx.py
"""

import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "proto_20261109"))
sys.path.insert(0, HERE)
import vampir_donusum_proto as V  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, ".."))
OUT = os.path.join(ROOT, "assets", "fx", "vampir_donusum")


def main():
    os.makedirs(OUT, exist_ok=True)
    for phase, fn, nf in (("in", V.c_in, V.NF_IN), ("out", V.c_out, V.NF_OUT)):
        strips = {"front": Image.new("RGBA", (V.W * nf, V.H)), "ground": Image.new("RGBA", (V.W * nf, V.H))}
        for i in range(nf):
            f, g = fn(i)
            strips["front"].paste(f.image(), (i * V.W, 0))
            if g is not None:
                strips["ground"].paste(g.image(), (i * V.W, 0))
        for layer, im in strips.items():
            a = im.getchannel("A")
            for i in range(nf):
                cell = a.crop((i * V.W, 0, (i + 1) * V.W, V.H))
                bb = cell.getbbox()
                if bb and (bb[0] == 0 or bb[1] == 0 or bb[2] == V.W or bb[3] == V.H):
                    print("UYARI kenara degiyor:", phase, layer, i, bb)
            path = os.path.join(OUT, "%s_%s.png" % (phase, layer))
            im.save(path)
            print(path, im.size, nf, "kare")


if __name__ == "__main__":
    main()
