"""TAKIM ÜSSÜ KAMPI (PvPvE modu, docs/pvp/PLAN.md 2.2): Craftpix "Camp" paketinin örnek haritasından (kaynak/Camp.tmx) KÜÇÜK, İNSANSIZ
bir kamp çıkarır (kullanıcı 2026-11-12: "ben küçük bir kamp istemiştim ayrıca birsürü insan var burda. olmamalıydı").

Çıktı (assets/map/kamp/):
- parça başına PNG (animasyonluysa yatay şerit: kare sayısı x genişlik), haritanın kendi 16 px karo pikselinde (1 sanat px = 1 dünya birimi).
- scripts/pvp/kamp_yerlesim.gd (ÜRETİLİR): parçaların kamp merkezine (kamp ateşi) göre konumu, ayak hizası (derinlik), kare sayısı, çarpışma
  çemberi. JSON değil GDScript sabiti: dışa aktarma filtresi .json dosyalarını exe'ye koymuyor.

Kamp (KUCUK_KAMP): kazan ateşi + çevresindeki 4 kütük + 2 çadır (beyaz-mavi + mor, örnekteki yerlerinde) + silah rafı + 2 küçük taş.
- HİÇ KARAKTER YOK: karakter sayfalarından gelen her karo atlanır (çadırların içinde uyuyanlar dahil). Örnekteki kamp ateşi kazanı karıştıran bir
  kertenkele: paketin aynı sayfasındaki KERTENKELESİZ kazan varyantı (her ikinci sütun) örnekteki ateş çukuruna piksel piksel hizalanarak kullanılır.
- Çadır grubu (içindeki eşya + gölge) TEK parça; kütükler opak PİKSEL öbeklerine bölünür (karo karo bitişikler).
- Zemin / çimen / tepe / ağaç / çiçek alınmaz: kamp hangi haritaya kurulursa o haritanın zemininde durur.
Animasyon: paketin karo animasyonları 150 ms, 12 kare.

Kullanım (depo kökünden):  python -I tools/kamp/gen_kamp.py [--onizleme cikti.png]
"""
import base64, json, os, struct, sys, zlib
import xml.etree.ElementTree as ET
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "kaynak")
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(REPO, "assets", "map", "kamp")
TMX = os.path.join(SRC, "Camp.tmx")

GROUND_LAYERS = {"Ground", "Spots", "Grass", "Grass_details_ground", "Hill", "Grass_details_hill", "Trees1", "Trees2", "flowers"}
## Kamp merkezi = örnekteki kamp ateşinin (kazanlı kertenkele) ortası; çizilen ateş kertenkelesiz varyant (FIRE_*).
CENTER_LAYER = "Bonfire_lizardman"
## Karakter sayfaları (tileset adı): bunlardan gelen karo HİÇ çizilmez.
CHARACTER_TILESETS = {"Lute_player", "Drinker1", "Drinker2", "Happy_character1", "Orc", "Resting_character", "Sleeping_character",
                      "Sleeping_character2", "Сharacter_bag", "Character_bag", "Char_sharpens_weapons", "Bonfire_boiler_lizardman"}
## Küçük kamp: örnekteki parçalardan alınanlar (adlar collect_pieces / piksel öbeği adları) + kertenkelesiz ateş ("ates").
KUCUK_KAMP = {"tent1", "tent2", "logs_0", "logs_1", "logs_2", "logs_3", "weapons_1", "rocks_1", "rocks2_0"}
## Bonfire sayfası 56x56 hücrelerden: çift sütun (0,2,4) kertenkeleli, tek sütun (1,3,5) KERTENKELESİZ kazan. Örneğin animasyonu tek satırlarda
## sütun sütun iner (gen_kamp eşleştirmesiyle doğrulandı: (1,0),(3,0),(5,0),(7,0),(1,2)...). Kertenkelesiz kareler aynı sırada bir sağdaki hücre.
FIRE_CELL = 56
FIRE_FRAMES = [(1, 1), (3, 1), (5, 1), (7, 1), (1, 3), (3, 3), (5, 3), (7, 3), (1, 5), (3, 5), (5, 5), (7, 5)]
FIRE_REF_LIZARD = (1, 0)
FIRE_REF_POT = (1, 1)
FRAMES = 12
FRAME_MS = 150
## Çarpışma: çadırlar oyuncuyu durdurur (move_blockers çemberi, ayak hizasında, genişliğin bu oranı); diğer parçalar geçilir.
TENT_BLOCK_K = 0.30


