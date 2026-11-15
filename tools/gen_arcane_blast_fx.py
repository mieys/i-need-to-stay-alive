"""Buyucu "Arcane Patlama" (E1) patlama sayfalari - "M1 Yildiz Tozu" (madde 563, kullanicinin sectigi prototip).

  python -I tools/gen_arcane_blast_fx.py
Cizim prototipin KENDISI (tools/proto_20261111/arcane_patlama/arcane_patlama_proto.py m1_frame + FADE_M); prototipte degisiklik
yapilirsa bunu yeniden kos. Cikti assets/fx/buyucu/patlama_front.png + patlama_ground.png: yatay serit, 12 kare, 20 fps (BuyucuFx.SHEETS),
kare 128 x 144, isabet noktasi (capa) karenin TAM ORTASI (BuyucuFx Sheet centered). 1 piksel = Buyucu sanat pikseli (BuyucuFx.PX 0,903).
Cizildigi alan yaricapi = proto BLAST_WORLD (52,5 dunya) = scripts/fx_arcane_blast.gd DRAWN_RADIUS (ikisi ayni olmali).
Karisim TOPLAMALI (fx_arcane_blast.gd) - renkler eklenen isik; saydamlik (FADE_M) sayfaya pisirilir.
"""

import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
sys.path.insert(0, os.path.join(HERE, "proto_20261111", "arcane_patlama"))
import arcane_patlama_proto as proto  # noqa: E402

OUT = os.path.join(ROOT, "assets", "fx", "buyucu")
HW, HH = 64, 72  # capanin cevresindeki yarim genislik / yukseklik (tozlar alan kenarindan ~13 px yukselir)


def main():
    assert abs(proto.BLAST_WORLD - 52.5) < 1e-6, "fx_arcane_blast.gd DRAWN_RADIUS ile ayni olmali"
    box = (proto.AX - HW, proto.AY - HH, proto.AX + HW, proto.AY + HH)
    fronts, grounds = [], []
    for f in range(proto.NF):
        fr, gr = proto.m1_frame(f)
        k = proto.FADE_M[f]
        for img, dst in ((fr.image(), fronts), (gr.image(), grounds)):
            full = proto._bake_alpha(img, k)
            # kirpmanin disinda boyali piksel kalmasin (sayfa kesmesin)
            a = full.getchannel("A")
            bb = a.getbbox()
            if bb and (bb[0] < box[0] or bb[1] < box[1] or bb[2] > box[2] or bb[3] > box[3]):
                raise SystemExit("kare %d kirpmaya sigmiyor: %s / %s" % (f, bb, box))
            dst.append(full.crop(box))
    w, h = 2 * HW, 2 * HH
    for name, imgs in (("patlama_front", fronts), ("patlama_ground", grounds)):
        strip = Image.new("RGBA", (w * len(imgs), h), (0, 0, 0, 0))
        for i, im in enumerate(imgs):
            strip.paste(im, (i * w, 0))
        strip.save(os.path.join(OUT, name + ".png"))
        print("yazildi", name, strip.size)


if __name__ == "__main__":
    main()
