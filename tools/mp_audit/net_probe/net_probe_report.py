"""AĞ SONDASI raporu (madde 349): python -I -X utf8 net_probe_report.py <klasör> [<klasör> ...]
host.json + client.json (net_probe.gd çıktısı) -> kare hızı/fizik adımı, ENet trafiği, senkron turu, yaratık ve oyuncu kuklası konum hatası
(host gerçeği vs istemcide görünen, duvar saatiyle hizalı), güvenilir/güvenilmez/ayrı-kanal ping gecikmesi ve kaybı."""
import bisect
import json
import math
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

SPEED = 0.8 * 120.0  # px/sn: sondanın oyuncuyu gezdirdiği daire (omega 0,8 rad/sn x yarıçap 120)


def pct(a, p):
    a = sorted(a)
    return a[min(len(a) - 1, int(len(a) * p))] if a else float("nan")


def align(hs, cs):
    uc = [x["u"] for x in cs]
    pairs = []
    for x in hs:
        i = bisect.bisect_left(uc, x["u"])
        cand = [j for j in (i - 1, i) if 0 <= j < len(cs)]
        if not cand:
            continue
        j = min(cand, key=lambda j: abs(uc[j] - x["u"]))
        if abs(uc[j] - x["u"]) <= 0.06:
            pairs.append((x, cs[j]))
    return pairs


def lat_stats(name, arr, sent):
    if not arr:
        print(f"  {name}: veri yok")
        return
    ms = [x[0] for x in arr]
    got = len(set(x[1] for x in arr))
    reorder = sum(1 for i in range(1, len(arr)) if arr[i][1] < arr[i - 1][1])
    ts = [x[2] for x in arr]
    gaps = [ts[i] - ts[i - 1] for i in range(1, len(ts))] or [0]
    print(f"  {name}: gönderilen={sent} alınan={got} (kayıp %{100*(1-got/max(1,sent)):.1f}) | tek yön ms p50={pct(ms,.5):.0f} p90={pct(ms,.9):.0f} p99={pct(ms,.99):.0f} maks={max(ms):.0f} | sıra bozulması={reorder} | alım boşluğu p99={pct(gaps,.99)*1000:.0f}ms maks={max(gaps)*1000:.0f}ms")


def main(d):
    h = json.load(open(f"{d}/host.json", encoding="utf-8"))
    c = json.load(open(f"{d}/client.json", encoding="utf-8"))
    hs, cs = h["samples"], c["samples"]
    tag = d.replace("\\", "/").rstrip("/").split("/")[-1]
    dur = hs[-1]["u"] - hs[0]["u"]
    print(f"=== {tag}  (hedef yaratık={h['n']}, ortalama canlı={sum(x['n'] for x in hs)/len(hs):.0f}, süre {dur:.0f} sn)")
    print(f"  durum paketi (extra_state) boyutu: host {h['cost'].get('extra_state_bytes')} B / istemci {c['cost'].get('extra_state_bytes')} B, anahtar {h['cost'].get('extra_state_keys')}")
    for name, x in (("HOST", h), ("İSTEMCİ", c)):
        s = x["samples"]
        fps = sum(v["fr"] for v in s) / dur
        pf = (s[-1].get("pf", 0) - s[0].get("pf", 0)) / dur
        mx = [v["mx"] for v in s]
        sent = sum(v["bs"] for v in s)
        recv = sum(v["br"] for v in s)
        ps = sum(v["bp"] for v in s)
        pr = sum(v["bpr"] for v in s)
        print(f"  {name}: FPS={fps:.0f} fizik adımı/sn={pf:.1f}/60 | en uzun kare p95={pct(mx,.95):.0f}ms maks={max(mx):.0f}ms | gönderilen {sent/dur/1024:.1f} KB/s {ps/dur:.0f} paket/s | alınan {recv/dur/1024:.1f} KB/s {pr/dur:.0f} paket/s")
    if c["cost"].get("client_apply_ms_per_tick") is not None:
        print(f"  istemci senkron uygulama maliyeti: {c['cost']['client_apply_ms_per_tick']:.2f} ms / tur ({c['cost'].get('client_apply_states')} yaratık)")
    ticks = hs[-1]["th"] - hs[0]["th"]
    print(f"  HOST senkron turu: {ticks/dur:.2f} tur/sn (hedef 6,67)")
    pairs = align(hs, cs)
    errs = [math.hypot(v[0] - b["en"][k][0], v[1] - b["en"][k][1]) for a, b in pairs for k, v in a["en"].items() if k in b["en"]]
    if errs:
        print(f"  YARATIK konum hatası px: ort={sum(errs)/len(errs):.1f} medyan={pct(errs,.5):.1f} p95={pct(errs,.95):.1f} p99={pct(errs,.99):.1f} maks={max(errs):.0f}")
    for nm, fa, fb in (("istemcide görünen HOST oyuncusu", "own", "pup"), ("host'ta görünen İSTEMCİ oyuncusu", "pup", "own")):
        e = []
        for a, b in pairs:
            if nm.startswith("istemcide"):
                p, q = a.get("own"), b.get("pup")
            else:
                p, q = b.get("own"), a.get("pup")
            if p and q:
                e.append(math.hypot(q[0] - p[0], q[1] - p[1]))
        if e:
            print(f"  OYUNCU kuklası ({nm}): ort={sum(e)/len(e):.1f}px (~{1000*sum(e)/len(e)/SPEED:.0f} ms) p95={pct(e,.95):.1f}px (~{1000*pct(e,.95)/SPEED:.0f} ms)")
    lh, lc = h.get("lat"), c.get("lat")
    if lh and lc:
        lat_stats("HOST→İSTEMCİ güvenilir (oyunun güvenilir akışıyla aynı kanal)", lc["rel"], lh["sent_rel"])
        lat_stats("HOST→İSTEMCİ güvenilmez", lc["unr"], lh["sent_unr"])
        lat_stats("İSTEMCİ→HOST güvenilir (aynı kanal)", lh["rel"], lc["sent_rel"])
        lat_stats("İSTEMCİ→HOST güvenilmez", lh["unr"], lc["sent_unr"])
        if "chan" in lc:
            lat_stats("HOST→İSTEMCİ güvenilir AYRI KANAL (7)", lc["chan"], lh["sent_chan"])
            lat_stats("İSTEMCİ→HOST güvenilir AYRI KANAL (7)", lh["chan"], lc["sent_chan"])


for d in sys.argv[1:]:
    main(d)
