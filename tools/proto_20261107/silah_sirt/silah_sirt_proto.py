# -*- coding: utf-8 -*-
"""SİLAHLAR SIRTTA prototipleri (2026-11-07, oyuna bağlı DEĞİL). Kullanıcı: "bundan sonra silahlar içeri girip kaybolmak yerine
karakterin sırtında görünsün bunun nasıl görüneceğinin prototipini hazırlar mısın".

Bugün (madde 247/283/291, weapon_follow_math.gd step_visibility): görüşte düşman yoksa / çalıda saklıyken / ölünce silahlar
göğse (CHEST 0,-8 dünya) dönerek küçülüp çekilir ve KAYBOLUR; düşman görünce göğüsten dönerek çıkar (REVEAL_T 0,42, kademe 0,07).

Varyantlar (hepsi aynı sahne; "sırttaki" silah karakterle aynı piksel ızgarasında, gölgesiz; arkadan bakışta karakterin ÖNÜNDE,
önden/yandan bakışta ARKASINDA çizilir = gövde örter, yalnız omuz/baş üstünden taşan uçlar görünür):
  A Çapraz Kın      - üç silah sırtta çapraz (X) + ortada dik; kabza/asa başı omuzun üstünden taşar, %72 boy, adımda 0,5 px sekme.
                      Çekiş: kabzadan yukarı sıyrılır -> yuvasına uçar; kına giriş: yukarıdan iner, "klik" parıltısı + 1 px oturma.
  B Omuz Yelpazesi  - üç silah sırtta dik yelpaze (sağ-orta-sol), yalnız üst uçları başın/omuzların üstünden görünür (okçu sadağı
                      gibi), %62 boy. Silüet en temiz olan.
  C Türüne Göre     - uzun silahlar (asa, yay) sırtta çapraz, kılıç BELDE kınında (kabza önde-yukarı); Bıçak/Tabanca/Pençe gibi
                      küçükler de belde olurdu. En "gerçekçi" olan, en çok kural isteyen.
  D Süzülen Kın     - büyülü: silahlar sırtın hemen arkasında küçük (%58), hafif koyu, yavaş salınır ve yürürken yayla geride
                      kalır; kayış yok. Bugünkü süzülen silah diline en yakın.
ŞU AN = bugünkü göğse çekilip kaybolma (karşılaştırma).

Sahne (9 sn döngü, kamera oyuncuya kilitli): önden dur -> sağa yürü -> yukarı yürü (arkadan, sırt tam görünür) -> aşağı yürü ->
sağdan slime gelir, silahlar sırttan çekilir -> nişan -> slime ölür -> 0,6 sn sonra kına girer -> sola yürü -> dur.
Silahlar: Uzunkılıç, Ateş Asası, Yay (oyundaki masaüstü çizimleri assets/weapons/yeni/, 0,575 dünya px / sanat pikseli).

Çıktılar (out/): sirt_oyun.gif (1080p oyun ölçeği x2, gerçek hız), sirt_yakin.gif (x4 yakın), sirt_yonler.png (4 yön x varyant,
x5, durağan). Çalıştırma: python -I tools/proto_20261107/silah_sirt/silah_sirt_proto.py [oyun|yakin|yonler|alcak|alcak_gif]
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
P17 = os.path.join(HERE, "..", "..", "proto_20261017")
sys.path.insert(0, P17)
import silah_takip_proto as T  # noqa: E402
from silah_takip_proto import (CHAR_K, CHAR_OFF_Y, SLOTS, SLIME_K, blit2, ellipse, rect, star, ground, char_frame,  # noqa: E402
                               slime_frame, grid)
from mermi_proto import asset, label  # noqa: E402
from bicak_proto import header, stack_v, save_gif  # noqa: E402

OUT = os.path.join(HERE, "out")
D2R = math.pi / 180.0
WPP = 0.575
SPEED = T.SPEED
START = T.START
LOOP = 9.0

## (anahtar, sanat dosyası, FORWARD = ucun sanattaki açısı, yukarı taşan uçtan uca açı farkı)
WEAPONS = [("uzunkilic", "assets/weapons/yeni/uzunkilic.png", -45.0, 180.0),  # kılıçta yukarı taşan = kabza (uç aşağıda)
           ("fire_staff", "assets/weapons/yeni/fire_staff.png", -45.0, 0.0),  # asada = baş
           ("yay", "assets/weapons/yeni/yay.png", 45.0, 90.0)]  # yayda "yukarı" = üst kol; ok yönü kollara dik
_ICON = {}


def icon(i):
    if i not in _ICON:
        _ICON[i] = np.asarray(asset(WEAPONS[i][1]), dtype=np.float32)
    return _ICON[i]


# ------------------------------------------------------------------ oyuncu yolu (analitik)
SEGS = [(1.0, None, (0, 1)), (1.3, (1, 0), None), (1.1, (0, -1), None), (0.5, None, (0, -1)), (1.1, (0, 1), None),
        (2.3, None, (1, 0)), (1.3, (-1, 0), None), (0.4, None, (0, 1))]
assert abs(sum(s[0] for s in SEGS) - LOOP) < 1e-6
SLIME_SEEN = 5.0  # slime görüşe girer
SLIME_DIE = 6.3
SHEATHE_AT = SLIME_DIE + 0.6  # HIDE_GRACE
DRAW_T, DRAW_STAG = 0.42, [0.0, 0.07, 0.14]
SHEATHE_T, SHEATHE_STAG = 0.30, [0.08, 0.04, 0.0]


def player(t):
    t = t % LOOP
    x, y = START
    acc = 0.0
    face = (0, 1)
    for dur, d, f in SEGS:
        seg = min(dur, max(0.0, t - acc))
        if d is not None:
            x += d[0] * SPEED * seg
            y += d[1] * SPEED * seg
        if t < acc + dur:
            moving = d is not None
            face = d if moving else f
            return {"P": (x, y), "moving": moving, "face": face, "walk_t": t - acc if moving else 0.0, "t": t,
                    "V": (d[0] * SPEED, d[1] * SPEED) if moving else (0.0, 0.0)}
        acc += dur
    return {"P": (x, y), "moving": False, "face": (0, 1), "walk_t": 0.0, "t": t, "V": (0.0, 0.0)}


P_FIGHT = player(5.5)["P"]
SLIME_STOP = (P_FIGHT[0] + 58.0, P_FIGHT[1] + 4.0)


def slime_state(t):
    """(konum, alfa, flaş) ya da None."""
    if t < SLIME_SEEN - 0.6 or t > SLIME_DIE + 0.25:
        return None
    f = min(1.0, (t - (SLIME_SEEN - 0.6)) / 1.2)
    pos = (SLIME_STOP[0] + 50.0 * (1.0 - f), SLIME_STOP[1])
    flash = 0.0
    for h in (5.75, 6.02, SLIME_DIE):
        if 0.0 <= t - h < 0.09:
            flash = 1.0 - (t - h) / 0.09
    alpha = 1.0 if t < SLIME_DIE else max(0.0, 1.0 - (t - SLIME_DIE) / 0.25)
    return pos, alpha, flash


# ------------------------------------------------------------------ yardımcılar
def ease_out_back(x, s=1.7):
    x -= 1.0
    return 1.0 + (s + 1.0) * x ** 3 + s * x ** 2


def ease_in(x, p=2.4):
    return x ** p


def ang_lerp(a, b, f):
    d = (b - a + 180.0) % 360.0 - 180.0
    return a + d * f


def bez(p0, c, p1, f):
    u = 1.0 - f
    return (u * u * p0[0] + 2 * u * f * c[0] + f * f * p1[0], u * u * p0[1] + 2 * u * f * c[1] + f * f * p1[1])


def step_bob(st):
    """Yürüme klibi 8 fps, 3 karede bir adım -> sırttaki kayışlı silah adımda 0,5 dünya px sekmesi."""
    if not st["moving"]:
        return 0.0
    return -0.55 * abs(math.sin(math.pi * st["walk_t"] * 8.0 / 3.0))


# ------------------------------------------------------------------ sırt duruşları
## Kanonik = ARKADAN bakış (yüz yukarı, sırt bize dönük); x ekran sağı. Her giriş: (dx, dy, yukarı_uç_açısı, ölçek).
## Önden bakışta x ve açı aynalanır + gövdenin arkasında; yandan bakışta x sırta sıkışır, uçlar geriye yatar.
MOUNTS = {
    "A": [(3.0, -9.0, -52.0, 0.85), (-3.0, -9.0, -128.0, 0.85), (0.0, -10.0, -90.0, 0.80)],
    ## A alçak (kullanıcı 2026-11-07: "A fena değil ama biraz daha aşağıda durmalılar sırtta gibi hissedilmesi için"):
    ## A2 = 3,5 px aşağı (X'in ortası kürek kemiği), A3 = 6 px aşağı + X biraz yatık (ortası bel üstü, kabzalar omuz hizasında).
    ## Yay dik durunca arkadan bakışta başı ortadan bölüyordu -> alçaklarda X'in altında belde YATAY (kolları gövdenin iki yanından taşar).
    "A2": [(3.0, -5.5, -48.0, 0.85), (-3.0, -5.5, -132.0, 0.85), (0.0, -2.5, -166.0, 0.80)],
    "A3": [(3.0, -3.0, -42.0, 0.85), (-3.0, -3.0, -138.0, 0.85), (0.0, -0.5, -166.0, 0.80)],
    "B": [(-5.0, -11.0, -124.0, 0.75), (0.0, -12.5, -90.0, 0.75), (5.0, -11.0, -56.0, 0.75)],
    "C": [(-6.5, 2.0, -122.0, 0.66), (3.0, -9.0, -52.0, 0.85), (-3.0, -9.0, -128.0, 0.80)],  # 0 = belde kın
    "D": [(-7.5, -10.0, -122.0, 0.58), (0.0, -13.0, -90.0, 0.58), (7.5, -10.0, -58.0, 0.58)],
}
HIP = {"C": {0}}
DRAW_ORDER_BACK = [2, 0, 1]  # sırtta en altta yay (A'da ortadaki dik), sonra kılıç, üstte asa


def mount_pose(var, i, st, t):
    dx, dy, up, sc = MOUNTS[var][i]
    face = st["face"]
    hip = i in HIP.get(var, ())
    if face == (0, -1):  # arkadan: sırt bize dönük
        depth = 1.0
    elif face == (0, 1):  # önden: aynala, gövdenin arkasında (belde kın önde)
        dx, up = -dx, 180.0 - up
        depth = 1.0 if hip else -1.0
    else:  # yandan: sırt yüzün tersinde
        back = -face[0]
        vx, vy = math.cos(up * D2R), math.sin(up * D2R)
        vx = vx * 0.35 + back * 0.30
        up = math.atan2(vy, vx) / D2R
        if hip:
            dx = face[0] * 1.5 + back * 3.0
            depth = 1.0 if face == (1, 0) else -1.0
        else:
            dx = back * 3.5 + dx * 0.25
            depth = -1.0
    dy += step_bob(st)
    mul = 1.0
    if var == "D":
        ph = [0.0, 2.1, 4.2][i]
        dy += math.sin(2.2 * t + ph) * 0.8
        up += math.sin(1.4 * t + ph) * 4.0
        dx -= st["V"][0] * 0.045  # yürürken yayla geride kalır (sabit hızda kararlı gecikme)
        dy -= st["V"][1] * 0.045
        mul = 0.80
    return {"d": (dx, dy), "up": up, "sc": sc, "depth": depth, "mul": mul}


def tip_from_up(i, up):
    return up + WEAPONS[i][3]


def hover_pose(i, st, t):
    P = st["P"]
    bob = math.sin(2.2 * t + T.CUR_PHASES[i]) * 1.75
    d = (SLOTS[i][0], SLOTS[i][1] + bob)
    s = slime_state(t)
    tgt = s[0] if s else SLIME_STOP
    pos = (P[0] + d[0], P[1] + d[1])
    tip = math.atan2(tgt[1] - 4.0 - pos[1], tgt[0] - pos[0]) / D2R
    return {"d": d, "tip": tip, "sc": 1.0, "depth": 1.0, "mul": 1.0}


def weapon_pose(var, i, st, t):
    """Dönen: d (oyuncuya göre), tip, sc, depth, mul, alpha, shadow (0..1), glint (None ya da (dx, dy, a))."""
    t0 = SLIME_SEEN + DRAW_STAG[i]
    t1 = SHEATHE_AT + SHEATHE_STAG[i]
    ph = "back"
    if t0 <= t < t0 + DRAW_T:
        ph, f = "draw", (t - t0) / DRAW_T
    elif t0 + DRAW_T <= t < t1:
        ph = "hover"
    elif t1 <= t < t1 + SHEATHE_T:
        ph, f = "sheathe", (t - t1) / SHEATHE_T
    hv = hover_pose(i, st, t)
    out = {"glint": None, "shadow": 0.0, "alpha": 1.0}
    if var == "NOW":
        chest = (0.0, -8.0)
        if ph == "back":
            out.update(d=chest, tip=0.0, sc=0.0, depth=1.0, mul=1.0, alpha=0.0)
        elif ph == "hover":
            out.update(hv, shadow=1.0)
        elif ph == "draw":
            e = ease_out_back(f)
            out.update(d=(chest[0] + (hv["d"][0] - chest[0]) * e, chest[1] + (hv["d"][1] - chest[1]) * e),
                       tip=hv["tip"] - 360.0 * (1.0 - f), sc=min(1.0, 0.25 + 0.75 * e), depth=1.0, mul=1.0, shadow=f)
            if f > 0.78:
                out["glint"] = (0.0, 0.0, 1.0 - (f - 0.78) / 0.22)
        else:
            e = ease_in(f)
            out.update(d=(hv["d"][0] + (chest[0] - hv["d"][0]) * e, hv["d"][1] + (chest[1] - hv["d"][1]) * e),
                       tip=hv["tip"] + 220.0 * f, sc=max(0.0, 1.0 - e), depth=1.0, mul=1.0, shadow=1.0 - f)
        return out
    mp = mount_pose(var, i, st, t)
    mtip = tip_from_up(i, mp["up"])
    up_v = (math.cos(mp["up"] * D2R), math.sin(mp["up"] * D2R))
    if ph == "back":
        out.update(d=mp["d"], tip=mtip, sc=mp["sc"], depth=mp["depth"], mul=mp["mul"])
        # kına giriş "klik": 1 px oturma + kabzada kısa parıltı
        ts = t - (t1 + SHEATHE_T)
        if 0.0 <= ts < 0.12 and var != "D":
            out["d"] = (mp["d"][0], mp["d"][1] + 0.8 * (1.0 - ts / 0.12))
            L = 8.0 * mp["sc"]
            out["glint"] = (mp["d"][0] + up_v[0] * L, mp["d"][1] + up_v[1] * L, 1.0 - ts / 0.12)
        return out
    if ph == "hover":
        out.update(hv, shadow=1.0)
        return out
    # çekiş / kına giriş: kabza yönünde sıyrılma payı (kontrol noktası)
    pull = 16.0 if var != "D" else 8.0
    ctrl = (mp["d"][0] + up_v[0] * pull * 0.6, mp["d"][1] + up_v[1] * pull - 6.0)
    if ph == "draw":
        e = ease_out_back(f)
        pos = bez(mp["d"], ctrl, hv["d"], min(1.0, e)) if e <= 1.0 else (
            hv["d"][0] + (hv["d"][0] - ctrl[0]) * (e - 1.0) * 0.5, hv["d"][1] + (hv["d"][1] - ctrl[1]) * (e - 1.0) * 0.5)
        spin = 360.0 * (1.0 - f) if var != "D" else 0.0
        out.update(d=pos, tip=ang_lerp(mtip, hv["tip"], min(1.0, f * 1.4)) - spin,
                   sc=mp["sc"] + (1.0 - mp["sc"]) * min(1.0, e), depth=1.0 if f > 0.12 else mp["depth"],
                   mul=mp["mul"] + (1.0 - mp["mul"]) * f, shadow=f)
        if f > 0.78:
            out["glint"] = (pos[0], pos[1], 1.0 - (f - 0.78) / 0.22)
    else:
        e = ease_in(f) if var != "D" else 1.0 - (1.0 - f) ** 2
        pos = bez(hv["d"], ctrl, mp["d"], e)
        out.update(d=pos, tip=ang_lerp(hv["tip"], mtip, min(1.0, f * 1.3)), sc=1.0 + (mp["sc"] - 1.0) * e,
                   depth=mp["depth"] if f > 0.82 else 1.0, mul=1.0 + (mp["mul"] - 1.0) * f, shadow=1.0 - f)
    return out


# ------------------------------------------------------------------ çizim
def draw_weapon(F, i, w, S, P, z):
    if w["sc"] <= 0.02 or w["alpha"] <= 0.0:
        return
    x, y = S((P[0] + w["d"][0], P[1] + w["d"][1]))
    fw = WEAPONS[i][2]
    tip = w["tip"]
    # sola bakan uç -> aynalı sanat (oyunda flip_h; ucu aşağı kalan sanat ters görünmesin)
    vx = math.cos(tip * D2R)
    if vx < -0.05:
        blit2(F, icon(i), x, y, WPP * z * w["sc"], (tip - (180.0 - fw)) * D2R, sx=-1.0, alpha=w["alpha"], mul=w["mul"])
    else:
        blit2(F, icon(i), x, y, WPP * z * w["sc"], (tip - fw) * D2R, alpha=w["alpha"], mul=w["mul"])


def render(var, t, z, view):
    st = player(t)
    P = st["P"]
    G = ground(z)
    cx0 = int(round((P[0] + view[0]) * z))
    cy0 = int(round((P[1] + view[1]) * z))
    Wd, Hd = int((view[2] - view[0]) * z), int((view[3] - view[1]) * z)
    F = G[cy0:cy0 + Hd, cx0:cx0 + Wd].astype(np.float32).copy()

    def S(p):
        return (p[0] * z - cx0, p[1] * z - cy0)

    ws = [weapon_pose(var, i, st, t) for i in range(3)]
    for w in ws:  # süzülen silah gölgesi (shadow_blob.gd), sırttakinin gölgesi yok
        if w["shadow"] > 0.01:
            gx, gy = S((P[0] + w["d"][0], P[1] + 12.0 + 4.0))
            ellipse(F, gx, gy, 4.0 * z * w["sc"], 1.8 * z * w["sc"], (0, 0, 0), 0.13 * w["shadow"])
    s = slime_state(t)
    if s:
        ex, ey = S(s[0])
        blit2(F, slime_frame(t), ex, ey, SLIME_K * z, alpha=s[1])
        if s[2] > 0:
            blit2(F, slime_frame(t), ex, ey, SLIME_K * z, alpha=s[1] * s[2], tint=(255, 250, 236))
    order = DRAW_ORDER_BACK
    for i in order:
        if ws[i]["depth"] < 0:
            draw_weapon(F, i, ws[i], S, P, z)
    sx, sy = S((P[0], P[1] + 12.0))
    ellipse(F, sx, sy, 9.0 * z, 3.5 * z, (0, 0, 0), 0.32)
    fr = char_frame(st["moving"], st["face"], st["walk_t"], st["t"])
    sx, sy = S((P[0], P[1] + CHAR_OFF_Y))
    blit2(F, fr, sx, sy, CHAR_K * z)
    for i in order:
        if ws[i]["depth"] >= 0 and ws[i]["shadow"] < 0.5:  # sırttaki önde (arkadan bakış) - can barının altında
            draw_weapon(F, i, ws[i], S, P, z)
    bx0, bx1 = P[0] - 11.0, P[0] + 11.0
    for (y0, y1, fill) in ((-34.0, -30.5, (77, 209, 61)), (-29.5, -27.0, (89, 184, 255))):
        a0, b0 = S((bx0 - 1.0, P[1] + y0 - 1.0))
        a1, b1 = S((bx1 + 1.0, P[1] + y1 + 1.0))
        rect(F, a0, b0, a1, b1, (14, 12, 12))
        a0, b0 = S((bx0, P[1] + y0))
        a1, b1 = S((bx1, P[1] + y1))
        rect(F, a0, b0, a1, b1, fill)
    for i in order:
        if ws[i]["depth"] >= 0 and ws[i]["shadow"] >= 0.5:  # havadaki silahlar en üstte
            draw_weapon(F, i, ws[i], S, P, z)
    for w in ws:
        if w["glint"]:
            gx, gy, a = w["glint"]
            c = S((P[0] + gx, P[1] + gy))
            star(F, c[0], c[1], 3.0 * z, (255, 252, 232), 0.9 * a, max(1, z // 2))
    return Image.fromarray(np.clip(F, 0, 255).astype(np.uint8), "RGB")


VARIANTS = [("NOW", "ŞU AN", "göğse çekilip kaybolur"),
            ("A", "A · Çapraz Kın", "sırtta X, kabzalar omuz üstü"),
            ("B", "B · Omuz Yelpazesi", "dik yelpaze, uçlar baş üstü"),
            ("C", "C · Türüne Göre", "kılıç belde, asa+yay sırtta"),
            ("D", "D · Süzülen Kın", "büyülü, küçük, yayla geride")]


def phase_text(t):
    if t < 1.0:
        return "dur (önden)"
    if t < 2.3:
        return "sağa yürü (yandan)"
    if t < 3.9:
        return "yukarı (arkadan: sırt görünür)"
    if t < SLIME_SEEN:
        return "aşağı yürü (önden)"
    if t < SLIME_SEEN + 0.56:
        return "düşman göründü: SIRTTAN ÇEKİŞ"
    if t < SLIME_DIE:
        return "nişan / savaş"
    if t < SHEATHE_AT:
        return "düşman öldü (0,6 sn bekleme)"
    if t < SHEATHE_AT + 0.4:
        return "KINA GİRİŞ"
    return "sola yürü (yandan)"


def info_tile(w, h, t):
    im = Image.new("RGB", (w, h), (30, 34, 32))
    d = ImageDraw.Draw(im)
    label(d, 10, 8, "Şimdi: " + phase_text(t), 12, (255, 226, 150))
    lines = ["Silahlar: Uzunkılıç, Ateş Asası, Yay", "Sırttaki silah gölgesiz, karakterle", "aynı ızgarada; arkadan bakışta önde,",
             "önden/yandan gövdenin arkasında.", "Düşman görünce sırttan çekilip", "bugünkü yuvalarına uçar; düşman",
             "ölünce 0,6 sn sonra kına girer."]
    y = 32
    for s in lines:
        label(d, 10, y, s, 10, (220, 214, 198))
        y += 15
    bw = w - 20
    rect_arr = np.asarray(im).copy()
    im = Image.fromarray(rect_arr)
    d = ImageDraw.Draw(im)
    d.rectangle((10, h - 14, 10 + bw, h - 8), fill=(50, 56, 52))
    d.rectangle((10, h - 14, 10 + int(bw * (t / LOOP)), h - 8), fill=(214, 176, 96))
    return im


def tile(var, title, sub, t, z, view, small):
    im = render(var, t, z, view)
    d = ImageDraw.Draw(im)
    label(d, 6, 3, title, 12)
    if not small:
        label(d, 6, im.height - 15, sub, 9, (232, 226, 210))
    return im


VARIANTS_ALCAK = [("A", "A · eski", "X ortası ense"),
                  ("A2", "A2 · biraz aşağı", "3,5 px aşağı, yay belde"),
                  ("A3", "A3 · daha aşağı", "6 px aşağı, X yatık")]


def build_gif(z, view, name, fps, cols, title, variants=None):
    variants = variants or VARIANTS
    n = int(round(LOOP * fps))
    dt = LOOP / n
    tw, th = int((view[2] - view[0]) * z), int((view[3] - view[1]) * z)
    hd = header(tw * cols + 4 * (cols - 1), title,
                "önden dur · sağa · yukarı (sırt) · aşağı · düşman: sırttan çekiş · savaş · kına giriş · sola")
    frames = []
    for k in range(n):
        t = k * dt
        tiles = [tile(v, a, b, t, z, view, False) for v, a, b in variants]
        tiles.append(info_tile(tw, th, t))
        frames.append(stack_v([hd, grid(tiles, cols)]))
    os.makedirs(OUT, exist_ok=True)
    save_gif(frames, os.path.join(OUT, name), fps, [int(3.0 / dt), int(5.3 / dt), int(8.0 / dt)])


YON_T = [(0.5, "önden"), (1.6, "yandan (sağ)"), (3.6, "arkadan"), (8.0, "yandan (sol)"), (5.12, "çekiş anı"), (7.16, "kına giriş")]


def build_yonler(z=5, view=(-26.0, -38.0, 26.0, 18.0), variants=None, fname="sirt_yonler.png"):
    variants = variants or VARIANTS[1:]
    tw, th = int((view[2] - view[0]) * z), int((view[3] - view[1]) * z)
    rows = []
    hd = header(140 + (tw + 4) * len(YON_T), "Silahlar sırtta · 4 yön + çekiş/kına giriş anı (x5)",
                "satır = varyant, sütun = bakış yönü; sırttaki silah karakterle aynı piksel ızgarasında")
    for v, a, b in variants:
        lab = Image.new("RGB", (140, th), (30, 34, 32))
        d = ImageDraw.Draw(lab)
        label(d, 8, 8, a, 12)
        label(d, 8, 28, b, 9, (220, 214, 198))
        cells = [lab]
        for t, nm in YON_T:
            vw = view if nm not in ("çekiş anı", "kına giriş") else (-40.0, -72.0, 40.0, 18.0)
            zz = z if vw is view else max(2, int(round(z * (view[3] - view[1]) / (vw[3] - vw[1]))))
            im = render(v, t, zz, vw).resize((tw, th), Image.NEAREST) if vw is not view else render(v, t, z, view)
            d = ImageDraw.Draw(im)
            label(d, 4, 2, nm, 10)
            cells.append(im)
        W = sum(c.width for c in cells) + 4 * (len(cells) - 1)
        row = Image.new("RGB", (W, th), (18, 20, 20))
        x = 0
        for c in cells:
            row.paste(c, (x, 0))
            x += c.width + 4
        rows.append(row)
    os.makedirs(OUT, exist_ok=True)
    stack_v([hd] + rows).save(os.path.join(OUT, fname))
    print("png", os.path.join(OUT, fname))


if __name__ == "__main__":
    what = sys.argv[1:] or ["yonler", "oyun", "yakin"]
    if "yonler" in what:
        build_yonler()
    if "oyun" in what:
        build_gif(2, (-75.0, -80.0, 75.0, 28.0), "sirt_oyun.gif", 25, 3, "Silahlar sırtta · oyun ölçeği (1080p), gerçek hız")
    if "yakin" in what:
        build_gif(4, (-34.0, -74.0, 34.0, 22.0), "sirt_yakin.gif", 25, 6, "Silahlar sırtta · x4 yakın, gerçek hız")
    if "alcak" in what:  # A'nın alçak sürümleri (A / A2 / A3)
        build_yonler(variants=VARIANTS_ALCAK, fname="sirt_A_alcak_yonler.png")
    if "alcak_gif" in what:
        build_gif(2, (-75.0, -80.0, 75.0, 28.0), "sirt_A_alcak_oyun.gif", 25, 4, "A alçak · oyun ölçeği (1080p), gerçek hız",
                  VARIANTS_ALCAK)
        build_gif(4, (-34.0, -74.0, 34.0, 22.0), "sirt_A_alcak_yakin.gif", 25, 4, "A alçak · x4 yakın, gerçek hız", VARIANTS_ALCAK)
