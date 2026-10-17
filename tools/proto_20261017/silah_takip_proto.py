# -*- coding: utf-8 -*-
"""Süzülen silahların KARAKTERİ TAKİP animasyonu PROTOTİPLERİ (2026-10-17, oyuna bağlı DEĞİL). Kullanıcı: "silahların karakterin
üstünde karakteri takip ederkenki animasyonu için yeni prototipler üret 4 tane".

Bugün (teşhis; weapon.gd _update_hover_follow + _update_icon_shadow, player.gd WEAPON_ICON_SLOTS):
  - 3 slot (yerel x0,5 = dünya): tepe (0,-62,5), sağ üst (31,-35), sol üst (-31,-35). Can barı -34..-27 (overhead_bar.gd).
  - Konum: hedefe her fizik karesinde lerp(9 x dt) + en fazla 10 dünya px kopma; 82 px/sn yürüyüşte kararlı gecikme v/9 = ~9 px
    (sınırın hemen altı) -> yürürken silahlar ~9 px geride, durunca ~0,3 sn'de yerine kayar. Dönüş/eğilme YOK.
  - Salınım: sin(2,2 t + rastgele faz) x 1,75 dünya px (3,5 yerel), her silahın kendi fazı.
  - Konum TAM dünya pikseline yuvarlanıyor (global_position.round()) ama karakter/kamera kesirli -> zoom 2'de karaktere göre
    1-2 ekran px titreme (fizik interpolasyonu araya kesir koysa da yuvarlanmış iki nokta arası).
  - Gölge ikonun altında sabit boşlukta, ikonla birlikte kayar (karakterin altında çizilir).

Dört yön (hepsi aynı yürüyüş: dur, sağ, dur, yukarı, sola + keskin dönüşle aşağı, kısa sağ-sol kaçış, dur; kamera oyuncuya kilitli
= oyundaki gibi; yeni yönlerde konum ekran pikseline (0,5 dünya px) yuvarlanır -> titreme yok):
  A Yaylı Sarkaç   - konum yay ile (ω 10, sönüm 0,4; ~6 px gecikme, durunca ~1,5 px ileri taşar), uçlar harekete karşı 12 derece
                     geriye yatar (hava direnci), durunca sarkaç gibi 2-3 kez sallanıp oturur; her silahın yayı biraz farklı.
  B Adım Ritmi     - konum karaktere KİLİTLİ (gecikme yok); yürürken her ayak basışında (yürüme klibi 8 fps, 3 karede bir) 2,5 px
                     zıplar, inişte ezilir, adım adım sağa-sola 5 derece sallanır, sol -> tepe -> sağ dalga gibi sırayla;
                     dururken üçü yavaş bir dalga halinde nefes alır.
  C Taç Yörüngesi  - silahlar kafanın üstünde 2:1 bir halkada (60 x 16 px) yavaşça döner (5,7 sn'de bir tur); arkadakiler %12
                     küçük ve koyu (derinlik), gölgeler ayak çevresinde aynı halkada döner; halka yay ile hafifçe geride kalır.
  D Kanat Süpürmesi- dururken bugünkü yelpaze; yürürken öndeki kanat 6 px yükselir, arkadaki 12 px geride kalır, tepe geri-yukarı, uçlar
                     gidiş yönüne 22 derece eğilir (ileri atılma); her silahın yayı farklı -> sırayla katlanır, durunca kanatlar
                     açılırken hafifçe ileri savrulur (kanat çırpma).
Menzilli silahlar oyunda en yakın düşmana döner: A/B/D'deki eğim nişan açısına EKLENİR (bu prototipte düşman yok, dinlenme pozu).

Çıktılar (out/silah_takip/): takip_oyun.gif (1080p oyun ölçeği, gerçek hız; ŞU AN + A-D + bilgi), takip_yakin.gif (x2 yakın,
kafa üstü), takip_kare.png.
Çalıştırma: python tools/proto_20261017/silah_takip_proto.py [oyun|yakin]   (argümansız: hepsi)
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import mermi_proto as MP  # noqa: E402  (varlık yükleme, yazı)
from mermi_proto import asset, label  # noqa: E402
from bicak_proto import header, stack_v, save_gif  # noqa: E402

OUT = os.path.join(HERE, "out", "silah_takip")
GROUND_SRC = os.path.join(HERE, "..", "proto_20261016", "harita_renk", "out", "kopru_oyun_A.png")  # gerçek çizici, 1 dünya px/px
WPP = 0.575  # weapon_tier_art.gd WORLD_PX (silah sanat pikseli -> dünya px)
CHAR_K = 2.2368375 * 0.8075 * 0.5  # Şovalye: characters.gd ölçek x EntityScale.SIZE x oyuncu kökü 0,5
CHAR_OFF_Y = -1.8 * CHAR_K  # characters.gd "offset" (0,-1,8) karakter pikseli
SPEED = 91.0 * 0.9  # player.tscn speed x EntityScale.SPEED
TICK = 60.0
DT = 1.0 / TICK
FPS = 50
D2R = math.pi / 180.0

SLOTS_LOCAL = [(0.0, -125.0), (62.0, -70.0), (-62.0, -70.0)]  # player.gd WEAPON_ICON_SLOTS (ilk 3, MAX_OWNED_WEAPONS 3)
SLOTS = [(x * 0.5, y * 0.5) for x, y in SLOTS_LOCAL]
WEAPONS = [("uzunkilic", -45.0), ("fire_staff", 0.0), ("tabanca", 0.0)]  # (anahtar, dinlenme dönüşü: REST / nişansız 0)
ORDER_LR = [1, 0, 2]  # soldan sağa sıra: silah 2 (sol), 0 (tepe), 1 (sağ) -> dalga sırası indeksi
CUR_PHASES = [0.4, 2.6, 4.9]  # bugünkü rastgele bob fazları (sabit örnek)
BOB_W = 2.2  # weapon.gd HOVER_BOB_SPEED
LOOP = 2.0 * (2.0 * math.pi / BOB_W)  # 2 salınım periyodu = 5,71 sn (GIF dikişsiz)

# ------------------------------------------------------------------ yürüyüş
# (süre, yön) ; yön None = dur. Net yer değiştirme 0 (döngü kapanır).
PATH = [(0.50, None), (1.00, (1, 0)), (0.60, None), (0.50, (0, -1)), (1.00, (-1, 0)), (0.50, (0, 1)),
        (0.40, None), (0.30, (1, 0)), (0.30, (-1, 0))]
PATH.append((LOOP - sum(p[0] for p in PATH), None))
FACE_ROW = {(0, 1): 0, (-1, 0): 1, (1, 0): 2, (0, -1): 3}  # walk/idle sayfası satırları: aşağı, sol, sağ, yukarı
START = (258.0, 208.0)  # kopru_oyun_A.png içinde başlangıç (köprünün kuzeyindeki sakin çimenlik, küçük filizler)


def player_track():
    """Her fizik karesi için oyuncu durumu (konum, hız, hareket, yüz, yürüme süresi). Hız anlık (CharacterBody2D)."""
    n = int(round(LOOP * TICK))
    out = []
    x, y = START
    face = (0, 1)
    walk_t = 0.0
    prev_dir = None
    for i in range(n):
        t = i * DT
        acc, d = 0.0, None
        for dur, dd in PATH:
            if t < acc + dur - 1e-9:
                d = dd
                break
            acc += dur
        if d is not None:
            if d != prev_dir:
                walk_t = 0.0  # AnimatedSprite2D.play(yeni klip) -> kare 0
            face = d
        vx, vy = (d[0] * SPEED, d[1] * SPEED) if d else (0.0, 0.0)
        out.append({"t": t, "P": (x, y), "V": (vx, vy), "moving": d is not None, "face": face, "walk_t": walk_t})
        x += vx * DT
        y += vy * DT
        walk_t = walk_t + DT if d is not None else 0.0
        prev_dir = d
    return out


TRACK = player_track()


# ------------------------------------------------------------------ küçük matematik
def clamp(x, a, b):
    return a if x < a else b if x > b else x


def hover_shadow_gap(slot_y_local):
    """weapon_orbit_math.gd hover_shadow_gap (yerel) -> dünya boşluğu (x0,5)."""
    return (62.0 + max(0.0, -28.0 - slot_y_local) * 0.9) * 0.5


ICON_PX = {}


def icon_np(key):
    if key not in ICON_PX:
        ICON_PX[key] = np.asarray(asset("assets/weapons/zanaat/%s_L3.png" % key), dtype=np.float32)
    return ICON_PX[key]


def icon_size_world(key):
    a = icon_np(key)[..., 3]
    ys, xs = np.nonzero(a > 0)
    return ((xs.max() - xs.min() + 1) * WPP, (ys.max() - ys.min() + 1) * WPP)


def cur_shadow_radii(key, bob_norm):
    """weapon.gd _update_icon_shadow: half_w/half_h (dünya), SHADOW_SHRINK 0,8, FLATTEN 0,55."""
    w, h = icon_size_world(key)
    bf = 1.0 - bob_norm * 0.05
    return max(3.5, w * 0.30 * bf * 0.8), max(2.5, h * 0.30 * 0.55 * bf * 0.8)


class Spring2:
    """x'' = w^2 (T - x) - c x'  (mutlak sönüm = hava direnci -> kararlı gecikme c v / w^2)."""

    def __init__(self, w, zeta, absolute=True):
        self.w2, self.c, self.abs = w * w, 2.0 * zeta * w, absolute
        self.x = None
        self.v = (0.0, 0.0)

    def step(self, T, Tv=(0.0, 0.0)):
        if self.x is None:
            self.x = T
            self.v = Tv
            return self.x
        rvx = self.v[0] - (0.0 if self.abs else Tv[0])
        rvy = self.v[1] - (0.0 if self.abs else Tv[1])
        ax = self.w2 * (T[0] - self.x[0]) - self.c * rvx
        ay = self.w2 * (T[1] - self.x[1]) - self.c * rvy
        self.v = (self.v[0] + ax * DT, self.v[1] + ay * DT)
        self.x = (self.x[0] + self.v[0] * DT, self.x[1] + self.v[1] * DT)
        return self.x

    def limit(self, T, r):
        dx, dy = self.x[0] - T[0], self.x[1] - T[1]
        L = math.hypot(dx, dy)
        if L > r:
            self.x = (T[0] + dx / L * r, T[1] + dy / L * r)