def load_map():
    root = ET.parse(TMX).getroot()
    tw = int(root.get("tilewidth"))
    tilesets = []
    for ts in root.findall("tileset"):
        img = ts.find("image")
        name = img.get("source").replace("С", "C")
        im = Image.open(os.path.join(SRC, name)).convert("RGBA")
        anims = {}
        for t in ts.findall("tile"):
            a = t.find("animation")
            if a is not None:
                anims[int(t.get("id"))] = [int(f.get("tileid")) for f in a.findall("frame")]
                if any(int(f.get("duration")) != FRAME_MS for f in a.findall("frame")):
                    raise SystemExit("beklenmeyen kare süresi: " + ts.get("name"))
        tilesets.append({"first": int(ts.get("firstgid")), "cols": int(ts.get("columns")), "img": im, "anims": anims, "name": ts.get("name")})
    tilesets.sort(key=lambda t: t["first"])
    return root, tw, tilesets


def layer_cells(layer):
    data = layer.find("data")
    enc = data.get("encoding")
    out = {}
    w0 = int(layer.get("width"))
    for chk in (data.findall("chunk") or [data]):
        cx, cy = int(chk.get("x", 0)), int(chk.get("y", 0))
        w = int(chk.get("width", w0))
        if enc == "csv":
            vals = [int(v) for v in chk.text.replace("\n", "").split(",") if v.strip()]
        else:
            raw = base64.b64decode(chk.text.strip())
            if data.get("compression") == "zlib":
                raw = zlib.decompress(raw)
            vals = list(struct.unpack("<%dI" % (len(raw) // 4), raw))
        for i, g in enumerate(vals):
            if g & 0x1FFFFFFF:
                out[(cx + i % w, cy + i // w)] = g
    return out


def find_ts(tilesets, gid):
    gid &= 0x1FFFFFFF
    best = None
    for t in tilesets:
        if gid >= t["first"]:
            best = t
    return best, gid - best["first"]


def tile_image(tilesets, tw, gid, frame):
    ts, idx = find_ts(tilesets, gid)
    if idx in ts["anims"]:
        seq = ts["anims"][idx]
        idx = seq[frame % len(seq)]
    c = ts["cols"]
    x, y = (idx % c) * tw, (idx // c) * tw
    im = ts["img"].crop((x, y, x + tw, y + tw))
    if gid & 0x80000000:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    if gid & 0x40000000:
        im = im.transpose(Image.FLIP_TOP_BOTTOM)
    return im


def is_animated(tilesets, gid):
    ts, idx = find_ts(tilesets, gid)
    return idx in ts["anims"]


## Kütükler kamp ateşinin çevresinde karo karo bitişik: karo öbeği tek parça olur, ortadaki oyuncu üstteki kütüğün de arkasında kalırdı.
## Bu katmanlar karo yerine opak PİKSEL öbeklerine bölünür (yalnız durağan parçalar).
FOUR_CONN_LAYERS = set()
PIXEL_SPLIT_LAYERS = {"Logs"}


def pixel_blobs(img):
    """Opak piksellerin 8-komşulu öbekleri -> [(l, t, r, b)] (r/b hariç)."""
    w, h = img.size
    px = img.load()
    seen = [[False] * w for _ in range(h)]
    out = []
    for y in range(h):
        for x in range(w):
            if seen[y][x] or px[x, y][3] == 0:
                continue
            l, t, r, b = x, y, x + 1, y + 1
            stack = [(x, y)]
            seen[y][x] = True
            mask = []
            while stack:
                cx, cy = stack.pop()
                mask.append((cx, cy))
                l, t, r, b = min(l, cx), min(t, cy), max(r, cx + 1), max(b, cy + 1)
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = cx + dx, cy + dy
                        if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and px[nx, ny][3] > 0:
                            seen[ny][nx] = True
                            stack.append((nx, ny))
            if len(mask) >= 12:
                out.append(((l, t, r, b), mask))
    return out


def components(cells, four=False):
    """8-komşulu (four=True: 4-komşulu) karo öbekleri."""
    left = set(cells)
    out = []
    while left:
        start = left.pop()
        comp = {start}
        stack = [start]
        while stack:
            x, y = stack.pop()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    if four and dx != 0 and dy != 0:
                        continue
                    n = (x + dx, y + dy)
                    if n in left:
                        left.remove(n)
                        comp.add(n)
                        stack.append(n)
        out.append(comp)
    out.sort(key=lambda c: (min(p[1] for p in c), min(p[0] for p in c)))
    return out


def collect_pieces(root):
    """[(ad, tür, [katman hücre sözlükleri sırasıyla], hücre kümesi)]"""
    pieces = []
    order = 0
    for node in root:
        if node.tag == "group":
            layers = [layer_cells(l) for l in node.iter("layer")]
            cells = set()
            for lc in layers:
                cells |= set(lc)
            pieces.append((node.get("name").lower(), "cadir", layers, cells, order))
            order += 1
        elif node.tag == "layer":
            name = node.get("name")
            if name in GROUND_LAYERS:
                continue
            lc = layer_cells(node)
            comps = components(lc.keys(), name in FOUR_CONN_LAYERS)
            for i, comp in enumerate(comps):
                sub = {p: lc[p] for p in comp}
                kind = "ates" if name == CENTER_LAYER else ("karakter" if name[:1].isupper() and name not in ("Rocks", "Rocks2", "Logs", "Weapons") else "esya")
                pieces.append(("%s_%d" % (name.lower(), i) if len(comps) > 1 else name.lower(), kind, [sub], set(comp), order))
            order += 1
    return pieces


def render_piece(tilesets, tw, layers, cells, frames, skip_chars=True):
    x0 = min(p[0] for p in cells); y0 = min(p[1] for p in cells)
    x1 = max(p[0] for p in cells); y1 = max(p[1] for p in cells)
    w, h = (x1 - x0 + 1) * tw, (y1 - y0 + 1) * tw
    strip = Image.new("RGBA", (w * frames, h), (0, 0, 0, 0))
    for f in range(frames):
        for lc in layers:
            for (x, y), g in lc.items():
                if skip_chars and find_ts(tilesets, g)[0]["name"] in CHARACTER_TILESETS:
                    continue
                strip.alpha_composite(tile_image(tilesets, tw, g, f), (f * w + (x - x0) * tw, (y - y0) * tw))
    return strip, (x0 * tw, y0 * tw, w, h)


def trim(strip, frames, w, h):
    """Bütün karelerde boş olan kenar satır/sütunlarını kırpar (konum düzeltmesiyle)."""
    union = None
    for f in range(frames):
        bb = strip.crop((f * w, 0, (f + 1) * w, h)).getbbox()
        if bb is None:
            continue
        union = bb if union is None else (min(union[0], bb[0]), min(union[1], bb[1]), max(union[2], bb[2]), max(union[3], bb[3]))
    if union is None:
        return None
    l, t, r, b = union
    nw, nh = r - l, b - t
    out = Image.new("RGBA", (nw * frames, nh), (0, 0, 0, 0))
    for f in range(frames):
        out.paste(strip.crop((f * w + l, t, f * w + r, b)), (f * nw, 0))
    return out, l, t, nw, nh


def foot_row(img, w, h):
    """Kare 0'ın en alt dolu satırı (+1): derinlik ayak hizası (parçanın üst kenarından px)."""
    fr = img.crop((0, 0, w, h))
    px = fr.load()
    for y in range(h - 1, -1, -1):
        for x in range(w):
            if px[x, y][3] > 40:
                return y + 1
    return h


def fire_alignment():
    """Kertenkelesiz kazan hücresinin kertenkeleli hücreye göre kayması (ateş çukuru pikselleri en çok örtüşen kaydırma)."""
    sheet = Image.open(os.path.join(SRC, "Bonfire_boiler_lizardman.png")).convert("RGBA")
    c = FIRE_CELL
    lz = sheet.crop((FIRE_REF_LIZARD[1] * c, FIRE_REF_LIZARD[0] * c, FIRE_REF_LIZARD[1] * c + c, FIRE_REF_LIZARD[0] * c + c)).load()
    pt = sheet.crop((FIRE_REF_POT[1] * c, FIRE_REF_POT[0] * c, FIRE_REF_POT[1] * c + c, FIRE_REF_POT[0] * c + c)).load()
    best, best_s = -1, (0, 0)
    for dx in range(-30, 31):
        for dy in range(-30, 31):
            n = 0
            for y in range(c):
                for x in range(c):
                    q = pt[x, y]
                    if q[3] < 200:
                        continue
                    lx, ly = x + dx, y + dy
                    if 0 <= lx < c and 0 <= ly < c and lz[lx, ly] == q:
                        n += 1
            if n > best:
                best, best_s = n, (dx, dy)
    return best_s, best


def fire_strip():
    """Kertenkelesiz kazan ateşi: 12 kare yatay şerit (56x56 hücreler, sonra trim)."""
    sheet = Image.open(os.path.join(SRC, "Bonfire_boiler_lizardman.png")).convert("RGBA")
    c = FIRE_CELL
    strip = Image.new("RGBA", (c * len(FIRE_FRAMES), c), (0, 0, 0, 0))
    for f, (r, col) in enumerate(FIRE_FRAMES):
        strip.paste(sheet.crop((col * c, r * c, col * c + c, r * c + c)), (f * c, 0))
    return strip


def main():
    preview = None
    if "--onizleme" in sys.argv:
        preview = sys.argv[sys.argv.index("--onizleme") + 1]
    root, tw, tilesets = load_map()
    pieces = collect_pieces(root)
    os.makedirs(OUT, exist_ok=True)
    entries = []
    images = {}
    center = None
    lizard_origin = None ## örnekteki kertenkeleli ateş parçasının sol üstü (kamp öncesi koordinat)
    for name, kind, layers, cells, order in pieces:
        if kind == "ates":
            ## yalnız merkez + hizalama için: kertenkeleli ateş KARAKTERLE çizilir (skip_chars=False), kaydedilmez
            strip, (px, py, w, h) = render_piece(tilesets, tw, layers, cells, FRAMES, skip_chars=False)
            t = trim(strip, FRAMES, w, h)
            img, l, tp, nw, nh = t
            foot = foot_row(img, nw, nh)
            center = (px + l + nw / 2.0, py + tp + foot - 6.0)
            lizard_origin = (px + l, py + tp)
            continue
        frames = FRAMES if any(is_animated(tilesets, g) and find_ts(tilesets, g)[0]["name"] not in CHARACTER_TILESETS
                               for lc in layers for g in lc.values()) else 1
        strip, (px, py, w, h) = render_piece(tilesets, tw, layers, cells, frames)
        parts = [(name, strip, px, py, w, h)]
        if frames == 1 and name.split("_")[0] in {n.lower() for n in PIXEL_SPLIT_LAYERS}:
            parts = []
            for i, ((l, t, r, b), mask) in enumerate(pixel_blobs(strip)):
                blob = Image.new("RGBA", (r - l, b - t), (0, 0, 0, 0))
                src = strip.load()
                dst = blob.load()
                for mx, my in mask:
                    dst[mx - l, my - t] = src[mx, my]
                parts.append(("%s_%d" % (name, i), blob, px + l, py + t, r - l, b - t))
        for pname, pimg, ppx, ppy, pw, ph in parts:
            if pname not in KUCUK_KAMP:
                continue
            t = trim(pimg, frames, pw, ph)
            if t is None:
                continue
            img, l, tp, nw, nh = t
            x, y = ppx + l, ppy + tp
            foot = foot_row(img, nw, nh)
            fname = pname + ".png"
            images[fname] = img
            e = {"ad": pname, "tur": kind, "dosya": fname, "x": x, "y": y, "w": nw, "h": nh, "kare": frames, "ayak": foot, "sira": order}
            if kind == "cadir":
                e["engel_r"] = round(nw * TENT_BLOCK_K, 1)
            entries.append(e)
    if center is None:
        raise SystemExit("kamp ateşi katmanı yok: " + CENTER_LAYER)
    missing = KUCUK_KAMP - {e["ad"] for e in entries}
    if missing:
        raise SystemExit("küçük kamp parçası bulunamadı: %s" % sorted(missing))
    ## kertenkelesiz kazan ateşi: kertenkeleli referans karenin (eşleştirmede kare 0 = hücre (1,0), kırpma (1,10)) yerine hizalanır
    (sdx, sdy), score = fire_alignment()
    fstrip = fire_strip()
    t = trim(fstrip, len(FIRE_FRAMES), FIRE_CELL, FIRE_CELL)
    fimg, fl, ftp, fnw, fnh = t
    ## pot hücresindeki p pikseli kertenkele hücresinde p + s'ye düşer; kertenkeleli parça kare 0'ı hücrenin (1, 10) pikselinden başlıyordu
    LIZ_CROP = (1, 10)
    fx = lizard_origin[0] + (fl + sdx - LIZ_CROP[0])
    fy = lizard_origin[1] + (ftp + sdy - LIZ_CROP[1])
    ffoot = foot_row(fimg, fnw, fnh)
    images["ates.png"] = fimg
    entries.append({"ad": "ates", "tur": "ates", "dosya": "ates.png", "x": fx, "y": fy, "w": fnw, "h": fnh, "kare": len(FIRE_FRAMES),
                    "ayak": ffoot, "sira": 0})
    print("ateş hizası", (sdx, sdy), "örtüşen piksel", score)
    for e in entries:
        e["x"] = round(e["x"] - center[0], 1)
        e["y"] = round(e["y"] - center[1], 1)
    for fname, img in images.items():
        img.save(os.path.join(OUT, fname))
    xs = [e["x"] for e in entries] + [e["x"] + e["w"] for e in entries]
    ys = [e["y"] for e in entries] + [e["y"] + e["h"] for e in entries]
    layout = {"kaynak": "tools/kamp/kaynak/Camp.tmx (Craftpix Camp)", "kare_ms": FRAME_MS, "kapsam": [min(xs), min(ys), max(xs), max(ys)],
              "parcalar": entries}
    ## Artık üretilmeyen eski parçalar (PNG + Godot'un .import'u) silinir; aynı adlı parçalar yerinde yazılır (.import / uid korunur).
    keep = {e["dosya"] for e in entries}
    for f in os.listdir(OUT):
        base = f[:-7] if f.endswith(".import") else f
        if base.endswith(".png") and base not in keep:
            os.remove(os.path.join(OUT, f))
    gd = os.path.join(REPO, "scripts", "pvp", "kamp_yerlesim.gd")
    with open(gd, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("extends RefCounted\n\n")
        fh.write("## ÜRETİLDİ: tools/kamp/gen_kamp.py (elle düzenleme; yeniden üret). Takım üssü kampının parçaları (madde 607, team_camp.gd).\n")
        fh.write("## x / y = parçanın sol üst köşesi, kamp merkezine (kamp ateşi) göre dünya birimi (1 sanat px = 1 birim); ayak = üst kenardan\n")
        fh.write("## derinlik ayak hizası; kare = animasyon karesi (yatay şerit); engel_r = çadır çarpışma çemberi (move_blockers).\n\n")
        fh.write("const DIR := \"res://assets/map/kamp/\"\n")
        fh.write("const KARE_MS := %d\n" % FRAME_MS)
        k = layout["kapsam"]
        fh.write("const KAPSAM := Rect2(%s, %s, %s, %s)\n" % (k[0], k[1], k[2] - k[0], k[3] - k[1]))
        fh.write("const PARCALAR: Array = [\n")
        for e in entries:
            fh.write("\t" + json.dumps(e, ensure_ascii=False) + ",\n")
        fh.write("]\n")
    print("parça", len(entries), "kapsam", layout["kapsam"])
    for e in entries:
        print(" ", e["tur"], e["ad"], e["w"], "x", e["h"], "kare", e["kare"])
    if preview:
        x0, y0, x1, y1 = [int(round(v)) for v in layout["kapsam"]]
        pad = 16
        can = Image.new("RGBA", (x1 - x0 + 2 * pad, y1 - y0 + 2 * pad), (86, 120, 60, 255))
        for e in sorted(entries, key=lambda e: e["y"] + e["ayak"]):
            im = Image.open(os.path.join(OUT, e["dosya"])).crop((0, 0, e["w"], e["h"]))
            can.alpha_composite(im, (int(e["x"] - x0 + pad), int(e["y"] - y0 + pad)))
        can = can.resize((can.width * 2, can.height * 2), Image.NEAREST)
        can.save(preview)
        print("önizleme", preview)


if __name__ == "__main__":
    main()
