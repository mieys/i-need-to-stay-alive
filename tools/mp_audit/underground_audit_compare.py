#!/usr/bin/env python3
"""Yeraltı Canavarı denetimi (run_audit.ps1 -Mode underground) sonuç karşılaştırması: python tools/mp_audit/underground_audit_compare.py <klasör>

host.json = gerçek boss + uzuvlar (host), client.json = istemcideki kopyalar + istemcinin KENDİ oyuncusu. Rapor: uzuv sayısı eğrisi farkı, uzuv başına konum/poz/tür/can karşılaştırması
(ağ kimliğiyle eşleşir; uzuvlar hareket etmez, konum farkı ~0 olmalı), boss havuzunun (can+kalkan) iki tarafta tutarlılığı, asit damlası görselleri, iki oyuncunun aldığı hasar miktarları."""
import json
import os
import sys
from collections import Counter

d = sys.argv[1]
host = json.load(open(os.path.join(d, "host.json")))
cli = json.load(open(os.path.join(d, "client.json")))
hs, cs = host["samples"], cli["samples"]
print("örnek: host %d, istemci %d | uzuv kaydı: host %d, istemci %d" % (len(hs), len(cs), len(host["limbs"]), len(cli["limbs"])))


def first_limb_time(samples):
    for r in samples:
        if r[3] > 0:
            return r[0]
    return None


ht, ct = first_limb_time(hs), first_limb_time(cs)
if ht is None or ct is None:
    print("UZUV YOK: host ilk uzuv=%s istemci ilk uzuv=%s" % (ht, ct))
    sys.exit(1)
shift = ct - ht
print("ilk uzuv: host %.2f sn, istemci %.2f sn -> zaman kayması %.2f sn" % (ht, ct, shift))


def nearest(rows, t):
    return min(rows, key=lambda r: abs(r[0] - t))


diffs = [abs(r[3] - nearest(cs, r[0] + shift)[3]) for r in hs if r[0] >= ht]
print("yüzeydeki uzuv sayısı: host en çok %d, istemci en çok %d, ortalama |fark| %.2f" % (max(r[3] for r in hs), max(r[3] for r in cs), sum(diffs) / max(len(diffs), 1)))

# uzuv başına karşılaştırma
seen_host, matched, pos_err, pose_mism, kind_mism, total = set(), 0, 0.0, 0, 0, 0
for t, rec in host["limbs"]:
    c = nearest(cli["limbs"], t + shift)[1]
    for nid, v in rec.items():
        seen_host.add(nid)
        total += 1
        if nid in c:
            matched += 1
            cv = c[nid]
            pos_err = max(pos_err, ((v[0] - cv[0]) ** 2 + (v[1] - cv[1]) ** 2) ** 0.5)
            pose_mism += 1 if v[2] != cv[2] else 0
            kind_mism += 1 if v[3] != cv[3] else 0
print("host'ta görülen benzersiz uzuv: %d; kayıt başına istemcide bulunma %.1f%% (%d/%d)" % (len(seen_host), 100.0 * matched / max(total, 1), matched, total))
print("eşleşen uzuvlarda en büyük konum farkı %.2f px; poz farkı %d, tür farkı %d (0,5 sn örnekleme: geçişte birkaç fark normal)" % (pos_err, pose_mism, kind_mism))

# boss havuzu
pool_diffs = []
for r in hs:
    if r[1] < 0:
        continue
    c = nearest(cs, r[0] + shift)
    if c[1] >= 0:
        pool_diffs.append(abs((r[1] + r[2]) - (c[1] + c[2])))
if pool_diffs:
    pool_diffs.sort()
    print("boss havuzu (can+kalkan) iki tarafta: ort fark %.0f  p95 %.0f  en çok %.0f" % (sum(pool_diffs) / len(pool_diffs), pool_diffs[int(len(pool_diffs) * 0.95) - 1], pool_diffs[-1]))
first = next((r for r in hs if r[1] >= 0), None)
last = next((r for r in reversed(hs) if r[1] >= 0), None)
if first and last:
    print("boss havuzu host: başta %.0f -> sonda %.0f (azalan = uzuvlara vuruluyor)" % (first[1] + first[2], last[1] + last[2]))
lastc = next((r for r in reversed(cs) if r[1] >= 0), None)
if lastc:
    print("boss havuzu istemci: sonda %.0f" % (lastc[1] + lastc[2]))
print("asit damlası düğümü en çok: host %d, istemci %d" % (max(r[4] for r in hs), max(r[4] for r in cs)))

for name, data in (("host", host), ("istemci", cli)):
    ev = [e for e in data["events"] if e["e"] == "player_damaged"]
    cnt = Counter(round(e["amount"]) for e in ev)
    print("%s oyuncusu %d kez hasar aldı; miktarlar (yuvarlak): %s | duvar hücresine girdi: %s" % (name, len(ev), dict(cnt.most_common(8)), data["wall_ever"]))
be = [e for e in host["events"] if e["e"] == "boss_spawned"]
if be:
    print("boss: can %.0f kalkan %.0f (2 oyuncu = x1,5)" % (be[0]["hp"], be[0]["shield"]))

# boss ölümü (stres koşusu: MP_STRESS=1) + uzuv parçalanma/geri dönüş sayıları
def death_time(samples):
    for r in samples:
        if len(r) > 8 and r[8] == 1:
            return r[0]
    return None


hd, cd = death_time(hs), death_time(cs)
if hd is not None or cd is not None:
    print("boss öldü mü: host %s, istemci %s (aynı anda olmalı: kayma %.2f sn)" % (hd, cd, shift))
    last_h = hs[-1][3]
    last_c = cs[-1][3]
    print("sonda yüzeyde kalan uzuv: host %d, istemci %d (boss ölünce hepsi dağılmalı)" % (last_h, last_c))
