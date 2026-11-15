# Kullanıcının renk notları için önizleme: ton (hue) aralığı kaydırma + Şovalye pasifindeki yeşil oku silme.
# H, PIL HSV ölçeğinde 0-255 (0 kırmızı, ~21 turuncu, ~42 sarı, ~85 yeşil, ~170 mavi, ~200 mor).
import numpy as np
from PIL import Image


def _hsv(img):
    return np.asarray(img.convert("RGB").convert("HSV")).astype(int)


def remap_hue(img, lo, hi, target, spread=0.5, min_sat=60, sat_mul=1.0, val_mul=1.0, min_val=0):
    """[lo, hi] aralığındaki tonları (doygunluğu min_sat üstü) target etrafına toplar; spread = eski farkın ne kadarı korunur."""
    hsv = _hsv(img)
    h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    if lo <= hi:
        inr = (h >= lo) & (h <= hi)
        center = (lo + hi) / 2.0
        off = h - center
    else:  # 0'ı saran aralık (ör. 230..20)
        inr = (h >= lo) | (h <= hi)
        hh = np.where(h >= lo, h - 256, h)
        center = ((lo - 256) + hi) / 2.0
        off = hh - center
    m = inr & (s >= min_sat) & (v >= min_val)
    nh = np.where(m, (target + off * spread) % 256, h)
    ns = np.where(m, np.clip(s * sat_mul, 0, 255), s)
    nv = np.where(m, np.clip(v * val_mul, 0, 255), v)
    out = np.stack([nh, ns, nv], axis=-1).astype(np.uint8)
    return Image.fromarray(out, "HSV").convert("RGB")


# --- 5. tur: SANATA DOKUNMAYAN ton değişimi -------------------------------------------------
# Kullanıcı: "sadece tonunu değiştirmen lazımdı, sıfırdan çizmişsin gibi" / "sanatlara karışmaman gerekiyor".
# remap_hue tonları sıkıştırıyor (spread), doygunluk eşiğiyle yamalı çalışıyor ve HSV V'si sabit kaldığı için
# algılanan parlaklık değişiyordu (sarı -> mavi aynı V'de çok koyu görünür). YIQ'da (I, Q) düzlemini döndürmek
# parlaklığı (Y) birebir korur: gölgelendirme, ışık, kontur aynı kalır, yalnız ton döner.
_M = np.array([[0.299, 0.587, 0.114], [0.596, -0.274, -0.322], [0.211, -0.523, 0.312]])
_MI = np.linalg.inv(_M)


def _yiq(img):
    return np.asarray(img.convert("RGB")).astype(float) @ _M.T


def _rgb(yiq):
    return Image.fromarray(np.clip(yiq @ _MI.T, 0, 255).round().astype(np.uint8), "RGB")


def yiq_angle(rgb):
    _, i, q = np.array(rgb, float) @ _M.T
    return np.arctan2(q, i)


def rotate_hue(img, target_rgb, weight=None, src_weight=None, chroma=1.0, luma=1.0):
    """Ağırlıklı piksellerin baskın tonunu target_rgb'nin tonuna döndürür. Y (parlaklık) korunur;
    chroma / luma yalnız açıkça istenirse 1'den farklı verilir. weight: 0..1 piksel ağırlığı (None = hepsi)."""
    a = _yiq(img)
    h, w = a.shape[:2]
    wt = np.ones((h, w)) if weight is None else weight
    sw = wt if src_weight is None else src_weight
    ang = np.arctan2(a[..., 2], a[..., 1])
    mag = np.hypot(a[..., 1], a[..., 2])
    # kaynak baskın açısı: kroma ağırlıklı dairesel ortalama
    k = sw * mag
    src = np.arctan2((k * np.sin(ang)).sum(), (k * np.cos(ang)).sum())
    d = yiq_angle(target_rgb) - src
    na = ang + d * wt
    nm = mag * (1 + (chroma - 1) * wt)
    out = np.stack([a[..., 0] * (1 + (luma - 1) * wt), nm * np.cos(na), nm * np.sin(na)], axis=-1)
    return _rgb(out)


