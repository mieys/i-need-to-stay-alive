# -*- coding: utf-8 -*-
"""YAKIN DÖVÜŞ SALDIRI ARDIL GÖRÜNTÜSÜ prototipleri (2026-10-19, oyuna bağlı DEĞİL; madde 295'in düzeltmesi). Kullanıcı: "silahlar
konusunda da beni yanlış anladın, saldırı efektleri zaten var benim isteğim saldırı hareketine geçtikleri anda efekt olması (hareket
ederkenki arkasında iz bırakma efekti gibi senle kapattığımız o efektin daha az dikkat çekici hali gibi olmalı)".

"Kapattığımız efekt" = madde 247'nin ARDIL GÖRÜNTÜSÜ (madde 256'da kaldırıldı): süzülen silahın son 12 fizik karesinden 4/7/11 kare
önceki hâlinde düz soğuk tonlu (206,226,255) silüet, saydamlık 0,45/0,28/0,16. Burada aynı fikir SADECE saldırı hareketi boyunca
(saldırı başından vuruş bitimine: kılıç yaklaşma + süpürme + takip 0,32 sn, bıçak 3 saplama 0,43, topuz kaldır-indir-sek 0,40,
pençe sin-atıl-yırt 0,30; dönüşte yok) ve daha soluk. Oyundaki saldırı hareketi + TÜM mevcut efektler (kılıç hilali, bıçak
kıvılcımı - artık tek çizik, topuz/pençe lekesi, çatlak, toz) AYNEN durur; ardıl görüntü bunların ALTINDA, silahın arkasında.
Hayalet hıza bağlı: aradaki yol (gecikme başına) 60 px/sn altında görünmez, 300 px/sn'de tam (saplı bekleme / tepe duruşunda yok).
  ESKİ (kapatılan) - karşılaştırma için madde 247'nin değerleri, saldırıya uygulanmış hâli.
  A Soluk Ardıl     - 2 düz soğuk ton hayalet, 3/6 kare geride, a 0,22 / 0,11.
  B Kendi Renginde  - 3 hayalet silahın KENDİ renginde (%45 soğuk tona çekilmiş), 2/4/6 kare geride, a 0,26 / 0,15 / 0,07.
  C Yumuşak Bulanıklık - 5 sık düz hayalet (her kare), a 0,12 -> 0,04: yavaşken silahın altında kalır, hızlanınca bulanık iz.
Çıktılar (out/yakin_ardil/): ardil_<silah>.gif (1080p gerçek hız, ŞU AN + ESKİ + A/B/C), ardil_yavas.gif (hepsi x0,25), ardil_ozet.png.
Çalıştırma: python tools/proto_20261019/yakin_ardil_proto.py [oyun|yavas|ozet]
"""
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import yakin_iz_proto as YI  # noqa: E402
from yakin_iz_proto import BP, TP, PP, WPP, Z, FWD, ORDER, WEAPONS, INTERVAL, hstack, tile_label, header, stack_v, save_gif  # noqa: E402
from mermi_proto import asset  # noqa: E402

BP.B_SIDE_LINES = False  # ŞU AN bıçak = oyundaki düzeltilmiş sayfa (madde 299: tek çizik)
YI.KEEP_CUR_FX = True

