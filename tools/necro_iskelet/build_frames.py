"""Necromancer iskelet birlikleri: "2D Pixel Quest Vol.2: The Necromancer's Order" (Barely Apes) paketinden oyun dokuları.

Kullanım (zip doğrudan okunur, açmaya gerek yok):
    python -I tools/necro_iskelet/build_frames.py "C:/Users/perva/Desktop/Vol2-The Necromancers Order.zip"

Ürettikleri (depo köküne göre):
    assets/pets/necro_iskelet/<birim>_sheet.png   - birimin tüm kareleri, sıkı kırpılmış, raf paketli (2 px boşluk)
    assets/pets/necro_iskelet/<birim>_frames.tres - SpriteFrames; her kare AtlasTexture (region + margin = paketteki asıl tuval)
    assets/pets/necro_iskelet/fx/*.png             - ok (5 yön), ateş sütunu, şifa, yeniden doğuş, büyücü halkası şeritleri
    scripts/necro_units.gd                         - birim tablosu (yol, ayak ofseti, boy, kare sayıları) + yön yardımcıları

Paket kuralları (Congrats.txt): idle/walk dışındaki her animasyonun 1. karesi yalnız hizalama referansıdır -> atılır.
Yönler paketteki 5 yön (S/SE/E/NE/N); batı yarısı oyunda flip_h ile aynalanır. Paket gövdeyi her yönde tuvalin yatay
ortasına koyar, o yüzden her karenin toplam boyu (region + margin) birimin tuvaliyle AYNI tutulur: centered sprite
gövde ortasından aynalanır (Godot flip_h ofseti aynalamaz - gövde tuval ortasında olmalı).
Hayalet "Spawn" tek yönlüdür; tuvali farklıysa (Okçu 60x57 / idle 54x44) son karesi idle'a en iyi örtüşen kaymayla yerleşir.
"""
import hashlib
import io
import os
import re
import sys
import zipfile

import numpy as np
from PIL import Image

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(REPO, "assets", "pets", "necro_iskelet")
OUT_FX = os.path.join(OUT_DIR, "fx")
OUT_GD = os.path.join(REPO, "scripts", "necro_units.gd")
RES_DIR = "res://assets/pets/necro_iskelet"

DIRS = ["s", "se", "e", "ne", "n"]
DIR_TOKENS = {
    "n": "n", "north": "n", "s": "s", "south": "s", "e": "e", "east": "e", "est": "e",
    "ne": "ne", "northeast": "ne", "se": "se", "southeast": "se",
}
KEEP_FIRST = {"idle", "walk"}
FPS = {"idle": 6.0, "walk": 8.0, "attack": 12.0, "attack2": 12.0, "attack3": 12.0, "block": 12.0, "hurt": 12.0,
       "death": 12.0, "rise": 12.0, "cast": 12.0, "summon": 14.0}
LOOP = {"idle", "walk"}
PAD = 2
SHEET_W = 1024

STD = "Standard Livery"
GHO = "Ghost Livery"
BASIC = {"idle": "Idle", "walk": "Walk", "attack": "Attack", "hurt": "Damaged", "death": "Death"}
KNIGHT = {"idle": "Knight Idle", "walk": "Knight Walk", "attack": "Knight Attack 1", "attack2": "Knight Attack 2",
          "attack3": "Knight Attack 3 Super", "block": "Knight Block", "hurt": "Knight Damaged", "death": "Knight Death"}

## birim anahtarı -> (kostüm, paket birimi, {oyun anim adı: paket klasörü}, Türkçe ad)
UNITS = {
    "common": (STD, "Common", {**BASIC, "rise": "Reborn"}, "İskelet Er"),
    "armored": (STD, "Armored", {**BASIC, "block": "Shield", "rise": "Reborn"}, "Zırhlı İskelet"),
    "captain": (STD, "Captain", {**BASIC, "block": "Block", "rise": "Reborn"}, "İskelet Yüzbaşı"),
    "knight": (STD, "Knight", {**KNIGHT, "rise": "Knight Reborn"}, "Kemik Şövalyesi"),
    "archer": (STD, "Archer", {**BASIC, "rise": "Reborn"}, "İskelet Okçu"),
    "mage": (STD, "Necromancer", {"idle": "Idle", "walk": "Walk", "attack": "Attack", "cast": "Cast Spell",
                                   "summon": "Summoning", "hurt": "Damaged", "death": "Death"}, "Kemik Büyücüsü"),
    "ghost_common": (GHO, "Common", {**BASIC, "rise": "Spawn"}, "Hayalet Er"),
    "ghost_armored": (GHO, "Armored", {**BASIC, "block": "Shield", "rise": "Spawn"}, "Hayalet Zırhlı"),
    "ghost_captain": (GHO, "Captain", {**BASIC, "block": "Block", "rise": "Spawn"}, "Hayalet Yüzbaşı"),
    "ghost_knight": (GHO, "Knight", {**KNIGHT, "rise": "Spawn"}, "Hayalet Şövalye"),
    "ghost_archer": (GHO, "Archer", {**BASIC, "rise": "Spawn"}, "Hayalet Okçu"),
}