class Spring1:
    def __init__(self, w, zeta):
        self.w2, self.c = w * w, 2.0 * zeta * w
        self.x, self.v = 0.0, 0.0

    def step(self, T):
        a = self.w2 * (T - self.x) - self.c * self.v
        self.v += a * DT
        self.x += self.v * DT
        return self.x


def half_px(v):
    """Ekran pikseline yuvarla (zoom 2 -> 0,5 dünya px)."""
    return round(v * 2.0) / 2.0


# ------------------------------------------------------------------ yönler
# Her yön: tick(st) -> silah başına {pos, rot, sx, sy, sh (x, y, rx, ry), depth, mul}
class Cur:
    title = "ŞU AN"
    sub = "lerp 9·dt, 10 px sınır · 1,75 px salınım · dünya px yuvarlı"

    def __init__(self):
        self.fl = [None] * 3

    def tick(self, st):
        P, t = st["P"], st["t"]
        res = []
        for i in range(3):
            bob_l = math.sin(t * BOB_W + CUR_PHASES[i]) * 3.5
            T = (P[0] + SLOTS[i][0], P[1] + SLOTS[i][1] + bob_l * 0.5)
            f = self.fl[i]
            if f is None or math.hypot(f[0] - T[0], f[1] - T[1]) > 200.0:
                f = T
            else:
                k = 9.0 * DT
                f = (f[0] + (T[0] - f[0]) * k, f[1] + (T[1] - f[1]) * k)
                dx, dy = f[0] - T[0], f[1] - T[1]
                L = math.hypot(dx, dy)
                if L > 10.0:
                    f = (T[0] + dx / L * 10.0, T[1] + dy / L * 10.0)
            self.fl[i] = f
            pos = (round(f[0]), round(f[1]))
            norm = bob_l / 3.5
            gap = (hover_shadow_gap(SLOTS_LOCAL[i][1]) * 2.0 + norm * 3.0) * 0.5
            rx, ry = cur_shadow_radii(WEAPONS[i][0], norm)
            res.append({"pos": pos, "rot": WEAPONS[i][1], "sh": (pos[0], pos[1] + gap, rx, ry)})
        return res


