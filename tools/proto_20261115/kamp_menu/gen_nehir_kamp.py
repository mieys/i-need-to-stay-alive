# ANA MENÜ "Nehir Kenarı Kampı" arka planı (2026-11-15). Kullanıcı: "Şovalye, Oakley, Hadime, Matthew, Talon ve Elara'nın ana haritanın cozy
# nehir kenarı bir kısmında, hafif loş günbatımı olmak üzere olan havada kamp yapıp bazılarının oturduğu, iyi vakit geçirdiği; kamp ateşi ve birkaç
# yiyeceğin olduğu cozy bir sahne. Hava hep günbatımı tadında kalacak."
#
# Taban = ANA HARİTANIN gerçek çizici yakalaması (kamp_capture.gd, kadraj "kadrajA" = hücre (140.475, 110.7) merkezli 384x216 DÜNYA px (2026-11-16 öncesi (140.6, 111.2) 320x180): sol üstten
# çapraz akan nehir, sağ üstte pembe ağaçlar + mantarlar, ortada açık çayır). Üstüne oyunun KENDİ sanatından yer eşyaları pişirilir (oturma
# kütüğü, küçük ahşap tabure, yastıklar; 2026-11-15 yiyecek örtüsü + yiyecekler kalktı - kullanıcı: "yemekleri kaldır"). Kamp ateşi (Night
# Camp paketi, gen_kamp_kareler.py gece_ates; eski kazansız çukur clean_pit kalktı) + karakterler Godot'ta canlı çizilir (menu_camp_scene.gd);
# günbatımı tonu + ateş ışığı + sudaki yansıma shader'da (shaders/kamp_gunbatimi.gdshader) - BURADA ışık/ton YOK (ışıksız taban).
# Oyunda x6 (1920x1080). Yer eşyalarının konumları burada; ateş/karakter konumları menu_camp_scene.gd'de (ikisi aynı dünya px uzayında).
#
#   python -I tools/proto_20261115/kamp_menu/gen_nehir_kamp.py           -> out/nehir_kamp_onizleme.png (x3)
#   python -I tools/proto_20261115/kamp_menu/gen_nehir_kamp.py --oyun    -> assets/ui/ana_menu/nehir_kamp.png + nehir_kamp_su.png
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
EV = os.path.join(ROOT, "harita", "Ev içi")
KAMP = os.path.join(ROOT, "tools", "kamp", "kaynak")
# 2026-11-16 UZAKLAŞTIRMA (kullanıcı: "sahneyi azcık uzaklaştır"): kadraj 320x180 -> 384x216 dünya px (oyunda x5, önce x6), sol üst
# (34, 26) px geride - bu dosyadaki ve menu_camp_scene.gd'deki bütün kadraj konumları bu kadar kaydırıldı (kamp ekranda aynı yerde kalır).
# (Aynı gün x4 / 480x270 "kadrajC" denendi, kullanıcı "öncekine dön" dedi -> yine 384x216 "kadrajB".)
W, H = 384, 216

# (kaynak, kutu) - kutu sayfa pikselinde; kırpılıp alfa sınırına daraltılır.
SRC = {
    "kutuk_yatay": (os.path.join(KAMP, "Tents_n_objects.png"), (202, 613, 247, 626)),
    "tabure": (os.path.join(EV, "Interior_objects.png"), (182, 24, 191, 37)),  # küçük yuvarlak ahşap tabure (ev içi seti)
    "yastik": (os.path.join(KAMP, "Tents_n_objects.png"), (206, 656, 229, 681)),
}

# Düz yer örtüleri (önce, sırasız) + eşyalar (ayak y'ye göre sıralı). (parça, ayak ortası x, ayak y) - dünya px (kadraj içi).
# Ateş çukuru ayağı menu_camp_scene.gd FIRE_FOOT = (170, 141); karakterler PARTY.
FLATS = [
    ("yastik", 173, 164),             # batı: Büyücü Kız'ın yastıkları
]
PROPS = [
    ("kutuk_yatay", 204, 134),        # kuzey: Şovalye + Matthew'in oturduğu kütük
    ("tabure", 242, 164),             # doğu: Elara'nın oturduğu küçük tabure (2026-11-16 ağaç kütüğü yerine - kullanıcı: "kütüğe değil küçük bir tabureye otursun")
]


