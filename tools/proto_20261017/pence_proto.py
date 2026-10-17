# -*- coding: utf-8 -*-
"""PENÇE vuruş animasyonu + efekti PROTOTİPLERİ (2026-10-17, oyuna bağlı DEĞİL). Kullanıcı: "pençenin animasyonu ve efekti için
yeni 4 prototip hazırlar mısın".

Bugün (teşhis; weapon_pence.tscn + player.gd _configure_pence_melee + weapon.gd _do_melee_swing / _spawn_slash_fx):
  - Menzil 110, 2 parça ("çift pençe darbesi"), alan hasarı yarıçap 60 dünya px (yarı hasar). Aralık 1,1111 / 0,7 = 1,59 sn.
    Bıçak (madde 231) ve Topuz kendi animasyonlarına geçti; eski "Z" zikzak yolunu kullanan SON yakın dövüş silahı Pençe.
  - İkon hedefin 8 px önü + saldırı yönüne dik 24 px'e uçar (0,12 sn), karşı yana geçer (0,09 sn) = tek yatay süpürme; efekt
    bitene kadar (12 kare / 30 fps = 0,40 sn) bekler, 0,26 sn'de döner. Hasar 2 parça ATIŞ ANINDA (0 / 0,1 sn): ikon varmadan.
  - Efekt fx_pence_slash (fx_claw_slash.gd): 64 px sayfa, 3 varyant (art arda aynısı gelmez) x 12 kare, pembe-kırmızı 3 kavisli
    çizgi; ölçek 2,424 x sahip 0,5 = 1,21 dünya px/piksel (silahların 0,575'inin İKİ katı iri piksel, ~78 px kare), savuruşun
    merkezinde (hedefin 8 px önü), saldırı yönüyle döner. İsabet kanı (fx_hit_blood_3, yaratık renginde) ayrı; burada çizilmedi.
  - MP: `melee` bayrağı configure_melee'de açılıyor -> kuklanın geçici kopyasında KAPALI, diğer oyuncular pençenin savuruşunu
    görmüyor (madde 231'de bıçakta düzeltildi, Pençe'de duruyor).

Dört yön (1 sanat pikseli = 0,575 dünya px = Zanaatkâr silahları; efekt 30 fps'e kuantalı = sprite sayfası gibi; iki isabet =
iki temas anı; pençe ikon MERKEZİNDEN döner - oyunda Sprite2D offset gerekmez):
  A Üçlü Hilal   - geniş yay + ters yay: her pençe ucundan bir krem hilal izi (3 paralel hilal), temasta kıvılcım. Yönle döner.
  B Kanca Çekiş  - geri sinip atılır, saplanır (1. isabet), titreyip ÇEKEREK yırtar (2. isabet): oyuncuya doğru 3 uzun yırtık,
                   geri saçılan kehribar kıvılcım + toz. Yönle döner.
  C Dev Pençe    - tepeden iki pençe indirir: hedefin üstünde ALAN BOYU (60 px) kehribar hayalet pençe tırmığı, yerde 3 oluk,
                   alan sınırına açılan ince halka, korlar. Dönmez (sola saldırıda aynalanır).
  D Kızıl Tırmık - bugünkü 3 kırmızı çizgi fikri piksel sanatıyla: çizgiler süpürmeyle birlikte açılır, ters süpürme ikinci
                   (ince, hafif çapraz) tırmığı atar, kızıl damlalar düşer. Yönle döner.

Çıktılar (out/pence/): pence_oyun.gif (1080p oyun ölçeği, gerçek hız, 2 vuruş; ŞU AN + A-D), pence_yavas.gif (x0,25 hız, x2
yakın), pence_kareler.png (1. temasa hizalı kare şeridi), pence_oyun_kare.png.
Çalıştırma: python tools/proto_20261017/pence_proto.py [oyun|yavas|kareler]   (argümansız: hepsi)
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bicak_proto as BP  # noqa: E402  (numpy blit, yıldız/çizgi bantları, başlık, GIF)
import topuz_proto as TP  # noqa: E402  (Track, pençe/topuz blit'i, iz/bulut/halka/kıvılcım/kor, aynı efekt tuvali)
from mermi_proto import cl, hx, asset, label, grass  # noqa: E402
from bicak_proto import blit, header, stack_v, save_gif  # noqa: E402
from topuz_proto import Lay, Track, clamp01, ez, np_trail, np_cloud, np_ring, draw_sparks, draw_embers, make_embers  # noqa: E402

OUT = os.path.join(HERE, "out", "pence")
ZOOM = 2.0
WPP = TP.WPP  # 0,575
CHAR_K = 2.2368375 * 0.8075 * 0.5  # Talon dünya px / karakter pikseli
SLIME_K = 0.94905
FPS = 50
INTERVAL = 1.1111 / 0.7  # weapon_pence.tscn fire_rate / GameManager.WEAPON_ATTACK_SPEED_MULT
FXFPS = 30
CUR_FX_K = 2.424 * 0.5  # fx_pence_slash ölçeği x sahip ölçeği
CUR_FX_FPS = 30.0  # claw_frames.tres speed
CUR_FX_N = 12
AOE = 60.0  # player.gd _configure_pence_melee aoe_radius
D2R = math.pi / 180.0

ART_FWD = -math.pi / 4  # zanaat pençesinde tırnaklar sağ-üstte (weapon_tier_art.gd FORWARD)
REST_ANG = ART_FWD  # dinlenmede döndürme yok (REST'te pence yok)
CENTER_PX = (24.0, 24.0)
## üç tırnak ucu (ikon merkezinden, tırnak yönü / dik eksen, dünya px): sanatta ~(4,7 ; -2,4 / 0,2 / 3,3), izler biraz açıldı
TIP_F = 5.0
TIP_S = (-3.8, 0.3, 4.4)

# şerit (dünya px) - topuz_proto ile aynı yerleşim (efekt tuvali TP'ninki, merkez = TGT)
LWW, LHW = TP.LWW, TP.LHW
CHAR = TP.CHAR
REST_C = TP.REST_C
TGT = TP.TGT
G_OFF = TP.G_OFF
DIR_ANG = TP.DIR_ANG
DIRV = TP.DIRV
SC = (TGT[0] - DIRV[0] * 8.0, TGT[1] - DIRV[1] * 8.0)  # savuruş merkezi: hedefin 8 px önü (_do_melee_swing strike_center)
EXTRA_IN = (TGT[0] + 40.0, TGT[1] - 24.0)  # alanın içinde (46 px) -> yarı hasar, parlar
EXTRA_OUT = (TGT[0] + 64.0, TGT[1] + 26.0)  # alanın dışında (69 px) -> parlamaz


def S(p):
    return (p[0] * ZOOM, p[1] * ZOOM)


def off(p):
    return (p[0] - TGT[0], p[1] - TGT[1])


def L2W(p):
    """Yerel çerçeve (orijin SC, +x saldırı yönü, +y = Godot perp (-dir.y, dir.x)) -> dünya."""
    c, s = DIRV
    return (SC[0] + c * p[0] - s * p[1], SC[1] + s * p[0] + c * p[1])


def LO(p):
    """Yerel -> TGT'ye göre (efekt tuvali)."""
    return off(L2W(p))