class DirA:
    title = "A · Yaylı Sarkaç"
    sub = "yay ~6 px gecikme · uç geriye 12° yatar · durunca sallanır"
    LEAN = 12.0

    def __init__(self):
        self.sp = [Spring2(10.0 * m, 0.40) for m in (1.0, 0.92, 1.08)]
        self.ang = [Spring1(11.0 * m, 0.28) for m in (1.0, 1.06, 0.95)]

    def tick(self, st):
        P, t = st["P"], st["t"]
        res = []
        for i in range(3):
            bob = math.sin(t * BOB_W + CUR_PHASES[i]) * 1.75
            T = (P[0] + SLOTS[i][0], P[1] + SLOTS[i][1] + bob)
            x = self.sp[i].step(T)
            self.sp[i].limit(T, 9.0)
            x = self.sp[i].x
            vx = self.sp[i].v[0]
            lean = self.ang[i].step(-self.LEAN * clamp(vx / SPEED, -1.3, 1.3))
            pos = (half_px(x[0]), half_px(x[1]))
            gap = hover_shadow_gap(SLOTS_LOCAL[i][1])
            rx, ry = cur_shadow_radii(WEAPONS[i][0], 0.0)
            res.append({"pos": pos, "rot": WEAPONS[i][1] + lean, "sh": (pos[0], pos[1] - bob + gap, rx, ry)})
        return res


