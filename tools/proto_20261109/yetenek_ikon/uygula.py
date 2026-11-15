# Kullanıcının son seçimini (4 tur, onay sayfası) assets/skills/ altındaki yetenek ikonlarına yazar.
# Dosya adları AYNI kalır (characters.gd'ye dokunulmaz); eskiler yedek/ klasörüne bir kez kopyalanır.
# Biçim: oyunun kuralı 48x48 sanat x3 = 144x144 (HUD yuvasında 48 px birebir). Kaynak önizleme
# ızgarası güvenilir geri çıkmadığı için kırpım LANCZOS ile 48'e indirilir, sonra en yakın x3.
# Kullanım: python -I uygula.py        (yaz + out/son_ozet.png)
#           python -I uygula.py --geri (yedekten geri yükle)
#           python -I uygula.py --yalniz 51 [52 ...] (yalnız bu satırlar; diğer ikonlara dokunmaz, özet out/son_ozet_yalniz.png)
import os, sys, json, shutil
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ikon_secim as K  # noqa: E402
import renk_ayar as R  # noqa: E402

SKILLS = os.path.join(K.ROOT, "assets", "skills")
YEDEK = os.path.join(HERE, "yedek")
ART, SCALE = 48, 3

# no -> (seçilen ikon, renk ayarı). None = şu anki ikon kalsın. renk: RENK[no] ya da "son" (SON_RENK[anahtar]).
SON = {
    1: ("BAR-A1", None), 2: ("SWO-C3", None), 3: ("SWO-C4", None), 4: ("PAL-C6", None),
    5: ("DRU-C1", None), 6: ("SUM-E3", None), 7: None, 8: ("DRU-A8", None),
    # 5./6. tur: 12 e (LIG-A5) yalnız kırmızı zemin tonu, 18 r (MON-C6) boyasız, 24/34 yalnız ton (renk_ayar.TON5)
    9: ("LIG-D7", None), 10: ("LIG-A1", "renk"), 11: ("PAL-C3", None), 12: ("LIG-A5", ("ton", 1)),
    13: ("AER-F6", None), 14: ("PAL-F4", None), 15: ("WAR-C4", None), 16: ("CRY-C5", None),
    17: ("BLD-A8", None), 18: ("MON-C6", None), 19: ("DM1-F4", None), 20: ("THI-F3", None),
    21: ("BUF-E5", "renk"), 22: ("BAR-B8", None), 23: ("PAL-E6", "renk"), 24: ("PAL-A8", ("ton", 2)),
    25: ("BUF-D1", None), 26: ("BUF-F2", None), 27: ("CRS-F8", None), 28: ("CRS-B8", None),
    29: ("PIR-E8", None), 30: ("ORC-D3", None), 31: ("PIR-C7", None), 32: ("PIR-C6", None),
    33: ("BUF-F8", None), 34: ("PRI-A6", ("ton", 3)), 35: ("FAI-D2", "son"), 36: ("PRI-F1", None),
    37: ("NEC-B3", None), 38: ("NEC-A5", None), 39: ("NEC-C3", None), 40: ("NEC-F2", None),
    # 42/43 Shaman Q/E: 2026-11-11'den beri kullanıcının RÜN TAŞINDAN (tools/proto_20261111/shaman_ikon/shaman_ikon.py);
    # eski seçim DRU-F1 / EAR-D5 idi. None = bu betik onlara dokunmaz.
    41: ("PYR-E7", None), 42: None, 43: None, 44: ("EAR-E3", None),
    45: ("BLD-A4", None), 46: ("BLD-B5", None), 47: ("UND-F4", None), 48: ("DM1-F5", None),
    49: ("CUR-C3", ("hadime", "b")), 50: ("UND-F8", ("hadime", "b")), 51: ("DM2-E8", "lanet_yesil"), 52: ("CUR-E8", ("hadime", "a")),
    53: ("FAI-F6", None), 54: ("NEC-A7", None), 55: ("AER-E8", None), 56: ("WAR-E5", None),
}