def LP(x, y, a_deg, sl=1.0, sw=1.0):
    w = L2W((x, y))
    return (w[0], w[1], a_deg * D2R + DIR_ANG, sl, sw)


def WP(x, y, a_deg, sl=1.0, sw=1.0):
    return (x, y, a_deg * D2R, sl, sw)


def tips(tr, t):
    x, y, a, sl, sw = tr.pose(t)
    c, s = math.cos(a), math.sin(a)
    f = TIP_F * sl
    return [(x + f * c - q * sw * s, y + f * s + q * sw * c) for q in TIP_S]


def tip_trail(tr, t, t0, t1, i, win, linger=0.04, eat=0.08, n=10):
    """[t0, t1] boyunca i. tırnak ucunun son `win` saniyelik yolu (en yeni önce, TGT'ye göre); hareket bitince `linger` kadar
    durur, sonra kuyruktan `eat` sürede yenir."""
    if t < t0:
        return []
    te = min(t, t1)
    tb = max(t0, te - win)
    if t > t1 + linger:
        k = (t - t1 - linger) / eat
        if k >= 1.0:
            return []
        tb += (te - tb) * k
    if te - tb < 0.003:
        return []
    return [off(tips(tr, te - (te - tb) * j / (n - 1))[i]) for j in range(n)]


REST_POSE = (REST_C[0], REST_C[1], REST_ANG, 1.0, 1.0)


# ------------------------------------------------------------------ hareketler
# ---- ŞU AN (oyundaki): hedefin önünün +perp 24 px'ine (0,12), -perp 24 px'ine (0,09), efekt boyunca bekle, dön
CUR_FX_HOLD = CUR_FX_N / CUR_FX_FPS
CUR_P1 = L2W((0.0, 24.0))
CUR_P2 = L2W((0.0, -24.0))


def CUR_track():
    a1 = math.atan2(CUR_P1[1] - REST_C[1], CUR_P1[0] - REST_C[0])
    a2 = math.atan2(CUR_P2[1] - CUR_P1[1], CUR_P2[0] - CUR_P1[0])
    tr = Track(REST_POSE, CENTER_PX)
    tr.to(0.12, "out", (CUR_P1[0], CUR_P1[1], a1, 1.0, 1.0))
    tr.to(0.09, "out", (CUR_P2[0], CUR_P2[1], a2, 1.0, 1.0))
    return tr.hold(CUR_FX_HOLD).home(0.26)


