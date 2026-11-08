# KARAKTERE OZEL PORTRE ARKA PLANLARI (madde 464, 2026-11-08). Kullanici onayi: karakter temali arka plan + "sadece blurlu olsun".
# Tasarimlar: tools/proto_20261108/portre_tema/gen_portre_tema.py (CHARS, 28x28 sanat pikseli = yuz kirpiminin izgarasi);
# bulaniklik: gen_portre_odak.py blur() (sanat pikselinde gauss r 1.4, kenar tekrari, x0.85) - oyunda shader/bulaniklik YOK, doku hazir.
# Cikti: assets/ui/portrait_bg/<karakter id>.png (28x28). Ayrica scripts/portrait_face.gd FACE_OY tablosunu yazdirir (yuz kirpiminin ust satiri,
# Python yuvarlamasiyla onaylanan onizlemeyle birebir - GDScript round() 0.5'te farkli yuvarlar, o yuzden tablo sabit).
#   python -I tools/gen_portrait_bg.py   (sonra Godot --headless --import)
import os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROTO = os.path.join(ROOT, "tools", "proto_20261108", "portre_tema")
sys.path.insert(0, PROTO)
import gen_portre_tema as G
import gen_portre_zoom as Zm
import gen_portre_odak as Od

OUT = os.path.join(ROOT, "assets", "ui", "portrait_bg")


def main():
    os.makedirs(OUT, exist_ok=True)
    rows = []
    for cid, name, key, fn, desc in G.CHARS:
        Od.blur(fn()).save(os.path.join(OUT, "%d.png" % cid))
        eye = Zm.EYES[cid]
        p = Zm.crop_box(eye, 18, Zm.EYE_AT_PANEL)[1]
        g = Zm.crop_box(eye, 16, Zm.EYE_AT_PARTY)[1]
        rows.append("%d: [%d, %d]" % (cid, p, g))
    print("FACE_OY := {" + ", ".join(rows) + "}")


if __name__ == "__main__":
    main()
