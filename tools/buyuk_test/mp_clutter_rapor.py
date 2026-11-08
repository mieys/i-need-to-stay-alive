#!/usr/bin/env python
# MP savas gorsel karmasa raporu (mp_clutter.gd ciktilari). Kullanim:
#   python -I tools/buyuk_test/mp_clutter_rapor.py <mp_etiket> <solo_etiket>     ornek: ags_fx3 ags_fx_solo
# Uretir: out/<mp_etiket>/MPC_RAPOR.md + kategori_haritasi_m*.jpg + sayfa_mp.jpg
import os, re, sys, collections
import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
MP = sys.argv[1]
SOLO = sys.argv[2] if len(sys.argv) > 2 else None
CATS = ["hud", "numbers", "drops", "decal", "bars", "weapons_own", "weapons_puppet", "projectile", "player_fx", "enemy_fx", "pets", "summons", "enemy"]
TR = {"hud": "HUD", "numbers": "hasar/altin yazilari", "drops": "yerdeki esyalar (XP/altin/...)", "decal": "yer lekeleri (kan/catlak)", "bars": "can/kalkan cubuklari + durum ikonlari",
      "weapons_own": "kendi silahlarim", "weapons_puppet": "DIGER oyuncularin silahlari", "projectile": "mermiler/isinlar", "player_fx": "oyuncu yetenek + silah efektleri",
      "enemy_fx": "yaratik saldirilari/efektleri", "pets": "evcil hayvanlar", "summons": "cagrilanlar", "enemy": "yaratiklar"}
COLORS = {"hud": (120, 120, 120), "numbers": (255, 255, 255), "drops": (255, 215, 0), "decal": (150, 0, 0), "bars": (0, 255, 120), "weapons_own": (0, 200, 255), "weapons_puppet": (0, 90, 255),
          "projectile": (255, 140, 0), "player_fx": (255, 0, 255), "enemy_fx": (255, 40, 40), "pets": (160, 255, 0), "summons": (0, 255, 255), "enemy": (170, 170, 170)}


def load(label, name):
    p = os.path.join(HERE, "out", label, "viewer", name + ".jpg")
    return np.asarray(Image.open(p).convert("RGB").resize((960, 540), Image.BILINEAR), dtype=np.float32) if os.path.exists(p) else None


def edge(a):
    g = a.mean(axis=2)
    gx = np.abs(g[:, 2:] - g[:, :-2])[1:-1, :]
    gy = np.abs(g[2:, :] - g[:-2, :])[:, 1:-1]
    return float(np.sqrt(gx[: gy.shape[0], : gy.shape[1]] ** 2 + gy[: gx.shape[0], : gx.shape[1]] ** 2).mean())


def satfrac(a):
    mx = a.max(axis=2); mn = a.min(axis=2)
    return float(((mx > 150) & ((mx - mn) / np.maximum(mx, 1) > 0.55)).mean())


def brightfrac(a):
    return float((a.max(axis=2) > 235).mean())


def log_lines(label, name):
    p = os.path.join(HERE, "out", label, name + ".log")
    return open(p, encoding="utf-8", errors="replace").read().splitlines() if os.path.exists(p) else []


def counts(label):
    rows = collections.defaultdict(list)
    draws, objs, fps = [], [], []
    for l in log_lines(label, "viewer"):
        m = re.match(r"MPC CNT t=(\d+) (.*) draws=(\d+) objs=(\d+) nodes=(\d+) fps=(\d+)", l)
        if m and 8 <= int(m.group(1)) <= 68:
            for kv in m.group(2).split():
                k, v = kv.split("=")
                rows[k].append(int(v))
            draws.append(int(m.group(3))); objs.append(int(m.group(4))); fps.append(int(m.group(6)))
    out = {k: float(np.mean(v)) for k, v in rows.items()}
    out["draws"] = float(np.mean(draws)) if draws else 0
    out["objs"] = float(np.mean(objs)) if objs else 0
    out["fps_cnt"] = float(np.mean(fps)) if fps else 0
    return out


def flick(label):
    for l in log_lines(label, "viewer"):
        if l.startswith("MPC FLICK"):
            return {k: float(v) for k, v in re.findall(r"(\w+)=([\d.]+)", l)}
    return {}


def inv(label, tag):
    for l in log_lines(label, "viewer"):
        if l.startswith("MPC INV %s " % tag):
            return l.split(" ", 3)[3]
    return ""


def ablation(label):
    res = {c: [] for c in CATS}
    glob = collections.defaultdict(list)
    for m in range(4):
        base = load(label, "m%d_00_base" % m)
        if base is None:
            continue
        glob["edge_base"].append(edge(base)); glob["sat_base"].append(satfrac(base)); glob["bright_base"].append(brightfrac(base))
        ef = load(label, "m%d_zz_efektsiz" % m)
        bd = load(label, "m%d_zzz_bos_dunya" % m)
        if ef is not None:
            glob["edge_efektsiz"].append(edge(ef)); glob["sat_efektsiz"].append(satfrac(ef)); glob["bright_efektsiz"].append(brightfrac(ef))
            glob["area_efekt"].append(float((np.abs(base - ef).max(axis=2) > 28).mean()))
        if bd is not None:
            glob["edge_bos"].append(edge(bd)); glob["area_hepsi"].append(float((np.abs(base - bd).max(axis=2) > 28).mean()))
        for c in CATS:
            h = load(label, "m%d_%s" % (m, c))
            if h is None:
                continue
            d = np.abs(base - h).max(axis=2) > 28
            res[c].append((float(d.mean()), edge(base) - edge(h), satfrac(base) - satfrac(h), brightfrac(base) - brightfrac(h)))
    return res, {k: float(np.mean(v)) for k, v in glob.items()}