# ---- A Üçlü Hilal: yerel çerçevede iki yay (tırnaklar hareket yönüne bakar -> uçlar yarıçap boyunca açılır = 3 hilal)
A_C1, A_R1 = (-14.0, 0.0), 22.0
A_R2 = 17.0
_a_end1 = (A_C1[0] + A_R1 * math.cos(80 * D2R), A_C1[1] + A_R1 * math.sin(80 * D2R))
A_C2 = (_a_end1[0] - A_R2 * math.cos(80 * D2R), _a_end1[1] - A_R2 * math.sin(80 * D2R))
A_HIT1, A_HIT2 = 0.215, 0.325


def _a_pose(c, r, th_deg, back=False):
    th = th_deg * D2R
    return LP(c[0] + r * math.cos(th), c[1] + r * math.sin(th), th_deg + (-90.0 if back else 90.0))


def _arc(c, r, a0, a1, back=False):
    return lambda e: _a_pose(c, r, a0 + (a1 - a0) * e, back)


def A_track():
    tr = Track(REST_POSE, CENTER_PX)
    tr.to(0.12, "out", _a_pose(A_C1, A_R1, -125.0))
    tr.add(0.04, "inout", _arc(A_C1, A_R1, -125.0, -140.0))  # geri ger
    tr.add(0.055, "in", _arc(A_C1, A_R1, -140.0, 0.0))  # savur -> 1. temas
    tr.add(0.04, "out", _arc(A_C1, A_R1, 0.0, 80.0))
    tr.to(0.03, "inout", _a_pose(A_C2, A_R2, 80.0, back=True))  # bilek döner (tırnaklar ters yöne)
    tr.add(0.04, "in", _arc(A_C2, A_R2, 80.0, 0.0, back=True))  # ters yay -> 2. temas
    tr.add(0.035, "out", _arc(A_C2, A_R2, 0.0, -60.0, back=True))
    tr.hold(0.12)
    return tr.home(0.26)


# ---- B Kanca Çekiş
B_HIT1, B_HIT2 = 0.145, 0.235
B_DIG = (0.175, 0.215)  # saplı bekleme


def B_track():
    tr = Track(REST_POSE, CENTER_PX)
    tr.to(0.10, "out", LP(-20.0, -5.0, 0.0, 0.9, 1.06))  # geri sin
    tr.to(0.045, "in", LP(12.0, 0.0, 0.0, 1.15, 0.92))  # atıl -> saplan (1. temas)
    tr.to(0.03, "lin", LP(12.0, 0.0, 0.0, 0.85, 1.12))  # ezil
    base = tr.cur

    def shake(e):  # saplıyken titre (dik eksende ±0,8 px)
        d = 0.8 * math.sin(e * math.pi * 6.0)
        return (base[0] - DIRV[1] * d, base[1] + DIRV[0] * d, base[2], 1.0, 1.0)

    tr.add(B_DIG[1] - B_DIG[0], "lin", shake)
    tr.to(0.03, "out", LP(-14.0, 3.0, 12.0))  # çekerek yırt (2. temas yolda)
    tr.to(0.055, "out", LP(-20.0, 4.0, 8.0))
    tr.hold(0.10)
    return tr.home(0.26)


# ---- C Dev Pençe (dünya çerçevesi, dönmez)
C_HIT1, C_HIT2 = 0.22, 0.32


def C_track():
    tx, ty = TGT
    tr = Track(REST_POSE, CENTER_PX)
    tr.to(0.12, "out", WP(tx - 6.0, ty - 32.0, -100.0))
    tr.to(0.05, "inout", WP(tx - 8.0, ty - 36.0, -115.0))  # geri ger
    tr.to(0.05, "in", WP(tx + 2.0, ty + 2.0, 80.0))  # tepeden indir (1. temas)
    tr.to(0.03, "lin", WP(tx + 2.0, ty + 2.0, 80.0, 0.88, 1.1))
    tr.to(0.04, "out", WP(tx - 2.0, ty - 14.0, -30.0))  # kalk
    tr.to(0.03, "in", WP(tx + 5.0, ty + 4.0, 85.0))  # yine indir (2. temas)
    tr.hold(0.14)
    return tr.home(0.26)


# ---- D Kızıl Tırmık (bugünkü tek süpürme + ters süpürme)
D_HIT1, D_HIT2 = 0.145, 0.24


def D_track():
    tr = Track(REST_POSE, CENTER_PX)
    tr.to(0.11, "out", LP(-4.0, 26.0, -75.0))
    tr.to(0.035, "in", LP(6.0, 0.0, -90.0))  # 1. temas
    tr.to(0.035, "out", LP(-2.0, -26.0, -105.0))
    tr.to(0.03, "inout", LP(-4.0, -28.0, 75.0))  # bilek döner
    tr.to(0.03, "in", LP(4.0, -2.0, 90.0))  # 2. temas
    tr.to(0.03, "out", LP(-2.0, 16.0, 105.0))
    tr.hold(0.10)
    return tr.home(0.26)


