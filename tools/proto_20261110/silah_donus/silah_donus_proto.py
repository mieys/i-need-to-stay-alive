# -*- coding: utf-8 -*-
"""MENZİLLİ SİLAH DÖNÜŞ HIZI prototipi (2026-11-10, oyuna bağlı DEĞİL). Kullanıcı: "menzilli silahlar hedef değiştirirken anında
dönmesin, biraz daha yavaş dönsün; dönerken ateş etmeye devam edebilir. Hızlarını kademe olarak gösteren gif prototipleri."

Bugün (weapon.gd _update_aim -> _face_dir): her karede lerp_angle(ikon, hedef, delta x AIM_EASE_RATE 12) - ÜSTEL yumuşatma, hız sınırı
YOK (büyük fark ilk karede çok hızlı kapanır, 140 derece ~0,36 sn). Tabanca aynalanınca (hedef x < silah x) dönüş o karede HEDEFE
atlar (_face_dir "ara kare yok") - yavaş dönüşte bu atlama asıl göze batan şey olur.
Atış (_fire_at): direction = (hedef - silah konumu).normalized - İKONUN dönüşünden BAĞIMSIZ. Yani yavaş dönse de atış hiç durmaz,
mermi hedefe düz gider; ikon yetişene kadar yan bakıyor olabilir (prototip bunu olduğu gibi gösterir: mermi namlu ucundan çıkar,
hedefe doğru uçar).

Prototip modeli: silah "dünya nişan açısı" tutar (aynalama dönüşten türetilir -> Tabanca dikeyi geçerken yön kesintisiz, sadece
ikon aynalanır), her karede açısal hız = min(fark x 12/sn'lik üstel yumuşatma, KADEME SINIRI derece/sn). Küçük farklarda bugünkü
yumuşaklık aynen, sınır sadece büyük savurmada devreye girer.
Kademeler: ŞU AN (sınır yok) / K1 480 / K2 300 / K3 180 / K4 110 derece/sn (büyük savurma ~0,36 -> 0,5 -> 0,65 -> 0,9 -> 1,4 sn).

Sahne: Şovalye duruyor, Ateş Asası (sağ) + Tabanca (sol) süzülüyor, 3 duran slime sırayla (sağ -> sol üst -> sol alt) vuruluyor, ölünce
hedef değişir. Atış takvimi kademeden bağımsız (Asa 0,75 sn, Tabanca 0,5 sn) - kademeler yan yana ve eş zamanlı.

Çıktılar (out/): donus_kademeler.gif (1080p oyun ölçeği, gerçek hız, 5 kademe + bilgi), donus_kareler.png (büyük savurma kare şeridi).
Çalıştırma: python tools/proto_20261110/silah_donus/silah_donus_proto.py [oyun|kareler]   (argümansız: ikisi)
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "proto_20261017"))
import silah_takip_proto as T  # noqa: E402  (zemin, Şovalye, slime, çizici yardımcıları)
from silah_takip_proto import (blit2, line_w, star, ellipse, ground, char_frame, icon_np, slime_frame, SLIME_K, WPP,  # noqa: E402
                               CHAR_K, CHAR_OFF_Y, START, SLOTS, SLOTS_LOCAL, hover_shadow_gap, cur_shadow_radii, label)

OUT = os.path.join(HERE, "out")
D2R = math.pi / 180.0
FPS = 50  # GIF gecikmesi 1/100 sn'ye yuvarlanır: 50 fps = tam 20 ms (40 fps 25 ms -> 20 ms'ye düşüp %25 hızlı oynardı)
DT = 1.0 / FPS
LOOP = 7.5  # 10 slime animasyon periyodu (0,75 sn) = 3 süzülme periyodu (2,5 sn) = GIF dikişsiz
N = int(round(LOOP * FPS))
P = START
VIEW = (-96.0, -84.0, 96.0, 34.0)  # oyuncuya göre dünya penceresi
BOB_W = 2.0 * math.pi * 3.0 / LOOP

# P'ye göre slime konumları (dünya px) ve ölüm zamanları - sırayla hedef
ENEMY = [(74.0, 8.0), (-76.0, -46.0), (-28.0, 24.0)]
DIE = [2.3, 4.6, 6.9]
POP, DEATH_T = 0.30, 0.30

# silahlar: (anahtar, slot indeksi T.SLOTS, sprite_forward_angle_deg, aynalı mı, atış aralığı, faz, mermi hızı, tür)
WEAPONS = [
    dict(key="fire_staff", slot=1, fwd=-45.0, mirror=False, period=0.75, phase=0.30, spd=250.0, kind="fire", bob=T.CUR_PHASES[1]),
    dict(key="tabanca", slot=2, fwd=0.0, mirror=True, period=0.50, phase=0.10, spd=380.0, kind="bullet", bob=T.CUR_PHASES[2]),
]
# (başlık, derece/sn sınırı, alt başlık)
LEVELS = [
    ("ŞU AN", None, "sınır yok · üstel yumuşatma 12/sn"),
    ("KADEME 1", 480.0, "çevik"),
    ("KADEME 2", 300.0, "dengeli"),
    ("KADEME 3", 180.0, "ağır"),
    ("KADEME 4", 110.0, "çok ağır"),
]

CREAM = (255, 246, 220)
FIRE_COL = (255, 150, 52)
FIRE_CORE = (255, 232, 150)
SLIME_COL = (120, 216, 226)  # Slime1 mavi-camgöbeği


def ang_diff(a, b):
    d = (b - a + 180.0) % 360.0 - 180.0
    return 180.0 if d == -180.0 else d


def clamp(x, a, b):
    return a if x < a else b if x > b else x


def tip_radius(key, fwd_deg):
    """İkon merkezinden, ileri yönde en uzak opak piksele uzaklık (dünya px) = namlu / asa ucu."""
    a = icon_np(key)[..., 3]
    h, w = a.shape
    ys, xs = np.nonzero(a > 0)
    fx, fy = math.cos(fwd_deg * D2R), math.sin(fwd_deg * D2R)
    return float(((xs + 0.5 - w / 2.0) * fx + (ys + 0.5 - h / 2.0) * fy).max()) * WPP


for _w in WEAPONS:
    _w["tip"] = tip_radius(_w["key"], _w["fwd"])


def wpos(w, t):
    """Süzülen silahın dünya px'e yuvarlı konumu (oyundaki gibi)."""
    bob = math.sin(t * BOB_W + w["bob"]) * 1.75
    s = SLOTS[w["slot"]]
    return (round(P[0] + s[0]), round(P[1] + s[1] + bob)), bob