def heatmap(label, m):
    base = load(label, "m%d_00_base" % m)
    if base is None:
        return None
    img = (base * 0.55).astype(np.float32)
    for c in CATS:
        h = load(label, "m%d_%s" % (m, c))
        if h is None or c in ("hud", "enemy"):
            continue
        d = np.abs(base - h).max(axis=2) > 28
        col = np.array(COLORS[c], dtype=np.float32)
        img[d] = img[d] * 0.25 + col * 0.75
    # yaratiklar en altta (gri)
    h = load(label, "m%d_enemy" % m)
    if h is not None:
        d = np.abs(base - h).max(axis=2) > 28
        img[d & (img.sum(axis=2) < 3 * 255 * 0.55 * 1.0)] = img[d & (img.sum(axis=2) < 3 * 255 * 0.55 * 1.0)] * 0.5 + 60
    out = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(out)
    y = 6
    for c in CATS:
        if c in ("hud",):
            continue
        d.rectangle([6, y, 18, y + 10], fill=COLORS[c]); d.text((24, y), TR[c], fill=(255, 255, 255)); y += 13
    path = os.path.join(HERE, "out", label, "kategori_haritasi_m%d.jpg" % m)
    out.save(path, quality=90)
    return path


def main():
    L = ["# MP savas gorsel karmasa raporu: %s%s\n" % (MP, (" (taban: %s)" % SOLO) if SOLO else "")]
    cm = counts(MP); cs = counts(SOLO) if SOLO else {}
    L.append("## 1. Ekrandaki ogeler (ortalama, t=8-68 sn)\n")
    L.append("| oge | MP | tek oyunculu | fark |\n|---|---|---|---|")
    for k in ["players", "enemy", "enemy_fx", "weapons_own", "weapons_puppet", "projectile", "player_fx", "numbers", "decal", "drops", "bars", "pets", "summons", "draws", "objs"]:
        a, b = cm.get(k, 0), cs.get(k, 0)
        L.append("| %s | %.1f | %.1f | %+.1f |" % (TR.get(k, k), a, b, a - b))
    L.append("\nGorunen toplam 'oge' (yaratik + oyuncu haric): MP %.0f / tek %.0f\n" % (sum(cm.get(k, 0) for k in ["enemy_fx", "weapons_own", "weapons_puppet", "projectile", "player_fx", "numbers", "decal", "drops", "bars", "pets", "summons"]),
                                                                                  sum(cs.get(k, 0) for k in ["enemy_fx", "weapons_own", "weapons_puppet", "projectile", "player_fx", "numbers", "decal", "drops", "bars", "pets", "summons"])))
    L.append("## 2. Yanip sonme / hareket (10 sn, ~20 Hz ornek)\n")
    fm, fs = flick(MP), flick(SOLO) if SOLO else {}
    L.append("| olcu | MP | tek |\n|---|---|---|")
    for k in ["lum_mean", "lum_std", "lum_jump_mean", "lum_jump_p95", "diff_mean", "diff_hi_frac", "sat_frac"]:
        L.append("| %s | %.3f | %.3f |" % (k, fm.get(k, 0), fs.get(k, 0)))
    L.append("\n(lum_jump = ardisik orneklerde ortalama isik farki; diff_hi_frac = karede ani degisen piksel orani; sat_frac = doygun renk orani)\n")
    L.append("## 3. Kategori katkisi (ablation, 4 an ortalamasi)\n")
    for tag, lab in (("MP", MP), ("TEK", SOLO)):
        if not lab:
            continue
        res, g = ablation(lab)
        L.append("### %s (%s)\n" % (tag, lab))
        L.append("kenar yogunlugu: tum kare %.2f | efektsiz %.2f | bos dunya %.2f ; doygun piksel: %.3f -> %.3f ; ekranin degisen alani: efektler %.1f%%, hepsi %.1f%%\n" % (
            g.get("edge_base", 0), g.get("edge_efektsiz", 0), g.get("edge_bos", 0), g.get("sat_base", 0), g.get("sat_efektsiz", 0), 100 * g.get("area_efekt", 0), 100 * g.get("area_hepsi", 0)))
        L.append("| kategori | ekran alani %% | kenar katkisi | doygun katkisi | parlak katkisi |\n|---|---|---|---|---|")
        rows = []
        for c in CATS:
            v = res[c]
            if not v:
                continue
            a = np.mean(v, axis=0)
            rows.append((a[0], c, a))
        for _, c, a in sorted(rows, reverse=True):
            L.append("| %s | %.2f | %.3f | %.4f | %.4f |" % (TR[c], 100 * a[0], a[1], a[2], a[3]))
        L.append("")
    L.append("## 4. Envanter (MP, 3. an) - kategori:betik=adet\n")
    L.append("```\n" + inv(MP, "m2") + "\n```\n")
    for m in (1, 2):
        p = heatmap(MP, m)
        if p:
            L.append("- kategori haritasi: %s" % os.path.basename(p))
    open(os.path.join(HERE, "out", MP, "MPC_RAPOR.md"), "w", encoding="utf-8").write("\n".join(L))
    print("\n".join(L))


main()
