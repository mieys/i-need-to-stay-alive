# Seçilebilir onay sayfası: out/sayfa/index.html + out/sayfa/ikonlar.webp
# (satır = yetenek no, sütun 0 = şu anki ikon, 1-3 = aday a/b/c). Önce ikon_secim.py çalışmış olmalı.
# Kullanım: python -I sayfa_hazirla.py
import os, sys, json
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ikon_secim as K  # noqa: E402

CELL = 120
DESC = {
    ("Talon", "P"): "Yetenek kullandıkça güç yükü kazanır (+saldırı gücü, hasar azaltma).",
    ("Talon", "Q"): "İleri hamle yapar, ardından bütün silahlar 3 kez ateş eder.",
    ("Talon", "E"): "Silahlar etrafında dönüp sürekli ateş eder.",
    ("Talon", "R"): "Her silahın aynalı bir kopyası belirir.",
    ("Oakley", "P"): "Yere şifa veren bir çiçek bırakır.",
    ("Oakley", "Q"): "Etrafını zehirleyen bir arı halkası sarar.",
    ("Oakley", "E"): "Yaratıkları yere sabitleyen 3 sarmaşık.",
    ("Oakley", "R"): "Gölgesi şifa veren bir Hayat Ağacı diker.",
    ("Matthew", "P"): "Yürüdükçe hızlanır, arkasında yıldırım izi bırakır.",
    ("Matthew", "Q"): "En yakın 6 düşmana sırayla şimşek çaktırır.",
    ("Matthew", "E"): "Elektrik topuna dönüşür, değdiğine hasar verir.",
    ("Matthew", "R"): "Hasar emen yıldırım kalkanı, sonunda patlar.",
    ("Büyücü Kız", "P"): "E/R sonrası silahlar geri tepip güçlü ateş eder.",
    ("Büyücü Kız", "Q"): "E ve R büyü setini değiştirir.",
    ("Büyücü Kız", "E"): "Düşmanlar arasında seken lanet (2. set: Hortum).",
    ("Büyücü Kız", "R"): "Yavaşlatan buz dalgası (2. set: Meteor).",
    ("Assasin Çocuk", "P"): "Yetenekten sonra 3 sn garantili kritik.",
    ("Assasin Çocuk", "Q"): "Yürüdüğü yöne hızlı hamle, 2 yük.",
    ("Assasin Çocuk", "E"): "Odaklanıp 6 sn görünmez olur.",
    ("Assasin Çocuk", "R"): "Görüşteki düşmanlara sırayla 15 kez çarpar.",
    ("Şovalye Adam", "P"): "Canı %40'ın altındayken %20 az hasar alır.",
    ("Şovalye Adam", "Q"): "6 sn boyunca kendi kalkanını yeniler.",
    ("Şovalye Adam", "E"): "Dostların etrafında, hasarlarını üstlenen bariyer.",
    ("Şovalye Adam", "R"): "İçine düşman giremeyen koruma kubbesi.",
    ("Elara", "P"): "Her seviyede saldırı hızı kazanır.",
    ("Elara", "Q"): "Hızlanır, yaratıkların içinden geçer.",
    ("Elara", "E"): "6 sn saldırı hızı artışı.",
    ("Elara", "R"): "Saldırılar iki kez tetiklenir.",
    ("Korsan", "P"): "Öldürme başına altın; altın saldırı gücüne döner.",
    ("Korsan", "Q"): "Görüşteki bütün saatli bombaları patlatır.",
    ("Korsan", "E"): "Bulunduğu yere saatli bomba bırakır.",
    ("Korsan", "R"): "Geniş bir alanı top ateşiyle döver.",
    ("Melek", "P"): "Kendisinin ve yakındaki dostların kalkanını yeniler.",
    ("Melek", "Q"): "Kendine ve dostuna can basar.",
    ("Melek", "E"): "Kendine ve dostuna kalkan basar.",
    ("Melek", "R"): "Kanatlanıp parlar, yaratıkları itip korkutur.",
    ("Necromancer", "P"): "Ölen düşmanlardan ruh biriktirir.",
    ("Necromancer", "Q"): "Ruh harcayıp iskelet çağırır.",
    ("Necromancer", "E"): "Ruh harcayıp golem çağırır.",
    ("Necromancer", "R"): "Etrafında dönen lanetli kafatası, ultide büyür.",
    ("Shaman", "P"): "Totem yakınındaki dostların vuruşları yakar.",
    ("Shaman", "Q"): "Düşmana ateş eden saldırı totemi.",
    ("Shaman", "E"): "Dostlara kalkan veren totem.",
    ("Shaman", "R"): "20 sn dev bir elemental goleme dönüşür.",
    ("Vampir Çocuk", "P"): "Can emme kazanır, saldırı gücü kadar azami can.",
    ("Vampir Çocuk", "Q"): "En yakın 4 düşmanın kanını emer.",
    ("Vampir Çocuk", "E"): "Yarasaya dönüşüp hızlanır.",
    ("Vampir Çocuk", "R"): "Düşmanlara küçük kan yarasaları gönderir.",
    ("Hadime", "P"): "Düşünce hayalet olarak savaşmaya devam eder.",
    ("Hadime", "Q"): "Kitap okuyup etrafa lanet fırlatır (aç/kapa).",
    ("Hadime", "E"): "Yaratıkları içine çeken kara delik.",
    ("Hadime", "R"): "Korku saçan Karabasan formuna bürünür.",
    ("Cadı", "P"): "Eksik canı arttıkça şans kazanır.",
    ("Cadı", "Q"): "Arkasında zehirli duman bırakır (aç/kapa).",
    ("Cadı", "E"): "Süpürgeye biner, dostlarını da taşır.",
    ("Cadı", "R"): "Rastgele iksir fırlatır, 5 yük.",
}