def target_index(tm):
    for i, d in enumerate(DIE):
        if tm < d:
            return i
    return None


def icon_pose(w, aim):
    """Nişan açısından ikon dönüşü + aynalama (weapon_follow_math.gd face_rotation, süreklilik için dünya açısından türetilir)."""
    if not w["mirror"]:
        return aim - w["fwd"], False
    flip = math.cos(aim * D2R) < 0.0
    return ((aim - 180.0 + w["fwd"]) if flip else (aim - w["fwd"])), flip


def simulate(vmax):
    """İki döngü koşturur, ikincisinin karelerini döner. Her kare: silah durumları, mermiler, kıvılcımlar, slime durumları."""
    aim = [None, None]
    rc = [0.0, 0.0]  # geri tepme (1 -> 0)
    mf = [0.0, 0.0]  # namlu parıltısı (1 -> 0)
    bullets, sparks = [], []
    flash = [0.0] * 3
    frames = []
    switches = []  # (savurma açısı, yakalama süresi) - Asa için
    pend = None
    prev_tgt = None
    for step in range(2 * N):
        t = step * DT
        tm = t % LOOP
        if step % N == 0:
            bullets, sparks = [], []
        ti = target_index(tm) if tm >= 0.15 else None
        # --- dönüş
        errs = []
        d0 = 0.0  # Asa'nın bu karede dönüşten ÖNCEKİ farkı (savurma büyüklüğü ölçümü)
        for i, w in enumerate(WEAPONS):
            (wx, wy), _ = wpos(w, t)
            if ti is None:
                errs.append(0.0)
                continue
            tx, ty = P[0] + ENEMY[ti][0], P[1] + ENEMY[ti][1] + 3.0
            want = math.degrees(math.atan2(ty - wy, tx - wx))
            if aim[i] is None:
                aim[i] = want
            d = ang_diff(aim[i], want)
            if i == 0:
                d0 = abs(d)
            st = d * (1.0 - 0.8 ** (60.0 * DT))
            if vmax is not None:
                st = clamp(st, -vmax * DT, vmax * DT)
            aim[i] += st
            errs.append(abs(ang_diff(aim[i], want)))
        # Asa için savurma ölçümü (ikinci döngü): hedef değişince başlat, hata < 3 derece olunca bitir
        if step >= N:
            if ti != prev_tgt and ti is not None:
                pend = [t, d0, None]
                switches.append(pend)
            if pend is not None and pend[2] is None and ti is not None and errs[0] < 3.0:
                pend[2] = t - pend[0]
        prev_tgt = ti
        # --- atış (hedef varken, dönüşü beklemeden)
        for i, w in enumerate(WEAPONS):
            if ti is None or aim[i] is None:
                continue
            n_now = math.floor((t - w["phase"]) / w["period"] + 1e-9)
            n_prev = math.floor((t - DT - w["phase"]) / w["period"] + 1e-9)
            if n_now != n_prev:
                (wx, wy), _ = wpos(w, t)
                ex, ey = P[0] + ENEMY[ti][0], P[1] + ENEMY[ti][1] + 3.0
                dx, dy = ex - wx, ey - wy
                L = math.hypot(dx, dy)
                ox, oy = wx + math.cos(aim[i] * D2R) * w["tip"], wy + math.sin(aim[i] * D2R) * w["tip"]  # namlu ucu (ikonun BAKTIĞI yer)
                bullets.append(dict(x=ox, y=oy, vx=dx / L * w["spd"], vy=dy / L * w["spd"], tgt=ti, kind=w["kind"],
                                    ex=ex, ey=ey, left=math.hypot(ex - ox, ey - oy), trail=[]))
                rc[i], mf[i] = 1.0, 1.0
        # --- mermiler
        keep = []
        for b in bullets:
            b["trail"].append((b["x"], b["y"]))
            b["trail"] = b["trail"][-4:]
            mv = math.hypot(b["vx"], b["vy"]) * DT
            b["x"] += b["vx"] * DT
            b["y"] += b["vy"] * DT
            b["left"] -= mv
            if b["left"] <= 0.0:
                flash[b["tgt"]] = 0.09
                sparks.append(dict(x=b["ex"], y=b["ey"], t0=t, kind="hit", fire=b["kind"] == "fire"))
            else:
                keep.append(b)
        bullets = keep
        for k in range(3):
            if tm >= DIE[k] and tm - DIE[k] < DT * 1.01:
                for a in range(7):
                    sparks.append(dict(x=P[0] + ENEMY[k][0], y=P[1] + ENEMY[k][1] + 2.0, t0=t, kind="puff", ang=a * 51.4 + k * 17.0))
        sparks = [s for s in sparks if t - s["t0"] < 0.35]
        # --- kare kaydı (ikinci döngü)
        if step >= N:
            ws = []
            for i, w in enumerate(WEAPONS):
                (wx, wy), bob = wpos(w, t)
                a = aim[i] if aim[i] is not None else 0.0
                rot, flip = icon_pose(w, a)
                kick = rc[i] * 1.8
                ws.append(dict(pos=(wx - math.cos(a * D2R) * kick, wy - math.sin(a * D2R) * kick), rot=rot, flip=flip, aim=a,
                               flash=mf[i], bob=bob / 1.75))
            sl = []
            for k in range(3):
                if tm < DIE[k]:
                    sc = clamp(tm / POP, 0.0, 1.0) if tm < POP else 1.0
                    sl.append(dict(scale=sc, flash=flash[k], dead=0.0))
                elif tm < DIE[k] + DEATH_T:
                    sl.append(dict(scale=1.0 - (tm - DIE[k]) / DEATH_T, flash=0.6, dead=(tm - DIE[k]) / DEATH_T))
                else:
                    sl.append(None)
            frames.append(dict(t=t, tm=tm, ws=ws, bullets=[dict(b, trail=list(b["trail"])) for b in bullets],
                               sparks=[dict(s) for s in sparks], slimes=sl, tgt=ti, err=errs[0]))
        for i in range(2):
            rc[i] = max(0.0, rc[i] - DT / 0.12)
            mf[i] = max(0.0, mf[i] - DT / 0.07)
        for k in range(3):
            flash[k] = max(0.0, flash[k] - DT)
    return frames, switches


