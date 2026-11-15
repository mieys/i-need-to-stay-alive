# Ruhani (F) yetenek ikonları için AYRI seçim sayfası. Kullanıcı: "kullanmadığımız bütün ikonları kullanarak ruhani
# yetenekler için yeni ikonlar öner, ayrı bir liste olarak gönder". Adaylar yalnız oyunda kullanılmayan paket
# ikonlarından (out/kullanilan.json dışı; aşağıda kontrol edilir). Çıktı out/ruhani/index.html + ikonlar.webp.
# Kullanım: python -I ruhani_sayfa.py
import os, sys, json
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ikon_secim as K  # noqa: E402
import sayfa_hazirla as SH  # noqa: E402
import uygula as U  # noqa: E402

CELL = 120
# (no, ad, mevcut dosya, açıklama, [a(önerim), b, c, ekler...])  — spiritual_skills.gd sırası
RUHANI = [
    (101, "Para", "spirit_para_icon", "Pasif: 10 sn'de 5 altın, dükkan %10 ucuz.",
     ["THI-B8", "THI-E4", "PIR-C8", "PIR-E6", "BUF-E1", "PIR-E7"]),
    (102, "Can", "spirit_can_icon", "Tüm takıma anında can + kalkan, 3 sn hasar görmez.",
     ["BUF-D7", "PRI-D2", "FAI-D7", "BUF-D6", "PAL-F2", "PRI-B1", "BLD-C6", "PAL-C4", "FAI-E7"]),
    (103, "Adc", "spirit_adc_icon", "10 sn saldırı hızı, kalkan delme ve can emme.",
     ["ARC-F3", "ARC-B4", "BUF-D3", "ARC-F5", "ARC-B2", "ARC-B7", "ARC-E2", "BUF-B1", "ARC-C6"]
     + ["BUF-A3", "ARC-E1", "CRS-C3", "SPE-F7", "BUF-B7", "SWO-F7", "THI-D6", "BUF-B5", "LIG-E6"]),  # 2. tur
    (104, "Tank", "spirit_tank_icon", "10 sn alınan hasarın %200'ünü yansıtır, kalkan yenilenir.",
     ["PAL-D6", "CUR-B1", "SWO-B1", "BUF-A8", "SWO-C5", "PRI-E1", "BUF-C2", "SPE-B8"]),
    (105, "Taktiksel", "spirit_taktik_icon", "İleri ışınlanır, 3 sn %30 hız.",
     ["MON-E7", "AER-E2", "CUR-F8", "BUF-E8", "CRS-D3", "ARC-C1", "THI-F6", "SWO-E3", "AER-D3"]),
    # 106 Dükkan: kullanıcı "bu yetenek silinecek" -> oyundan silindi (madde 541), kart yok
    (107, "Savaş Şevki", "spirit_savas_sevki_icon", "Pasif: öldürmeler birikir, 50'de kalıcı +1 saldırı gücü.",
     ["BUF-A7", "DM1-C4", "BUF-D8", "BUF-E7", "BAR-C5", "BAR-C3", "BAR-D2", "SWO-D2", "CUR-F4"]
     + ["BAR-C2", "BAR-C8", "ORC-B1", "BUF-A1", "BAR-D6", "BAR-F4", "ORC-C7", "BAR-E5", "DM1-A7"]),  # 2. tur
    (108, "Kalkan Bağı", "spirit_kalkan_bagi_icon", "En yakın dostla kalkan bağı: değişimler %50 yansır.",
     ["PAL-F1", "DM1-F3", "BUF-C8", "DEB-A5", "CUR-C7", "MON-E2", "DM1-E2", "PAL-B8", "BUF-E4"]),
    (109, "Toplayıcı", "spirit_toplayici_icon", "Pasif: XP toplama menzili, 60 sn'de bir görüşteki XP sana çekilir.",
     ["BUF-F4", "FAI-D6", "PRI-B5", "SUM-E7"]),  # 2026-11-12: yeni ruhani (madde 625), önerim a
]
IDS = list("abcdefghijklmnopqrstuvwxyz")
ROUND2_START = {103: 9, 107: 9}  # bu sıradan sonraki adaylar 2. tur ("yeni"), öncekiler "önceki tur"


