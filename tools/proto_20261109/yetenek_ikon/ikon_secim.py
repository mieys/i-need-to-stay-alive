# Yetenek ikonu seçimi: masaüstü "Genel iconlar" önizlemelerinden (28 paket x 8x6) her yeteneğe
# 1 öneri + 2 yedek. Oyuna bağlı DEĞİL; çıktı out/ozet_1.png, out/ozet_2.png, out/secim.json.
# Kullanım: python -I ikon_secim.py
import os, json
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
SRC = os.path.join(os.path.expanduser("~"), "Desktop", "Genel iconlar")
CODES = {"48-Curse": "CUR", "Aeromancer": "AER", "Archer": "ARC", "Barbarian": "BAR", "Blood-Mage": "BLD", "Buff": "BUF",
         "Crossbowman": "CRS", "Cryomancer": "CRY", "Debuff": "DEB", "Demon-Skill-Icons-32x32": "DM1", "Demon-Skill-Icons-Pixel": "DM2",
         "Druid": "DRU", "Earthbender": "EAR", "Fairy": "FAI", "Free-Paladin": "PAL", "Free-Swordsman": "SWO", "Free-Undead": "UND",
         "Goblin": "ORC", "Lightning": "LIG", "Monk": "MON", "Necromancer": "NEC", "Pirate": "PIR", "Priest": "PRI", "Pyromancer": "PYR",
         "Spearman": "SPE", "Summoner": "SUM", "Thief": "THI", "Warlock": "WAR"}