class DirB:
    title = "B · Adım Ritmi"
    sub = "kilitli · her adımda 2,5 px zıplar (dalga) · dururken nefes"
    HOP = 2.5
    STEP_T = 3.0 / 8.0  # yürüme klibi 8 fps, 6 kare -> 3 karede bir ayak basışı
    DELAY = 0.06

    def __init__(self):
        self.wf = 0.0

    def tick(self, st):
        P, t = st["P"], st["t"]
        self.wf = clamp(self.wf + (DT / 0.12 if st["moving"] else -DT / 0.18), 0.0, 1.0)
        wf = self.wf * self.wf * (3.0 - 2.0 * self.wf)
        res = []
        for i in range(3):
            o = ORDER_LR.index(i)  # 0 sol, 1 tepe, 2 sağ
            breath = math.sin(t * BOB_W - o * 0.9) * 2.0
            h, rock, sq = 0.0, 0.0, 1.0
            wt = st["walk_t"] - o * self.DELAY
            if st["moving"] and wt > 0.0:
                n = int(wt / self.STEP_T)
                u = (wt / self.STEP_T) - n
                h = self.HOP * math.sin(math.pi * u)
                rock = 5.0 * math.sin(math.pi * u) * (1.0 if n % 2 == 0 else -1.0)
                if u < 0.2:
                    sq = 1.0 - 0.14 * (1.0 - u / 0.2)
            dy = -h * wf + breath * (1.0 - wf)
            pos = (half_px(P[0] + SLOTS[i][0]), half_px(P[1] + SLOTS[i][1] + dy))
            gy = P[1] + SLOTS[i][1] + hover_shadow_gap(SLOTS_LOCAL[i][1])
            rx, ry = cur_shadow_radii(WEAPONS[i][0], 0.0)
            k = 1.0 - (h * wf) / 14.0
            res.append({"pos": pos, "rot": WEAPONS[i][1] + rock * wf, "sx": 1.0 / sq, "sy": sq,
                        "sh": (pos[0], gy, rx * k, ry * k)})
        return res