def hue_band(img, lo, hi, min_sat=25, soft=12):
    """PIL HSV ton aralığı [lo, hi] (0-255) için yumuşak 0..1 ağırlık (aralık dışına 'soft' birimde söner)."""
    hsv = _hsv(img)
    hh, s = hsv[..., 0].astype(float), hsv[..., 1].astype(float)
    c = (lo + hi) / 2.0
    half = (hi - lo) / 2.0
    dist = np.abs(((hh - c + 128) % 256) - 128)
    w = np.clip(1 - (dist - half) / soft, 0, 1)
    return w * np.clip((s - min_sat) / 25.0, 0, 1)


def flood_background(img, is_bg, border=10):
    """Çerçevenin içinden başlayıp is_bg piksellerinden kenara bağlı olanları bulur (figürün içine sızmaz)."""
    h, w = is_bg.shape
    seen = np.zeros_like(is_bg)
    stack = [(y, x) for y in range(h) for x in range(w)
             if is_bg[y, x] and (y < border or x < border or y >= h - border or x >= w - border)]
    for y, x in stack:
        seen[y, x] = True
    while stack:
        y, x = stack.pop()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not seen[ny, nx] and is_bg[ny, nx]:
                seen[ny, nx] = True
                stack.append((ny, nx))
    return seen


def _dilate(m, r):
    out = m.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dy * dy + dx * dx <= r * r:
                out |= np.roll(np.roll(m, dy, 0), dx, 1)
    return out


