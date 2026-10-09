#!/usr/bin/env python3
"""Köpek denetimi (run_audit.ps1 -Mode dog) sonuç karşılaştırması: python tools/mp_audit/dog_audit_compare.py <klasör>

host.json = gerçek köpek, client.json = istemcideki kozmetik kopya (aynı dünya koordinatları, süreçler ~0,1-0,3 sn farkla başlar).
Rapor: konum hatası (ortalama/p95/en çok; 0,25 sn'de bir örnek, istemci zaman kaydırması en iyi eşleşmeyle bulunur), ısırma klibi sayıları (host vs istemci),
istemcide walk/run/idle titremesi (saniyedeki klip geçişi, host ile karşılaştırmalı), host köpeğinin sahibinden uzaklığı (takip kalitesi)."""
import json
import math
import os
import sys

d = sys.argv[1]
host = json.load(open(os.path.join(d, "host.json")))
cli = json.load(open(os.path.join(d, "client.json")))


def pos_at(rows, t):
    best = min(rows, key=lambda r: abs(r[0] - t))
    return best


def err_for(shift):
    errs = []
    for r in host["pos"]:
        c = pos_at(cli["pos"], r[0] + shift)
        errs.append(math.hypot(r[1] - c[1], r[2] - c[2]))
    return errs


best_shift, best_errs = 0.0, err_for(0.0)
for s in [x * 0.05 for x in range(-8, 9)]:
    e = err_for(s)
    if sum(e) < sum(best_errs):
        best_shift, best_errs = s, e
best_errs_sorted = sorted(best_errs)
print("örnek: host %d konum, istemci %d konum; en iyi zaman kayması %.2f sn" % (len(host["pos"]), len(cli["pos"]), best_shift))
print("konum hatası px: ort %.1f  p95 %.1f  en çok %.1f" % (sum(best_errs) / len(best_errs), best_errs_sorted[int(len(best_errs) * 0.95) - 1], best_errs_sorted[-1]))

# takip kalitesi: host köpeği - host oyuncusu uzaklığı
dist = [math.hypot(r[1] - r[3], r[2] - r[4]) for r in host["pos"]]
print("host köpek-sahip uzaklığı px: ort %.0f  en çok %.0f  (yürürken/dururken)" % (sum(dist) / len(dist), max(dist)))


def clip_stats(tr, lo, hi):
    return [t for t in tr if lo <= t[0] < hi]


def count(tr, prefix):
    return sum(1 for t in tr if t[1].startswith(prefix))


print("ısırma klibi başlangıcı: host %d  istemci %d" % (count(host["trans"], "bite_"), count(cli["trans"], "bite_")))
for name, lo, hi in (("yürüyüş fazı 2-24 sn", 2.0, 24.0), ("savaş fazı 26-40 sn", 26.0, 40.0)):
    h = clip_stats(host["trans"], lo, hi)
    c = clip_stats(cli["trans"], lo, hi)
    print("%s: klip geçişi host %d (%.2f/sn)  istemci %d (%.2f/sn)" % (name, len(h), len(h) / (hi - lo), len(c), len(c) / (hi - lo)))
print("host klip dizisi (ilk 40):", [t[1] for t in host["trans"]][:40])
print("istemci klip dizisi (ilk 40):", [t[1] for t in cli["trans"]][:40])
# zigzag ölçüsü (savaş fazı 26-40 sn): ardışık 0,25 sn hareket vektörleri arasında > 110 derece dönüş sayısı ve toplam yol
pts = [(r[0], r[1], r[2]) for r in host["pos"] if 26.0 <= r[0] < 40.0]
rev = 0
path = 0.0
prev = None
for a, b in zip(pts, pts[1:]):
    v = (b[1] - a[1], b[2] - a[2])
    L = math.hypot(*v)
    path += L
    if prev is not None and L > 25 and math.hypot(*prev) > 25:
        cosang = (v[0] * prev[0] + v[1] * prev[1]) / (L * math.hypot(*prev))
        if cosang < math.cos(math.radians(110)):
            rev += 1
    if L > 25:
        prev = v
print("savaş fazı zigzag: ters dönüş %d, toplam yol %.0f px" % (rev, path))
print("olaylar:", host.get("events"))