class DirC:
    title = "C · Taç Yörüngesi"
    sub = "2:1 halka, 5,7 sn/tur · arkadakiler küçük-koyu · gölge halkası"
    RC = (0.0, -58.0)
    RX, RY = 30.0, 8.0
    GROUND = 12.0  # gölge halkasının merkezi (ayak çizgisi)

    def __init__(self):
        self.sp = Spring2(9.0, 0.6)

    def tick(self, st):
        P, t = st["P"], st["t"]
        bob = math.sin(t * BOB_W) * 1.5
        T = (P[0] + self.RC[0], P[1] + self.RC[1] + bob)
        c = self.sp.step(T)
        self.sp.limit(T, 5.0)
        c = self.sp.x
        # 1 tur / döngü (5,7 sn) -> dikişsiz; ilk silah önde başlar
        base = 2.0 * math.pi * t / LOOP + math.pi / 2.0
        res = []
        for i in range(3):
            ph = base + i * 2.0 * math.pi / 3.0
            s = math.sin(ph)
            x = c[0] + self.RX * math.cos(ph)
            y = c[1] + self.RY * s
            sc = 0.94 + 0.06 * s
            rx, ry = cur_shadow_radii(WEAPONS[i][0], 0.0)
            gx = P[0] + (c[0] - P[0]) * 0.5 + self.RX * math.cos(ph)
            gy = P[1] + self.GROUND + self.RY * 0.7 * s
            res.append({"pos": (half_px(x), half_px(y)), "rot": WEAPONS[i][1], "sx": sc, "sy": sc, "depth": s,
                        "mul": 0.86 + 0.14 * (s + 1.0) / 2.0, "sh": (gx, gy, rx * sc, ry * sc)})
        return res


class DirD:
    title = "D · Kanat Süpürmesi"
    sub = "öndeki kanat yükselir, arkadaki geride · uç ileri 22° · çırpar"
    TILT = 22.0

    def __init__(self):
        self.sp = [Spring2(12.0, 0.42), Spring2(9.0, 0.38), Spring2(8.5, 0.38)]

    def tick(self, st):
        P, t = st["P"], st["t"]
        vx, vy = st["V"]
        w_t = (vx / SPEED, vy / SPEED)
        res = []
        for i in range(3):
            w = self.sp[i].step(w_t)
            m = min(1.2, math.hypot(w[0], w[1]))
            bob = math.sin(t * BOB_W + CUR_PHASES[i]) * 1.75 * (1.0 - min(1.0, m) * 0.6)
            sx, sy = SLOTS[i]
            if i == 0:
                ox, oy = -w[0] * 6.0, -w[1] * 3.0 - 3.0 * m
            else:
                side = 1.0 if sx > 0 else -1.0
                lead = side * w[0]  # > 0: bu kanat gidiş yönünde (öndeki kanat)
                if lead > 0.0:
                    ox, oy = -w[0] * 3.0, -6.0 * lead  # öndeki kanat yükselir, neredeyse geri gitmez (can barına binmez)
                else:
                    ox, oy = -w[0] * 12.0, 2.0 * -lead  # arkadaki kanat geride (dışarı) kalır
                ox += side * 4.0 * abs(w[1])  # dikey yürüyüşte iki kanat da biraz açılır
                oy += -w[1] * 5.5
            pos = (half_px(P[0] + sx + ox), half_px(P[1] + sy + oy + bob))
            rx, ry = cur_shadow_radii(WEAPONS[i][0], 0.0)
            gap = hover_shadow_gap(SLOTS_LOCAL[i][1])
            res.append({"pos": pos, "rot": WEAPONS[i][1] + self.TILT * clamp(w[0], -1.2, 1.2),
                        "sh": (pos[0], pos[1] - bob + gap, rx, ry)})
        return res


DIRS = [Cur, DirA, DirB, DirC, DirD]


def simulate(cls):
    """İki döngü koşturur (yaylar otursun), ikincisinin karelerini döner."""
    d = cls()
    for _ in range(2):
        rec = [d.tick(st) for st in TRACK]
    return d, rec