OUT = os.path.join(HERE, "out", "yakin_ardil")
FPS = 30
TINT = (206, 226, 255)  # madde 247 WeaponFollowFx ghost tonu
F60 = 1.0 / 60.0
GHOSTS = {
    "ESKI": dict(mode="flat", lag=[4 * F60, 7 * F60, 11 * F60], alpha=[0.45, 0.28, 0.16]),
    "A": dict(mode="flat", lag=[3 * F60, 6 * F60], alpha=[0.22, 0.11]),
    "B": dict(mode="own", lag=[2 * F60, 4 * F60, 6 * F60], alpha=[0.26, 0.15, 0.07]),
    "C": dict(mode="flat", lag=[k * F60 for k in range(1, 6)], alpha=[0.12, 0.10, 0.08, 0.06, 0.04]),
}
ATTACK_END = {"uzunkilic": YI.SW_APPROACH + YI.SW_SWEEP + YI.SW_FOLLOW, "dagger": 0.43, "topuz": 0.40, "pence": 0.30}
V0, V1 = 60.0, 300.0  # hız kapısı (dünya px/sn)
VARS = [("cur", "ŞU AN (oyundaki)", None), ("ESKI", "ESKİ ardıl (kapatılan, madde 247)", "4/7/11 kare geride, a 0,45 / 0,28 / 0,16"),
        ("A", "A · Soluk Ardıl", "2 düz soğuk hayalet, a 0,22 / 0,11"),
        ("B", "B · Kendi Renginde", "3 hayalet silahın renginde, a 0,26 / 0,15 / 0,07"),
        ("C", "C · Yumuşak Bulanıklık", "5 sık hayalet a 0,12 -> 0,04, hızlanınca bulanır")]
CUR_SUB = dict(YI.CUR_SUB, dagger="Kıvılcım Saplama (düzeltildi: tek çizik)")

_ICON = {}


def icon_img(key):
    if key not in _ICON:
        _ICON[key] = {"uzunkilic": lambda: asset("assets/weapons/zanaat/uzunkilic_L3.png"), "dagger": BP.icon, "topuz": TP.icon,
                      "pence": PP.icon}[key]().convert("RGBA")
    return _ICON[key]


_GH = {}


def ghost_img(key, mode, alpha):
    q = round(alpha, 2)
    k = (key, mode, q)
    if k not in _GH:
        a = np.asarray(icon_img(key), dtype=np.float32).copy()
        t = np.array(TINT, np.float32)
        a[..., :3] = t if mode == "flat" else a[..., :3] * 0.55 + t * 0.45
        a[..., 3] *= q
        _GH[k] = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")
    return _GH[k]


def center(key, ta, n):
    if key == "uzunkilic":
        return YI.sw_pose(ta, YI.sw_side(n))[0]
    if key == "dagger":
        return YI._BMO.pos(ta)
    if key == "topuz":
        return YI._TTR.head(ta)
    x, y = YI._PTR.pose(ta)[:2]
    return (x, y)


def blit_pose(F, key, ta, n, img):
    if key == "uzunkilic":
        c, a = YI.sw_pose(ta, YI.sw_side(n))
        TP.blit(F, img, *TP.S(c), WPP * Z, a - FWD)
    elif key == "dagger":
        p, a, sc = YI._BMO.pos(ta), YI._BMO.ang(ta), YI._BMO.scale(ta)
        BP.blit(F, img, *BP.S(p), WPP * Z * sc, a - BP.REST_ANG)
    elif key == "topuz":
        x, y, a, sl, sw = YI._TTR.pose(ta)
        TP.blit_mace(F, img, TP.S((x, y)), a, WPP * Z, YI._TTR.piv, sl, sw)
    else:
        x, y, a, sl, sw = YI._PTR.pose(ta)
        TP.blit_mace(F, img, PP.S((x, y)), a, WPP * Z, YI._PTR.piv, sl, sw)


def draw_ghosts(F, key, var, ta, n, lw, lh):
    """yakin_iz_proto lane'lerinin ikon öncesi kancası (draw_trail yerine)."""
    G = GHOSTS[var]
    c0 = center(key, ta, n)
    for lag, al in reversed(list(zip(G["lag"], G["alpha"]))):  # en eski önce (en yenisi silaha en yakın, üstte)
        tg = ta - lag
        if tg < 0.0 or tg > ATTACK_END[key]:
            continue
        cg = center(key, tg, n)
        v = math.hypot(c0[0] - cg[0], c0[1] - cg[1]) / lag
        k = min(1.0, max(0.0, (v - V0) / (V1 - V0)))
        if k <= 0.02:
            continue
        blit_pose(F, key, tg, n, ghost_img(key, G["mode"], al * k))


YI.draw_trail = draw_ghosts


def lane_set(key):
    return [YI.LANES[key](i) for i in range(len(VARS))]


def sub_of(key, vid, sub):
    return CUR_SUB[key] if vid == "cur" else sub