# 2. tur (kullanıcı "hiçbiri, başka bak" dedi): no -> yeni adaylar (seçim kimliği d, e, f...)
TUR2 = {
    15: ["WAR-C5", "WAR-C4", "WAR-B8", "AER-B7", "WAR-D4", "AER-D2"],
    # 3. tur adayları listenin sonuna eklenir (kimlikler j, k... olur; eski kimlikler kaymaz)
    16: ["CRY-B4", "CRY-B3", "CRY-C4", "CRY-D2", "CRY-E3", "CRY-B6",
         "PAL-B6", "CRY-B5", "CRY-C8", "CRY-C5", "CRY-B8", "DM2-A5", "CRY-E4"],
    18: ["SUM-D5", "DRU-E2", "DRU-B3", "AER-E3", "ARC-C7", "DRU-B7",  # 3. tur: "dash temalı"
         "SWO-D7", "CRS-D3", "MON-F1", "BLD-D5", "SWO-F7", "SPE-F7", "MON-C7", "LIG-D2"],
    22: ["SWO-C5", "PAL-B8", "SPE-C5", "PAL-D6", "SWO-B2", "BAR-B8"],
    26: ["AER-E2", "BUF-E8", "THI-F6", "SWO-E3", "BUF-F2", "THI-B5"],
    33: ["PRI-D2", "BUF-F8", "PAL-B6", "PRI-C4", "PAL-A1", "PAL-F6"],
    35: ["DM1-E2", "BUF-E4", "PRI-E2", "PRI-F7", "BUF-A6", "BUF-C6",  # 3. tur: "sihir odaklı"
         "AER-F7", "AER-B8", "BUF-C8", "WAR-F2", "PAL-F6", "AER-A5", "PAL-D1", "MON-F6"],
    41: ["PYR-C8", "PYR-E7", "PYR-F5", "PYR-B4", "DM2-F6", "PYR-D2"],
    43: ["EAR-E8", "DRU-F8", "SUM-B7", "DRU-D7", "BUF-E2"],
    45: ["BLD-A7", "BLD-D7", "BLD-C5", "BLD-C6", "UND-F4", "DEB-D7"],
    46: ["BLD-D2", "BLD-C2", "BLD-B5", "BLD-E2", "BLD-E4", "BLD-C7"],
    47: ["UND-F4"],  # kullanıcı: "pasifteki H'yi istiyorum" (45'in h'si)
    56: ["THI-B7", "DEB-E8", "UND-A5", "UND-E7", "DM1-C8", "PYR-D1"],
}
# 4. tur: hâlâ "hiçbiri" olan 18 ("dash temalı") ve 35 ("sihir odaklı"); listenin sonuna eklenir
TUR4 = {
    18: ["MON-C6", "MON-D3", "MON-E7", "SWO-F6", "SWO-D3", "THI-B6", "THI-C2", "THI-D5", "SPE-D4"],
    35: ["FAI-D2", "SUM-E7", "AER-A3", "PRI-B1", "PRI-A4", "FAI-C6", "SUM-D8", "FAI-E2", "PRI-C3"],
}
# tur numarası: kartın EN SON turdaki adayları "yeni", öncekiler "önceki tur"
ROUND3_START = {16: 6, 18: 6, 35: 6}  # TUR2 listesinde 3. turun başladığı sıra
NEW_IDS = list("defghijklmnopqrstuvwxyz") + ["za", "zb", "zc", "zd", "ze"]