# ------------------------------------------------------------------ renkler
CREAM_W = cl("#fffdf6 #f2ead6 #d8ccae #aa9e82")
CREAM_W_OL = hx("#6e6450")
CREAM = TP.CREAM
CREAM_L = TP.CREAM_L
EMBER = TP.EMBER
DUST, DUST_OL = TP.DUST, TP.DUST_OL
HOOK = cl("#ffffff #fff2c4 #fbd27a #e0a040")
HOOK_OL = hx("#6a3a14")
GHOST = cl("#fff6d8 #fde08a #f6b545 #d9822b")
GHOST2 = cl("#fffbee #fff0c0 #fbd27a #f0a848")
AMBER, AMBER_OL = TP.AMBER, TP.AMBER_OL
GROOVE = [TP.CRACK, hx("#4a3c2a"), hx("#6e5a40")]
GROOVE_LIP = TP.CRACK_LIP
RED_FRESH = cl("#ffffff #ffd0c4 #f0605a #b02a34")
RED_MID = cl("#ffb4a4 #f0605a #c03a40 #8a1c28")
RED_OLD = cl("#e05050 #b02a34 #8a1c28 #5e1020")
RED_OL = hx("#3c0a14")
DROP = cl("#f05a54 #c0303a #7e1626")


def _sparks(seed, n, a0, a1, v, life):
    rng = random.Random(seed)
    return [(rng.uniform(a0, a1) * D2R + DIR_ANG, rng.uniform(*v), rng.uniform(*life)) for _ in range(n)]


# ---- A Üçlü Hilal
A_SPARKS1 = _sparks(3, 6, 60.0, 130.0, (60.0, 130.0), (0.12, 0.24))  # 1. yayın gidişi yönünde (yerel +y'ye)
A_SPARKS2 = _sparks(4, 4, -130.0, -60.0, (50.0, 100.0), (0.10, 0.20))


def A_fx(Ls, tr, t):
    hd = (0.0, -2.0)
    for hit, r, sp in ((A_HIT1, 8.0, A_SPARKS1), (A_HIT2, 6.0, A_SPARKS2)):
        age = t - hit
        if 0.0 <= age < 0.10:
            BP.star(Ls["f"], hd, r, CREAM, age / 0.10)
        draw_sparks(Ls["f"], hd, sp, age, EMBER, g=200.0)


def A_live(L, tr, t):
    for i in range(3):
        np_trail(L, tip_trail(tr, t, 0.16, 0.255, i, 0.065, linger=0.05), 4.4, CREAM_W, CREAM_W_OL)
        np_trail(L, tip_trail(tr, t, 0.285, 0.36, i, 0.05, linger=0.05), 3.2, CREAM_W, CREAM_W_OL)


# ---- B Kanca Çekiş
B_SPARKS = _sparks(9, 9, 135.0, 225.0, (70.0, 150.0), (0.16, 0.30))  # oyuncuya doğru (geri)
B_LINES = [120, 150, 180, 210, 240]


def B_fx(Ls, tr, t):
    dig = tips(tr, B_DIG[0])
    hd = off(dig[1])
    age = t - B_HIT1
    if 0.0 <= age < 0.12:
        BP.star(Ls["f"], hd, 9.0, CREAM, age / 0.12)
    if 0.0 <= age < 0.09:  # darbe çizgileri: saplanma noktasından geriye/yanlara
        e = math.sin(clamp01(age / 0.09) * math.pi / 2)
        for i, a in enumerate(B_LINES):
            aw = a * D2R + DIR_ANG
            r0, r1 = 5.0 + 8.0 * e, 9.0 + (8.0 if i % 2 else 12.0) * e
            BP.line_band(Ls["f"], (hd[0] + math.cos(aw) * r0, hd[1] + math.sin(aw) * r0),
                         (hd[0] + math.cos(aw) * r1, hd[1] + math.sin(aw) * r1), 3.0, CREAM_L, 1.0, 0.0,
                         clamp01((age - 0.03) / 0.06))
    ## yırtıklar: saplanma noktasından tırnağın o anki ucuna; çekiş bitince 0,06 sn durur, 0,14 sn'de incelip kırıntılanır
    if t >= B_DIG[1]:
        cur = tips(tr, min(t, 0.30))
        thin = clamp01((t - 0.36) / 0.14)
        for i in range(3):
            p0, p1 = off(cur[i]), off(dig[i])
            if math.hypot(p1[0] - p0[0], p1[1] - p0[1]) > 1.5:
                BP.line_band(Ls["f"], p0, p1, 3.4 if i == 1 else 3.0, HOOK, 1.0, 0.0, thin, ol=HOOK_OL, peak=0.8)
    age2 = t - B_HIT2
    draw_sparks(Ls["f"], hd, B_SPARKS, age2, EMBER, g=240.0)
    k = clamp01(age2 / 0.24)
    if 0.0 <= age2 and k < 1.0:  # ayağın dibinde küçük toz, oyuncuya doğru
        e = math.sin(k * math.pi / 2)
        f = (-DIRV[0] * (4.0 + 6.0 * e), -DIRV[1] * (4.0 + 6.0 * e))
        np_cloud(Ls["g"], [(G_OFF[0] + f[0] + dx, G_OFF[1] + f[1] + dy - 2.0 * e, r * (0.5 + 0.6 * e))
                           for dx, dy, r in ((-4.0, 0.5, 2.6), (3.0, -0.5, 3.0), (0.0, 1.5, 2.2))],
                 DUST, DUST_OL, 1.0, clamp01((age2 - 0.06) / 0.18))


