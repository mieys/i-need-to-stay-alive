# GÖRÜNMEZ DUVARI GÖRÜNEN NESNELERE HİZALA (madde 676, 2026-11-14) - üretilen açık hava haritalarının ortak son adımı
# (tools/bataklik/gen_bataklik.py, tools/col/gen_col.py, tools/kis/gen_kis.py; ana harita Harita.tmx elle çizildiği için DEĞİL).
#
# Kullanıcı: "bataklıkta ağaç kenarlarında ve bazı yerlerde sürekli takılma sorunu var ağaçların arasından geçilmiyor engel sınırları hiç belli
# değil ... bu diğer haritalarda da var". Kök neden: üreteçler geçilmez bandı / koruyu / platoyu / dağ sırtını gürültülü bir HÜCRE MASKESİ olarak
# görünmez engel katmanına ("Orman parçaları/Orman parçaları", saydam karo) yazıp ağaç / kayayı sonra ARALIKLI diziyordu; maskenin oyun alanına bakan
# kenarı nesnelerin 1-3 hücre ötesinde açık zemine (çamur, kum, kar) taşıyordu: ölçüm, kenar hücrelerinin %57-68'i nesnesiz görünüyordu.
#
# Burada: haritanın ağaç + y-sıralı nesne katmanlarının opak pikselleri hücre başına "örtü" olarak ölçülür (hücre KÖK uzayında: oyuncunun gövde
# ortası; ayak FEET_SHIFT px aşağıda, terrain_collision.gd ile aynı). Doğuştan yürünerek ulaşılan alana komşu engel hücresi, örtüsü ESIK'ten azsa
# (açık zemin görünüyorsa) engelden çıkarılır; DERINLIK tur tekrarlanır (en çok o kadar hücre içeri kırpılır, seyrek bandın içine tünel açılmasın).
# Oyun alanının dış KENAR_KORU hücresi hiç kırpılmaz (harita sınırı açılmasın). Kırpma rastgelelik KULLANMAZ: haritanın geri kalanı bayt bayt aynı.
import numpy as np

ESIK = 0.35
DERINLIK = 3  ## ölçüldü: 6 / 12 tur açık kenarı azaltmıyor, yalnız seyrek bandın içine tünel açıyor
KENAR_KORU = 2


def nesne_ortusu(m, imgs, tile_rgba, layer_names, H, W, T, feet_shift):
    """hücre (KÖK uzayı) -> ayak kutusundaki (hücre + feet_shift px aşağı, T x T) nesne opak piksel oranı (0..1)"""
    alpha = np.zeros((H * T + T * 2, W * T), bool)
    for name in layer_names:
        for (x, y), v in m.layers.get(name, {}).items():
            t = tile_rgba(imgs, *v)
            alpha[y * T:(y + 1) * T, x * T:(x + 1) * T] |= t[..., 3] > 127
    fs = int(round(feet_shift))
    cov = np.zeros((H, W), np.float32)
    for gy in range(H):
        blk = alpha[gy * T + fs:gy * T + fs + T]
        cov[gy] = blk.reshape(T, W, T).mean(axis=(0, 2))
    return cov


def _komsu4(mask):
    nb = np.zeros_like(mask)
    nb[1:, :] |= mask[:-1, :]
    nb[:-1, :] |= mask[1:, :]
    nb[:, 1:] |= mask[:, :-1]
    nb[:, :-1] |= mask[:, 1:]
    return nb


def duvari_hizala(m, imgs, cov, compute_blocked, flood, spawn, play_rect, wall_layer='Orman parçaları',
                  esik=ESIK, derinlik=DERINLIK, kenar_koru=KENAR_KORU):
    """m.forest (görünmez engel maskesi) + m.layers[wall_layer] kırpılır. Dönüş: kırpılan hücre sayısı.
    play_rect = (px0, py0, genişlik, yükseklik) hücre."""
    px0, py0, pw, ph = play_rect
    H, W = m.forest.shape
    yy, xx = np.mgrid[0:H, 0:W]
    lx, ly = xx - px0, yy - py0
    edge = np.minimum.reduce([lx, ly, pw - 1 - lx, ph - 1 - ly])
    ## nesne engeli (ağaç gövdesi / katı nesne / su) - orman maskesi geçici boşaltılarak
    saved = m.forest.copy()
    m.forest[:] = False
    obj_blocked, _ = compute_blocked(m, imgs)
    m.forest[:] = saved
    cut_total = 0
    for _ in range(derinlik):
        reach = flood(m.forest | obj_blocked, spawn)
        cut = m.forest & _komsu4(reach) & (cov < esik) & (edge >= kenar_koru)
        if not cut.any():
            break
        m.forest &= ~cut
        for y, x in zip(*np.nonzero(cut)):
            m.layers[wall_layer].pop((int(x), int(y)), None)
        cut_total += int(cut.sum())
    return cut_total


def kenar_doldur(m, imgs, cov, compute_blocked, flood, spawn, try_place, esik=ESIK, seed=675):
    """kırpmadan ÖNCE: ulaşılan alana komşu, açık görünen engel hücrelerine haritanın kendi nesnesi denenir (try_place(x, y, rnd) -> bool,
    üretecin yerleştirme kurallarıyla; ayrı rastgele üreteç -> haritanın geri kalanı aynı). Bir nesnenin örttüğü komşu hücreler atlanır
    (kaba: yerleşen hücrenin 1 hücre çevresi). Dönüş: yerleşen nesne sayısı."""
    import random
    rnd = random.Random(seed)
    blocked, _ = compute_blocked(m, imgs)
    reach = flood(blocked, spawn)
    rim = m.forest & _komsu4(reach) & (cov < esik)
    ys, xs = np.nonzero(rim)
    order = list(zip(xs.tolist(), ys.tolist()))
    rnd.shuffle(order)
    done = set()
    n = 0
    for (x, y) in order:
        if (x, y) in done:
            continue
        if try_place(x, y, rnd):
            n += 1
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    done.add((x + dx, y + dy))
    return n


def acik_kenar(m, imgs, cov, compute_blocked, flood, spawn, esik=ESIK):
    """rapor: ulaşılan alana komşu engel hücresi sayısı ve bunların kaçı açık zemin görünüyor"""
    blocked, _ = compute_blocked(m, imgs)
    reach = flood(blocked, spawn)
    rim = m.forest & _komsu4(reach)
    return int(rim.sum()), int((rim & (cov < esik)).sum())
