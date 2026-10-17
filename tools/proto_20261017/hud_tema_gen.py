"""HUD TEMA prototipi (2026-10-17) - doku üreticisi. Oyuna bağlı DEĞİL.

Mevcut HUD kit dokularını (assets/ui/kit + assets/ui/game) AYNI boyut ve AYNI silüetle (dış şekil, delik, köşe
yarıçapı, 9-dilim payları) yeniden boyar: sadece çerçeve/arka plan rengi ve kabartması değişir, yerleşim değişmez.
Her doku kendi ön ölçeğinde (2x / 3x) sanat pikseline indirilir, boyanır, aynı ölçeğe geri büyütülür.

Çıktı: tools/proto_20261017/out/hud_tema/tex_<TEMA>/<res yolu, / yerine __>.png
Kullanım: python tools/proto_20261017/hud_tema_gen.py
Okuyan: tools/proto_20261017/hud_tema_capture.gd (Resource.take_over_path ile orijinal yolun yerine geçirir).
"""
from __future__ import annotations

import os
from collections import deque

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "tools", "proto_20261017", "out", "hud_tema")


def hx(s: str, a: int = 255) -> tuple:
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


# ---------------------------------------------------------------------------------------------- temalar
# out: dış hat | rim/rim_hi/rim_lo: çerçeve gövdesi + üst/alt kabartma | fill: panel içi | line: dolgu içi ince çizgi
# inset: kuyu (çubuk/yuva içi) | acc*: rozet (seviye) | spirit: F yuvası tonu | fill_a: panel opaklığı
THEMES = {
    "A": {  # Koyu Ceviz - seyyar satıcı/demirci koyu ahşap kitiyle akraba (shop_dark_kit PAL_WOOD)
        "out": "#110b07", "rim": "#5b4431", "rim_hi": "#7b5d42", "rim_lo": "#3e2e20",
        "fill": "#261d16", "line": "#33281e", "inset": "#18120d", "fill_a": 236,
        "acc": "#b98a46", "acc_hi": "#dcb06a", "acc_lo": "#7c5928",
        "spirit": "#6d5a92", "spirit_hi": "#8e7bb6", "spirit_lo": "#4a3c66",
        "sky_top": "#2c241d", "sky_bot": "#3a2f25", "ground": "#3f4a2c",
        "text": "#efe2c6", "dim": "#ad9b80", "price": "#f2c674",
    },
    "B": {  # Orman Gecesi - ana menü / karakter seçimi koyu kitiyle akraba (menu_dark_kit)
        "out": "#08100e", "rim": "#2f4a42", "rim_hi": "#46665c", "rim_lo": "#1f332d",
        "fill": "#15221f", "line": "#1d2e2a", "inset": "#0e1817", "fill_a": 232,
        "acc": "#5f9a84", "acc_hi": "#93c9a6", "acc_lo": "#2f5f4a",
        "spirit": "#5d5a8e", "spirit_hi": "#8180b4", "spirit_lo": "#3c3a62",
        "sky_top": "#1a2a27", "sky_bot": "#22362f", "ground": "#2f4a2e",
        "text": "#e7efe3", "dim": "#92aba2", "price": "#f0da94",
    },
    "C": {  # Arduvaz ve Pirinç - klasik RPG: koyu arduvaz zemin, soluk pirinç kenar (shop_dark_kit PAL_SLATE)
        "out": "#0a0d13", "rim": "#6a5735", "rim_hi": "#9a8152", "rim_lo": "#463a24",
        "fill": "#1b212d", "line": "#252d3c", "inset": "#11161f", "fill_a": 236,
        "acc": "#b99654", "acc_hi": "#dcc07e", "acc_lo": "#7a5f2c",
        "spirit": "#6a5a96", "spirit_hi": "#8f80bc", "spirit_lo": "#463c6a",
        "sky_top": "#1f2633", "sky_bot": "#2a3242", "ground": "#34452f",
        "text": "#ece6d7", "dim": "#96a0b2", "price": "#eccb7e",
    },
    "D": {  # Kısık Ahşap - mevcut kitin kendisi, parlaklık ve doygunluk düşük (en az değişiklik)
        "out": "#20150d", "rim": "#6a4a30", "rim_hi": "#86623f", "rim_lo": "#4b3320",
        "fill": "#5a4734", "line": "#665240", "inset": "#271a11", "fill_a": 255,
        "acc": "#a98140", "acc_hi": "#cba15e", "acc_lo": "#71532a",
        "spirit": "#66548a", "spirit_hi": "#8673aa", "spirit_lo": "#45385e",
        "sky_top": "#5b4b3a", "sky_bot": "#665543", "ground": "#55623a",
        "text": "#f3e6cc", "dim": "#c4b090", "price": "#f6d27e",
    },
}

