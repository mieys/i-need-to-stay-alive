# YÜKLEME EKRANI yeniden tasarım PROTOTİPLERİ (madde 366, 2026-10-23; oyuna bağlı DEĞİL).
# Kullanıcı: "yükleme ekranını yeniden tasarla yeni haritadan esinlenerek 2 prototip hazırla. veya hiçbirşeyden esinlenmeden ai kullanmadan
# 2 prototip hazırla. ikisi dahil toplam 4 prototip istiyorum".
#   A "Mühürlü Kapı"  - derin orman Kuzey, Kemik Mahzeni gecesi: kahraman + ölü yaratıklar barın ucunda kapıya koşar, kapının yeşil halesi
#                       ilerlemeyle büyür, varışta alev parlar ve sahne kararır. Arka plan = GERÇEK çizici çekimi (yukleme_capture.gd).
#   B "Dört Bölge"     - dört dikey pano (Batı / Kuzey / Doğu / Güney, gerçek çizici), hepsi sisli; kahraman alttaki barda koşarken geçtiği
#                       yerin sisi yırtık bir kenarla açılır, panonun adı ("? ? ?" -> bölge adı) ve ipucu satırı o bölgenin sezdirmesi olur.
#   C "Şafağa Kadar"   - ÖZGÜN, hiçbir hazır sanat yok: her piksel bu dosyada (ASCII çizimler + el seçimi palet). Gece -> şafak: gökyüzü
#                       bantları paleti kaydırır, yıldızlar söner, güneş dağ çentiğinden doğar, kamp ateşi kora döner.
#   D "Son Mum"        - ÖZGÜN, hiçbir hazır sanat yok. Karanlıkta tek mum: ilerledikçe sert kenarlı ışık halkaları büyür, tahta zemin ve
#                       eşyalar görünür, karanlıktaki gözler geri çekilir; varışta mum söner, duman, karanlık.
# Kurallar: tuval 640x360 (oyunda x3 = 1920x1080, kahraman/yaratıklar aynı ızgara, loading_screen.gd ile aynı ölçekler); A/B'nin ışığı
# yumuşak (madde 326: Bayer basamağı "pixel pixel"), C/D düz renk + sert kenar, dither/gürültü YOK ("çok ai" dersi, madde 241).
# Çalıştır: önce yukleme_run.ps1 (A/B çekimleri out/raw), sonra
#   python tools/proto_20261023/yukleme/yukleme_proto.py [a b c d]
# Çıktı out/: <x>_<ad>.png (1920x1080, ~%55), <x>_<ad>.gif (960x540, 0 -> %100 + varış), karsilastirma.png
import math
import os
import re
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(HERE, "out")
RAW = os.path.join(OUT, "raw")
CW, CH, K = 640, 360, 3
SW, SH = CW * K, CH * K
CX, CY = SW // 2, SH // 2
FONT_PATH = os.path.join(ROOT, "assets", "fonts", "m5x7.ttf")
C_CREAM = (255, 240, 214)
C_OUTLINE = (58, 34, 18)
TIP_COL = (232, 212, 176)
PROG_FRAMES = 48            # 0 -> %100
ARRIVE_FRAMES = 10          # varış (kahraman kapıya / güneş doğar / mum söner)
HOLD_FRAMES = 5             # "OYUN BAŞLIYOR" karanlığı
GIF_MS = 100


def res(p):
    return os.path.join(ROOT, p.replace("res://", "").replace("/", os.sep))


def font(size):
    return ImageFont.truetype(FONT_PATH, size)


def hsh(*v):
    """Tam sayı hash -> 0..1 (madde 362 dersi: sin-hash yok)."""
    h = 2166136261
    for x in v:
        h = ((h ^ (int(x) & 0xffffffff)) * 16777619) & 0xffffffff
        h ^= h >> 13
        h = (h * 1274126177) & 0xffffffff
    return (h & 0xffffff) / float(0xffffff)


# ------------------------------------------------------------------ gerçek sprite'lar (loading_screen.gd ile aynı kaynak/ölçek)
def tres_anim(path, anim):
    t = open(res(path), encoding="utf-8").read()
    ext = {m.group(2): m.group(1) for m in re.finditer(r'\[ext_resource[^\]]*path="([^"]+)"[^\]]*id="([^"]+)"', t)}
    subs = {}
    for m in re.finditer(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\s*atlas = ExtResource\("([^"]+)"\)\s*region = Rect2\(([^)]*)\)', t):
        subs[m.group(1)] = (ext[m.group(2)], [int(float(v)) for v in m.group(3).split(",")])
    for m in re.finditer(r'\{"frames": \[(.*?)\],"loop": \w+,"name": &"(\w+)","speed": ([\d.]+)\}', t, re.S):
        if m.group(2) != anim:
            continue
        frames = []
        sheets = {}
        for sid in re.findall(r'SubResource\("([^"]+)"\)', m.group(1)):
            p, (x, y, w, h) = subs[sid]
            if p not in sheets:
                sheets[p] = Image.open(res(p)).convert("RGBA")
            frames.append(sheets[p].crop((x, y, x + w, y + h)))
        return frames, float(m.group(3))
    raise KeyError(anim)


def creature(cid):
    t = open(res("res://scenes/creatures/enemy_%s.tscn" % cid), encoding="utf-8").read()
    ext = {m.group(2): m.group(1) for m in re.finditer(r'\[ext_resource[^\]]*path="([^"]+)"[^\]]*id="([^"]+)"', t)}
    walk = ext[re.search(r'walk_texture = ExtResource\("([^"]+)"\)', t).group(1)]
    cell = int(re.search(r"cell_size = (\d+)", t).group(1))
    fps = float(re.search(r"sprite_fps = ([\d.]+)", t).group(1))
    spr = t[t.index('[node name="Sprite2D"'):]
    s = float(re.search(r"scale = Vector2\(([\d.]+)", spr).group(1))
    sheet = Image.open(res(walk)).convert("RGBA")
    n = sheet.width // cell
    frames = [sheet.crop((i * cell, 3 * cell, (i + 1) * cell, 4 * cell)) for i in range(n)]   # satır 3 = sağa
    return frames, fps, s * 3.6


