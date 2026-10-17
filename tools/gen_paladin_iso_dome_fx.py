"""Sovalye R (Koruma Baloncugu) IZOMETRIK kubbe "C - Isik Perdesi" + Sovalye'nin havada parlayan "bariyer_" klibi.

Kullanici secimi (2026-10-14): prototip C (tools/proto_20261014/sovalye_izo_kubbe_proto.py, madde 159), PROTOTIPTEKI boyutta
("aynı alan" ile 178 px genisligi "cok buyuk" bulundu): koruma alani ELIPS yatay r = 126 (player.gd PALADIN_ULTI_ZONE_RADIUS), dikey 63
(scripts/paladin_dome.gd). Gorsel: yaricapi 126 olan yarim kure, 2:1 izometrik (zemin elipsi = koruma alani).

Cikti (1 sanat pikseli = 1 dunya px, merkez = Sovalye'nin ayak noktasi):
  assets/fx/paladin_dome/iso_floor.png               zemin ayak izi (statik, karakterlerin ALTINDA)
  assets/fx/paladin_dome/iso_back_sheet.png/.tres     arka kabuk dongusu (karakterlerin ALTINDA)
  assets/fx/paladin_dome/iso_front_sheet.png/.tres    on kabuk dongusu (karakterlerin USTUNDE)
  assets/fx/paladin_dome/iso_flash_sheet.png/.tres    isabette on kabugun ustune binen tek seferlik parlama
  assets/characters/sovalye/sheets/bariyer.png        shrug 3. karesi (kollar acik), mavi parlayan govde + gozler, 6 kare nabiz
  assets/characters/sovalye_frames.tres               bariyer_<yon> klipleri eklenir (yoksa)
Sayfalar 4 sutunlu IZGARA (tek satir 16 kare Android doku sinirini asardi).
"""
import math
import os
import re

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "assets", "fx", "paladin_dome")
RES = "res://assets/fx/paladin_dome/"

ZONE_R = 126.0
RV = ZONE_R  # kure yaricapi = koruma elipsinin yatay yaricapi
K = 0.5
SIN, COS = K, math.sqrt(1.0 - K * K)
FW = 2 * math.ceil(RV) + 4  # 256
OX = FW // 2  # 128
OY = math.ceil(RV) + 2  # 128 (merkezin ustundeki satir sayisi; kurenin silueti tepeden degil R kadar yukari cikar)
FH = OY + math.ceil(RV * K) + 5  # 196
BACK_H = OY + 1  # arka kabuk sadece merkez satirinin ustunde
FLOOR_HALF = math.ceil(RV * K) + 5
FRAMES = 16
FPS = 8
COLS = 4

rng = np.random.default_rng(11)
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 + 1.0 / 32.0
yy, xx = np.mgrid[0:FH, 0:FW]
THR = BAYER[yy % 4, xx % 4]
THR2 = BAYER[(yy + 2) % 4, (xx + 1) % 4]
SX = xx + 0.5 - OX
SY = yy + 0.5 - OY
D2 = SX * SX + SY * SY
INSIDE = D2 < RV * RV
T = np.sqrt(np.clip(RV * RV - D2, 0.0, None))
FY = -SY * COS + T * SIN
FZ = SY * SIN + T * COS
FRONT = INSIDE & (FY >= 0)
BY = -SY * COS - T * SIN
BZ = SY * SIN - T * COS
BACK = INSIDE & (BY >= 0)
NF = np.stack([SX, FY, FZ], -1) / RV
NB = np.stack([SX, BY, BZ], -1) / RV
RIM = 1.0 - T / RV
GE = np.sqrt(SX * SX + (SY / K) ** 2) - RV
FLOOR_IN = GE < 0
SANG = np.degrees(np.arctan2(SY, SX))

ALPHA_LEVELS = np.array([0.0, 0.3, 0.55, 0.8, 1.0])
PAL = [(36, 96, 160), (60, 132, 200), (100, 180, 240), (160, 220, 255), (220, 245, 255), (255, 255, 255)]


def dither_alpha(a):
    a = np.clip(a, 0.0, 1.0)
    i = np.clip(np.searchsorted(ALPHA_LEVELS, a, side="right") - 1, 0, len(ALPHA_LEVELS) - 2)
    lo, hi = ALPHA_LEVELS[i], ALPHA_LEVELS[i + 1]
    return np.where((a - lo) / (hi - lo) > THR, hi, lo)


