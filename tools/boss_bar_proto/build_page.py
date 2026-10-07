import html, os

SP = os.path.dirname(os.path.abspath(__file__))

TOPS = [
    ("T1", "Ahşap Plaket", "Ahşap ailesi",
     "HUD'daki envanter ve altın plaketleriyle aynı ahşap çerçeve. Solda kafatası yuvası (HUD'daki kalp yuvasının karşılığı), üstte parşömen isim tabelası.",
     [("Kalkan", "Canın üstünde ince mavi şerit."),
      ("Çoklu boss", "Ana plaketin altında isimli küçük plaketler.")]),
    ("T2", "Zırh Dilimleri", "Demir ailesi",
     "Koyu demir çerçeve, iki ucunda boynuz. Kalkan 10 plaka olarak çizilir, her plaka %10 ve hasar aldıkça tek tek boşalır.",
     [("Kalkan", "10 plaka, sayarak okunur."),
      ("Çoklu boss", "Beş plakalı küçük demir çubuklar.")]),
    ("T3", "Madalyon", "Halka",
     "Taçlı kafatası madalyonu. Kalkan madalyonun çevresinde mavi halka olarak durur ve saat yönünde erir. Can sağdaki uzun çubukta.",
     [("Kalkan", "Halka, can çubuğundan ayrı bir yerde."),
      ("Çoklu boss", "Küçük madalyonlar, yanlarında ince can çubuğu.")]),
    ("T4", "Sade Çizgi", "Sade",
     "Çerçevesiz. İsim ve yüzde üstte, 3 piksellik kalkan çizgisi ve 6 piksellik can çubuğu altta. Ekranın en az kapladığı sürüm.",
     [("Kalkan", "Canın üstünde ince mavi çizgi."),
      ("Çoklu boss", "Üst üste ince çizgiler, isim üstte.")]),
]

WORLDS = [
    ("O1", "Demir + Kafatası", "Demir ailesi",
     "Demir çerçeve, solda altın kenarlı kafatası plakası. Kalkan canın hemen üstünde ince şerit.",
     [("Kalkan", "Canın üstünde ince şerit.")]),
    ("O2", "Asma Tabela", "Ahşap ailesi",
     "Zincirle asılı parşömen isim tabelası ve ahşap çubuk. Boss'un adı kafasının üstünde de okunur. Kalkan canın altında ince çizgi.",
     [("Kalkan", "Canın altında ince çizgi."),
      ("İsim", "Tabelada, kısa hâliyle (GOLEM, AĞAÇ, LICH).")]),
    ("O3", "Boynuzlu Taç", "Demir ailesi",
     "Çerçevenin iki ucundan yükselen boynuzlar. Kalkan boynuzların arasında, canın üstünde ayrı bir plaka.",
     [("Kalkan", "Boynuzların arasında ayrı plaka.")]),
    ("O4", "Sade + Kalkan Noktaları", "Sade",
     "Kafatası ve koyu kırmızı çift anahatlı can çubuğu. Kalkan 5 hap olarak çizilir, her hap %20.",
     [("Kalkan", "5 hap, her biri %20.")]),
]


def esc(s):
    return html.escape(s, quote=True)


def fig(src, cap, w, h, wide=False):
    cls = "z wide" if wide else "z"
    return (f'<figure class="{cls}" tabindex="0" role="button" aria-label="{esc(cap)} (2 kat büyütmek için tıkla)">'
            f'<div class="scroll"><img src="img/{src}" width="{w}" height="{h}" alt="{esc(cap)}"></div>'
            f'<figcaption>{esc(cap)}</figcaption></figure>')


def dl(items):
    return "<dl>" + "".join(f"<div><dt>{esc(k)}</dt><dd>{esc(v)}</dd></div>" for k, v in items) + "</dl>"


def sizes():
    from PIL import Image
    out = {}
    for f in os.listdir(os.path.join(SP, "site", "img")):
        im = Image.open(os.path.join(SP, "site", "img", f))
        out[f] = im.size
    return out


S = sizes()


def top_block(key, name, fam, desc, facts):
    ctx, multi, st = f"top_{key}_ctx.png", f"top_{key}_multi.png", f"top_{key}_states.png"
    return f'''
<article class="proto" id="{key.lower()}">
  <header class="proto-head">
    <span class="tag">{key}</span>
    <h3>{esc(name)}</h3>
    <span class="fam">{esc(fam)}</span>
  </header>
  <div class="proto-text"><p>{esc(desc)}</p>{dl(facts)}</div>
  {fig(ctx, "Oyun içinde, tek boss (kalkan %70, can %85)", *S[ctx], wide=True)}
  <div class="pair">
    {fig(st, "Dört durum, yukarıdan aşağı: kalkan tam, kalkan eriyor, kalkan kırıldı, can kritik", *S[st])}
    {fig(multi, "Çoklu boss: ana bar ve iki küçük bar", *S[multi])}
  </div>
</article>'''


