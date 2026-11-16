#!/usr/bin/env python3
"""Nox (Vampir Cocuk, roster 13) E yetenegi (Yarasa Formu) - buyuk yarasa gorunumu, KULLANICININ HAZIR SAYFASINDAN.

Kullanici istegi (2026-11-16): "Nox'un yarasa donusum skilindeki yarasa formunu bununla degistir." + bat_fly.png.
Eskiden bu betik yarasayi kodla ciziyordu (2026-09-24 tasarimi, 4 yon x 4 kare; git gecmisinde). Artik kaynak:
  tools/vampir_bat_kaynak/bat_fly.png  (957x348, 87x87 hucre, 11 sutun = tek kanat cirpma dongusu, 4 renk, 1:1 piksel)
  satir 1 = onden (gozler/disler gorunur) -> down
  satir 2 = arkadan (goz yok)            -> up
  satir 3 = sola bakan                   -> left
  satir 4 = saga bakan (satir 3'un aynasi) -> right
Cikti: assets/characters/vampir/bat_sheet.png - 96x112 hucre (eskisiyle AYNI tuval: karakterin anim.offset'i,
BAT_FORM_SCALE_MULT ve havada durma yuksekligi degismez), satirlar DIR_ROWS sirasinda (down, left, right, up),
11 sutun. Klip adlari (bat_<yon>) degismez - uzak oyuncular bu adi taniyor (vampir_math.gd is_bat_anim).
--tres: vampir_frames.tres'teki bat_<yon> AtlasTexture'larini + kliplerini yeni kare sayisina gore yeniden yazar
(import_character_sheets.py'yi tum karakterlerde yeniden kosmadan; o betik sit_/ride_ kliplerini bilmiyor).
Boyama: varsayilan Nox renkleri + 1 px kontur (kullanici prototip C'yi secti, paint_nox_cell); --orijinal = bat_fly.png renkleri.
Kullanim: python tools/gen_vampir_bat_form.py [--tres] [--orijinal]
"""
import os
import re
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_PATH = os.path.join(ROOT, "tools", "vampir_bat_kaynak", "bat_fly.png")
OUT_PATH = os.path.join(ROOT, "assets", "characters", "vampir", "bat_sheet.png")
TRES_PATH = os.path.join(ROOT, "assets", "characters", "vampir_frames.tres")
SRC_CELL = 87
CELL_W, CELL_H = 96, 112
FRAMES = 11
FPS = 18.0  # 11 kare -> ~0.6 sn'lik bir kanat cirpma (eskisi 4 kare @10)
## Kaynak hucrenin (87x87) 96x112 hucredeki yeri: yatay ortalanir (yarasanin ekseni x=48), govde/bas eski karelerin
## govde satirina (~y 50) gelecek kadar asagi.
OFF_X, OFF_Y = 5, 2
DIR_ROWS = [("down", 0), ("left", 1), ("right", 2), ("up", 3)]  # import_character_sheets.py DIR_ROWS ile ayni
SRC_ROW = {"down": 0, "up": 1, "left": 2, "right": 3}


## Kaynak sayfa DEGISTIRILMEZ; temizlik yuklerken uygulanir (kullanici 2026-11-16: "fazladan pixeller var bunlari kaldir,
## yukari ve asagiyi biraz guzellestir"). Onden/arkadan (satir 1-2) kanatlar kalkikken (kare 1, 8-11) kafanin ustunden
## gittikce uzayan koyu bir "diken" cikiyordu (kare 11'de ucu kopuk 7 px'lik nokta). Bu karelerde kafa, kanatlar
## asagidayken (kare 2-7) cizilen kafanin aynisi: kulak satiri = goz satiri - 4, kulaklar x 40 / 46, aralarinda 3 px tepe.
## Kulak satirinin ustundeki orta bant (x 36-50) silinir, kulak satiri bu desene cekilir; kare 2-7'de islem etkisizdir.
EYE_RGB = (255, 0, 0)
DARK = (31, 14, 20, 255)
MEM = (80, 27, 46, 255)
CLEAR = (0, 0, 0, 0)
HEAD_BAND = range(36, 51)