# ------------------------------------------------------------------ çizim
def render(fr, z, view=VIEW):
    G = ground(z)
    cx0 = int(round((P[0] + view[0]) * z))
    cy0 = int(round((P[1] + view[1]) * z))
    Wd, Hd = int((view[2] - view[0]) * z), int((view[3] - view[1]) * z)
    F = G[cy0:cy0 + Hd, cx0:cx0 + Wd].astype(np.float32).copy()

    def S(p):
        return (p[0] * z - cx0, p[1] * z - cy0)

    # silah gölgeleri (karakterin altında)
    for i, w in enumerate(WEAPONS):
        wd = fr["ws"][i]
        gap = (hover_shadow_gap(SLOTS_LOCAL[w["slot"]][1]) * 2.0 + wd["bob"] * 3.0) * 0.5
        rx, ry = cur_shadow_radii(w["key"], wd["bob"])
        sx, sy = S((round(wd["pos"][0]), round(wd["pos"][1]) + gap))
        ellipse(F, sx, sy, rx * z, ry * z, (0, 0, 0), 0.32 * 0.4)

    def draw_slime(k):
        s = fr["slimes"][k]
        if s is None:
            return
        ex, ey = S((P[0] + ENEMY[k][0], P[1] + ENEMY[k][1]))
        sc = max(0.02, s["scale"])
        args = (F, slime_frame(fr["tm"], k), ex, ey + (1.0 - sc) * 10.0 * z, SLIME_K * z, 0.0, sc, sc)
        blit2(*args)
        if s["flash"] > 0.0:
            blit2(*args, alpha=min(1.0, s["flash"] * 4.0 if s["dead"] == 0.0 else 0.55), tint=(255, 250, 236))

    for k in range(3):
        if ENEMY[k][1] < 0.0:
            draw_slime(k)
    sx, sy = S((P[0], P[1] + 12.0))
    ellipse(F, sx, sy, 9.0 * z, 3.5 * z, (0, 0, 0), 0.32)
    chf = char_frame(False, (0, 1), 0.0, fr["t"])
    sx, sy = S((P[0], P[1] + CHAR_OFF_Y))
    blit2(F, chf, sx, sy, CHAR_K * z)
    for k in range(3):
        if ENEMY[k][1] >= 0.0:
            draw_slime(k)

    # silahlar
    for i, w in enumerate(WEAPONS):
        wd = fr["ws"][i]
        x, y = S(wd["pos"])
        fl = -1.0 if wd["flip"] else 1.0
        blit2(F, icon_np(w["key"]), x, y, WPP * z, wd["rot"] * D2R, fl, 1.0)
        if wd["flash"] > 0.0:  # namlu parıltısı (ikonun baktığı uç)
            a = wd["aim"] * D2R
            tx, ty = S((wd["pos"][0] + math.cos(a) * (w["tip"] + 1.5), wd["pos"][1] + math.sin(a) * (w["tip"] + 1.5)))
            star(F, tx, ty, (2.0 + 2.5 * wd["flash"]) * z, FIRE_CORE if w["kind"] == "fire" else CREAM, 0.95 * wd["flash"], z)

    # mermiler
    for b in fr["bullets"]:
        n = len(b["trail"])
        for j, (px, py) in enumerate(b["trail"]):
            f = (j + 1) / (n + 1)
            qx, qy = S((px, py))
            if b["kind"] == "fire":
                ellipse(F, qx, qy, 2.0 * f * z, 2.0 * f * z, FIRE_COL, 0.45 * f)
            else:
                ellipse(F, qx, qy, 0.8 * f * z, 0.8 * f * z, (255, 224, 140), 0.5 * f)
        qx, qy = S((b["x"], b["y"]))
        if b["kind"] == "fire":
            ellipse(F, qx, qy, 3.0 * z, 3.0 * z, FIRE_COL, 0.85)
            ellipse(F, qx, qy, 1.6 * z, 1.6 * z, FIRE_CORE, 1.0)
        else:
            ellipse(F, qx, qy, 1.3 * z, 1.3 * z, (255, 240, 170), 1.0)
    for s in fr["sparks"]:
        age = fr["t"] - s["t0"]
        if s["kind"] == "hit" and age < 0.12:
            qx, qy = S((s["x"], s["y"]))
            star(F, qx, qy, (3.5 - age * 12.0) * z, FIRE_CORE if s["fire"] else CREAM, 1.0 - age / 0.12, z)
        elif s["kind"] == "puff":
            f = age / 0.3
            qx, qy = S((s["x"] + math.cos(s["ang"] * D2R) * 14.0 * f, s["y"] + math.sin(s["ang"] * D2R) * 8.0 * f - 4.0 * f))
            ellipse(F, qx, qy, 1.6 * (1.0 - f) * z + 0.5, 1.6 * (1.0 - f) * z + 0.5, SLIME_COL, 1.0 - f)
    return Image.fromarray(np.clip(F, 0, 255).astype(np.uint8), "RGB")