def B_live(L, tr, t):
    for i in range(3):  # atılışta kısa hız izi
        np_trail(L, tip_trail(tr, t, 0.10, B_HIT1, i, 0.03, linger=0.0, eat=0.05), 2.4, CREAM_W, CREAM_W_OL)


# ---- C Dev Pençe: üç dev hilal bıçak (hayalet = Bayer ile yarı saydam), yerde 3 oluk, alan sınırına ince halka, korlar
C_X = (-13.0, 0.0, 13.0)
C_EMBERS = make_embers(21, 10, (16.0, 6.0), (6.0, 22.0), (40.0, 80.0), (0.30, 0.55))


def _ghost_claw(L, t, t0, x_off, y0, y1, bulge, w, cols, fade):
    """t0'dan 0,05 sn'de tepeden aşağı açılır, 0,02 sn sonra 0,12 sn'de incelip söner."""
    head = clamp01((t - t0) / 0.05)
    if head <= 0.0:
        return
    thin = clamp01((t - t0 - 0.07) / 0.12)
    for i, x in enumerate(C_X):
        xx = x + x_off
        dy = abs(i - 1) * 4.0  # yan tırnaklar biraz kısa
        BP.line_band(L, (xx - 7.0, y0 + dy), (xx + 5.0, y1 - dy), w * (1.0 if i == 1 else 0.85), cols, head, 0.0, thin,
                     ol=None, bulge=bulge, peak=1.6, fade=fade)


def C_fx(Ls, tr, t):
    _ghost_claw(Ls["f"], t, C_HIT1 - 0.04, 0.0, -50.0, 44.0, 7.0, 8.0, GHOST, 0.85)
    _ghost_claw(Ls["f"], t, C_HIT2 - 0.04, 8.0, -40.0, 38.0, -6.0, 6.0, GHOST2, 0.7)
    age = t - C_HIT1
    if age < 0.0:
        return
    fade = 1.0 - clamp01((age - 0.30) / 0.25)
    if fade > 0.0:  # yerde oluklar (ayağın altından)
        for i, x in enumerate(C_X):
            h = clamp01(age / 0.05)
            p0 = (G_OFF[0] + x - 3.0, G_OFF[1] - 12.0)
            p1 = (G_OFF[0] + x + 2.0, G_OFF[1] + 14.0 - abs(i - 1) * 3.0)
            BP.line_band(Ls["g"], p0, p1, 3.0, GROOVE, h, 0.0, 0.0, ol=GROOVE_LIP, fade=fade)
    np_ring(Ls["g"], G_OFF, 8.0, 4.0, AOE, AOE / 2.0, 2.6, AMBER, age / 0.30, nbreak=6, phase=0.4, ol=AMBER_OL, fade=0.8, brk=0.55)
    if age < 0.12:
        BP.star(Ls["f"], (0.0, 0.0), 10.0, CREAM, age / 0.12)
    draw_embers(Ls["f"], G_OFF, C_EMBERS, age, EMBER, g=60.0)


def C_live(L, tr, t):
    for i in range(3):
        np_trail(L, tip_trail(tr, t, 0.17, C_HIT1, i, 0.04, linger=0.0, eat=0.05), 2.4, CREAM_W, CREAM_W_OL)
        np_trail(L, tip_trail(tr, t, 0.29, C_HIT2, i, 0.03, linger=0.0, eat=0.05), 2.0, CREAM_W, CREAM_W_OL)


# ---- D Kızıl Tırmık: çizgiler yerel y boyunca (süpürme yönü), x'te aralıklı; açılış süpürmeyle eş zamanlı
D_MARKS1 = [(-5.5, 22.0, -22.0), (0.5, 24.0, -24.0), (6.5, 20.0, -20.0)]  # (x, y başı, y sonu)
D_MARKS2 = [(-3.0, -17.0, 15.0), (2.5, -19.0, 17.0), (8.0, -15.0, 13.0)]
D_ROT2 = 18.0 * D2R  # ikinci tırmık hafif çapraz


def _d_pal(age):
    return RED_FRESH if age < 0.08 else (RED_MID if age < 0.20 else RED_OLD)


