# DERİN ORMAN bölge zemini GERÇEK KAROLAR olarak (madde 363; kullanıcı: "Bölge zeminlerini Harita.tmx'e gerçek karolar olarak da yaz, Tiled'da da göreyim").
# Eskiden (madde 361/362) zemin oyun içinde shader'da piksel piksel hesaplanıyordu (harita_renk.gdshaderinc do_zemin_renk / do_zemin_uygula) ve Tiled'da
# bölgeler yeşil görünüyordu. Şimdi AYNI hesap burada (numpy, birebir port) yapılıp karolara PİŞİRİLİR; oyunda shader artık zemin hesaplamaz:
#   - "Yer/Derin orman zemini" (YENİ katman, Zemin Çimen'in hemen üstü, ground_texel_pass'ın zemin katmanlarından): bölge zemininin göründüğü her
#     piksel opak, görünmediği (bölge dışı / su pikseli) saydam -> altındaki çimen/toprak kendi shader'ıyla görünür. Görünen kaynak = Zemin Çimen
#     pikseli (opaksa) yoksa Zemin Toprak; toprak payı karonun rengiyle (smoothstep(0.18, 0.38, r - 0.55 g)) -> yollar bölgenin yol karosu.
#   - Yerinde değiştirilen karolar (hücre aynı, karo yeni tileset'ten; çarpışma hücreye bağlı olduğu için değişmez):
#       "Su ayrıntılar 2"  : kıyı çimeni (su pikselleri kalır; ANİMASYONLU karolar kare kare pişer, aynı süreler)
#       "Orman parçaları 2": plato tepesinin yeşil pikselleri;  "Orman parçaları", "-1", "3", "4": uçurum dudaklarının yeşil pikselleri
#       Plato karolarında bölge zemini alan pikseller ALFA 254 ile işaretlenir (gözle görünmez, PISMIS_ALFA): plato shader'ı (orman_parcalari_doku)
#       çimen öbek/çizgi/nokta/gürültü aşamalarını onlara uygulamaz (eskiden bölge zemini en sonda üstlerine yazılıyordu).
#   - "Çimler"deki tam düz çimen karoları (başıboş) pişmiş hücrelerde silinir (zeminin üstünde yeşil kare kalmasın).
# Karolar tekilleştirilir -> harita/derin_orman_zemin.png + "harita/Derin orman zemin.tsx" (animasyonlar Tiled <animation>, kareler alt alta).
# Kaynak zemin dokusu: tools/derin_orman/out/zemin_kaynak.png (gen_zemin_dokusu.py), bölge maskesi: gen_bolge_maskesi.build_mask.
# place_derin_orman.py --apply her yazımda çağırır (yedekten kurulan metin üstünde); tek başına çalıştırılmaz.
import os
import re
import xml.etree.ElementTree as ET

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..', '..'))
HARITA = os.path.join(PROJECT, 'harita')
OVERLAY = 'Derin orman zemini'
## write_atlas'ın parçaları yazdığı klasör (madde 385: doğrulama koşusu geçici klasöre yazar; tileset'ler hep HARITA'dan okunur)
ATLAS_DIR = HARITA
## Madde 372: zemin atlası PARÇALARA bölünür (harita/derin_orman_zemin_NN.png + "Derin orman zemin NN.tsx"): TileSetAtlasSource.create_tile karo sayısının
## karesiyle yavaşlıyor (14.072 karo tek kaynakta = harita yüklemesine +4,5 sn; 8 x 2000 = 10x hızlı).
PART_COLS = 32
PART_LIMIT = 1000


def part_png(i):
    return 'derin_orman_zemin_%02d.png' % (i + 1)


def part_tsx(i):
    return 'Derin orman zemin %02d.tsx' % (i + 1)


def _morton(qx, qy):
    k = 0
    for b in range(10):
        k |= ((qx >> b) & 1) << (2 * b) | ((qy >> b) & 1) << (2 * b + 1)
    return k