def foot_off(img):
    bb = img.getbbox()
    return (bb[3] if bb else img.height) - img.height * 0.5


def scaled(img, s):
    return img.resize((max(1, round(img.width * s)), max(1, round(img.height * s))), Image.NEAREST)


def tint(img, c):
    a = np.asarray(img).astype(np.float32)
    a[..., :3] *= np.array(c, np.float32)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


class Chase:
    """Kahraman barın ucunda, yaratıklar arkasında (loading_screen.gd _layout_chase / _animate_chasers)."""
    HERO_SCALE = 3.0
    GAP, START_GAP, FOOT_SINK, INSET = 130.0, 170.0, 4.0, 6.0
    MOON = (0.9, 0.92, 1.0)

    def __init__(self, path_rect, chasers, moon=MOON):
        self.pr = path_rect
        fr, self.hero_fps = tres_anim("res://assets/characters/talha_frames.tres", "run_right")
        self.hero = [tint(scaled(f, self.HERO_SCALE), moon) for f in fr]
        self.hero_foot = foot_off(fr[0]) * self.HERO_SCALE
        self.ch = []
        for i, cid in enumerate(chasers):
            frames, fps, s = creature(cid)
            self.ch.append(([tint(scaled(f, s), moon) for f in frames], fps, foot_off(frames[0]) * s, hsh(i, 7) * 10.0))

    def hero_x(self, ratio):
        x, y, w, h = self.pr
        return x + self.INSET + (w - self.INSET * 2) * ratio

    def draw(self, im, ratio, t, hero_x=None, chasers_run=True, hero_alpha=1.0):
        x, y, w, h = self.pr
        ground = y + self.FOOT_SINK
        hx = self.hero_x(ratio) if hero_x is None else hero_x
        for i, (frames, fps, foot, ph) in enumerate(self.ch):
            f = frames[int((t + ph) * fps) % len(frames)] if chasers_run else frames[0]
            px = self.hero_x(ratio) - self.START_GAP - i * self.GAP
            im.alpha_composite(f, (int(round(CX + px - f.width / 2)), int(round(CY + ground - foot - f.height / 2))))
        if hero_alpha > 0:
            f = self.hero[int(t * self.hero_fps) % len(self.hero)]
            if hero_alpha < 1:
                f = f.copy()
                f.putalpha(f.getchannel("A").point(lambda v: int(v * hero_alpha)))
            im.alpha_composite(f, (int(round(CX + hx - f.width / 2)), int(round(CY + ground - self.hero_foot - f.height / 2))))


# ------------------------------------------------------------------ arayüz (oyundaki yazı tipi m5x7 + loading_screen.gd ölçüleri)
def text_c(im, txt, y, size, col, stroke, stroke_col=C_OUTLINE, x=CX):
    d = ImageDraw.Draw(im)
    d.fontmode = "1"
    f = font(size)
    bb = d.textbbox((0, 0), txt, font=f, stroke_width=stroke)
    d.text((x - (bb[2] - bb[0]) / 2 - bb[0], y), txt, font=f, fill=col, stroke_width=stroke, stroke_fill=stroke_col)


def bar(im, rect, ratio, trough, border, fill, fill_border, radius=3, bw=3):
    x, y, w, h = rect
    d = ImageDraw.Draw(im)
    x0, y0 = CX + x, CY + y
    d.rounded_rectangle((x0, y0, x0 + w - 1, y0 + h - 1), radius=radius, fill=trough, outline=border, width=bw)
    fw = (w - 12) * ratio
    if fw >= 8:
        d.rounded_rectangle((x0 + 6, y0 + 6, x0 + 6 + fw - 1, y0 + h - 7), radius=radius, fill=fill, outline=fill_border, width=bw)


