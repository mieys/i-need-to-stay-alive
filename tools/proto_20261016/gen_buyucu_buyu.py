"""2026-10-16 prototipleri: BÜYÜCÜ KIZ - MEVCUT yeteneklere yeni piksel efektler (kullanıcı: "büyücü kızın tüm yetenekleri için
yeni prototip hazırla (don nova hariç)"). MEKANİKLER AYNI (madde 178 dersi: "efekt" = mekanik/sayı değişmez), sadece görsel.
OYUNA HENÜZ BAĞLI DEĞİL. Değişecek eski efektler:
  Q  Büyü Değişimi  `fx_mage_swap` (gökkuşağı yıldızlar) + `_spawn_burst`
  E1 Arcane Lanet   `fx_arcane_skull_bounce.gd` (mor kafatası) + `fx_arcane_impact`
  E2 Hortum         `assets/fx/buyucu_tornado/loop_sheet.png` (ince çizgili beyaz huni)
  R2 Meteor         `fx_meteor_strike.gd` (yuvarlak parçacık izi) + `_spawn_ring_sized` kanal halkası
  Pasif Büyü Dalgası  silah geri tepmesi (`WeaponJuice.arcane_surge`) AYNEN kalır; üstüne dalga + mor yüklü atış
  (Don Nova kullanıcı isteğiyle HARİÇ.)
Yeni efektler:
  Q   havada açılan büyü kitabı: sayfalar çevrilir, eski setin iki element zerresi kitaba girer, kitap parlar, yeni setin
      zerreleri çıkıp belin çevresinde bir tur döner; yerde yeni setin renginde rün halkası. Set 1 (Arcane Lanet + Don Nova)
      = SOĞUK menekşe-buz, Set 2 (Hortum + Meteor) = SICAK rüzgâr-ateş -> oyuncu hangi sette olduğunu renkten okur.
  E1  "lanet gözü": badem biçimli mor göz yaratıktan yaratığa kavisli uçar, arkasında incelen mor iz + rün kıvılcımları;
      vurduğu yaratığın ayağına mor lanet mührü (2:1 rün halkası) basılır, yaratık mor yanar, sekmeler arası ince "lanet
      ipi" bir an kalır (zincir okunur). Her sekme bir öncekinden biraz büyük (ses de tizleşiyor).
  E2  dolu, cel-shaded hortum hunisi (sarmal bantlar döner, ağzı koyu, üstü kıvrılan rüzgâr tutamları), içinde dönen mor
      kıvılcımlar + yaprak/çakıl, tabanda toz girdabı; doğuşta ayaktan 3 küçük girdap sarmal açılıp huniye büyür, değdiği
      yaratık havalanıp ezilir + rüzgâr kesikleri, bitişte alttan çözülüp yukarı dağılır.
  R2  ayak altında 2:1 rün çemberi: KANAL İLERLEMESİ çember üstünde dolan ateş yayı (3 sn'de tam tur); şapka ucundan göğe
      kor yükselir; meteor düşeceği yerde önce gölge + daralan uyarı halkası, sonra korlu kaya + alev kuyruğu, isabette
      dolu patlama + kaya parçaları + hasar yarıçapında (70 dünya px) ince şok halkası + soğuyan krater izi.
  Pasif  E/R anında karakterden mor dalga yayılır, geçtiği her silah mor kontürle yüklenir, hepsi aynı karede hedefin
      tersine geri tepip ateş eder: büyük mor namlu parlaması, mor izli mermi, mor patlama (normal atışlar sade kalır).
Çizim dili tools/pixfx.py (dolu kütleler, 5 ton [kontur, koyu, orta, açık, parlak], 1 px koyu kontur, uçlar incelir).
1 GIF pikseli = 1 Büyücü sanat pikseli = 2,2368375 x 0,8075 x 0,5 = 0,903 dünya birimi (Elara ile aynı).
Çıktı: out/buyucu_{q,e_lanet,e_hortum,r_meteor,pasif}.gif
Kullanım (proje kökünden): python -I tools/proto_20261016/gen_buyucu_buyu.py
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(PROJECT, 'tools'))
sys.path.insert(0, os.path.join(PROJECT, 'tools', 'proto_20261012'))
import pixfx as P  # noqa: E402
import gen_elara_nisanci as EL  # noqa: E402  (silah yuvaları, ikon ölçeği, şerit/mermi, GIF kaydı)
from gen_matthew_simsek import comp, grass, ground_shadow, slime  # noqa: E402

TAU = math.tau
## [kontur, koyu, orta, açık, parlak]
ARC = [(30, 12, 54), (74, 34, 136), (130, 80, 214), (192, 152, 255), (246, 234, 255)]  ## kıyafetinin menekşesi = büyü
HEX = [(46, 10, 50), (112, 28, 124), (182, 64, 200), (236, 140, 240), (255, 230, 250)]  ## lanet (menekşe-eflatun)
COLD = [(22, 30, 84), (58, 84, 182), (112, 156, 240), (186, 218, 255), (240, 250, 255)]  ## Set 1: Arcane Lanet + Don Nova
WARM = [(88, 30, 14), (190, 86, 30), (246, 152, 52), (255, 212, 122), (255, 248, 218)]  ## Set 2: Hortum + Meteor
HOR = [(44, 40, 84), (110, 116, 168), (170, 184, 222), (222, 232, 250), (255, 255, 255)]  ## hortum (hafif menekşe gölgeli rüzgâr)
ROCK = [(26, 14, 14), (62, 32, 26), (104, 56, 40), (150, 92, 60), (206, 144, 92)]
LEAF = [(30, 60, 20), (62, 112, 36), (104, 160, 58), (150, 204, 90), (200, 236, 140)]
COVER = [(30, 14, 52), (60, 28, 100), (92, 50, 146), (132, 90, 192), (180, 140, 230)]
GOLD = [(80, 52, 18), (164, 114, 38), (228, 184, 78), (255, 228, 146), (255, 250, 220)]
PAGE = [(96, 80, 70), (196, 180, 156), (232, 220, 196), (248, 242, 226), (255, 255, 246)]
FIRE = P.FIRE
ICE = P.ICE
CREAM = P.CREAM
FEET = 40  ## Büyücü karesinde ayak satırı (idle/walk, ölçüldü: bbox alt 41)
PXW = 1.0 / 0.903  ## dünya birimi -> Büyücü pikseli


# ====================================================================== karakter / ortak
def _sheet(name):
    return Image.open(os.path.join(PROJECT, 'assets', 'characters', 'buyucu', 'sheets', name + '.png')).convert('RGBA')


IDLE = _sheet('idle')  ## 4 sütun; satırlar: aşağı, sol, sağ, yukarı


def mage(col, row=2):
    return IDLE.crop((col * 48, row * 48, col * 48 + 48, row * 48 + 48))


def put_mage(dst, f, cx, feet):
    ground_shadow(dst, cx, feet + 1)
    comp(dst, mage((f // 4) % 4), cx - 24, feet - FEET)


def _hat_tip():
    a = np.array(mage(0))
    ys, xs = np.nonzero(a[:, :, 3] > 0)
    top = ys.min()
    return float(xs[ys == top].mean()) - 24.0, float(top) - FEET  ## karakter merkezine/ayağa göre


HAT_DX, HAT_DY = _hat_tip()


def layer(W, H):
    return P.Canvas(W, H)


def cc(img, cv):
    comp(img, cv.image())


def fade_cv(cv, level):
    """Bayer ile seyreltme (alfa yok): level 1 tam, 0 yok."""
    if level >= 1.0:
        return
    bay = np.tile(EL.BAYER, (cv.h // 4 + 1, cv.w // 4 + 1))[:cv.h, :cv.w]
    cv.rgba[bay >= level, 3] = 0


def ease_in(t):
    return t * t


def put_slime_fx(dst, x, feet, tint=None, squash=0.0, lift=0.0):
    """Temsili yaratık; tint: isabet anı rengi (siluet o paletin açık tonlarına boyanır), lift: havalanma (px)."""
    ground_shadow(dst, x, feet, 8, 2.5)
    s = slime(False, squash).img()
    if tint is not None:
        a = np.array(s)
        m = a[:, :, 3] > 0
        lum = a[:, :, :3].astype(float).mean(axis=2)
        for cond, col in ((m & (lum > 110), tint[4]), (m & (lum > 60) & (lum <= 110), tint[3]), (m & (lum <= 60), tint[1])):
            a[cond, 0], a[cond, 1], a[cond, 2] = col
        s = Image.fromarray(a, 'RGBA')
    comp(dst, s, x - 14, feet - 20 - lift)


def save(name, frames, ms, label, scale=3):
    EL.save_gif(name, frames, scale, ms, [(8, 6, label)])


# ====================================================================== Q - Büyü Değişimi
SET_PAIR = {0: ('arc', 'ice'), 1: ('wind', 'fire')}
SET_PAL = {0: COLD, 1: WARM}


def mote(cv, kind, x, y, f):
    """Set zerresi (~5 px): Set 1 = menekşe büyü küresi + buz kristali, Set 2 = rüzgâr kıvrımı + kor."""
    if kind == 'arc':
        P.puffs(cv, [(x, y, 2.3)], ARC)
        cv.px(x - 0.8, y - 0.8, ARC[4])
    elif kind == 'ice':
        P.facets(cv, [([(x, y - 3.6), (x, y + 3.6), (x - 2.3, y)], 3), ([(x, y - 3.6), (x + 2.3, y), (x, y + 3.6)], 2)], ICE)
        cv.px(x - 1, y - 1, ICE[4])
    elif kind == 'wind':
        P.arc_band(cv, x, y, 3.4, f * 0.7, f * 0.7 + 4.2, 1.9, 0.6, HOR)
        cv.px(x, y, HOR[4])
    else:
        P.puffs(cv, [(x, y + 0.6, 2.2), (x + 0.3, y - 1.4, 1.4)], FIRE)
        cv.px(x + 0.3, y - 3.2, FIRE[3])
        cv.px(x - 0.4, y + 0.2, FIRE[4])


def grimoire(cv, bx, by, open_k, pages, accent):
    """Havada büyü kitabı; (bx, by) sırt merkezi. open_k 0 kapalı / 1 açık; pages: çevrilen sayfaların evresi (0..1)."""
    X, Y = cv.grid()
    if open_k < 0.5:  ## kapalı: menekşe kapak, altın köşeler, ortada altın yıldız
        m = (np.abs(X - bx) <= 3.5) & (np.abs(Y - by) <= 4.5)
        cv.put(m, COVER[2])
        cv.put(m & (X < bx - 1.5), COVER[3])
        cv.put(m & (X > bx + 2.0), COVER[1])
        for (cx, cy) in ((bx - 3, by - 4), (bx + 3, by - 4), (bx - 3, by + 4), (bx + 3, by + 4)):
            cv.px(cx, cy, GOLD[2])
        cv.px(bx, by, GOLD[4])
        cv.px(bx, by - 1, GOLD[2])
        cv.px(bx, by + 1, GOLD[2])
        cv.put(P.outline_of(m) & ~cv.filled(), COVER[0])
        return
    cover = (np.abs(X - bx) <= 8.5) & (Y >= by - 4.0 - np.abs(X - bx) * 0.12) & (Y <= by + 4.5)
    cv.put(cover, COVER[1])
    pg = (np.abs(X - bx) <= 7.5) & (Y >= by - 3.2 - np.abs(X - bx) * 0.15) & (Y <= by + 3.4)
    cv.put(pg, PAGE[3])
    cv.put(pg & (np.abs(X - bx) < 1.6), PAGE[2])  ## sırta doğru gölge
    for row in (-1.5, 0.5, 2.5):  ## sayfalardaki rün satırları (yeni setin renginde)
        for side in (-1, 1):
            for i in range(2, 6):
                if (i + int(row)) % 3:
                    cv.px(bx + side * i, by + row, accent[2])
    cv.put(P.outline_of(cover) & ~cv.filled(), COVER[0])
    cv.px(bx, by - 3, COVER[0])
    for ph in pages:  ## çevrilen sayfa: sağdan sola, ortada havalanır
        phi = ph * math.pi
        xe = bx + 7.5 * math.cos(phi)
        lift = 3.0 * math.sin(phi)
        if abs(xe - bx) < 0.6:
            for yy in range(int(by - 3 - lift), int(by + 4)):
                cv.px(bx, yy, PAGE[4])
            continue
        m = P.poly_mask(cv, [(bx, by - 3.4), (xe, by - 3.4 - lift), (xe, by + 3.4 - lift * 0.6), (bx, by + 3.4)])
        cv.put(m, PAGE[4] if math.cos(phi) > 0 else PAGE[2])
        cv.put(P.outline_of(m) & ~m & ~pg, PAGE[0])


def scene_q():
    W, H = 168, 100
    ex, feet = 74, 88
    SW = (6, 36)  ## iki değişim: Set 1 -> 2, sonra Set 2 -> 1
    F = 66
    ocx, ocy, ORX, ORY = ex, feet - 13, 15.0, 5.0  ## bel çevresi yörüngesi
    bx, by = ex + 14, feet - 22  ## kitap: göğsünün önünde havada
    frames = []
    for f in range(F):
        img = grass(W, H, 400)
        gv = layer(W, H)
        for idx, s in enumerate(SW):
            k = f - s - 4
            if 0 <= k < 8:  ## yeni setin renginde yerde rün halkası
                P.shock_ring(gv, ex, feet, 8.0 + 14.0 * P.ease_out(k / 8.0), 2.4, k / 8.0, SET_PAL[1 - idx % 2], 0.5, seed=s, break_from=0.4)
                if k < 3:
                    for q in range(6):
                        a = q * TAU / 6 + k * 0.4
                        r = 8.0 + 14.0 * P.ease_out(k / 8.0) + 3
                        gv.px(ex + math.cos(a) * r, feet + math.sin(a) * r * 0.5, SET_PAL[1 - idx % 2][4])
        cc(img, gv)
        back, front, top = layer(W, H), layer(W, H), layer(W, H)
        for idx, s in enumerate(SW):
            k = f - s
            if k < 0 or k > 22:
                continue
            old, new = idx % 2, 1 - idx % 2
            a = f * 0.45
            if k < 4:  ## eski setin zerreleri sarmal çizip kitaba girer
                t = ease_in((k + 1) / 4.5)
                for j, kind in enumerate(SET_PAIR[old]):
                    aj = a + j * math.pi
                    ox, oy = ocx + math.cos(aj) * ORX * (1 - t), ocy + math.sin(aj) * ORY * (1 - t)
                    x, y = P.lerp(ox, bx, t), P.lerp(oy, by, t)
                    mote(front if (math.sin(aj) > 0 or t > 0.4) else back, kind, x, y, f)
            elif k < 20:  ## yeni setin zerreleri kitaptan çıkıp bir tur döner, sonra yükselip söner
                mv = layer(W, H)
                grow = P.ease_out(min(1.0, (k - 4) / 3.0))
                rise = max(0, k - 14) * 1.6
                for j, kind in enumerate(SET_PAIR[new]):
                    aj = a + j * math.pi
                    ox, oy = ocx + math.cos(aj) * ORX, ocy + math.sin(aj) * ORY - rise
                    x, y = P.lerp(bx, ox, grow), P.lerp(by, oy, grow)
                    tgt = front if math.sin(aj) > 0 else back
                    for tr in (1, 2):  ## yörünge izi
                        ap = aj - tr * 0.45
                        tgt.px(P.lerp(bx, ocx + math.cos(ap) * ORX, grow), P.lerp(by, ocy + math.sin(ap) * ORY - rise, grow),
                               SET_PAL[new][3 if tr == 1 else 2])
                    mote(tgt, kind, x, y, f)
                if k >= 15:
                    fade_cv(front, 1.0 - (k - 14) / 6.0)
                    fade_cv(back, 1.0 - (k - 14) / 6.0)
            ## kitap: belirir, açılır, 3 sayfa çevrilir, parlar, kapanıp menekşe pufla kaybolur
            if k == 0:
                grimoire(top, bx, by, 0.0, [], SET_PAL[new])
                P.star(top, bx, by - 6, 2, P.WHITE, ARC[3])
            elif 1 <= k <= 9:
                pages = [((k - 1 - i) + 1) / 3.0 for i in range(3) if 0 <= k - 1 - i < 2]
                grimoire(top, bx, by, 1.0, pages, SET_PAL[new] if k >= 3 else SET_PAL[old])
                if k == 4:
                    P.disc_flash(top, bx, by - 1, 5.0, core=CREAM, rim=SET_PAL[new][4])
                    P.star(top, bx, by - 1, 7, P.WHITE, SET_PAL[new][3], diag=True)
                elif k == 5:
                    P.star(top, bx, by - 1, 4, SET_PAL[new][4], SET_PAL[new][3])
            elif k == 10:
                grimoire(top, bx, by, 0.0, [], SET_PAL[new])
            elif 11 <= k <= 13:
                u = (k - 11) / 3.0
                P.puffs(top, [(bx - 2, by, 3.2 * (1 - u * 0.5)), (bx + 2, by - 1, 2.8 * (1 - u * 0.5))], ARC,
                        cut=[(bx + 1.5, by - 2, 2.5 * u + 0.5)] if u > 0 else None)
        cc(img, back)
        put_mage(img, f, ex, feet)
        cc(img, front)
        cc(img, top)
        frames.append(img)
    return frames


# ====================================================================== E1 - Arcane Lanet
def eye(cv, x, y, ang, size):
    """Lanet gözü: uçuş yönünde badem göz, krem iris + koyu dikey göz bebeği, seyrek eflatun hale."""
    X, Y = cv.grid()
    c, s = math.cos(ang), math.sin(ang)
    u = ((X - x) * c + (Y - y) * s) / (4.6 * size)
    v = (-(X - x) * s + (Y - y) * c) / (2.7 * size)
    m = (np.abs(u) <= 1.0) & (np.abs(v) <= 1.0 - u * u)
    halo = P.dilate(P.dilate(m)) & ~P.dilate(m)
    bay = np.tile(EL.BAYER, (cv.h // 4 + 1, cv.w // 4 + 1))[:cv.h, :cv.w]
    cv.put(halo & (bay < 0.5), HEX[1])
    cv.put(m, HEX[2])
    cv.put(m & (Y < y - 0.3), HEX[3])
    iris = (X - x) ** 2 + (Y - y) ** 2 <= (1.7 * size) ** 2
    cv.put(m & iris, CREAM)
    cv.px(x, y, HEX[0])
    cv.px(x, y + 1, HEX[0])
    cv.put(P.outline_of(m) & ~cv.filled(), HEX[0])


def curve(p0, p1, t):
    """Kavisli sekme yolu: düz hat + yukarı doğru sinüs şişkinliği."""
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    d = math.hypot(dx, dy) or 1.0
    nx, ny = -dy / d, dx / d
    if ny > 0:
        nx, ny = -nx, -ny
    b = math.sin(math.pi * t) * min(16.0, d * 0.16)
    return p0[0] + dx * t + nx * b, p0[1] + dy * t + ny * b


def scene_e_lanet():
    W, H = 320, 150
    ex, feet = 52, 126
    hand = (ex + 8, feet - 17)
    TG = [(124, 94), (186, 130), (240, 80), (292, 118)]
    CAST = 5
    SPEED = 750.0 * PXW * 0.05  ## 750 dünya/sn, 50 ms kare
    hops, prev, s = [], hand, CAST + 2
    for i, (tx, tsf) in enumerate(TG):  ## (kalkış karesi, uçuş kare sayısı, p0, p1, sıra)
        p1 = (tx, tsf - 8)
        n = max(2, int(math.ceil(math.hypot(p1[0] - prev[0], p1[1] - prev[1]) / SPEED)))
        hops.append((s, n, prev, p1, i))
        s += n + 3  ## isabette kısa duraklama (oyunda sekmeler arası 0,14 sn)
        prev = p1
    F = hops[-1][0] + hops[-1][1] + 22
    frames = []
    for f in range(F):
        img = grass(W, H, 120)
        gv = layer(W, H)
        tint_at = {}
        for (s0, n, p0, p1, i) in hops:
            a = s0 + n
            k = f - a
            sz = 1.0 + 0.12 * i
            if 0 <= k < 12:  ## ayağa basılan lanet mührü
                tx, tsf = TG[i]
                R = 10.0 * sz
                P.shock_ring(gv, tx, tsf, R * (1.08 - 0.08 * min(k, 3) / 3.0), 1.8, k / 12.0, HEX, 0.5, seed=i * 3.0, break_from=0.45)
                if k < 7:
                    for q in range(4):
                        aq = q * TAU / 4 + 0.3 + k * 0.18
                        for d in (R + 2.0, R + 3.0):
                            gv.px(tx + math.cos(aq) * d, tsf + math.sin(aq) * d * 0.5, HEX[3] if k < 4 else HEX[2])
                if k < 2:
                    P.disc_flash(gv, tx, tsf, 4.0 * sz, core=HEX[4], rim=HEX[3], squash=0.5)
            if 0 <= k < 3:
                tint_at[i] = k
        cc(img, gv)
        for i, (tx, tsf) in enumerate(TG):
            k = tint_at.get(i)
            put_slime_fx(img, tx, tsf, tint=HEX if k is not None and k < 2 else None, squash=0.5 if k == 0 else 0.0)
        put_mage(img, f, ex, feet)
        cv = layer(W, H)
        if CAST <= f < CAST + 3:  ## elde lanet mührü belirir (kalkış)
            k = f - CAST
            P.ring_band(cv, hand[0], hand[1], 5.0 + k, 1.4, HEX, gaps=[(k * 0.8, k * 0.8 + 0.9), (k * 0.8 + 3.1, k * 0.8 + 4.0)])
            if k == 0:
                P.disc_flash(cv, hand[0], hand[1], 2.5, core=CREAM, rim=HEX[4])
                P.star(cv, hand[0], hand[1], 4, P.WHITE, HEX[3], diag=True)
        for (s0, n, p0, p1, i) in hops:
            a = s0 + n
            k = f - a
            if 0 <= k < 8:  ## sekmeler arası lanet ipi: kaynaktan hedefe doğru çözülür
                for q in range(40):
                    t = q / 39.0
                    if t < k / 8.0 or (q % 2 and k > 3):
                        continue
                    x, y = curve(p0, p1, t)
                    cv.px(x, y, HEX[3] if q % 3 else HEX[2])
            dt = f - s0
            if 0 <= dt < n:  ## uçan göz + incelen iz + düşen rün kıvılcımları
                t = (dt + 0.8) / (n + 0.2)
                pts = [curve(p0, p1, max(0.0, t - 0.38 * (1 - j / 4.0))) for j in range(5)]
                for j in range(4):
                    EL.strip(cv, pts[j], pts[j + 1], 0.6 + 0.6 * j, 1.2 + 0.6 * j, HEX, outline=j > 1)
                hx, hy = curve(p0, p1, t)
                tx2, ty2 = curve(p0, p1, min(1.0, t + 0.02))
                ang = math.atan2(ty2 - hy, tx2 - hx) if (tx2, ty2) != (hx, hy) else 0.0
                eye(cv, hx, hy, ang, 1.0 + 0.12 * i)
            for back in (1, 2, 3):
                dtb = f - back - s0
                if 0 <= dtb < n:
                    tb = (dtb + 0.8) / (n + 0.2)
                    sx, sy = curve(p0, p1, max(0.0, tb - 0.25))
                    sy += back * 1.5
                    if back == 1:
                        P.star(cv, sx, sy, 1, HEX[4], HEX[3])
                    else:
                        cv.px(sx, sy, HEX[3] if back == 2 else HEX[2])
            if 0 <= k < 7:  ## isabet patlaması (sıra büyüdükçe büyür)
                P.burst(cv, p1[0], p1[1], 9.0 * (1.0 + 0.12 * i), k / 7.0, HEX, P.SHADOW, seed=i * 7, n_puffs=6)
        cc(img, cv)
        frames.append(img)
    return frames


# ====================================================================== E2 - Hortum
HMAX = 46.0


def tornado(cv, x, gy, t, h, sc=1.0, cut=0.0, seed=0.0):
    """Dolu hortum hunisi: sarmal bantlar döner (açı arcsin ile yuvarlak gövde), ağzı koyu elips, içinde menekşe kıvılcımlar
    + yaprak/çakıl (arkadakiler gövdeden önce, öndekiler sonra çizilir). cut: alttan çözülme (0..1)."""
    if h < 2:
        return
    X, Y = cv.grid()
    base_y = gy - 2.0
    r0, r1 = 2.2 * sc, 13.0 * sc

    def rad(s):
        return r0 + (r1 - r0) * np.clip(s, 0, 1) ** 1.25

    def sway(s):
        return 3.5 * sc * np.clip(s, 0, 1) ** 1.4 * np.sin(t * 0.45 + seed + s * 2.4)

    s = (base_y - Y) / h
    xc = x + sway(s)
    rr = rad(s) * (1.0 + 0.1 * np.sin(s * 22.0 - t * 1.7 + seed)) + 0.6 * np.sin(s * 37.0 + t * 2.3)  ## yırtık kenar
    body = (s >= cut) & (s <= 1.0) & (np.abs(X - xc) <= rr)
    xt, top_y, ryr = x + float(sway(1.0)), base_y - h, r1 * 0.32
    rim = ((X - xt) / r1) ** 2 + ((Y - top_y) / ryr) ** 2 <= 1.0
    mouth = ((X - xt) / max(r1 - 2.2, 0.5)) ** 2 + ((Y - top_y + 0.4) / max(ryr - 1.1, 0.5)) ** 2 <= 1.0
    m = body | rim

    def bits(front):
        for q in range(5):
            a = t * (0.85 + 0.1 * q) + q * 1.9 + seed
            sq = (t * 0.035 + q * 0.21 + seed * 0.1) % 1.0
            if sq < cut:
                continue
            if (math.cos(a) > 0) != front:
                continue
            yy = base_y - sq * h
            r = float(rad(sq)) + 1.5
            xx = x + float(sway(sq)) + r * math.sin(a)
            if q < 3:  ## menekşe büyü kıvılcımı
                cv.px(xx, yy, ARC[4] if front else ARC[2])
                if front:
                    cv.px(xx - 1, yy, ARC[3])
                    cv.px(xx + 1, yy, ARC[3])
            elif q == 3:  ## yaprak
                cv.px(xx, yy, LEAF[3] if front else LEAF[1])
                cv.px(xx + 1, yy - 1, LEAF[2] if front else LEAF[1])
            else:  ## çakıl
                cv.px(xx, yy, P.STONE[3] if front else P.STONE[1])

    bits(False)
    ## Ön yüz SARMAL ŞERİTLER: aralarındaki boşluktan arka duvarın koyu şeritleri ya da çimen görünür (katı külah değil, rüzgâr).
    u = np.clip((X - xc) / np.maximum(rr, 0.5), -1, 1)
    th = np.arcsin(u)
    ph = s * 13.0 - t * 1.5 + seed
    stripe = np.sin(th * 2.0 + ph)
    gap = body & (stripe < -0.4) & (s < 0.9)
    front = (body & ~gap) | rim
    backwall = gap & (np.sin((math.pi - th) * 2.0 + ph) > -0.1)
    cv.put(backwall, HOR[1])
    tone = np.where(u < -0.35, 3, np.where(u > 0.6, 1, 2))
    tone = np.where(stripe > 0.55, np.minimum(tone + 1, 4), tone)
    tone = np.where(rim & ~body, 3, tone)
    for tt in range(1, 5):
        cv.put(front & (tone == tt), HOR[tt])
    cv.put(mouth & ~body | (mouth & (Y < top_y)), HOR[1])
    cv.put(P.outline_of(front) & ~front & ~(mouth & rim), HOR[0])
    for side in (-1, 1):  ## ağızdan dışa kıvrılan rüzgâr tutamları
        a0 = t * 0.6 + (0 if side > 0 else math.pi)
        wx = xt + side * (r1 + 1.5)
        P.arc_band(cv, wx, top_y - 1.0, 3.2 * sc, a0, a0 + 2.6, 1.6, 0.5, HOR)
    bits(True)


def base_swirl(cv, x, gy, t, sc=1.0, level=1.0):
    """Hortum tabanında toz girdabı (yere yatık iki hilal)."""
    if level < 0.25:
        return
    for j in (0, 1):
        a0 = t * 0.7 + j * math.pi
        P.arc_band(cv, x, gy, 8.0 + 3.0 * sc, a0, a0 + 2.3, 2.2 * level, 0.6, P.DUST, squash=0.45)


def _walk(path, dist):
    for (a, b) in zip(path, path[1:]):
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        if dist <= L:
            k = dist / L
            return a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k
        dist -= L
    return path[-1]


def scene_e_hortum():
    W, H = 360, 196
    ex, feet = 56, 150
    CAST, GROW0, GROW, END, ENDN = 4, 9, 6, 58, 12
    F = END + ENDN + 4
    SPD = 102.0 * PXW * 0.066  ## hortum hızı 102 dünya/sn
    TG = [(172, 132), (252, 184), (306, 116), (220, 80), (330, 164)]
    ## her hortum kendi yolunda, kendi hızında dolaşır (oyunda rastgele yaratıklara yönelir - dizi hâlinde yürümesin)
    PATHS = [[(100, 184), (150, 186), (200, 176), (252, 186), (300, 172)],
             [(116, 140), (172, 136), (204, 118), (228, 92), (222, 74)],
             [(92, 100), (150, 106), (232, 120), (302, 116), (334, 150)]]
    PACE = (0.9, 0.75, 1.1)
    last_hit = {}
    react = {}
    frames = []
    for f in range(F):
        img = grass(W, H, 260)
        gv = layer(W, H)
        if CAST <= f < CAST + 5:  ## ayak altında açılan girdap
            k = (f - CAST) / 5.0
            for j in (0, 1):
                a0 = f * 0.8 + j * math.pi
                P.arc_band(gv, ex, feet, 8.0 + 6.0 * k, a0, a0 + 2.4, 2.2 * (1 - k * 0.6), 0.6, HOR, squash=0.45)
        pos = []
        for i, path in enumerate(PATHS):
            if f < GROW0:  ## tohum: ayaktan sarmal açılarak başlangıç noktasına
                u = P.ease_out(max(0.0, (f - CAST) / (GROW0 - CAST)))
                curl = math.sin(u * math.pi) * 10.0
                ang = math.atan2(path[0][1] - feet, path[0][0] - ex) + math.pi / 2
                x = P.lerp(ex, path[0][0], u) + math.cos(ang) * curl
                y = P.lerp(feet, path[0][1], u) + math.sin(ang) * curl * 0.5
            else:
                x, y = _walk(path, (min(f, END) - GROW0) * SPD * PACE[i])
            pos.append((x, y))
            if f >= CAST:
                lv = 1.0 if f < END else max(0.0, 1.0 - (f - END) / ENDN)
                if f < GROW0:
                    a0 = f * 0.9 + i
                    P.arc_band(gv, x, y, 3.6, a0, a0 + 3.4, 1.8, 0.6, HOR, squash=0.5)
                else:
                    base_swirl(gv, x, y, f + i * 2.0, min(1.0, (f - GROW0 + 1) / GROW), lv)
        cc(img, gv)
        ## temas: yaratık havalanır + kesikler (çift başına 1 sn'de bir)
        if GROW0 + GROW <= f < END:
            for i, (x, y) in enumerate(pos):
                for j, (tx, tsf) in enumerate(TG):
                    if math.hypot(tx - x, (tsf - y) * 1.6) < 20 and f - last_hit.get((i, j), -99) >= 15:
                        last_hit[(i, j)] = f
                        react[j] = f
        draw = []
        for j, (tx, tsf) in enumerate(TG):
            k = f - react.get(j, -99)
            lift = (3.0, 5.0, 5.0, 3.0, 1.0)[k] if 0 <= k < 5 else 0.0
            draw.append((tsf, 'slime', j, k, lift))
        draw.append((feet, 'mage', 0, 0, 0))
        for i, (x, y) in enumerate(pos):
            draw.append((y + 0.5, 'tor', i, 0, 0))
        draw.sort(key=lambda d: d[0])
        for (yy, kind, j, k, lift) in draw:
            if kind == 'slime':
                tx, tsf = TG[j]
                put_slime_fx(img, tx, tsf, tint=HOR if 0 <= k < 2 else None, squash=0.4 if k in (0, 1) else 0.0, lift=lift)
            elif kind == 'mage':
                put_mage(img, f, ex, feet)
            elif f >= GROW0:
                x, y = pos[j]
                tv = layer(W, H)
                g = P.ease_out(min(1.0, (f - GROW0 + 1) / GROW))
                cut, rise, lv = 0.0, 0.0, 1.0
                if f >= END:
                    u = (f - END) / ENDN
                    cut, rise, lv = u * 0.9, u * 10.0, 1.0 - u * 0.85
                tornado(tv, x, y - rise, f * 1.0, HMAX * g, sc=0.55 + 0.45 * g, cut=cut, seed=j * 2.3)
                fade_cv(tv, lv)
                cc(img, tv)
        cv = layer(W, H)
        for j, (tx, tsf) in enumerate(TG):
            k = f - react.get(j, -99)
            if 0 <= k < 4:  ## rüzgâr kesikleri
                for q in (0, 1):
                    a0 = k * 1.1 + q * math.pi + j
                    P.arc_band(cv, tx, tsf - 8, 10.0 + k, a0, a0 + 1.6, 2.0 * (1 - k / 4.0) + 0.4, 0.5, HOR)
                if k == 0:
                    P.star(cv, tx, tsf - 9, 4, P.WHITE, HOR[3], diag=True)
        cc(img, cv)
        frames.append(img)
    return frames


# ====================================================================== R2 - Meteor Patlaması
IMPACT_R = 70.0 * PXW  ## BUYUCU_METEOR_IMPACT_RADIUS (dünya 70)
MDIR = (120.0 / math.hypot(120, 420), 420.0 / math.hypot(120, 420))  ## fx_meteor_strike: (-120, -420)'den düşer


def meteor(cv, x, y, f, seed):
    ang = math.atan2(MDIR[1], MDIR[0])
    fl = 0.5 * math.sin(f * 2.1 + seed)
    items = [(x - MDIR[0] * j * 3.6, y - MDIR[1] * j * 3.6, 6.2 - j * 0.8 + fl * (j > 1), 4.8 - j * 0.62, ang) for j in range(7)]
    P.heat_fill(cv, P.ellipses_mask(cv, items), FIRE, levels=(1, 2, 3, 5))
    P.puffs(cv, [(x + MDIR[0] * 0.6, y + MDIR[1] * 0.6, 4.3)], ROCK)
    for (dx, dy, c) in ((-1, 0, FIRE[3]), (0, 1, FIRE[3]), (1, -1, FIRE[4])):
        cv.px(x + dx + MDIR[0] * 0.6, y + dy + MDIR[1] * 0.6, c)
    rng = random.Random(f * 13 + int(seed * 7))
    for q in range(3):
        d = rng.uniform(22, 32)
        o = rng.uniform(-3, 3)
        cv.px(x - MDIR[0] * d - MDIR[1] * o, y - MDIR[1] * d + MDIR[0] * o, FIRE[3] if q % 2 else FIRE[4])


def crater(cv, x, y, k, seed):
    """Soğuyan krater izi: kömürleşmiş leke + sönen kor çatlakları; k 1.. kare."""
    if k < 1 or k > 40:
        return
    tmp = P.Canvas(cv.w, cv.h)
    m = P.blob_mask(tmp, x, y, 9.5, 3.8, seed, wobble=0.2)
    tmp.put(m, (40, 30, 22))
    tmp.put(m & P.erode(P.erode(m)), (28, 20, 16))
    cool = min(1.0, max(0.0, (k - 4) / 20.0))
    col = FIRE[3] if cool < 0.3 else (FIRE[1] if cool < 0.7 else ROCK[2])
    rng = random.Random(seed)
    for q in range(4):
        a = q * TAU / 4 + rng.uniform(-0.4, 0.4)
        for d in range(1, 6):
            tmp.px(x + math.cos(a) * d, y + math.sin(a) * d * 0.4, col)
    fade_cv(tmp, 1.0 - max(0.0, (k - 26) / 14.0))
    cv.rgba[tmp.filled()] = tmp.rgba[tmp.filled()]


def scene_r():
    W, H = 320, 180
    ex, feet = 150, 112
    CAST, CH = 5, 45  ## 3 sn kanal (66 ms kare)
    END = CAST + CH
    F = END + 34
    TG = [(64, 82), (240, 70), (268, 142), (92, 156), (196, 166)]
    rng = random.Random(5)
    spawns = list(range(CAST + 3, END, 6))  ## 0,4 sn'de bir
    picks = [TG[0], TG[2], (206, 112), TG[1], TG[4], TG[3], (118, 60)]  ## %80 yaratık üstü, kalanı rastgele nokta
    strikes = [(s, s + 7, picks[i % len(picks)][0] + rng.uniform(-3, 3), picks[i % len(picks)][1] + rng.uniform(-2, 2), i * 1.7)
               for i, s in enumerate(spawns)]
    tip = (ex + HAT_DX, feet + HAT_DY)
    R0 = 22.0
    frames = []
    for f in range(F):
        img = grass(W, H, 40)
        gv = layer(W, H)
        for (s0, i0, tx, ty, sd) in strikes:
            crater(gv, tx, ty, f - i0, int(sd * 10))
        if CAST <= f < END:  ## kanal rün çemberi: soluk halka + ilerleme yayı + dönen rün çentikleri
            p = (f - CAST + 1) / CH
            R = R0 * (0.4 + 0.6 * P.ease_out(min(1.0, (f - CAST + 1) / 4.0)))
            P.ring_band(gv, ex, feet, R, 2.0, [ARC[0], ARC[1], ARC[1], ARC[2], ARC[2]], squash=0.5)
            P.arc_band(gv, ex, feet, R + 0.2, -math.pi / 2, -math.pi / 2 + p * TAU * 0.999, 2.6, 2.2, FIRE, squash=0.5, round_head=False)
            for q in range(6):
                a = q * TAU / 6 + f * 0.08
                lit = ((a + math.pi / 2) % TAU) / TAU < p
                for d in (R - 4.0, R - 5.0):
                    gv.px(ex + math.cos(a) * d, feet + math.sin(a) * d * 0.5, FIRE[3] if lit else ARC[2])
        if END <= f < END + 7:  ## kanal biter: çember parlayıp parçalanır
            k = (f - END) / 7.0
            P.shock_ring(gv, ex, feet, R0 + 10.0 * P.ease_out(k), 2.6, k, FIRE, 0.5, seed=3, break_from=0.2)
        for (s0, i0, tx, ty, sd) in strikes:
            dt = f - s0
            if 0 <= dt < 7:  ## uyarı: büyüyen gölge + daralan halka
                t = (dt + 1) / 7.0
                ground_shadow_cv(gv, tx, ty, 2.0 + 7.0 * t, (2.0 + 7.0 * t) * 0.4)
                P.ring_band(gv, tx, ty, 13.0 - 6.0 * t, 1.3, [FIRE[0], FIRE[1], FIRE[2], FIRE[2], FIRE[3]], squash=0.5)
            k = f - i0
            if 0 <= k < 4:  ## hasar yarıçapında ince, hızlı şok halkası (koyu kor tonları - kalabalıkta göz yormasın)
                P.shock_ring(gv, tx, ty, 10.0 + (IMPACT_R - 10.0) * P.ease_out((k + 1) / 4.0), 1.3, k / 4.0, P.EMBER, 0.5,
                             seed=sd, break_from=0.25)
        cc(img, gv)
        draw = [(feet, 'mage', None)]
        for j, (tx, tsf) in enumerate(TG):
            hitk = None
            for (s0, i0, sx, sy, sd) in strikes:
                if 0 <= f - i0 < 2 and math.hypot(sx - tx, sy - tsf) < 14:
                    hitk = f - i0
            draw.append((tsf, 'slime', (j, hitk)))
        draw.sort(key=lambda d: d[0])
        for (yy, kind, data) in draw:
            if kind == 'mage':
                put_mage(img, f, ex, feet)
            else:
                j, hitk = data
                put_slime_fx(img, TG[j][0], TG[j][1], tint=WARM if hitk is not None else None, squash=0.5 if hitk == 0 else 0.0)
        cv = layer(W, H)
        if CAST <= f < END:  ## şapka ucundan göğe yükselen korlar
            P.star(cv, tip[0], tip[1] - 1, 1 + (f // 3) % 2, FIRE[4], FIRE[3])
            for born in range(max(CAST, f - 9), f + 1):
                if (born - CAST) % 2:
                    continue
                age = f - born
                r2 = random.Random(born)
                x = tip[0] + r2.uniform(-2.5, 2.5) + math.sin(age * 0.7 + born) * 1.5
                y = tip[1] - 2 - age * 2.4
                col = FIRE[4] if age < 2 else (FIRE[3] if age < 5 else FIRE[2])
                cv.px(x, y, col)
                if age < 3:
                    cv.px(x, y + 1, FIRE[2])
        if f == END:
            P.disc_flash(cv, ex, feet - 1, 5.0, core=CREAM, rim=FIRE[4], squash=0.5)
        for (s0, i0, tx, ty, sd) in strikes:
            dt = f - s0
            if 0 <= dt < 7:
                e = ease_in((dt + 1) / 7.0)
                D = 150.0 * (1.0 - e)
                meteor(cv, tx - MDIR[0] * D, ty - 3 - MDIR[1] * D, f, sd)
            k = f - i0
            if 0 <= k < 10:
                P.burst(cv, tx, ty - 4, 16.0, k / 10.0, FIRE, P.SMOKE, seed=int(sd * 10), n_puffs=8, squash=0.8)
            if 1 <= k < 10:
                for q in range(6):
                    a = q * TAU / 6 + sd
                    x = tx + math.cos(a) * 3.0 * k
                    y = ty - 4 + math.sin(a) * 1.2 * k - 4.0 * k + 0.55 * k * k
                    if y < ty + 2:
                        P.chunk(cv, x, y, 2, ROCK)
        cc(img, cv)
        frames.append(img)
    return frames


def ground_shadow_cv(cv, x, y, rx, ry):
    X, Y = cv.grid()
    m = ((X - x) / max(rx, 0.5)) ** 2 + ((Y - y) / max(ry, 0.5)) ** 2 <= 1.0
    cv.put(m & ~cv.filled(), (70, 96, 48))
    cv.put(m & ~cv.filled() & (((X - x) / max(rx * 0.6, 0.5)) ** 2 + ((Y - y) / max(ry * 0.6, 0.5)) ** 2 <= 1.0), (58, 80, 40))


# ====================================================================== Pasif - Büyü Dalgası
def _icon_fit(path, size):
    """Asa ikonu oyundaki boyuna yakın (en uzun kenar ~size Büyücü pikseli; tabanca EL._icon ile oyun ölçeğinde)."""
    im = Image.open(os.path.join(PROJECT, path)).convert('RGBA')
    im = im.crop(im.getbbox())
    k = size / max(im.width, im.height)
    small = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.BOX)
    a = np.array(small)
    a[:, :, 3] = np.where(a[:, :, 3] > 110, 255, 0)
    return Image.fromarray(a, 'RGBA')


WEAPONS = [
    dict(icon=_icon_fit('assets/weapons/arcane/icon_v3.png', 24), slot=(0, -69), kind='orb', pal=ARC, period=12, tgt=0, phase=0.0, first=3),
    dict(icon=_icon_fit('assets/weapons/fire/firestaff_icon_v3.png', 24), slot=(34, -39), kind='orb', pal=FIRE, period=10, tgt=1, phase=2.1, first=6),
    dict(icon=EL._icon('assets/weapons/tabanca/icon_v2.png', 0.28875), slot=(-34, -39), kind='bullet', pal=EL.BRASS, period=14, tgt=2, phase=4.2, first=1),
]
for _w in WEAPONS:
    if _w['kind'] == 'orb':  ## asanın tepesi (sağ üst köşe)
        _w['muzzle'] = (_w['icon'].width / 2.0 - 3.0, -_w['icon'].height / 2.0 + 3.0)
    else:
        _w['muzzle'] = (_w['icon'].width / 2.0 - 1.0, -_w['icon'].height / 2.0 + 3.0)


def icon_outline(icon, col):
    a = np.array(icon)
    h, w = a.shape[:2]
    m = np.zeros((h + 2, w + 2), dtype=bool)
    m[1:-1, 1:-1] = a[:, :, 3] > 0
    out = np.zeros((h + 2, w + 2, 4), dtype=np.uint8)
    out[P.dilate(m) & ~m] = col + (255,)
    return Image.fromarray(out, 'RGBA')


def scene_pasif():
    W, H = 300, 156
    ex, feet = 72, 132
    TRIG = (16, 46)  ## E / R kullanıldığı kareler
    F = 74
    TARGETS = EL.TARGETS
    shots = []  ## (kare, silah, güçlü mü)
    for wi, w in enumerate(WEAPONS):
        nxt = w['first']
        for f in range(F):
            if any(f == t + 2 for t in TRIG):
                shots.append((f, wi, True))
                nxt = f + w['period']
            elif f == nxt and not any(t <= f < t + 2 for t in TRIG):
                shots.append((f, wi, False))
                nxt += w['period']
    hit_log = {}
    frames = []
    for f in range(F):
        img = grass(W, H, 330)
        gv = layer(W, H)
        for t0 in TRIG:
            k = f - t0
            if 0 <= k < 6:
                P.shock_ring(gv, ex, feet, 6.0 + 18.0 * P.ease_out(k / 6.0), 2.0, k / 6.0, ARC, 0.5, seed=t0, break_from=0.4)
        cc(img, gv)
        for i, (x, sf) in enumerate(TARGETS):
            hk = [f - hf for (hf, strong) in hit_log.get(i, []) if 0 <= f - hf < 2]
            strong = any(st for (hf, st) in hit_log.get(i, []) if 0 <= f - hf < 2)
            put_slime_fx(img, x, sf, tint=ARC if strong else None, squash=0.5 if hk and min(hk) == 0 else 0.0)
        put_mage(img, f, ex, feet)
        cv = layer(W, H)
        for t0 in TRIG:  ## karakterden yayılan mor dalga (silahların arkasından geçer)
            k = f - t0
            if k == 0:
                P.disc_flash(cv, ex + 8, feet - 17, 2.5, core=CREAM, rim=ARC[4])
                P.star(cv, ex + 8, feet - 17, 4, P.WHITE, ARC[3], diag=True)
            if 0 <= k < 5:
                P.shock_ring(cv, ex, feet - EL.ORIGIN_UP - 14, 8.0 + 52.0 * P.ease_out((k + 1) / 5.0), 2.2, k / 5.0, ARC, 0.78,
                             seed=t0 + 1, break_from=0.45)
        cc(img, cv)
        cv = layer(W, H)
        for wi, w in enumerate(WEAPONS):
            cx, cy = EL.weapon_center(w, ex, feet, f)
            tx, tsf = TARGETS[w['tgt']]
            d = math.hypot(tx - cx, tsf - 8 - cy) or 1.0
            ux, uy = (tx - cx) / d, (tsf - 8 - cy) / d
            for t0 in TRIG:  ## güçlü atışta hedefin tersine sert geri tepme (WeaponJuice.arcane_surge, oyunda var)
                k = f - (t0 + 2)
                if 0 <= k < 4:
                    back = (5.0, 3.0, 1.5, 0.5)[k]
                    cx, cy = cx - ux * back, cy - uy * back
            charged = any(t0 + 1 <= f <= t0 + 3 for t0 in TRIG)
            if charged:
                lvl = [f - t0 for t0 in TRIG if t0 + 1 <= f <= t0 + 3][0]
                ol = icon_outline(w['icon'], ARC[4] if lvl == 2 else ARC[3])
                comp(img, ol, cx - ol.width / 2.0, cy - ol.height / 2.0)
            EL.put_icon(img, w['icon'], cx, cy)
            if any(f == t0 + 1 for t0 in TRIG):
                P.star(cv, cx + w['icon'].width / 2.0, cy - w['icon'].height / 2.0, 2, P.WHITE, ARC[3])
        for (f0, wi, strong) in shots:  ## mermiler
            w = WEAPONS[wi]
            dt = f - f0
            if dt < 0:
                continue
            cx, cy = EL.weapon_center(w, ex, feet, f0)
            p0 = (cx + w['muzzle'][0], cy + w['muzzle'][1])
            tx, tsf = TARGETS[w['tgt']]
            p1 = (tx + 0.5, tsf - 8.0)
            dx, dy = p1[0] - p0[0], p1[1] - p0[1]
            dist = math.hypot(dx, dy)
            ang = math.atan2(dy, dx)
            n = max(1, int(math.ceil(dist / 26.0)))
            if dt == 0:
                if strong:
                    P.disc_flash(cv, p0[0], p0[1], 3.0, core=CREAM, rim=ARC[4])
                    P.star(cv, p0[0], p0[1], 5, P.WHITE, ARC[3], diag=True)
                else:
                    P.star(cv, p0[0], p0[1], 2, CREAM, w['pal'][3])
            if dt < n:
                k = (dt + 0.6) / n
                hx, hy = p0[0] + dx * k, p0[1] + dy * k
                if strong:
                    L = min(16.0, dist * k)
                    EL.strip(cv, (hx - math.cos(ang) * (L + 2), hy - math.sin(ang) * (L + 2)), (hx - math.cos(ang) * 2, hy - math.sin(ang) * 2),
                             0.0, 3.0, ARC)
                if w['kind'] == 'orb':
                    P.puffs(cv, [(hx, hy, 2.7 if strong else 1.9)], w['pal'])
                    cv.px(hx - math.cos(ang) * 3, hy - math.sin(ang) * 3, w['pal'][3])
                else:
                    EL.bullet(cv, hx, hy, ang, EL.BRASS)
            elif dt == n:
                hit_log.setdefault(w['tgt'], []).append((f, strong))
            if strong and n <= dt < n + 7:
                P.burst(cv, p1[0], p1[1], 10.0, (dt - n) / 7.0, ARC, P.SHADOW, seed=wi * 5 + f0, n_puffs=6)
            elif not strong and dt in (n, n + 1):
                P.star(cv, p1[0] - math.cos(ang) * 4, p1[1] - math.sin(ang) * 4, 3 if dt == n else 1, CREAM, w['pal'][3], diag=dt == n)
        cc(img, cv)
        frames.append(img)
    return frames


def main():
    save('buyucu_q.gif', scene_q(), 66, 'Q  Büyü Değişimi: kitap çevrilir, set zerreleri değişir (Set 1 soğuk, Set 2 sıcak)', scale=4)
    save('buyucu_e_lanet.gif', scene_e_lanet(), 50, 'E  Arcane Lanet: lanet gözü sekip her yaratığı mühürler')
    save('buyucu_e_hortum.gif', scene_e_hortum(), 66, 'E  Hortum: dolu huni, menekşe kıvılcım, havalanan yaratık')
    save('buyucu_r_meteor.gif', scene_r(), 66, 'R  Meteor: rün çemberi 3 sn dolar, uyarı gölgesi, meteor, krater')
    save('buyucu_pasif.gif', scene_pasif(), 66, 'Pasif  Büyü Dalgası: E/R anında mor dalga, silahlar yüklenip birlikte ateşler')
    print('tamam:', sorted(n for n in os.listdir(EL.OUT) if n.startswith('buyucu')))


if __name__ == '__main__':
    main()