THEME_NAMES = {"A": "Koyu Ceviz", "B": "Orman Gecesi", "C": "Arduvaz ve Pirinç", "D": "Kısık Ahşap"}

# kind: frame = delikli çerçeve (rim = delik ile dış arası) | panel = dolu panel (rim kalınlığı `rim` sanat pikseli)
# pal: "base" | "acc" (rozet) | "spirit" (F yuvası)
TARGETS = [
    ("assets/ui/kit/panel_ability_bar.png", "panel", {"rim": 3, "line": True}),
    ("assets/ui/kit/hud_skill_frame.png", "frame", {}),
    ("assets/ui/kit/hud_skill_frame_small.png", "frame", {}),
    ("assets/ui/kit/hud_skill_frame_spirit.png", "frame", {"pal": "spirit"}),
    ("assets/ui/kit/hud_avatar_frame.png", "frame", {}),
    ("assets/ui/kit/hud_avatar_bg.png", "backdrop", {}),
    ("assets/ui/kit/hud_level_badge.png", "panel", {"rim": 3, "pal": "acc"}),
    ("assets/ui/kit/hud_minimap_ring.png", "frame", {"unit": 2}),
    ("assets/ui/kit/panel_status_badge.png", "panel", {"rim": 2}),
    ("assets/ui/game/hud_plaque_clean.png", "panel", {"rim": 2}),
    ("assets/ui/game/plaque.png", "panel", {"rim": 2}),
    ("assets/ui/game/inset.png", "inset", {}),
    ("assets/ui/game/btn_tan_normal.png", "panel", {"rim": 2, "btn": "normal"}),
    ("assets/ui/game/btn_tan_hover.png", "panel", {"rim": 2, "btn": "hover"}),
    ("assets/ui/game/btn_tan_pressed.png", "panel", {"rim": 2, "btn": "pressed"}),
    ("assets/ui/game/btn_mini_tan_normal.png", "panel", {"rim": 2, "btn": "normal"}),
    ("assets/ui/game/btn_mini_tan_hover.png", "panel", {"rim": 2, "btn": "hover"}),
    ("assets/ui/game/btn_mini_tan_pressed.png", "panel", {"rim": 2, "btn": "pressed"}),
]


# ---------------------------------------------------------------------------------------------- ölçek
def detect_scale(im: Image.Image) -> tuple[int, int, int]:
    w, h = im.size
    px = im.load()
    for s in (3, 2):
        for oy in range(s):
            for ox in range(s):
                ok = True
                for y0 in range(oy, h - s + 1, s):
                    for x0 in range(ox, w - s + 1, s):
                        c = px[x0, y0]
                        for dy in range(s):
                            for dx in range(s):
                                if px[x0 + dx, y0 + dy] != c:
                                    ok = False
                                    break
                            if not ok:
                                break
                        if not ok:
                            break
                    if not ok:
                        break
                if ok:
                    return s, ox, oy
    return 1, 0, 0


def to_art(im: Image.Image, s: int, ox: int, oy: int) -> Image.Image:
    if s == 1:
        return im.copy()
    w, h = im.size
    aw = (w - ox + s - 1) // s + (1 if ox else 0)
    ah = (h - oy + s - 1) // s + (1 if oy else 0)
    art = Image.new("RGBA", (aw, ah), (0, 0, 0, 0))
    px = im.load()
    ap = art.load()
    for ay in range(ah):
        for ax in range(aw):
            x = min(w - 1, max(0, (ax - (1 if ox else 0)) * s + ox))
            y = min(h - 1, max(0, (ay - (1 if oy else 0)) * s + oy))
            ap[ax, ay] = px[x, y]
    return art


def from_art(art: Image.Image, s: int, ox: int, oy: int, size: tuple[int, int]) -> Image.Image:
    if s == 1:
        return art
    w, h = size
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    ap = art.load()
    op = out.load()
    for y in range(h):
        ay = (y - oy) // s + (1 if oy else 0) if y >= oy else 0
        for x in range(w):
            ax = (x - ox) // s + (1 if ox else 0) if x >= ox else 0
            op[x, y] = ap[min(ax, art.width - 1), min(ay, art.height - 1)]
    return out