def fix_head_spike(src: Image.Image) -> int:
    px = src.load()
    changed = 0
    for c in range(FRAMES):
        x0 = c * SRC_CELL
        eye_rows = [y for y in range(SRC_CELL) for x in HEAD_BAND if px[x0 + x, y][3] and px[x0 + x, y][:3] == EYE_RGB]
        ear = min(eye_rows) - 4
        assert px[x0 + 40, ear] == MEM and px[x0 + 46, ear] == MEM, f"kare {c + 1}: kulak satiri beklenen yerde degil"
        for sr, ear_col in ((0, MEM), (1, DARK)):  # 0 = onden (kulak ici kizil), 1 = arkadan (kulak koyu)
            y0 = sr * SRC_CELL
            want = {(x, y): CLEAR for y in range(ear) for x in HEAD_BAND}
            want.update({(40, ear): ear_col, (41, ear): CLEAR, (42, ear): DARK, (43, ear): DARK, (44, ear): DARK,
                         (45, ear): CLEAR, (46, ear): ear_col})
            for (x, y), col in want.items():
                cur = px[x0 + x, y0 + y]
                if (cur[3] == 0 and col[3] == 0) or cur == col:
                    continue
                px[x0 + x, y0 + y] = col
                changed += 1
    return changed


## NOX RENKLERI (kullanici 2026-11-16 prototip C'yi secti; prototipler tools/proto_20261109/nox_yarasa_proto.py): siluet / kare
## ayni, yalniz boyama. Kanat zari (>= 40 px'lik kizil bilesen) Nox'un pelerin kizilinda, kemige (koyu piksele) uzakliga gore
## duz bantlar (DITHER YOK): kemik dibi / taban / acik + dis kenar parlak kizil. Kucuk kizil bilesenler (yuz, kulak ici) pelerin
## tabani; koyu govde/kemik kurk siyahi, ustu bos olan koyu pikselde serin bir isik. Siluetin cevresinde Nox'un kendi kontur
## renginde 1 px dis kontur (8-komsu). Goz ve disler aynen. --orijinal: kullanicinin kendi renkleri (bu boyama atlanir).
NOX_WING = [(0x41, 0x13, 0x10), (0x5b, 0x16, 0x10), (0x8b, 0x1b, 0x16)]  # kemik dibi (d<=1) / taban (d<=4) / acik
NOX_WING_EDGE = (0xb2, 0x2c, 0x2e)
NOX_FACE = (0x5b, 0x16, 0x10)
NOX_FUR, NOX_FUR_TOP = (0x1d, 0x1d, 0x22), (0x3a, 0x2d, 0x38)
NOX_OUTLINE = (0x17, 0x12, 0x12)
WING_MIN_PX = 40
N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))
N8 = N4 + ((1, 1), (1, -1), (-1, 1), (-1, -1))


def paint_nox_cell(out: Image.Image, x0: int, y0: int) -> None:
    px = out.load()
    kind = {}
    for y in range(CELL_H):
        for x in range(CELL_W):
            p = px[x0 + x, y0 + y]
            if p[3]:
                kind[(x, y)] = "D" if p == DARK else "M" if p == MEM else "?"
    ## Kizil bilesen boyu (4-komsu) -> kanat mi, yuz mu.
    msize = {}
    for p, k in kind.items():
        if k != "M" or p in msize:
            continue
        comp = [p]
        msize[p] = 0
        i = 0
        while i < len(comp):
            x, y = comp[i]
            i += 1
            for dx, dy in N4:
                n = (x + dx, y + dy)
                if n not in msize and kind.get(n) == "M":
                    msize[n] = 0
                    comp.append(n)
        for c in comp:
            msize[c] = len(comp)
    ## Kizil pikselin koyu piksele (kemik/govde) 4-komsu BFS uzakligi.
    dist = {p: 0 for p, k in kind.items() if k == "D"}
    q = list(dist)
    i = 0
    while i < len(q):
        x, y = q[i]
        i += 1
        for dx, dy in N4:
            n = (x + dx, y + dy)
            if n not in dist and kind.get(n) == "M":
                dist[n] = dist[(x, y)] + 1
                q.append(n)

    def put(x: int, y: int, rgb: tuple) -> None:
        px[x0 + x, y0 + y] = rgb + (255,)

    for (x, y), k in kind.items():
        if k == "M" and msize[(x, y)] >= WING_MIN_PX:
            if any((x + dx, y + dy) not in kind for dx, dy in N4):
                put(x, y, NOX_WING_EDGE)
            else:
                d = dist.get((x, y), 99)
                put(x, y, NOX_WING[0] if d <= 1 else NOX_WING[1] if d <= 4 else NOX_WING[2])
        elif k == "M":
            put(x, y, NOX_FACE)
        elif k == "D":
            put(x, y, NOX_FUR_TOP if (x, y - 1) not in kind else NOX_FUR)
    for y in range(CELL_H):
        for x in range(CELL_W):
            if (x, y) not in kind and any((x + dx, y + dy) in kind for dx, dy in N8):
                put(x, y, NOX_OUTLINE)