## fx anahtarı -> (paket klasörü, dosya adı süzgeci, sıra) ; tek satır şerit, kareler eşit boy
FX = {
    "arrow": (STD + "/Archer/Arrows", "Archer_Arrow_", ["E", "SE", "S", "NE", "N"]),
    "ghost_arrow": (GHO + "/Archer/Arrows", "Ghost_Arrow_", ["E", "SE", "S", "NE", "N"]),
    "fire": ("Spells", "Spell-FireFX_", None),
    "heal": ("Spells", "Heal-FX_", None),
    "reborn": ("Spells", "SpellRebornFX_", None),
    "mage_ring": (STD + "/Necromancer/Attack/Attack FX", "", None),
}


def num_key(name):
    m = re.findall(r"(\d+)", os.path.basename(name))
    return int(m[-1]) if m else 0


def parse_dir(folder_name):
    toks = folder_name.lower().split()
    tail = []
    while toks and toks[-1] in DIR_TOKENS:
        tail.insert(0, toks.pop())
    if not tail:
        return None
    joined = "".join(tail)
    if joined in DIR_TOKENS:
        return DIR_TOKENS[joined]
    if len(tail) == 1:
        return DIR_TOKENS.get(tail[0])
    return None


class Pack:
    def __init__(self, path):
        self.z = zipfile.ZipFile(path)
        self.root = self.z.namelist()[0].split("/")[0]
        self.pngs = [n for n in self.z.namelist() if n.lower().endswith(".png") and "sheet" not in n.lower()]

    def img(self, name):
        return Image.open(io.BytesIO(self.z.read(name))).convert("RGBA")

    def anim_frames(self, livery, unit, folder):
        """-> {dir or 'all': [zip names sorted]}"""
        pre = f"{self.root}/{livery}/{unit}/{folder}/"
        out = {}
        for n in self.pngs:
            if not n.startswith(pre):
                continue
            rest = n[len(pre):].split("/")
            if len(rest) == 1:
                out.setdefault("all", []).append(n)
            elif len(rest) == 2:
                d = parse_dir(rest[0])
                if d is None:
                    continue  ## Necromancer "Attack FX" gibi alt klasörler fx tarafında
                out.setdefault(d, []).append(n)
        for k in out:
            out[k].sort(key=num_key)
        return out


def alpha_iou(a, b, dx, dy):
    """a, b: 'L' maskeler (aynı boy değil olabilir); b'yi a üzerinde (dx, dy) kaydır."""
    w, h = a.size
    canvas = Image.new("L", (w, h), 0)
    canvas.paste(b, (dx, dy))
    pa = np.asarray(a) > 0
    pb = np.asarray(canvas) > 0
    union = np.count_nonzero(pa | pb)
    return np.count_nonzero(pa & pb) / union if union else 0.0


def place_single_dir(frames, idle_imgs, canvas_size):
    """Tek yönlü (hayalet Spawn) kareleri birim tuvaline yerleştir: son kareyi idle'a en iyi örtüştüren kayma."""
    last = frames[-1]
    W, H = canvas_size
    base_dx = (W - last.width) // 2
    base_dy = H - last.height  ## alt kenarlar hizalı başla
    best = (-1.0, 0, 0, "s")
    la = last.getchannel("A")
    for d, im in idle_imgs.items():
        ia = im.getchannel("A")
        for dy in range(base_dy - 16, base_dy + 17):
            for dx in range(base_dx - 10, base_dx + 11):
                s = alpha_iou(ia, la, dx, dy)
                if s > best[0]:
                    best = (s, dx, dy, d)
    return best