# 5. tur: kullanıcı "Matthew R için başka alternatifler öner" (doğal sarı-turuncu ya da kalkan/kafes biçimli)
TUR5 = {
    12: ["LIG-A4", "LIG-A5", "LIG-D8", "LIG-C2", "LIG-C3", "LIG-E3", "PRI-D1", "LIG-B6"],
}


# 6. tur: kullanıcı "Büyücü Kız'ın yetenek varyantları, Shaman ulti sonrası skilleri, Cadı iksirlerinin her birinin
# kendi simgesi" -> ayrı kartlar (no 57+). (no, karakter, yuva, yetenek, mevcut dosya, a, b, c, [ekler], açıklama)
VARYANT = [
    (57, "Büyücü Kız", "E", "Hortum (2. set)", "buyucu_skill_hortum_icon", "AER-D2", "EAR-B8", "LIG-A6",
     ["PYR-B4", "PYR-B3", "AER-B3", "AER-B4"], "2. sette E: etrafında dönen hortum."),
    (58, "Büyücü Kız", "R", "Meteor Patlaması (2. set)", "buyucu_skill_meteor_icon", "EAR-F8", "WAR-C3", "PYR-B8",
     ["PYR-D7", "DM1-A8", "PYR-B7", "DM2-A4"], "2. sette R: kanal sonrası göktaşı düşer."),
    (59, "Shaman", "Q", "Sarsıcı Darbe (golem)", "shaman_sarsici_darbe_icon", "EAR-C1", "EAR-A2", "EAR-B5",
     ["EAR-C7", "EAR-F3", "EAR-E7", "ORC-A2"], "Golem formunda Q: yere darbe, sersemletir."),
    (60, "Shaman", "E", "Golem Sıçrayışı (golem)", "shaman_golem_sicrayisi_icon", "EAR-E1", "EAR-D4", "EAR-C3",
     ["EAR-B7", "EAR-C8", "EAR-F1", "EAR-C4"], "Golem formunda E: ileri sıçrar, düştüğü yerde yaratıkları çeker."),
    (61, "Cadı", "R", "Delilik İksiri", "cadi_iksir_1_icon", "UND-E7", "FAI-D6", "DM1-C5", ["WAR-E5"],
     "Yaratıklar 4 sn birbirine saldırır."),
    (62, "Cadı", "R", "Don İksiri", "cadi_iksir_2_icon", "DEB-F8", "CRY-B8", "CRY-D3", ["WAR-E5"],
     "2 sn dondurur, saldırı gücü kadar hasar."),
    (63, "Cadı", "R", "Patlama İksiri", "cadi_iksir_3_icon", "PYR-D1", "DM1-E7", "PIR-E1", ["WAR-E5"],
     "Alan açmaz, %200 hasarla patlar."),
    (64, "Cadı", "R", "Şifa İksiri", "cadi_iksir_4_icon", "BLD-D7", "UND-A5", "DEB-E8", ["WAR-E5"],
     "Üstündeki dostlar saniyede %20 can yeniler."),
    (65, "Cadı", "R", "Korku İksiri", "cadi_iksir_5_icon", "PIR-F8", "DM1-C2", "UND-E1", ["WAR-E5"],
     "2 sn korkutur, saldırı gücü kadar hasar."),
    (66, "Cadı", "R", "Kalkan İksiri", "cadi_iksir_6_icon", "SUM-E7", "BUF-C8", "ARC-D7", ["WAR-E5"],
     "Üstündeki dostlar saniyede %25 mana kalkanı yeniler."),
]


# 7. tur: iksirler (61-66) kullanıcının Transperent klasöründen AYRI sayfada seçiliyor (iksir_sayfa.py) -> ana sayfada yok
IKSIR_AYRI = {61, 62, 63, 64, 65, 66}


def variant_rows(include_potions=False):
    return [{"no": no, "karakter": k, "yuva": y, "yetenek": n, "mevcut": m, "oneri": a, "b": b, "c": c, "ekler": ex, "desc_v": d}
            for (no, k, y, n, m, a, b, c, ex, d) in VARYANT if include_potions or no not in IKSIR_AYRI]


def new_candidates(no):
    """[(anahtar, tur)] - TUR2 (2. + 3. tur), ardından TUR4, TUR5."""
    out = []
    for i, key in enumerate(TUR2.get(no, [])):
        out.append((key, 3 if i >= ROUND3_START.get(no, 99) else 2))
    out += [(key, 4) for key in TUR4.get(no, [])]
    out += [(key, 5) for key in TUR5.get(no, [])]
    for v in VARYANT:
        if v[0] == no:
            out += [(key, 6) for key in v[8]]
    return out


