#!/usr/bin/env python3
"""Masaustu "ek animasyonlar" klasorunu oyuna alir (2026-10-13, madde 112).

Kullanim (repo kokunden):
    python tools/import_ek_animasyonlar.py [--src "<ek animasyonlar klasoru>"]

Yaptiklari:
  1) 12 oynanabilir karakterin "oturma" sayfasini (4 kare x 4 yon) assets/characters/<anahtar>/sheets/sit.png olarak yazar ve
     karakterin SpriteFrames'ine sit_down/left/right/up klipleri (4 kare, dongu, 4 fps) EKLER (var olan klipler/sira bozulmaz,
     yarasa/golem/hayalet klipleri korunur; betik tekrar calistirilabilir: klip varsa dokunmaz).
  2) Matthew ve Elara'nin YENI gorunumu: idle/walk/run/eat/hurt/read/shrug/downed/death/strike/pickup sayfalari degistirilir
     (kare sayilari ayni, frames .tres'e dokunulmaz) + secim ekrani portresi (idle asagi ilk kare) yeniden yazilir.
     chop sayfasi yeni sette YOK (oyunda hicbir yerde kullanilmiyor) - eskisi kalir.
  3) Demirci ve Seyyar satici NPC'leri: assets/npc/<ad>/sheets/*.png + <ad>_frames.tres (idle/walk/strike ya da idle/walk/think).
Kaynak sayfalar piksel sanatinin 6 kat buyutulmus hali (288 px hucre); 48 px'e KAYIPSIZ indirilir (tam katlama dogrulanir).
"""
import argparse
import os
import re
import unicodedata

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHAR_DIR = os.path.join(ROOT, "assets", "characters")
NPC_DIR = os.path.join(ROOT, "assets", "npc")
CELL = 48
DIR_ROWS = [("down", 0), ("left", 1), ("right", 2), ("up", 3)]
DEFAULT_SRC = os.path.join(os.path.expanduser("~"), "Desktop", "ek animasyonlar")

# klasor adi (ASCII'ye indirgenmis, kucuk harf) on eki -> (anahtar, frames .tres adi, portre adi)
CHARS = {
    "assasin": ("assasin", "assasin_frames.tres", "assasin_portrait.png"),
    "buyucu": ("buyucu", "buyucu_frames.tres", "buyucu_portrait.png"),
    "elera": ("elara", "elara_frames.tres", "elara_portrait.png"),
    "korsan": ("korsan", "korsan_frames.tres", "korsan_portrait.png"),
    "matthew": ("matthew", "matthew_frames.tres", "matthew_portrait.png"),
    "melek": ("melek", "melek_frames.tres", "melek_portrait.png"),
    "necromancer": ("necromancer", "necromancer_frames.tres", "necromancer_portrait.png"),
    "suriyeli": ("hadime", "hadime_frames.tres", "hadime_portrait.png"),
    "talon": ("talon", "talha_frames.tres", "talha_portrait.png"),
    "vampir": ("vampir", "vampir_frames.tres", "vampir_portrait.png"),
    "saman": ("shaman", "shaman_frames.tres", "shaman_portrait.png"),
    "sovalye": ("sovalye", "sovalye_frames.tres", "sovalye_portrait.png"),
}
# Yeni gorunumu olan karakterler: degisen sayfalar (oyundaki ad -> kaynak dosya adi parcasi)
REPLACE_CHARS = ("matthew", "elera")
REPLACE_SHEETS = ["idle", "walk", "run", "eat", "hurt", "read", "shrug", "downed", "death", "strike", "pickup"]

SIT_CLIP = ("sit", 4, True, 4.0)  # (on ek, kare, dongu, fps)


def ascii_key(name):
    return unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode("ascii").lower().strip()