# ------------------------------------------------------------------ çizim
def blit2(F, Sa, cx, cy, k, rot=0.0, sx=1.0, sy=1.0, alpha=1.0, mul=1.0):
    """Godot Sprite2D taklidi: merkezli, ölçek sonra dönüş, NEAREST. (cx, cy) ekran; k = ekran px / sanat pikseli."""
    sh, sw = Sa.shape[:2]
    px, py = sw / 2.0, sh / 2.0
    c, s = math.cos(rot), math.sin(rot)
    rad = int(math.hypot(sw, sh) / 2.0 * k * max(sx, sy)) + 2
    H, W = F.shape[:2]
    x0, x1 = max(0, int(cx) - rad), min(W, int(cx) + rad)
    y0, y1 = max(0, int(cy) - rad), min(H, int(cy) + rad)
    if x0 >= x1 or y0 >= y1:
        return
    X, Y = np.meshgrid(np.arange(x0, x1) + 0.5 - cx, np.arange(y0, y1) + 0.5 - cy)
    u = np.floor((c * X + s * Y) / (k * sx) + px).astype(np.int32)
    v = np.floor((-s * X + c * Y) / (k * sy) + py).astype(np.int32)
    m = (u >= 0) & (u < sw) & (v >= 0) & (v < sh)
    if not m.any():
        return
    samp = np.zeros((y1 - y0, x1 - x0, 4), np.float32)
    samp[m] = Sa[v[m], u[m]]
    a = samp[..., 3:4] / 255.0 * alpha
    F[y0:y1, x0:x1] = F[y0:y1, x0:x1] * (1.0 - a) + samp[..., :3] * mul * a


def ellipse(F, cx, cy, rx, ry, col, alpha):
    H, W = F.shape[:2]
    x0, x1 = max(0, int(cx - rx) - 1), min(W, int(cx + rx) + 2)
    y0, y1 = max(0, int(cy - ry) - 1), min(H, int(cy + ry) + 2)
    if x0 >= x1 or y0 >= y1:
        return
    X, Y = np.meshgrid(np.arange(x0, x1) + 0.5 - cx, np.arange(y0, y1) + 0.5 - cy)
    m = ((X / max(rx, 0.1)) ** 2 + (Y / max(ry, 0.1)) ** 2) <= 1.0
    sub = F[y0:y1, x0:x1]
    sub[m] = sub[m] * (1.0 - alpha) + np.array(col, np.float32) * alpha


def rect(F, x0, y0, x1, y1, col):
    H, W = F.shape[:2]
    x0, y0, x1, y1 = max(0, int(round(x0))), max(0, int(round(y0))), min(W, int(round(x1))), min(H, int(round(y1)))
    if x0 < x1 and y0 < y1:
        F[y0:y1, x0:x1] = col


_GROUND = {}


def ground(z):
    if z not in _GROUND:
        g = Image.open(GROUND_SRC).convert("RGB")
        _GROUND[z] = np.asarray(g.resize((g.width * z, g.height * z), Image.NEAREST))
    return _GROUND[z]


_SHEET = {}


def char_frame(moving, face, walk_t, t):
    row = FACE_ROW[face]
    if moving:
        name, n, fps = "walk", 6, 8.0
        col = int(walk_t * fps) % n
    else:
        name, n, fps = "idle", 4, 4.0
        col = int(t * fps) % n
    k = (name, row, col)
    if k not in _SHEET:
        _SHEET[k] = np.asarray(asset("assets/characters/sovalye/sheets/%s.png" % name, (col * 48, row * 48, col * 48 + 48, row * 48 + 48)),
                               dtype=np.float32)
    return _SHEET[k]


def lerp2(a, b, f):
    return (a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f)


def interp_state(rec, t):
    """Fizik interpolasyonu: iki fizik karesi arası doğrusal (project.godot physics_interpolation=true)."""
    n = len(TRACK)
    ft = (t % LOOP) * TICK
    i0 = int(ft) % n
    i1 = (i0 + 1) % n
    f = ft - int(ft)
    p0, p1 = TRACK[i0]["P"], TRACK[i1]["P"]
    if i1 == 0:
        p1 = START
    P = lerp2(p0, p1, f)
    ws = []
    for a, b in zip(rec[i0], rec[i1]):
        w = dict(a)
        w["pos"] = lerp2(a["pos"], b["pos"], f)
        w["rot"] = a["rot"] + (b["rot"] - a["rot"]) * f
        sa, sb = a["sh"], b["sh"]
        w["sh"] = tuple(sa[j] + (sb[j] - sa[j]) * f for j in range(4))
        ws.append(w)
    return P, TRACK[i0], ws


