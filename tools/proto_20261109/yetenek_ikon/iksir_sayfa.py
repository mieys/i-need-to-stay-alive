# Cadı R iksirleri için AYRI seçim sayfası (artifact RppeetXaj1fXqnDhorwENu).
# 7. tur: kullanıcı ~/Desktop/Transperent/Icon1..48'den iksir seçti (db secimler/s61..66).
# 8. tur: "arkaplanı yok, her iksire renk tonuna uygun sade bir arkaplan" -> iksir_zemin.py 3 stil x (1:1 / büyük);
# seçim artık db "zemin" koleksiyonunda (DATA.coll), kimlik = iksir_zemin.OPTIONS anahtarı.
# Kullanım: python -I iksir_sayfa.py
import os, sys, json
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import sayfa_hazirla as SH  # noqa: E402
import iksir_zemin as Z  # noqa: E402

CELL = 120
IKSIR = [
    (61, "cadi_iksir_1_icon", "Yaratıklar 4 sn birbirine saldırır."),
    (62, "cadi_iksir_2_icon", "2 sn dondurur, saldırı gücü kadar hasar."),
    (63, "cadi_iksir_3_icon", "Alan açmaz, %200 hasarla patlar."),
    (64, "cadi_iksir_4_icon", "Üstündeki dostlar saniyede %20 can yeniler."),
    (65, "cadi_iksir_5_icon", "2 sn korkutur, saldırı gücü kadar hasar."),
    (66, "cadi_iksir_6_icon", "Üstündeki dostlar saniyede %25 mana kalkanı yeniler."),
]
INTRO = ("Zeminler artık ikon paketinin KENDİ zeminleri (konusuz üç paket ikonu: ışın patlaması, ışık perdesi, ince ışınlar), "
         "yalnız tonu iksirin rengine döndürüldü; ışık deseni ve çerçeve paketinki. İksir öteki yetenek ikonlarındaki konular "
         "kadar büyük. 'konturlu' olanlarda iksirin etrafında paket ikonlarındaki gibi açık bir kontur var (koyu iksirleri öne "
         "çıkarır). Her iksir için birini seç; altısında aynı zemini seçersen tutarlı bir set olur.")


def main():
    out = os.path.join(HERE, "out", "iksir")
    os.makedirs(out, exist_ok=True)
    import ikon_secim as K
    icons = K.load_icons()
    rows, tiles = [], []
    for i, (no, cur, desc) in enumerate(IKSIR):
        name, n = Z.SECIM[no]
        opts = [{"id": "mevcut", "label": "şu an", "icon": cur, "tag": "cur", "col": 0}]
        row_tiles = [None]
        for j, (oid, (tmpl, outline, label)) in enumerate(Z.OPTIONS):
            opts.append({"id": oid, "label": label, "icon": "Icon%d+%s" % (n, oid),
                         "tag": "rec" if oid == "pric2_k" else "new", "col": j + 1})
            row_tiles.append(Z.compose_pack(no, icons, tmpl, outline))
        rows.append({"no": no, "row": i, "karakter": "Cadı", "yuva": "R", "yetenek": "%s (Icon%d)" % (name, n),
                     "mevcut": cur, "desc": desc, "opts": opts})
        tiles.append(row_tiles)
    cols = len(Z.OPTIONS) + 1
    sheet = Image.new("RGBA", (cols * CELL, len(rows) * CELL), (0, 0, 0, 0))
    for r, row_tiles in zip(rows, tiles):
        y = r["row"] * CELL
        cur = SH.current_icon(r["mevcut"])
        sheet.paste(cur, ((CELL - cur.width) // 2, y + (CELL - cur.height) // 2), cur)
        for c, t in enumerate(row_tiles[1:], start=1):
            big = t.resize((96, 96), Image.NEAREST)  # 48 x2
            sheet.paste(big, (c * CELL + 12, y + 12), big)
    sheet.save(os.path.join(out, "ikonlar.webp"), "WEBP", lossless=True, method=6)
    tpl = open(os.path.join(HERE, "sayfa_sablon.html"), encoding="utf-8").read()
    tpl = tpl.replace("<title>Yetenek İkonu Seçimi</title>", "<title>Cadı İksir Simgeleri</title>")
    tpl = tpl.replace("<h1>Yetenek İkonu Seçimi</h1>", "<h1>Cadı İksir Simgeleri</h1>")
    data = json.dumps({"cols": cols, "rows": rows, "mode": "iksir", "intro": INTRO, "coll": "zemin"}, ensure_ascii=False)
    open(os.path.join(out, "index.html"), "w", encoding="utf-8", newline="\n").write(tpl.replace("/*VERI*/{}", data))
    print("tamam", len(rows), os.path.getsize(os.path.join(out, "ikonlar.webp")) // 1024, "KB")


if __name__ == "__main__":
    main()
