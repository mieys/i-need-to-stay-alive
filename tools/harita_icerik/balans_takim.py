import json, sys, statistics as st
from collections import defaultdict
from datetime import datetime

min_rev = int(sys.argv[1])
runs, seen = [], set()
for p in sys.argv[2:]:
    try:
        f = open(p, encoding="utf-8")
    except OSError:
        continue
    for line in f:
        try:
            r = json.loads(line)
        except ValueError:
            continue
        if r.get("run_id") in seen or r.get("rev", 0) < min_rev or r.get("time", 0) < 120:
            continue
        seen.add(r.get("run_id"))
        try:
            r["_w"] = datetime.fromisoformat(str(r.get("when", "")).replace("Z", "")).timestamp()
        except ValueError:
            r["_w"] = 0.0
        runs.append(r)

runs.sort(key=lambda r: r["_w"])
games = []
for r in runs:
    for g in games:
        if g[0].get("team", 1) == r.get("team", 1) and r.get("team", 1) > 1 and abs(g[0]["_w"] - r["_w"]) <= 180 and len(g) < r.get("team", 1):
            g.append(r)
            break
    else:
        games.append([r])

def med(xs):
    return st.median(xs) if xs else 0.0

print("rev >= %d: %d kayit, %d oyun" % (min_rev, len(runs), len(games)))
rows = defaultdict(list)
for g in games:
    team = g[0].get("team", 1)
    host = max(g, key=lambda r: len(r.get("tier_time") or {}))
    tt = {int(k): float(v) for k, v in (host.get("tier_time") or {}).items()}
    scale = team / len(g)
    for t in sorted(tt):
        if t + 1 not in tt:
            continue
        d = tt[t + 1] - tt[t]
        if d < 30:
            continue
        dealt = sum(float((r.get("dealt_tier") or {}).get(str(t), 0.0)) for r in g) * scale
        taken = sum(float((r.get("taken_tier") or {}).get(str(t), 0.0)) for r in g) / len(g)
        rows[t].append((team, d, dealt / d, taken / d, host.get("rev", 0), len(g)))
print("kademe: [takim, sure, TAKIM DPS, kisi basi alinan/sn, rev, kayit]")
for t in sorted(rows):
    if t > 15:
        continue
    print("K%-2d n=%d  takim DPS med %.0f | " % (t, len(rows[t]), med([x[2] for x in rows[t]])) + "  ".join("%dk:%.0fsn:%.0f" % (x[0], x[1], x[2]) for x in rows[t]))
print("\noyun bazinda bitis: [takim, bitis kademesi, sure, neden, rev]")
for g in games:
    h = max(g, key=lambda r: r.get("time", 0))
    print("  %dk K%-2d %5.0f sn %-11s rev %d  can %s  seviye %s" % (h.get("team", 1), h.get("tier", 0), h.get("time", 0), h.get("end_reason", "?"), h.get("rev", 0), "/".join(str(int(r.get("max_hp", 0))) for r in g), "/".join(str(r.get("level", 0)) for r in g)))