class Packer:
    def __init__(self, width):
        self.w = width
        self.x = PAD
        self.y = PAD
        self.row_h = 0
        self.items = []  ## (img, x, y)
        self.cache = {}

    def add(self, im):
        key = hashlib.md5(im.tobytes() + bytes(str(im.size), "ascii")).hexdigest()
        if key in self.cache:
            return self.cache[key]
        if self.x + im.width + PAD > self.w:
            self.x = PAD
            self.y += self.row_h + PAD
            self.row_h = 0
        pos = (self.x, self.y)
        self.items.append((im, pos))
        self.x += im.width + PAD
        self.row_h = max(self.row_h, im.height)
        self.cache[key] = pos
        return pos

    def image(self):
        h = self.y + self.row_h + PAD
        sheet = Image.new("RGBA", (self.w, h), (0, 0, 0, 0))
        for im, pos in self.items:
            sheet.paste(im, pos)
        return sheet


def build_unit(pack, key, spec, log):
    livery, unit, anims, tr_name = spec
    idle = pack.anim_frames(livery, unit, anims["idle"])
    canvas = pack.img(idle["s"][0]).size
    W, H = canvas
    idle_first = {d: pack.img(idle[d][0]) for d in DIRS}
    s_bb = idle_first["s"].getchannel("A").getbbox()
    feet_line = s_bb[3]  ## idle S en alt opak satırın altı = ayak çizgisi
    body_h = s_bb[3] - s_bb[1]

    packer = Packer(SHEET_W)
    out_anims = []  ## (name, [(pos, region_size, margin)], fps, loop)
    counts = {}
    strike = {}
    for game_anim, folder in anims.items():
        per_dir = pack.anim_frames(livery, unit, folder)
        if not per_dir:
            raise SystemExit(f"{key}: '{folder}' bulunamadı")
        drop_first = game_anim not in KEEP_FIRST
        if "all" in per_dir:
            names = per_dir["all"][1:] if drop_first else per_dir["all"]
            imgs = [pack.img(n) for n in names]
            score, dx, dy, d = place_single_dir(imgs, idle_first, canvas)
            log.append(f"  {key}.{game_anim}: tek yön, tuval {imgs[0].size} -> kayma ({dx},{dy}) idle_{d} örtüşme {score:.2f}")
            placed = [(im, dx, dy) for im in imgs]
            out_anims.append((game_anim, placed))
            counts[game_anim] = len(placed)
            continue
        missing = [d for d in DIRS if d not in per_dir]
        if missing:
            raise SystemExit(f"{key}.{game_anim}: eksik yön {missing}")
        n_ref = None
        for d in DIRS:
            names = per_dir[d]
            if drop_first:
                ref = pack.img(names[0])
                diff = int(np.count_nonzero((np.asarray(ref.getchannel("A")) > 0) != (np.asarray(idle_first[d].getchannel("A")) > 0)))
                ## rise'ın 1. karesi yerdeki kemik yığını (ölümün son karesi = hizalama referansı); diğerlerinde referans idle'dır.
                ## Hayalet Er "Damaged North"ta referans yok (5 kare, 1. kare beyaz parlama) -> idle'dan çok farklıysa tutulur.
                if game_anim != "rise" and diff > 60:
                    log.append(f"  {key}.{game_anim}_{d}: 1. kare idle'dan {diff} px farklı -> referans değil, tutuldu")
                else:
                    n_ref = diff if n_ref is None else max(n_ref, diff)
                    names = names[1:]
            imgs = [pack.img(n) for n in names]
            for im in imgs:
                if im.size != canvas:
                    raise SystemExit(f"{key}.{game_anim}_{d}: tuval {im.size} != {canvas}")
            out_anims.append((f"{game_anim}_{d}", [(im, 0, 0) for im in imgs]))
            if d == "e" and game_anim.startswith("attack"):
                ext = [(im.getchannel("A").getbbox() or (0, 0, 0, 0))[2] for im in imgs]
                mx = max(ext)
                strike[game_anim] = next(i for i, v in enumerate(ext) if v >= mx - 1)
        counts[game_anim] = len(out_anims[-1][1])
        if drop_first:
            log.append(f"  {key}.{game_anim}: 1. kare atıldı (idle'dan en çok {n_ref} px farklı = hizalama referansı)")

    tres_anims = []
    for name, placed in out_anims:
        frames = []
        for im, ox, oy in placed:
            bb = im.getchannel("A").getbbox()
            if bb is None:
                bb = (0, 0, 1, 1)
            crop = im.crop(bb)
            left, top = ox + bb[0], oy + bb[1]
            ## tuval dışına taşan (kaydırılmış tek yön) kısmı kırp
            if left < 0:
                crop = crop.crop((-left, 0, crop.width, crop.height)); left = 0
            if top < 0:
                crop = crop.crop((0, -top, crop.width, crop.height)); top = 0
            if left + crop.width > W:
                crop = crop.crop((0, 0, W - left, crop.height))
            if top + crop.height > H:
                crop = crop.crop((0, 0, crop.width, H - top))
            pos = packer.add(crop)
            frames.append((pos, crop.size, (left, top, W - crop.width, H - crop.height)))
        base = name.split("_")[0]
        tres_anims.append((name, frames, FPS[base], base in LOOP))

    sheet = packer.image()
    sheet_path = os.path.join(OUT_DIR, f"{key}_sheet.png")
    sheet.save(sheet_path, optimize=True)
    write_tres(key, tres_anims)
    log.append(f"{key}: tuval {W}x{H}, sayfa {sheet.width}x{sheet.height}, {sum(len(f) for _, f, _, _ in tres_anims)} kare ({len(packer.items)} benzersiz)")
    return {
        "name": tr_name, "canvas": (W, H), "feet": feet_line, "body_h": body_h,
        "counts": counts, "strike": strike,
    }