def build_sheet(nox_colors: bool = True) -> None:
    src = Image.open(SRC_PATH).convert("RGBA")
    assert src.size == (SRC_CELL * FRAMES, SRC_CELL * 4), src.size
    print(f"kafa dikeni temizligi: {fix_head_spike(src)} piksel")
    out = Image.new("RGBA", (CELL_W * FRAMES, CELL_H * len(DIR_ROWS)), (0, 0, 0, 0))
    for d, row in DIR_ROWS:
        sr = SRC_ROW[d]
        for c in range(FRAMES):
            cell = src.crop((c * SRC_CELL, sr * SRC_CELL, (c + 1) * SRC_CELL, (sr + 1) * SRC_CELL))
            out.alpha_composite(cell, (c * CELL_W + OFF_X, row * CELL_H + OFF_Y))
            if nox_colors:
                paint_nox_cell(out, c * CELL_W, row * CELL_H)
    out.save(OUT_PATH)
    print(f"yazildi: {OUT_PATH} {out.size} ({'Nox renkleri' if nox_colors else 'orijinal renkler'})")


def patch_tres() -> None:
    with open(TRES_PATH, encoding="utf-8") as f:
        text = f.read()
    m = re.search(r'\[ext_resource type="Texture2D" path="res://assets/characters/vampir/bat_sheet.png" id="([^"]+)"\]', text)
    assert m, "bat_sheet ext_resource yok"
    ext_id = m.group(1)
    ## Eski bat AtlasTexture bloklarini sil.
    block_re = re.compile(r'\[sub_resource type="AtlasTexture" id="AtlasTexture_bat_[a-z]+_\d+"\]\natlas = [^\n]*\nregion = [^\n]*\n\n?')
    old_count = len(block_re.findall(text))
    text = block_re.sub("", text)
    subs = []
    anims = {}
    for d, row in DIR_ROWS:
        refs = []
        for i in range(FRAMES):
            sid = f"AtlasTexture_bat_{d}_{i + 1}"
            subs.append(
                f'[sub_resource type="AtlasTexture" id="{sid}"]\n'
                f'atlas = ExtResource("{ext_id}")\n'
                f"region = Rect2({i * CELL_W}, {row * CELL_H}, {CELL_W}, {CELL_H})\n"
            )
            refs.append(f'{{"duration": 1.0,"texture": SubResource("{sid}")}}')
        anims[d] = f'{{"frames": [{", ".join(refs)}],"loop": true,"name": &"bat_{d}","speed": {FPS}}}'
    ## Yeni bloklari [resource]'tan hemen once ekle.
    idx = text.index("[resource]")
    text = text[:idx] + "\n".join(subs) + "\n" + text[idx:]
    for d, _row in DIR_ROWS:
        clip_re = re.compile(r'\{"frames": \[[^\]]*\],"loop": (?:true|false),"name": &"bat_' + d + r'","speed": [0-9.]+\}')
        assert len(clip_re.findall(text)) == 1, f"bat_{d} klibi bulunamadi"
        text = clip_re.sub(lambda _m, s=anims[d]: s, text)
    n_ext = len(re.findall(r"^\[ext_resource ", text, re.M))
    n_sub = len(re.findall(r"^\[sub_resource ", text, re.M))
    text = re.sub(r"load_steps=\d+", f"load_steps={n_ext + n_sub + 1}", text, count=1)
    with open(TRES_PATH, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print(f"yazildi: {TRES_PATH} (bat karesi {old_count} -> {len(subs)}, load_steps={n_ext + n_sub + 1})")


if __name__ == "__main__":
    build_sheet(nox_colors="--orijinal" not in sys.argv)
    if "--tres" in sys.argv:
        patch_tres()
