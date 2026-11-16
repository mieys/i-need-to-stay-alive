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


def cikinti_temizle(m, imgs, compute_blocked, flood, spawn, play_rect, wall_layer='Orman parçaları', tur=4, kenar_koru=KENAR_KORU):
    """CİLA (madde 714, 2026-11-15): duvari_hizala'dan SONRA görünmez engel maskesinin (m.forest) oyun alanına doğru TEK HÜCRE çıkıntıları
    engelden çıkarılır: 4 komşusundan en az 3'ü ulaşılan zemin olan hücre (bant kenarındaki köşegen basamak, açıkta kalan kırıntı). Bu hücreler
    nesne örtüsü ESIK'i geçtiği için (ağaç tacı, kuru dal, kaya sırtı) hizalamada kalmıştı ama ayağın değdiği yerde gövde/taban yok: oyuncu ağaç
    tacının ALTINDA görünmez duvara takılıyordu. Nesnelerin kendi engeli (ağaç gövdesi / kaya tabanı / su, compute_blocked) DOKUNULMAZ; iki yanı
    açık ince duvar (2 komşu) kalır -> bant içine tünel açılmaz. Görünüşü değiştirmez, rastgelelik kullanmaz. Dönüş: çıkarılan hücre sayısı."""
    px0, py0, pw, ph = play_rect
    H, W = m.forest.shape
    yy, xx = np.mgrid[0:H, 0:W]
    lx, ly = xx - px0, yy - py0
    edge = np.minimum.reduce([lx, ly, pw - 1 - lx, ph - 1 - ly])
    saved = m.forest.copy()
    m.forest[:] = False
    obj_blocked, _ = compute_blocked(m, imgs)
    m.forest[:] = saved
    total = 0
    for _ in range(tur):
        reach = flood(m.forest | obj_blocked, spawn)
        r = reach.astype(np.int8)
        open4 = np.zeros((H, W), np.int8)
        open4[1:, :] += r[:-1, :]
        open4[:-1, :] += r[1:, :]
        open4[:, 1:] += r[:, :-1]
        open4[:, :-1] += r[:, 1:]
        cut = m.forest & (open4 >= 3) & (edge >= kenar_koru)
        ## açık arazide tek başına kalan küçük adacık (<= ADA hücre, çevresinin TAMAMI ulaşılan zemin; 2x2'de her hücrenin 2 açık komşusu var)
        isl = m.forest & (open4 >= 1) & (edge >= kenar_koru) & ~cut
        seen = np.zeros_like(isl)
        for sy, sx in zip(*np.nonzero(isl)):
            if seen[sy, sx]:
                continue
            comp, st, ok = [], [(sy, sx)], True
            seen[sy, sx] = True
            while st and len(comp) <= 4:
                y, x = st.pop()
                comp.append((y, x))
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = y + dy, x + dx
                    if not (0 <= ny < H and 0 <= nx < W):
                        ok = False
                    elif m.forest[ny, nx]:
                        if not seen[ny, nx]:
                            seen[ny, nx] = True
                            st.append((ny, nx))
                    elif not reach[ny, nx] and not obj_blocked[ny, nx]:
                        ok = False  ## ağaç gövdesi / kaya tabanı komşusu sorun değil: onun kendi engeli kalır
            if ok and not st and len(comp) <= 4:
                for p in comp:
                    cut[p] = True
        if not cut.any():
            break
        m.forest &= ~cut
        for y, x in zip(*np.nonzero(cut)):
            m.layers[wall_layer].pop((int(x), int(y)), None)
        total += int(cut.sum())
    return total


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