# ---------------------------------------------------------------------------------------------- mesafe
def distances(art: Image.Image) -> tuple[list, list, bool]:
    """d_out: en yakın DIŞ saydam piksele 8-komşu adım; d_in: en yakın DELİK pikseline. has_hole."""
    w, h = art.size
    a = art.load()
    solid = [[a[x, y][3] > 0 for x in range(w)] for y in range(h)]
    INF = 10 ** 6
    # dış: kenara bağlı saydamlar (+ resim dışı)
    ext = [[False] * w for _ in range(h)]
    q = deque()
    for y in range(h):
        for x in range(w):
            if (x in (0, w - 1) or y in (0, h - 1)) and not solid[y][x]:
                ext[y][x] = True
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not ext[ny][nx] and not solid[ny][nx]:
                ext[ny][nx] = True
                q.append((nx, ny))
    hole = [[(not solid[y][x]) and not ext[y][x] for x in range(w)] for y in range(h)]
    has_hole = any(any(r) for r in hole)

    def bfs(seed_fn, border_counts: bool) -> list:
        d = [[INF] * w for _ in range(h)]
        q2 = deque()
        for y in range(h):
            for x in range(w):
                if seed_fn(x, y):
                    d[y][x] = 0
                    q2.append((x, y))
        if border_counts:
            for y in range(h):
                for x in range(w):
                    if solid[y][x] and (x in (0, w - 1) or y in (0, h - 1)) and d[y][x] > 1:
                        d[y][x] = 1
                        q2.append((x, y))
        while q2:
            x, y = q2.popleft()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and d[ny][nx] > d[y][x] + 1:
                        d[ny][nx] = d[y][x] + 1
                        q2.append((nx, ny))
        return d

    d_out = bfs(lambda x, y: ext[y][x], True)
    d_in = bfs(lambda x, y: hole[y][x], False) if has_hole else [[INF] * w for _ in range(h)]
    return d_out, d_in, has_hole


def facing(d: list, x: int, y: int, k: int, w: int, h: int) -> str:
    """Bu kabuk pikselinin dışa baktığı yön: üst/sol = 'hi', alt/sağ = 'lo', ikisi de değil = ''."""
    def lt(nx, ny):
        return not (0 <= nx < w and 0 <= ny < h) or d[ny][nx] < k
    if lt(x, y - 1):
        return "hi"
    if lt(x, y + 1):
        return "lo"
    if lt(x - 1, y):
        return "hi"
    if lt(x + 1, y):
        return "lo"
    return ""


# ---------------------------------------------------------------------------------------------- boyama
def pal_of(t: dict, which: str) -> tuple:
    if which == "acc":
        return hx(t["acc"]), hx(t["acc_hi"]), hx(t["acc_lo"])
    if which == "spirit":
        return hx(t["spirit"]), hx(t["spirit_hi"]), hx(t["spirit_lo"])
    return hx(t["rim"]), hx(t["rim_hi"]), hx(t["rim_lo"])


def mix(c1: tuple, c2: tuple, f: float) -> tuple:
    return tuple(int(round(c1[i] + (c2[i] - c1[i]) * f)) for i in range(3)) + (c1[3],)


def paint_frame(art: Image.Image, t: dict, opt: dict) -> Image.Image:
    w, h = art.size
    d_out, d_in, has_hole = distances(art)
    src = art.load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    o = out.load()
    rim, rim_hi, rim_lo = pal_of(t, opt.get("pal", "base"))
    oc = hx(t["out"])
    for y in range(h):
        for x in range(w):
            a = src[x, y][3]
            if a == 0:
                continue
            if a < 255:  # deliğe düşen yarı saydam iç gölge: koyu, aynı opaklık
                o[x, y] = oc[:3] + (a,)
                continue
            u = int(opt.get("unit", 1))  # 1x saklanan doku (halka): 2 ekran pikseli = 1 sanat pikseli
            do, di = (d_out[y][x] + u - 1) // u, (d_in[y][x] + u - 1) // u
            if do == 1 or di == 1:
                o[x, y] = oc
            elif do == 2:
                f = facing(d_out, x, y, u + 1, w, h)
                o[x, y] = rim_hi if f == "hi" else (rim_lo if f == "lo" else rim)
            elif di == 2:
                # delik kenarı ters kabartma: üstü gölgede (içe gömük his)
                f = facing(d_in, x, y, u + 1, w, h)
                o[x, y] = rim_lo if f == "hi" else (mix(rim, rim_hi, 0.5) if f == "lo" else rim)
            else:
                o[x, y] = rim
    return out


