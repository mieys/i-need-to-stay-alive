# HARİTA SEÇİMİ (madde 444'ten beri, çok oturumlu iş)

Kullanıcı (2026-11-07): "oda kurarken harita seçip öyle başlatsak bu harita da seçeneklerden biri olsa" -> "başlayalım". Cila dönemi
hatırlatıldı. İlk alternatif harita: **Kadim Derinlikler** (madde 442, `tools/zindan/gen_kadim_derinlikler.py`, zindan biçimli: DungeonData
hücre kodları + pişmiş sahne).

## İlke
- Ana harita seçiliyken oyun BİREBİR bugünkü gibi çalışır (her adımda başsız duman testiyle karşılaştırılır).
- Tek kaynak: `scripts/map_profiles.gd` (profil = sahne, veri, tür, özellik bayrakları). Haritaya özgü bir sistem "ana haritada mıyım"
  diye değil, profilin bayrağına bakar (`MapProfiles.feature("...")`).
- `main.tscn`'e dokunulmaz (editör açıksa dışarıdan düzenleme ezilir): ana harita sahnede gömülü kalır, başka harita seçiliyse `Main._enter_tree`
  onun yerine seçilen sahneyi koyar (aynı ad "Harita", aynı sıra).

## Adımlar
1. **Profil + yükleme** (madde 444, BİTTİ): `map_profiles.gd`, `GameManager.selected_map`, `HARITA=<id>` ortam değişkeni (geliştirme), Main'de
   harita değişimi, yükleme ekranı seçilen sahneyi iş parçacığında yükler, orman görselleri bayrağa bağlı.
2. **Oynanabilirlik (Kadim Derinlikler)**: çarpışma/mermi/görüş (orman katmanı yerine DungeonData hücreleri - `GameManager.get_forest_layer`
   ve `is_position_blocked_*` profilden), EnemyPathing + C++ EnemyWorld ızgarası, görüş sisi (vision_occluders extra_cells), kamera/oyun
   alanı (`get_map_world_rect`), doğuş (`dogus` nesnesi; ev açılışı yok), yaratık halka doğuşu duvara düşmesin, minimap (veriden doku),
   aydınlatma (dungeon_light gibi), "yeraltı" (hava/güneş/şimşek/akarsu yok), kapı/sandık/sunak/tuzak/kaynak/avcı/sakin (DungeonManager
   mantığı), saklanma yerleri. Ana haritaya özgüler kapalı: ev + kuşatma + babaanne, madenler, çalılıklar, derin orman + 3 zindan girişi,
   kenar bekçileri, seyyar satıcı (yer seçilene kadar), görevler (alan işaretleri gelene kadar).
3. **Seçim arayüzü + ağ**: oda kur formu + tek oyunculu ekran harita kartları, oda listesinde harita adı, `selected_map` host'tan herkese
   (oda bilgisi + lobi protokolü), geç katılan / yeniden bağlanan / host devri aynı haritayı yükler.
4. **Görevler**: üreteç görev alanı nesneleri yazar (salon = bayrak/alan/ağaç, yol = konvoy, küme = topla), görev yöneticisi profildeki
   alanlardan seçer; Ağacı Koru'nun görseli zindan sanatıyla ya da bu haritada kapalı.
5. **Test**: duman testi iki harita, `run_audit` çok oyunculu, FPS (276 ışık), denge.

İlerleme: `ILERLEME.md`.