# 6. tur varyant kartları (sayfa_hazirla.VARYANT, no 57-66): no -> (ikon, renk). İksirler (61-66) ayrı sayfada seçilir.
SON_V = {
    57: ("EAR-B8", None), 58: ("DM2-A4", None),  # Büyücü 2. set Hortum / Meteor
    59: ("EAR-C1", None), 60: ("EAR-D4", None),  # Shaman golem Sarsıcı Darbe / Golem Sıçrayışı
}


# 9. tur: Cadı iksirleri (iksir sayfası, db "zemin"): no -> (paket zemin şablonu, kontur). İksir = iksir_zemin.SECIM.
SON_IKSIR = {
    61: ("PRI-C2", False), 62: ("PRI-C2", False), 63: ("PRI-C2", False),  # Delilik / Don / Patlama: ışık perdesi
    64: ("PRI-C1", False), 65: ("PRI-C2", False), 66: ("PRI-C1", False),  # Şifa: ışın patlaması, Korku: perde, Kalkan: patlama
}


# Ruhani (F) yetenekler (ruhani_sayfa.py, db secimler/s101..): no -> (ikon, renk). Renkler ruhani_sayfa._tints ile.
SON_RUHANI = {
    101: ("PIR-E7", None),  # Para
    102: ("PRI-D2", ("rton", 4)),  # Can: b yumuşak yeşil (yalnız ton)
    103: ("LIG-E6", None),  # Adc
    104: ("PAL-D6", None),  # Tank
    105: ("BUF-E8", ("rton", 1)),  # Taktiksel: d, sağ alttaki ok silindi
    107: ("BUF-D8", ("rton", 1)),  # Savaş Şevki: c, zemin kırmızı (yumruk/oklar aynı)
    108: ("PAL-F1", ("rton", 2)),  # Kalkan Bağı: a lacivert-mavi (yalnız ton)
    109: ("BUF-F4", None),  # Toplayıcı (2026-11-12, madde 625): avuçlanmış el ışığı toplar, boyasız
}


def variant_rows():
    import sayfa_hazirla as SH
    return [r for r in SH.variant_rows() if r["no"] in SON_V]


def spirit_rows():
    import ruhani_sayfa as RS
    return [{"no": no, "karakter": "Ruhani", "yuva": "F", "yetenek": name, "mevcut": cur}
            for no, name, cur, _, _ in RS.RUHANI if no in SON_RUHANI]


def potion_rows():
    import iksir_zemin as Z
    import iksir_sayfa as IS
    files = {no: cur for no, cur, _ in IS.IKSIR}
    return [{"no": no, "karakter": "Cadı", "yuva": "R", "yetenek": Z.SECIM[no][0], "mevcut": files[no]} for no in SON_IKSIR]


def make_icon(icons, no, key, renk):
    im = icons[key].convert("RGB").resize((144, 144), Image.LANCZOS)
    if isinstance(renk, tuple) and renk[0] == "rton":  # ruhani sayfası seçenekleri (ruhani_sayfa._tints)
        import ruhani_sayfa as RS
        im = RS._tints()[no][renk[1] - 1][2](im)
    elif isinstance(renk, tuple) and renk[0] == "hadime":  # Hadime seti (madde 561): Pasif/Q mor, R yeşil - hadime_e_oneri.SET_RENK
        import hadime_e_oneri as HE
        im = next(f for k, _, f in HE.SET_RENK[no] if k == renk[1])(im)
    elif isinstance(renk, tuple):  # ("ton", k): yalnız ton döner (5. tur yöntemi)
        im = R.TON5[no][renk[1] - 1][2](im)
    elif renk == "renk":
        im = R.RENK[no][2](im)
    elif renk == "son":
        im = R.SON_RENK[key](im)
    elif renk == "lanet_yesil":  # Hadime E Lanet Çukuru (madde 561): sıcak ışık -> efektin lanet yeşili, yalnız ton
        import hadime_e_oneri as HE
        im = HE.to_green(im)
    small = im.resize((ART, ART), Image.LANCZOS)
    return small.resize((ART * SCALE, ART * SCALE), Image.NEAREST).convert("RGBA")


