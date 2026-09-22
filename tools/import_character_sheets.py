#!/usr/bin/env python3
"""Yeni karakter sprite sayfalarini (Talon, Buyucu Kiz, Elara, Korsan, Melek, Vampir) oyuna alir.

Kullanim (repo kokunden):
    python tools/import_character_sheets.py --src "<new characters klasoru>" [--only talon,buyucu]

Kullanicinin verdigi her karakter klasoru (idle/walk/run/eat/hurt/read/shrug/down|downed/death/strike/chop/pickup .png) icin:
  1) Sayfalari (satirlar yukaridan asagiya: asagi, sol, sag, yukari; hucre = 48x48 piksel sanatinin K kat buyutulmusu - K sayfaya gore 6 ya da 5)
     48x48 hucrelere indirir -> assets/characters/<anahtar>/sheets/<ad>.png ("down" sayfasi "downed" adiyla yazilir)
  2) SpriteFrames (.tres) uretir: her sayfadan <ad>_<yon> klipleri (bkz. player.gd/char_anim.gd klip adi kurallari). Vampir icin ayrica
     yarasa formu bat_<yon> klipleri eklenir (assets/characters/vampir/bat_*.png, tools/gen_vampir_assets.py uretir).
  3) Portre (idle, asagi bakan ilk kare, ust govde kirpimi) -> assets/characters/<eski portre adi>.png
  4) Ciktiya DEFS icin olculen govde/ayak bilgisini yazdirir.
Hangi animasyon oyunda ne zaman oynar: kullanici talimatlari (Animasyon talimatlari.txt) ve player.gd/char_anim.gd.
"""
import argparse
import os
import unicodedata

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHAR_DIR = os.path.join(ROOT, "assets", "characters")
CELL = 48
DIR_ROWS = [("down", 0), ("left", 1), ("right", 2), ("up", 3)]

# klasor adi (ASCII'ye indirgenmis, kucuk harf) -> (anahtar, frames .tres adi, portre adi)
CHARS = {
    "talon": ("talon", "talha_frames.tres", "talha_portrait.png"),
    "buyucu": ("buyucu", "buyucu_frames.tres", "buyucu_portrait.png"),
    "elera": ("elara", "elara_frames.tres", "elara_portrait.png"),
    "korsan": ("korsan", "korsan_frames.tres", "korsan_portrait.png"),
    "melek": ("melek", "melek_frames.tres", "melek_portrait.png"),
    "vampire new": ("vampir", "vampir_frames.tres", "vampir_portrait.png"),
}

# (oyundaki sayfa adi, kaynak dosya adi adaylari, dongu, hiz fps)
#  eat    : ~0.5 sn tek seferlik (3 kare / 6 fps)
#  hurt   : tek seferlik
#  read   : dukkan/kart ekrani acikken dongude
#  shrug  : yetenek kullaniminda tek seferlik (kanal yeteneklerinde player.gd bitince yeniden baslatir)
#  downed/death: yerde yatma / kalici olum; strike/chop/pickup henuz oyunda kullanilmiyor (iceri alinir, baglanmaz)
SHEETS = [
    ("idle", ["idle"], True, 4.0),
    ("walk", ["walk"], True, 8.0),
    ("run", ["run"], True, 12.0),
    ("eat", ["eat"], False, 6.0),
    ("hurt", ["hurt"], False, 6.0),
    ("read", ["read"], True, 4.0),
    ("shrug", ["shrug"], False, 10.0),
    ("downed", ["downed", "down"], False, 4.0),
    ("death", ["death"], False, 5.0),
    ("strike", ["strike"], False, 10.0),
    ("chop", ["chop"], False, 10.0),
    ("pickup", ["pickup"], False, 10.0),
]
BAT_ANIM = ("bat", 4, True, 10.0)


def ascii_key(name):
    s = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode("ascii").lower()
    return s.replace("y", "y")


def find_char_dirs(src):
    out = {}
    for entry in os.listdir(src):
        p = os.path.join(src, entry)
        if not os.path.isdir(p):
            continue
        k = ascii_key(entry).strip()
        # "buyucu" klasoru dosya sisteminde bozuk kodlanmis gelebilir (b?y?c?): ilk 2 + son harfe gore esle
        for key in CHARS:
            if k == key or (key == "buyucu" and k.startswith("b") and k.endswith("c") and len(k) <= 7):
                out[key] = p
    return out


