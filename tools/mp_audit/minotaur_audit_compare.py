#!/usr/bin/env python3
"""Minotaur denetimi (run_audit.ps1 -Mode minotaur) sonuç karşılaştırması: python tools/mp_audit/minotaur_audit_compare.py <klasör>

host.json = gerçek boss (host), client.json = istemcideki kukla + istemcinin KENDİ oyuncusu (hasar / savrulma / duvar).
Rapor: boss konum hatası (hücum süresince ve dışında; istemci zaman kayması en iyi eşleşmeyle bulunur), poz dizileri (host vs istemci), istemcide uyarı şeridi görüldü mü,
ağ hızı tavanı hücumda yükseldi mi, istemci oyuncusunun aldığı hasar + savrulma mesafeleri + duvara girip girmediği."""
import json
import math
import os
import sys

d = sys.argv[1]
host = json.load(open(os.path.join(d, "host.json")))
cli = json.load(open(os.path.join(d, "client.json")))
hs, cs = host["samples"], cli["samples"]
print("örnek: host %d, istemci %d | host olayları %d, istemci olayları %d" % (len(hs), len(cs), len(host["events"]), len(cli["events"])))
if not hs or not cs:
    print("BOŞ: boss doğmadı ya da istemci görmedi")
    sys.exit(1)


def nearest(rows, t):
    return min(rows, key=lambda r: abs(r[0] - t))


def errs_for(shift, only_charge=None):
    out = []
    for r in hs[::3]:
        if only_charge is not None and ((r[3] == 2) != only_charge):
            continue
        c = nearest(cs, r[0] + shift)
        out.append(math.hypot(r[1] - c[1], r[2] - c[2]))
    return out


## İki süreç farklı anlarda başlar: ilk "eğilme" (poz 1) olayından kaba kayma, sonra ±0,3 sn'de ağ gecikmesi için ince arama.
hp1 = [e["t"] for e in host["events"] if e["e"] == "pose" and e["pose"] == 1]
cp1 = [e["t"] for e in cli["events"] if e["e"] == "pose" and e["pose"] == 1]
coarse = (cp1[0] - hp1[0]) if hp1 and cp1 else 0.0
best_shift, best = coarse, errs_for(coarse)
for s in [coarse + x * 0.02 for x in range(-15, 16)]:
    e = errs_for(s)
    if e and sum(e) < sum(best):
        best_shift, best = s, e
print("kaba kayma (ilk poz-1 olayı) %.2f sn, ince arama sonrası %.2f sn (fark = ağ gecikmesi)" % (coarse, best_shift))


def stat(name, e):
    if not e:
        print("%s: örnek yok" % name)
        return
    e = sorted(e)
    print("%s: ort %.1f  p95 %.1f  en çok %.1f px (n=%d)" % (name, sum(e) / len(e), e[max(int(len(e) * 0.95) - 1, 0)], e[-1], len(e)))


print("en iyi zaman kayması %.2f sn" % best_shift)
stat("boss konum hatası (tümü)", best)
stat("  hücum (poz 2) süresince", errs_for(best_shift, True))
stat("  hücum dışında", errs_for(best_shift, False))

hp = [e["pose"] for e in host["events"] if e["e"] == "pose"]
cp = [e["pose"] for e in cli["events"] if e["e"] == "pose"]
print("poz dizisi host  :", hp)
print("poz dizisi istemci:", cp)
n = min(len(hp), len(cp))
print("poz dizileri ilk %d olayda %s" % (n, "AYNI" if hp[:n] == cp[:n] else "FARKLI"))
caps = [e["cap"] for e in cli["events"] if e["e"] == "pose" and e["pose"] == 2]
print("istemci hücumda ağ hızı tavanı:", sorted(set(caps)))
print("istemcide uyarı şeridi düğümü en çok: %d (host: %d)" % (max(r[5] for r in cs), max(r[5] for r in hs)))

boss_ev = [e for e in host["events"] if e["e"] == "boss_spawned"]
if boss_ev:
    print("boss: can %.0f kalkan %.0f" % (boss_ev[0]["hp"], boss_ev[0]["shield"]))

target_is_host = any(e["e"] == "host_damaged" for e in host["events"])
target_rows = hs if target_is_host else cs
dmg = [e for e in (host["events"] if target_is_host else cli["events"]) if e["e"] in ("client_damaged", "host_damaged")]
print("%s oyuncusu hasarları:" % ("HOST" if target_is_host else "istemci"), [(e["t"], e["amount"]) for e in dmg])
for e in dmg:
    t = e["t"]
    before = nearest(target_rows, t - 0.05)
    after = nearest(target_rows, t + 1.6)
    print("  t=%.2f: savrulma %.0f px (%.0f,%.0f) -> (%.0f,%.0f)" % (t, math.hypot(after[6] - before[6], after[7] - before[7]), before[6], before[7], after[6], after[7]))
print("istemci oyuncusu duvar hücresine girdi mi:", cli["wall_ever"], "(başlangıçta içindeydi: %s)" % cli["start_in_wall"])