def shade(b):
    n = len(PAL)
    x = np.clip(b, 0.0, 1.0) * (n - 1)
    lo = np.floor(x).astype(int)
    idx = np.clip(np.where(x - lo > THR2, lo + 1, lo), 0, n - 1)
    return np.array(PAL, dtype=np.float32)[idx]


def to_img(b, a, mask):
    arr = np.zeros((FH, FW, 4), np.uint8)
    arr[..., :3] = shade(b).astype(np.uint8)
    arr[..., 3] = (dither_alpha(np.where(mask, a, 0.0)) * 255).astype(np.uint8)
    return Image.fromarray(arr, "RGBA")


def outline(mask):
    e = np.zeros(mask.shape, bool)
    m = mask
    e[1:-1, 1:-1] = m[1:-1, 1:-1] & ~(m[:-2, 1:-1] & m[2:, 1:-1] & m[1:-1, :-2] & m[1:-1, 2:])
    return e


def angles(nvec):
    return np.arctan2(nvec[..., 2], nvec[..., 0]), np.arcsin(np.clip(nvec[..., 1], -1.0, 1.0))


DN = np.sqrt(D2) / RV
CRES = FRONT & (DN > 0.865) & (DN < 0.9) & (SANG > -152) & (SANG < -122)
CRES |= FRONT & (np.abs(DN - 0.8) < 0.016) & (np.abs(SANG + 128) < 1.6)
FOOT_F = FRONT & (FY < 3.0)
N_STREAK = 16
STREAK_AZ = rng.random(N_STREAK) * 2 * math.pi
STREAK_PH = rng.random(N_STREAK)
AZ_F, EL_F = angles(NF)
AZ_B, EL_B = angles(NB)


def streaks(az, el, t):
    s = np.zeros((FH, FW))
    width = 1.1 / (RV * np.maximum(np.cos(el), 0.15))
    for k in range(N_STREAK):
        daz = np.abs(((az - STREAK_AZ[k] + math.pi) % (2 * math.pi)) - math.pi)
        p = ((t + STREAK_PH[k]) % 1.0) * 1.7 - 0.2
        env = np.exp(-(((el - p) / 0.28) ** 2)) * np.clip(1.0 - el / 1.35, 0, 1)
        s = np.maximum(s, (daz < width) * env)
    return s


def shell(az, el, t, back):
    a = 0.04 + 0.62 * RIM ** 2.6
    b = 0.25 + 0.6 * RIM
    st = streaks(az, el, t)
    a = a + st * 0.55
    b = b + st * 0.5
    if back:
        return b * 0.85, a * 0.45
    a = np.where(FOOT_F, 0.85, a)
    b = np.where(FOOT_F, 0.8, b)
    a = np.where(CRES, 0.7, a)
    b = np.where(CRES, 1.0, b)
    return b, a


def floor_img():
    line = outline(FLOOR_IN)
    a = np.zeros((FH, FW))
    b = np.zeros((FH, FW))
    inner = FLOOR_IN & (GE > -10)
    a = np.where(inner, 0.45 * np.exp(GE / 4.0), a)
    b = np.where(inner, 0.55, b)
    a = np.where(FLOOR_IN & (GE <= -10), 0.07, a)
    b = np.where(FLOOR_IN & (GE <= -10), 0.45, b)
    halo = (~FLOOR_IN) & (GE < 5)
    a = np.where(halo, 0.3 * np.exp(-GE / 2.0), a)
    b = np.where(halo, 0.6, b)
    a = np.where(line, 0.95, a)
    b = np.where(line, 0.85, b)
    img = to_img(b * 0.85, a * 0.85, np.ones((FH, FW), bool))
    return img.crop((0, OY - FLOOR_HALF, FW, OY + FLOOR_HALF))


def flash_img(k):
    """Isabet parlamasi (k 1 -> 0): kenar isigi + taban cizgisi aydinlanir. Dongunun USTUNE biner."""
    a = (0.1 + 0.75 * RIM ** 2.0) * k
    b = 0.55 + 0.45 * RIM
    a = np.where(FOOT_F, 0.9 * k, a)
    b = np.where(FOOT_F, 1.0, b)
    return to_img(b, a, FRONT)