def render(rec, t, z, view):
    """view = (x0, y0, x1, y1) oyuncuya göre dünya penceresi. Kamera oyuncuya kilitli (player.tscn Camera2D, yumuşatma yok)."""
    P, st, ws = interp_state(rec, t)
    G = ground(z)
    cx0 = int(round((P[0] + view[0]) * z))
    cy0 = int(round((P[1] + view[1]) * z))
    Wd, Hd = int((view[2] - view[0]) * z), int((view[3] - view[1]) * z)
    F = G[cy0:cy0 + Hd, cx0:cx0 + Wd].astype(np.float32).copy()

    def S(p):
        return (p[0] * z - cx0, p[1] * z - cy0)

    # silah gölgeleri (karakterin altında) - shadow_blob.gd: siyah daire a 0,32 x modulate 0,4
    for w in ws:
        gx, gy, rx, ry = w["sh"]
        sx, sy = S((gx, gy))
        ellipse(F, sx, sy, rx * z, ry * z, (0, 0, 0), 0.32 * 0.4)
    # karakter gölgesi + karakter
    sx, sy = S((P[0], P[1] + 12.0))
    ellipse(F, sx, sy, 9.0 * z, 3.5 * z, (0, 0, 0), 0.32)
    fr = char_frame(st["moving"], st["face"], st["walk_t"], st["t"])
    sx, sy = S((P[0], P[1] + CHAR_OFF_Y))
    blit2(F, fr, sx, sy, CHAR_K * z)

    order = sorted(range(len(ws)), key=lambda j: ws[j].get("depth", 0.0))
    back = [j for j in order if ws[j].get("depth", 0.0) < 0.0]
    front = [j for j in order if ws[j].get("depth", 0.0) >= 0.0]

    def draw_w(j):
        w = ws[j]
        x, y = S(w["pos"])
        blit2(F, icon_np(WEAPONS[j][0]), x, y, WPP * z, w["rot"] * D2R, w.get("sx", 1.0), w.get("sy", 1.0), mul=w.get("mul", 1.0))

    for j in back:
        draw_w(j)
    # can + kalkan barı (overhead_bar.gd: 44 x 7 yerel, kalkan 0,72 boy, 2 yerel çerçeve) - dünya = yerel x 0,5
    bx0, bx1 = P[0] - 11.0, P[0] + 11.0
    for (y0, y1, fill, bg) in ((-34.0, -30.5, (77, 209, 61), (31, 10, 10)), (-29.5, -27.0, (89, 184, 255), (10, 20, 36))):
        a0, b0 = S((bx0 - 1.0, P[1] + y0 - 1.0))
        a1, b1 = S((bx1 + 1.0, P[1] + y1 + 1.0))
        rect(F, a0, b0, a1, b1, (14, 12, 12))
        a0, b0 = S((bx0, P[1] + y0))
        a1, b1 = S((bx1, P[1] + y1))
        rect(F, a0, b0, a1, b1, fill)
        rect(F, a0, b0, a1, b0 + max(1, z // 2), tuple(min(255, c + 50) for c in fill))
    for j in front:
        draw_w(j)
    return Image.fromarray(np.clip(F, 0, 255).astype(np.uint8), "RGB")


def tile_label(im, cls, small=False):
    d = ImageDraw.Draw(im)
    label(d, 6, 3, cls.title, 12)
    if not small:
        label(d, 6, im.height - 15, cls.sub, 9, (232, 226, 210))


def info_tile(w, h, lines, title=None):
    im = Image.new("RGB", (w, h), (30, 34, 32))
    d = ImageDraw.Draw(im)
    y = 10
    if title:
        label(d, 10, y, title, 14)
        y += 24
    for s in lines:
        label(d, 10, y, s, 10, (220, 214, 198))
        y += 15
    return im


def grid(tiles, cols, gap=4):
    w, h = tiles[0].size
    rows = (len(tiles) + cols - 1) // cols
    g = Image.new("RGB", (cols * w + (cols - 1) * gap, rows * h + (rows - 1) * gap), (18, 20, 20))
    for i, tl in enumerate(tiles):
        g.paste(tl, ((i % cols) * (w + gap), (i // cols) * (h + gap)))
    return g


def phase_name(t):
    acc = 0.0
    for dur, d in PATH:
        if t < acc + dur:
            if d is None:
                return "duruyor"
            return {(1, 0): "sağa yürüyor", (-1, 0): "sola yürüyor", (0, -1): "yukarı yürüyor", (0, 1): "aşağı yürüyor"}[d]
        acc += dur
    return "duruyor"


INFO = [
    "Şovalye + 3 silah (Uzunkılıç tepe, Ateş Asası sağ, Tabanca sol)",
    "kamera oyuncuya kilitli (oyundaki gibi), yürüyüş 82 px/sn",
    "fizik 60 Hz + interpolasyon, GIF %d fps",
    "ŞU AN: yürürken ~9 px geride, dünya pikseline yuvarlı",
    "  -> zoom 2'de karaktere göre 1-2 ekran px titreme",
    "yeni yönler ekran pikseline yuvarlı (titreme yok)",
    "menzilli silah oyunda düşmana döner: eğim nişana eklenir",
    "gölgeler: bugünkü shadow_blob (çok soluk, %13)",
]


def build(z, view, name, small, fps):
    sims = [(cls, simulate(cls)[1]) for cls in DIRS]
    n = int(round(LOOP * fps))
    dt = LOOP / n
    tw, th = int((view[2] - view[0]) * z), int((view[3] - view[1]) * z)
    hd = header(tw * 2 + 4, "Silahların takip animasyonu  ·  %s" % ("oyun ölçeği (1080p), gerçek hız" if z == 2 else "x2 yakın (kafa üstü), gerçek hız"),
                "dur · sağ · dur · yukarı · sol + keskin dönüş aşağı · kısa sağ-sol kaçış · dur  (%.1f sn döngü)" % LOOP)
    frames = []
    for k in range(n):
        t = k * dt
        tiles = []
        for cls, rec in sims:
            im = render(rec, t, z, view)
            tile_label(im, cls, small)
            tiles.append(im)
        lines = [(ln % fps) if "%d" in ln else ln for ln in INFO]
        info = info_tile(tw, th, lines if not small else lines[:3], "Takip")
        d = ImageDraw.Draw(info)
        label(d, 10, th - 22, "%.2f sn · %s" % (t, phase_name(t)), 12, (255, 214, 120))
        tiles.append(info)
        frames.append(stack_v([hd, grid(tiles, 2)]))
    os.makedirs(OUT, exist_ok=True)
    marks = [int(1.0 / dt), int(2.2 / dt), int(4.0 / dt)]
    save_gif(frames, os.path.join(OUT, name + ".gif"), 1.0 / dt, marks)
    return frames, dt


STRIP_T = [0.45, 0.75, 1.40, 1.58, 1.68, 1.85, 2.40, 3.20, 3.75, 4.20]


def build_strip(z=3, view=(-60.0, -82.0, 60.0, 18.0)):
    """Satır = yön, sütun = an (durma/keskin dönüş çevresi)."""
    sims = [(cls, simulate(cls)[1]) for cls in DIRS]
    rows = []
    tw = int((view[2] - view[0]) * z)
    for cls, rec in sims:
        cells = []
        for t in STRIP_T:
            im = render(rec, t, z, view)
            d = ImageDraw.Draw(im)
            label(d, 4, 2, "%.2f %s" % (t, phase_name(t)), 10)
            cells.append(im)
        row = Image.new("RGB", (len(cells) * (tw + 2), cells[0].height + 18), (30, 34, 32))
        label(ImageDraw.Draw(row), 4, 2, cls.title, 12)
        for j, c in enumerate(cells):
            row.paste(c, (j * (tw + 2), 18))
        rows.append(row)
    os.makedirs(OUT, exist_ok=True)
    stack_v(rows).save(os.path.join(OUT, "takip_kareler.png"))


if __name__ == "__main__":
    what = sys.argv[1:] or ["oyun", "yakin", "kareler"]
    if "kareler" in what:
        build_strip()
    if "oyun" in what:
        fr, dt = build(2, (-90.0, -92.0, 90.0, 30.0), "takip_oyun", False, FPS)
        fr[int(1.3 / dt)].save(os.path.join(OUT, "takip_kare.png"))
    if "yakin" in what:
        build(4, (-52.0, -84.0, 52.0, 20.0), "takip_yakin", True, 25)
