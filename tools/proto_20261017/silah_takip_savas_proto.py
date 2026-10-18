# -*- coding: utf-8 -*-
"""Süzülen silahların takip animasyonu - SAVAŞ HİSSİ prototipleri E-H (2026-10-17, oyuna bağlı DEĞİL). Kullanıcı: "4 prototip daha
üret savaş hissiyatı uyandıran" (ilk set A-D: silah_takip_proto.py, madde 238).

Sahne ilk setle aynı yürüyüş + 3 duran slime (sağda, sol üstte, sol altta): yürüyüş boyunca en yakın düşman değişir
(alt-sol -> sağ -> üst-sol -> alt-sol). Menzilli silahlar (Ateş Asası, Tabanca) OYUNDAKİ GİBİ en yakın düşmana döner
(weapon.gd _update_aim: lerp_angle 12/sn, Tabanca solda aynalanır) - ŞU AN dahil her şeritte; atış yok.
  E Hücum          - yürürken silahlar gidiş yönüne öne çıkar (tepe 9 px, yanlar 5 px; yatay yürüyüşte tepe 6 px alçalır), Uzunkılıç
                     ucunu mızrak gibi gidiş yönüne indirir, arkalarında 2 rüzgâr çizgisi; durunca sert fren: yay geri teper,
                     kılıç ucunda parıltı.
  F Kılıç Çemberi  - silahlar kafanın üstünden iner, göğüs hizasında 68 x 30 elips çemberde döner (1,9 sn'de bir tur), Uzunkılıç
                     ucu dışarı bakar; arkadakiler karakterin ARKASINDA (küçük, koyu), öndekiler önünde; gölgeler ayak çevresinde.
  G Savaş Davulu   - karaktere kilitli; her ayak basışında ÜÇÜ BİRDEN ağır vuruş: yavaş kalkar (4 px), hızla iner, inişte ezilme +
                     metal parlaması + gölge koyulaşır, adım adım ±5 derece; dururken 1,43 sn'de bir çift "kalp atışı" (büyü-sön + titreme).
  H Tetikte        - dizilim en yakın düşmana doğru 5 px gerilir (yakınlaştıkça daha çok), Uzunkılıç da ucunu düşmana çevirir, sinirli
                     1 ekran px titreme (10 Hz); hedef değişince yayla savrulup döner + kısa beyaz parlama (kilitlenme).

Çıktılar (out/silah_takip/): savas_oyun.gif (1080p, gerçek hız, ŞU AN + E-H + bilgi), savas_yakin.gif (x2 yakın, 25 fps),
savas_kareler.png, savas_kare.png.
Çalıştırma: python tools/proto_20261017/silah_takip_savas_proto.py [oyun|yakin|kareler]   (argümansız: hepsi)
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import silah_takip_proto as T  # noqa: E402  (yürüyüş, yaylar, çizici, GIF)
from silah_takip_proto import (DT, SPEED, SLOTS, SLOTS_LOCAL, WEAPONS, CUR_PHASES, BOB_W, LOOP, START, Spring2,  # noqa: E402
                               clamp, half_px, hover_shadow_gap, cur_shadow_radii)

D2R = math.pi / 180.0
ENEMIES = [(START[0] + 165.0, START[1] - 15.0), (START[0] - 60.0, START[1] - 105.0), (START[0] - 70.0, START[1] + 28.0)]
FWD = [-45.0, -45.0, 0.0]  # weapon_tier_art.gd FORWARD: uzunkilic, fire_staff, tabanca (sprite_forward_angle_deg)
RANGED = [False, True, True]
MIRROR = [False, False, True]  # weapon_tabanca.tscn mirror_icon_when_aiming_left
AIM_RATE = 12.0  # weapon.gd AIM_EASE_RATE
CREAM = (255, 246, 220)
GLINT = (255, 252, 232)


def ang_diff(a, b):
    """b - a, (-180, 180] derece."""
    d = (b - a + 180.0) % 360.0 - 180.0
    return 180.0 if d == -180.0 else d


def lerp_ang(a, b, f):
    return a + ang_diff(a, b) * f


def nearest(P):
    return min(range(len(ENEMIES)), key=lambda k: (ENEMIES[k][0] - P[0]) ** 2 + (ENEMIES[k][1] - P[1]) ** 2)


class Aim:
    """weapon.gd _update_aim taklidi: en yakın düşmana lerp_angle; aynalanan ikon solda flip_h + (açı - PI + ileri)."""

    def __init__(self):
        self.rot = [w[1] for w in WEAPONS]
        self.flip = [False] * 3

    def step(self, i, pos, P, rate=AIM_RATE, extra=0.0):
        e = ENEMIES[nearest(P)]
        a = math.degrees(math.atan2(e[1] - pos[1], e[0] - pos[0]))
        if MIRROR[i]:
            fl = e[0] - pos[0] < 0.0
            tgt = (a - 180.0 + FWD[i]) if fl else (a - FWD[i])
            if fl != self.flip[i]:
                self.rot[i] = tgt
                self.flip[i] = fl
            else:
                self.rot[i] = lerp_ang(self.rot[i], tgt, clamp(DT * rate, 0.0, 1.0))
        else:
            self.rot[i] = lerp_ang(self.rot[i], a - FWD[i], clamp(DT * rate, 0.0, 1.0))
        return self.rot[i] + (-extra if self.flip[i] else extra), self.flip[i]


def tip_offset(rot_deg, fwd_deg, r=10.0):
    a = (rot_deg + fwd_deg) * D2R
    return (math.cos(a) * r, math.sin(a) * r)


# ------------------------------------------------------------------ ŞU AN (+ nişan)
class CurAim(T.Cur):
    sub = "lerp 9·dt, 10 px sınır · menzilliler en yakın düşmana nişan"

    def __init__(self):
        super().__init__()
        self.aim = Aim()

    def tick(self, st):
        res = super().tick(st)
        for i, w in enumerate(res):
            if RANGED[i]:
                w["rot"], w["flip"] = self.aim.step(i, w["pos"], st["P"])
        return res


# ------------------------------------------------------------------ E Hücum
class DirE:
    title = "E · Hücum"
    sub = "öne çıkar, kılıç mızrak gibi iner · rüzgâr çizgisi · fren + parıltı"

    def __init__(self):
        self.sp = [Spring2(13.0, 0.45), Spring2(11.0, 0.45), Spring2(11.0, 0.45)]
        self.aim = Aim()
        self.was_moving = False
        self.t_stop = -9.0

    def tick(self, st):
        P, t = st["P"], st["t"]
        if self.was_moving and not st["moving"]:
            self.t_stop = t
        self.was_moving = st["moving"]
        vx, vy = st["V"]
        res = []
        for i in range(3):
            w = self.sp[i].step((vx / SPEED, vy / SPEED))
            m = min(1.2, math.hypot(w[0], w[1]))
            bob = math.sin(t * BOB_W + CUR_PHASES[i]) * 1.75 * (1.0 - min(1.0, m) * 0.7)
            push = 9.0 if i == 0 else 5.0
            low = 6.0 * min(1.0, abs(w[0])) if i == 0 else 0.0
            pos = (half_px(P[0] + SLOTS[i][0] + w[0] * push), half_px(P[1] + SLOTS[i][1] + w[1] * push + low + bob))
            fx = []
            if RANGED[i]:
                rot, flip = self.aim.step(i, pos, P)
            else:
                flip = False
                head = math.degrees(math.atan2(w[1], w[0])) if m > 1e-4 else -90.0
                d = ang_diff(-90.0, head)
                if abs(d) >= 179.9:
                    d = 180.0
                rot = WEAPONS[i][1] + d * min(1.0, m)
                ts = t - self.t_stop
                if 0.06 <= ts < 0.34:
                    k = math.sin(math.pi * (ts - 0.06) / 0.28)
                    tx, ty = tip_offset(rot, FWD[i], 11.0)
                    fx.append(("star", tx, ty, 2.0 + 3.5 * k, GLINT, 0.95 * k))
            if m > 0.5:
                dn = (w[0] / m, w[1] / m)
                pr = (-dn[1], dn[0])
                al = 0.4 * clamp((m - 0.5) / 0.4, 0.0, 1.0)
                for j, side in enumerate((-1.0, 1.0)):
                    b0 = 11.0 + j * 3.0
                    L = 4.0 + 3.0 * m
                    ox, oy = pr[0] * side * (4.0 + j * 2.0), pr[1] * side * (4.0 + j * 2.0)
                    fx.append(("line", -dn[0] * b0 + ox, -dn[1] * b0 + oy, -dn[0] * (b0 + L) + ox, -dn[1] * (b0 + L) + oy, CREAM, al))
            rx, ry = cur_shadow_radii(WEAPONS[i][0], 0.0)
            gap = hover_shadow_gap(SLOTS_LOCAL[i][1])
            res.append({"pos": pos, "rot": rot, "flip": flip, "fx": fx, "sh": (pos[0], pos[1] - bob - low + gap, rx, ry)})
        return res


# ------------------------------------------------------------------ F Kılıç Çemberi
class DirF:
    title = "F · Kılıç Çemberi"
    sub = "göğüs hizasında dönen çember (1,9 sn/tur) · uçlar dışarı · önde/arkada"
    RX, RY = 34.0, 15.0
    H = 20.0  # çemberin yerden yüksekliği (ekranda ayak +12'den yukarı)

    def __init__(self):
        self.sp = Spring2(12.0, 0.6)
        self.aim = Aim()

    def tick(self, st):
        P, t = st["P"], st["t"]
        Tg = (P[0], P[1] + 12.0)
        self.sp.step(Tg)
        self.sp.limit(Tg, 5.0)
        g = self.sp.x
        bob = math.sin(t * BOB_W) * 1.5
        base = 3.0 * 2.0 * math.pi * t / LOOP
        res = []
        for i in range(3):
            ph = base + i * 2.0 * math.pi / 3.0
            c, s = math.cos(ph), math.sin(ph)
            gx, gy = g[0] + self.RX * c, g[1] + self.RY * s
            pos = (half_px(gx), half_px(gy - self.H + bob))
            sc = 0.92 + 0.08 * (s + 1.0) / 2.0
            if RANGED[i]:
                rot, flip = self.aim.step(i, pos, P)
            else:
                flip = False
                rot = math.degrees(math.atan2(self.RY * s, self.RX * c)) - FWD[i]
            rx, ry = cur_shadow_radii(WEAPONS[i][0], 0.0)
            res.append({"pos": pos, "rot": rot, "flip": flip, "sx": sc, "sy": sc, "depth": s,
                        "mul": 0.8 + 0.2 * (s + 1.0) / 2.0, "sh": (gx, gy, rx * sc, ry * sc)})
        return res


# ------------------------------------------------------------------ G Savaş Davulu
class DirG:
    title = "G · Savaş Davulu"
    sub = "her adımda üçü birden ağır iner (ezilme + parlama) · dururken kalp atışı"
    STEP_T = 3.0 / 8.0
    LIFT = 4.0
    BEAT = LOOP / 4.0

    def __init__(self):
        self.wf = 0.0
        self.aim = Aim()

    @staticmethod
    def _slam(u):
        """Adım içi yükseklik (0 = iniş anı): 0,12'ye kadar dipte, sonra yavaş kalkış, son %15'te hızlı iniş."""
        if u < 0.12:
            return -0.8 * (1.0 - u / 0.12)  # inişte 0,8 px aşağı teper
        if u < 0.85:
            x = (u - 0.12) / 0.73
            return 1.0 - (1.0 - x) * (1.0 - x)
        x = (u - 0.85) / 0.15
        return 1.0 - x * x * x

    def tick(self, st):
        P, t = st["P"], st["t"]
        self.wf = clamp(self.wf + (DT / 0.08 if st["moving"] else -DT / 0.2), 0.0, 1.0)
        wf = self.wf
        res = []
        h, sq, flash, rock = 0.0, 1.0, 0.0, 0.0
        if st["moving"]:
            wt = st["walk_t"]
            n = int(wt / self.STEP_T)
            u = wt / self.STEP_T - n
            h = self.LIFT * self._slam(u)
            if u < 0.10:
                sq = 0.86 + 0.14 * (u / 0.10)
                flash = 0.5 * (1.0 - u / 0.10)
            rock = 5.0 * max(0.0, h / self.LIFT) * (1.0 if n % 2 == 0 else -1.0)
        # kalp atışı (dururken): çeyrek döngüde bir "güm-güm"
        bp = (t % self.BEAT)
        beat = math.exp(-((bp - 0.0) / 0.05) ** 2) + 0.7 * math.exp(-((bp - 0.22) / 0.05) ** 2) + math.exp(-((bp - self.BEAT) / 0.05) ** 2)
        idle_s = 1.0 + 0.07 * beat * (1.0 - wf)
        trem = 0.0
        for i in range(3):
            base_y = P[1] + SLOTS[i][1] - 1.0 * min(1.0, beat) * (1.0 - wf)  # atışta 1 px kalkar
            pos = (half_px(P[0] + SLOTS[i][0] + trem), half_px(base_y - h * wf))
            if RANGED[i]:
                rot, flip = self.aim.step(i, pos, P, extra=rock * wf)
            else:
                rot, flip = WEAPONS[i][1] + rock * wf, False
            sx = (1.0 / sq) * idle_s
            sy = sq * idle_s
            rx, ry = cur_shadow_radii(WEAPONS[i][0], 0.0)
            k = 1.0 - max(0.0, h * wf) / 12.0
            gy = P[1] + SLOTS[i][1] + hover_shadow_gap(SLOTS_LOCAL[i][1])
            res.append({"pos": pos, "rot": rot, "flip": flip, "sx": sx, "sy": sy, "flash": flash * wf,
                        "sh": (pos[0], gy, rx * k * (1.0 + 0.25 * (1.0 - sq) / 0.14), ry * k)})
        return res


# ------------------------------------------------------------------ H Tetikte
class DirH:
    title = "H · Tetikte"
    sub = "dizilim düşmana gerilir, kılıç da hedefte · sinirli titreme · kilitlenme parlaması"

    def __init__(self):
        self.sp = Spring2(14.0, 0.42, absolute=False)
        self.aim = Aim()
        self.sword = WEAPONS[0][1]
        self.sword_v = 0.0
        self.target = None
        self.t_switch = -9.0

    def tick(self, st):
        P, t = st["P"], st["t"]
        k = nearest(P)
        if self.target is not None and k != self.target:
            self.t_switch = t
        self.target = k
        e = ENEMIES[k]
        dx, dy = e[0] - P[0], e[1] - (P[1] - 40.0)
        dist = math.hypot(dx, dy)
        close = clamp((200.0 - dist) / 120.0, 0.35, 1.0)
        lean_t = (dx / dist * 5.0 * close, dy / dist * 4.0 * close)
        self.sp.step(lean_t)
        lean = self.sp.x
        ts = t - self.t_switch
        flash = 0.75 * (1.0 - ts / 0.08) if 0.0 <= ts < 0.08 else 0.0
        res = []
        for i in range(3):
            bob = math.sin(t * BOB_W + CUR_PHASES[i]) * 0.8
            # sinirli titreme: 10 Hz'de ±0,5 dünya px (1 ekran px), sadece yakındayken
            h = (int(t * 10.0) * 7 + i * 13) % 5
            jx = ((h % 3) - 1) * 0.5 * (1.0 if close > 0.6 else (1 if h == 0 else 0))
            jy = (((h // 2) % 3) - 1) * 0.5 * (1.0 if close > 0.6 else 0.0)
            pos = (half_px(P[0] + SLOTS[i][0] + lean[0] + jx), half_px(P[1] + SLOTS[i][1] + lean[1] + bob + jy))
            if RANGED[i]:
                rot, flip = self.aim.step(i, pos, P)
            else:
                flip = False
                a = math.degrees(math.atan2(e[1] - pos[1], e[0] - pos[0])) - FWD[i]
                # açısal yay: hedef değişince savrulup oturur
                acc = 260.0 * ang_diff(self.sword, a) - 2.0 * 0.38 * math.sqrt(260.0) * self.sword_v
                self.sword_v += acc * DT
                self.sword += self.sword_v * DT
                rot = self.sword
            rx, ry = cur_shadow_radii(WEAPONS[i][0], 0.0)
            gap = hover_shadow_gap(SLOTS_LOCAL[i][1])
            res.append({"pos": pos, "rot": rot, "flip": flip, "flash": flash, "sh": (pos[0], pos[1] - bob + gap, rx, ry)})
        return res


DIRS = [CurAim, DirE, DirF, DirG, DirH]

INFO = [
    "Şovalye + Uzunkılıç (tepe), Ateş Asası (sağ), Tabanca (sol)",
    "3 duran slime: en yakın düşman yürüdükçe değişir",
    "fizik 60 Hz + interpolasyon, GIF %d fps",
    "menzilliler oyundaki gibi en yakın düşmana nişan alır",
    "  (lerp 12/sn, Tabanca solda aynalanır) - atış yok",
    "E/F/H'de Uzunkılıç da harekete/çembere/düşmana döner",
    "  (oyunda yakın dövüş silahı dinlenme pozunda durur)",
    "kamera oyuncuya kilitli, yürüyüş 82 px/sn",
]
STRIP_T = [0.45, 1.00, 1.40, 1.58, 1.70, 2.40, 3.20, 3.75, 4.20, 5.30]

if __name__ == "__main__":
    what = sys.argv[1:] or ["oyun", "yakin", "kareler"]
    kw = dict(dirs=DIRS, enemies=ENEMIES, title="Takip · savaş hissi", info=INFO, info_title="Savaş hissi")
    if "kareler" in what:
        T.build_strip(dirs=DIRS, enemies=ENEMIES, fname="savas_kareler.png", times=STRIP_T)
    if "oyun" in what:
        fr, dt = T.build(2, (-90.0, -92.0, 90.0, 30.0), "savas_oyun", False, T.FPS, **kw)
        fr[int(1.3 / dt)].save(os.path.join(T.OUT, "savas_kare.png"))
    if "yakin" in what:
        T.build(4, (-52.0, -84.0, 52.0, 20.0), "savas_yakin", True, 25, **kw)