def downsample(png_path):
    a = np.array(Image.open(png_path).convert("RGBA"))
    h, w = a.shape[:2]
    if h % 4 or (h // 4) % CELL:
        raise SystemExit(f"{png_path}: yukseklik {h}, 4 yon x {CELL}px katlari bekleniyordu")
    cell = h // 4
    k = cell // CELL
    if w % cell:
        raise SystemExit(f"{png_path}: genislik {w}, {cell}px'lik kare katlari olmali")
    exact = a[::k, ::k]
    if k > 1 and not (np.repeat(np.repeat(exact, k, axis=0), k, axis=1) == a).all():
        # tam nearest-buyutme degil: her KxK blogun MERKEZ pikselini al (uyari ver)
        exact = a[k // 2 :: k, k // 2 :: k]
        print(f"    UYARI: {os.path.basename(png_path)} tam {k}x buyutme degil, blok merkezi ornekleme kullanildi")
    return exact, w // cell, k


def write_frames(key, frames_name, sheet_counts):
    res_dir = f"res://assets/characters/{key}"
    ext, subs, anims = [], [], []

    def add_ext(path):
        ext.append(f'[ext_resource type="Texture2D" path="{path}" id="{len(ext) + 1}"]')
        return len(ext)

    def add_atlas(ext_id, col, row):
        idx = len(subs) + 1
        subs.append(
            f'[sub_resource type="AtlasTexture" id="AtlasTexture_{idx}"]\n'
            f'atlas = ExtResource("{ext_id}")\n'
            f"region = Rect2({col * CELL}, {row * CELL}, {CELL}, {CELL})\n"
        )
        return f"AtlasTexture_{idx}"

    def add_anim(name, refs, loop, speed):
        frames = ", ".join('{"duration": 1.0,"texture": %s}' % r for r in refs)
        anims.append('{"frames": [%s],"loop": %s,"name": &"%s","speed": %s}' % (frames, "true" if loop else "false", name, speed))

    for sheet, _names, loop, speed in SHEETS:
        count = sheet_counts[sheet]
        ext_id = add_ext(f"{res_dir}/sheets/{sheet}.png")
        for d, row in DIR_ROWS:
            refs = [f'SubResource("{add_atlas(ext_id, c, row)}")' for c in range(count)]
            add_anim(f"{sheet}_{d}", refs, loop, speed)
    if key == "vampir":
        prefix, count, loop, speed = BAT_ANIM
        for d, _row in DIR_ROWS:
            refs = [f'ExtResource("{add_ext(f"{res_dir}/{prefix}_{d}_{i}.png")}")' for i in range(1, count + 1)]
            add_anim(f"{prefix}_{d}", refs, loop, speed)
    lines = [f'[gd_resource type="SpriteFrames" load_steps={len(ext) + len(subs) + 1} format=3]', ""]
    lines += ext + [""]
    lines += ["\n".join(subs)] if subs else []
    lines += ["[resource]", "animations = [" + ", ".join(anims) + "]", ""]
    out = os.path.join(CHAR_DIR, frames_name)
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print(f"    yazildi: {frames_name} ({len(ext)} doku, {len(subs)} atlas karesi, {len(anims)} klip)")


def bbox(frame):
    a = frame[:, :, 3] > 10
    ys, xs = np.where(a)
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def import_char(entry_key, src_dir):
    key, frames_name, portrait_name = CHARS[entry_key]
    print(f"== {key}  ({src_dir})")
    out_dir = os.path.join(CHAR_DIR, key, "sheets")
    os.makedirs(out_dir, exist_ok=True)
    found = {f.lower(): f for f in os.listdir(src_dir)}
    counts = {}
    idle_small = None
    for sheet, names, _loop, _speed in SHEETS:
        fn = None
        for n in names:
            if n + ".png" in found:
                fn = found[n + ".png"]
                break
        if fn is None:
            raise SystemExit(f"eksik sayfa: {names} ({src_dir})")
        small, cols, k = downsample(os.path.join(src_dir, fn))
        counts[sheet] = cols
        Image.fromarray(small).save(os.path.join(out_dir, sheet + ".png"))
        if sheet == "idle":
            idle_small = small
        print(f"    {sheet}: {cols} kare x 4 yon (kaynak {k}x)")
    write_frames(key, frames_name, counts)
    # portre: idle asagi ilk kare -> ust govde kirpimi (kafa + omuzlar, 36x36)
    fr = idle_small[0:CELL, 0:CELL]
    x0, y0, x1, y1 = bbox(fr)
    cx = (x0 + x1) // 2
    top = max(0, y0 - 2)
    left = max(0, min(CELL - 36, cx - 18))
    crop = fr[top : top + 36, left : left + 36]
    Image.fromarray(crop).save(os.path.join(CHAR_DIR, portrait_name))
    print(f"    portre: {portrait_name} (kirpim {left},{top} 36x36)")
    print(f"    OLCU idle_down: govde {x1 - x0 + 1}x{y1 - y0 + 1} sanat px, ayak satiri {y1}, x {x0}-{x1}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--only", default="")
    args = ap.parse_args()
    dirs = find_char_dirs(args.src)
    only = [s for s in args.only.split(",") if s]
    for key, path in sorted(dirs.items()):
        if only and CHARS[key][0] not in only:
            continue
        import_char(key, path)
    missing = [k for k in CHARS if k not in dirs]
    if missing:
        print("BULUNAMAYAN klasorler:", missing)


if __name__ == "__main__":
    main()