def write_tres(key, anims):
    subs = []
    seen = {}
    lines_anim = []
    for name, frames, fps, loop in anims:
        fr_txt = []
        for pos, size, margin in frames:
            k = (pos, size, margin)
            if k not in seen:
                sid = f"AT_{len(seen)}"
                seen[k] = sid
                subs.append(
                    f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("1")\n'
                    f"region = Rect2({pos[0]}, {pos[1]}, {size[0]}, {size[1]})\n"
                    f"margin = Rect2({margin[0]}, {margin[1]}, {margin[2]}, {margin[3]})\n"
                )
            fr_txt.append('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % seen[k])
        lines_anim.append(
            '{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}'
            % (", ".join(fr_txt), "true" if loop else "false", name, f"{fps:.1f}")
        )
    txt = (
        '[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n' % (len(subs) + 2)
        + f'[ext_resource type="Texture2D" path="{RES_DIR}/{key}_sheet.png" id="1"]\n\n'
        + "\n".join(subs)
        + "\n[resource]\nanimations = [" + ", ".join(lines_anim) + "]\n"
    )
    with open(os.path.join(OUT_DIR, f"{key}_frames.tres"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write(txt)


def build_fx(pack, log):
    info = {}
    for key, (folder, prefix, order) in FX.items():
        pre = f"{pack.root}/{folder}/"
        names = [n for n in pack.pngs if n.startswith(pre) and "/" not in n[len(pre):] and os.path.basename(n).startswith(prefix)]
        if order:
            by_dir = {os.path.splitext(os.path.basename(n))[0].split("_")[-1]: n for n in names}
            names = [by_dir[d] for d in order]
        else:
            names.sort(key=num_key)
        imgs = [pack.img(n) for n in names]
        fw, fh = imgs[0].size
        strip = Image.new("RGBA", (fw * len(imgs), fh), (0, 0, 0, 0))
        for i, im in enumerate(imgs):
            strip.paste(im, (i * fw, 0))
        strip.save(os.path.join(OUT_FX, f"{key}.png"), optimize=True)
        info[key] = (fw, fh, len(imgs))
        log.append(f"fx/{key}.png: {len(imgs)} kare {fw}x{fh}")
    return info


def write_gd(units, fx):
    L = []
    L.append("extends RefCounted")
    L.append("")
    L.append("## Necromancer iskelet birlikleri - \"2D Pixel Quest Vol.2: The Necromancer's Order\" (Barely Apes; künyede anılmasını istiyor).")
    L.append("## ÜRETİLEN DOSYA: tools/necro_iskelet/build_frames.py yazar, elle düzenleme (yeniden üretimde gider).")
    L.append("## Kareler: assets/pets/necro_iskelet/<birim>_frames.tres. Anim adları \"<anim>_<yön>\", yön DIRS'ten; batı yarısı flip_h.")
    L.append("## Hayalet birimlerde \"rise\" tek yönlüdür (yön eki yok) - anim_name() ikisini de çözer.")
    L.append("## Sprite: AnimatedSprite2D centered=true, offset=UNITS[k].offset (ayaklar düğüm kökünde), scale=WORLD_SCALE.")
    L.append("")
    L.append("## Bir sanat pikseli kaç dünya birimi: Corvina'nın karakter pikseli ~0.9 (2.237 x 0.8075 x 0.5) - aynı doku yoğunluğu.")
    L.append("## 2026-11-16 (kullanıcı: \"biraz büyümeleri gerek\"): 0.9 -> 1.1, ardından \"biraz fazla büyümüşler küçült\" -> 1.0.")
    L.append("const WORLD_SCALE := 1.0")
    L.append('const DIRS: Array[String] = ["s", "se", "e", "ne", "n"]')
    L.append("")
    L.append("## anahtar -> frames (yol), name (Türkçe), canvas (paket tuvali px), offset (centered sprite için, ayaklar = 0),")
    L.append("## body_h (idle S gövde boyu px), counts (anim -> yön başına kare), strike (saldırı animinde silahın en uzağa")
    L.append("## uzandığı kare - TAHMİN, bağlarken gözle doğrula).")
    L.append("const UNITS := {")
    for key, u in units.items():
        W, H = u["canvas"]
        off_y = H / 2.0 - u["feet"]
        counts = ", ".join(f'"{k}": {v}' for k, v in u["counts"].items())
        strike = ", ".join(f'"{k}": {v}' for k, v in u["strike"].items())
        L.append(f'\t"{key}": {{')
        L.append(f'\t\t"frames": "{RES_DIR}/{key}_frames.tres",')
        L.append(f'\t\t"name": "{u["name"]}", ## dil:yok (iç ad, ekranda görünmez)')
        L.append(f'\t\t"canvas": Vector2i({W}, {H}),')
        L.append(f'\t\t"offset": Vector2(0.0, {off_y:.1f}),')
        L.append(f'\t\t"body_h": {u["body_h"]},')
        L.append(f"\t\t\"counts\": {{{counts}}},")
        L.append(f"\t\t\"strike\": {{{strike}}},")
        L.append("\t},")
    L.append("}")
    L.append("")
    L.append("## fx anahtarı -> [yol, kare_w, kare_h, kare sayısı] (tek satır şerit). arrow/ghost_arrow kare sırası: e, se, s, ne, n.")
    L.append("const FX := {")
    for key, (fw, fh, n) in fx.items():
        L.append(f'\t"{key}": ["{RES_DIR}/fx/{key}.png", {fw}, {fh}, {n}],')
    L.append("}")
    L.append("")
    L.append("")
    L.append("## Bakış yönü -> [yön eki, flip_h]. Tam kuzey/güney (n/s) ön/arka görünümdür: aynalama önceki değerde kalır,")
    L.append("## yoksa dikey yürürken küçük x titremesi silahı el değiştirir gibi oynatır.")
    L.append("static func dir_of(v: Vector2, prev_flip: bool = false) -> Array:")
    L.append("\tif v.length_squared() < 0.0001:")
    L.append('\t\treturn ["s", prev_flip]')
    L.append("\tvar deg := rad_to_deg(atan2(v.y, absf(v.x))) ## -90 yukarı .. +90 aşağı (Godot y aşağı)")
    L.append('\tvar d := "e"')
    L.append("\tif deg < -67.5:")
    L.append('\t\td = "n"')
    L.append("\telif deg < -22.5:")
    L.append('\t\td = "ne"')
    L.append("\telif deg <= 22.5:")
    L.append('\t\td = "e"')
    L.append("\telif deg <= 67.5:")
    L.append('\t\td = "se"')
    L.append("\telse:")
    L.append('\t\td = "s"')
    L.append('\tif d == "n" or d == "s":')
    L.append("\t\treturn [d, prev_flip]")
    L.append("\treturn [d, v.x < 0.0]")
    L.append("")
    L.append("")
    L.append("## \"<base>_<d>\" yoksa yönsüz \"<base>\" (hayalet rise), o da yoksa idle_<d>.")
    L.append("static func anim_name(frames: SpriteFrames, base: String, d: String) -> String:")
    L.append('\tvar n := base + "_" + d')
    L.append("\tif frames.has_animation(n):")
    L.append("\t\treturn n")
    L.append("\tif frames.has_animation(base):")
    L.append("\t\treturn base")
    L.append('\treturn "idle_" + d')
    L.append("")
    with open(OUT_GD, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(L))


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    pack = Pack(sys.argv[1])
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(OUT_FX, exist_ok=True)
    log = []
    units = {}
    for key, spec in UNITS.items():
        units[key] = build_unit(pack, key, spec, log)
    fx = build_fx(pack, log)
    write_gd(units, fx)
    print("\n".join(log))


if __name__ == "__main__":
    main()