def downsample(png_path):
    """288 px'lik (6x) sayfayi 48 px'lik hucrelere kayipsiz indirir. Doner: (dizi, sutun sayisi)."""
    a = np.array(Image.open(png_path).convert("RGBA"))
    h, w = a.shape[:2]
    if h % 4 or (h // 4) % CELL or w % (h // 4):
        raise SystemExit(f"{png_path}: beklenmeyen boyut {w}x{h}")
    cell = h // 4
    k = cell // CELL
    small = a[::k, ::k]
    if k > 1 and not (np.repeat(np.repeat(small, k, axis=0), k, axis=1) == a).all():
        raise SystemExit(f"{png_path}: tam {k}x nearest buyutme degil (kayipsiz indirilemez)")
    return small, w // cell


def save_sheet(small, out_path):
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    Image.fromarray(small).save(out_path)


def find_file(folder, *needles):
    """Klasorde adi TUM needle'lari iceren tek png'yi bulur (buyuk/kucuk harf duyarsiz)."""
    hits = [f for f in os.listdir(folder) if f.lower().endswith(".png") and all(n in f.lower() for n in needles)]
    if len(hits) != 1:
        raise SystemExit(f"{folder}: {needles} icin {len(hits)} dosya bulundu: {hits}")
    return os.path.join(folder, hits[0])


# ------------------------------------------------------------------ .tres yamasi (klip ekleme)

def patch_frames_add_clips(frames_path, res_sheet_path, ext_id, prefix, count, loop, speed):
    """Mevcut SpriteFrames .tres'ine <prefix>_<yon> klipleri ekler (dokuyu ext_resource, kareleri AtlasTexture olarak)."""
    with open(frames_path, "r", encoding="utf-8", newline="") as f:
        text = f.read()
    if f'&"{prefix}_down"' in text:
        print(f"    {os.path.basename(frames_path)}: {prefix}_* klipleri zaten var, atlandi")
        return False
    m = re.search(r"load_steps=(\d+)", text)
    if not m:
        raise SystemExit(f"{frames_path}: load_steps bulunamadi")
    added = 1 + 4 * count
    text = text.replace(m.group(0), f"load_steps={int(m.group(1)) + added}", 1)
    # ext_resource: sonuncusunun ARDINA
    ext_lines = list(re.finditer(r'^\[ext_resource [^\n]*\]\r?\n', text, re.M))
    pos = ext_lines[-1].end()
    text = text[:pos] + f'[ext_resource type="Texture2D" path="{res_sheet_path}" id="{ext_id}"]\n' + text[pos:]
    # sub_resource: [resource]'tan ONCE
    subs, anims = [], []
    for d, row in DIR_ROWS:
        refs = []
        for c in range(count):
            sid = f"AtlasTexture_{prefix}_{d}_{c}"
            subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("{ext_id}")\nregion = Rect2({c * CELL}, {row * CELL}, {CELL}, {CELL})\n')
            refs.append('{"duration": 1.0,"texture": SubResource("%s")}' % sid)
        anims.append('{"frames": [%s],"loop": %s,"name": &"%s_%s","speed": %s}' % (", ".join(refs), "true" if loop else "false", prefix, d, speed))
    ri = text.index("[resource]")
    text = text[:ri] + "\n".join(subs) + "\n" + text[ri:]
    # animations dizisinin sonuna ekle (son "}]")
    end = text.rindex("}]")
    text = text[:end] + "}, " + ", ".join(anims) + "]" + text[end + 2:]
    with open(frames_path, "w", encoding="utf-8", newline="") as f:
        f.write(text)
    print(f"    {os.path.basename(frames_path)}: +{4} klip ({prefix}_*), +{added} kaynak")
    return True


# ------------------------------------------------------------------ NPC frames

def write_npc_frames(npc_key, frames_name, sheets):
    """sheets: [(ad, kare, dongu, fps)] - her biri assets/npc/<npc_key>/sheets/<ad>.png"""
    res_dir = f"res://assets/npc/{npc_key}"
    ext, subs, anims = [], [], []
    for name, count, loop, speed in sheets:
        ext.append(f'[ext_resource type="Texture2D" path="{res_dir}/sheets/{name}.png" id="{len(ext) + 1}"]')
        ext_id = len(ext)
        for d, row in DIR_ROWS:
            refs = []
            for c in range(count):
                sid = f"AtlasTexture_{name}_{d}_{c}"
                subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("{ext_id}")\nregion = Rect2({c * CELL}, {row * CELL}, {CELL}, {CELL})\n')
                refs.append('{"duration": 1.0,"texture": SubResource("%s")}' % sid)
            anims.append('{"frames": [%s],"loop": %s,"name": &"%s_%s","speed": %s}' % (", ".join(refs), "true" if loop else "false", name, d, speed))
    lines = [f'[gd_resource type="SpriteFrames" load_steps={len(ext) + len(subs) + 1} format=3]', ""]
    lines += ext + [""]
    lines += ["\n".join(subs)]
    lines += ["[resource]", "animations = [" + ", ".join(anims) + "]", ""]
    out = os.path.join(NPC_DIR, npc_key, frames_name)
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print(f"    yazildi: {os.path.relpath(out, ROOT)} ({len(ext)} doku, {len(subs)} kare, {len(anims)} klip)")


# ------------------------------------------------------------------ ana akis

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=DEFAULT_SRC)
    args = ap.parse_args()
    src = args.src
    folders = {}
    for entry in sorted(os.listdir(src)):
        p = os.path.join(src, entry)
        if os.path.isdir(p):
            folders[ascii_key(entry)] = p

    def folder_for(prefix):
        hits = [p for k, p in folders.items() if k.startswith(prefix)]
        if len(hits) != 1:
            raise SystemExit(f"'{prefix}' icin {len(hits)} klasor: {list(folders)}")
        return hits[0]

    # 1) oturma klipleri (12 karakter)
    print("== oturma (sit)")
    for prefix, (key, frames_name, _portrait) in CHARS.items():
        folder = folder_for(prefix)
        sheet = find_file(folder, "sit") if prefix != "suriyeli" else find_file(folder, "oturma")
        small, cols = downsample(sheet)
        if cols != SIT_CLIP[1]:
            raise SystemExit(f"{sheet}: {cols} kare, {SIT_CLIP[1]} bekleniyordu")
        save_sheet(small, os.path.join(CHAR_DIR, key, "sheets", "sit.png"))
        patch_frames_add_clips(os.path.join(CHAR_DIR, frames_name), f"res://assets/characters/{key}/sheets/sit.png", "sit_sheet",
                               SIT_CLIP[0], SIT_CLIP[1], SIT_CLIP[2], SIT_CLIP[3])

    # 2) Matthew + Elara yeni gorunum
    print("== Matthew / Elara yeni gorunum")
    for prefix in REPLACE_CHARS:
        key, _frames, portrait = CHARS[prefix]
        folder = folder_for(prefix)
        for sheet in REPLACE_SHEETS:
            small, cols = downsample(find_file(folder, f"_{sheet}_f"))
            dst = os.path.join(CHAR_DIR, key, "sheets", sheet + ".png")
            old_w = Image.open(dst).size[0]
            if cols * CELL != old_w:
                raise SystemExit(f"{dst}: yeni sayfa {cols} kare, eski {old_w // CELL} kare - frames .tres uyusmaz")
            save_sheet(small, dst)
            if sheet == "idle":
                Image.fromarray(small[0:CELL, 0:CELL]).save(os.path.join(CHAR_DIR, portrait))
        print(f"    {key}: {len(REPLACE_SHEETS)} sayfa + portre yazildi")

    # 3) NPC'ler
    print("== NPC'ler")
    d = folder_for("demirci")
    for name in ("idle", "walk", "strike"):
        small, _ = downsample(find_file(d, f"_{name}_f"))
        save_sheet(small, os.path.join(NPC_DIR, "demirci", "sheets", name + ".png"))
    write_npc_frames("demirci", "demirci_frames.tres", [("idle", 4, True, 4.0), ("walk", 6, True, 8.0), ("strike", 4, True, 6.0)])
    s = folder_for("seyyar")
    for name, fn in (("idle", "idle.png"), ("walk", "walk.png"), ("think", None)):
        path = os.path.join(s, fn) if fn else find_file(s, "think")
        small, _ = downsample(path)
        save_sheet(small, os.path.join(NPC_DIR, "seyyar_satici", "sheets", name + ".png"))
    write_npc_frames("seyyar_satici", "seyyar_satici_frames.tres", [("idle", 4, True, 4.0), ("walk", 6, True, 8.0), ("think", 4, True, 4.0)])


if __name__ == "__main__":
    main()
