import json, sys
from collections import Counter

min_rev = int(sys.argv[1])
seen = set()
kill = Counter()
taken = {3: Counter(), 5: Counter(), 13: Counter()}
tot = {3: 0.0, 5: 0.0, 13: 0.0}
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
        t = r.get("tier", 0)
        if r.get("end_reason") == "lost" or r.get("dead"):
            kill[(t, r.get("killer", "?"))] += 1
        b = 3 if t <= 4 else (5 if t <= 7 else 13)
        for k, v in (r.get("taken_by") or {}).items():
            taken[b][k] += float(v)
            tot[b] += float(v)
print("olenlerin (bitis kademesi, son vuran):", dict(kill))
for b in (3, 5, 13):
    if tot[b] > 0:
        print("bitis ~K%d alinan hasar payi:" % b, ", ".join("%s %%%d" % (k, round(100 * v / tot[b])) for k, v in taken[b].most_common(7)))