# (karakter, [(yuva, yetenek, mevcut ikon dosyası, öneri, yedek b, yedek c), ...])
SECIM = [
    ("Talon", [("P", "Güç Yükü (pasif)", "talon_passive_icon", "BUF-D8", "BUF-E7", "BAR-A1"),
               ("Q", "Hamle Vuruşu", "talon_devlesme_icon", "SWO-D7", "SWO-C3", "SWO-F7"),
               ("E", "Silah Salvosu", "talon_yer_sarsintisi_icon", "SWO-C4", "SWO-B6", "UND-B7"),
               ("R", "Ayna Formu", "talon_ayna_formu_icon", "PAL-C6", "SWO-F3", "PAL-C7")]),
    ("Oakley", [("P", "Çiçek (pasif)", "oakley_cicek_icon", "DRU-C1", "FAI-C7", "FAI-E7"),
                ("Q", "Arı Sürüsü", "oakley_ari_suru_icon", "FAI-B7", "SUM-E3", "ARC-D5"),
                ("E", "Sarmaşıklar", "oakley_sarmasik_icon", "DRU-F4", "FAI-C2", "CUR-B5"),
                ("R", "Hayat Ağacı", "oakley_passive_icon", "DRU-A8", "DRU-F3", "FAI-E6")]),
    ("Matthew", [("P", "Yıldırım Hızı", "matthew_yildirim_hizi_icon", "LIG-D7", "AER-E2", "LIG-D2"),
                 ("Q", "Şimşek Hücumu", "matthew_simsek_hucumu_icon", "LIG-F2", "LIG-A1", "DM1-F8"),
                 ("E", "Elektrik Topu", "matthew_elektrik_topu_icon", "LIG-C1", "PAL-C3", "LIG-B1"),
                 ("R", "Yıldırım Kalkanı", "matthew_yildirim_kalkani_icon", "LIG-E2", "BUF-A4", "LIG-F1")]),
    ("Büyücü Kız", [("P", "Büyü Dalgası", "buyucu_passive_icon", "AER-F6", "PAL-B3", "BUF-C7"),
                    ("Q", "Büyü Değişimi", "buyucu_ulti_buyu_degisimi_icon", "PAL-F4", "MON-E2", "NEC-F7"),
                    ("E", "Arcane Lanet", "buyucu_skill_arcane_lanet_icon", "WAR-C7", "AER-D3", "CUR-E6"),
                    ("R", "Don Nova", "buyucu_skill_don_nova_icon", "CRY-F2", "CRY-B1", "CRY-F7")]),
    ("Assasin Çocuk", [("P", "Bıçak Uzmanlığı", "assasin_passive_icon", "THI-D6", "THI-A3", "BLD-A8"),
                       ("Q", "Şahin Hamlesi", "assasin_sahin_hamlesi_icon", "SWO-C3", "DM2-D7", "THI-C3"),
                       ("E", "Gölge Adımı", "assasin_golge_adimi_icon", "THI-C8", "AER-E6", "DM1-F4"),
                       ("R", "Gölge Hücumu", "assasin_golge_hucumu_icon", "THI-F3", "SWO-F7", "THI-F7")]),
    ("Şovalye Adam", [("P", "Dirençli Duruş", "sovalye_passive_icon", "BUF-E5", "PAL-B7", "PRI-E1"),
                      ("Q", "Kışkırtma (kalkan yeniler)", "sovalye_kiskirtma_icon", "PAL-D8", "BUF-E2", "PAL-C8"),
                      ("E", "Koruma Bariyeri", "sovalye_koruma_bariyeri_icon", "PAL-E7", "PAL-F1", "PAL-E6"),
                      ("R", "Koruma Baloncuğu", "sovalye_ulti_koruma_baloncugu_icon", "PAL-A8", "PAL-D5", "BUF-A6")]),
    ("Elara", [("P", "Seviye başı saldırı hızı", "elara_passive_icon", "BUF-D1", "BUF-D3", "ARC-C6"),
               ("Q", "Sıvışma", "elara_sivisma_icon", "ARC-C1", "ARC-C2", "CRS-D3"),
               ("E", "Gerçek Hasar", "elara_gercek_hasar_icon", "ARC-B6", "CRS-F8", "ARC-F7"),
               ("R", "Çift Tetik", "elara_cift_tetik_icon", "CRS-D1", "ARC-F3", "CRS-B8")]),
    ("Korsan", [("P", "Altın Avcısı", "korsan_papagan_icon", "THI-B8", "THI-E4", "PIR-E8"),
                ("Q", "Patlat", "korsan_patlat_icon", "DM1-E8", "ORC-D3", "PIR-E3"),
                ("E", "Saatli Bomba", "korsan_saatli_bomba_icon", "PIR-C7", "PIR-E1", "ORC-E1"),
                ("R", "Bombardıman", "korsan_bombardiman_icon", "PIR-C6", "PIR-D5", "PIR-D6")]),
    ("Melek", [("P", "Kalkan aurası (pasif)", "melek_passive_icon", "BUF-C8", "PRI-F7", "PRI-A2"),
               ("Q", "Can Basma", "melek_can_basma_icon", "BUF-D7", "PRI-A6", "FAI-D7"),
               ("E", "Kalkan Yenileme", "melek_kalkan_yenileme_icon", "PRI-F2", "BUF-E2", "PAL-F1"),
               ("R", "Kutsal Korku", "melek_kutsal_korku_icon", "PRI-F1", "PAL-E3", "PRI-C1")]),
    ("Necromancer", [("P", "Ruh biriktirme", "necromancer_passive_icon", "NEC-B4", "NEC-B3", "NEC-E6"),
                     ("Q", "İskelet Çağır", "necromancer_iskelet_cagir_icon", "NEC-A5", "NEC-A2", "NEC-A4"),
                     ("E", "Golem Çağır", "necromancer_hortlak_cagir_icon", "EAR-B3", "NEC-C3", "NEC-B8"),
                     ("R", "Lanetli Kafatası", "necromancer_lanetli_kafatasi_icon", "NEC-F2", "DM1-D3", "UND-B2")]),
    ("Shaman", [("P", "Totem Auraları", "shaman_passive_icon", "DRU-E1", "BUF-C5", "PYR-D6"),
                ("Q", "Saldırı Totemi", "shaman_saldiri_totemi_icon", "DRU-F1", "EAR-E8", "DRU-C6"),
                ("E", "Kalkan Totemi", "shaman_kalkan_totemi_icon", "EAR-D5", "BUF-C4", "EAR-D6"),
                ("R", "Elemental Golem", "shaman_elemental_golem_icon", "EAR-C5", "EAR-E3", "EAR-B5")]),
    ("Vampir Çocuk", [("P", "Kan Emme (pasif)", "vampir_passive_icon", "BLD-A4", "BLD-F8", "BUF-C1"),
                      ("Q", "Kan Emme", "vampir_kan_emme_icon", "BLD-D6", "BLD-C6", "BLD-A1"),
                      ("E", "Yarasa Formu", "vampir_yarasa_formu_icon", "BLD-E3", "UND-E5", "DM2-A8"),
                      ("R", "Kan Yarasaları", "vampir_kan_yarasalari_icon", "DM1-F5", "DM1-B3", "BLD-F3")]),
    ("Hadime", [("P", "Ruh Göçü", "hadime_passive_icon", "NEC-E5", "CUR-C8", "CUR-C3"),
                ("Q", "Lanet Kitabı", "hadime_lanet_kitabi_icon", "UND-F8", "NEC-D8", "UND-B8"),
                ("E", "Kara Delik", "hadime_kara_delik_icon", "UND-A2", "CUR-D2", "NEC-E4"),
                ("R", "Karabasan", "hadime_karabasan_icon", "CUR-E8", "BLD-F4", "UND-E1")]),
    ("Cadı", [("P", "Şans Tılsımı", "cadi_passive_icon", "FAI-F6", "MON-F6", "DEB-F7"),
              ("Q", "Zehirli Duman", "cadi_zehirli_duman_icon", "NEC-A7", "DEB-E8", "UND-A5"),
              ("E", "Uçan Süpürge", "cadi_supurge_icon", "PAL-E2", "AER-E7", "AER-E8"),
              ("R", "İksir Çantası", "cadi_iksir_icon", "WAR-E5", "DM1-C5", "DEB-F8")]),
]