def cut(name):
    path, box = SRC[name]
    im = Image.open(path).convert("RGBA").crop(box)
    bb = im.getbbox()
    return im.crop(bb) if bb else im


# Haritanın kendi çiçeklerinden SİLİNENLER (kullanıcı 2026-11-16: "Elara'nın saçındaki kırmızılığı ve önündeki çiçeği kaldır"): taburenin
# solundaki turkuaz yapraklı turuncu çiçek öbeği + taburenin üstünde Elara'nın saç hizasındaki turuncu çiçek (saçının arkasından kırmızı benek
# gibi görünüyordu). Bölgedeki çiçek renkleri (taç yaprak, koyu sap, turkuaz yaprak, gölgesi) çevredeki çim rengiyle doldurulur; arkadaki
# açık yeşil uzun fide durur.
CICEK_BOLGE = (228, 142, 250, 166)
CIM_RENK = {(103, 154, 82), (110, 159, 85)}


def cicek_rengi(c):
    """Çiçek pikseli mi (renk KURALI - bitki renkleri haritada konuma göre hafifçe kayıyor, birebir liste her çekimde tutmuyordu):
    turuncu taç yaprak, turkuaz yaprak, koyu sap, bitkinin gölgesi. Arkadaki açık yeşil fide (b düşük, g yüksek) girmez."""
    r, g, b = c
    if r > 120 and r > g + 30:
        return True  # turuncu / sarı taç yaprak
    if b > r + 10 and b > 55 and g < 130:
        return True  # turkuaz yaprak
    if g < 80 and r < 70:
        return True  # koyu sap
    return 70 <= r <= 100 and 120 <= g <= 135 and 66 <= b <= 90  # bitkinin zemindeki gölgesi


def cicek_sil(img):
    px = img.load()
    x0, y0, x1, y1 = CICEK_BOLGE
    hedef = [(x, y) for y in range(y0, y1) for x in range(x0, x1) if cicek_rengi(px[x, y][:3])]
    while hedef:
        kalan = []
        for x, y in hedef:
            komsu = [px[x + dx, y + dy][:3] for dy in (-1, 0, 1) for dx in (-1, 0, 1) if (dx or dy) and px[x + dx, y + dy][:3] in CIM_RENK]
            if komsu:
                px[x, y] = max(set(komsu), key=komsu.count) + (255,)
            else:
                kalan.append((x, y))
        if len(kalan) == len(hedef):  # çimle komşusu kalmadıysa (olmamalı) en yakın çim rengi
            for x, y in kalan:
                px[x, y] = (103, 154, 82, 255)
            break
        hedef = kalan
    return img


def compose(base):
    img = cicek_sil(base.copy())
    for name, fx, fy in FLATS + sorted(PROPS, key=lambda p: p[2]):
        spr = cut(name)
        img.alpha_composite(spr, (round(fx - spr.width / 2), round(fy - spr.height)))
    return img


def water_mask(base):
    """Su pikselleri (nehir mavisi) = beyaz; kıyı köpüğü/nilüfer hariç. Shader yansımayı yalnız burada çizer."""
    m = Image.new("L", base.size, 0)
    src = base.load()
    dst = m.load()
    for y in range(base.height):
        for x in range(base.width):
            r, g, b, a = src[x, y]
            if b > g + 6 and b > r + 25 and g < 150:
                dst[x, y] = 255
    return m