def fmt_sec(x):
    return ("%.2f" % x).replace(".", ",")


def swing_info(sw):
    """En büyük savurmanın (derece, yakalama süresi sn)."""
    done = [s for s in sw if s[2] is not None]
    if not done:
        return None
    s = max(done, key=lambda q: q[1])
    return s[1], s[2]


BAND = 30  # karenin altındaki etiket şeridi (slime'ların üstüne binmesin)


def tile_text(im, title, sub, bottom, err):
    d = ImageDraw.Draw(im)
    label(d, 6, 3, title, 12)
    label(d, 6, 17, sub, 9, (232, 226, 210))
    tile = Image.new("RGB", (im.width, im.height + BAND), (30, 34, 32))
    tile.paste(im, (0, 0))
    d = ImageDraw.Draw(tile)
    label(d, 6, im.height + 3, bottom, 10, (255, 214, 120))
    label(d, 6, im.height + 17, "Asa nişanı hedefin gerisinde: %3d°" % int(round(err)), 9, (232, 226, 210))
    return tile


def build_gif():
    z = 2
    sims = []
    for title, vmax, sub in LEVELS:
        fr, sw = simulate(vmax)
        sims.append((title, vmax, sub, fr, sw))
    tw, th = int((VIEW[2] - VIEW[0]) * z), int((VIEW[3] - VIEW[1]) * z)
    hd = T.header(tw * 3 + 8, "Menzilli silah dönüş hızı · kademeler · oyun ölçeği (1080p), gerçek hız",
                  "hedef sırası: sağ → sol üst → sol alt (ölünce değişir) · atış hiç durmaz, mermi hedefe düz gider · ikon yetişene kadar yan bakabilir")
    infos = []
    for title, vmax, sub, fr, sw in sims:
        si = swing_info(sw)
        infos.append("büyük savurma %d° = %s sn" % (round(si[0]), fmt_sec(si[1])) if si else "")
        print(title, "tüm savurmalar (derece, sn):", [(round(s[1]), None if s[2] is None else round(s[2], 2)) for s in sims[len(infos) - 1][4]])
    lines = [
        "Şovalye + Ateş Asası (sağ) + Tabanca (sol)",
        "3 duran slime sırayla vurulur, hedef değişir",
        "atış takvimi kademeden bağımsız: Asa 0,75 sn,",
        "  Tabanca 0,5 sn (dönerken de aynı)",
        "kademe = en çok derece/sn; fark küçülünce",
        "  bugünkü yumuşatma (12/sn) aynen sürer",
        "Tabanca dikeyi geçerken aynalanır, yön kesintisiz",
        "  (oyunda şimdi hedefe ATLIYOR)",
        "kamera sabit, %d fps, 1080p ölçek" % FPS,
    ]
    frames = []
    for k in range(N):
        tiles = []
        for idx, (title, vmax, sub, fr, sw) in enumerate(sims):
            im = render(fr[k], z)
            head = title if vmax is None else "%s · %d°/sn" % (title, vmax)
            tiles.append(tile_text(im, head, sub, infos[idx], fr[k]["err"]))
        info = T.info_tile(tw, th + BAND, lines, "Dönüş hızı kademeleri")
        d = ImageDraw.Draw(info)
        label(d, 10, th + BAND - 20, "%.2f sn" % fr[k]["tm"], 12, (255, 214, 120))
        tiles.append(info)
        frames.append(T.stack_v([hd, T.grid(tiles, 3)]))
    os.makedirs(OUT, exist_ok=True)
    T.save_gif(frames, os.path.join(OUT, "donus_kademeler.gif"), FPS, [int(1.0 * FPS), int(3.0 * FPS), int(5.0 * FPS)])
    frames[int(2.3 * FPS) + 6].save(os.path.join(OUT, "donus_kare.png"))
    return sims


