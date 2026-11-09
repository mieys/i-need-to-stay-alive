"""Her harita icin CAP_NOKTALAR uretir (yuzey: oyun alanina yayilmis 3x2 izgara; zindan: temsili zemin/duvar oranli zemin hucreleri)."""
import base64, re, sys, random

PROJ = sys.argv[1]

def grid(rect):
    x0, y0, w, h = rect
    pts = []
    for j, fy in enumerate((0.33, 0.66)):
        for i, fx in enumerate((0.22, 0.5, 0.78)):
            pts.append(("p%d" % (j * 3 + i), int(x0 + w * fx), int(y0 + h * fy)))
    return pts

def dungeon(mid):
    t = open(f"{PROJ}/scenes/zindan/{mid}_data.tres", encoding="utf-8").read()
    w, h = map(int, re.search(r"size = Vector2i\((\d+), (\d+)\)", t).groups())
    cells = base64.b64decode(re.search(r'cells = PackedByteArray\("([^"]+)"\)', t).group(1))
    rnd = random.Random(7)
    pts = []
    tries = 0
    while len(pts) < 6 and tries < 200000:
        tries += 1
        x, y = rnd.randrange(30, w - 30), rnd.randrange(17, h - 17)
        if cells[y * w + x] != 0:
            continue
        # gorus penceresi 60x34 hucre: zemin orani %45-80 (temsili oda + duvar)
        fl = sum(1 for yy in range(y - 17, y + 17, 2) for xx in range(x - 30, x + 30, 2) if cells[yy * w + xx] in (0, 3, 5))
        frac = fl / (17 * 30)
        if not 0.45 <= frac <= 0.8:
            continue
        if any(abs(x - px) < 40 and abs(y - py) < 30 for _, px, py in pts):
            continue
        pts.append(("p%d" % len(pts), x, y))
    return pts

maps = {
    "ana": grid((0, 0, 288, 276)),
    "bataklik": grid((32, 20, 214, 214)),
    "col": grid((32, 20, 243, 243)),
    "batik_nekropol": dungeon("batik_nekropol"),
    "taskin_hisar": dungeon("taskin_hisar"),
    "lagim_agi": dungeon("lagim_agi"),
}
for k, v in maps.items():
    print(k + "=" + ";".join(f"{n}:{x},{y}" for n, x, y in v))