def rows():
    return json.load(open(os.path.join(HERE, "out", "secim.json"), encoding="utf-8"))


def geri():
    n = 0
    for f in os.listdir(YEDEK):
        shutil.copy2(os.path.join(YEDEK, f), os.path.join(SKILLS, f))
        n += 1
    print("geri yüklendi:", n)


def ozet(pairs, path):
    f, fb = K.font(14), K.font(16, True)
    S, NAME_W, CELL = 96, 150, 2 * 96 + 40
    chars = []
    for r, old, new in pairs:
        if r["karakter"] not in chars:
            chars.append(r["karakter"])
    im = Image.new("RGB", (NAME_W + 4 * CELL + 10, 50 + len(chars) * (S + 34)), K.BG)
    d = ImageDraw.Draw(im)
    d.text((14, 12), "YETENEK İKONLARI: eski  »  yeni (oyunda 48 px, burada x2)", fill=K.GOLD, font=K.font(20, True))
    for ci, c in enumerate(chars):
        y = 50 + ci * (S + 34)
        d.text((14, y + S // 2 - 8), c, fill=K.INK, font=fb)
        for k, (r, old, new) in enumerate([p for p in pairs if p[0]["karakter"] == c]):
            x = NAME_W + k * CELL
            d.text((x, y), "%s  %s" % (r["yuva"], r["yetenek"][:22]), fill=K.DIM, font=f)
            o = old.convert("RGBA")
            o.thumbnail((S, S), Image.NEAREST if max(o.size) <= 200 else Image.LANCZOS)
            im.paste(o, (x, y + 20), o)
            d.text((x + S + 8, y + 20 + S // 2 - 12), "»", fill=K.DIM, font=K.font(20, True))
            if new is not None:
                n = new.resize((S, S), Image.NEAREST)
                im.paste(n, (x + S + 30, y + 20), n)
            else:
                d.text((x + S + 34, y + 20 + S // 2 - 8), "aynı kalır", fill=K.DIM, font=f)
    im.save(path)


def main():
    if "--geri" in sys.argv:
        return geri()
    only = None
    if "--yalniz" in sys.argv:
        only = {int(x) for x in sys.argv[sys.argv.index("--yalniz") + 1:]}
    icons = K.load_icons()
    os.makedirs(YEDEK, exist_ok=True)
    import iksir_zemin as Z
    pairs, n = [], 0
    for r in rows() + variant_rows() + potion_rows() + spirit_rows():
        if only is not None and r["no"] not in only:
            continue
        name = r["mevcut"] + ".png"
        src = os.path.join(SKILLS, name)
        bak = os.path.join(YEDEK, name)
        if not os.path.exists(bak) and os.path.exists(src):
            shutil.copy2(src, bak)  # yalnız ilk sefer: yeniden çalıştırmak yedeği ezmez
        old = Image.open(bak) if os.path.exists(bak) else Image.new("RGBA", (ART * SCALE, ART * SCALE))  # yeni ikon: eski yok
        if r["no"] in SON_IKSIR:
            tmpl, outline = SON_IKSIR[r["no"]]
            new = Z.compose_pack(r["no"], icons, tmpl, outline).resize((ART * SCALE, ART * SCALE), Image.NEAREST)
            new.save(src)
            pairs.append((r, old, new))
            n += 1
            continue
        pick = SON.get(r["no"]) if r["no"] in SON else (SON_V.get(r["no"]) or SON_RUHANI[r["no"]])
        if pick is None:
            pairs.append((r, old, None))
            continue
        new = make_icon(icons, r["no"], *pick)
        new.save(src)
        pairs.append((r, old, new))
        n += 1
    ozet(pairs, os.path.join(HERE, "out", "son_ozet.png" if only is None else "son_ozet_yalniz.png"))
    print("yazıldı:", n, "ikon; yedek:", YEDEK)


if __name__ == "__main__":
    main()