def bg_only(img, lo, hi, target_rgb, luma, rim_luma, min_val=140, loose_min_val=70):
    """Yalnız kenara bağlı zemin (ton lo..hi, parlak) + zemine değen soluk 'ışık kenarı' değişir; figür AYNI.
    Zeminde ton döner ve parlaklık luma ile çarpılır; soluk kenar aynı tona döner, parlaklığı rim_luma."""
    hsv = _hsv(img)
    hh, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    strict = (hh >= lo) & (hh <= hi) & (s >= 60) & (v >= min_val)
    bg = flood_background(img, strict)
    # zemindeki koyu turuncu ışınlar: katı zeminden en çok 4 px yayılır; figür kahvesi (ölçüm: ton 15-18,
    # V 67-99) ton >= lo+2 ve V >= 110 ile DIŞARIDA kalır (ilk sürüm konturdaki boşluktan giysiye sızmıştı)
    loose = (hh >= lo + 2) & (hh <= hi + 4) & (s >= 50) & (v >= loose_min_val) & _dilate(bg, 4)
    h, w = bg.shape
    stack = list(zip(*np.nonzero(bg)))
    while stack:
        y, x = stack.pop()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not bg[ny, nx] and loose[ny, nx]:
                bg[ny, nx] = True
                stack.append((ny, nx))
    near = _dilate(bg, max(3, img.width // 24)) & ~bg
    rim = near & (s < 120) & (v >= 140)
    # zemin: ton döner, sonra RGB birlikte koyulaşır (ışın dokusu oranıyla kalır)
    a = _yiq(rotate_hue(img, target_rgb, weight=bg.astype(float)))
    a[bg] *= luma
    if rim.any():
        # paketin soluk ışık konturu = zeminin AÇIK hâli: sarı zeminde açık sarıydı, lacivertte açık lacivert olur
        bg_y = float(a[..., 0][bg].mean())
        tgt = yiq_angle(target_rgb)
        bg_mag = float(np.hypot(a[..., 1][bg], a[..., 2][bg]).mean())
        a[..., 0][rim] = np.minimum(a[..., 0][rim], bg_y * rim_luma)
        a[..., 1][rim] = bg_mag * np.cos(tgt)
        a[..., 2][rim] = bg_mag * np.sin(tgt)
    return _rgb(a)


# 5. tur seçenekleri: no -> [(taban seçim kimliği, ad, işlev), ...]  (önceki RENK girdisinin yerine geçer)
TON5 = {
    # bg_only(..., luma = zemin koyuluğu, rim_luma = kontur zeminin kaç katı açık)
    18: [("w", "koyu lacivert zemin", lambda im: bg_only(im, 22, 52, (30, 50, 120), 0.40, 1.6)),
         ("w", "koyu lacivert, kontur zeminle bir", lambda im: bg_only(im, 22, 52, (30, 50, 120), 0.40, 1.15)),
         ("w", "orta lacivert zemin", lambda im: bg_only(im, 22, 52, (35, 60, 140), 0.55, 1.5))],
    24: [("a", "mavi", lambda im: rotate_hue(im, (60, 150, 220))),
         ("a", "lacivert-mavi", lambda im: rotate_hue(im, (40, 110, 210))),
         ("a", "lacivert, biraz koyu", lambda im: rotate_hue(im, (30, 95, 200), luma=0.8))],
    # 12 Matthew R: seçim e (LIG-A5) "arkadaki kırmızı zemin sarı-turuncumsu, sakın yeniden çizme" -> yalnız
    # kırmızı ton bandı döner (yüz/ten ~ton 15-20 bandın dışında kalsın diye üst sınır 8, yumuşaklık 6)
    # ölçüm: kırmızı zemin ton 252..14 (V ~104, koyu), yüzdeki ten 18 -> bant -8..13, yumuşaklık 4 (ten 0 ağırlık)
    12: [("e", "sarı-turuncu zemin", lambda im: rotate_hue(im, (240, 170, 50), weight=hue_band(im, -8, 13, soft=4))),
         ("e", "sarı-turuncu zemin, biraz açık", lambda im: rotate_hue(im, (240, 170, 50), weight=hue_band(im, -8, 13, soft=4), luma=1.35))],
    34: [("b", "yeşil", lambda im: rotate_hue(im, (60, 170, 90), weight=hue_band(im, 120, 175))),
         ("b", "yumuşak yeşil", lambda im: rotate_hue(im, (90, 160, 100), weight=hue_band(im, 120, 175), chroma=0.7)),
         ("b", "yumuşak koyu yeşil", lambda im: rotate_hue(im, (90, 160, 100), weight=hue_band(im, 120, 175), chroma=0.7, luma=0.82))],
}


def _potion(target, luma=1.0):
    """Cadı R ana ikonu WAR-E5'in yalnız yeşil SIVISI döner (şişe + mor zemin aynı) -> 6 iksir tutarlı set."""
    # ölçüm: WAR-E5 sıvısı ton 45-55 (sarımsı yeşil), şişe camı/zemin 150-215 (mor) -> bant 35..72
    return lambda im: rotate_hue(im, target, weight=hue_band(im, 35, 72, soft=8), luma=luma)


# Varyant kartları (61-66 Cadı iksirleri): kimlik d = WAR-E5, d_ton1 = sıvısı iksirin rengine dönmüş hâli
TON5.update({
    61: [("d", "pembe-mor sıvı", _potion((220, 60, 200)))],
    62: [("d", "buz mavisi sıvı", _potion((120, 200, 245)))],
    63: [("d", "turuncu sıvı", _potion((245, 120, 40)))],
    64: [("d", "kırmızı sıvı", _potion((225, 60, 80)))],
    65: [("d", "koyu mor sıvı", _potion((100, 40, 150), luma=0.75))],
    66: [("d", "camgöbeği sıvı", _potion((60, 200, 230)))],
})


def bg_behind_outline(img, target_hue, val_mul=0.8, spread=0.4, keep_hue=(55, 115), frame=4):
    """Paket konusunun açık konturu (soluk, parlak) DUVAR kabul edilir; kenardan duvara kadar dolan bölge = zemin.
    Zemin HSV'de target_hue'ya döner (ton farkları spread oranında korunur, doygunluk aynı, V*val_mul) -> ışın dokusu
    kalır. Duvara değen kontur pikselleri aynı tona döner (parlaklık aynı: sarı zeminde açık sarı -> açık kırmızı).
    keep_hue aralığındaki doygun pikseller (ör. yeşil oklar) hiç değişmez."""
    hsv = _hsv(img)
    hh, s, v = hsv[..., 0].astype(float), hsv[..., 1].astype(float), hsv[..., 2].astype(float)
    H, W = hh.shape
    outline = (s < 120) & (v >= 150)
    wall = _dilate(outline, 1)
    keep = (hh >= keep_hue[0]) & (hh <= keep_hue[1]) & (s >= 80)
    inner = np.zeros((H, W), bool)
    inner[frame:H - frame, frame:W - frame] = True
    # FİGÜR önce: merkezden konturun İÇİNE dolgu (kenardan zemin dolgusu figürün kenara değdiği yerden - ör. bilek
    # ikonun altına iniyorsa - içeri sızıyordu). Figür + konturu kilitli; geri kalan iç alan zemin (koyu ışınlar dahil).
    fig = np.zeros((H, W), bool)
    can = inner & ~wall & ~keep
    stack = [(H // 2, W // 2)] if can[H // 2, W // 2] else []
    for y, x in stack:
        fig[y, x] = True
    while stack:
        y, x = stack.pop()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < H and 0 <= nx < W and not fig[ny, nx] and can[ny, nx]:
                fig[ny, nx] = True
                stack.append((ny, nx))
    fig = _dilate(fig, 1) | (wall & _dilate(fig, 3))
    # figürün içindeki açık parlamalar (kontur maskesine düşen) DELİK olarak kalmasın: kenardan figüre değmeden
    # ulaşılamayan her iç piksel figürdür (delik doldurma)
    outside = np.zeros((H, W), bool)
    free = inner & ~fig
    stack = [(y, x) for y in range(H) for x in range(W)
             if free[y, x] and (y < frame + 2 or x < frame + 2 or y >= H - frame - 2 or x >= W - frame - 2)]
    for y, x in stack:
        outside[y, x] = True
    while stack:
        y, x = stack.pop()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < H and 0 <= nx < W and not outside[ny, nx] and free[ny, nx]:
                outside[ny, nx] = True
                stack.append((ny, nx))
    fig |= inner & ~outside
    bg = inner & ~fig & ~keep & ~outline
    if bg.any():
        # çerçeve payında kalan parlak zemin pikselleri (koyu çerçevenin kendisi değil) de zemin
        lo_h, hi_h = np.percentile(hh[bg], 5), np.percentile(hh[bg], 95)
        bg |= ~inner & (hh >= lo_h - 4) & (hh <= hi_h + 4) & (s >= 120) & (v >= 120)
    src = float(np.median(hh[bg])) if bg.any() else 0.0
    pale_bg = outline & ~fig & inner  # zemindeki soluk ışın çizgileri (figür konturu değil): zeminle birlikte döner
    rim = outline & fig & _dilate(bg | pale_bg, 1)  # figürün zemine değen konturu
    nh, ns, nv = hh.copy(), s.copy(), v.copy()
    nh[bg] = (target_hue + (hh[bg] - src) * spread) % 256
    nv[bg] = np.clip(v[bg] * val_mul, 0, 255)
    nh[pale_bg] = target_hue
    ns[pale_bg] = np.maximum(s[pale_bg], 110)
    nv[pale_bg] = np.clip(v[pale_bg] * val_mul, 0, 255)
    # figür konturu = zeminin AÇIK tonu (sarı zeminde açık sarıydı, kırmızıda açık kırmızı); parlaklığı aynı
    nh[rim] = target_hue
    ns[rim] = np.maximum(s[rim], 115)
    out = np.stack([nh, ns, nv], axis=-1).round().astype(np.uint8)
    return Image.fromarray(out, "HSV").convert("RGB"), bg


def mirror_box(img, x0, y0, frame_frac=1 / 24):
    """Sağ alt kutuyu (x >= x0*W, y >= y0*H, çerçeve hariç) yatay aynadaki piksellerle doldurur.
    BUF paketindeki 'yukarı ok' rozeti için: ok + koyu konturu + tabanı tümüyle gider (renk eşiği gerekmez)."""
    a = np.asarray(img.convert("RGB")).copy()
    H, W = a.shape[:2]
    b = max(2, int(round(W * frame_frac)))
    xs = np.arange(int(W * x0), W - b)
    for y in range(int(H * y0), H - b):
        a[y, xs] = a[y, W - 1 - xs]
    return Image.fromarray(a, "RGB")


def remove_arrow_mask(img, x0, y0, min_x, grow=3, frame_frac=1 / 24):
    """Kutu aynası (mirror_box) botun sağ konturunu kesip dikey çizgi bırakıyordu (kullanıcı: "tuhaf bir çizgi").
    Yalnız OKUN pikselleri değişir: sağ alt bölgedeki doygun yeşil gövde, grow px büyütülerek koyu çizgisi ve parıltısı
    dahil; x < min_x (figürün konturu) hiç değişmez. Dolgu aynı satırın yatay aynasından (sol alt = düz zemin)."""
    a = np.asarray(img.convert("RGB")).copy()
    hsv = _hsv(img)
    H, W = a.shape[:2]
    b = max(2, int(round(W * frame_frac)))
    region = np.zeros((H, W), bool)
    region[int(H * y0):H - b, int(W * x0):W - b] = True
    core = region & (hsv[..., 0] >= 60) & (hsv[..., 0] <= 115) & (hsv[..., 1] >= 120) & (hsv[..., 2] >= 50)
    mask = _dilate(core, grow) & region
    mask[:, :min_x] = False
    # sınırın hemen solundaki ok parıltısı noktaları (koyu-doygun yeşil; zemin daha açık) da deliğe katılır
    hh, ss, vv = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    # (ölçüm: zemin S~155 V~240; parıltı noktası + ince halkası S 180-255, V 164-225; botun konturu soluk, S düşük)
    spark = region & (hh >= 85) & (hh <= 110) & (ss >= 180) & (vv <= 225)
    spark[:, :min_x - 5] = False
    mask |= spark
    # Delik = çevresinden içe yumuşak geçiş (harmonik doldurma). Ayna dolgusu kaynak tarafı daha açık olduğu için
    # botun yanındaki koyu hale ile arasında yeni bir ton dikişi bırakıyordu.
    # Doku = yatay ayna (zeminin ışınları merkezden simetrik); ton = Poisson eşitleme: (asıl - ayna) farkı kenardan
    # deliğe yumuşak yayılır, ayna + fark -> kenarda dikiş yok, içeride ışın dokusu var. Düz ayna dikiş bırakıyordu,
    # düz yumuşak dolgu doku-suz soluk yama. Çerçeve (koyu kahve) hiç komşu sayılmaz.
    inner = np.zeros((H, W), bool)
    inner[b:H - b, b:W - b] = True
    valid = inner.astype(float)
    src = a.astype(float)
    mir = src[:, ::-1]
    diff = src - mir
    diff[mask] = 0.0
    for _ in range(800):
        num = np.zeros_like(diff)
        den = np.zeros((H, W))
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            num += np.roll(np.roll(diff * valid[..., None], dy, 0), dx, 1)
            den += np.roll(np.roll(valid, dy, 0), dx, 1)
        avg = num / np.maximum(den, 1)[..., None]
        diff[mask] = avg[mask]
    a[mask] = np.clip(mir[mask] + diff[mask], 0, 255).round().astype(np.uint8)
    # Figüre bitişik parıltı pikselleri (x < min_x): aynanın kaynağı orada figürün KARŞI konturuna denk geliyor
    # (botun sol beyaz konturu -> beyaz leke) -> bunlar yalnız komşu zeminden yumuşak dolgu.
    near = mask & (np.arange(W)[None, :] < min_x)
    if near.any():
        f = a.astype(float)
        f[near] = f[_dilate(near, 2) & ~near & inner].mean(axis=0)
        for _ in range(300):
            num = np.zeros_like(f)
            den = np.zeros((H, W))
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                num += np.roll(np.roll(f * valid[..., None], dy, 0), dx, 1)
                den += np.roll(np.roll(valid, dy, 0), dx, 1)
            f[near] = (num / np.maximum(den, 1)[..., None])[near]
        a[near] = np.clip(f[near], 0, 255).round().astype(np.uint8)
    return Image.fromarray(a, "RGB")


def remove_green_arrow(img):
    """Sağ alt çeyrekteki yeşil ok (+1-2 px koyu kontur) -> yatay aynadaki pikselle doldur."""
    a = np.asarray(img.convert("RGB")).copy()
    hsv = _hsv(img)
    H, W = a.shape[:2]
    green = (hsv[..., 0] >= 55) & (hsv[..., 0] <= 115) & (hsv[..., 1] >= 70) & (hsv[..., 2] >= 50)
    quad = np.zeros_like(green)
    quad[H // 2:, W // 2:] = True
    m = green & quad
    # konturu da al: 3 px genişlet
    k = max(2, W // 30)
    mm = m.copy()
    for dy in range(-k, k + 1):
        for dx in range(-k, k + 1):
            mm |= np.roll(np.roll(m, dy, 0), dx, 1)
    mm &= quad
    # çerçeveyi koru
    b = max(3, W // 18)
    mm[H - b:, :] = False
    mm[:, W - b:] = False
    ys, xs = np.nonzero(mm)
    a[ys, xs] = a[ys, W - 1 - xs]
    return Image.fromarray(a, "RGB")


def _sovalye_blue(im):
    wy = hue_band(im, 28, 60, min_sat=40, soft=8)   # zırh çevresindeki sarı ışık
    wr = hue_band(im, -20, 27, min_sat=40, soft=8)  # kırmızı-turuncu ışınlı zemin
    im = rotate_hue(im, (120, 200, 250), weight=wy, src_weight=wy)
    return rotate_hue(im, (30, 80, 190), weight=wr, src_weight=wr)


# no -> (taban seçim kimliği, açıklama, işlev)
RENK = {
    10: ("b", "sarı-turuncu", lambda im: remap_hue(im, 120, 245, 22, 0.35)),
    12: ("a", "sarı-turuncu", lambda im: remap_hue(im, 120, 245, 30, 0.35)),
    # 2026-11-11: "arkaplan mavi tonlarında, koruma hissiyatı" -> kırmızı-turuncu zemin mavi, zırhın etrafındaki
    # sarı ışık açık camgöbeği (tek dönüşte sarı mora kayıyordu, iki bant ayrı döner; zırh boyasız, Y korunur)
    21: ("a", "yeşil ok yok + mavi zemin", lambda im: _sovalye_blue(remove_green_arrow(im))),
    23: ("c", "mavi", lambda im: remap_hue(im, 40, 125, 160, 0.6)),
    # 3. tur: "biraz daha lacivert mavi, bu çok mor oldu" -> 182 (mor) yerine 160 (lacivert-mavi), biraz koyu
    24: ("a", "lacivert-mavi", lambda im: remap_hue(im, 240, 60, 160, 0.45, min_sat=50, val_mul=0.85)),
    # 4. tur: "çok yeşil olmuş, daha soft bir yeşil" -> doygunluk yarıya, ton biraz mint
    34: ("b", "yumuşak yeşil", lambda im: remap_hue(im, 115, 200, 92, 0.4, sat_mul=0.5, val_mul=1.05)),
    47: ("b", "kırmızı zemin", lambda im: remap_hue(im, 8, 70, 252, 0.4, min_sat=50, sat_mul=1.6)),
}

# Son seçimde gelen notlar (sayfada önizlemesi yok, doğrudan uygulanır): anahtar -> işlev
SON_RENK = {
    # 18 Şahin Hamlesi THI-B6: "arkaplan koyu karanlık mavi" -> parlak sarı ışınlar lacivert, koyu figür dokunulmaz
    "THI-B6": lambda im: remap_hue(im, 8, 64, 160, 0.3, min_sat=70, sat_mul=0.85, val_mul=0.42, min_val=110),
    # 35 Melek E FAI-D2: "arkaplan mavi tonlarında, hafif soft" -> yeşil zemin yumuşak mavi
    # 2026-11-11: "arkaplandaki ışık biraz daha mavi tonlarında olmalı, bu çok beyazımsı" -> _melek_e_blue
    # (eskisi: remap_hue(im, 45, 125, 150, 0.35, min_sat=50, sat_mul=0.6, val_mul=1.05) - s<50 soluk ışık hiç dönmüyordu)
    "FAI-D2": lambda im: _melek_e_blue(im),
}


def _melek_e_blue(im, target=(60, 130, 235), chroma=1.15, floor=32, luma=0.95, spread=0.35):
    """Melek E zemini (yeşil ışık, ton 40-125) YIQ'da tek maviye toplanır (spread: eski ton farkının payı; tek dönüşte
    sarımsı köşe camgöbeğine kaçıyordu). Soluk/beyazımsı ışığa hedef tonda kroma tabanı (floor) -> açık mavi kalır.
    Kristaller (ton ~150) ve eller (ton 7-17) bandın dışında, dokunulmaz."""
    w = hue_band(im, 40, 125, min_sat=8, soft=8)
    a = _yiq(im)
    mag = np.hypot(a[..., 1], a[..., 2])
    ang = np.arctan2(a[..., 2], a[..., 1])
    k = w * mag
    src = np.arctan2((k * np.sin(ang)).sum(), (k * np.cos(ang)).sum())
    tgt = yiq_angle(target)
    off = (ang - src + np.pi) % (2 * np.pi) - np.pi
    new_ang = tgt + off * spread
    na = ang + (((new_ang - ang + np.pi) % (2 * np.pi)) - np.pi) * w
    nm = mag * (1 + (chroma - 1) * w)
    low = nm < floor * w
    nm = np.where(low, floor * w, nm)
    na = np.where(low, tgt, na)
    a[..., 0] *= 1 + (luma - 1) * w
    a[..., 1] = nm * np.cos(na)
    a[..., 2] = nm * np.sin(na)
    return _rgb(a)
