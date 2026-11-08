#!/usr/bin/env python
# BUYUK TEST raporu: buyuk_test.gd gunluklerini okur, aykiri degerleri isaretler, inceleme icin gorsel sayfalar uretir.
#   python -I tools/buyuk_test/rapor.py <etiket>      (ornek: tam1)  -> out/<etiket>/RAPOR.md + out/<etiket>/sayfa_*.jpg
import os, re, sys, statistics, collections
from PIL import Image, ImageDraw

LABEL = sys.argv[1] if len(sys.argv) > 1 else "tam1"
BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out", LABEL)

CHAR_NAMES = {1: "Talon", 2: "Oakley", 3: "Matthew", 4: "Buyucu Kiz", 5: "Assasin", 7: "Sovalye", 8: "Elara", 9: "Korsan",
              10: "Melek", 11: "Necromancer", 12: "Shaman", 13: "Vampir", 14: "Hadime", 15: "Cadi"}
KV = re.compile(r"(\w+)=([^\s|]+)")
UID_WARN = re.compile(r"invalid UID")


def read(name):
    p = os.path.join(BASE, name)
    if not os.path.exists(p):
        return []
    return open(p, encoding="utf-8", errors="replace").read().splitlines()


def kv(line):
    return {k: v for k, v in KV.findall(line)}


def frame_stats(line):
    m = re.search(r"mean=([\d.]+) p50=([\d.]+) p95=([\d.]+) max=([\d.]+)", line)
    return tuple(float(x) for x in m.groups()) if m else (0, 0, 0, 0)


def engine_errors(lines):
    """Motor ERROR/WARNING satirlari, son 'BT >>' isaretine bagli. UID uyarilari ayri sayilir."""
    out, uid, marker = [], 0, "(baslangic)"
    for i, ln in enumerate(lines):
        if ln.startswith("BT >>"):
            marker = ln[6:].strip()
        elif ln.startswith(("ERROR:", "SCRIPT ERROR:", "WARNING:", "USER ERROR:", "USER WARNING:")):
            if UID_WARN.search(ln):
                uid += 1
                continue
            at = lines[i + 1].strip() if i + 1 < len(lines) and lines[i + 1].startswith("   ") else ""
            out.append((marker, ln.strip(), at))
    return out, uid


def err_key(s):
    return re.sub(r"\d+(\.\d+)?|0x[0-9a-f]+|<[^>]*>", "#", s)[:170]


