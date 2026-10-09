#!/usr/bin/env python3
"""Boss yakalama denetimi (run_audit.ps1 -Mode bosscatchup) sonuç karşılaştırması: python tools/mp_audit/boss_catchup_audit_compare.py <klasör>

İstemci oyun sürerken bağlantıyı kesti ve yeniden katıldı. Son (eşzamanlı) anlık görüntüde host'un ve yeniden katılan istemcinin bossları + uzuvları karşılaştırılır:
boss kimliği/statları/boss bayrağı/Kademe/konum/can+kalkan, uzuvların kümesi (ağ kimliği), türü, konumu, pozu, gömülme (hedeflenemez) durumu."""
import json
import os
import sys

d = sys.argv[1]
host = json.load(open(os.path.join(d, "host.json")))
cli = json.load(open(os.path.join(d, "client.json")))
print("host olayları:", [e for e in host["events"]])
print("istemci olayları:", [e["e"] for e in cli["events"]])
hs = next((s for s in host["snaps"] if s["label"] == "sync_end"), None)
cs = next((s for s in cli["snaps"] if s["label"] == "sync_end"), None)
if hs is None or cs is None:
    print("EŞZAMANLI ANLIK GÖRÜNTÜ YOK (host=%s istemci=%s) - istemci yeniden katılamadı mı?" % (hs is not None, cs is not None))
    sys.exit(1)
print("anlık görüntü zaman farkı: %.2f sn" % abs(hs["t"] - cs["t"]))
bad = 0

hb = {v["id"]: v for v in hs["bosses"].values()}
cb = {v["id"]: v for v in cs["bosses"].values()}
print("bosslar: host %s | istemci %s" % (sorted(hb), sorted(cb)))
for cid, h in hb.items():
    c = cb.get(cid)
    if c is None:
        print("  EKSİK: istemcide %s yok" % cid)
        bad += 1
        continue
    dx = ((h["x"] - c["x"]) ** 2 + (h["y"] - c["y"]) ** 2) ** 0.5
    pool_h = h["health"] + h["shield"]
    pool_c = c["health"] + c["shield"]
    print("  %-12s max can %.0f/%.0f  max kalkan %.0f/%.0f  soğurma %.2f/%.2f  boss=%s/%s kademe %d/%d  havuz %.0f/%.0f (fark %.0f)  konum farkı %.0f px"
          % (cid, h["max_health"], c["max_health"], h["shield_max"], c["shield_max"], h["protection"], c["protection"], h["is_boss"], c["is_boss"], h["tier"], c["tier"], pool_h, pool_c, abs(pool_h - pool_c), dx))
    for k in ("max_health", "shield_max", "protection", "is_boss", "tier"):
        if h[k] != c[k]:
            print("    FARKLI: %s host %s istemci %s" % (k, h[k], c[k]))
            bad += 1

hl, cl = hs["limbs"], cs["limbs"]
only_h = sorted(set(hl) - set(cl))
only_c = sorted(set(cl) - set(hl))
both = sorted(set(hl) & set(cl))
print("uzuvlar: host %d, istemci %d, ortak %d, yalnız host'ta %s, yalnız istemcide %s" % (len(hl), len(cl), len(both), only_h, only_c))
pos_err = pose_bad = kind_bad = hide_bad = 0
for nid in both:
    h, c = hl[nid], cl[nid]
    pos_err = max(pos_err, ((h[0] - c[0]) ** 2 + (h[1] - c[1]) ** 2) ** 0.5)
    pose_bad += 1 if h[2] != c[2] else 0
    kind_bad += 1 if h[3] != c[3] else 0
    hide_bad += 1 if h[5] != c[5] else 0
print("ortak uzuvlarda: en büyük konum farkı %.1f px, poz farkı %d, tür farkı %d, gömülme farkı %d" % (pos_err, pose_bad, kind_bad, hide_bad))
if kind_bad:
    bad += 1
if len(only_h) + len(only_c) > 1:
    bad += 1
print("SONUÇ: %s" % ("TEMİZ" if bad == 0 else "SORUN VAR (%d)" % bad))