def save_grid(name, frames, cell_w, cell_h, anim, loop, fps, origin):
    rows = (len(frames) + COLS - 1) // COLS
    cols = min(COLS, len(frames))
    sheet = Image.new("RGBA", (cell_w * cols, cell_h * rows), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, ((i % COLS) * cell_w, (i // COLS) * cell_h))
    sheet.save(os.path.join(OUT, name + "_sheet.png"), optimize=True)
    lines = ['[gd_resource type="SpriteFrames" format=3]', "",
             '[ext_resource type="Texture2D" path="%s%s_sheet.png" id="1"]' % (RES, name), ""]
    for i in range(len(frames)):
        lines += ['[sub_resource type="AtlasTexture" id="AT_%d"]' % i, 'atlas = ExtResource("1")',
                  "region = Rect2(%d, %d, %d, %d)" % ((i % COLS) * cell_w, (i // COLS) * cell_h, cell_w, cell_h), ""]
    entries = ",\n".join('{\n"duration": 1.0,\n"texture": SubResource("AT_%d")\n}' % i for i in range(len(frames)))
    lines += ["[resource]", 'animations = [{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}]' % (
        entries, "true" if loop else "false", anim, float(fps)), ""]
    with open(os.path.join(OUT, name + "_frames.tres"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines))
    print(name, sheet.size, "origin", origin)


# ------------------------------------------------------------------ Sovalye: havada, kollar acik, mavi parlayan
CHAR_DIR = os.path.join(ROOT, "assets", "characters", "sovalye", "sheets")
CHAR_TRES = os.path.join(ROOT, "assets", "characters", "sovalye_frames.tres")
POSE_COL = 2  # shrug klibinin kollarin en acik oldugu karesi
DIRS = ["down", "left", "right", "up"]
EYE_COLORS = {(0xFF, 0xF0, 0xF7), (0x14, 0x4C, 0x8B), (0x1C, 0x66, 0x9C)}
GLOW_TINT = [0.52, 0.6, 0.68, 0.74, 0.68, 0.6]
GLOW_RIM = [0.45, 0.65, 0.85, 1.0, 0.85, 0.65]
BODY_RAMP = [(20, 40, 96), (38, 84, 170), (70, 140, 230), (130, 200, 255), (210, 240, 255)]


def ramp(lum):
    x = min(max(lum, 0.0), 1.0) * (len(BODY_RAMP) - 1)
    i = min(int(x), len(BODY_RAMP) - 2)
    f = x - i
    a, b = BODY_RAMP[i], BODY_RAMP[i + 1]
    return tuple(a[c] + (b[c] - a[c]) * f for c in range(3))


def glow_frame(src, row, k):
    tint, rim_a = GLOW_TINT[k], GLOW_RIM[k]
    out = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    sp, op = src.load(), out.load()
    solid = [[sp[x, y][3] > 0 for x in range(48)] for y in range(48)]
    # 1 px dis isik (kenar) + seyrek 2. halka (dama deseni, sadece nabiz tepesinde)
    for y in range(48):
        for x in range(48):
            if solid[y][x]:
                continue
            n1 = any(0 <= x + dx < 48 and 0 <= y + dy < 48 and solid[y + dy][x + dx]
                     for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if n1:
                op[x, y] = (120, 210, 255, int(255 * 0.8 * rim_a))
                continue
            if rim_a >= 0.85 and (x + y) % 2 == 0:
                n2 = any(0 <= x + dx < 48 and 0 <= y + dy < 48 and solid[y + dy][x + dx]
                         for dx, dy in ((2, 0), (-2, 0), (0, 2), (0, -2), (1, 1), (-1, 1), (1, -1), (-1, -1)))
                if n2:
                    op[x, y] = (90, 170, 255, int(255 * 0.35))
    for y in range(48):
        for x in range(48):
            r, g, b, a = sp[x, y]
            if a == 0:
                continue
            if row != 3 and 14 <= y <= 18 and (r, g, b) in EYE_COLORS:
                # parlayan goz: beyaz -> buz beyazi, iris -> parlak camgobegi
                op[x, y] = (235, 252, 255, 255) if (r, g, b) == (0xFF, 0xF0, 0xF7) else (110, 225, 255, 255)
                continue
            lum = (0.3 * r + 0.55 * g + 0.15 * b) / 255.0
            tr = ramp(lum * 1.15 + 0.05)
            op[x, y] = tuple(int(round(c0 + (c1 - c0) * tint)) for c0, c1 in zip((r, g, b), tr)) + (a,)
    if row != 3 and rim_a >= 0.85:
        # nabiz tepesinde goz isigi yanlara tasar (gozun hemen dis yanindaki 1 piksel)
        eyes = [(x, y) for y in range(14, 19) for x in range(48) if sp[x, y][3] and sp[x, y][:3] in EYE_COLORS]
        if eyes:
            ys = sorted({y for _, y in eyes})
            y0 = ys[0]
            xs = [x for x, y in eyes if y == y0]
            for x in (min(xs) - 1, max(xs) + 1):
                if 0 <= x < 48 and sp[x, y0][3]:
                    op[x, y0] = (170, 235, 255, 255)
    return out


def build_char():
    shrug = Image.open(os.path.join(CHAR_DIR, "shrug.png")).convert("RGBA")
    n = len(GLOW_TINT)
    sheet = Image.new("RGBA", (48 * n, 48 * 4), (0, 0, 0, 0))
    for row in range(4):
        src = shrug.crop((POSE_COL * 48, row * 48, POSE_COL * 48 + 48, row * 48 + 48))
        for k in range(n):
            sheet.paste(glow_frame(src, row, k), (k * 48, row * 48))
    sheet.save(os.path.join(CHAR_DIR, "bariyer.png"), optimize=True)
    with open(CHAR_TRES, encoding="utf-8") as fh:
        txt = fh.read()
    if '&"bariyer_down"' in txt:
        print("sovalye_frames.tres: bariyer_ klipleri zaten var (sadece png yenilendi)")
        return
    txt = txt.replace('[ext_resource type="Texture2D" path="res://assets/characters/sovalye/sheets/sit.png" id="sit_sheet"]',
                      '[ext_resource type="Texture2D" path="res://assets/characters/sovalye/sheets/sit.png" id="sit_sheet"]\n'
                      '[ext_resource type="Texture2D" path="res://assets/characters/sovalye/sheets/bariyer.png" id="bariyer_sheet"]', 1)
    subs = []
    anims = []
    for row, d in enumerate(DIRS):
        ids = []
        for k in range(n):
            sid = "AtlasTexture_bariyer_%s_%d" % (d, k)
            subs.append('[sub_resource type="AtlasTexture" id="%s"]\natlas = ExtResource("bariyer_sheet")\n'
                        "region = Rect2(%d, %d, 48, 48)\n" % (sid, k * 48, row * 48))
            ids.append(sid)
        frames = ", ".join('{"duration": 1.0,"texture": SubResource("%s")}' % s for s in ids)
        anims.append('{"frames": [%s],"loop": true,"name": &"bariyer_%s","speed": 8.0}' % (frames, d))
    txt = txt.replace("[resource]", "\n".join(subs) + "\n[resource]", 1)
    idx = txt.rindex("]")  # animations dizisinin kapanisi (dosyanin son ']' karakteri)
    txt = txt[:idx] + ", " + ", ".join(anims) + txt[idx:]
    m = re.search(r"load_steps=(\d+)", txt)
    if m:
        txt = txt.replace(m.group(0), "load_steps=%d" % (int(m.group(1)) + 1 + 4 * n), 1)
    with open(CHAR_TRES, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(txt)
    print("sovalye_frames.tres: bariyer_<yon> eklendi")


def main():
    os.makedirs(OUT, exist_ok=True)
    floor_img().save(os.path.join(OUT, "iso_floor.png"), optimize=True)
    print("iso_floor", (FW, 2 * FLOOR_HALF), "origin", (OX, FLOOR_HALF))
    back, front = [], []
    for f in range(FRAMES):
        t = f / FRAMES
        bb, ba = shell(AZ_B, EL_B, t, True)
        fb, fa = shell(AZ_F, EL_F, t, False)
        back.append(to_img(bb, ba, BACK).crop((0, 0, FW, BACK_H)))
        front.append(to_img(fb, fa, FRONT))
    save_grid("iso_back", back, FW, BACK_H, "loop", True, FPS, (OX, OY))
    save_grid("iso_front", front, FW, FH, "loop", True, FPS, (OX, OY))
    save_grid("iso_flash", [flash_img(k) for k in (1.0, 0.8, 0.6, 0.4, 0.22, 0.1)], FW, FH, "flash", False, 20, (OX, OY))
    build_char()


if __name__ == "__main__":
    main()