def cell_key(c):
    """Hücre -> 16x16 hücre öbeğinin Z-sırası (karoların parçalara dizilişi)."""
    return _morton(max(0, c[0]) // 16, max(0, c[1]) // 16)
PISMIS_ALFA = 254

## --- harita_renk.gdshaderinc ile AYNI sabitler (eski shader sürümü git'te; burası artık tek kaynak) ---
KOKU = np.array([-2.0, 21.0], np.float32)
BOYU = np.float32(4096.0)
KENAR = np.float32(0.14)
## Batı (1): madde 364'te gölcükler KALDIRILDI (kullanıcı: "siyah siyah öbekleri beğenmedim doğal durmuyor") - B yaması yok (eşik 2), gölcük
## bölgesi yok (-1); yerine nesne katmanında paketin kök tümsekleri (place_derin_orman.py BATI 'extra').
DOZ = {0: (0.62, 52.0, 0.13, 0.05), 1: (2.0, 40.0, 0.12, 0.05), 2: (2.0, 40.0, 0.2, 0.05), 3: (0.6, 36.0, 0.12, 0.06)}
GOLCUK_ZONE = -1
GOLCUK_KENAR = np.array([0.30, 0.12, 0.10], np.float32)
GOLCUK_PARILTI = np.array([0.33, 0.35, 0.47], np.float32)
GOLCUK_SUS = 0.22
SATIR = 6
CIM_L = np.float32(0.579)
TOPRAK_L = np.float32(0.507)
SINIR = np.float32(0.5)
SINIR_GURULTU = np.float32(0.8)
SECIM_GURULTU = np.float32(0.5)
LUMA = np.array([0.299, 0.587, 0.114], np.float32)
FULL_GRASS = np.array([0.478, 0.678, 0.333], np.float32)
F = np.float32


def _u32(a):
    return a.astype(np.uint32)


def do_hash(x, y):
    """Tam sayı hash (shader do_hash ile aynı): floor + 1048576, uint karıştırma -> [0, 1]."""
    ux = _u32(np.floor(x).astype(np.int64) + 1048576)
    uy = _u32(np.floor(y).astype(np.int64) + 1048576)
    with np.errstate(over='ignore'):
        h = (ux * np.uint32(1597334677)) ^ (uy * np.uint32(3812015801))
        h = (h ^ (h >> np.uint32(16))) * np.uint32(2246822519)
        h = (h ^ (h >> np.uint32(13))) * np.uint32(3266489917)
        h = h ^ (h >> np.uint32(16))
    return (h & np.uint32(16777215)).astype(np.float32) / F(16777215.0)


def do_gurultu(x, y):
    x, y = F(0.8) * x - F(0.6) * y, F(0.6) * x + F(0.8) * y
    ix, iy = np.floor(x), np.floor(y)
    fx, fy = x - ix, y - iy
    fx = fx * fx * (F(3.0) - F(2.0) * fx)
    fy = fy * fy * (F(3.0) - F(2.0) * fy)
    a = do_hash(ix, iy)
    b = do_hash(ix + 1, iy)
    c = do_hash(ix, iy + 1)
    d = do_hash(ix + 1, iy + 1)
    return (a + (b - a) * fx) + ((c + (d - c) * fx) - (a + (b - a) * fx)) * fy


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


class Field:
    """Bölge zemini alanı: dünya pikselinde (tam sayı px, merkez px + 0.5) renk + etkinlik."""

    def __init__(self, mask_rgba, src_atlas):
        self.mask = np.asarray(mask_rgba.convert('RGBA'), np.float32) / F(255.0)
        self.src = np.asarray(src_atlas.convert('RGBA'), np.float32) / F(255.0)

    def bolge(self, px, py):
        u = (px + F(0.5) - KOKU[0]) / BOYU
        v = (py + F(0.5) - KOKU[1]) / BOYU
        out = (u < -KENAR) | (v < -KENAR) | (u > 1 + KENAR) | (v > 1 + KENAR)
        u = np.clip(u, F(0.5 / 256.0), F(1.0 - 0.5 / 256.0)) * F(256.0) - F(0.5)
        v = np.clip(v, F(0.5 / 256.0), F(1.0 - 0.5 / 256.0)) * F(256.0) - F(0.5)
        x0 = np.floor(u)
        y0 = np.floor(v)
        tx = (u - x0)[:, None]
        ty = (v - y0)[:, None]
        x0 = x0.astype(np.int64)
        y0 = y0.astype(np.int64)
        x1 = np.minimum(x0 + 1, 255)
        y1 = np.minimum(y0 + 1, 255)
        m = self.mask
        z = (m[y0, x0] * (1 - tx) + m[y0, x1] * tx) * (1 - ty) + (m[y1, x0] * (1 - tx) + m[y1, x1] * tx) * ty
        z[out] = 0
        top = z.sum(1)
        z = np.where((top > 1)[:, None], z / np.maximum(top, 1e-6)[:, None], z)
        return z

    def karo(self, b, satir, hx, hy, ix, iy, tohum):
        b = np.asarray(b)
        satir = np.asarray(satir)
        bf, sf, tf = b.astype(np.float32), satir.astype(np.float32), np.asarray(tohum, np.float32)
        yuva = np.floor(do_hash(hx + tf * F(1013.0), hy + bf * F(7919.0) + sf * F(331.0)) * F(15.999)).astype(np.int64)
        row = ((b * SATIR + satir) * 16 + iy).astype(np.int64)
        col = (yuva * 16 + ix).astype(np.int64)
        return self.src[row, col]

    def golcuk(self, px, py):
        P = DOZ[GOLCUK_ZONE]
        v = do_gurultu(px / F(P[1]), py / F(P[1])) * F(0.85) + do_gurultu(px / F(P[1] * 0.35) + 5, py / F(P[1] * 0.35) + 9) * F(0.15)
        islak = do_gurultu(px / F(190.0) + 41, py / F(190.0) + 7)
        return v > F(P[0]) + (F(0.5) - islak) * F(0.45)

    def renk(self, px, py, tur):
        """(rgb N x 3, etkin N) - shader do_zemin_renk(dunya, tur)."""
        n_ = px.shape[0]
        rgb = np.zeros((n_, 3), np.float32)
        z = self.bolge(px, py)
        w = np.minimum(1.0, z.sum(1))
        nz = do_gurultu(px / F(34.0), py / F(34.0)) * F(0.5) + do_gurultu(px / F(11.0) + 17, py / F(11.0) + 3) * F(0.3) \
            + do_gurultu(px / F(4.0) + 3, py / F(4.0) + 29) * F(0.2)
        act = (w >= 0.08) & (w + (nz - F(0.5)) * SINIR_GURULTU >= SINIR)
        idx = np.nonzero(act)[0]
        if idx.size == 0:
            return rgb, act
        px, py, z = px[idx], py[idx], z[idx]
        sc = z.copy()
        on = (z >= 0.03)
        multi = on.sum(1) > 1
        if multi.any():
            qx, qy = px[multi] / F(23.0), py[multi] / F(23.0)
            ns = np.stack([do_gurultu(qx, qy), do_gurultu(qx + 7, qy + 3), do_gurultu(qx + 13, qy + 5), do_gurultu(qx + 19, qy + 11)], 1)
            sc[multi] += (ns - F(0.5)) * SECIM_GURULTU * on[multi]
        ## shader sırası: r, g > m, b > m, a > m (eşitlikte önceki kalır) -> argmax ilk en büyüğü verir
        b = np.argmax(sc, 1).astype(np.int64)
        hx = np.floor((px - KOKU[0]) / F(16.0))
        hy = np.floor((py - KOKU[1]) / F(16.0))
        ix = (px - KOKU[0] - hx * 16).astype(np.int64)
        iy = (py - KOKU[1] - hy * 16).astype(np.int64)
        c = np.zeros((idx.size, 3), np.float32)
        sus_satir = np.full(idx.size, 3 + tur, np.int64)
        sus_p = np.array([DOZ[k][2 if tur == 0 else 3] for k in range(4)], np.float32)[b]
        if tur == 0:
            yama = np.zeros(idx.size, bool)
            gol = b == GOLCUK_ZONE
            for k in range(4):
                sel = (b == k) & ~gol
                if sel.any():
                    P = DOZ[k]
                    v = do_gurultu(px[sel] / F(P[1]), py[sel] / F(P[1])) * F(0.85) \
                        + do_gurultu(px[sel] / F(P[1] * 0.35) + 5, py[sel] / F(P[1] * 0.35) + 9) * F(0.15) \
                        + (do_hash(px[sel] + 523, py[sel] + 911) - F(0.5)) * F(0.035)
                    yama[sel] = v > F(P[0])
            if gol.any():
                gx, gy = px[gol], py[gol]
                g0 = self.golcuk(gx, gy)
                yama[gol] = g0
            c = self.karo(b, yama.astype(np.int64), hx, hy, ix, iy, 1.0)[:, :3]
            if gol.any():
                gi = np.nonzero(gol)[0]
                gx, gy = px[gi], py[gi]
                g0 = yama[gi]
                up = self.golcuk(gx, gy - 1)
                ## gölcük içi: üst kenar parıltı, içi dalgacık süsleri (satır 5)
                par = g0 & ~up
                c[gi[par]] = GOLCUK_PARILTI
                sus_p[gi[par]] = 0
                ic = g0 & up
                sus_satir[gi[ic]] = 5
                sus_p[gi[ic]] = GOLCUK_SUS
                ## gölcük dışı komşusu gölcük: çamur kenar çizgisi
                dis = ~g0
                if dis.any():
                    di = gi[dis]
                    ex, ey = px[di], py[di]
                    kenar = self.golcuk(ex, ey + 1) | self.golcuk(ex, ey - 1) | self.golcuk(ex + 1, ey) | self.golcuk(ex - 1, ey)
                    c[di[kenar]] = GOLCUK_KENAR
                    sus_p[di[kenar]] = 0
        else:
            c = self.karo(b, np.full(idx.size, 2, np.int64), hx, hy, ix, iy, 3.0)[:, :3]
        hs = do_hash(hx + F(4111.0) + F(tur * 577.0) + sus_satir.astype(np.float32) * F(97.0), hy + b.astype(np.float32) * F(3001.0))
        dec = hs < sus_p
        if dec.any():
            di = np.nonzero(dec)[0]
            ## süs tohumu = 9 + sus_satir (gölcük içinde satır 5 -> pikselden piksele değişebilir)
            s = self.karo(b[di], sus_satir[di], hx[di], hy[di], ix[di], iy[di], F(9.0) + sus_satir[di].astype(np.float32))
            ok = s[:, 3] > 0.5
            c[di[ok]] = s[ok, :3]
        rgb[idx] = c
        return rgb, act


def golge(oran):
    d = oran - 1.0
    return np.clip(1.0 + np.sign(d) * np.maximum(np.abs(d) - 0.14, 0.0), 0.55, 1.15).astype(np.float32)


def uygula(field, px, py, tex, toprak):
    """Shader do_zemin_uygula: (rgb, etkin). tex = karonun özgün rengi (N x 3), toprak = toprak payı (N)."""
    need_c = toprak < 0.999
    need_y = toprak > 0.001
    cim = np.zeros_like(tex)
    yol = np.zeros_like(tex)
    act = np.zeros(px.shape[0], bool)
    l = tex @ LUMA
    if need_c.any():
        r, a = field.renk(px[need_c], py[need_c], 0)
        cim[need_c] = r * golge(l[need_c] / CIM_L)[:, None]
        act[need_c] |= a
    if need_y.any():
        r, a = field.renk(px[need_y], py[need_y], 1)
        yol[need_y] = r * golge(l[need_y] / TOPRAK_L)[:, None]
        act[need_y] |= a
    t = toprak[:, None]
    return cim * (1 - t) + yol * t, act


## ------------------------------------------------------------------ karo kaynakları (TMX tileset'leri)
class Tilesets:
    def __init__(self, text):
        self.sets = []
        for m in re.finditer(r'<tileset firstgid="(\d+)" source="([^"]+)"/>', text):
            self.sets.append((int(m.group(1)), m.group(2)))
        self.sets.sort()
        self.cache = {}

    def _load(self, src):
        if src in self.cache:
            return self.cache[src]
        p = os.path.join(HARITA, src)
        info = None
        try:
            root = ET.parse(p).getroot()
            tw, th = int(root.get('tilewidth')), int(root.get('tileheight'))
            img = root.find('image')
            anim = {}
            for t in root.findall('tile'):
                a = t.find('animation')
                if a is not None:
                    anim[int(t.get('id'))] = [(int(f.get('tileid')), int(f.get('duration'))) for f in a.findall('frame')]
            if img is not None and tw == 16 and th == 16:
                ip = os.path.normpath(os.path.join(os.path.dirname(p), img.get('source')))
                im = np.asarray(Image.open(ip).convert('RGBA'), np.uint8)
                cols = int(root.get('columns') or (im.shape[1] // 16))
                info = {'img': im, 'cols': cols, 'anim': anim}
        except (ET.ParseError, OSError):
            info = None
        self.cache[src] = info
        return info

    def lookup(self, gid):
        g = gid & 0x1FFFFFFF
        best = None
        for fg, src in self.sets:
            if fg <= g:
                best = (fg, src)
        return best[0], best[1], g - best[0]

    def frames(self, gid):
        """[(16x16x4 uint8, süre ms)] (animasyonsuzsa tek kare, süre 0) ya da None (16 px görüntü tileset'i değil)."""
        fg, src, lid = self.lookup(gid)
        info = self._load(src)
        if info is None:
            return None
        seq = info['anim'].get(lid, [(lid, 0)])
        out = []
        for tid, dur in seq:
            r, c = divmod(tid, info['cols'])
            t = info['img'][r * 16:(r + 1) * 16, c * 16:(c + 1) * 16]
            if t.shape[:2] != (16, 16):
                return None
            out.append((_flip(t, gid), dur))
        return out


def _flip(t, gid):
    if gid & 0x20000000:
        t = t.transpose(1, 0, 2)
    if gid & 0x80000000:
        t = t[:, ::-1]
    if gid & 0x40000000:
        t = t[::-1]
    return np.ascontiguousarray(t)


## ------------------------------------------------------------------ pişirme
def _cell_pixels(cells):
    """Hücre listesi -> dünya pikseli (px, py) dizileri (hücre başına 256, satır sırası)."""
    c = np.asarray(cells, np.int64)
    j, i = np.mgrid[0:16, 0:16]
    px = (KOKU[0] + c[:, 0, None] * 16 + i.ravel()[None, :]).astype(np.float32)
    py = (KOKU[1] + c[:, 1, None] * 16 + j.ravel()[None, :]).astype(np.float32)
    return px.ravel(), py.ravel()


def candidate_cells(field, cells):
    """Bölge zemininin bir pikseline bile dokunabileceği hücreler (maske payı >= 0,1 köşe/merkez örneklemesiyle)."""
    cells = list(cells)
    if not cells:
        return []
    c = np.asarray(cells, np.int64)
    best = np.zeros(len(cells), np.float32)
    for ox in (0, 5, 10, 15):
        for oy in (0, 5, 10, 15):
            px = (KOKU[0] + c[:, 0] * 16 + ox).astype(np.float32)
            py = (KOKU[1] + c[:, 1] * 16 + oy).astype(np.float32)
            best = np.maximum(best, np.minimum(1.0, field.bolge(px, py).sum(1)))
    return [cells[k] for k in np.nonzero(best >= 0.07)[0]]


class Baker:
    def __init__(self, field, ts):
        self.field = field
        self.ts = ts
        self.static = {}     ## bytes -> yerel id
        self.static_list = []
        self.anim = {}       ## (frames bytes..., süreler) -> yerel anahtar
        self.anim_list = []  ## [(kareler, süreler)]
        self.first = {}      ## karo anahtarı -> ilk kullanıldığı hücre öbeğinin Z-sırası (write_atlas parçalara bunla böler)

    def add_static(self, t, cell=None):
        k = t.tobytes()
        if k not in self.static:
            self.static[k] = len(self.static_list)
            self.static_list.append(t)
        key = ('s', self.static[k])
        if cell is not None and key not in self.first:
            self.first[key] = cell_key(cell)
        return key

    def add_anim(self, frames, durs, cell=None):
        k = tuple(f.tobytes() for f in frames) + tuple(durs)
        if k not in self.anim:
            self.anim[k] = len(self.anim_list)
            self.anim_list.append((frames, durs))
        key = ('a', self.anim[k])
        if cell is not None and key not in self.first:
            self.first[key] = cell_key(cell)
        return key

    def overlay(self, cells, grass, dirt, keep_dirt=frozenset()):
        """Derin orman zemini katmanı: hücre -> karo anahtarı (boşsa yok). keep_dirt (madde 387): bu hücrelerde Zemin Toprak'tan görünen
        pikseller bölgenin yol karosuna çevrilmez (toprak olduğu gibi kalır, sadece çimen pikselleri bölge zemini)."""
        out = {}
        B = 2048
        for s in range(0, len(cells), B):
            chunk = cells[s:s + B]
            px, py = _cell_pixels(chunk)
            gt = np.zeros((len(chunk), 16, 16, 4), np.uint8)
            dt = np.zeros((len(chunk), 16, 16, 4), np.uint8)
            for k, c in enumerate(chunk):
                for lay, arr in ((grass, gt), (dirt, dt)):
                    g = lay.get(c)
                    if g:
                        fr = self.ts.frames(g)
                        if fr:
                            arr[k] = fr[0][0]
            gt = gt.reshape(-1, 4).astype(np.float32) / 255.0
            dt = dt.reshape(-1, 4).astype(np.float32) / 255.0
            use_g = gt[:, 3] >= 0.5
            use_d = ~use_g & (dt[:, 3] >= 0.5)
            tex = np.where(use_g[:, None], gt[:, :3], dt[:, :3])
            elig = (use_g & (gt[:, 2] < gt[:, 1] + 0.02)) | use_d
            if keep_dirt:
                elig &= ~(use_d & np.repeat(np.array([c in keep_dirt for c in chunk], bool), 256))
            toprak = smoothstep(0.18, 0.38, tex[:, 0] - tex[:, 1] * 0.55).astype(np.float32)
            rgb = np.zeros_like(tex)
            act = np.zeros(px.shape[0], bool)
            ei = np.nonzero(elig)[0]
            if ei.size:
                r, a = uygula(self.field, px[ei], py[ei], tex[ei], toprak[ei])
                rgb[ei] = r
                act[ei] = a
            img = np.zeros((px.shape[0], 4), np.uint8)
            img[:, :3] = np.clip(np.round(rgb * 255), 0, 255).astype(np.uint8)
            img[:, 3] = np.where(act, 255, 0)
            img = img.reshape(len(chunk), 16, 16, 4)
            for k, c in enumerate(chunk):
                if img[k, :, :, 3].any():
                    out[c] = self.add_static(img[k], c)
        return out

    def inplace(self, layer, mode):
        """Yerinde değiştirme: mode 'su' (çimen shader'ı kuralı) / 'yesil' (uçurum dudağı kuralı) / 'plato' (yesil + PISMIS_ALFA işareti).
        Döner: hücre -> karo anahtarı."""
        out = {}
        items = [(c, g) for c, g in layer.items()]
        for c, g in items:
            fr = self.ts.frames(g)
            if fr is None:
                continue
            px, py = _cell_pixels([c])
            new_frames = []
            changed = False
            for t, _d in fr:
                f = t.reshape(-1, 4).astype(np.float32) / 255.0
                tex = f[:, :3]
                if mode == 'su':
                    sel = (f[:, 3] > 0) & (tex[:, 2] < tex[:, 1] + 0.02)
                    toprak = smoothstep(0.18, 0.38, tex[:, 0] - tex[:, 1] * 0.55).astype(np.float32)
                    k = sel.astype(np.float32)
                else:  ## 'yesil' / 'plato'
                    k = smoothstep(0.02, 0.08, tex[:, 1] - np.maximum(tex[:, 0], tex[:, 2])).astype(np.float32) * (f[:, 3] > 0)
                    toprak = np.zeros(tex.shape[0], np.float32)
                si = np.nonzero(k > 0.001)[0]
                res = tex.copy()
                painted = np.zeros(tex.shape[0], bool)
                if si.size:
                    r, a = uygula(self.field, px[si], py[si], tex[si], toprak[si])
                    m = (k[si] * a)[:, None]
                    res[si] = tex[si] * (1 - m) + r * m
                    painted[si] = a
                    changed = changed or bool(a.any())
                img = np.zeros((256, 4), np.uint8)
                img[:, :3] = np.clip(np.round(res * 255), 0, 255).astype(np.uint8)
                img[:, 3] = t.reshape(-1, 4)[:, 3]
                if mode == 'plato':
                    img[painted & (img[:, 3] == 255), 3] = PISMIS_ALFA
                new_frames.append(img.reshape(16, 16, 4))
            if not changed:
                continue
            if len(fr) > 1:
                out[c] = self.add_anim(new_frames, [d for _t, d in fr], c)
            else:
                out[c] = self.add_static(new_frames[0], c)
        return out

    def write_atlas(self, usage):
        """Atlas PARÇALARI + TSX'ler (madde 372). usage = [(hücre, karo anahtarı)] (bölge zemini + yerinde değişen tüm katmanlar).
        Döner: (ids: (bölge, anahtar) -> GLOBAL karo id (parçanın tabanı + yerel id), parçalar [(tsx adı, taban, karo sayısı)], region_of: 16x16 hücre öbeği -> bölge).
        Godot'un TileSetAtlasSource.create_tile'ı karo sayısının KARESİYLE yavaşlıyor (14.000 karo tek kaynakta = harita yüklemesine +4,5 sn): karolar
        <= PART_LIMIT'lik BÖLGE parçalarına bölünür. Bölge = Z-sırasında (Morton) ardışık 16x16 hücre öbekleri; parça = O BÖLGEDE kullanılan karolar (bir karo
        başka bölgede de kullanılıyorsa orada da kendi kopyası var) -> bir öbeğin tüm hücreleri AYNI dokudan (çizimde doku değişimi yok, görüntü birebir aynı).
        Bir animasyonun kareleri hep aynı parçada."""
        def size(key):
            return 1 if key[0] == 's' else len(self.anim_list[key[1]][0])
        by_q = {}
        for c, key in usage:
            by_q.setdefault((c[0] // 16, c[1] // 16), set()).add(key)
        regions = []
        cur, curq, n = set(), [], 0
        for q in sorted(by_q, key=lambda q: _morton(max(0, q[0]), max(0, q[1]))):
            add = sum(size(k) for k in by_q[q] - cur)
            if curq and n + add > PART_LIMIT:
                regions.append((curq, cur))
                cur, curq, n = set(), [], 0
                add = sum(size(k) for k in by_q[q])
            cur |= by_q[q]
            curq.append(q)
            n += add
        if curq:
            regions.append((curq, cur))
        region_of = {q: ri for ri, (qs, _k) in enumerate(regions) for q in qs}
        keep = {part_png(k) for k in range(len(regions))} | {part_tsx(k) for k in range(len(regions))}
        for f in os.listdir(ATLAS_DIR):
            if re.match(r'(Derin orman zemin( \d+)?\.tsx|derin_orman_zemin(_\d+)?\.png(\.import)?)$', f) and f not in keep and f[:-7] not in keep:
                os.remove(os.path.join(ATLAS_DIR, f))
        ids = {}
        parts = []
        base = 0
        for pi, (_qs, keys) in enumerate(regions):
            statics = sorted(k[1] for k in keys if k[0] == 's')
            anims = sorted(k[1] for k in keys if k[0] == 'a')
            srows = (len(statics) + PART_COLS - 1) // PART_COLS
            ## animasyonlar: kare sayısına göre bantlar; her animasyon bir sütun, kareler alt alta (Tiled kare aralığı = 1 satır)
            bands = {}
            for i in anims:
                bands.setdefault(len(self.anim_list[i][0]), []).append(i)
            rows = srows
            places = {}
            for fc in sorted(bands):
                idl = bands[fc]
                for j, i in enumerate(idl):
                    places[i] = (j % PART_COLS, rows + (j // PART_COLS) * fc)
                rows += ((len(idl) + PART_COLS - 1) // PART_COLS) * fc
            rows = max(rows, 1)
            atlas = np.zeros((rows * 16, PART_COLS * 16, 4), np.uint8)
            for k, i in enumerate(statics):
                r, cc = divmod(k, PART_COLS)
                atlas[r * 16:(r + 1) * 16, cc * 16:(cc + 1) * 16] = self.static_list[i]
                ids[(pi, ('s', i))] = base + k
            tiles = []
            for i in anims:
                frames, durs = self.anim_list[i]
                col, r0 = places[i]
                for k, f in enumerate(frames):
                    atlas[(r0 + k) * 16:(r0 + k + 1) * 16, col * 16:(col + 1) * 16] = f
                tid = r0 * PART_COLS + col
                ids[(pi, ('a', i))] = base + tid
                fr = ''.join('   <frame tileid="%d" duration="%d"/>\n' % (tid + k * PART_COLS, durs[k] or 120) for k in range(len(frames)))
                tiles.append((tid, ' <tile id="%d">\n  <animation>\n%s  </animation>\n </tile>\n' % (tid, fr)))
            tiles.sort()
            Image.fromarray(atlas).save(os.path.join(ATLAS_DIR, part_png(pi)), optimize=True)
            count = rows * PART_COLS
            tsx = ('<?xml version="1.0" encoding="UTF-8"?>\n'
                   '<tileset version="1.10" tiledversion="1.12.2" name="Derin orman zemin %02d" tilewidth="16" tileheight="16" tilecount="%d" columns="%d">\n'
                   ' <image source="%s" width="%d" height="%d"/>\n'
                   '%s</tileset>\n') % (pi + 1, count, PART_COLS, part_png(pi), PART_COLS * 16, rows * 16, ''.join(t for _, t in tiles))
            open(os.path.join(ATLAS_DIR, part_tsx(pi)), 'w', encoding='utf-8', newline='\n').write(tsx)
            parts.append((part_tsx(pi), base, count))
            base += count
        return ids, parts, region_of


def is_flat_grass(t):
    a = t[:, :, 3] > 0
    if a.mean() < 0.9:
        return False
    rgb = t[:, :, :3].reshape(-1, 3).astype(np.float32) / 255.0
    return (np.abs(rgb - FULL_GRASS).max(1) < 0.06).mean() > 0.9