def build_strip(sims=None):
    """Büyük savurma (A -> B, t = 2,3 sn) kare şeridi: satır = kademe, sütun = hedef değişiminden sonraki süre."""
    z = 1
    if sims is None:
        sims = []
        for title, vmax, sub in LEVELS:
            fr, sw = simulate(vmax)
            sims.append((title, vmax, sub, fr, sw))
    offs = [0.0, 0.1, 0.2, 0.35, 0.55, 0.8, 1.2]
    rows = []
    for title, vmax, sub, fr, sw in sims:
        tiles = []
        for o in offs:
            k = min(N - 1, int(round((DIE[0] + o) * FPS)))
            im = render(fr[k], z)
            d = ImageDraw.Draw(im)
            label(d, 4, 2, ("%s" % title) if o == 0.0 else "", 9)
            label(d, 4, im.height - 13, "+%s sn" % fmt_sec(o), 9, (255, 214, 120))
            tiles.append(im)
        rows.append(T.grid(tiles, len(offs), gap=2))
    os.makedirs(OUT, exist_ok=True)
    big = T.stack_v(rows, 2)
    big.save(os.path.join(OUT, "donus_kareler.png"))
    print("png", os.path.join(OUT, "donus_kareler.png"), big.size)
    return sims


if __name__ == "__main__":
    what = sys.argv[1:] or ["oyun", "kareler"]
    sims = None
    if "oyun" in what:
        sims = build_gif()
    if "kareler" in what:
        build_strip(sims)
