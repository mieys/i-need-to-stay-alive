"""Hafif Makineli Tüfek NAMLU ATEŞİ (madde 652, 2026-11-13; kullanıcı: "bu silahın ucundaki patlama tuhaf görünüyor").

Önce Tabanca'nın fx_revolver_muzzle sayfası kullanılıyordu: o sayfa "namlu diski -> ileri uçan iz -> öne savrulan duman" anlatır,
saniyede 12+ atışta parçaları namludan 15 px ileride kopuk uçuşuyordu (+ sahnede 90 derece yana dönüktü). Bunun yerine namlu ağzına
OTURAN küçük, hızlı bir yıldız alev: 3 kare (parlak çekirdek + ileri dil + iki yan çatal -> küçülen turuncu -> kor), 30 fps = 0,1 sn
(bir sonraki atışın ateşi gelmeden söner).

Çıktı: assets/fx/makineli/muzzle_sheet.png (3 kare, 12x7) + muzzle_frames.tres ("play", döngüsüz).
Doku pikseli SİLAHIN pikseli (0,575 x 0,78 = 0,4485 dünya px; scenes/fx_makineli_muzzle.tscn ölçeği) - silah çizimiyle aynı ızgara.
Ucu +x; namlu ağzı karenin SOL kenarı, orta satır (3). Renkler Pompalı ateşinin rampası (krem / altın / turuncu / kızıl).
Kullanım: python -I tools/gen_makineli_fx.py
"""
import os
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "fx", "makineli")
PAL = {"W": (255, 244, 208), "Y": (255, 186, 64), "O": (236, 112, 36), "R": (182, 44, 28)}
CELL = (12, 7)
FRAMES = [
    [
        "...O....O...",
        "....YY.YY...",
        ".YYWWWWYYOO.",
        "YWWWWWWWWWYO",
        ".YYWWWWYYOO.",
        "....YY.YY...",
        "...O....O...",
    ],
    [
        "............",
        "..O..O......",
        ".YYYYYYOO...",
        "YWWWWYYYOR..",
        ".YYYYYYOO...",
        "..O..O......",
        "............",
    ],
    [
        "............",
        "............",
        ".R.O........",
        "OYYOR.......",
        ".R.O........",
        "............",
        "............",
    ],
]
FPS = 30.0


def main():
    os.makedirs(OUT, exist_ok=True)
    w, h = CELL
    sheet = Image.new("RGBA", (w * len(FRAMES), h), (0, 0, 0, 0))
    for f, rows in enumerate(FRAMES):
        assert len(rows) == h and all(len(r) == w for r in rows), "kare %d boyutu" % f
        for y, r in enumerate(rows):
            for x, ch in enumerate(r):
                if ch in PAL:
                    sheet.putpixel((f * w + x, y), PAL[ch] + (255,))
    sheet.save(os.path.join(OUT, "muzzle_sheet.png"))
    subs = []
    frames = []
    for f in range(len(FRAMES)):
        subs.append('[sub_resource type="AtlasTexture" id="AT_%d"]\natlas = ExtResource("1")\nregion = Rect2(%d, 0, %d, %d)\n' % (f, f * w, w, h))
        frames.append('{\n"duration": 1.0,\n"texture": SubResource("AT_%d")\n}' % f)
    tres = ('[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n'
            '[ext_resource type="Texture2D" path="res://assets/fx/makineli/muzzle_sheet.png" id="1"]\n\n' % (len(FRAMES) + 2)
            + "\n".join(subs)
            + '\n[resource]\nanimations = [{\n"frames": [' + ", ".join(frames) + '],\n"loop": false,\n"name": &"play",\n"speed": %.1f\n}]\n' % FPS)
    with open(os.path.join(OUT, "muzzle_frames.tres"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write(tres)
    print("yazildi:", OUT)


if __name__ == "__main__":
    main()
