"""Prototipleri gerçek oyun karelerinin üstüne yerleştirir, sayfa için PNG'leri üretir."""
import os, sys
from PIL import Image
from art import *
import protos_top as PT
import protos_world as PW

SP = os.environ.get("BOSS_PROTO_DIR", "C:/temp/boss_proto")  # içinde cap/ (boss_capture.gd çıktısı) olan çalışma klasörü
OUT = SP + "/page"
os.makedirs(OUT, exist_ok=True)
SINGLE = Image.open(SP + "/cap/single.png").convert("RGBA")
MULTI = Image.open(SP + "/cap/multi.png").convert("RGBA")
CURRENT = Image.open(SP + "/cap/current_single.png").convert("RGBA")

TOP_Y = 40  # FPS etiketinin (y 12-30) altı

# boss kafa konumları (ekran px): (merkez x, tepe y)
HEAD_SINGLE = {"golem": (1450, 167)}
HEAD_MULTI = {"golem": (1470, 188), "agac": (420, 42), "lich": (927, 664)}
NAMES_TOP = {"golem": "KADİM GOLEM", "agac": "AĞAÇ", "lich": "LICH"}
NAMES_WORLD = {"golem": "GOLEM", "agac": "AĞAÇ", "lich": "LICH"}

# bağlamda gösterilen durumlar (can, kalkan)
ST_SINGLE = {"golem": (0.85, 0.70)}
ST_MULTI = {"golem": (0.90, 0.80), "agac": (0.55, 0.0), "lich": (0.30, 0.20)}
# durum şeridi (4 durum): kalkan tam / kalkan yarı / kalkan kırık / can kritik
STATES = [("Kalkan tam", 1.0, 1.0), ("Kalkan eriyor", 0.92, 0.38), ("Kalkan kırıldı", 0.55, 0.0), ("Can kritik", 0.12, 0.0)]

GRASS = SINGLE.crop((1190, 690, 1890, 1060))  # gerçek çimen yaması (şerit zemini)


def grass_bg(w, h):
    bg = Image.new("RGBA", (w, h))
    gw, gh = GRASS.size
    for iy, y in enumerate(range(0, h, gh)):
        for ix, x in enumerate(range(0, w, gw)):
            tile = GRASS
            if ix % 2:
                tile = tile.transpose(Image.FLIP_LEFT_RIGHT)
            if iy % 2:
                tile = tile.transpose(Image.FLIP_TOP_BOTTOM)
            bg.paste(tile, (x, y))
    return bg


def put(img, art, scale, x, y):
    img.alpha_composite(art.scaled(scale), (int(x), int(y)))


# ------------------------------------------------------------------ ÜST
def make_top(key, title, fn, cfn):
    # 1) bağlamda tek boss
    f = SINGLE.copy()
    art = fn(NAMES_TOP["golem"], *ST_SINGLE["golem"])
    put(f, art, 3, 960 - art.w * 3 // 2, TOP_Y)
    f.crop((480, 0, 1440, 230)).save(f"{OUT}/top_{key}_ctx.png")
    # 2) çoklu boss: ana çubuk + diğer ikisi küçük
    f = MULTI.copy()
    art = fn(NAMES_TOP["golem"], *ST_MULTI["golem"])
    put(f, art, 3, 960 - art.w * 3 // 2, TOP_Y)
    y = TOP_Y + art.h * 3 + 8
    for b in ("agac", "lich"):
        c = cfn(NAMES_TOP[b], *ST_MULTI[b])
        put(f, c, 3, 960 - c.w * 3 // 2, y)
        y += c.h * 3 + 6
    f.crop((480, 0, 1440, max(y + 14, 330))).save(f"{OUT}/top_{key}_multi.png")
    # 3) durum şeridi
    arts = [fn(NAMES_TOP["golem"], hp, sh) for (_, hp, sh) in STATES]
    wmax = max(a.w for a in arts) * 3 + 40
    hs = [a.h * 3 + 26 for a in arts]
    strip = grass_bg(wmax, sum(hs) + 10)
    y = 10
    for (label, _, _), a, h in zip(STATES, arts, hs):
        put(strip, a, 3, (wmax - a.w * 3) // 2, y)
        y += h
    strip.save(f"{OUT}/top_{key}_states.png")


# ------------------------------------------------------------------ DÜNYA
def place_world(img, art, head, hp_sh, name, gap=12):
    x = head[0] - art.w  # art px*2 -> merkez
    y = head[1] - gap - art.h * 2
    y = max(y, 4)
    put(img, art, 2, x, y)


def make_world(key, title, fn):
    # 1) bağlamda tek boss (golem)
    f = SINGLE.copy()
    art = fn(*ST_SINGLE["golem"][:2][::1], NAMES_WORLD["golem"]) if fn.__name__ == "world_o2" else fn(*ST_SINGLE["golem"])
    place_world(f, art, HEAD_SINGLE["golem"], None, None)
    f.crop((1200, 0, 1700, 440)).save(f"{OUT}/world_{key}_single.png")
    # 2) çoklu boss: üç boss'un yakın kesitleri yan yana
    f = MULTI.copy()
    for b in ("golem", "agac", "lich"):
        hp, sh = ST_MULTI[b]
        a = fn(hp, sh, NAMES_WORLD[b]) if fn.__name__ == "world_o2" else fn(hp, sh)
        place_world(f, a, HEAD_MULTI[b], None, None)
    crops = [(1290, 40, 1650, 380), (240, 0, 600, 340), (747, 520, 1107, 860)]
    strip = Image.new("RGBA", (360 * 3 + 8, 340))
    for i, c in enumerate(crops):
        strip.paste(f.crop(c), (i * 364, 0))
    strip.save(f"{OUT}/world_{key}_multi.png")
    # 3) durum şeridi
    arts = [(fn(hp, sh, NAMES_WORLD["golem"]) if fn.__name__ == "world_o2" else fn(hp, sh)) for (_, hp, sh) in STATES]
    wmax = max(a.w for a in arts) * 2 + 30
    cellw = wmax
    strip = grass_bg(cellw * 4 + 30, max(a.h for a in arts) * 2 + 50)
    for i, ((label, _, _), a) in enumerate(zip(STATES, arts)):
        put(strip, a, 2, 15 + i * cellw + (cellw - a.w * 2) // 2, 22)
    strip.save(f"{OUT}/world_{key}_states.png")


if __name__ == "__main__":
    for key, (title, fn, cfn) in PT.TOPS.items():
        make_top(key, title, fn, cfn)
    for key, (title, fn) in PW.WORLDS.items():
        make_world(key, title, fn)
    CURRENT.crop((1200, 0, 1700, 440)).save(f"{OUT}/current_single.png")
    print("ok", sorted(os.listdir(OUT)))
