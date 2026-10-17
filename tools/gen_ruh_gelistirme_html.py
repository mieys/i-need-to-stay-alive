"""Ruh Mağazası kalıcı geliştirmeleri için ince ayar listesi (HTML) üretir.

Değerler scripts/meta_upgrades.gd içindeki LIST tablosundan OKUNUR (tek kaynak orası); kullanıcı HTML'de sayıları düzenleyip
"Kopyala" ile çıkan metni Claude'a yapıştırır, Claude tabloya işler.

Kullanım:  python tools/gen_ruh_gelistirme_html.py   ->   docs/balans/ruh_gelistirmeleri_ince_ayar.html
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "scripts" / "meta_upgrades.gd"
OUT = ROOT / "docs" / "balans" / "ruh_gelistirmeleri_ince_ayar.html"

# Oyundaki mevcut karşılıklar (karşılaştırma için) ve sınırlar - sadece bilgi, koddan okunmaz.
REF = {
    "pickup": ("Toplama mesafesi kartı havuzdan çıktı (eski kart tier1 +%30).", ""),
    "attack": ("Kart: +6 / +7,8 / +9,6 / +11,4 (kademe 1-4). Başlangıç 8-16.", ""),
    "atk_speed": ("Kart: +%6 (kademe 1). Karakter başlangıcı -%10..+%10.", "Üst sınır %600 (üstü saldırı gücüne döner)."),
    "regen": ("Kart: +2 / +4 / +6 / +8 (5 sn'de bir).", ""),
    "health": ("Kart: +15 / +24 / +30 / +38. Başlangıç 80-150.", ""),
    "lifesteal": ("Kart: %2 / %4 / %6 / %8 (kademe 1-4).", ""),
    "speed": ("Kart: +%4.", ""),
    "shield_amount": ("Kart: +%6,5.", ""),
    "shield_regen": ("Eşyalar: +0,5 .. +2 /sn.", ""),
    "heal_power": ("Eşyalar: +%5 .. +%25.", ""),
    "crit_chance": ("Kart: +%3,5.", "Üst sınır %100."),
    "crit_damage": ("Kart: +%6 / +7,8 / +9,6 / +11,4.", ""),
    "luck": ("Kart: +1 (kademe 1).", ""),
    "discount": ("Para ruhanisi: %10.", "Para ile TOPLANIR, toplam en fazla %50."),
    "shield_protection": ("Kart (havuzdan çıktı): +%4.", "Üst sınır %92."),
    "free_reroll": ("Karıştırma bedeli: 3, 6, 9... altın.", "Koşu başına 1 bedava (level kartı karıştırması)."),
    "revive": ("Taban 3 dirilme hakkı.", "Çok oyunculuda host'a bildirilir."),
    "cooldown": ("Kart: %4. Eşyalar da ekler.", "Üst sınır %60."),
    "skill_cost": ("Yetenek Kitabı eşyası.", "Yetenek bedeli = azami kalkanın %4-8'i + 20-40."),
    "shield_pen": ("Eşyalar: %5 .. %20. Kart havuzdan çıktı.", "Üst sınır %100."),
}


def parse_list(text: str):
    rows = []
    for m in re.finditer(r'\{"id": "(\w+)", "name": "([^"]+)", "desc": "([^"]+)", "icon": "[^"]*",\s*'
                         r'"max": (\d+), "per": ([\d.]+), "unit": (\w+), "first": (\d+), "step": (\d+)\}', text):
        id_, name, desc, mx, per, unit, first, step = m.groups()
        rows.append({
            "id": id_, "name": name, "desc": desc, "max": int(mx), "per": float(per),
            "unit": {"PCT": "pct", "FLAT": "flat", "COUNT": "count"}[unit],
            "first": int(first), "step": int(step),
            "ref": REF.get(id_, ("", ""))[0], "cap": REF.get(id_, ("", ""))[1],
        })
    return rows


def read_const(text: str, name: str):
    m = re.search(rf"const {name} := ([\d.]+)", text)
    return float(m.group(1))


def main():
    text = SRC.read_text(encoding="utf-8")
    rows = parse_list(text)
    assert len(rows) == 20, f"20 geliştirme bekleniyordu, {len(rows)} bulundu"
    cfg = {
        "reset_fee_percent": read_const(text, "RESET_FEE_PERCENT"),
        "reset_fee_min": int(read_const(text, "RESET_FEE_MIN")),
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    html = TEMPLATE.replace("__ROWS__", json.dumps(rows, ensure_ascii=False)).replace("__CFG__", json.dumps(cfg))
    OUT.write_text(html, encoding="utf-8")
    print("yazıldı:", OUT)


TEMPLATE = r"""<!doctype html>
<html lang="tr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Ruh Geliştirmeleri İnce Ayar</title>
<style>
:root{--bg:#f6f1e7;--card:#fffdf8;--ink:#2d2418;--dim:#7a6a52;--line:#e0d6c2;--accent:#a8641c;--good:#3e6b2a;--warn:#b3401f;--chip:#efe6d2;--input:#fff}
@media (prefers-color-scheme:dark){:root{--bg:#1d1812;--card:#26201a;--ink:#f0e6d2;--dim:#b3a283;--line:#3d3427;--accent:#e0a050;--good:#8cc46a;--warn:#f08a6a;--chip:#352c20;--input:#1d1812}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.45 system-ui,Segoe UI,sans-serif}
.wrap{max-width:1180px;margin:0 auto;padding:20px 16px 80px}
h1{font-size:22px;margin:0 0 4px}
p.sub{margin:0 0 16px;color:var(--dim)}
.panel{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:14px 16px;margin-bottom:16px}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:12px}
label.f{display:block;font-size:12px;color:var(--dim);margin-bottom:2px}
input[type=number]{width:100%;padding:6px 8px;border:1px solid var(--line);border-radius:6px;background:var(--input);color:var(--ink);font:inherit}
input[type=number]:focus{outline:2px solid var(--accent);outline-offset:0}
.stat b{display:block;font-size:20px}
.stat span{font-size:12px;color:var(--dim)}
table{width:100%;border-collapse:collapse}
th,td{padding:8px 6px;border-bottom:1px solid var(--line);vertical-align:top;text-align:left}
th{font-size:12px;color:var(--dim);font-weight:600;position:sticky;top:0;background:var(--card);z-index:1}
td.n{width:30px;color:var(--dim)}
td.name b{display:block}
td.name small{color:var(--dim)}
td.num input{width:84px}
td.out{white-space:nowrap}
td.out.big{font-weight:600}
.chips{display:flex;flex-wrap:wrap;gap:4px;margin-top:6px}
.chip{background:var(--chip);border-radius:5px;padding:1px 6px;font-size:12px;font-variant-numeric:tabular-nums}
.ref{font-size:12px;color:var(--dim)}
.cap{font-size:12px;color:var(--warn)}
.changed{background:color-mix(in srgb,var(--accent) 12%,transparent)}
.row-changed td.name b::after{content:" • değişti";color:var(--accent);font-weight:400;font-size:12px}
button{font:inherit;padding:7px 14px;border-radius:8px;border:1px solid var(--accent);background:var(--accent);color:#fff;cursor:pointer}
button.ghost{background:transparent;color:var(--accent)}
textarea{width:100%;min-height:210px;margin-top:8px;padding:10px;border:1px solid var(--line);border-radius:8px;background:var(--input);color:var(--ink);font:13px/1.5 ui-monospace,Consolas,monospace}
.bar{height:8px;background:var(--chip);border-radius:4px;overflow:hidden;margin-top:4px}
.bar i{display:block;height:100%;background:var(--accent)}
@media (max-width:820px){th:nth-child(n+8),td.hide-s{display:none}}
</style>
</head>
<body>
<div class="wrap">
<h1>Ruh Geliştirmeleri — İnce Ayar</h1>
<p class="sub">Sayıları düzenle, sonuçlar anında güncellenir. Bitince en alttaki <b>Kopyala</b> metnini bana yapıştır; ben tabloya (<code>scripts/meta_upgrades.gd</code>) işlerim. Fiyat: seviye n→n+1 = <b>ilk fiyat + artış × n</b>.</p>

<div class="panel">
  <div class="grid">
    <div><label class="f">Ortalama koşu kazancı (Ruh Kıymığı)</label><input type="number" id="income" min="1" step="5" value="120"></div>
    <div><label class="f">Sıfırlama ücreti (%)</label><input type="number" id="feePct" min="0" max="100" step="1"></div>
    <div><label class="f">Sıfırlama asgari ücret</label><input type="number" id="feeMin" min="0" step="5"></div>
  </div>
  <p class="ref" style="margin:10px 0 0">Koşu kazancı kılavuzu: Kademe 5'e kadar ≈ 35 + 2/dk, Kademe 10 ≈ 95 + 2/dk, Kademe 15 ≈ 180 + 2/dk (kademe puanı 5-6-7-8… artan). 25 dk'lık Kademe 8 koşusu ≈ 98 civarı.</p>
</div>

<div class="panel grid" id="summary"></div>

<div class="panel" style="padding:6px 10px;overflow-x:auto">
<table id="tbl">
  <thead><tr>
    <th>#</th><th>Geliştirme</th><th>Seviye</th><th id="thPer">Seviye başı etki</th><th>Tam etki</th><th>İlk fiyat</th><th>Fiyat artışı</th><th>Toplam maliyet</th><th>≈ Koşu</th>
  </tr></thead>
  <tbody></tbody>
</table>
</div>

<div class="panel">
  <h2 style="margin:0 0 4px;font-size:17px">Kopyala</h2>
  <p class="ref" style="margin:0">Sadece değişen satırlar “DEĞİŞTİ” ile işaretlenir; hepsi listelenir. Etki birimi: yüzdelik puan (% sütunu) ya da düz sayı.</p>
  <div style="display:flex;gap:8px;margin-top:10px;flex-wrap:wrap">
    <button id="copy">Metni kopyala</button>
    <button class="ghost" id="reset">Varsayılana dön</button>
  </div>
  <textarea id="out" readonly></textarea>
</div>
</div>

<script>
const ROWS = __ROWS__;
const CFG = __CFG__;
const KEY = "ruh_gelistirme_ince_ayar_v1";
const $ = s => document.querySelector(s);
const fmt = n => { const s = (Math.round(n*100)/100).toString().replace(".", ","); return s; };
const unitLabel = r => r.unit === "pct" ? "%" : (r.unit === "count" ? "adet" : "düz");
const toDisp = r => r.unit === "pct" ? +(r.per*100).toFixed(4) : r.per;
const fromDisp = (r,v) => r.unit === "pct" ? v/100 : v;

let state = ROWS.map(r => ({id:r.id, max:r.max, per:toDisp(r), first:r.first, step:r.step}));
let fee = {pct: CFG.reset_fee_percent*100, min: CFG.reset_fee_min, income: 120};
const base = JSON.parse(JSON.stringify({state, fee}));
try { const saved = JSON.parse(localStorage.getItem(KEY) || "null"); if (saved && saved.state && saved.state.length === state.length) { state = saved.state; fee = saved.fee; } } catch(e) {}

function costs(s){ const a=[]; for(let n=0;n<s.max;n++) a.push(s.first + s.step*n); return a; }
function total(s){ return costs(s).reduce((x,y)=>x+y,0); }
function changed(i){ const a=state[i], b=base.state[i]; return a.max!==b.max||a.per!==b.per||a.first!==b.first||a.step!==b.step; }

function build(){
  const tb = $("#tbl tbody"); tb.innerHTML = "";
  ROWS.forEach((r,i)=>{
    const tr = document.createElement("tr"); tr.dataset.i = i;
    tr.innerHTML = `
      <td class="n">${i+1}</td>
      <td class="name"><b>${r.name}</b><small>${r.desc}</small>
        <div class="ref">${r.ref}</div>${r.cap?`<div class="cap">${r.cap}</div>`:""}
        <div class="chips"></div></td>
      <td class="num"><input type="number" data-k="max" min="1" step="1"></td>
      <td class="num"><input type="number" data-k="per" min="0" step="any"><div class="ref">${unitLabel(r)}</div></td>
      <td class="out big" data-o="full"></td>
      <td class="num"><input type="number" data-k="first" min="1" step="1"></td>
      <td class="num"><input type="number" data-k="step" min="0" step="1"></td>
      <td class="out big" data-o="total"></td>
      <td class="out" data-o="runs"></td>`;
    tb.appendChild(tr);
    tr.querySelectorAll("input").forEach(inp=>{
      inp.addEventListener("input",()=>{ const v=parseFloat(inp.value.replace(",", ".")); if(!isFinite(v)) return; state[i][inp.dataset.k]=(inp.dataset.k==="max"||inp.dataset.k==="first"||inp.dataset.k==="step")?Math.max(0,Math.round(v)):v; refresh(); });
    });
  });
  $("#feePct").addEventListener("input",e=>{fee.pct=parseFloat(e.target.value)||0;refresh();});
  $("#feeMin").addEventListener("input",e=>{fee.min=parseFloat(e.target.value)||0;refresh();});
  $("#income").addEventListener("input",e=>{fee.income=Math.max(1,parseFloat(e.target.value)||1);refresh();});
}

function refresh(){
  let grand = 0, levels = 0;
  const rows = [...document.querySelectorAll("#tbl tbody tr")];
  const maxTotal = Math.max(...state.map(total));
  rows.forEach(tr=>{
    const i = +tr.dataset.i, s = state[i], r = ROWS[i];
    for (const inp of tr.querySelectorAll("input")) if (document.activeElement !== inp) inp.value = s[inp.dataset.k];
    const t = total(s); grand += t; levels += s.max;
    const per = fromDisp(r, s.per), full = per*s.max;
    const dispFull = r.unit==="pct" ? "+%"+fmt(full*100) : "+"+fmt(full);
    tr.querySelector('[data-o="full"]').textContent = dispFull;
    tr.querySelector('[data-o="total"]').innerHTML = t.toLocaleString("tr")+`<div class="bar"><i style="width:${Math.round(t/maxTotal*100)}%"></i></div>`;
    tr.querySelector('[data-o="runs"]').textContent = "~"+fmt(t/fee.income)+" koşu";
    tr.querySelector(".chips").innerHTML = costs(s).map((c,n)=>`<span class="chip" title="${n+1}. seviye: ${r.unit==="pct"?"+%"+fmt(per*(n+1)*100):"+"+fmt(per*(n+1))}">${n+1}: ${c}</span>`).join("");
    tr.classList.toggle("row-changed", changed(i));
  });
  $("#feePct").value = fee.pct; $("#feeMin").value = fee.min; $("#income").value = fee.income;
  const refundAll = Math.round(grand - Math.min(grand, Math.max(fee.min, Math.round(grand*fee.pct/100))));
  const feeAll = grand - refundAll;
  $("#summary").innerHTML = `
    <div class="stat"><b>${levels}</b><span>toplam seviye</span></div>
    <div class="stat"><b>${grand.toLocaleString("tr")}</b><span>hepsini almanın maliyeti (Ruh Kıymığı)</span></div>
    <div class="stat"><b>~${fmt(grand/fee.income)}</b><span>koşu (ortalama ${fee.income} kazançla)</span></div>
    <div class="stat"><b>${feeAll.toLocaleString("tr")}</b><span>hepsi alınmışken sıfırlama ücreti (iade ${refundAll.toLocaleString("tr")})</span></div>`;
  $("#out").value = makeText();
  try { localStorage.setItem(KEY, JSON.stringify({state,fee})); } catch(e) {}
}

function makeText(){
  const L = ["RUH GELİŞTİRMELERİ İNCE AYAR (id: seviye | seviye başı etki | ilk fiyat | fiyat artışı)",
             `sıfırlama ücreti: %${fee.pct} (asgari ${fee.min})   [ortalama koşu kazancı: ${fee.income}]`, ""];
  ROWS.forEach((r,i)=>{
    const s = state[i];
    const unit = r.unit==="pct" ? "%" : "";
    L.push(`${String(i+1).padStart(2," ")}. ${r.id.padEnd(18)} | ${s.max} seviye | etki ${fmt(s.per)}${unit}/seviye | ilk ${s.first} | artış +${s.step}  (toplam ${total(s)})${changed(i)?"   <- DEĞİŞTİ":""}`);
  });
  return L.join("\n");
}

$("#copy").addEventListener("click",async()=>{ const t=$("#out").value; try{ await navigator.clipboard.writeText(t); $("#copy").textContent="Kopyalandı ✓"; }catch(e){ $("#out").select(); document.execCommand("copy"); $("#copy").textContent="Kopyalandı ✓"; } setTimeout(()=>$("#copy").textContent="Metni kopyala",1600); });
$("#reset").addEventListener("click",()=>{ state=JSON.parse(JSON.stringify(base.state)); fee=JSON.parse(JSON.stringify(base.fee)); refresh(); });
build(); refresh();
</script>
</body>
</html>
"""

if __name__ == "__main__":
    main()