def sheet(tiles, cols, tw, th, path, labels=None):
    rows = (len(tiles) + cols - 1) // cols
    img = Image.new("RGB", (cols * tw, rows * th), (24, 24, 28))
    d = ImageDraw.Draw(img)
    for i, t in enumerate(tiles):
        x, y = (i % cols) * tw, (i // cols) * th
        if t and os.path.exists(t):
            im = Image.open(t).convert("RGB").resize((tw, th), Image.LANCZOS)
            img.paste(im, (x, y))
        else:
            d.rectangle([x, y, x + tw - 1, y + th - 1], outline=(160, 40, 40))
            d.text((x + 6, y + 6), "GORUNTU YOK", fill=(220, 80, 80))
        if labels:
            lab = labels[i]
            d.rectangle([x, y, x + 8 * len(lab) + 6, y + 13], fill=(0, 0, 0))
            d.text((x + 3, y + 1), lab, fill=(255, 235, 140))
    img.save(path, quality=88)


def main():
    rep = ["# Buyuk test raporu (%s)\n" % LABEL]
    flags = []

    # ---------- data ----------
    data = read("data.log")
    rep.append("## 1. Veri tutarliligi (data)\n")
    drows = [l[8:] for l in data if l.startswith("BT DATA ")]
    infos = [l[12:] for l in data if l.startswith("BT DATAINFO ")]
    rep.append("Isaretlenen: %d  | bilgi: %d\n" % (len(drows), len(infos)))
    for r in drows:
        rep.append("- " + r)
    de, uid = engine_errors(data)
    rep.append("\nMotor hata/uyari (data): %d, gecersiz UID uyarisi: %d\n" % (len(de), uid))

    # ---------- wt ----------
    wt = read("wt.log")
    cfg = {}
    for l in wt:
        if l.startswith("BT CFG wt"):
            d = kv(l.split("|")[0])
            cfg[(d["w"], int(d["t"]))] = dict(dps=float(d["dps"]), glow=int(d["glow"]), vis=d["vis"], nodes_d=int(d["nodes_d"]), fs=frame_stats(l))
        elif l.startswith("BT FAIL") or l.startswith("BT BOOTFAIL") or l.startswith("BT TIMEOUT"):
            flags.append("wt: " + l)
    rep.append("\n## 2. Silah x kademe (wt)\n")
    rep.append("Yapilandirma: %d / 114\n" % len(cfg))
    rep.append("| silah | t1 | t2 | t3 | t4 | t5 | t6(+5) | t5/t1 | not |\n|---|---|---|---|---|---|---|---|---|")
    weapons = sorted({w for (w, t) in cfg})
    for w in weapons:
        ds = [cfg.get((w, t), {}).get("dps") for t in range(1, 7)]
        note = []
        for t in range(1, 7):
            c = cfg.get((w, t))
            if not c:
                continue
            if c["dps"] <= 0.5:
                note.append("t%d HASAR 0" % t)
            if c["glow"] != min(t, 5):
                note.append("t%d konturu %d" % (t, c["glow"]))
            if c["vis"] != "true":
                note.append("t%d gorunmez" % t)
        v = [x for x in ds if x is not None]
        ratio = (ds[4] / ds[0]) if ds[0] and ds[4] else 0
        if ds[0] and ds[4] and (ratio < 1.15 or ratio > 2.3):
            note.append("t5/t1 sapma %.2f" % ratio)
        for a, b, n in ((0, 4, "t1>t5"),):
            if ds[a] and ds[b] and ds[b] < ds[a]:
                note.append("t5 < t1 !")
        rep.append("| %s | %s | %.2f | %s |" % (w, " | ".join("%.0f" % x if x is not None else "-" for x in ds), ratio, "; ".join(note)))
        if note:
            flags.append("wt %s: %s" % (w, "; ".join(note)))
    e_wt, uid = engine_errors(wt)
    rep.append("\nMotor hata/uyari (wt): %d (gecersiz UID: %d)\n" % (len(e_wt), uid))
    p95s = [c["fs"][2] for c in cfg.values() if c["fs"][2] > 0]
    if p95s:
        med = statistics.median(p95s)
        slow = [(k, c["fs"]) for k, c in cfg.items() if c["fs"][2] > 2.0 * med or c["fs"][3] > 40]
        rep.append("Kare suresi (p95 ortanca %.2f ms) - sapmalar: %s\n" % (med, "; ".join("%s t%d p95=%.1f max=%.0f" % (k[0], k[1], f[2], f[3]) for k, f in slow) or "yok"))

    # ---------- ch ----------
    ch = read("ch.log")
    rep.append("\n## 3. Karakter yetenekleri (ch)\n")
    rep.append("| karakter | slot | durum gecisi | bekleme | dps | taban dps | fark | kare p95 |\n|---|---|---|---|---|---|---|---|")
    idle = {}
    for l in ch:
        if l.startswith("BT CHIDLE"):
            d = kv(l.split("|")[0])
            idle[int(d["c"])] = d
            if "false" in l.split("unlocked=")[1].split("|")[0]:
                flags.append("ch %s: kilitli slot var %s" % (CHAR_NAMES.get(int(d["c"]), d["c"]), l.split("unlocked=")[1].split("|")[0].strip()))
        elif l.startswith("BT CAST"):
            d = kv(l.split("|")[0])
            c = int(d["c"])
            st = d["st"]
            fs = frame_stats(l)
            dps, base = float(d["dps"]), float(d["base_dps"])
            note = ""
            parts = st.split(">")
            if len(parts) >= 2 and parts[0] == parts[1] == "ready":
                note = " DURUM DEGISMEDI"
                flags.append("ch %s %s: basinca durum 'ready' kaldi (%s)" % (CHAR_NAMES.get(c, c), d["slot"], st))
            rep.append("| %s | %s | %s%s | %s | %.0f | %.0f | %+.0f | %.1f |" % (CHAR_NAMES.get(c, c), d["slot"], st, note, d["timer"], dps, base, dps - base, fs[2]))
        elif l.startswith(("BT FAIL", "BT BOOTFAIL", "BT TIMEOUT")):
            flags.append("ch: " + l)
    e_ch, uid = engine_errors(ch)
    rep.append("\nMotor hata/uyari (ch): %d (UID: %d)\n" % (len(e_ch), uid))

    # ---------- crowd ----------
    cr = read("crowd.log")
    rep.append("\n## 4. Kademe kalabaligi (crowd)\n")
    rep.append("| kademe | yakin | dugum | mean | p95 | max |\n|---|---|---|---|---|---|")
    for l in cr:
        if l.startswith("BT CROWD"):
            d = kv(l.split("|")[0])
            fs = frame_stats(l)
            rep.append("| %s | %s | %s | %.1f | %.1f | %.0f |" % (d["tier"], d["near"], d["nodes"], fs[0], fs[2], fs[3]))
            if fs[2] > 25:
                flags.append("crowd K%s: p95 %.1f ms (yavas)" % (d["tier"], fs[2]))
        elif l.startswith("BT BOSS"):
            d = kv(l.split("|")[0])
            fs = frame_stats(l)
            rep.append("| K%s BOSS %s | boss_nodes=%s | | %.1f | %.1f | %.0f |" % (d["tier"], d["id"], d["boss_nodes"], fs[0], fs[2], fs[3]))
            if d["boss_nodes"] == "0":
                flags.append("crowd K%s: boss dogmadi" % d["tier"])
        elif l.startswith(("BT FAIL", "BT BOOTFAIL", "BT TIMEOUT")):
            flags.append("crowd: " + l)
    e_cr, uid = engine_errors(cr)
    rep.append("\nMotor hata/uyari (crowd): %d (UID: %d)\n" % (len(e_cr), uid))

    # ---------- cw ----------
    cw = read("cw.log")
    rows = collections.defaultdict(dict)
    for l in cw:
        if l.startswith("BT CFG cw"):
            d = kv(l.split("|")[0])
            rows[d["w"]][int(d["c"])] = (float(d["dps"]), frame_stats(l))
        elif l.startswith(("BT FAIL", "BT BOOTFAIL", "BT TIMEOUT")):
            flags.append("cw: " + l)
    rep.append("\n## 5. Karakter x silah (cw), kademe 1\n")
    ap = {1: 16, 2: 11, 3: 10, 4: 12, 5: 14, 7: 8, 8: 10, 9: 12, 10: 12, 11: 12, 12: 11, 13: 12, 14: 12, 15: 10}
    rep.append("Yapilandirma: %d / 266. Sapma = karakterin AP'ye bolunmus dps'i, silahin ortanca degerinden <%%35 ya da 0.\n" % sum(len(v) for v in rows.values()))
    for w, cs in sorted(rows.items()):
        norm = {c: v[0] / ap.get(c, 10) for c, v in cs.items()}
        med = statistics.median(norm.values()) if norm else 0
        bad = [(c, norm[c]) for c in norm if med > 0 and (norm[c] < 0.35 * med or norm[c] == 0)]
        if bad:
            rep.append("- %s: ortanca %.1f dps/AP; sapan: %s" % (w, med, ", ".join("%s=%.1f" % (CHAR_NAMES.get(c, c), n) for c, n in bad)))
            flags.append("cw %s: %s" % (w, ", ".join("%s dusuk (%.1f vs %.1f)" % (CHAR_NAMES.get(c, c), n, med) for c, n in bad)))
    e_cw, uid = engine_errors(cw)
    rep.append("\nMotor hata/uyari (cw): %d (UID: %d)\n" % (len(e_cw), uid))

    # ---------- motor hatalari toplu ----------
    agg = collections.defaultdict(lambda: [0, set(), ""])
    for src, errs in (("data", de), ("wt", e_wt), ("ch", e_ch), ("crowd", e_cr), ("cw", e_cw)):
        for marker, text, at in errs:
            a = agg[err_key(text)]
            a[0] += 1
            a[1].add(src + ":" + marker)
            a[2] = a[2] or ("%s | %s" % (text[:230], at))
    rep.append("\n## 6. Motor hata / uyarilari (tekilleştirilmiş)\n")
    if not agg:
        rep.append("Hic motor hatasi/uyarisi yok (gecersiz UID uyarilari haric).")
    for k, (n, where, sample) in sorted(agg.items(), key=lambda x: -x[1][0]):
        rep.append("- x%d  %s  ( %s )" % (n, sample, "; ".join(sorted(where)[:3])))
        flags.append("motor hatasi x%d: %s" % (n, sample[:160]))

    # ---------- gorsel sayfalar ----------
    def tile(mode, name):
        return os.path.join(BASE, mode, name + ".jpg")

    pages = []
    ws = weapons
    for pi in range(0, len(ws), 5):
        grp = ws[pi:pi + 5]
        tiles, labs = [], []
        for w in grp:
            for t in (1, 3, 5, 6):
                tiles.append(tile("wt", "wt_%s_t%d_a" % (w, t)))
                labs.append("%s t%d" % (w, t))
        p = os.path.join(BASE, "sayfa_silah_%d.jpg" % (pi // 5 + 1))
        sheet(tiles, 4, 400, 225, p, labs)
        pages.append(p)
    chars = sorted(idle) or sorted({int(m.group(1)) for m in (re.search(r"ch_c(\d+)_", f) for f in os.listdir(os.path.join(BASE, "ch")) if os.path.isdir(os.path.join(BASE, "ch"))) if m})
    for pi in range(0, len(chars), 4):
        grp = chars[pi:pi + 4]
        tiles, labs = [], []
        for c in grp:
            for s in ("idle", "skill_a", "skill2_a", "skill3_a"):
                tiles.append(tile("ch", "ch_c%d_%s" % (c, s)))
                labs.append("%s %s" % (CHAR_NAMES.get(c, c), s))
        p = os.path.join(BASE, "sayfa_karakter_%d.jpg" % (pi // 4 + 1))
        sheet(tiles, 4, 400, 225, p, labs)
        pages.append(p)
    tiles = [tile("crowd", "crowd_t%02d" % t) for t in range(1, 16)]
    p = os.path.join(BASE, "sayfa_kalabalik.jpg")
    sheet(tiles, 3, 640, 360, p, ["K%d" % t for t in range(1, 16)])
    pages.append(p)
    tiles = [tile("crowd", "crowd_t%02d_boss" % t) for t in (3, 5, 8, 12, 15)]
    p = os.path.join(BASE, "sayfa_boss.jpg")
    sheet(tiles, 3, 640, 360, p, ["K%d boss" % t for t in (3, 5, 8, 12, 15)])
    pages.append(p)
    for c in sorted({c for v in rows.values() for c in v}):
        tiles = [tile("cw", "cw_c%d_%s" % (c, w)) for w in sorted(rows)]
        p = os.path.join(BASE, "sayfa_cw_%02d_%s.jpg" % (c, CHAR_NAMES.get(c, c)))
        sheet(tiles, 5, 320, 180, p, [w for w in sorted(rows)])
        pages.append(p)

    rep.append("\n## Gorsel sayfalar\n")
    for p in pages:
        rep.append("- " + os.path.basename(p))
    rep.insert(1, "## ISARETLENENLER (%d)\n" % len(flags) + "\n".join("- " + f for f in flags) + "\n")
    open(os.path.join(BASE, "RAPOR.md"), "w", encoding="utf-8").write("\n".join(rep))
    print("RAPOR:", os.path.join(BASE, "RAPOR.md"), "isaret:", len(flags), "sayfa:", len(pages))


main()
