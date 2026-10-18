# -*- coding: utf-8 -*-
"""E "Hücum" v2 PROTOTİPİ (2026-10-17, oyuna bağlı DEĞİL). Kullanıcı (madde 244'ten E'yi seçti): "hız çizgileri daha iyi olabilir
güncelleyip göster öyle ekleyelim. ayrıca silahların ucu asaların ucu v.b de gidilen yöne bakmalı (ters yöne koşarken ateş
ediyorlarsa öyle olmamalı ama) ayrıca karakterin kendi görüş alanında yani yakınında düşman yoksa silahları içine doğru gelip
görünmesinler. düşman görünce de havalı bir şekilde çıkıp savaşa hazır dursunlar".

Kurallar (her silah, her fizik karesi):
  - Görüş elipsinde (vision_fog.gd VISION_RADIUS 250 x VISION_WIDTH_SCALE 1,4 = 350 x 250) yaşayan düşman YOK -> silahlar karakterin
    göğsüne doğru dönerek küçülüp çekilir, görünmez (gölge dahil). VAR -> göğüsten fırlayıp yay çizerek yerine gider, 1 tur döner,
    büyüyüp oturur, ucunda "şing" parıltısı (sırayla: tepe, sağ, sol).
  - Silah ÇATIŞMADA (hedef kendi menzilinde: Tabanca 210, Ateş Asası 168, Uzunkılıç ~120) -> ucu hedefe (oyundaki nişan), koşu
    yönünden bağımsız (kaçarken geriye ateş).
  - Çatışmada değil + yürüyor -> ucu GİDİŞ YÖNÜNE (asa ucu, namlu, kılıç ucu; Tabanca solda aynalanır).
  - Çatışmada değil + duruyor -> "hazır": ucu en yakın görünen düşmana.
  - Hücum konumu madde 244 E ile aynı (öne 9/5 px, yatayda tepe 6 px alçalır, durunca yay geri teper + kılıç ucunda parıltı).
Hız çizgisi varyantları (sadece görünürken ve hız yayı > 0,5):
  A Sivri İz       - silahın arkasından (gövde ucundan) çıkan 2 sivrilen iz, GERÇEK geçmiş konumdan (dönüşte kıvrılır), kalın -> ince,
                     Bayer ile kırılarak söner (yumuşak saydamlık yok, piksel)
  B Ardıl Görüntü  - silahın 3 soğuk tonlu hayaleti (0,06 / 0,12 / 0,18 sn önceki konum ve açı), azalan saydamlık
  C Hava Yarığı    - ucun önünde havayı yaran küçük ok başı (V) + gövde ucundan tek ince iz
Sahne: köprünün kuzeyi; sağdan yaklaşan 1 slime (60 px/sn), 3. isabette ölür. Atış: Tabanca 0,9444/0,7 sn, Ateş Asası 1,4444/0,7 sn
(basit mermi + namlu parıltısı + 2 px tepme; gerçek mermi sanatı değil).
Çıktılar (out/silah_takip/): hucum_oyun.gif (1080p ölçek, gerçek hız: A/B/C + durum haritası), hucum_yakin.gif (x2 yakın, 25 fps),
hucum_kareler.png.  Çalıştırma: python tools/proto_20261017/silah_hucum_proto.py [oyun|yakin|kareler]
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import silah_takip_proto as T  # noqa: E402
from silah_takip_proto import (DT, TICK, SPEED, SLOTS, SLOTS_LOCAL, WEAPONS, CUR_PHASES, BOB_W, Spring2, clamp, half_px,  # noqa: E402
                               hover_shadow_gap, cur_shadow_radii, blit2, ellipse, line_w, star, icon_np, slime_frame,
                               SLIME_K, WPP, CHAR_K, CHAR_OFF_Y)
from mermi_proto import label, BAY  # noqa: E402
from bicak_proto import header, stack_v, save_gif  # noqa: E402

OUT = T.OUT
D2R = math.pi / 180.0
FPS = 50
LOOP = 2.0 * (2.0 * math.pi / BOB_W)  # 5,71 sn (salınım dikişsiz)
START = (265.0, 150.0)  # kopru_oyun_A.png: köprünün kuzeyindeki sakin çimen
PATH = [(0.5, None), (1.5, (1, 0)), (1.0, None), (1.5, (-1, 0))]
PATH.append((LOOP - sum(p[0] for p in PATH), None))

VIS_RX, VIS_RY = 350.0, 250.0  # vision_fog.gd
RANGE = [120.0, 168.0, 210.0]  # Uzunkılıç (yakın dövüş ~), weapon_fire.tscn, weapon_tabanca.tscn attack_range
FIRE_INT = [None, 1.4444 / 0.7, 0.9444 / 0.7]
PROJ_V = [0.0, 260.0, 520.0]
FWD = [-45.0, -45.0, 0.0]
MIRROR = [False, False, True]
SLIME_X0, SLIME_Y, SLIME_V = 465.0, -8.0, 60.0
HITS_TO_KILL = 3
CHEST = (0.0, -8.0)
REVEAL_T, REVEAL_STAG = 0.42, [0.0, 0.07, 0.14]
RETRACT_T, RETRACT_STAG = 0.30, [0.08, 0.04, 0.0]
TURN_RATE = 14.0
GLINT = (255, 252, 232)
STREAK = (246, 242, 228)
GHOST = (206, 226, 255)


def ang_diff(a, b):
    d = (b - a + 180.0) % 360.0 - 180.0
    return 180.0 if d == -180.0 else d


def lerp_ang(a, b, f):
    return a + ang_diff(a, b) * f


def ease_out_back(x, s=1.9):
    x -= 1.0
    return 1.0 + (s + 1.0) * x ** 3 + s * x ** 2


def ease_out(x, p=3):
    return 1.0 - (1.0 - x) ** p


def ease_in(x, p=3):
    return x ** p


# ------------------------------------------------------------------ yürüyüş
def player_track():
    n = int(round(LOOP * TICK))
    out, x, face, walk_t, prev = [], 0.0, (0, 1), 0.0, None
    for i in range(n):
        t = i * DT
        acc, d = 0.0, None
        for dur, dd in PATH:
            if t < acc + dur - 1e-9:
                d = dd
                break
            acc += dur
        if d is not None:
            if d != prev:
                walk_t = 0.0
            face = d
        vx = d[0] * SPEED if d else 0.0
        out.append({"t": t, "P": (START[0] + x, START[1]), "V": (vx, 0.0), "moving": d is not None, "face": face, "walk_t": walk_t})
        x += vx * DT
        walk_t = walk_t + DT if d is not None else 0.0
        prev = d
    return out


TRACK = player_track()


def phase_name(t):
    acc = 0.0
    for dur, d in PATH:
        if t < acc + dur:
            return "duruyor" if d is None else {(1, 0): "sağa yürüyor", (-1, 0): "sola kaçıyor"}[d]
        acc += dur
    return "duruyor"


# ------------------------------------------------------------------ simülasyon
class Sim:
    """Tek simülasyon; varyantlar sadece çizimde ayrılır."""

    def __init__(self):
        self.sp = [Spring2(13.0, 0.45), Spring2(11.0, 0.45), Spring2(11.0, 0.45)]
        self.rot = [w[1] for w in WEAPONS]
        self.flip = [False] * 3
        self.state = "hidden"
        self.t_state = -9.0
        self.cool = [0.0, 0.0, 0.0]
        self.kick = [0.0, 0.0, 0.0]
        self.muzzle = [-9.0] * 3
        self.was_moving = False
        self.t_stop = -9.0
        self.proj = []
        self.reset_slime()

    def reset_slime(self):
        self.hits, self.t_dead, self.t_flash = 0, None, -9.0

    def slime_pos(self, t):
        return (START[0] + SLIME_X0 - SLIME_V * t, START[1] + SLIME_Y)

    def tick(self, st):
        P, t = st["P"], st["t"]
        if t < 1e-9:
            self.reset_slime()
            self.proj = []
        alive = self.t_dead is None
        E = self.slime_pos(t)
        dx, dy = E[0] - P[0], E[1] - P[1]
        seen = alive and (dx / VIS_RX) ** 2 + (dy / VIS_RY) ** 2 <= 1.0
        if seen and self.state in ("hidden", "retract"):
            self.state, self.t_state = "reveal", t
        elif not seen and self.state in ("shown", "reveal"):
            self.state, self.t_state = "retract", t
        ts = t - self.t_state
        if self.state == "reveal" and ts > REVEAL_T + max(REVEAL_STAG):
            self.state = "shown"
        if self.state == "retract" and ts > RETRACT_T + max(RETRACT_STAG):
            self.state = "hidden"
        if self.was_moving and not st["moving"]:
            self.t_stop = t
        self.was_moving = st["moving"]

        vx, vy = st["V"]
        chest = (P[0] + CHEST[0], P[1] + CHEST[1])
        ws = []
        for i in range(3):
            w = self.sp[i].step((vx / SPEED, vy / SPEED))
            m = min(1.2, math.hypot(w[0], w[1]))
            bob = math.sin(t * BOB_W + CUR_PHASES[i]) * 1.75 * (1.0 - min(1.0, m) * 0.7)
            push = 9.0 if i == 0 else 5.0
            low = 6.0 * min(1.0, abs(w[0])) if i == 0 else 0.0
            home = (P[0] + SLOTS[i][0] + w[0] * push, P[1] + SLOTS[i][1] + w[1] * push + low + bob)
            # --- yön kuralı
            dist = math.hypot(E[0] - home[0], E[1] - home[1])
            engaged = seen and dist <= RANGE[i]
            if engaged or (seen and not st["moving"]):
                a = math.degrees(math.atan2(E[1] - home[1], E[0] - home[0]))
                mode = "ateş" if engaged and FIRE_INT[i] else ("menzilde" if engaged else "hazır")
            elif st["moving"]:
                a = math.degrees(math.atan2(vy, vx))
                mode = "gidiş yönü"
            else:
                a = None
                mode = "bekliyor"
            if a is not None:
                if MIRROR[i]:
                    fl = math.cos(a * D2R) < -1e-6
                    tgt = (a - 180.0 + FWD[i]) if fl else (a - FWD[i])
                    if fl != self.flip[i]:
                        self.rot[i], self.flip[i] = tgt, fl
                    else:
                        self.rot[i] = lerp_ang(self.rot[i], tgt, clamp(DT * TURN_RATE, 0.0, 1.0))
                else:
                    self.rot[i] = lerp_ang(self.rot[i], a - FWD[i], clamp(DT * TURN_RATE, 0.0, 1.0))
            rot, flip = self.rot[i], self.flip[i]
            # --- atış (sadece görünür + menzilde)
            self.cool[i] = max(0.0, self.cool[i] - DT)
            visible_now = self.state in ("shown", "reveal") and ts > REVEAL_STAG[i] + REVEAL_T * 0.8 if self.state == "reveal" else self.state == "shown"
            if engaged and FIRE_INT[i] and visible_now and self.cool[i] <= 0.0:
                self.cool[i] = FIRE_INT[i]
                aim = (rot + FWD[i] if not flip else rot + 180.0 - FWD[i]) * D2R
                tip = (home[0] + math.cos(aim) * 11.0, home[1] + math.sin(aim) * 11.0)
                self.proj.append({"k": i, "x": tip[0], "y": tip[1]})
                self.muzzle[i] = t
                self.kick[i] = 1.0
            self.kick[i] = max(0.0, self.kick[i] - DT / 0.1)
            if self.kick[i] > 0.0:
                aim = (rot + FWD[i] if not flip else rot + 180.0 - FWD[i]) * D2R
                home = (home[0] - math.cos(aim) * 2.0 * self.kick[i], home[1] - math.sin(aim) * 2.0 * self.kick[i])
            # --- görünürlük animasyonu
            sc, alpha, spin, pos = 1.0, 1.0, 0.0, home
            if self.state == "hidden":
                alpha = 0.0
            elif self.state == "reveal":
                u = clamp((ts - REVEAL_STAG[i]) / REVEAL_T, 0.0, 1.0)
                if u <= 0.0:
                    alpha = 0.0
                else:
                    e = ease_out(u, 3)
                    ctrl = (chest[0] + SLOTS[i][0] * 1.3, chest[1] + SLOTS[i][1] * 0.35 - 6.0)
                    q = 1.0 - e
                    pos = (q * q * chest[0] + 2 * q * e * ctrl[0] + e * e * home[0], q * q * chest[1] + 2 * q * e * ctrl[1] + e * e * home[1])
                    sc = 0.25 + 0.75 * ease_out_back(u)
                    spin = (1.0 if i != 2 else -1.0) * 360.0 * (1.0 - ease_out(u, 4))
                    alpha = min(1.0, u / 0.12)
            elif self.state == "retract":
                u = clamp((ts - RETRACT_STAG[i]) / RETRACT_T, 0.0, 1.0)
                e = ease_in(u, 3)
                pos = (home[0] + (chest[0] - home[0]) * e, home[1] + (chest[1] - home[1]) * e)
                sc = 1.0 - 0.8 * e
                spin = -220.0 * e * (1.0 if i != 2 else -1.0)
                alpha = 1.0 - clamp((u - 0.55) / 0.45, 0.0, 1.0)
            fx = []
            # namlu parıltısı
            mt = t - self.muzzle[i]
            if 0.0 <= mt < 0.07 and alpha > 0.0:
                aim = (rot + FWD[i] if not flip else rot + 180.0 - FWD[i]) * D2R
                col = (255, 176, 64) if i == 1 else (255, 244, 190)
                fx.append(("star", math.cos(aim) * 13.0, math.sin(aim) * 13.0, 3.5 * (1.0 - mt / 0.07) + 1.0, col, 0.95))
            # çıkış "şing" parıltısı + beyaz parlama
            flash = 0.0
            if self.state in ("reveal", "shown"):
                rt = ts - REVEAL_STAG[i] - REVEAL_T * 0.78
                if 0.0 <= rt < 0.2 and ts < REVEAL_T + 0.6:
                    k = math.sin(math.pi * rt / 0.2)
                    aim = (rot + FWD[i] if not flip else rot + 180.0 - FWD[i]) * D2R
                    fx.append(("star", math.cos(aim) * 11.0, math.sin(aim) * 11.0, 1.5 + 4.0 * k, GLINT, k))
                    flash = 0.55 * max(0.0, 1.0 - rt / 0.1)
            # fren parıltısı (madde 244 E): durunca kılıç ucunda
            if i == 0 and self.state == "shown":
                tsp = t - self.t_stop
                if 0.06 <= tsp < 0.34:
                    k = math.sin(math.pi * (tsp - 0.06) / 0.28)
                    aim = (rot + FWD[0]) * D2R
                    fx.append(("star", math.cos(aim) * 11.0, math.sin(aim) * 11.0, 1.5 + 3.0 * k, GLINT, 0.9 * k))
            rx, ry = cur_shadow_radii(WEAPONS[i][0], 0.0)
            home_gy = home[1] - bob - low + hover_shadow_gap(SLOTS_LOCAL[i][1])
            feet = P[1] + 12.0
            if self.state == "reveal":
                gy = feet + (home_gy - feet) * ease_out(clamp((ts - REVEAL_STAG[i]) / REVEAL_T, 0.0, 1.0), 3)
            elif self.state == "retract":
                gy = home_gy + (feet - home_gy) * ease_in(clamp((ts - RETRACT_STAG[i]) / RETRACT_T, 0.0, 1.0), 3)
            else:
                gy = home_gy
            ws.append({"pos": (half_px(pos[0]), half_px(pos[1])), "rot": rot + spin, "flip": flip, "sx": sc, "sy": sc,
                       "alpha": alpha, "flash": flash, "fx": fx, "sh": (pos[0], gy, rx * sc, ry * sc), "m": m,
                       "w": w, "mode": mode if alpha > 0.0 else "gizli"})
        # mermiler
        keep = []
        for p in self.proj:
            if self.t_dead is not None:
                continue
            ex, ey = self.slime_pos(t)
            ex, ey = ex, ey - 6.0
            ddx, ddy = ex - p["x"], ey - p["y"]
            L = math.hypot(ddx, ddy)
            step = PROJ_V[p["k"]] * DT
            if L <= step:
                self.hits += 1
                self.t_flash = t
                if self.hits >= HITS_TO_KILL:
                    self.t_dead = t
                continue
            p["x"] += ddx / L * step
            p["y"] += ddy / L * step
            p["dx"], p["dy"] = ddx / L, ddy / L
            keep.append(p)
        self.proj = keep
        chest_fx = []
        if self.state == "reveal" and ts < 0.12:
            chest_fx.append(("star", chest[0], chest[1], 2.0 + 3.0 * math.sin(math.pi * ts / 0.12), GLINT, 0.9))
        if self.state in ("retract", "hidden") and RETRACT_T + 0.08 <= ts < RETRACT_T + 0.24:
            k = math.sin(math.pi * (ts - RETRACT_T - 0.08) / 0.16)
            chest_fx.append(("star", chest[0], chest[1], 1.0 + 2.5 * k, GLINT, 0.8 * k))
        return {"ws": ws, "slime": {"pos": E, "dead": self.t_dead, "flash": self.t_flash, "seen": seen},
                "proj": [dict(p) for p in self.proj], "chest_fx": chest_fx, "state": self.state}


def simulate():
    s = Sim()
    for _ in range(2):
        rec = [s.tick(st) for st in TRACK]
    return rec


# ------------------------------------------------------------------ örnekleme (fizik interpolasyonu)
def lerp2(a, b, f):
    return (a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f)


def sample(rec, t):
    n = len(TRACK)
    ft = (t % LOOP) * TICK
    i0 = int(ft) % n
    i1 = (i0 + 1) % n
    f = ft - int(ft)
    p1 = TRACK[i1]["P"] if i1 != 0 else (START[0], START[1])
    P = lerp2(TRACK[i0]["P"], p1, f)
    A, B = rec[i0], rec[i1]
    ws = []
    for a, b in zip(A["ws"], B["ws"]):
        w = dict(a)
        w["pos"] = lerp2(a["pos"], b["pos"], f)
        if a["flip"] != b["flip"]:
            src = a if f < 0.5 else b
            w["rot"], w["flip"] = src["rot"], src["flip"]
        else:
            w["rot"] = a["rot"] + ang_diff(a["rot"], b["rot"]) * f
        for k in ("sx", "sy", "alpha"):
            w[k] = a[k] + (b[k] - a[k]) * f
        w["sh"] = tuple(a["sh"][j] + (b["sh"][j] - a["sh"][j]) * f for j in range(4))
        ws.append(w)
    return P, TRACK[i0], A, ws


# ------------------------------------------------------------------ çizim
BAYF = (np.array(BAY, np.float32) + 0.5) / 16.0


def dither_trail(F, pts, col):
    """pts: [(x, y, kalınlık_px, a)] ekran; ardışık noktalar arası kalınlık/saydamlık doğrusal, Bayer eşiği (piksel, yarı saydam yok)."""
    H, W = F.shape[:2]
    c = np.array(col, np.float32)
    for (x0, y0, w0, a0), (x1, y1, w1, a1) in zip(pts, pts[1:]):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for s in range(n):
            f = s / max(1, n - 1)
            x, y = x0 + (x1 - x0) * f, y0 + (y1 - y0) * f
            wpx = w0 + (w1 - w0) * f
            a = a0 + (a1 - a0) * f
            if wpx < 0.5 or a <= 0.02:
                continue
            r = wpx / 2.0
            for yy in range(int(y - r + 0.5), int(y + r + 0.5)):
                for xx in range(int(x - r + 0.5), int(x + r + 0.5)):
                    if 0 <= xx < W and 0 <= yy < H and a > BAYF[yy & 3][xx & 3]:
                        F[yy, xx] = c


def render(rec, t, z, view, variant):
    P, st, A, ws = sample(rec, t)
    G = T.ground(z)
    cx0 = int(round((P[0] + view[0]) * z))
    cy0 = int(round((P[1] + view[1]) * z))
    Wd, Hd = int((view[2] - view[0]) * z), int((view[3] - view[1]) * z)
    F = G[cy0:cy0 + Hd, cx0:cx0 + Wd].astype(np.float32).copy()

    def S(p):
        return (p[0] * z - cx0, p[1] * z - cy0)

    # silah gölgeleri
    for w in ws:
        if w["alpha"] > 0.0:
            gx, gy, rx, ry = w["sh"]
            sx, sy = S((gx, gy))
            ellipse(F, sx, sy, rx * z, ry * z, (0, 0, 0), 0.32 * 0.4 * w["alpha"])
    # slime
    sl = A["slime"]
    dead = sl["dead"]
    if dead is None or t - dead < 0.3:
        ex, ey = S(sl["pos"])
        k = 1.0 if dead is None else 1.0 - (t - dead) / 0.3
        blit2(F, slime_frame(t), ex, ey, SLIME_K * z * (0.6 + 0.4 * k), alpha=k)
        if 0.0 <= t - sl["flash"] < 0.1:
            blit2(F, slime_frame(t), ex, ey, SLIME_K * z * (0.6 + 0.4 * k), alpha=0.8 * k, tint=(255, 255, 255))
        if dead is not None:
            for j in range(5):
                a = j * 1.2566 + 0.4
                rr = 6.0 + 14.0 * (t - dead) / 0.3
                star(F, ex + math.cos(a) * rr * z, ey - 6 * z + math.sin(a) * rr * 0.6 * z, 1.0 * z, (190, 240, 210), 0.7 * k, z)
    # mermiler
    for p in A["proj"]:
        px, py = S((p["x"], p["y"]))
        dx, dy = p.get("dx", 1.0), p.get("dy", 0.0)
        if p["k"] == 1:
            line_w(F, px - dx * 6 * z, py - dy * 6 * z, px, py, (236, 104, 30), 0.6, 2 * z)
            ellipse(F, px, py, 2.6 * z, 2.6 * z, (255, 150, 40), 1.0)
            ellipse(F, px, py, 1.3 * z, 1.3 * z, (255, 236, 150), 1.0)
        else:
            line_w(F, px - dx * 5 * z, py - dy * 5 * z, px, py, (255, 240, 180), 1.0, z)

    order = [0, 1, 2]
    # çıkış izi (tüm varyantlar): göğüsten slota çizilen yay boyunca tek ince, sönen iz
    for i in order:
        pts = []
        for kk in range(0, 12):
            hs = kk * 0.018
            _, _, Ah, hw = sample(rec, t - hs)
            if Ah["state"] != "reveal" or hw[i]["alpha"] < 0.5:
                if pts:
                    break
                continue
            f = kk / 11.0
            pts.append((*S(hw[i]["pos"]), (1.8 - 1.2 * f) * z, 0.85 - 0.85 * f))
        if len(pts) >= 2:
            dither_trail(F, pts, GLINT)
    # hız çizgileri (silahların ARKASINDA)
    for i in order:
        w = ws[i]
        if A["state"] != "shown" or w["m"] < 0.5:
            continue
        strength = clamp((w["m"] - 0.5) / 0.35, 0.0, 1.0)
        mv = w["w"]
        L = math.hypot(mv[0], mv[1])
        d = (mv[0] / L, mv[1] / L)
        pr = (-d[1], d[0])
        if variant == "A":
            for side in (-1.0, 1.0):
                pts = []
                for kk in range(0, 13):
                    hs = 0.10 + kk * 0.016
                    _, _, Ah, hw = sample(rec, t - hs)
                    if Ah["state"] != "shown":
                        break  # iz sadece silahın göründüğü geçmişten (gizliyken/çıkarken konum = slot)
                    hp = hw[i]["pos"]
                    off = 3.5 * side
                    f = kk / 12.0
                    pts.append((*S((hp[0] + pr[0] * off, hp[1] + pr[1] * off)), (2.2 - 1.6 * f) * z, (0.85 - 0.85 * f) * strength))
                dither_trail(F, pts, STREAK)
        elif variant == "B":
            for kk, al in ((3, 0.16), (2, 0.28), (1, 0.45)):
                _, _, Ah, hw = sample(rec, t - 0.06 * kk)
                if Ah["state"] != "shown":
                    continue
                g = hw[i]
                gx, gy = S(g["pos"])
                fl = -1.0 if g["flip"] else 1.0
                blit2(F, icon_np(WEAPONS[i][0]), gx, gy, WPP * z, g["rot"] * D2R, g["sx"] * fl, g["sy"], alpha=al * strength, tint=GHOST)
        elif variant == "C":
            pts = []
            for kk in range(0, 11):
                hs = 0.12 + kk * 0.02
                _, _, Ah, hw = sample(rec, t - hs)
                if Ah["state"] != "shown":
                    break
                hp = hw[i]["pos"]
                f = kk / 10.0
                pts.append((*S(hp), (1.2 - 0.6 * f) * z, (0.7 - 0.7 * f) * strength))
            dither_trail(F, pts, STREAK)
    # karakter
    sx, sy = S((P[0], P[1] + 12.0))
    ellipse(F, sx, sy, 9.0 * z, 3.5 * z, (0, 0, 0), 0.32)
    fr = T.char_frame(st["moving"], st["face"], st["walk_t"], st["t"])
    sx, sy = S((P[0], P[1] + CHAR_OFF_Y))
    blit2(F, fr, sx, sy, CHAR_K * z)
    # can barı
    bx0, bx1 = P[0] - 11.0, P[0] + 11.0
    for (y0, y1, fill) in ((-34.0, -30.5, (77, 209, 61)), (-29.5, -27.0, (89, 184, 255))):
        a0, b0 = S((bx0 - 1.0, P[1] + y0 - 1.0))
        a1, b1 = S((bx1 + 1.0, P[1] + y1 + 1.0))
        T.rect(F, a0, b0, a1, b1, (14, 12, 12))
        a0, b0 = S((bx0, P[1] + y0))
        a1, b1 = S((bx1, P[1] + y1))
        T.rect(F, a0, b0, a1, b1, fill)
        T.rect(F, a0, b0, a1, b0 + max(1, z // 2), tuple(min(255, c + 50) for c in fill))
    # silahlar
    for i in order:
        w = ws[i]
        if w["alpha"] <= 0.0:
            continue
        x, y = S(w["pos"])
        fl = -1.0 if w["flip"] else 1.0
        args = (F, icon_np(WEAPONS[i][0]), x, y, WPP * z, w["rot"] * D2R, w["sx"] * fl, w["sy"])
        blit2(*args, alpha=w["alpha"])
        if w["flash"] > 0.0:
            blit2(*args, alpha=w["flash"] * w["alpha"], tint=(255, 250, 236))
        if variant == "C" and A["state"] == "shown" and w["m"] >= 0.5:
            strength = clamp((w["m"] - 0.5) / 0.35, 0.0, 1.0)
            mv = w["w"]
            L = math.hypot(mv[0], mv[1])
            d = (mv[0] / L, mv[1] / L)
            # ok başı: gidiş yönünde ucun (silah merkezinden 12 px) önünde, geriye açılan iki kısa çizgi
            ax, ay = w["pos"][0] + d[0] * 14.0, w["pos"][1] + d[1] * 14.0
            for sgn in (-1.0, 1.0):
                ca, sa = math.cos(sgn * 0.62), math.sin(sgn * 0.62)
                bx, by = -d[0] * ca + d[1] * sa, -d[1] * ca - d[0] * sa
                p0 = S((ax, ay))
                p1 = S((ax + bx * 5.5, ay + by * 5.5))
                dither_trail(F, [(p0[0], p0[1], 1.2 * z, 0.9 * strength), (p1[0], p1[1], 0.8 * z, 0.25 * strength)], STREAK)
    # efektler
    for w in ws:
        for prim in w["fx"]:
            _, a0, b0, r, col, al = prim
            c = S((w["pos"][0] + a0, w["pos"][1] + b0))
            star(F, c[0], c[1], r * z, col, al, z)
    for prim in A["chest_fx"]:
        _, a0, b0, r, col, al = prim
        c = S((a0, b0))
        star(F, c[0], c[1], r * z, col, al, z)
    return Image.fromarray(np.clip(F, 0, 255).astype(np.uint8), "RGB")


# ------------------------------------------------------------------ durum haritası
def status_tile(rec, t, w, h):
    im = Image.new("RGB", (w, h), (28, 32, 30))
    d = ImageDraw.Draw(im)
    P, st, A, ws = sample(rec, t)
    sc = 0.42 if w >= 600 else 0.28
    ox, oy = 14 + 380.0 * sc, h / 2.0 + 8
    sp = lambda p: (ox + (p[0] - START[0]) * sc, oy + (p[1] - START[1]) * sc)  # noqa: E731
    px, py = sp(P)
    seen = A["slime"]["seen"]
    d.ellipse((px - VIS_RX * sc, py - VIS_RY * sc, px + VIS_RX * sc, py + VIS_RY * sc), fill=(36, 44, 40) if not seen else (44, 52, 40),
              outline=(150, 146, 120))
    for r, col in ((RANGE[2], (110, 160, 220)), (RANGE[1], (230, 140, 60))):
        d.ellipse((px - r * sc, py - r * sc, px + r * sc, py + r * sc), outline=col)
    d.ellipse((px - 4, py - 4, px + 4, py + 4), fill=(240, 220, 140))
    sl = A["slime"]
    if sl["dead"] is None:
        ex, ey = sp(sl["pos"])
        d.ellipse((ex - 4, ey - 4, ex + 4, ey + 4), fill=(120, 230, 190))
    for p in A["proj"]:
        qx, qy = sp((p["x"], p["y"]))
        d.rectangle((qx - 1, qy - 1, qx + 1, qy + 1), fill=(255, 200, 120))
    label(d, 10, 6, "Durum", 13)
    label(d, 10, 24, "elips = görüş (350 x 250) · mavi Tabanca 210 · turuncu Asa 168", 9, (200, 196, 182))
    x0 = int(max(ox + 470.0 * sc + 12, w - 262))
    y = 44
    label(d, x0, y, "%.2f sn · %s" % (t, phase_name(t)), 12, (255, 214, 120))
    y += 22
    label(d, x0, y, "görüşte düşman: %s" % ("VAR" if seen else "YOK"), 11, (150, 236, 160) if seen else (236, 170, 150))
    y += 20
    names = ["Uzunkılıç", "Ateş Asası", "Tabanca"]
    for i in range(3):
        label(d, x0, y, "%s: %s" % (names[i], ws[i]["mode"]), 11, (226, 220, 204))
        y += 18
    y += 6
    for s in ("menzilde = hedefe (kaçarken geriye)", "menzil dışı + yürüyor = gidiş yönü",
              "duruyor = hazır (düşmana)", "görüşte düşman yok = içe çekilir"):
        label(d, x0, y, s, 9, (190, 186, 172))
        y += 14
    return im


VARIANTS = [("A", "A · Sivri İz", "gövde ucundan 2 sivrilen iz, gerçek geçmiş yol, piksel söner"),
            ("B", "B · Ardıl Görüntü", "3 soğuk tonlu hayalet (0,06 / 0,12 / 0,18 sn önce)"),
            ("C", "C · Hava Yarığı", "ucun önünde havayı yaran V + tek ince iz")]


def tile_label(im, title, sub, small):
    d = ImageDraw.Draw(im)
    label(d, 6, 3, title, 12)
    if not small:
        label(d, 6, im.height - 15, sub, 9, (232, 226, 210))


def grid(tiles, cols, gap=4):
    w, h = tiles[0].size
    rows = (len(tiles) + cols - 1) // cols
    g = Image.new("RGB", (cols * w + (cols - 1) * gap, rows * h + (rows - 1) * gap), (18, 20, 20))
    for i, tl in enumerate(tiles):
        g.paste(tl, ((i % cols) * (w + gap), (i // cols) * (h + gap)))
    return g


def build(z, view, name, small, fps, cols):
    rec = simulate()
    n = int(round(LOOP * fps))
    dt = LOOP / n
    tw, th = int((view[2] - view[0]) * z), int((view[3] - view[1]) * z)
    hd = header(tw * cols + 4 * (cols - 1), "E Hücum v2 · hız çizgisi A/B/C + yön kuralı + içe çekilme / çıkış  ·  %s" %
                ("oyun ölçeği (1080p), gerçek hız" if z == 2 else "x2 yakın, gerçek hız"),
                "düşman görüşe girince çıkar · menzildekiler hedefe (kaçarken geriye) · diğerleri gidiş yönüne · düşman ölünce içe çekilir")
    frames = []
    for k in range(n):
        t = k * dt
        tiles = []
        for key, title, sub in VARIANTS:
            im = render(rec, t, z, view, key)
            tile_label(im, title, sub, small)
            tiles.append(im)
        tiles.append(status_tile(rec, t, tw, th))
        frames.append(stack_v([hd, grid(tiles, cols)]))
    os.makedirs(OUT, exist_ok=True)
    save_gif(frames, os.path.join(OUT, name + ".gif"), 1.0 / dt, [int(1.6 / dt), int(2.6 / dt), int(3.6 / dt)])
    return frames, dt


STRIP_T = [1.14, 1.20, 1.28, 1.40, 1.80, 2.60, 3.30, 3.95, 4.45, 5.10, 5.20, 5.30, 5.42]


def build_strip(z=3, view=(-62.0, -84.0, 62.0, 18.0)):
    rec = simulate()
    tw = int((view[2] - view[0]) * z)
    rows = []
    for key, title, _ in VARIANTS:
        cells = []
        for t in STRIP_T:
            im = render(rec, t, z, view, key)
            label(ImageDraw.Draw(im), 4, 2, "%.2f %s" % (t, phase_name(t)), 10)
            cells.append(im)
        row = Image.new("RGB", (len(cells) * (tw + 2), cells[0].height + 18), (30, 34, 32))
        label(ImageDraw.Draw(row), 4, 2, title, 12)
        for j, c in enumerate(cells):
            row.paste(c, (j * (tw + 2), 18))
        rows.append(row)
    os.makedirs(OUT, exist_ok=True)
    stack_v(rows).save(os.path.join(OUT, "hucum_kareler.png"))


if __name__ == "__main__":
    what = sys.argv[1:] or ["kareler", "oyun", "yakin"]
    if "kareler" in what:
        build_strip()
    if "oyun" in what:
        fr, dt = build(2, (-130.0, -95.0, 210.0, 40.0), "hucum_oyun", False, FPS, 2)
        fr[int(3.5 / dt)].save(os.path.join(OUT, "hucum_kare.png"))
    if "yakin" in what:
        build(4, (-60.0, -84.0, 60.0, 20.0), "hucum_yakin", True, 25, 2)