def world_block(key, name, fam, desc, facts):
    single, multi, st = f"world_{key}_single.png", f"world_{key}_multi.png", f"world_{key}_states.png"
    return f'''
<article class="proto" id="{key.lower()}">
  <header class="proto-head">
    <span class="tag">{key}</span>
    <h3>{esc(name)}</h3>
    <span class="fam">{esc(fam)}</span>
  </header>
  <div class="proto-text"><p>{esc(desc)}</p>{dl(facts)}</div>
  <div class="pair world">
    {fig(single, "Golem, tek boss (kalkan %70, can %85)", *S[single])}
    <div class="stack">
      {fig(multi, "Üç boss aynı karede: golem, ağaç (kalkan kırık), lich (can düşük)", *S[multi])}
      {fig(st, "Dört durum, soldan sağa: kalkan tam, kalkan eriyor, kalkan kırıldı, can kritik", *S[st])}
    </div>
  </div>
</article>'''


CSS = """
/* Layout: tek sütunlu inceleme sayfası. Bölüm başına bir başlık, her prototip kendi çizgili bloğunda, görseller tam genişlik. */
:root{
  --bg:#eef1ee; --panel:#ffffff; --line:#cdd6d1; --fg:#1b2420; --muted:#52615a;
  --accent:#8a5608; --accent-soft:#f1e6cf; --shot:#dfe6e1;
  --font-display:"Pixelify Sans","Courier New",monospace;
  --font-body:"IBM Plex Sans",system-ui,sans-serif;
  --font-mono:"IBM Plex Mono",ui-monospace,monospace;
}
@media (prefers-color-scheme: dark){
  :root:not([data-theme="light"]){
    --bg:#12171a; --panel:#1a2024; --line:#2a343a; --fg:#e7e5dc; --muted:#98a59e;
    --accent:#d8ab4e; --accent-soft:#2a2414; --shot:#0d1113; color-scheme:dark;
  }
}
:root[data-theme="dark"]{
  --bg:#12171a; --panel:#1a2024; --line:#2a343a; --fg:#e7e5dc; --muted:#98a59e;
  --accent:#d8ab4e; --accent-soft:#2a2414; --shot:#0d1113; color-scheme:dark;
}
body{background:var(--bg);color:var(--fg);font-family:var(--font-body);font-size:16px;line-height:1.55;
  padding-inline:clamp(16px,4vw,48px);padding-block:32px 64px}
main{max-width:1040px;margin-inline:auto;display:flex;flex-direction:column;gap:56px}
h1,h2,h3{font-family:var(--font-display);font-weight:600;line-height:1.15;text-wrap:balance;margin:0}
h1{font-size:clamp(30px,5vw,44px);letter-spacing:.01em}
h2{font-size:clamp(22px,3.4vw,28px)}
h3{font-size:22px}
p{margin:0;max-width:68ch}
.lede{color:var(--muted);font-size:17px;margin-top:12px}
.intro{display:flex;flex-direction:column;gap:20px}
.facts{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,17rem),1fr));gap:16px 28px;margin:0;padding:0;list-style:none}
.facts li{border-top:2px solid var(--accent);padding-top:10px;font-size:15px;color:var(--muted)}
.facts strong{display:block;color:var(--fg);font-weight:600;margin-bottom:2px}
.legend{display:flex;flex-wrap:wrap;gap:8px 10px;font-family:var(--font-mono);font-size:12px;letter-spacing:.04em;text-transform:uppercase;color:var(--muted)}
.legend span{border:1px solid var(--line);padding:3px 9px;background:var(--panel)}
.section{display:flex;flex-direction:column;gap:36px}
.section>header{display:flex;flex-direction:column;gap:8px;border-bottom:1px solid var(--line);padding-bottom:16px}
.section>header p{color:var(--muted)}
.proto{display:flex;flex-direction:column;gap:14px;padding-top:28px;border-top:1px solid var(--line)}
.proto:first-of-type{border-top:0;padding-top:0}
.proto-head{display:flex;flex-wrap:wrap;align-items:baseline;gap:6px 14px}
.tag{font-family:var(--font-mono);font-size:13px;font-weight:600;color:var(--accent);border:1px solid var(--accent);padding:1px 8px}
.fam{font-family:var(--font-mono);font-size:12px;letter-spacing:.05em;text-transform:uppercase;color:var(--muted)}
.proto-text{display:grid;grid-template-columns:minmax(0,1.3fr) minmax(0,1fr);gap:14px 32px;align-items:start}
.proto-text p{font-size:16px}
dl{margin:0;display:flex;flex-direction:column;gap:6px;font-size:14.5px}
dl div{display:grid;grid-template-columns:7.2rem minmax(0,1fr);gap:10px}
dt{font-family:var(--font-mono);font-size:12px;letter-spacing:.05em;text-transform:uppercase;color:var(--muted);padding-top:2px}
dd{margin:0}
figure{margin:0;display:flex;flex-direction:column;gap:6px;min-width:0}
figure.z{cursor:zoom-in}
figure.z.zoomed{cursor:zoom-out}
.scroll{overflow-x:auto;background:var(--shot);border:1px solid var(--line)}
.scroll img{display:block;max-width:100%;height:auto;image-rendering:pixelated}
figure.zoomed .scroll img{max-width:none}
figcaption{font-size:13px;color:var(--muted);max-width:70ch}
.pair{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,22rem),1fr));gap:20px;align-items:start}
.pair.world{grid-template-columns:minmax(0,500px) minmax(0,1fr)}
.stack{display:flex;flex-direction:column;gap:20px;min-width:0}
.current{display:grid;grid-template-columns:minmax(0,500px) minmax(0,1fr);gap:20px 32px;align-items:start}
.note{font-size:14px;color:var(--muted);border-left:2px solid var(--line);padding-left:14px;max-width:70ch}
a:focus-visible,figure:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
@media (max-width:760px){
  .proto-text,.pair.world,.current{grid-template-columns:minmax(0,1fr)}
}
"""

