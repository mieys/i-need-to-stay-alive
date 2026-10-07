import json, sys, math, statistics, collections

d = sys.argv[1]
H = json.load(open(d + "/host.json", encoding="utf-8"))
C = json.load(open(d + "/client.json", encoding="utf-8"))


def nearest(snaps, t, tol=0.45):
    best = None
    bd = 1e9
    for s in snaps:
        dt = abs(s["t"] - t)
        if dt < bd:
            bd = dt
            best = s
    return best if bd <= tol else None


def pct(a, p):
    a = sorted(a)
    return a[min(len(a) - 1, int(len(a) * p))] if a else float("nan")


print("== olaylar (host)")
for e in H["events"]:
    print("  ", e)
print("== olaylar (istemci)")
for e in C["events"]:
    print("  ", e)

for name, A, B in (("HOST gerçek -> istemcideki kukla", H, C), ("İSTEMCİ gerçek -> host'taki kukla", C, H)):
    print("==", name)
    pos_err, mism = [], collections.Counter()
    anim_pairs = collections.Counter()
    n = 0
    for s in A["snaps"]:
        o = s["own"]
        t = nearest(B["snaps"], s["t"])
        if not t or not t["pup"] or not o:
            continue
        p = t["pup"]
        n += 1
        pos_err.append(math.dist(o["pos"], p["pos"]))
        if o["anim"] != p["anim"]:
            mism["anim"] += 1
            anim_pairs[(o["anim"], p["anim"])] += 1
        for k in ("hp", "max", "sh", "shm"):
            if abs(o[k] - p[k]) > 2.0 and not (k in ("hp", "max") and (o[k] > 1e8 or p[k] > 1e8)):
                mism[k] += 1
        if o["wk"] != p["wk"]:
            mism["weapon_keys"] += 1
        for k in ("indoors", "inv", "downed", "dead"):
            if o[k] != p[k]:
                mism[k] += 1
    print("  eşleşen örnek:", n, " konum hatası ort=%.1f p95=%.1f maks=%.1f px" % (statistics.mean(pos_err) if pos_err else -1, pct(pos_err, 0.95), max(pos_err) if pos_err else -1))
    print("  uyuşmazlık sayıları:", dict(mism))
    if anim_pairs:
        print("  en sık animasyon farkları (gerçek, kukla):", anim_pairs.most_common(6))
    # silah anahtarları son hali
    if A["snaps"]:
        print("  son silahlar gerçek:", A["snaps"][-1]["own"].get("wk"), " kukla:", (nearest(B["snaps"], A["snaps"][-1]["t"]) or {}).get("pup", {}).get("wk"))

print("== yaratıklar (host gerçek vs istemci kopya)")
miss, ghost, perr, hpd, deadm = 0, 0, [], [], 0
tot_h, tot_c, rows = 0, 0, 0
for s in H["snaps"]:
    t = nearest(C["snaps"], s["t"])
    if not t:
        continue
    rows += 1
    he, ce = s["enemies"], t["enemies"]
    tot_h += len(he)
    tot_c += len(ce)
    for k, v in he.items():
        if k not in ce:
            if not v[3]:
                miss += 1
        else:
            perr.append(math.dist(v[:2], ce[k][:2]))
            if not v[3] and not ce[k][3]:
                hpd.append(abs(v[2] - ce[k][2]))
            if v[3] != ce[k][3]:
                deadm += 1
    for k, v in ce.items():
        if k not in he and not v[3]:
            ghost += 1
print("  örnek:", rows, " ort. yaratık host=%.1f istemci=%.1f" % (tot_h / max(rows, 1), tot_c / max(rows, 1)))
print("  istemcide EKSİK (canlı):", miss, " istemcide HAYALET (host'ta yok):", ghost, " ölü-bayrak uyuşmazlığı:", deadm)
print("  konum hatası ort=%.1f p95=%.1f maks=%.1f px" % (statistics.mean(perr) if perr else -1, pct(perr, 0.95), max(perr) if perr else -1))
print("  can farkı ort=%.1f p95=%.1f" % (statistics.mean(hpd) if hpd else -1, pct(hpd, 0.95)))

print("== drop sayıları (host: toplam/görsel kopya; istemci: toplam/görsel kopya) - son 6 örnek")
for s in H["snaps"][-6:]:
    t = nearest(C["snaps"], s["t"])
    if t:
        print("  ", {g: (s["drops"][g], t["drops"][g]) for g in s["drops"]})

print("== takım durumu (host vs istemci)")
for s in H["snaps"][::6]:
    t = nearest(C["snaps"], s["t"])
    if t:
        print("  host", s["team"], "| istemci", t["team"])
last_h, last_c = H["snaps"][-1]["team"], C["snaps"][-1]["team"]
print("  SON host  :", last_h)
print("  SON istem.:", last_c)
