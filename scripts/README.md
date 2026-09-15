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