def bands(prof, thr=0.15):
    b, s = [], None
    for i, v in enumerate(prof > thr):
        if v and s is None:
            s = i
        if not v and s is not None:
            b.append((s, i))
            s = None
    if s is not None:
        b.append((s, len(prof)))
    return [x for x in b if x[1] - x[0] > 10]


def load_icons():
    """Her önizlemeyi 8x6 ızgaraya böler: anahtar PAKET-<satır harfi><sütun>, ör. NEC-F2."""
    icons = {}
    for f in os.listdir(SRC):
        code = next(v for k, v in CODES.items() if f.startswith(k))
        im = Image.open(os.path.join(SRC, f)).convert("RGB")
        a = np.asarray(im).astype(int)
        edge = np.concatenate([a[:4].reshape(-1, 3), a[-4:].reshape(-1, 3), a[:, :4].reshape(-1, 3), a[:, -4:].reshape(-1, 3)])
        m = np.abs(a - np.median(edge, axis=0)).sum(axis=2) > 40
        rows, cols = bands(m.mean(axis=1)), bands(m.mean(axis=0))
        assert len(rows) == 6 and len(cols) == 8, f
        for ri, (y0, y1) in enumerate(rows):
            for ci, (x0, x1) in enumerate(cols):
                icons["%s-%s%d" % (code, "ABCDEF"[ri], ci + 1)] = im.crop((x0, y0, x1, y1))
    return icons


def font(sz, bold=False):
    return ImageFont.truetype("C:/Windows/Fonts/" + ("segoeuib.ttf" if bold else "segoeui.ttf"), sz)


BG, INK, DIM, GOLD, LINE = (36, 28, 22), (240, 226, 200), (170, 150, 125), (232, 190, 92), (70, 56, 44)


def badge(d, x, y, text, f):
    w = d.textlength(text, font=f) + 8
    d.rectangle((x, y, x + w, y + 18), fill=(20, 15, 12))
    d.text((x + 4, y - 1), text, fill=GOLD, font=f)


def render(icons, chars, start_no, path, page, pages):
    NAME_W, CELL_W, ROW_H, TOP = 150, 300, 168, 70
    W = NAME_W + 4 * CELL_W + 20
    im = Image.new("RGB", (W, TOP + len(chars) * ROW_H + 10), BG)
    d = ImageDraw.Draw(im)
    d.text((16, 10), "YETENEK İKONU ÖNERİLERİ  (%d/%d)" % (page, pages), fill=GOLD, font=font(24, True))
    d.text((16, 42), "Her yetenek: soldaki küçük = ŞU ANKİ ikon, büyük = ÖNERİM (numara), sağdaki iki küçük = yedek b / c.   "
                     "Örn: \"7 olmasın\", \"12 b olsun\".", fill=DIM, font=font(14))
    no = start_no
    for r, (cname, slots) in enumerate(chars):
        y = TOP + r * ROW_H
        d.line((10, y, W - 10, y), fill=LINE, width=1)
        d.text((16, y + 64), cname, fill=INK, font=font(18, True))
        for k, (slot, sname, cur, pick, alt_b, alt_c) in enumerate(slots):
            x = NAME_W + k * CELL_W
            d.text((x, y + 8), slot + "  " + sname, fill=INK, font=font(15, True))
            cp = os.path.join(ROOT, "assets", "skills", cur + ".png")
            if os.path.exists(cp):
                c = Image.open(cp).convert("RGBA").resize((48, 48), Image.NEAREST)
                im.paste(c, (x, y + 62), c)
            d.text((x + 6, y + 112), "şu an", fill=DIM, font=font(12))
            d.text((x + 54, y + 72), "»", fill=DIM, font=font(22, True))
            im.paste(icons[pick].resize((112, 112), Image.LANCZOS), (x + 74, y + 36))
            badge(d, x + 74, y + 36, str(no), font(14, True))
            for j, a in enumerate((alt_b, alt_c)):
                ay = y + 36 + j * 58
                im.paste(icons[a].resize((54, 54), Image.LANCZOS), (x + 194, ay))
                badge(d, x + 194, ay, "%d%s" % (no, "bc"[j]), font(12, True))
            d.text((x + 74, y + 150), pick, fill=DIM, font=font(11))
            no += 1
    im.save(path)
    return no


def main():
    icons = load_icons()
    out = os.path.join(HERE, "out")
    os.makedirs(out, exist_ok=True)
    no = render(icons, SECIM[:7], 1, os.path.join(out, "ozet_1.png"), 1, 2)
    render(icons, SECIM[7:], no, os.path.join(out, "ozet_2.png"), 2, 2)
    rows, n = [], 1
    for cname, slots in SECIM:
        for slot, sname, cur, pick, b, c in slots:
            rows.append({"no": n, "karakter": cname, "yuva": slot, "yetenek": sname, "mevcut": cur, "oneri": pick, "b": b, "c": c})
            n += 1
    with open(os.path.join(out, "secim.json"), "w", encoding="utf-8") as fh:
        json.dump(rows, fh, ensure_ascii=False, indent=1)
    print("tamam", n - 1, "yetenek")


if __name__ == "__main__":
    main()