def current_icon(name):
    cur = Image.open(os.path.join(K.ROOT, "assets", "skills", name + ".png")).convert("RGBA")
    cur.thumbnail((CELL, CELL), Image.NEAREST if max(cur.size) < 200 else Image.LANCZOS)
    if max(cur.size) < CELL:
        k = CELL // max(cur.size)
        cur = cur.resize((cur.width * k, cur.height * k), Image.NEAREST) if k > 1 else cur.resize((CELL, CELL), Image.NEAREST)
    return cur


def main():
    import renk_ayar as R
    out = os.path.join(HERE, "out", "sayfa")
    os.makedirs(out, exist_ok=True)
    rows = json.load(open(os.path.join(HERE, "out", "secim.json"), encoding="utf-8"))
    vrows = variant_rows()
    # varyant kartı kendi karakterinin son kartından hemen sonra gelsin
    for v in vrows:
        last = max(i for i, r in enumerate(rows) if r["karakter"] == v["karakter"])
        rows.insert(last + 1, v)
    icons = K.load_icons()
    for r in rows:
        opts = [{"id": "mevcut", "label": "şu an", "icon": r["mevcut"], "tag": "cur"},
                {"id": "a", "label": "a", "icon": r["oneri"], "tag": "rec"},
                {"id": "b", "label": "b", "icon": r["b"], "tag": ""},
                {"id": "c", "label": "c", "icon": r["c"], "tag": ""}]
        cands = new_candidates(r["no"])
        last = max((t for _, t in cands), default=0)
        for i, (key, rnd) in enumerate(cands):
            opts.append({"id": NEW_IDS[i], "label": NEW_IDS[i], "icon": key, "tag": "new" if rnd == last else "old"})
        if r["no"] in R.TON5:
            # 5. tur: yalnız ton döner (parlaklık/gölge korunur); eski bozuk *_renk seçenekleri gösterilmez
            for k, (base, desc, fn) in enumerate(R.TON5[r["no"]]):
                bkey = next(o["icon"] for o in opts if o["id"] == base)
                tkey = "%s+ton%d" % (bkey, k + 1)
                icons[tkey] = fn(icons[bkey].resize((144, 144), Image.LANCZOS))
                opts.append({"id": "%s_ton%d" % (base, k + 1), "label": base + " " + desc, "icon": tkey, "tag": "tint"})
        elif r["no"] in R.RENK:
            base, desc, fn = R.RENK[r["no"]]
            bkey = next(o["icon"] for o in opts if o["id"] == base)
            icons[bkey + "+renk"] = fn(icons[bkey].resize((CELL, CELL), Image.LANCZOS))
            opts.append({"id": base + "_renk", "label": base + " " + desc, "icon": bkey + "+renk", "tag": "tint"})
        for j, o in enumerate(opts):
            o["col"] = j
        r["opts"] = opts
        r["desc"] = r.pop("desc_v", None) or DESC[(r["karakter"], r["yuva"])]
        r.pop("ekler", None)
    for i, r in enumerate(rows):
        r["row"] = i  # sprite satırı (varyant kartları araya girdiği için no-1 DEĞİL)
    cols = max(len(r["opts"]) for r in rows)
    sheet = Image.new("RGB", (cols * CELL, len(rows) * CELL), (20, 14, 9))
    for i, r in enumerate(rows):
        for o in r["opts"]:
            if o["tag"] == "cur":
                cur = current_icon(o["icon"])
                sheet.paste(cur, ((CELL - cur.width) // 2, i * CELL + (CELL - cur.height) // 2), cur)
            else:
                sheet.paste(icons[o["icon"]].resize((CELL, CELL), Image.LANCZOS), (o["col"] * CELL, i * CELL))
    sheet.save(os.path.join(out, "ikonlar.webp"), "WEBP", quality=92, method=6)
    tpl = open(os.path.join(HERE, "sayfa_sablon.html"), encoding="utf-8").read()
    data = json.dumps({"cols": cols, "rows": rows}, ensure_ascii=False)
    open(os.path.join(out, "index.html"), "w", encoding="utf-8", newline="\n").write(tpl.replace("/*VERI*/{}", data))
    print("tamam", len(rows), os.path.getsize(os.path.join(out, "ikonlar.webp")) // 1024, "KB")


if __name__ == "__main__":
    main()
