#!/usr/bin/env python3
"""Oyun imleci dokuları (madde 206): seçilen prototip A "Kehribar Ok" -> assets/ui/cursor/imlec_<durum>.png (1x sanat).

Çizim tek yerde: tools/proto_20261017/imlec_proto.py (`build`, `style_defs`). Oyun 1x dokuyu pencere ölçeğine göre
tam katla büyütür (scripts/game_cursor.gd). Uç noktası (hotspot) burada yazdırılır -> game_cursor.gd HOTSPOT ile aynı olmalı.

Çalıştırma: python tools/gen_imlec.py   (sonra Godot --headless --import)
"""
import importlib.util
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
OUT = os.path.join(ROOT, "assets", "ui", "cursor")
STYLE = "A"

spec = importlib.util.spec_from_file_location("imlec_proto", os.path.join(HERE, "proto_20261017", "imlec_proto.py"))
proto = importlib.util.module_from_spec(spec)
spec.loader.exec_module(proto)


def main():
    os.makedirs(OUT, exist_ok=True)
    st = proto.style_defs()[STYLE]
    for state in proto.STATES:
        img, hot = proto.build(st, state)
        img.save(os.path.join(OUT, "imlec_%s.png" % state))
        print("imlec_%s.png %dx%d hotspot %s" % (state, img.width, img.height, hot))


if __name__ == "__main__":
    main()
