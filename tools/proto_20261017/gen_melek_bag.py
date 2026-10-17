"""2026-10-17 prototipleri v2: MELEK Q/E - "SİHİRLİ BAĞ + DALGALANMA" (madde 204'ün devamı; oyuna bağlı DEĞİL).
Kullanıcı ilk seti (Hale İnişi / Mana Kanatları, gen_melek_fx.py) beğenmedi: "sihirli bir bağ kuruyormuş da o bağdan müttefiğe bir
dalgalanma gidiyormuş gibi gözüksün". MEKANİK AYNI (Q Can Basma: anında %15 + 6 sn tik; E Kalkan Yenileme: 6 sn tik; ikisi de en düşük
can/kalkanlı dosta kilitlenir, bağ kurulunca menzil kontrol edilmez).
Ortak dil: Melek'in belinde 2:1 bağ halkası (dönen 4 rün çentiği), bağ halkanın yanından çıkıp dostun belindeki halkaya HAFİF KAVİSLE
uzanır (büyü ipi havada süzülür). Kuruluş: halka Melek'te açılır, bağın parlak başı dosta koşar, değince dostta halka + parlama
(Q'da anlık can artısı). Süre (6 sn): bağ hafifçe dalgalanır (dalga tepeleri Melek'ten dosta akar). Her tik (1 sn): Melek'in halkası
parlar, bağın üstünden DALGA PAKETİ dosta koşar; varınca dostun halkası dışa dalgalanır (yankı halkası) + Q yeşil artı / E mana
kristali. Bitiş: bağ ortadan incelip hilaller hâlinde kopar, halkalar söner.
  A  Işık İpi   tek, dolu ışık şeridi (krem çekirdek, açık/orta ton, yumuşak kontur); dalga = şeridin kalınlaşıp kıvrılan paketi
  B  Örgü Bağ   iki ince ip birbirine sarılır (önde/arkada tonları farklı, örgü düğümleri); dalga = iplerin açılıp göz biçimi
                yapması + içinde koşan ışık küresi
Renk: Q = şifa yeşili (`LIFE`, can sayısı rengi), dalga paketi hale altınına döner (`PKQ`); E = mana kalkanı mavisi (`MANA`), paket krem.
Ölçek: 1 GIF px = 1 Melek sanat pikseli = 0,903 dünya. Dost (Şovalye) 116 px (~105 dünya) uzakta; gerçek menzil 300 dünya - bağ her
uzunlukta aynı kalınlıkta, dalga paketi sabit HIZLA koşar (~195 px/sn, ~175 dünya/sn) -> uzak dosta daha geç varır. 6 sn GIF'te 3 tikle kısaltıldı.
Çıktı: out/melek_bag_q.gif, out/melek_bag_e.gif (üst sıra A, alt sıra B)
Kullanım (proje kökünden): python -I tools/proto_20261017/gen_melek_bag.py
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_melek_fx as M  # noqa: E402  (karakterler, halka, artı, kristal, katman araçları)
from gen_melek_fx import P, comp, font, grass, layer, cc, ring, plus, diamond, crack_keep, put_char, MEL, ALLY  # noqa: E402

TAU = math.tau
LIFE, MANA, HOLY, CREAM = M.LIFE, M.MANA, M.HOLY, M.CREAM
PKQ = [LIFE[0], LIFE[1], HOLY[2], HOLY[3], CREAM]  ## Q dalga paketi: yeşilden hale altınına
PKE = [MANA[0], MANA[1], MANA[3], MANA[4], CREAM]
FPS = 15.0
RING_RX, RING_RY = 9.5, 3.3  ## dostun bel halkası (kullanıcı: "sihir efekti biraz büyük" -> 11 x 3,8'den küçüldü)
WAIST = -13
TICKS = (22, 37, 52)
CONNECT = 9  ## bağın dosta değdiği kare
END = 60
F = 70
WAVE_SPEED = 13.0  ## px/kare (~195 px/sn)


# ====================================================================== bağ eğrisi
def bond_base(p0, p1, lift):
    """p0 -> p1 hafif yukarı kavisli eğri: yoğun örnekler (0,4 px aralık), normal (yukarı yönlü), yay uzunluğu s."""
    L0 = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
    n = max(8, int(L0 * 2.5))
    u = np.linspace(0.0, 1.0, n)
    cx, cy = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2 - 2 * lift
    bx = (1 - u) ** 2 * p0[0] + 2 * (1 - u) * u * cx + u * u * p1[0]
    by = (1 - u) ** 2 * p0[1] + 2 * (1 - u) * u * cy + u * u * p1[1]
    tx, ty = np.gradient(bx), np.gradient(by)
    tl = np.hypot(tx, ty) + 1e-9
    nx, ny = ty / tl, -tx / tl  ## sola dönük normal (soldan sağa giderken yukarı)
    s = np.concatenate([[0.0], np.cumsum(np.hypot(np.diff(bx), np.diff(by)))])
    return bx, by, nx, ny, s


def raster(cv, xs, ys, hw, pal, hot=None, outline=True, edge=None):
    """Örnek noktalarına en yakın uzaklıkla dolu şerit: hw örnek başına yarı genişlik; hot (bool) örneklerde paket paleti.
    Ton: çekirdek pal[4], orta pal[3], kenar pal[2]; kontur edge (vars. pal[1]). Sadece hw>0,3 olan örnekler çizilir."""
    keep = hw > 0.3
    if not keep.any():
        return np.zeros((cv.h, cv.w), dtype=bool)
    xs, ys, hw = xs[keep], ys[keep], hw[keep]
    hot = hot[keep] if hot is not None else None
    pad = hw.max() + 2
    c0, c1 = max(0, int(xs.min() - pad)), min(cv.w, int(xs.max() + pad) + 1)
    r0, r1 = max(0, int(ys.min() - pad)), min(cv.h, int(ys.max() + pad) + 1)
    if c1 <= c0 or r1 <= r0:
        return np.zeros((cv.h, cv.w), dtype=bool)
    yy, xx = np.mgrid[r0:r1, c0:c1]
    X, Y = (xx + 0.5).ravel(), (yy + 0.5).ravel()
    D = (X[None, :] - xs[:, None]) ** 2 + (Y[None, :] - ys[:, None]) ** 2
    idx = D.argmin(axis=0)
    d = np.sqrt(D[idx, np.arange(D.shape[1])])
    h = hw[idx]
    m = d <= h
    k = d / np.maximum(h, 0.5)
    tone = np.where(k < 0.36, 4, np.where(k < 0.72, 3, 2))
    full = np.zeros((cv.h, cv.w), dtype=bool)
    for tt in (2, 3, 4):
        sel = m & (tone == tt)
        for usehot in ((False, True) if hot is not None else (False,)):
            s2 = sel & (hot[idx] == usehot) if hot is not None else sel
            if not s2.any():
                continue
            mm = np.zeros((cv.h, cv.w), dtype=bool)
            mm[r0:r1, c0:c1] = s2.reshape(r1 - r0, c1 - c0)
            cv.put(mm, (pal if not usehot else hot_pal(pal))[tt])
    full[r0:r1, c0:c1] = m.reshape(r1 - r0, c1 - c0)
    if outline:
        cv.put(P.outline_of(full) & ~cv.filled(), edge or pal[1])
    return full


def hot_pal(pal):
    return PKQ if pal is LIFE else PKE


# ====================================================================== bağ durumu (iki stil aynı zamanlamayı paylaşır)
def bond_state(f, total):
    """Karede bağın görünen kısmı ve paketler: (head_s, packets [(merkez_s, güç)], dissolve 0..1)."""
    if f < 2:
        head = -1.0
    elif f < CONNECT:
        head = total * P.ease_out((f - 2) / (CONNECT - 2))
    else:
        head = total + 1
    packets = []
    for t0 in TICKS:
        c = (f - t0) * WAVE_SPEED
        if -6 <= c <= total + 10:
            packets.append((c, 1.0))
    if CONNECT - 2 <= f < CONNECT + 1:  ## kuruluşta başın kendisi parlak bir paket
        packets.append((min(head, total), 0.8))
    dis = 0.0 if f < END else min(1.0, (f - END) / 7.0)
    return head, packets, dis


def gauss_sum(s, packets, sigma):
    g = np.zeros_like(s)
    for (c, w) in packets:
        g = np.maximum(g, w * np.exp(-((s - c) / sigma) ** 2))
    return g


def ripple_osc(s, packets, sigma, lam):
    o = np.zeros_like(s)
    for (c, w) in packets:
        o += w * np.exp(-((s - c) / sigma) ** 2) * np.sin(TAU * (s - c) / lam)
    return o


def dissolve_keep(s, total, dis, seed=1.7):
    """Bitiş: ortadan başlayan, hilal gibi incelen kopmalar -> yarı genişlik çarpanı 0..1."""
    if dis <= 0:
        return np.ones_like(s)
    u = s / max(total, 1)
    pat = 0.55 * np.sin(u * 23 + seed) + 0.45 * np.sin(u * 9 + seed * 2.3)
    mid = 1.0 - np.abs(u - 0.5) * 2  ## ortada önce
    thr = 1.0 - 2.2 * dis - 0.6 * mid * dis
    return np.clip((thr - pat) / 0.5, 0, 1) ** 0.7


def bond_a(cv, p0, p1, f, pal):
    """A Işık İpi."""
    bx, by, nx, ny, s = bond_base(p0, p1, 5.0)
    total = s[-1]
    head, packets, dis = bond_state(f, total)
    if head < 0:
        return None
    t = f / FPS
    taper = np.clip(np.minimum(s, total - s) / 10.0, 0, 1) ** 0.6
    g = gauss_sum(s, packets, 10.0)
    disp = 1.0 * np.sin(TAU * (s / 30.0 - 0.9 * t)) * taper + 3.0 * ripple_osc(s, packets, 9.0, 19.0) * taper
    hw = (0.9 + 0.9 * g) * np.clip(0.55 + 0.45 * taper, 0, 1) * dissolve_keep(s, total, dis)
    hw = np.where(s <= head, hw, 0.0)
    if head < total:  ## koşan baş: uçta incelir
        hw *= np.clip((head - s) / 6.0 + 0.35, 0, 1)
    xs, ys = bx + nx * disp, by + ny * disp
    raster(cv, xs, ys, hw, pal, hot=g > 0.35)
    if head < total:
        i = int(np.searchsorted(s, head))
        i = min(i, len(s) - 1)
        P.disc_flash(cv, xs[i], ys[i], 1.6, core=CREAM, rim=pal[3])
        P.star(cv, xs[i], ys[i], 2, P.WHITE, pal[3])
    return total


def bond_b(back, front, p0, p1, f, pal):
    """B Örgü Bağ: iki ip birbirine sarılır; paket = iplerin göz biçimi açılması + ortasında koşan ışık küresi."""
    bx, by, nx, ny, s = bond_base(p0, p1, 5.0)
    total = s[-1]
    head, packets, dis = bond_state(f, total)
    if head < 0:
        return None
    t = f / FPS
    taper = np.clip(np.minimum(s, total - s) / 12.0, 0, 1) ** 0.7
    g = gauss_sum(s, packets, 10.0)
    amp = (1.7 * taper + 3.5 * g * taper)
    phi = TAU * (s / 24.0 - 1.1 * t)
    kd = dissolve_keep(s, total, dis)
    vis = s <= head
    for sign in (1.0, -1.0):
        disp = sign * amp * np.sin(phi)
        depth = sign * np.cos(phi)  ## >0 önde
        xs, ys = bx + nx * disp, by + ny * disp
        hw = (0.75 + 0.2 * g) * kd * vis
        if head < total:
            hw *= np.clip((head - s) / 6.0 + 0.35, 0, 1)
        fr = depth >= 0
        dark = [pal[0], pal[0], pal[1], pal[2], pal[3]]  ## arkada kalan kısım bir ton koyu
        raster(back, xs[~fr], ys[~fr], hw[~fr], dark, outline=False)
        raster(front, xs[fr], ys[fr], hw[fr], pal, hot=(g > 0.35)[fr], outline=False)
    ## koşan ışık küresi (paket ortası) + kuruluşta baş
    pk = [(c, w) for (c, w) in packets if 0 <= c <= total]
    if head < total:
        pk.append((max(0.0, head), 1.0))
    for (c, w) in pk:
        i = min(int(np.searchsorted(s, c)), len(s) - 1)
        hp = hot_pal(pal)
        P.disc_flash(front, bx[i], by[i], 1.7, core=CREAM, rim=hp[3])
        P.star(front, bx[i], by[i], 2, P.WHITE, hp[3])
    return total


# ====================================================================== halkalar
def bond_ring(back, front, cx, cy, f, pal, scale=1.0, bright=False, spin_dir=1):
    rx, ry = RING_RX * scale, RING_RY * scale
    if rx < 1.5:
        return
    ring(back, front, cx, cy, rx, ry, pal, thick=2, bright=bright, edge=pal[1])
    a0 = f * 0.12 * spin_dir
    for i in range(4):  ## 4 rün çentiği (halkanın üstünde parlak 2 px)
        a = a0 + i * TAU / 4
        x, y = cx + math.cos(a) * rx, cy + math.sin(a) * ry
        tgt = front if math.sin(a) >= 0 else back
        col = CREAM if bright else hot_pal(pal)[3]
        tgt.px(x, y, col)
        tgt.px(x + (1 if math.cos(a) < 0 else -1), y, col)


## Melek'in halesi (idle aşağı karelerinden ölçüldü, 2026-10-17 düzeltmesi - eski M.HALO x'i 2 px sağdaydı):
## altın halka piksel İNDEKSİ x 20..27 / satır 3..5 (kontur x 19..28 / satır 2..6), yani merkez karakterin TAM ortası;
## idle karelerinde hale 0 / -1 / 0 / +1 px oynar. `ring()` (px) indeks koordinatı, maske/şerit çizimi sürekli koordinat kullanır
## (indeks i'nin merkezi i+0,5) - ikisi ayrı tutulur, yoksa ışık halkası haleye göre 1 px kayık (simetrik değil) çıkar.
HALO_BOB = (0, -1, 0, 1)
HALO_RX = 3.5  ## altın halka (indeks merkezleri arası yarıçap)
HALO_OUTLINE = (80, 54, 21)  ## sprite halesinin koyu kahve konturu (iç satır dahil, tek ton)


def halo_pos(cx, feet, f):
    """(indeks x, indeks y, sürekli x, sürekli y) - halenin merkezi bu karede."""
    bob = HALO_BOB[(f // 4) % 4]
    return cx - 0.5, feet - 36 + bob, cx, feet - 35.5 + bob


def tint_halo(img, hx, hy, pal, bright=False):
    """Bağ sürerken Melek'in kendi halesi bağın rengine bürünür (sprite'taki altın pikseller yerinde yeniden boyanır;
    idle sallanmasına dayanıklı: hale çevresindeki kutuda altın tonlu pikseller aranır)."""
    a = np.array(img)
    x0, x1, y0, y1 = int(hx - 6), int(hx + 6), int(hy - 3), int(hy + 3)
    box = a[y0:y1, x0:x1]
    r, g, b = box[:, :, 0].astype(int), box[:, :, 1].astype(int), box[:, :, 2].astype(int)
    gold = (box[:, :, 3] > 0) & (r > 150) & (g > 110) & (b < 150) & (r - b > 60)
    lum = (r + g) / 2
    ## bir ton aşağı eşlenir (beyaza boyanınca koyu iç kontur satırlarıyla "çizgili kutu" gibi duruyordu)
    for cond, col in ((gold & (lum > 215), pal[4] if bright else pal[3]), (gold & (lum > 170) & (lum <= 215), pal[3] if bright else pal[2]),
                      (gold & (lum <= 170), pal[2] if bright else pal[1])):
        box[cond, 0], box[cond, 1], box[cond, 2] = col
    ## konturu da bağın koyu tonuna (2. düzeltme: hale DIŞINA ışık halkası koymak efekti büyütüyordu, bağ da o halkadan
    ## çıkıyordu -> hale hiç büyümeden kendi konturuyla parlar, bağ halenin sağ altın pikselinden çıkar)
    ol = (box[:, :, 3] > 0) & (r == HALO_OUTLINE[0]) & (g == HALO_OUTLINE[1]) & (b == HALO_OUTLINE[2])
    box[ol, 0], box[ol, 1], box[ol, 2] = pal[2] if bright else pal[1]
    a[y0:y1, x0:x1] = box
    img.paste(Image.fromarray(a, 'RGBA'))


def scene(pal, kind):
    """kind 'q' / 'e'. İki sıra: üst A Işık İpi, alt B Örgü Bağ."""
    W, H = 200, 132
    mx, ax = 42, 158
    rows = (58, 124)
    frames = []
    for f in range(F):
        img = grass(W, H, 140 if kind == 'q' else 260)
        for ri, feet in enumerate(rows):
            back, front, top = layer(W, H), layer(W, H), layer(W, H)
            cy = feet + WAIST
            ix, iy, hcx, hcy = halo_pos(mx, feet, f)  ## Melek'in halesi bu karede (idle sallanması dahil)
            ## bağ halenin SAĞ ALTIN PİKSELİNİN merkezinden (indeks cx+3, iy) çıkar: 1 px başlar, açıldıkça kalınlaşır
            p0, p1 = (hcx + HALO_RX, hcy), (ax - RING_RX + 1, cy - 1)
            total = bond_base(p0, p1, 5.0)[4][-1]
            ## (bağın kaynağı Melek'in halesi: aşağıda put_char'dan sonra tint_halo ile bağ rengine boyanır)
            ## dostun halkası: değince doğar
            if CONNECT <= f < END + 7:
                sc = P.ease_out(min(1.0, (f - CONNECT + 1) / 3.0))
                if f >= END:
                    sc = 1.0 - (f - END) / 7.0
                arrive = [t0 + int(math.ceil(total / WAVE_SPEED)) for t0 in TICKS]
                br = f in (CONNECT, CONNECT + 1) or any(0 <= f - a <= 1 for a in arrive)
                bond_ring(back, front, ax, cy, f, pal, sc, br, spin_dir=-1)
                ## varışta dışa yankı halkası (dalgalanma) + artı / kristal
                for a in [CONNECT] + arrive:
                    k = f - a
                    if 0 <= k <= 6:
                        tt = k / 6.0
                        R = RING_RX + 7 * P.ease_out(tt)
                        ring(back, front, ax, cy, R, R * 0.35, pal, thick=1, keep=crack_keep(a * 0.7, max(0.0, tt - 0.3) * 1.5, 5))
                    big = a == CONNECT
                    if 0 <= k <= 7 and (kind == 'q' or not big):
                        if kind == 'q':
                            plus(top, ax + 1, feet - 22 - k * 1.3, (3 if big else 2) if k < 5 else 1, LIFE)
                        else:
                            diamond(top, ax + 1, feet - 22 - k * 1.2, 1.5 if k < 5 else 1.0, 2.5 if k < 5 else 1.6, MANA)
                    if big and kind == 'e' and 0 <= k <= 3:
                        P.star(top, ax + 1, feet - 21, 4 - k, P.WHITE, MANA[3], diag=(k < 2))
            ## Melek'in kendi tiki (kendine de basar)
            for t0 in TICKS:
                k = f - t0
                if 0 <= k <= 7:
                    if kind == 'q':
                        plus(top, mx - 1, feet - 22 - k * 1.3, 2 if k < 5 else 1, LIFE)
                    else:
                        diamond(top, mx - 1, feet - 22 - k * 1.2, 1.5 if k < 5 else 1.0, 2.5 if k < 5 else 1.6, MANA)
            if kind == 'q' and 1 <= f <= 8:  ## anlık can (Melek)
                plus(top, mx - 1, feet - 22 - (f - 1) * 1.3, 3 if f < 6 else 2, LIFE)
            ## bağ: Melek'in halesinden dostun belindeki halkaya
            bl = layer(W, H)
            if ri == 0:
                bond_a(bl, p0, p1, f, pal)
                top.rgba[bl.filled()] = bl.rgba[bl.filled()]
            else:
                bb = layer(W, H)
                bond_b(bb, bl, p0, p1, f, pal)
                front.rgba[bb.filled()] = bb.rgba[bb.filled()]
                top.rgba[bl.filled()] = bl.rgba[bl.filled()]
            cc(img, back)
            put_char(img, MEL, f, mx, feet)
            if 1 <= f < END + 3:  ## bağ sürerken hale bağın renginde
                tint_halo(img, ix, iy, pal, bright=f <= 2 or any(0 <= f - t0 <= 1 for t0 in TICKS))
            put_char(img, ALLY, f + 2, ax, feet)
            cc(img, front)
            cc(img, top)
        frames.append(img)
    return frames


def save(name, frames, ms, title, scale=3):
    f15 = font(15)
    big = []
    labels = [(8, 4, title), (8, 4 + 18, 'A  Işık İpi'), (8, 66 * scale + 4, 'B  Örgü Bağ')]
    for fr in frames:
        im = fr.convert('RGB').resize((fr.width * scale, fr.height * scale), Image.NEAREST)
        d = ImageDraw.Draw(im)
        d.line([(0, 66 * scale), (im.width, 66 * scale)], fill=(70, 104, 50), width=2)
        for (x, y, text) in labels:
            d.text((x + 1, y + 1), text, fill=(20, 30, 14), font=f15)
            d.text((x, y), text, fill=(250, 246, 226), font=f15)
        big.append(im.quantize(colors=230, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE))
    big[0].save(os.path.join(M.OUT, name), save_all=True, append_images=big[1:], duration=ms, loop=0, disposal=1)


def main():
    save('melek_bag_q.gif', scene(LIFE, 'q'), 66, 'Q  Can Basma: bağ kurulur, her tikte bağdan dosta şifa dalgası (6 sn - burada 3 tik)')
    save('melek_bag_e.gif', scene(MANA, 'e'), 66, 'E  Kalkan Yenileme: bağ kurulur, her tikte bağdan dosta mana dalgası (6 sn - burada 3 tik)')
    print('tamam:', sorted(n for n in os.listdir(M.OUT) if n.startswith('melek_bag')))


if __name__ == '__main__':
    main()