def paint_panel(art: Image.Image, t: dict, opt: dict) -> Image.Image:
    w, h = art.size
    d_out, _, _ = distances(art)
    src = art.load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    o = out.load()
    which = opt.get("pal", "base")
    rim, rim_hi, rim_lo = pal_of(t, which)
    oc = hx(t["out"])
    rimw = int(opt.get("rim", 2))
    if which == "acc":
        # rozet: pirinç/kehribar halka + koyu yüz (sarı seviye rakamı okunur kalsın)
        fill = mix(hx(t["fill"]), hx(t["acc_lo"]), 0.3)
        fill_hi = mix(fill, hx(t["acc_lo"]), 0.5)
    else:
        fill = hx(t["fill"], t["fill_a"])
        fill_hi = hx(t["line"], t["fill_a"])
    btn = opt.get("btn", "")
    if btn:
        # düğme: ahşap/taş gövde = rim tonu (panelden açık), hover biraz açık, pressed koyu
        base = hx(t["rim"])
        fill = {"normal": mix(base, hx(t["fill"]), 0.35), "hover": mix(base, hx(t["rim_hi"]), 0.25),
                "pressed": mix(base, hx(t["fill"]), 0.6)}[btn]
        fill_hi = mix(fill, hx(t["rim_hi"]), 0.45)
    for y in range(h):
        for x in range(w):
            if src[x, y][3] == 0:
                continue
            do = d_out[y][x]
            if do == 1:
                o[x, y] = oc
            elif do <= rimw:
                f = facing(d_out, x, y, do, w, h)
                if btn == "pressed":
                    f = {"hi": "lo", "lo": "hi"}.get(f, f)
                o[x, y] = rim_hi if f == "hi" else (rim_lo if f == "lo" else rim)
            elif do == rimw + 1:
                if which == "acc":
                    f = facing(d_out, x, y, do, w, h)
                    o[x, y] = fill_hi if f == "hi" else fill
                elif opt.get("line"):
                    # büyük panelde kenar ile dolgu arasında ince koyu oluk (çerçeve hissi, süs yok)
                    o[x, y] = mix(hx(t["out"]), fill, 0.35)[:3] + (255,)
                else:
                    f = facing(d_out, x, y, do, w, h)
                    o[x, y] = fill_hi if f == "hi" else fill
            elif opt.get("line") and do == rimw + 2:
                o[x, y] = fill_hi
            else:
                o[x, y] = fill
    return out


def paint_inset(art: Image.Image, t: dict, opt: dict) -> Image.Image:
    """Kuyu: dış hat koyu, üst iç kenar gölge, alt iç kenar hafif ışık, iç koyu."""
    w, h = art.size
    d_out, _, _ = distances(art)
    src = art.load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    o = out.load()
    oc = hx(t["out"])
    ins = hx(t["inset"])
    for y in range(h):
        for x in range(w):
            if src[x, y][3] == 0:
                continue
            do = d_out[y][x]
            if do == 1:
                o[x, y] = oc
            elif do == 2:
                f = facing(d_out, x, y, 2, w, h)
                o[x, y] = mix(ins, oc, 0.5) if f == "hi" else (mix(ins, hx(t["rim"]), 0.35) if f == "lo" else ins)
            else:
                o[x, y] = ins
    return out


def paint_backdrop(art: Image.Image, t: dict, opt: dict) -> Image.Image:
    """Portre arkası: üstte koyu gök, altta biraz açık, alt üçte birde soluk yer elipsi (eski bej/yeşilin koyu karşılığı)."""
    w, h = art.size
    src = art.load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    o = out.load()
    top, bot, gr = hx(t["sky_top"]), hx(t["sky_bot"]), hx(t["ground"])
    cx, cy, rx, ry = (w - 1) / 2.0, h * 0.86, w * 0.42, h * 0.11
    for y in range(h):
        f = y / max(1, h - 1)
        for x in range(w):
            if src[x, y][3] == 0:
                continue
            c = top if f < 0.45 else (bot if f > 0.6 else (top if (x + y) % 2 == 0 else bot))
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                c = gr
            o[x, y] = c[:3] + (255,)
    return out


PAINTERS = {"frame": paint_frame, "panel": paint_panel, "inset": paint_inset, "backdrop": paint_backdrop}


def main() -> None:
    import json
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "palettes.json"), "w", encoding="utf-8") as f:
        json.dump({k: dict(v, name=THEME_NAMES[k]) for k, v in THEMES.items()}, f, ensure_ascii=False, indent=1)
    for key, t in THEMES.items():
        d = os.path.join(OUT, "tex_" + key)
        os.makedirs(d, exist_ok=True)
        for rel, kind, opt in TARGETS:
            src_path = os.path.join(ROOT, rel)
            if not os.path.exists(src_path):
                print("YOK", rel)
                continue
            im = Image.open(src_path).convert("RGBA")
            s, ox, oy = detect_scale(im)
            art = to_art(im, s, ox, oy)
            painted = PAINTERS[kind](art, t, opt)
            res = from_art(painted, s, ox, oy, im.size)
            res.save(os.path.join(d, rel.replace("/", "__")))
            if key == "A":
                print(f"{rel}: {im.size} olcek {s} ofset {ox},{oy} sanat {art.size}")
    print("tamam ->", OUT)


if __name__ == "__main__":
    main()
