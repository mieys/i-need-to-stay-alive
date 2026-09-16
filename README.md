# Vampire Survivors Co-op — Temel Proje

## ÖNEMLİ: nasıl güncellersin

Eski `vs-coop` klasörünü SİL ve bu zip'i tamamen yeni/boş bir yere aç,
sonra Godot'ta öyle aç.

## Bu güncellemede yapılan asıl düzeltme

Gördüğün `GameManager not declared` hatası, benim `project.godot`
dosyasına elle yazmaya çalıştığım tuş atama (Input Map) kısmının
formatının tam tutmamasından kaynaklanıyordu — bu da dosyanın geri
kalanının (autoload dahil) okunamamasına yol açmış. O riskli kısmı
tamamen kaldırdım. Bunun bedeli: **tuş atamalarını artık elle,
editörden yapman gerekiyor** (bir defalık, 2 dakikalık bir iş):

1. Üstteki **Project → Project Settings...**'e tıkla.
2. **Input Map** sekmesine geç.
3. Üstteki kutuya `move_left` yaz, **Add**'e bas. Sağındaki `+`
   ikonuna tıkla, klavyeden **A** tuşuna bas, **OK**.
4. Aynı şekilde `move_right` → **D**, `move_up` → **W**,
   `move_down` → **S** ekle.
5. **Close**.

Bunu yapmazsan karakter hareket etmez ama proje açılır ve diğer her
şey (autoload, kartlar, animasyonlar) çalışır.

## Bu güncellemede ne değişti