D_MX = 5.0  # çizgilerin yerel x kayması (hedefin gövdesine)


def _d_drops(seed, marks, rot, n, t0):
    """(yerel nokta, kopma anı, ilk düşüş hızı, ömür, boyut)"""
    rng = random.Random(seed)
    out = []
    for _ in range(n):
        x, y0, y1 = rng.choice(marks)
        u = rng.uniform(0.25, 0.75)
        p = (x + D_MX, y0 + (y1 - y0) * u)
        if rot:
            c, s = math.cos(rot), math.sin(rot)
            p = (c * p[0] - s * p[1], s * p[0] + c * p[1])
        out.append((p, t0 + rng.uniform(0.0, 0.10), rng.uniform(4.0, 14.0), rng.uniform(0.22, 0.36), rng.choice((1, 1, 2))))
    return out


D_DROPS = _d_drops(17, D_MARKS1, 0.0, 7, 0.18) + _d_drops(18, D_MARKS2, D_ROT2, 4, 0.27)


def _d_marks(L, t, t_open, t_full, marks, rot, w, thin_t0):
    if t < t_open:
        return
    head = clamp01((t - t_open) / (t_full - t_open))
    thin = clamp01((t - thin_t0) / 0.16)
    c, s = math.cos(rot), math.sin(rot)
    for i, (x, y0, y1) in enumerate(marks):
        a, b = (x + D_MX, y0), (x + D_MX, y1)
        a = (c * a[0] - s * a[1], s * a[0] + c * a[1])
        b = (c * b[0] - s * b[1], s * b[0] + c * b[1])
        BP.line_band(L, LO(a), LO(b), w * (1.0 if i == 1 else 0.85), _d_pal(t - t_open), head, 0.0, thin, ol=RED_OL,
                     bulge=2.5, peak=1.2)


def D_fx(Ls, tr, t):
    _d_marks(Ls["f"], t, 0.115, 0.175, D_MARKS1, 0.0, 4.2, 0.30)
    _d_marks(Ls["f"], t, 0.215, 0.265, D_MARKS2, D_ROT2, 3.0, 0.34)
    age = t - D_HIT1
    if 0.0 <= age < 0.08:
        BP.star(Ls["f"], LO((8.0, 0.0)), 6.0, cl("#ffffff #ffe6dc #ffb0a0 #f0605a"), age / 0.08)
    for (p, ts, vy, life, sz) in D_DROPS:  # kızıl damlalar: çizgiden kopup düşer
        a = t - ts
        if a < 0.0 or a >= life:
            continue
        q = LO(p)
        y = q[1] + vy * a + 0.5 * 160.0 * a * a
        k = a / life
        col = DROP[min(len(DROP) - 1, int(k * len(DROP)))]
        x, yy = (int(v) for v in TP.fpx((q[0], y)))
        for dx in range(sz):
            for dy in range(sz + (1 if k < 0.4 else 0)):
                Ls["f"].put(x + dx, yy + dy, col, 1.0 - max(0.0, k - 0.5) / 0.5)


# ------------------------------------------------------------------ yön tablosu
DIRS = {
    "cur": dict(title="ŞU AN (oyundaki)", sub="hedefin önünden yana süpürür, iri pikselli pembe-kırmızı 3 çizgi; hasar atış anında",
                track=CUR_track, hits=(0.0, 0.1), align=0.12),
    "A": dict(title="A - Üçlü Hilal", sub="geniş yay + ters yay: her tırnak ucundan krem hilal izi, temasta kıvılcım; yönle döner",
              track=A_track, fx=A_fx, live=A_live, hits=(A_HIT1, A_HIT2)),
    "B": dict(title="B - Kanca Çekiş", sub="atılıp saplanır, çekerek yırtar: oyuncuya doğru 3 yırtık + geri saçılan kıvılcım",
              track=B_track, fx=B_fx, live=B_live, hits=(B_HIT1, B_HIT2)),
    "C": dict(title="C - Dev Pençe", sub="tepeden iki pençe: alan boyu kehribar hayalet tırmık, yerde 3 oluk, alan halkası",
              track=C_track, fx=C_fx, live=C_live, hits=(C_HIT1, C_HIT2)),
    "D": dict(title="D - Kızıl Tırmık", sub="bugünkü 3 kızıl çizgi piksel sanatıyla: süpürmeyle açılır, ters tırmık, damlalar",
              track=D_track, fx=D_fx, hits=(D_HIT1, D_HIT2)),
}
ORDER = ["cur", "A", "B", "C", "D"]


def cur_frame(variant, i):
    return asset("assets/fx/claw/claw_sheet.png", (i * 64, variant * 64, i * 64 + 64, variant * 64 + 64))


# ------------------------------------------------------------------ şerit
_BG = {}