def build_oyun():
    os.makedirs(OUT, exist_ok=True)
    loop = 2.0 * INTERVAL
    nfr = int(round(loop * FPS))
    dt = loop / nfr
    for key in ORDER:
        lanes = lane_set(key)
        frames = []
        for i in range(nfr):
            t = i * dt
            parts = []
            for ln, (vid, title, sub) in zip(lanes, VARS):
                if hasattr(ln, "step"):
                    ln.step(t, dt)
                parts.append(tile_label(ln.render(t, vid), title, sub_of(key, vid, sub)))
            hd = header(parts[0].width, "%s · saldırı hareketinde ardıl görüntü (prototip, oyuna bağlı değil)" % WEAPONS[key]["name"],
                        "1080p oyun ölçeği, gerçek hız · saldırı + mevcut efektler oyundaki gibi · ardıl sadece saldırı hareketinde (dönüşte yok)")
            frames.append(stack_v([hd] + parts, 3))
        hit = WEAPONS[key]["contacts"][0] + 0.15
        save_gif(frames, os.path.join(OUT, "ardil_%s.gif" % key), FPS, [int(hit * FPS), int((hit - 0.05) * FPS), int((hit + 0.05) * FPS)])


def build_yavas(speed=0.25):
    os.makedirs(OUT, exist_ok=True)
    span = 0.5
    nfr = int(round(span / speed * 25))
    sets = {k: lane_set(k) for k in ORDER}
    frames = []
    for i in range(nfr):
        ta = i * span / nfr
        t = 0.15 + ta
        rows = []
        for key in ORDER:
            cells = []
            for ln, (vid, title, _) in zip(sets[key], VARS):
                if hasattr(ln, "step"):
                    ln.step(t, span / nfr)
                cells.append(tile_label(YI.crop_cell(ln.render(t, vid), key), "%s · %s" % (WEAPONS[key]["name"], title.split(" (")[0])))
            rows.append(hstack(cells))
        hd = header(rows[0].width, "Saldırı ardıl görüntüsü · x0,25 yavaş (tek saldırı, hedef çevresi, 1080p ölçek)",
                    "ŞU AN · ESKİ (kapatılan) · A Soluk Ardıl · B Kendi Renginde · C Yumuşak Bulanıklık  ·  saldırı +%.2f sn" % ta)
        frames.append(stack_v([hd] + rows, 3))
    save_gif(frames, os.path.join(OUT, "ardil_yavas.gif"), 25, [int(nfr * 0.25), int(nfr * 0.4), int(nfr * 0.55)])


def build_ozet():
    os.makedirs(OUT, exist_ok=True)
    moments = {"uzunkilic": [0.10, 0.18], "dagger": [0.12, 0.32], "topuz": [0.13, 0.25], "pence": [0.12, 0.24]}
    rows = []
    for key in ORDER:
        for ta in moments[key]:
            cells = []
            for ln, (vid, title, _) in zip(lane_set(key), VARS):
                if hasattr(ln, "step"):
                    tt = 0.0
                    while tt < 0.15 + ta:
                        ln.step(tt, 1.0 / 120.0)
                        tt += 1.0 / 120.0
                c = YI.crop_cell(ln.render(0.15 + ta, vid), key)
                c = c.resize((c.width * 2, c.height * 2), Image.NEAREST)
                cells.append(tile_label(c, "%s · %s · +%.2f sn" % (WEAPONS[key]["name"], title.split(" (")[0], ta)))
            rows.append(hstack(cells))
    im = stack_v([header(rows[0].width, "Saldırı ardıl görüntüsü · özet (x2 yakın)", "ŞU AN · ESKİ · A · B · C")] + rows, 3)
    im.save(os.path.join(OUT, "ardil_ozet.png"))
    print("ozet", im.size)


if __name__ == "__main__":
    what = sys.argv[1:] or ["ozet", "yavas", "oyun"]
    if "ozet" in what:
        build_ozet()
    if "yavas" in what:
        build_yavas()
    if "oyun" in what:
        build_oyun()