JS = """
document.querySelectorAll('figure.z').forEach(function(f){
  var img=f.querySelector('img');
  function toggle(){
    var on=f.classList.toggle('zoomed');
    img.style.width=on?(img.naturalWidth*2)+'px':'';
    img.style.height=on?'auto':'';
  }
  f.addEventListener('click',toggle);
  f.addEventListener('keydown',function(e){if(e.key==='Enter'||e.key===' '){e.preventDefault();toggle();}});
});
"""

page = f"""<title>Boss Bar Prototipleri</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;600&family=IBM+Plex+Sans:wght@400;600&family=Pixelify+Sans:wght@500;600&display=swap">
<style>{CSS}</style>
<main>
  <section class="intro">
    <h1>Boss Bar Prototipleri</h1>
    <p class="lede">Boss savaşında iki çubuk olacak: ekranın üst ortasında boss'un adıyla duran büyük bar ve boss'un üstünde kalan bar. Sekiz prototipin hepsi oyunun ahşap ve demir paletiyle, kendi piksel ızgarasında çizildi ve oyundan alınmış gerçek karelerin üstüne yerleştirildi. Görsellere tıklayınca 2 kat büyür.</p>
    <ul class="facts">
      <li><strong>Kalkan ayrı bir katman</strong>Boss kalkanı hasarın %90'ını emer, havuzu canın yaklaşık 1,4 katıdır ve bir süre sonra yenilenir. Bu yüzden her tasarımda kalkan canın yanında ayrı gösteriliyor.</li>
      <li><strong>Bazen birden fazla boss var</strong>Final'de 13 boss birden doğar, 12. ve 15. kademede ikişer boss çıkar. Üst bar tek boss için çizildi, çoklu boss görünümü her prototipte ayrıca var.</li>
      <li><strong>Yerleşim</strong>Üst bar FPS göstergesinin altında, ekranın üstünden 40 piksel aşağıda başlıyor. Boss üstü bar, boss'un kafasının 12 piksel üstünde duruyor.</li>
    </ul>
    <div class="legend" aria-label="Gösterilen dört durum">
      <span>Kalkan tam</span><span>Kalkan eriyor</span><span>Kalkan kırıldı</span><span>Can kritik</span>
    </div>
  </section>

  <section class="section" id="simdi">
    <header>
      <h2>Şu an oyunda olan</h2>
    </header>
    <div class="current">
      {fig("current_single.png", "Mevcut boss çubuğu (golem)", *S["current_single.png"])}
      <p class="note">Mevcut bar 88 piksel genişliğinde, ince bir kırmızı çubuk ve altında ince bir kalkan çizgisi. Golemde kafanın yaklaşık 100 piksel üstünde duruyor, yani bossa bağlı olduğu zor anlaşılıyor. Sıradan yaratıkların çubuğuyla aynı dili konuşuyor.</p>
    </div>
  </section>

  <section class="section" id="ust">
    <header>
      <h2>Üst orta boss barı</h2>
      <p>Boss aktifken ekranın üst ortasında durur. Her prototip için oyun içi görünüm, dört durum ve çoklu boss görünümü var.</p>
    </header>
    {''.join(top_block(*t) for t in TOPS)}
  </section>

  <section class="section" id="ustu">
    <header>
      <h2>Boss'un üstündeki bar</h2>
      <p>Bossun üzerindeki çubuk kalıyor ama artık sıradan yaratıklardan ayrışıyor. Üst barla aynı aileden seçersen takım gibi durur: ahşap için T1 ile O2, demir için T2 ile O1 veya O3, sade için T4 ile O4.</p>
    </header>
    {''.join(world_block(*w) for w in WORLDS)}
  </section>
</main>
<script>{JS}</script>
"""

with open(os.path.join(SP, "site", "index.html"), "w", encoding="utf-8") as f:
    f.write(page)
print("ok", len(page))