def lane_bg(idx):
    if idx not in _BG:
        g = grass(int(LWW * ZOOM), int(LHW * ZOOM), 61 + idx)
        F = np.asarray(g.convert("RGB"), dtype=np.float32).copy()
        ch = asset("assets/characters/talon/sheets/idle.png", (0, 96, 48, 144))
        cx, cy = S(CHAR)
        blit(F, ch, cx, cy, CHAR_K * ZOOM)
        _BG[idx] = F
    return _BG[idx].copy()


def slime():
    return asset("visuals/Yaratıklar/Tüm Yaratıklar/Slime 1/PNG/Slime1/With_shadow/Slime1_Walk_with_shadow.png", (0, 0, 64, 64))


def icon():
    return asset("assets/weapons/zanaat/pence_L3.png")


class Lane:
    def __init__(self, did, idx, t_first=0.15):
        self.did, self.idx, self.D = did, idx, DIRS[did]
        self.tr = self.D["track"]()
        self.t_first = t_first
        self.cache = {}

    def attack(self, t):
        if t < self.t_first:
            return 99.0, 0
        n = int((t - self.t_first) // INTERVAL)
        return t - self.t_first - n * INTERVAL, n

    def layers(self, ta):
        q = int(ta * FXFPS)
        if q not in self.cache:
            Ls = {"g": Lay(), "f": Lay()}
            if "fx" in self.D:
                self.D["fx"](Ls, self.tr, q / float(FXFPS))
            self.cache[q] = {k: v.cropped() for k, v in Ls.items()}
        return self.cache[q]

    def render(self, t):
        F = lane_bg(self.idx)
        ta, n_att = self.attack(t)
        lay = self.layers(ta)
        tx, ty = S(TGT)
        k_fx = WPP * ZOOM

        def put_layer(c):
            if c is not None:
                blit(F, c[0], tx, ty, k_fx, 0.0, c[1])

        put_layer(lay["g"])
        ## enemy.gd: HIT_FLASH_DURATION 0,12 sn + HIT_FLASH_MIN_INTERVAL 0,4 -> iki parçadan sadece ilki parlar (alandaki de)
        fl = ta - self.D["hits"][0]
        flash = 1.0 - fl / 0.12 if 0.0 <= fl < 0.12 else 0.0
        for p in sorted([TGT, EXTRA_IN, EXTRA_OUT], key=lambda q: q[1]):
            sx, sy = S(p)
            blit(F, slime(), sx, sy - 2, SLIME_K * ZOOM)
            if flash > 0.0 and p is not EXTRA_OUT:
                blit(F, slime(), sx, sy - 2, SLIME_K * ZOOM, alpha=flash, tint=(255, 255, 255))
        if "live" in self.D:
            L = Lay()
            self.D["live"](L, self.tr, ta)
            put_layer(L.cropped())
        x, y, a, sl, sw = self.tr.pose(ta)
        TP.blit_mace(F, icon(), S((x, y)), a, WPP * ZOOM, self.tr.piv, sl, sw)
        if self.did == "cur":
            fi = int(ta * CUR_FX_FPS)
            if 0 <= fi < CUR_FX_N:
                fx, fy = S(SC)
                blit(F, cur_frame(n_att % 3, fi), fx, fy, CUR_FX_K * ZOOM, DIR_ANG)
        put_layer(lay["f"])
        return Image.fromarray(np.clip(F, 0, 255).astype(np.uint8), "RGB")


def lane_label(im, did, small=False):
    d = ImageDraw.Draw(im)
    label(d, 6, 3, DIRS[did]["title"], 12)
    if not small:
        label(d, 6, im.height - 16, DIRS[did]["sub"], 10, (226, 220, 204))


def info_tile(w, h, lines, title=None):
    im = Image.new("RGB", (w, h), (30, 34, 32))
    d = ImageDraw.Draw(im)
    y = 12
    if title:
        label(d, 12, y, title, 16)
        y += 30
    for s in lines:
        label(d, 12, y, s, 11, (220, 214, 198))
        y += 18
    return im


grid = TP.grid

# ------------------------------------------------------------------ çıktılar
INFO = [
    "aralık %.2f sn  ·  çift pençe darbesi, alan %d px (yarı hasar)" % (INTERVAL, AOE),
    "beyaz parlama = 1. isabet (2. parça 0,4 sn kuralıyla parlamaz)",
    "sağ alttaki yaratık alanın dışında (69 px), parlamaz",
    "ŞU AN: hasar atış anında, efekt pikseli silahın 2 katı iri",
    "yeni yönler: iki isabet = iki temas anı, pençe merkezden döner",
    "isabet kanı (yaratık rengi) hepsinde aynı, çizilmedi",
    "Talon + Zanaatkâr L3 pençe  ·  efekt 30 fps (sprite sayfası gibi)",
]


def build_game():
    lanes = [Lane(d, i) for i, d in enumerate(ORDER)]
    loop = 2.0 * INTERVAL
    n = int(round(loop * FPS))
    dt = loop / n
    lw, lh = int(LWW * ZOOM), int(LHW * ZOOM)
    info = info_tile(lw, lh, INFO, "Pençe vuruşu")
    hd = header(lw * 2 + 4, "Pençe vuruşu  ·  oyun ölçeği (1080p), gerçek hız", "Talon + Zanaatkâr L3 pençe  ·  2 vuruş döngüsü")
    frames = []
    for st in range(n):
        t = st * dt
        tiles = []
        for ln in lanes:
            im = ln.render(t)
            lane_label(im, ln.did)
            tiles.append(im)
        tiles.append(info)
        frames.append(stack_v([hd, grid(tiles, 2)]))
    save_gif(frames, os.path.join(OUT, "pence_oyun.gif"), 1.0 / dt,
             [int(0.34 * FPS), int(0.40 * FPS), int(0.46 * FPS), int(0.54 * FPS)])
    frames[int((0.15 + 0.25) * FPS)].save(os.path.join(OUT, "pence_oyun_kare.png"))


CROP = (int((TGT[0] - 64) * ZOOM), int((TGT[1] - 56) * ZOOM), int((TGT[0] + 80) * ZOOM), int((TGT[1] + 52) * ZOOM))


def build_slow(speed=0.25, z=2):
    lanes = [Lane(d, i, t_first=0.05) for i, d in enumerate(ORDER)]
    fps = 40
    real_len = 0.9
    n = int(round(real_len / speed * fps))
    dt = real_len / n
    cw, ch = (CROP[2] - CROP[0]) * z, (CROP[3] - CROP[1]) * z
    frames = []
    for st in range(n):
        t = st * dt
        tiles = []
        for ln in lanes:
            im = ln.render(t).crop(CROP).resize((cw, ch), Image.NEAREST)
            lane_label(im, ln.did, small=True)
            tiles.append(im)
        tiles.append(info_tile(cw, ch, [
            "yakınlaştırma x%d (1 dünya px = %d ekran px)" % (z, int(ZOOM * z)),
            "süre: %.2f sn (gerçek)" % max(0.0, t - 0.05),
            "",
            "temaslar: A %.2f/%.2f · B %.2f/%.2f" % (A_HIT1, A_HIT2, B_HIT1, B_HIT2),
            "C %.2f/%.2f · D %.2f/%.2f sn" % (C_HIT1, C_HIT2, D_HIT1, D_HIT2),
            "ŞU AN: hasar 0,00/0,10 sn, pençe 0,12'de varır",
            "beyaz parlama = 1. isabet",
        ], "YAVAŞ ÇEKİM x%.2f" % speed))
        frames.append(grid(tiles, 3))
    save_gif(frames, os.path.join(OUT, "pence_yavas.gif"), fps, [int(0.25 / dt), int(0.32 / dt), int(0.40 / dt)])


OFFS = [-0.12, -0.06, -0.03, 0.0, 0.034, 0.067, 0.10, 0.16, 0.24, 0.34]
SCROP = (int((TGT[0] - 62) * ZOOM), int((TGT[1] - 54) * ZOOM), int((TGT[0] + 80) * ZOOM), int((TGT[1] + 54) * ZOOM))


def build_strip(z=1):
    rows = []
    cw, ch = (SCROP[2] - SCROP[0]) * z, (SCROP[3] - SCROP[1]) * z
    LBL = 150
    for i, did in enumerate(ORDER):
        ln = Lane(did, i, t_first=0.0)
        t0 = DIRS[did].get("align", DIRS[did]["hits"][0])
        h2 = DIRS[did]["hits"][1] - DIRS[did]["hits"][0]
        row = Image.new("RGB", (LBL + len(OFFS) * (cw + 2), ch + 18), (24, 26, 26))
        d = ImageDraw.Draw(row)
        for j, o in enumerate(OFFS):
            tt = max(0.0, t0 + o)
            im = ln.render(tt).crop(SCROP).resize((cw, ch), Image.NEAREST)
            row.paste(im, (LBL + j * (cw + 2), 18))
            tag = "  1. temas" if o == 0.0 else ("  ~2. temas" if abs(o - h2) < 0.017 and did != "cur" else "")
            label(d, LBL + j * (cw + 2) + 4, 2, "%.2f sn%s" % (tt, tag), 10, (220, 214, 198))
        label(d, 6, 22, DIRS[did]["title"], 12)
        rows.append(row)
    im = stack_v(rows, 6)
    path = os.path.join(OUT, "pence_kareler.png")
    im.save(path)
    print("kareler", path, im.size)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    gi = os.path.join(HERE, "out", ".gdignore")
    if not os.path.exists(gi):
        open(gi, "w").close()
    args = sys.argv[1:] or ["oyun", "yavas", "kareler"]
    for w in args:
        {"oyun": build_game, "yavas": build_slow, "kareler": build_strip}[w]()