# NEHRİN ANİMASYONLU KIYI / AKINTI KAROLARI (2026-11-16, kullanıcı: "haritada nehirde normalde akıntı sprite'ları vardı, burda neden yok?"):
# haritanın "Su ayrıntılar 2/3/4" katmanları (kıyı sanatı: çimen saçakları, kıyı köpüğü, akıntı çizgileri, nilüfer) animasyonlu; yakalamada
# tek kareye donuyordu. kamp_capture.gd (KAMP_AKINTI=1) tabanı bu katmanlar GİZLİ çeker ve katmanları saydam zeminde 50 ms arayla 6 sn
# örnekler (out/kadrajA_akinti.png). Burada ardışık aynı örnekler tek adıma indirilir, en kısa döngü bulunur (ana harita: 30 adım = 3,6 sn,
# adım ~120 ms; karolar farklı uzunlukta döndüğü için birleşik döngü uzun) -> assets/ui/ana_menu/nehir_kamp_akinti.png (yatay şerit,
# kare 320x180), menu_camp_scene.gd tabanın üstünde AKINTI_* ile oynatır. Örnekleme titremesi yüzünden adım süresi = döngü süresi / adım.
AKINTI_ORNEK_MS = 50


AKINTI_SUTUN = 12  # kamp_capture.gd AKINTI_SUTUN (ham örnek ızgarası)


AKINTI_EN_AZ = 12  # aranacak en kısa döngü (örnek)
## Döngü = karoların 120 ms adımı ile 50 ms örneklemenin ORTAK katı (600 ms = 12 örnek) olmak zorunda: kadraj büyüyünce 0,72 sn'lik bir karo
## animasyonu 43 örnekte (2,15 sn, tam bölünmüyor) sahte bir dip veriyordu; gerçek birleşik döngü 72 örnek (3,6 sn).
AKINTI_HIZA = 12
AKINTI_KIYI_PAY = 4  # nehir bölgesi = su maskesi + bu kadar px (kıyı köpüğü / saçak); dışı (salınan fideler, çalı) şeride girmez