1. **Ayı karakter sprite'ı eklendi.** Gönderdiğin sprite sheet'in
   arkaplanını temizleyip (checkerboard'ı şeffaf yaptım) 4 animasyona
   böldüm:
   - Satır 1 → **idle** (bekleme)
   - Satır 2 → **walk** (yürüme)
   - Satır 3 → **attack** (yumruk — ateş etme anı bu animasyonu tetikliyor)
   - Satır 4 → **death** (ölüm) — *not: bu satır görsel olarak tam bir
     "ölüm" pozu değil, daha çok kükreme/tepki gibi duruyordu ama elimizdeki
     4 animasyondan en uygun boşluğa onu yerleştirdim. Gerçek bir ölüm
     animasyonu istersen arkadaşından ayrıca isteyebilirsin, tek satırı
     değiştirmek yeterli olur.
   - Karakter artık sağa/sola baktığında görsel olarak da dönüyor (flip).

2. **Yumruk atınca ateş ediyor.** Silah otomatik ateş ettiği anda
   "attack" animasyonu tetikleniyor — yani ayı yumruk attığı anda mermi
   çıkıyor, senin istediğin gibi.

3. **Muhtemel bulduğum bug'ı düzelttim.** Önceki sürümde düşman spawn
   sistemi (`enemy_scenes`) bir "dizi" (array) olarak sahne dosyasına elle
   yazılmıştı. Bu format bazı Godot sürümlerinde düzgün ayrıştırılamayıp
   sessizce boş kalabiliyor — bu da hiç düşman doğmaması, dolayısıyla hiç
   XP toplanmaması, dolayısıyla hiç seviye atlanmaması anlamına geliyordu.
   Bunu 3 ayrı, tekil alana böldüm (çok daha güvenilir bir yöntem).
   **Eğer bu güncellemeden sonra da düşmanlar doğmuyorsa** (kırmızı/sarı/
   mor daireler ekranda görünmüyorsa), `EnemySpawner` node'unu seçip
   Inspector'da `Enemy Scene Normal / Fast / Tank` alanlarının dolu
   olduğunu kontrol et.

4. **Karakter nitelikleri ve geliştirme kartları çalışır durumda:**
   - Can (max_health)
   - Hareket hızı (speed)
   - Hasar (silahın mermi hasarı)
   - Ateş hızı (ne sıklıkla ateş ettiği)
   
   Seviye atladığında bu 4 nitelikten rastgele 3'ü kart olarak çıkıyor,
   birini seçiyorsun, o nitelik kademeli olarak artıyor. Ekranın sol
   üstünde güncel nitelik değerlerini de küçük bir yazıyla gösteriyorum.

## Nasıl açılır

1. Godot'u aç, **Import** butonuna tıkla, bu klasördeki `project.godot`
   dosyasını seç.
2. F5 / ▶ ile çalıştır, **BAŞLAT** butonuna bas.
3. WASD ile hareket et, ayı otomatik olarak en yakın düşmana yumruk
   atarak ateş eder.

## Klasör yapısı

```
vs-coop/
  project.godot
  assets/sprites/bear.png   → arkaplanı temizlenmiş ayı sprite sheet'i
  scenes/                   → .tscn sahne dosyaları
  scripts/                  → .gd script dosyaları
```

## Hâlâ eksik olanlar

- Gerçek bir tile-based harita (şu an sadece dekoratif şekiller)
- Düşmanlar için gerçek sprite/animasyon (hâlâ renkli daire)
- Co-op / multiplayer

Takıldığın ya da beklediğin gibi çalışmayan bir şey olursa, ekranda
tam olarak ne gördüğünü söyle — birlikte bakarız.

## Bu güncellemede eklenenler

- **Gerçek harita dokusu.** Gönderdiğin çim/ağaç/kaya görseli artık
  arka planda, 3000x3000'lik bir alanda döşenerek (tile) tekrarlanıyor
  (öncekinden daha geniş bir alan). Dürüst olmak gerekirse: bu görsel
  "seamless" (kenarları birbirine kusursuz uyan) bir doku olarak
  üretilmemiş, o yüzden döşenince aynı ağaç/kaya dizilimi belirli
  aralıklarla tekrar ediyor — biraz "kopyala-yapıştır" hissi verebilir.
  İleride gerçek bir TileMap'e ya da seamless bir zemin dokusuna
  geçince bu çözülür.
- **Animasyon hizalama düzeltmesi.** Her karedeki ayı figürünü ayak
  hizasına göre yeniden ortaladım, "zıplama" hissi büyük ölçüde azaldı.
  Idle animasyonunu da artık tek bir sabit kare olarak kullanıyorum
  (önceki 5 kare aslında farklı açılardan çizilmiş bir "turnaround"
  sayfasıydı, animasyon değil — o yüzden idle'da karakter "yer
  değiştiriyormuş" gibi görünüyordu). Yürüme ve yumruk animasyonlarında
  hâlâ hafif bir titreşim hissedebilirsin çünkü orijinal sprite
  sheet'teki bazı kareler hücre sınırına çok yakın çizilmiş (parmak
  ucu/vuruş çizgisi gibi detaylar kırpılabiliyor) — bunun kalıcı çözümü
  arkadaşının kareleri biraz daha boşluklu (padding'li) çizmesi olur.

## Harita düzeltmesi (tile tekrarı sorunu)

Eski harita, tüm sahneyi (ağaç+kaya+çim) tek parça olarak döşüyordu, bu
yüzden aynı dizilim tekrar tekrar görünüyordu. Şimdi:

- **Zemin artık sadece düz çim** — `assets/tiles/ground_tile.png`
  (300x300, objesiz bir alandan kesildi), bu çok daha az fark
  edilir şekilde döşeniyor.
- **Ağaç/kaya/çalılar artık ayrı, tekil objeler** — orijinal görselden
  12 farklı obje (3 yuvarlak ağaç, 3 çam, 3 kaya öbeği, 1 tekil kaya,
  2 çalı) otomatik olarak kesilip kenarları yumuşatıldı
  (`assets/decor/`), sonra haritaya 38 farklı noktaya, rastgele
  karışım ve bazılarında ayna (flip) uygulanarak serpiştirildi.
  Artık hiçbir yerde "aynı sahne" birebir tekrarlanmıyor.
- Oyuncunun başlangıç noktası (harita merkezi) bilerek boş bırakıldı.

## Süs objeleri artık engel

Ağaç/kaya/çalıların hepsine görünmez bir çarpışma alanı (StaticBody2D +
CollisionShape2D, daire şeklinde) ekledim. Çember, objenin görsel
tabanına (gövde/kaya kısmına) yakın duracak şekilde ayarlı — yani
karakter artık bir ağacın gövdesinden geçemiyor ama tepesindeki
yapraklara kısmen "değebilir" gibi görünebilir (top-down oyunlarda
normal bir durum, gerçek bir sorun değil). Düşmanlar da aynı çarpışmaya
tabi, yani onlar da ağaçların içinden geçemeyecek.

Not: Mermiler (Area2D oldukları için) şu an ağaçlardan geçip gidiyor,
onları durdurmuyor — bunu da istersen ayrıca ekleyebiliriz.

## Karakter sistemi (yeni)

Ayı çıkarıldı, yerine gönderdiğin 6 karakterli paket geldi. Artık:

- **Başlangıç akışı değişti:** Ana menü → BAŞLAT → **Karakter Seç
  ekranı** (6 portreden birine tıkla) → oyun başlıyor.
- Her karakterin **idle** ve **koşma** animasyonları 3 yöne göre
  (aşağı/yan/yukarı) ayrı ayrı çalışıyor, yana bakarken otomatik
  ayna (flip) uygulanıyor.
- **Yumruk/saldırı animasyonu yok** çünkü pakette böyle bir animasyon
  yoktu (sadece idle + run var). Bunun yerine ateş ettiğinde karakter
  hafifçe "zıplıyor" (küçük bir ölçek animasyonu) — basit ama fark
  edilir bir geri bildirim. İstersen ayrıca bir saldırı animasyonu
  paketi bulup gönderirsen entegre ederim.
- **Ölüm animasyonu da yok**, onun yerine karakter yavaşça saydamlaşıp
  kayboluyor (fade out).
- Karakterler `assets/characters/` klasöründe: her biri için bir
  atlas dokusu (`charN_atlas.png`) ve bir animasyon tanımı
  (`charN_frames.tres`).

## Büyük güncelleme: nitelikler, aktif yetenekler, harita sınırı

### Harita sınırı
Haritanın 4 kenarına hem görsel bir orman/kaya şeridi (166 obje)
hem de görünmez, kesinlikle geçilemeyen bir sınır duvarı ekledim.
Artık boşluğa düşmek ya da haritanın "sonsuz" gibi hissettirmesi
mümkün değil.

### Yeni nitelikler (kart havuzuna eklendi)
- **Can Yenilenmesi** — saniyede otomatik can doldurur
- **Kritik Oran** — mermilerin kritik vuruş yapma ihtimali (başlangıç %5)
- **Kritik Hasar** — kritik vurunca ne kadar fazla hasar verdiği çarpanı
  (başlangıç 1.5x). Kritik mermiler turuncu/kırmızı renkte ve biraz
  daha büyük görünüyor.

Artık toplam 8 farklı kart tipi var, seviye atlayınca bunlardan
rastgele 3'ü çıkıyor.

### Karakterlere özel aktif yetenek (R tuşu = ulti, E tuşu = temel)
Her karakterin kendine özgü bir ulti yeteneği var (R tuşu). Bazı
karakterlerin (örn. Öykü) ayrıca kısa süreli/az bekleme süreli bir de
temel yeteneği var (E tuşu) - bu not aşağıdaki listede güncel değil,
güncel liste için Characters.DEFS'e (scripts/characters.gd) bak.
HUD'da sol altta "Ulti: HAZIR / AKTİF / bekleniyor" ve (varsa) "Temel:
..." durumunu görebilirsin.

1. **Can Basma** — anında canın %30'unu doldurur + 10 saniye boyunca
   ekstra can yenilenmesi (yeşil parçacık efekti)
2. **Öfke** — 10 saniye boyunca hasar %30 artar, karakter kırmızımsı
   bir tona bürünür
3. **Hızlı Ateş** — 10 saniye boyunca çok daha sık ateş eder, karakter
   sarımsı bir tona bürünür
4. **Kalkan** — 10 saniye boyunca hiç hasar almaz, etrafında mavi bir
   kalkan halkası belirir
5. **Görünmezlik** — 10 saniye boyunca düşmanlar saldıramaz ve
   karakter düşmanların içinden geçebilir, karakter yarı saydam olur
6. **Rüzgar Hızı** — 10 saniye boyunca hareket hızı çok artar, karakter
   açık maviye bürünür

Her yetenek aktifleşince rengarenk bir parçacık patlaması efekti de
oynuyor.

### Teknik not: çarpışma katmanları
Bu özellikleri (özellikle görünmezlik) doğru çalıştırmak için
oyuncu/düşman/dünya/mermi için ayrı çarpışma katmanları kurdum. Bunu
fark etmene gerek yok ama bir şey bozulursa bilmen için not düşüyorum.

## Düzeltme: hasar almama ve düşmanlara yapışma sorunu

- Oyuncu ile düşmanlar art\u0131k fiziksel olarak \u00e7arp\u0131\u015fm\u0131yor
  (Vampire Survivors'daki gibi \u00fczerinizden ge\u00e7ip y\u0131\u011f\u0131labiliyorlar).
  Bu, hem "yap\u0131\u015f\u0131p kalma" hissini d\u00fczeltti hem de temas hasar\u0131n\u0131n
  g\u00fcvenilir \u00e7al\u0131\u015fmas\u0131n\u0131 sa\u011fl\u0131yor.
- D\u00fc\u015fmanlar\u0131n "hasar alan\u0131" art\u0131k g\u00f6rsel boyutlar\u0131ndan biraz daha
  b\u00fcy\u00fck \u2014 boyle boyle art\u0131k her temasta g\u00fcvenilir \u015fekilde tetikleniyor.
- D\u00fc\u015fmanlar hala a\u011fa\u00e7/kaya gibi harita engellerinden ge\u00e7emiyor,
  sadece oyuncuyla fiziksel olarak \u00e7arp\u0131\u015fm\u0131yorlar.

## Dev güncelleme: font, ses, düşman karakteri, arayüz

### Pixel font
Gönderdiğin "Pixelify Sans" fontu tüm oyuna uygulandı (proje ayarlarından
global tema olarak). Butonlar ve panellere de ahşap/orman temasına uygun
kalın kenarlı, köşeli bir görünüm verdim.

### Ses efektleri
- Ateş edince "atesetme.mp3" çalıyor (her atışta hafif ton farkıyla, tekdüze olmasın diye)
- Seviye atlayınca "levelatlama.mp3" çalıyor

### Düşman karakteri değişti
Renkli daireler yerine artık gönderdiğin Orc paketindeki gerçek
animasyonlu karakteri kullanıyorlar (yürüme, hasar alma, ölüm
animasyonları dahil). 3 tür hâlâ var ama artık boyut/renk tonuyla
ayrılıyorlar: normal (doğal renk), hızlı (küçük, sarımsı), tank
(büyük, morumsu). Hepsi ana karakterle orantılı boyutta.

### XP toplama sistemi
- Yeni "Toplama Mesafesi" statı kart havuzunda
- XP parçaları artık belirli bir mesafeye girince yumuşak bir şekilde
  sana doğru süzülüyor (aniden ışınlanmıyor)
- Nadiren (%4) düşmanlardan yiyecek düşüyor (anında can verir),
  daha nadir (%3) mıknatıs düşüyor (haritadaki TÜM XP'leri anında çeker)

### Can/XP barları
Gönderdiğin görsele benzer şekilde yeniden çizildi (ahşap çerçeve,
kalp/yıldız ikonu, yeşil/mavi dolgu) ve ekranın alt sol köşesine
taşındı. Dolumu artık ani değil, yumuşak bir animasyonla akıyor.

### Yetenek ikonları + dolum animasyonu
Her karakterin yeteneği için elle çizilmiş bir ikon var (kalp, alev,
şimşek, kalkan, göz, rüzgar) ve etrafında yetenek hazır olana kadar
dairesel bir dolum animasyonu dönüyor.

### Duraklatma menüsü
Oyun içinde ESC tuşuna basınca duraklıyor, "Devam Et / Yeniden Başla /
Ana Menü" seçenekleri çıkıyor.

### Karakter seçim ekranı
Artık her karaktere tıklayınca sağda/altta o karakterin yeteneğinin
adını ve açıklamasını gösteren bir bilgi paneli var, seçimini
onaylamak için ayrı bir BAŞLA butonuna basıyorsun.

### Harita kenarı
Haritanın dışı artık su gibi görünüyor (mavi, hafif dalgalı doku),
kenarlardaki boşluk hissi tamamen ortadan kalktı.

## Bilinen küçük eksikler
- Mermiler hâlâ ağaçlardan geçiyor (durdurmuyor)
- Enemy paketindeki "Attack" animasyonu kullanılmadı (düşmanlar sadece
  temas hasarı veriyor, saldırı animasyonu oynatmıyorlar) — istersen
  sonra ekleriz

## Dükkan sistemi + can barı düzeni + bug fix

### Can/XP barı düzeni değişti
- Can barı artık **küçük, sol üstte** (level yazısının hemen altında)
- XP barı **aynı yerde (altta)** ama daha ince

### Spawn bug'ı düzeltildi
Düşmanlar artık haritanın/suyun dışında asla doğmuyor — spawn
pozisyonu her zaman harita sınırları içinde kalacak şekilde
sınırlandırıldı.

### Altın ve Dükkan
Düşmanlar artık nadiren (%15) altın da düşürüyor. Ekranın sağ
üstünde bir **DÜKKAN** paneli var, oyunu duraklatmadan, savaşırken
bile kullanılabiliyor:

1. **Maden** — pasif gelir. Seviyesi kadar altını her 5 saniyede bir
   kazandırır (Lv1 = 5sn'de 1 altın, Lv50 = 5sn'de 50 altın). 100
   seviyeye kadar geliştirilebilir, her seviye biraz daha pahalı
   (fiyat = 10 × hedef seviye).
2. **İtici Sprey** — 10 saniyede bir, yakınındaki tüm düşmanları
   senden uzaklaştırır. 10 seviyeye kadar geliştirilebilir (menzil ve
   itme gücü artar), fiyatı Maden'den daha hızlı artıyor (fiyat = 50 ×
   hedef seviye).
3. **Sihirli Kalkan** — ayrı bir can havuzu (başlangıç 100), gelen
   hasarı önce o emer, ana canına dokunulmaz. Kırıldıktan sonra 6
   saniye hiç hasar almazsan hızlıca yenilenmeye başlar. 100 seviyeye
   kadar geliştirilebilir, her seviye maksimum kalkan canını artırır
   (fiyat = 15 × hedef seviye). Kalkanın kendine özel, mavi bir can
   barı var (sol üstte, can barının hemen altında — sadece kalkanı
   satın aldıysan görünür).

**Not:** Altın ve dükkan seviyeleri şu an sadece o oyun oturumu
boyunca geçerli — yeniden başlatınca (ya da ana menüye dönünce)
sıfırlanıyor. Kalıcı bir kayıt sistemi (save file) istersen ayrı bir
iş olarak ekleyebiliriz, biraz daha karmaşık bir konu.

## XP orb'ları, çoklu düşme, dolum göstergesi, arayüz büyütme

- **XP orb'ları artık güce göre büyüyor/renk değiştiriyor** — düşük
  XP değerli orb'lar küçük ve açık yeşil, yüksek değerliler daha
  büyük ve turuncuya kayıyor.
- **Tank düşman artık 3 ayrı orb düşürüyor** (öncekiler tek orb
  düşürüyordu, çoğu XP'yi kaçırmak daha kolaydı).
- **Maden itemi artık "dolan bir gösterge, her dolumda 1 altın"
  mantığıyla çalışıyor** — seviyen ne kadar yüksekse gösterge o kadar
  hızlı doluyor (Lv1 = 5 saniyede bir dolar, Lv10 = yarım saniyede bir
  dolar), her dolumda 1 altın kazanıyorsun. Gösterge, Maden satırındaki
  butonun hemen üstünde küçük bir çubuk olarak görünüyor.
- **Hasar/can/altın yazıları büyütüldü, yavaşlatıldı ve "pop" efekti
  eklendi** — artık aniden belirip hızla kaybolmuyorlar, biraz daha
  yumuşak bir şekilde büyüyüp yükseliyor ve yavaşça soluyorlar.
- **Tüm arayüzler büyütüldü**: HUD, ana menü, karakter seçimi,
  duraklatma menüsü, seviye atlama kartları, dükkan paneli — hepsinde
  yazı ve buton boyutları belirgin şekilde arttı.

## Kalıcı düşmeler + yeni dükkan tasarımı

- Yiyecek, mıknatıs ve altın artık **süresiz** — toplayana kadar
  yerde kalıyorlar, otomatik kaybolmuyorlar.
- Dükkan paneli gönderdiğin görsele göre yeniden tasarlandı: her item
  artık kendi kart panelinde, üstte elle çizilmiş büyük bir ikonu
  (Maden=altın parası, İtici Sprey=sprey şişesi+itme okları, Sihirli
  Kalkan=parıltılı kalkan), altında ismi ve seviyesi, en altta da
  küçük bir altın ikonu + fiyatı gösteren geniş bir buton var.

## Karakterler değişti + dükkan çerçevesi güncellendi

### Yeni ana karakterler
Gönderdiğin hayvan paketinden 5 karakter geldi: Tavşan, Yaban Domuzu,
Tilki, Geyik, Orman Tavuğu (kuş). 6 karaktere ihtiyacımız olduğu için
Tilki'yi bir kez daha, farklı (koyu/gümüşi) bir renk tonuyla altıncı
karakter olarak kullandım.

E�leşme (yetenekler aynı kaldı, sadece görseller değişti):
1. Tavşan — Can Basma
2. Yaban Domuzu — Öfke (bu karakterin gerçek bir yumruk/saldırı
   animasyonu vardı, onu da entegre ettim — ateş edince o animasyonu
   oynatıyor)
3. Tilki — Hızlı Ateş
4. Geyik — Kalkan
5. Orman Tavuğu — Görünmezlik
6. Tilki (koyu ton) — Rüzgar Hızı

Diğer 4 karakterin saldırı animasyonu olmadığı için (senin de dediğin
gibi) onlara eklemedim, ateş edince hâlâ küçük bir "zıplama" efekti
oluyor.

### Dükkan çerçevesi
Gönderdiğin ahşap çerçeveyi dükkan panelinin arka planı yaptım (nine-patch
olarak, yani panel boyutu değişse de çerçeve bozulmadan esniyor).
İçindeki 3 item kartı (ikon + isim + fiyat butonu) olduğu gibi kaldı,
sadece artık bu çerçevenin içinde duruyor.

## Silah yuvası arkı (Vampire Survivors tarzı)

Gönderdiğin mavi ark görselini karakterin başının üstüne yerleştirdim,
asa ikonunu da ortadaki (en yüksek) yuvaya koydum. Artık:

- Ateş edince asa, hedef düşmana doğru dönüyor (görselin orijinal
  çapraz duruşunu ölçüp buna göre hesapladım, yanlış yöne bakmamalı).
- Ateş edince artık **karakter büyümüyor**, bunun yerine asa küçük
  bir "zıplama" (pulse) efekti yapıyor.
- Diğer 4 boş yuva şimdilik boş duruyor — ileride birden fazla silah
  sistemi eklersen (örn. ikinci bir silah türü), o yuvalara yerleştirmek
  için hazır bir altyapı.