def status_text(frame):
    if frame >= PROG_FRAMES:
        return "OYUN BAŞLIYOR"
    return "YÜKLENİYOR" + "." * ((frame // 4) % 4)


def upscale(canvas):
    return Image.fromarray(canvas).resize((SW, SH), Image.NEAREST).convert("RGBA")


def dim(im, k, col=(0.2, 0.2, 0.27)):
    """loading_screen.gd _arrive: sahne + karakterler ARRIVE_DIM'e kararır (k 0..1)."""
    a = np.asarray(im).astype(np.float32)
    m = np.array([1 - (1 - c) * k for c in col], np.float32)
    a[..., :3] *= m
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


YY, XX = np.mgrid[0:CH, 0:CW].astype(np.float32)


def vignette(left_extra=0.5, k=0.6):
    vx = (XX / CW - 0.5) * 2
    vy = (YY / CH - 0.5) * 2
    v = np.clip(vx ** 2 * 0.4 + vy ** 2 * 0.55 - 0.18 + np.clip(-vx - 0.5, 0, None) * left_extra, 0, 1)
    return 1 - k * v


def glow_mask(a):
    mx = a.max(2)
    mn = a.min(2)
    sat = (mx - mn) / np.maximum(mx, 1e-4)
    return (sat > 0.32) & (mx > 0.5) & (a[..., 0] < a[..., 1] * 0.9)


# ================================================================== A - Mühürlü Kapı
A_PATH = (-720.0, 100.0, 1440.0, 40.0)    # loading_screen.gd PATH_RECT (tuval y 213..227)
A_DOOR = (546.0, 192.0)                   # Kemik Mahzeni kapı ağzı (tuval)


def a_grade(raw, p, flare=0.0):
    a = raw.astype(np.float32) / 255.0
    amb = np.array([0.46, 0.52, 0.68], np.float32)
    R = 95.0 + 85.0 * p + 230.0 * flare
    d = np.sqrt((XX - A_DOOR[0]) ** 2 + ((YY - A_DOOR[1]) / 0.75) ** 2) / R
    f = np.clip(1 - d, 0, 1) ** 2
    inten = 0.3 + 0.85 * p + 1.4 * flare
    light = amb + f[..., None] * np.array([0.32, 1.0, 0.6], np.float32) * inten
    light *= vignette()[..., None]
    out = a * light
    g = glow_mask(a)
    out[g] = np.maximum(out[g], a[g] * (0.85 + 0.25 * p))
    return np.clip(out * 255, 0, 255).astype(np.uint8)


def proto_a():
    chase = Chase(A_PATH, ["iskelet1", "zombie1", "iskelet2", "zombie2"])
    raws = [np.asarray(Image.open(os.path.join(RAW, "a_mahzen_%02d.png" % i)).convert("RGB")) for i in range(PROG_FRAMES)]
    door_x = (A_DOOR[0] * K) - CX
    frames = []
    for fi in range(PROG_FRAMES + ARRIVE_FRAMES + HOLD_FRAMES):
        t = fi * GIF_MS / 1000.0
        if fi < PROG_FRAMES:
            p = fi / (PROG_FRAMES - 1.0)
            ratio = min(p, 0.95) if fi < PROG_FRAMES - 1 else 0.97
            im = upscale(a_grade(raws[fi], p))
            bar(im, A_PATH, ratio, (24, 30, 29, 220), (78, 92, 86), (96, 176, 130), (40, 92, 68))
            chase.draw(im, ratio, t)
            k = 0.0
        else:
            j = fi - PROG_FRAMES
            flare = max(0.0, 1.0 - abs(j - 3) / 3.0) if j < ARRIVE_FRAMES else 0.0
            im = upscale(a_grade(raws[40 + j % 8], 1.0, flare))
            bar(im, A_PATH, 0.97, (24, 30, 29, 220), (78, 92, 86), (96, 176, 130), (40, 92, 68))
            run = min(1.0, j / 3.5)
            hx = chase.hero_x(0.97) + (door_x - chase.hero_x(0.97)) * run
            chase.draw(im, 0.97, t, hero_x=hx, chasers_run=j < 3, hero_alpha=max(0.0, 1.0 - max(0, j - 3) / 2.0))
            k = min(1.0, max(0, j - 3) / 4.0)
        text_c(im, "KEMİK MAHZENİ", 48, 64, (176, 232, 196), 6, (12, 26, 20))
        text_c(im, "Mühür kırılmamış. Kapının ardından kemik sesleri geliyor...", 120, 32, (196, 210, 200), 4, (12, 26, 20))
        im = dim(im, k)
        text_c(im, status_text(fi), CY + 140 + 20, 48, C_CREAM, 5)
        text_c(im, "İpucu: Bir kademenin boss'u yaşadıkça yeni kademe başlamaz.", CY + 140 + 80, 32, TIP_COL, 4)
        frames.append(im)
    return frames


# ================================================================== B - Dört Bölge
B_ORDER = [("b_bati", "KIZIL BATAKLIK", (232, 140, 112), "Toprak nefes alıyor. Bir şey seni izliyor..."),
           ("b_kuzey", "KADİM KARA ORMAN", (150, 214, 172), "Burada ağaçlar ölü doğar; ruhlar yolunu kaybetmiş."),
           ("b_dogu", "IŞIYAN KAYALIKLAR", (160, 214, 236), "Kristaller unutulmuş bir şarkıyı mırıldanıyor."),
           ("b_guney", "SİSLİ SAZLIK", (196, 214, 128), "Yaşlı ağaç uyumuyor. Sadece bekliyor.")]
B_PATH = (-912.0, 306.0, 1824.0, 42.0)   # tuval y 282..296, x 16..624 (dört panonun altında)
B_PANEL = 160


def proto_b():
    chase = Chase(B_PATH, ["slime1", "slime2", "iskelet1", "zombie1", "slime3"])
    raws = [[np.asarray(Image.open(os.path.join(RAW, "%s_%02d.png" % (n, i))).convert("RGB"))[:, 240:400] for i in range(12)]
            for n, _, _, _ in B_ORDER]
    jag = np.array([int(hsh(r // 3, 31) * 7) - 3 for r in range(CH)], np.float32)   # yırtık sis kenarı (3 satırlık basamak)
    low = np.clip((YY - 262) / 40.0, 0, 1) * 0.55                                    # yazı bandı biraz koyu
    frames = []
    for fi in range(PROG_FRAMES + ARRIVE_FRAMES + HOLD_FRAMES):
        t = fi * GIF_MS / 1000.0
        if fi < PROG_FRAMES:
            p = fi / (PROG_FRAMES - 1.0)
            ratio = min(p, 0.95) if fi < PROG_FRAMES - 1 else 0.97
        else:
            ratio = 1.0
        hx_c = (CX + chase.hero_x(ratio)) / K                    # kahramanın tuval x'i
        canvas = np.concatenate([raws[i][fi % 12] for i in range(4)], axis=1).astype(np.float32) / 255.0
        lum = canvas[..., 0] * 0.3 + canvas[..., 1] * 0.59 + canvas[..., 2] * 0.11
        fog = lum[..., None] * np.array([0.40, 0.44, 0.60], np.float32) * 0.62
        lit = canvas * np.array([0.8, 0.82, 0.92], np.float32)
        g = glow_mask(canvas)
        lit[g] = canvas[g]
        pi = min(3, int(hx_c // B_PANEL))
        start = pi * B_PANEL
        edge = 9999.0 if fi >= PROG_FRAMES else min(start + B_PANEL + 8, start + (hx_c - start) * 3.0)
        open_ = (XX < start) | (XX < edge + jag[:, None])
        out = np.where(open_[..., None], lit, fog)
        out *= (vignette(0.0, 0.45) * (1 - low))[..., None]
        for sx in (B_PANEL, 2 * B_PANEL, 3 * B_PANEL):           # pano araları: 2 px koyu kesik
            out[:, sx - 1:sx + 1] = np.array([0.05, 0.045, 0.06])
        im = upscale(np.clip(out * 255, 0, 255).astype(np.uint8))
        bar(im, B_PATH, ratio, (22, 18, 16, 225), (88, 70, 54), (136, 162, 79), (79, 101, 45))
        k = 0.0
        if fi >= PROG_FRAMES:
            j = fi - PROG_FRAMES
            k = min(1.0, j / 5.0)
        chase.draw(im, ratio, t, chasers_run=fi < PROG_FRAMES + 3)
        im = dim(im, k)
        cur = min(3, int(hx_c // B_PANEL))
        for i, (_, name, col, _) in enumerate(B_ORDER):
            px = i * B_PANEL * K + B_PANEL * K // 2
            seen = hx_c > i * B_PANEL + 20
            if seen:
                text_c(im, name, 36, 48, col, 5, (16, 12, 10), x=px)
            else:
                text_c(im, "? ? ?", 36, 48, (98, 102, 120), 5, (16, 12, 10), x=px)
        _, _, zcol, lore = B_ORDER[cur]
        text_c(im, status_text(fi), CY + 306 + 42 + 8, 48, C_CREAM, 5)
        text_c(im, lore, CY + 306 + 42 + 70, 32, tuple(int(c * 0.5 + 0.5 * t2) for c, t2 in zip(zcol, TIP_COL)), 4)
        frames.append(im)
    return frames


# ================================================================== C - Şafağa Kadar (özgün, kod çizimi)
SKY = [(11, 13, 31), (18, 22, 58), (29, 31, 79), (44, 42, 99), (69, 48, 111), (102, 56, 111), (140, 68, 104),
       (180, 85, 94), (216, 115, 90), (239, 154, 92), (246, 194, 114), (251, 226, 160)]
SKY_BANDS = [0, 30, 56, 78, 97, 113, 127, 139, 150, 160, 169, 177, 184, 190, 196, 201, 206, 211, 216, 240]
# katman renkleri 5 durum (gece -> şafak); palet kaydırma gibi basamakla değişir
C_FAR = [(24, 26, 56), (33, 31, 66), (52, 40, 80), (82, 56, 92), (116, 76, 100)]
C_MIST = [(40, 42, 78), (56, 50, 92), (90, 70, 108), (140, 100, 120), (196, 150, 140)]
C_MID = [(14, 15, 36), (20, 19, 44), (30, 25, 52), (46, 34, 60), (62, 44, 66)]
C_NEAR = [(7, 7, 16), (9, 8, 19), (13, 10, 23), (18, 13, 27), (24, 17, 31)]
C_RIM = [None, None, (150, 86, 92), (214, 124, 98), (246, 172, 112)]
SUN = (255, 236, 176)
SUN_RING = [(250, 208, 128), (243, 172, 104)]
FIRE = {"w": (255, 246, 208), "y": (255, 208, 96), "o": (255, 138, 42), "r": (200, 74, 32), "e": (140, 46, 30)}
FIRE_FR = [["...r...", "..ror..", "..oyo..", ".royor.", ".oywyo.", "royywyr", ".eoyoe.", "ee.e.ee"],
           ["..r....", "..or.r.", ".roy.o.", ".oyyor.", "royww o", ".oyyyo.", ".eoyoe.", "ee.e.ee"],
           ["....r..", ".r.ro..", ".oroy..", ".oyyo r", ".oywyo.", "royyyor", ".eoyoe.", "ee.e.ee"]]
EMBER_FR = [[".......", ".......", ".......", ".......", "...r...", "..ror..", ".eoyoe.", "ee.e.ee"],
            [".......", ".......", ".......", ".......", "..r....", "..oor..", ".eoyoe.", "ee.e.ee"]]
FIGURE = [".....###.....", "....#####....", "...######....", "...#######...", "...######....", "....####.....",
          "...######....", "..########...", "..#########..", ".##########..", ".##########..", ".###########.",
          "############.", "############.", ".##########..", ".##########..", "..#########..", "..########...",
          "..###..###...", "..##....##...", "..##....##...", "..##....##...", ".###....###.."]
SWORD_UP = ["..#..", ".###.", "..#..", "#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."]


def line(cv, x0, y0, x1, y1, col, th=1):
    """Tam sayı (Bresenham) çizgi, th kalınlık."""
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        for o in range(th):
            for (ax, ay) in (((x0 + o, y0), (x0, y0 + o)) if th > 1 else ((x0, y0),)):
                if 0 <= ax < CW and 0 <= ay < CH:
                    cv[ay, ax] = col
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def bare_tree(cv, x, y, col, seed=0):
    """Rüzgâra eğik çıplak ağaç: 3 px gövde, sabit açılı dallar (hash), dallar inceldikçe kısalır."""
    def branch(x0, y0, ang, ln, depth, i):
        x1 = int(round(x0 + math.cos(ang) * ln))
        y1 = int(round(y0 - math.sin(ang) * ln))
        line(cv, x0, y0, x1, y1, col, 2 if depth >= 3 else 1)
        if depth == 0:
            return
        for k, sgn in enumerate((-1, 1)):
            a = ang + sgn * (0.35 + hsh(seed, i, k) * 0.35) + 0.12
            branch(x1, y1, a, ln * (0.62 + hsh(seed, i, k, 9) * 0.18), depth - 1, i * 2 + k + 1)
    line(cv, x, y, x + 2, y - 26, col, 3)
    branch(x + 2, y - 26, math.pi / 2 - 0.1, 14, 4, 1)


def bump(x, c, w):
    return math.exp(-((x - c) / w) ** 2)


def far_ridge(x):
    y = 200 - 34 * bump(x, 110, 80) - 44 * bump(x, 290, 95) - 14 * bump(x, 520, 70) - 30 * bump(x, 610, 60)
    y += 10 * bump(x, 430, 40)                 # güneşin doğduğu çentik
    return int(round(y + int(hsh(x // 5, 3) * 3) - 1))


def mid_ridge(x):
    return int(round(240 - 14 * bump(x, 60, 120) - 9 * bump(x, 360, 140) - 12 * bump(x, 640, 110) + int(hsh(x // 7, 5) * 2)))


def near_ridge(x):
    if x < 40:
        y = 250 + (40 - x) * 0.1
    elif x < 225:
        y = 258 - 3 * bump(x, 120, 30)
    elif x < 320:
        y = 258 + (x - 225) * 0.45
    else:
        y = 300 - 8 * bump(x, 560, 80)
    return int(round(y + (1 if hsh(x // 3, 9) > 0.8 else 0)))


def put(canvas, rows, ox, oy, pal):
    for r, row in enumerate(rows):
        for c, ch in enumerate(row):
            if ch in pal and 0 <= oy + r < CH and 0 <= ox + c < CW:
                canvas[oy + r, ox + c] = pal[ch]


def pine(canvas, x, base, h, col):
    """Kat kat çam silüeti: 3 kat, her kat aşağı genişler; 1 px gövde."""
    tiers = 3
    th = h / tiers
    for i in range(tiers):
        top = base - h + int(i * th * 0.75)
        bot = top + int(th * 1.25)
        for y in range(top, bot):
            half = int((y - top) / (bot - top) * (2 + i * 1.6 + h * 0.12))
            canvas[max(0, y), max(0, x - half):x + half + 1] = col
    canvas[base - 2:base + 1, x] = col


def c_state(p):
    return min(4, int(p * 5))


def c_scene(p, fi, end=0.0):
    s = c_state(p)
    cv = np.zeros((CH, CW, 3), np.uint8)
    # gökyüzü bantları: tepe 0 -> 3, ufuk 2 -> 11 dizinine kayar
    top_i = 0 + p * 3
    hor_i = 2 + p * 9 + end * 1.5
    nb = len(SKY_BANDS) - 1
    for b in range(nb):
        u = (b / (nb - 1)) ** 1.6
        idx = int(round(top_i + (hor_i - top_i) * u))
        cv[SKY_BANDS[b]:SKY_BANDS[b + 1]] = SKY[min(11, idx)]
    # yıldızlar: her birinin sönme eşiği var (parlaklar sona kalır)
    for i in range(90):
        x = int(hsh(i, 1) * CW)
        y = int(hsh(i, 2) ** 1.4 * 165)
        if p > 0.12 + hsh(i, 3) * 0.75:
            continue
        bright = hsh(i, 4) > 0.8
        tw = (fi + int(hsh(i, 5) * 9)) % 9 == 0
        col = (255, 248, 220) if bright and not tw else (150, 156, 200)
        cv[y, x] = col
        if bright and not tw and y > 0:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                cv[y + dy, x + dx] = (110, 110, 160)
    # ay (hilal) - batıya iner, solar
    my = int(58 + p * 46)
    mcol = SKY[max(0, 11 - s * 2)] if s >= 3 else (236, 232, 210)
    for y in range(my - 11, my + 12):
        for x in range(104 - 11, 104 + 12):
            if (x - 104) ** 2 + (y - my) ** 2 <= 121 and (x - 109) ** 2 + (y - my + 3) ** 2 > 90:
                cv[y, x] = mcol
    # güneş + sert halkalar (dağların arkasında)
    sy = int(round(236 - 60 * p - 4 * end))
    for rr, col in ((20 + 14, SUN_RING[1]), (20 + 7, SUN_RING[0]), (20, SUN)):
        if p < 0.3 and col != SUN:
            continue
        for y in range(max(0, sy - rr), min(CH, sy + rr + 1)):
            w = int(math.sqrt(max(0, rr * rr - (y - sy) ** 2)))
            cv[y, 430 - w:430 + w + 1] = col
    # uzak dağlar + kenar ışığı
    for x in range(CW):
        r = far_ridge(x)
        cv[r:, x] = C_FAR[s]
        if C_RIM[s] and abs(x - 430) < 150 + 60 * p:
            cv[r, x] = C_RIM[s]
    # vadi sisi: düz şeritler, yavaş kayar
    for (y, ln, gap, sp) in ((214, 46, 30, 0.6), (220, 70, 22, 0.35), (226, 38, 40, 0.8)):
        off = int(fi * sp)
        for x in range(CW):
            if ((x + off) % (ln + gap)) < ln and far_ridge(x) < y:
                cv[y:y + 2, x] = C_MIST[s]
    # orta tepeler + çamlar
    for x in range(CW):
        r = mid_ridge(x)
        cv[r:, x] = C_MID[s]
        if C_RIM[s] and s >= 3 and abs(x - 430) < 120:
            cv[r, x] = tuple(int(a * 0.6 + b * 0.4) for a, b in zip(C_RIM[s], C_MID[s]))
    x = 6
    while x < CW:
        gap_zone = 380 < x < 480
        if not gap_zone and hsh(x, 11) > 0.35:
            h = 10 + int(hsh(x, 12) * 14)
            pine(cv, x, mid_ridge(x) + 2, h, C_MID[s])
        x += 7 + int(hsh(x, 13) * 9)
    # yakın kayalık + kahraman + kılıç + kamp ateşi
    for x in range(CW):
        r = near_ridge(x)
        cv[r:, x] = C_NEAR[s]
        if hsh(x, 21) > 0.86 and r < 300:
            cv[r - 1 - int(hsh(x, 22) * 2):r, x] = C_NEAR[s]   # ot tutamları
    fx_, fy = 132, near_ridge(132)
    fire_k = max(0.0, 1.0 - p * 1.25)
    if fire_k > 0:                       # ateşin sert kenarlı ışık havuzu (2 bant), şafakla söner
        for (rx, ry, col) in ((34, 10, (52, 26, 22)), (20, 6, (88, 42, 26))):
            for y in range(fy - ry, fy + ry + 1):
                for x in range(fx_ - rx, fx_ + rx + 1):
                    if ((x - fx_) / rx) ** 2 + ((y - fy) / ry) ** 2 <= 1 and y >= near_ridge(x):
                        c0 = cv[y, x].astype(np.float32)
                        cv[y, x] = np.clip(c0 + (np.array(col) - c0) * fire_k, 0, 255).astype(np.uint8)
    bare_tree(cv, 64, near_ridge(64) + 1, C_NEAR[s], 3)
    pal_fig = {"#": (5, 5, 10)}
    figx, figy = 160, near_ridge(166) - len(FIGURE)
    put(cv, FIGURE, figx, figy, pal_fig)
    put(cv, SWORD_UP, 178, near_ridge(180) - len(SWORD_UP) + 3, pal_fig)
    if C_RIM[s]:                         # kahramanın güneşe bakan sağ kenarı
        for r, row in enumerate(FIGURE):
            c = row.rfind("#")
            cv[figy + r, figx + c] = C_RIM[s]
    if fire_k > 0.15 and s < 3:          # ateşe bakan sol kenar
        for r, row in enumerate(FIGURE[4:], 4):
            c = row.find("#")
            cv[figy + r, figx + c] = (120, 52, 30)
    frs = FIRE_FR if p < 0.62 else EMBER_FR
    put(cv, frs[fi % len(frs)], fx_ - 3, fy - 8, FIRE)
    if p >= 0.62:                        # duman
        for i in range(4):
            yy = fy - 10 - ((fi * 2 + i * 7) % 28)
            xx = fx_ + int(math.sin((fi + i * 5) * 0.5) * 2)
            cv[yy, xx] = (70, 66, 80) if s < 4 else (120, 104, 116)
    # kuşlar (sabah)
    if p > 0.62:
        for i in range(3):
            bx = int(640 - ((fi - 30) * 5 + i * 22) % 700)
            by = 120 + i * 9 + (i % 2) * 4
            up = (fi + i) % 2 == 0
            for dx, dy in ((-2, -1 if up else 1), (-1, -1 if up else 0), (0, 0), (1, -1 if up else 0), (2, -1 if up else 1)):
                if 0 <= bx + dx < CW:
                    cv[by + dy, bx + dx] = C_MID[s]
    return cv


C_BAR_Y = 313        # tuval: durum yazısı 290, bar 313..318, ipucu 326


def proto_c():
    frames = []
    for fi in range(PROG_FRAMES + ARRIVE_FRAMES + HOLD_FRAMES):
        if fi < PROG_FRAMES:
            p = fi / (PROG_FRAMES - 1.0)
            ratio = min(p, 0.95) if fi < PROG_FRAMES - 1 else 0.97
            end = 0.0
        else:
            p, ratio = 1.0, 1.0
            end = min(1.0, (fi - PROG_FRAMES) / 4.0)
        im = upscale(c_scene(p, fi, end))
        if fi >= PROG_FRAMES:
            j = fi - PROG_FRAMES
            im = dim(im, min(1.0, max(0, j - 3) / 4.0), (0.08, 0.07, 0.1))
        d = ImageDraw.Draw(im)
        bx0, bx1 = 200 * K, 440 * K
        by = C_BAR_Y * K
        d.rectangle((bx0 - 3, by - 3, bx1 + 2, by + 14), fill=(11, 13, 31), outline=(70, 56, 92), width=3)
        fw = int((bx1 - bx0) * ratio)
        if fw > 0:
            d.rectangle((bx0 + 3, by + 3, bx0 + 3 + fw - 7, by + 8), fill=(246, 194, 114))
        text_c(im, status_text(fi), 290 * K, 48, C_CREAM, 5, (11, 13, 31))
        text_c(im, "İpucu: Hiç can hakkın kalmazsa 5 dakikada bir kalp yenilenir.", 326 * K, 32, (214, 196, 196), 4, (11, 13, 31))
        frames.append(im)
    return frames


# ================================================================== D - Son Mum (özgün, kod çizimi)
D_C = (320, 196)               # mum dibi (tabak merkezi)
WOOD = [(107, 74, 47), (95, 65, 42), (115, 80, 47), (101, 70, 44)]
SEAM = (46, 31, 20)
FLAME = {"w": (255, 246, 208), "y": (255, 208, 96), "o": (255, 138, 42), "r": (200, 74, 32)}
_FL = ["....r....", "....o....", "...oo....", "...ooo...", "..ooyo...", "..oyyoo..", ".ooyyyo..", ".oyywyyo.",
       ".oywwwyo.", ".oywwwyo.", "..yywyy..", "..yyyyy..", "...yyy...", "....y...."]


def _lean(rows, d):
    return [(r[d:] + "." * d) if d > 0 else ("." * -d + r[:len(r) + d]) for r in rows[:5]] + rows[5:]


FLAME_FR = [_FL, _lean(_FL, 1), _FL, _lean(_FL, -1)]
FLAME_SMALL = ["........."] * 8 + ["....o....", "...oyo...", "...oyo...", "...yy....", "....y....", "........."]
SMOKE = (92, 88, 96)
SWORD = [".......kk..................................",
         "......kcck.................................",
         ".kkk..kcckkkkkkkkkkkkkkkkkkkkkkkkkkkkkkk...",
         "kppkggkcckSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSk.",
         "kppkggkcckssssssssssssssssssssssssssssssskk",
         ".kkk..kcckkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkk..",
         "......kcck.................................",
         ".......kk.................................."]
SWORD_PAL = {"k": (28, 22, 20), "c": (196, 152, 64), "p": (214, 172, 80), "g": (92, 52, 30), "S": (226, 232, 236), "s": (150, 160, 172)}


def d_floor():
    """Tam aydınlık zemin + eşyalar (ışık bantları sonra çarpar)."""
    cv = np.zeros((CH, CW, 3), np.uint8)
    ph = 9
    for row in range(CH // ph + 1):
        y0 = row * ph
        x = -int(hsh(row, 41) * 60)
        while x < CW:
            ln = 38 + int(hsh(row, x, 42) * 56)
            col = WOOD[int(hsh(row, x, 43) * 4)]
            xa, xb = max(0, x), min(CW, x + ln)
            if xb > xa:
                cv[y0:y0 + ph - 1, xa:xb] = col
                for _ in range(int(hsh(row, x, 44) * 3)):         # damar çizgisi
                    gx = xa + int(hsh(row, x, _, 45) * max(1, xb - xa - 12))
                    gy = y0 + 2 + int(hsh(row, x, _, 46) * (ph - 4))
                    cv[min(CH - 1, gy), gx:min(CW, gx + 6 + int(hsh(row, x, _, 47) * 14))] = tuple(int(c * 0.82) for c in col)
                if xb < CW:
                    cv[y0:y0 + ph - 1, xb - 1] = SEAM
                    if 0 <= y0 + 3 < CH:
                        cv[y0 + 3, xb - 3] = (40, 34, 30)        # çivi
            x += ln
        if y0 + ph - 1 < CH:
            cv[y0 + ph - 1] = SEAM
    # kılıç (sol alt), kalkan (sağ), kitap (sol üst), paralar
    put(cv, SWORD, 168, 242, SWORD_PAL)
    sx, sy, rx, ry = 452, 196, 17, 12
    for y in range(sy - ry, sy + ry + 1):
        for x in range(sx - rx, sx + rx + 1):
            e = ((x - sx) / rx) ** 2 + ((y - sy) / ry) ** 2
            if e <= 1:
                if e > 0.78:
                    cv[y, x] = (120, 122, 130) if y < sy else (78, 78, 88)
                elif abs(x - sx + 6) < 1 or abs(x - sx - 6) < 1:
                    cv[y, x] = (70, 44, 26)
                else:
                    cv[y, x] = (142, 52, 40) if (x - sx) // 6 % 2 == 0 else (124, 44, 36)
    for y in range(sy - 3, sy + 4):
        for x in range(sx - 4, sx + 5):
            if ((x - sx) / 4) ** 2 + ((y - sy) / 3) ** 2 <= 1:
                cv[y, x] = (184, 186, 192) if y < sy else (120, 122, 132)
    bxx, byy = 196, 132
    cv[byy:byy + 14, bxx:bxx + 28] = (60, 30, 24)                  # cilt
    cv[byy + 1:byy + 13, bxx + 1:bxx + 13] = (226, 214, 180)        # sol sayfa
    cv[byy + 1:byy + 13, bxx + 15:bxx + 27] = (216, 204, 170)       # sağ sayfa
    cv[byy + 1:byy + 13, bxx + 13:bxx + 15] = (150, 132, 104)
    for i in range(5):
        cv[byy + 3 + i * 2, bxx + 3:bxx + 3 + 6 + int(hsh(i, 51) * 4)] = (120, 106, 90)
        cv[byy + 3 + i * 2, bxx + 17:bxx + 17 + 5 + int(hsh(i, 52) * 5)] = (120, 106, 90)
    for (x, y) in ((362, 218), (368, 221), (357, 223), (374, 216)):
        cv[y:y + 2, x:x + 4] = (214, 170, 64)
        cv[y, x + 1] = (250, 222, 132)
        cv[y + 2, x:x + 4] = (120, 86, 30)
    return cv


def d_light(cv, R, fi):
    flick = [0, 1, -1, 2, 0, -1][fi % 6]
    out = np.zeros_like(cv, np.float32)
    if R <= 0:
        return out.astype(np.uint8)
    e = np.sqrt(((XX - D_C[0]) / (R + flick)) ** 2 + ((YY - D_C[1] + 6) / ((R + flick) * 0.6)) ** 2)
    m = np.zeros((CH, CW, 3), np.float32)
    m[e <= 1.0] = (0.30, 0.22, 0.20)
    m[e <= 0.76] = (0.62, 0.50, 0.40)
    m[e <= 0.48] = (1.0, 0.88, 0.70)
    out = cv.astype(np.float32) * m
    return np.clip(out, 0, 255).astype(np.uint8)


def d_candle(cv, fi, flame="on"):
    cx, cy = D_C
    for y in range(cy - 4, cy + 5):                                   # pirinç tabak
        for x in range(cx - 14, cx + 15):
            e = ((x - cx) / 14) ** 2 + ((y - cy) / 4) ** 2
            if e <= 1:
                cv[y, x] = (122, 85, 36) if y > cy or e > 0.7 else (176, 130, 58)
    cv[cy - 2, cx - 9:cx - 4] = (224, 184, 96)
    top = cy - 46
    cv[top:cy, cx - 6:cx + 6] = (239, 228, 200)                      # mum gövdesi 12x46
    cv[top:cy, cx - 6:cx - 4] = (250, 244, 226)
    cv[top:cy, cx + 3:cx + 6] = (203, 189, 156)
    cv[top, cx - 6:cx + 6] = (252, 248, 232)
    for (dx, ln) in ((-6, 11), (-2, 6), (4, 17), (5, 9)):            # erimiş damlalar
        cv[top:top + ln, cx + dx] = (252, 248, 232) if dx < 2 else (222, 210, 178)
        cv[top + ln, cx + dx] = (190, 176, 146)
    cv[top - 4:top, cx] = (40, 30, 24)                                # fitil
    if flame == "on":
        put(cv, FLAME_FR[fi % 4], cx - 4, top - 17, FLAME)
    elif flame == "small":
        put(cv, FLAME_SMALL, cx - 4, top - 17, FLAME)
    else:                                                             # söndü: mum da karanlıkta kalır
        box = cv[top - 4:cy + 5, cx - 14:cx + 15]
        box[:] = np.maximum((box.astype(np.float32) * 0.16).astype(np.uint8), np.array([8, 7, 12], np.uint8))


EYES = None


def d_eyes(cv, R, fi):
    global EYES
    if EYES is None:
        EYES = []
        cols = [(200, 50, 58), (224, 160, 48), (143, 209, 79)]
        i = 0
        while len(EYES) < 15:
            x = 24 + int(hsh(i, 61) * (CW - 48))
            y = 18 + int(hsh(i, 62) * 250)
            e = math.sqrt(((x - D_C[0]) / 70.0) ** 2 + ((y - D_C[1]) / 42.0) ** 2)
            if e > 1.3 and not (190 < x < 450 and y > 270):
                EYES.append((x, y, cols[int(hsh(i, 63) * 3)], int(hsh(i, 64) * 40)))
            i += 1
    for (x, y, col, ph) in EYES:
        e = math.sqrt(((x - D_C[0]) / max(1.0, R)) ** 2 + ((y - D_C[1] + 6) / max(1.0, R * 0.6)) ** 2)
        if e < 1.12:
            continue                      # ışık yetişti: geri çekildi
        if (fi + ph) % 40 < 2:
            continue                      # kırpma
        squint = e < 1.35
        for ox in (0, 5):
            cv[y + (1 if squint else 0):y + 2, x + ox:x + ox + 2] = col


D_BAR_Y = 314


def proto_d():
    floor = d_floor()
    frames = []
    total = PROG_FRAMES + ARRIVE_FRAMES + HOLD_FRAMES
    for fi in range(total):
        if fi < PROG_FRAMES:
            p = fi / (PROG_FRAMES - 1.0)
            ratio = min(p, 0.95) if fi < PROG_FRAMES - 1 else 0.97
            R = 34 + p * 330
            flame = "on"
        else:
            j = fi - PROG_FRAMES
            ratio = 1.0
            R = [364, 300, 200, 90, 30, 0, 0, 0, 0, 0][j] if j < ARRIVE_FRAMES else 0
            flame = "on" if j < 1 else ("small" if j < 3 else "off")
        cv = d_light(floor, R, fi)
        cv[:] = np.where(cv.sum(2, keepdims=True) == 0, np.array([8, 7, 12], np.uint8), cv)
        d_eyes(cv, R, fi)
        d_candle(cv, fi, flame)
        if fi >= PROG_FRAMES and flame == "off":                     # söndükten sonra fitilden duman
            j = fi - PROG_FRAMES
            for i in range(6):
                yy = D_C[1] - 50 - i * 3 - j
                xx = D_C[0] + int(math.sin((i + j) * 0.9) * 2)
                if yy > 0 and i < j + 2:
                    cv[yy, xx] = SMOKE
        im = upscale(cv)
        d = ImageDraw.Draw(im)
        bx0, bx1 = 220 * K, 420 * K
        by = D_BAR_Y * K
        d.rectangle((bx0 - 3, by - 3, bx1 + 2, by + 11), fill=(14, 12, 18), outline=(59, 47, 42), width=3)
        fw = int((bx1 - bx0) * ratio)
        if fw > 6:
            d.rectangle((bx0 + 3, by + 3, bx0 + fw - 4, by + 5), fill=(239, 228, 200))
        text_c(im, status_text(fi), 290 * K, 48, C_CREAM, 5, (8, 7, 12))
        text_c(im, "İpucu: Evin içindeyken yaratıklar sana saldıramaz.", 326 * K, 32, (200, 184, 160), 4, (8, 7, 12))
        frames.append(im)
    return frames


# ------------------------------------------------------------------ çıktı
PROTOS = {"a": ("a_muhurlu_kapi", proto_a), "b": ("b_dort_bolge", proto_b), "c": ("c_safaga_kadar", proto_c), "d": ("d_son_mum", proto_d)}
STILL_FRAME = int(PROG_FRAMES * 0.55)


def save_gif(frames, path):
    """Tek ortak palet (örnek karelerden) -> kareler arası fark kodlanır, dosya küçük kalır."""
    rgb = [f.convert("RGB").resize((SW // 2, SH // 2), Image.LANCZOS) for f in frames]
    picks = rgb[::8] + [rgb[-ARRIVE_FRAMES - HOLD_FRAMES], rgb[-1]]
    strip = Image.new("RGB", (SW // 2, SH // 2 * len(picks)))
    for i, s in enumerate(picks):
        strip.paste(s, (0, i * SH // 2))
    pal = strip.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    small = [s.quantize(palette=pal, dither=Image.Dither.NONE) for s in rgb]
    durs = [GIF_MS] * len(small)
    durs[PROG_FRAMES - 1] = 500
    durs[-1] = 900
    small[0].save(path, save_all=True, append_images=small[1:], duration=durs, loop=0, optimize=False)


def main():
    os.makedirs(OUT, exist_ok=True)
    which = [a for a in sys.argv[1:] if a in PROTOS] or list(PROTOS)
    for key in which:
        name, fn = PROTOS[key]
        frames = fn()
        frames[STILL_FRAME].convert("RGB").save(os.path.join(OUT, name + ".png"))
        frames[PROG_FRAMES + ARRIVE_FRAMES + 1].convert("RGB").save(os.path.join(OUT, name + "_varis.png"))
        save_gif(frames, os.path.join(OUT, name + ".gif"))
        print("yazildi", name, len(frames), "kare")
    stills = [os.path.join(OUT, PROTOS[k][0] + ".png") for k in PROTOS]
    if all(os.path.exists(s) for s in stills):
        sheet = Image.new("RGB", (SW, SH + 2 * 44), (16, 13, 12))
        d = ImageDraw.Draw(sheet)
        labels = ["A - Mühürlü Kapı (yeni harita)", "B - Dört Bölge (yeni harita)", "C - Şafağa Kadar (özgün)", "D - Son Mum (özgün)"]
        for i, s in enumerate(stills):
            x, y = (i % 2) * (SW // 2), (i // 2) * (SH // 2 + 44)
            d.text((x + 16, y + 6), labels[i], font=font(32), fill=C_CREAM)
            sheet.paste(Image.open(s).resize((SW // 2, SH // 2), Image.LANCZOS), (x, y + 44))
        sheet.save(os.path.join(OUT, "karsilastirma.png"))
        print("yazildi karsilastirma.png")


if __name__ == "__main__":
    main()
