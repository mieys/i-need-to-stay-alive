#!/usr/bin/env python3
"""Yeni karakter sprite sayfalarini (Talon, Buyucu Kiz, Elara, Korsan, Melek, Vampir) oyuna alir.

Kullanim (repo kokunden):
    python tools/import_character_sheets.py --src "<new characters klasoru>" [--only talon,buyucu]

Kullanicinin verdigi her karakter klasoru (idle/walk/run/eat/hurt/read/shrug/down|downed/death/strike/chop/pickup .png) icin:
  1) Sayfalari (satirlar yukaridan asagiya: asagi, sol, sag, yukari; hucre = 48x48 piksel sanatinin K kat buyutulmusu - K sayfaya gore 6 ya da 5)
     48x48 hucrelere indirir -> assets/characters/<anahtar>/sheets/<ad>.png ("down" sayfasi "downed" adiyla yazilir)
  2) SpriteFrames (.tres) uretir: her sayfadan <ad>_<yon> klipleri (bkz. player.gd/char_anim.gd klip adi kurallari). Vampir icin ayrica
     yarasa formu bat_<yon> klipleri eklenir (assets/characters/vampir/bat_sheet.png, tools/gen_vampir_bat_form.py uretir).
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
    # 2026-09-23 ikinci parti (new characters.zip #2): Necromancer/Sovalye
    # Adam/Assasin/Matthew/Shaman - hepsi eski LPC atlasindan/uretilen
    # sayfalardan bu yeni 48x48 kite geciyor.
    "necromancer": ("necromancer", "necromancer_frames.tres", "necromancer_portrait.png"),
    "sovalye adam": ("sovalye", "sovalye_frames.tres", "sovalye_portrait.png"),
    "assasin": ("assasin", "assasin_frames.tres", "assasin_portrait.png"),
    "matthew": ("matthew", "matthew_frames.tres", "matthew_portrait.png"),
    "shaman": ("shaman", "shaman_frames.tres", "shaman_portrait.png"),
    # 2026-09-25 ucuncu parti: Oakley (eski LPC oyku_atlas.png'den bu kite). Dosya adlari
    # (oyku_*) eski Oyku adindan kalma - characters.gd bunlari kullandigi icin korunuyor.
    "oakley": ("oakley", "oyku_frames.tres", "oyku_portrait.png"),
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
        ## Yarasa formu (2026-09-24 yeniden tasarim): tools/gen_vampir_bat_form.py TEK bir sayfa uretir
        ## (bat_sheet.png, 96x112 hucre, satirlar DIR_ROWS sirasinda) - eskiden 16 ayri bat_<yon>_<n>.png vardi.
        prefix, count, loop, speed = BAT_ANIM
        bat_ext = add_ext(f"{res_dir}/bat_sheet.png")
        for d, row in DIR_ROWS:
            refs = []
            for i in range(count):
                idx = len(subs) + 1
                subs.append(
                    f'[sub_resource type="AtlasTexture" id="AtlasTexture_{idx}"]\n'
                    f'atlas = ExtResource("{bat_ext}")\n'
                    f"region = Rect2({i * 96}, {row * 112}, 96, 112)\n"
                )
                refs.append(f'SubResource("AtlasTexture_{idx}")')
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


# DUZELTME (kullanici bildirimi 2026-09-24, secim ekrani ekran goruntusu: "karakterler oyundaki gibi gorunmuyor
# dusuk kalitede"): portre eskiden 48x48 hucreden 36x36'ya NEAREST ile KUCULTULUYORDU - bu her 4 satir/sutundan
# birini ATIYOR (goz/yuz/kemer pikselleri kayboluyor/bozuluyor). Artik hucre 1:1 (48x48) yaziliyor; kartta
# tam sayi katla buyutme UIKit.attach_pixel_portrait'te.
PORTRAIT_SIZE = CELL

# DUZELTME (kullanici bildirimi, ekran goruntusuyle 2026-09-23: "karakter portlerlerinde boyu uzun olan
# karakterler sigmamis kutucuklarina ... gorunuslerini biraz uzaklastirman gerekiyor yani kucultmen"):
# eskiden portre, karakterin GERCEK govde kutusuna (bbox) SIKI SIKIYA oturan sabit 36x36'lik bir pencereydi
# (yukaridan sadece 2px pay, digger taraf CELL-36 ile kirpiliyordu) - kisa karakterlerde sorun cikmiyordu ama
# kanat/miğfer/basluk gibi uzun govdeli karakterlerde (Melek/Necromancer/Vampir Cocuk) bu pencere govdenin
# TAMAMINI kapsayamiyor, ust/alt kesiliyordu. Artik HERKES icin AYNI (tutarli "kamera mesafesi") - govdeye
# sikica degil, TUM 48x48 hucreye (idle asagi ilk kare) gore kirpiliyor, sadece govdenin CIKTI karesinin
# merkezine hizalaniyor - hicbir karakter artik kesilemiyor (kirpim penceresi kaynaktan asla buyuk degil),
# bedeli: herkes portrede biraz daha kucuk/uzak gorunuyor (istenen "uzaklastirma" tam olarak bu).
def make_portrait(idle_small, out_path):
    fr = idle_small[0:CELL, 0:CELL]  # idle asagi, ilk kare - kirpim penceresi = TUM 48x48 hucre (bkz. yukaridaki not)
    Image.fromarray(fr).save(out_path)  # yeniden boyutlandirma YOK (bkz. PORTRAIT_SIZE notu)
    print(f"    portre: {os.path.basename(out_path)} (tam hucre {PORTRAIT_SIZE}x{PORTRAIT_SIZE}, 1:1, hicbir govde kesilmiyor)")


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
    make_portrait(idle_small, os.path.join(CHAR_DIR, portrait_name))
    x0, y0, x1, y1 = bbox(idle_small[0:CELL, 0:CELL])  # sadece olcum/log amacli, portreyi ETKİLEMEZ (bkz. make_portrait)
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