def _nehir_bolgesi(base):
    """Su maskesinin AKINTI_KIYI_PAY px genişletilmişi: yalnız burası şeride girer. Çayırdaki fideler / çalılar kendi rüzgâr
    shader'larıyla sürekli salınır (döngüsü yok) - onları almak döngüyü bozuyordu, tabanda durağan kalırlar."""
    m = water_mask(base).load()
    bolge = [[False] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            if m[x, y]:
                for dy in range(-AKINTI_KIYI_PAY, AKINTI_KIYI_PAY + 1):
                    for dx in range(-AKINTI_KIYI_PAY, AKINTI_KIYI_PAY + 1):
                        if 0 <= x + dx < W and 0 <= y + dy < H:
                            bolge[y + dy][x + dx] = True
    return bolge


def akinti_serit(base):
    """Ham örnekler (haritanın TAMAMI, çimen/ağaç sallanması kapalı) -> nehir bölgesinde döngü; şeride yalnız döngü boyunca DEĞİŞEN
    pikseller girer (gerisi saydam) - önü kapalı yerler (ağaç tepesi vb.) haritadaki gibi örtülü kalır."""
    s = Image.open(os.path.join(HERE, "out", "kadrajB_akinti.png")).convert("RGBA")
    n = (s.width // W) * (s.height // H)
    kare = [s.crop(((i % AKINTI_SUTUN) * W, (i // AKINTI_SUTUN) * H, (i % AKINTI_SUTUN) * W + W, (i // AKINTI_SUTUN) * H + H))
            for i in range(n)]
    kare = [k for k in kare if k.getbbox() is not None]  # ızgaranın boş artığı
    bolge = _nehir_bolgesi(base)
    disari = Image.new("L", (W, H), 0)
    dp = disari.load()
    for y in range(H):
        for x in range(W):
            if not bolge[y][x]:
                dp[x, y] = 255
    temiz = []
    for k in kare:  # nehir bölgesi dışı saydam
        k = k.copy()
        k.paste((0, 0, 0, 0), (0, 0), disari)
        temiz.append(k)
    kare = temiz
    # Döngü = ham örneklerde (50 ms ızgara) i ile i+P karelerinin nehir bölgesinde en az farklı olduğu P. Durumları tek tek eşleştirmek
    # (karolar 120 ms adımla döner, 50 ms örnekleme adım sınırlarında titrer) döngüyü bozuyordu; ham örnekler olduğu gibi 50 ms'de oynatılır.
    arr = [np.asarray(k).astype(np.int16) for k in kare]
    en_iyi = None
    for p in range(AKINTI_EN_AZ, len(arr) - 12, AKINTI_HIZA):
        fark = np.mean([int((np.abs(arr[i] - arr[i + p]).sum(axis=2) > 0).sum()) for i in range(len(arr) - p)])
        if en_iyi is None or fark < en_iyi[1] - 0.5:
            en_iyi = (p, fark)
    donem = en_iyi[0]
    print("akinti: donem %d ornek (%.0f ms), ort. fark %.1f px" % (donem, donem * AKINTI_ORNEK_MS, en_iyi[1]))
    dongu = arr[:donem]
    degisen = np.zeros((H, W), bool)
    for a in dongu[1:]:
        degisen |= np.abs(a - dongu[0]).sum(axis=2) > 0
    satir = (donem + AKINTI_SUTUN - 1) // AKINTI_SUTUN
    izgara = np.zeros((H * satir, W * AKINTI_SUTUN, 4), np.uint8)
    for i, a in enumerate(dongu):
        kare_px = np.where(degisen[..., None], a, 0).astype(np.uint8)
        izgara[(i // AKINTI_SUTUN) * H:(i // AKINTI_SUTUN + 1) * H, (i % AKINTI_SUTUN) * W:(i % AKINTI_SUTUN + 1) * W] = kare_px
    print("akinti: degisen piksel %d" % int(degisen.sum()))
    return Image.fromarray(izgara, "RGBA"), donem, float(AKINTI_ORNEK_MS)


# SALLANAN BİTKİLER (2026-11-16, kullanıcı: "ağaçlar ve çalılar sallanmıyor, sallanmalıydı ama yavaşça"): taban durağan yakalama olduğu için
# bitkiler donuktu. kamp_capture.gd KAMP_ZEMIN=1 aynı kadrajı iki kez çeker: <ad>_bitkili (her şey) + <ad>_zemin (oyunda sallanan ağaç / çalı /
# çiçek hücreleri silinmiş). Fark = bitki pikselleri -> taban artık BİTKİSİZ zemin, bitkiler ayrı katman (nehir_kamp_bitki.png) + piksel başına
# veri (nehir_kamp_bitki_veri.png, RGBA8: R = bitkinin kök satırı (en alt opak satır + 1), G = boyu, B = faz, A = 255 geçerli). Bitki = 8-komşu
# bağlı piksel öbeği; veri yatayda BITKI_PAY px boşluğa da yayılır (bitki sallanınca kenarının dışına düşen ekran pikseli de kendi bitkisini bulsun).
# Sallanma shaders/kamp_bitki.gdshader (oyunun sallanan ağaç.gdshader eğrisi: kök sabit, tepe en çok).
BITKI_PAY = 2


def bitki_katmani(dolu_ham, zemin_ham, dolu, zemin, serit):
    """(bitki RGBA, veri RGBA). Ham fark VE eşyalı/çiçeksiz hâllerin farkı: eşyanın örttüğü ya da cicek_sil'in sildiği piksel bitki sayılmaz.
    Akıntı şeridinin herhangi bir karesinde değişen piksel (kıyı köpüğü, akıntı çizgisi: iki çekim arasında karo animasyonu ilerler) de sayılmaz."""
    a_ham = np.asarray(dolu_ham).astype(int)
    b_ham = np.asarray(zemin_ham).astype(int)
    a = np.asarray(dolu).astype(int)
    b = np.asarray(zemin).astype(int)
    mask = (np.abs(a_ham - b_ham).sum(2) > 0) & (np.abs(a - b).sum(2) > 0) & (np.abs(a - a_ham).sum(2) == 0)
    s_alfa = np.asarray(serit)[:, :, 3]
    hareketli = np.zeros((H, W), bool)
    for sy in range(0, s_alfa.shape[0], H):
        for sx in range(0, s_alfa.shape[1], W):
            hareketli |= s_alfa[sy:sy + H, sx:sx + W] > 0
    mask &= ~hareketli
    bitki = np.zeros((H, W, 4), np.uint8)
    bitki[mask] = a[mask].astype(np.uint8)
    veri = np.zeros((H, W, 4), np.uint8)
    etiket = np.zeros((H, W), int)
    n = 0
    for y0, x0 in zip(*np.nonzero(mask)):
        if etiket[y0, x0]:
            continue
        n += 1
        etiket[y0, x0] = n
        yigin, noktalar = [(y0, x0)], []
        while yigin:
            y, x = yigin.pop()
            noktalar.append((y, x))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < H and 0 <= xx < W and mask[yy, xx] and not etiket[yy, xx]:
                        etiket[yy, xx] = n
                        yigin.append((yy, xx))
        ys = [q[0] for q in noktalar]
        xs = [q[1] for q in noktalar]
        kok = max(ys) + 1
        boy = min(255, kok - min(ys))
        faz = (int(sum(xs) / len(xs)) * 37 + kok * 11) % 256
        for y, x in noktalar:
            veri[y, x] = (kok, boy, faz, 255)
    # yatay yayılma: boş pikseller en yakın bitki pikselinin verisini alır (önce 1 px uzaktakiler, sonra 2)
    dolu_veri = veri[:, :, 3] > 0
    for d in range(1, BITKI_PAY + 1):
        ek = veri.copy()
        for y in range(H):
            for x in range(W):
                if veri[y, x, 3] or ek[y, x, 3]:
                    continue
                for xx in (x - d, x + d):
                    if 0 <= xx < W and dolu_veri[y, xx]:
                        ek[y, x] = veri[y, xx]
                        break
        veri = ek
        dolu_veri = veri[:, :, 3] > 0
    print("bitki: %d piksel, %d öbek" % (int(mask.sum()), n))
    return Image.fromarray(bitki, "RGBA"), Image.fromarray(veri, "RGBA")


def main():
    base = Image.open(os.path.join(HERE, "out", "kadrajB.png")).convert("RGBA")
    assert base.size == (W, H), base.size
    img = compose(base)
    serit, adim, adim_ms = akinti_serit(base)
    print("akinti: %d kare, kare %.1f ms (menu_camp_scene.gd AKINTI_FRAMES / AKINTI_FPS)" % (adim, adim_ms))
    tam = base.copy()  # su maskesi kıyı sanatı DAHİL görüntüden (yoksa kıyı çimeni gece ışığında su gibi boyanırdı)
    tam.alpha_composite(serit.crop((0, 0, W, H)))
    mask = water_mask(tam)
    bitki = veri = None
    p_dolu = os.path.join(HERE, "out", "kadrajB_bitkili.png")
    p_zemin = os.path.join(HERE, "out", "kadrajB_zemin.png")
    if os.path.exists(p_dolu) and os.path.exists(p_zemin):
        dolu_ham = Image.open(p_dolu).convert("RGBA")
        zemin_ham = Image.open(p_zemin).convert("RGBA")
        dolu = compose(dolu_ham)
        zemin = compose(zemin_ham)
        bitki, veri = bitki_katmani(dolu_ham, zemin_ham, dolu, zemin, serit)
        img = zemin  # taban bitkisiz; bitkiler menu_camp_scene.gd "Bitkiler" katmanında sallanır
    if "--oyun" in sys.argv:
        out = os.path.join(ROOT, "assets", "ui", "ana_menu")
        img.save(os.path.join(out, "nehir_kamp.png"))
        if bitki is not None:
            bitki.save(os.path.join(out, "nehir_kamp_bitki.png"))
            veri.save(os.path.join(out, "nehir_kamp_bitki_veri.png"))
        mask.save(os.path.join(out, "nehir_kamp_su.png"))
        serit.save(os.path.join(out, "nehir_kamp_akinti.png"))
        print("yazildi:", out)
    prev = img.resize((W * 3, H * 3), Image.NEAREST)
    prev.save(os.path.join(HERE, "out", "nehir_kamp_onizleme.png"))
    mask.resize((W * 2, H * 2), Image.NEAREST).save(os.path.join(HERE, "out", "nehir_kamp_su_onizleme.png"))


if __name__ == "__main__":
    main()