def _tints():
    """no -> [(taban kimlik, ad, işlev)]: yalnız ton (renk_ayar.rotate_hue) ya da yalnız ok (mirror_box)."""
    import renk_ayar as R
    green = (60, 170, 90)
    red_to_green = lambda im: R.rotate_hue(im, green, weight=R.hue_band(im, -14, 12, soft=6))
    return {
        # Can: "a ve b olabilir ancak yeşil tonlarda, yeniden çizme" (ölçüm: BUF-D7 zemin ton 129, kalp/artı ~0-3;
        # PRI-D2 zemin 127-149, figür 157-170)
        102: [("a", "yeşil zemin", lambda im: R.rotate_hue(im, green, weight=R.hue_band(im, 108, 152))),
              ("a", "zemin + kalpler yeşil", lambda im: red_to_green(R.rotate_hue(im, green, weight=R.hue_band(im, 108, 152)))),
              ("b", "yeşil", lambda im: R.rotate_hue(im, green, weight=R.hue_band(im, 115, 180))),
              ("b", "yumuşak yeşil", lambda im: R.rotate_hue(im, green, weight=R.hue_band(im, 115, 180), chroma=0.7))],
        # Taktiksel: "sağ alttaki oku kaldır d'nin" (BUF-E8): ok kutusu yatay aynayla dolar, kanat/bot dokunulmaz
        # (ilk sürüm mirror_box kutusu botun sağ konturunu kesip dikey çizgi bırakıyordu - kullanıcı "tuhaf bir çizgi";
        # şimdi yalnız okun pikselleri, x >= 104 (ölçüm: bot koyusu x<=98, beyaz konturu 99-103), dikişsiz dolgu)
        105: [("d", "ok silindi", lambda im: R.remove_arrow_mask(im, 0.66, 0.6, 104))],
        # Savaş Şevki: "C ancak arkaplan kırmızı tonlarda" (BUF-D8; ölçüm: zemin ton 27-42 V 220+, yumruk ton 22-29
        # V 83-142, yeşil ok ton ~85) -> yalnız kenara bağlı parlak zemin kırmızıya döner + koyulaşır (parlak sarı
        # yalnız tonla soluk pembe olurdu); yumruk ve ok aynı, paketin açık konturu zeminin açık kırmızısı olur.
        # bg_only renk eşiğiyle kahve yumruğa sızdı / doygunluğu düşürdü -> bg_behind_outline: figür konturun içinden
        # merkezden dolgu + delik doldurma ile kilitlenir (ölçüm: yumruk bölgesinde değişen 118/4375 = yalnız dış kontur)
        107: [("c", "kırmızı zemin", lambda im: R.bg_behind_outline(im, 2, val_mul=0.75)[0])],
        # Kalkan Bağı: "A ancak mavi tonlarda" (PAL-F1 altın kalkanlar ton 23-42) -> bütün ikon yalnız ton
        108: [("a", "mavi", lambda im: R.rotate_hue(im, (60, 150, 220))),
              ("a", "lacivert-mavi", lambda im: R.rotate_hue(im, (40, 110, 210))),
              ("a", "lacivert, biraz koyu", lambda im: R.rotate_hue(im, (30, 95, 200), luma=0.8))],
    }


INTRO = ("2. tur: Dükkan oyundan silindi. Adc ve Savaş Şevki'ne 9'ar yeni aday ekledim (yeşil · yeni; eskiler de seçilebilir). "
         "Can, Taktiksel ve Kalkan Bağı'ndaki altın etiketli kareler notlarına göre: yalnız TON döndü ya da yalnız ok silindi, "
         "çizime dokunulmadı. Para ve Tank seçimlerin oyuna yazıldı. Üstteki 'Sadece seçilmemişler' kalan kartları gösterir.")


def main():
    used = set()
    for v in list(U.SON.values()) + list(U.SON_V.values()):
        if v:
            used.add(v[0])
    used |= {t for t, _ in U.SON_IKSIR.values()}
    used -= {"PIR-E7", "PAL-D6"}  # ruhani 101/104 seçimleri artık oyunda (SON_RUHANI) - kendi kartlarında aday kalırlar
    flat = [k for r in RUHANI for k in r[4]]
    clash = sorted(set(flat) & used)
    assert not clash, "kullanılmış ikon aday olmuş: %s" % clash
    out = os.path.join(HERE, "out", "ruhani")
    os.makedirs(out, exist_ok=True)
    icons = K.load_icons()
    rows = []
    tints = _tints()
    for i, (no, name, cur, desc, keys) in enumerate(RUHANI):
        opts = [{"id": "mevcut", "label": "şu an", "icon": cur, "tag": "cur", "col": 0}]
        r2 = ROUND2_START.get(no)
        for j, k in enumerate(keys):
            tag = "rec" if j == 0 else ""
            if r2 is not None:
                tag = "new" if j >= r2 else "old"
            opts.append({"id": IDS[j], "label": IDS[j], "icon": k, "tag": tag, "col": j + 1})
        for t, (base, label, fn) in enumerate(tints.get(no, [])):
            bkey = next(o["icon"] for o in opts if o["id"] == base)
            tkey = "%s+ton%d" % (bkey, t + 1)
            icons[tkey] = fn(icons[bkey].convert("RGB").resize((144, 144), Image.LANCZOS))
            opts.append({"id": "%s_ton%d" % (base, t + 1), "label": base + " " + label, "icon": tkey, "tag": "tint",
                         "col": len(opts)})
        rows.append({"no": no, "row": i, "karakter": "Ruhani yetenekler", "yuva": "F", "yetenek": name,
                     "mevcut": cur, "desc": desc, "opts": opts})
    cols = max(len(r["opts"]) for r in rows)
    sheet = Image.new("RGB", (cols * CELL, len(rows) * CELL), (20, 14, 9))
    for r in rows:
        y = r["row"] * CELL
        for o in r["opts"]:
            if o["tag"] == "cur":
                c = SH.current_icon(o["icon"])
                sheet.paste(c, ((CELL - c.width) // 2, y + (CELL - c.height) // 2), c)
            else:
                sheet.paste(icons[o["icon"]].resize((CELL, CELL), Image.LANCZOS), (o["col"] * CELL, y))
    sheet.save(os.path.join(out, "ikonlar.webp"), "WEBP", quality=92, method=6)
    tpl = open(os.path.join(HERE, "sayfa_sablon.html"), encoding="utf-8").read()
    tpl = tpl.replace("<title>Yetenek İkonu Seçimi</title>", "<title>Ruhani Yetenek İkonları</title>")
    tpl = tpl.replace("<h1>Yetenek İkonu Seçimi</h1>", "<h1>Ruhani Yetenek İkonları</h1>")
    data = json.dumps({"cols": cols, "rows": rows, "intro": INTRO}, ensure_ascii=False)
    open(os.path.join(out, "index.html"), "w", encoding="utf-8", newline="\n").write(tpl.replace("/*VERI*/{}", data))
    print("tamam", len(rows), "yetenek,", len(flat), "aday,", os.path.getsize(os.path.join(out, "ikonlar.webp")) // 1024, "KB")


if __name__ == "__main__":
    main()
