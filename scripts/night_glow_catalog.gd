extends RefCounted

## Gece ışıkları kataloğu - HANGİ efekt/mermi/obje karanlıkta ne renkte, ne büyüklükte parlar: TEK liste.
## (Kullanıcı isteği 2026-09-25: "tüm skill atışları ve efektleri parıltılı olacak karanlıkta ... ateş asası, buz
## asası, yıldırım asası, tabanca, tüfek, havai fişek de aynı şekilde mermilerinde ve uçlarında parıltı yayacak
## (tüfek ve tabanca ateşlenince ucunda parıltı olacak)" + soru-cevapta seçilen ek ışıklar: görev objeleri ve düşman
## büyüleri. XP/altın/sandık ve satıcı/ev ışıkları SEÇİLMEDİ.)
##
## NASIL ÇALIŞIR: atmosphere.gd sahne ağacına eklenen HER düğüme bakar (SceneTree.node_added) - düğüm buradaki bir
## SAHNE yolundan (scene_file_path) ya da SCRIPT yolundan üretilmişse ona night_glow.gd ışığı takar. Diğer
## oyunculardaki kozmetik kopyalar (broadcast_projectile / broadcast_player_vfx "muzzle_flash", "skill_scene",
## "hitscan_impact" ...) AYNI sahne/script yolundan üretildiği için ışık orada da KENDİLİĞİNDEN oluşur - CLAUDE.md'deki
## "kaster doğru görür, diğer oyuncular görmez" hata sınıfına karşı bilinçli olarak tek yerde.
##
## YENİ BİR EFEKT EKLERKEN: scenes/fx_*.tscn ise listede olmasa da DEFAULT_FX_SCENE ile hafif beyazımsı parlar - doğru
## rengi/boyu için BY_SCENE'e ekle; parlamaması gerekiyorsa (kan, toz, duman, gizlilik) NO_GLOW_SCENES'e ekle.
## Kodla kurulan (sahnesiz) efektler SADECE BY_SCRIPT'te listelenirse parlar.
##
## Profil anahtarları: c = renk, r = yarıçap (DÜNYA birimi; karakter ~30 birim boyunda), e = merkez gücü 0..1,
## f = titreme 0..1, d = flaş süresi (sn, >0 ise doğrusal söner), o = ofset (sahibin YEREL koordinatı),
## fog = sisin içindeyken hiç çizilmesin (düşman büyüleri - gizli yaratığın yerini ele vermesin),
## cap = bu ışığa özel güç tavanı (atmosphere_overlay.gd GLOW_ENERGY_CAP yerine) - sadece kısa patlama flaşlarında, bkz.
## fx_fire_impact notu; tavanı aşmak için "e" 1'in üstüne çıkabilir,
## cp = rengi sahibin bu alanından oku, rp = yarıçapı sahibin bu alanından oku (x rs çarpanı),
## pal = fx_pixel_burst palet adı -> renk (listede olmayan palet parlamaz),
## frames = fx_enemy_ability'nin SpriteFrames yolundaki parça -> profil (listede olmayan parlamaz).

## Listede olmayan yeni bir scenes/fx_*.tscn için varsayılan: hafif, nötr-sıcak bir parıltı.
const DEFAULT_FX_SCENE := {"c": Color(1.0, 0.92, 0.75), "r": 34.0, "e": 0.45}

## Karanlıkta ışık saçmaması gereken efekt sahneleri: kan, toz/duman, ölüm, fiziksel (çelik) yakın dövüş savuruşları,
## gizlilik (Assasin'in gizlenmesi parlarsa gizlilik anlamsızlaşır), hız çizgisi, arbalet (ateşli/büyülü değil).
const NO_GLOW_SCENES := [
	"res://scenes/fx_blood_splatter.tscn",
	"res://scenes/fx_hit_blood_1.tscn",
	"res://scenes/fx_hit_blood_2.tscn",
	"res://scenes/fx_hit_blood_3.tscn",
	"res://scenes/fx_death.tscn",
	"res://scenes/fx_korsan_puff_dust.tscn",
	"res://scenes/fx_korsan_puff_smoke.tscn",
	"res://scenes/fx_totem_collapse_dust.tscn",
	"res://scenes/fx_totem_plant_dust.tscn",
	"res://scenes/fx_assasin_stealth.tscn",
	"res://scenes/fx_assasin_slash.tscn",
	"res://scenes/fx_pence_slash.tscn",
	"res://scenes/fx_sovalye_slash.tscn",
	"res://scenes/fx_topuz_slash.tscn",
	"res://scenes/fx_uzunkilic_slash.tscn",
	"res://scenes/fx_crossbow_muzzle.tscn",
	"res://scenes/fx_speed_line.tscn",
	"res://scenes/fx_mage_swap.tscn",
	## Oakley Sarmaşıklar'ın yaratığa sarılan dikenleri - bitki, büyü değil.
	"res://scenes/fx_oakley_entangle.tscn",
	## Suriyeli Hadime: lanet kıvılcım izi (saniyede ~20 minik düğüm - her birine ışık takılmasın, lanetin kendisi parlar),
	## Q'daki karanlık uçma parçacıkları ve Karabasan'ın karanlık aurası/patlaması (karanlık - ışık saçmaz).
	"res://scenes/fx_hadime_curse_mote.tscn",
	"res://scenes/fx_hadime_levitate.tscn",
	"res://scenes/fx_hadime_nightmare.tscn",
	"res://scenes/fx_hadime_nightmare_burst.tscn",
]

const BY_SCENE := {
	## --- Silah mermileri (kullanıcı: "mermilerinde parıltı") ---
	"res://scenes/fire_projectile.tscn": {"c": Color(1.0, 0.56, 0.2), "r": 44.0, "e": 0.9, "f": 0.25},
	"res://scenes/ice_bolt_projectile.tscn": {"c": Color(0.5, 0.85, 1.0), "r": 40.0, "e": 0.85},
	"res://scenes/tabanca_projectile.tscn": {"c": Color(1.0, 0.82, 0.5), "r": 22.0, "e": 0.8},
	"res://scenes/tufek_projectile.tscn": {"c": Color(1.0, 0.82, 0.5), "r": 24.0, "e": 0.8},
	## Havai fişek: fitil kıvılcımı (sahnedeki Sparkle düğümü (2,24)'te) - titrek sıcak ışık.
	"res://scenes/firework_projectile.tscn": {"c": Color(1.0, 0.72, 0.35), "r": 40.0, "e": 0.9, "f": 0.45, "o": Vector2(2.0, 24.0)},
	## Arcane: mor ışığın parlaklığı düşük kaldığı için (kullanıcı: "arcane asasına da diğerleri gibi karanlıkta parıldama
	## ekle", 2026-09-25) daha açık leylak ve daha güçlü - ateş asasıyla aynı algılanan parlaklıkta.
	"res://scenes/arcane_projectile.tscn": {"c": Color(0.78, 0.58, 1.0), "r": 46.0, "e": 1.0, "f": 0.15},
	"res://scenes/buyucu_projectile.tscn": {"c": Color(0.45, 0.5, 1.0), "r": 40.0, "e": 0.85},
	"res://scenes/korsan_bomb.tscn": {"c": Color(1.0, 0.6, 0.25), "r": 26.0, "e": 0.55, "f": 0.6, "o": Vector2(0.0, -8.0)},
	## --- Namlu ateşi (kullanıcı: "tüfek ve tabanca ateşlenince ucunda parıltı olacak") - kısa flaş ---
	"res://scenes/fx_revolver_muzzle.tscn": {"c": Color(1.0, 0.8, 0.45), "r": 60.0, "e": 1.0, "d": 0.14},
	"res://scenes/fx_tufek_muzzle.tscn": {"c": Color(1.0, 0.78, 0.42), "r": 72.0, "e": 1.0, "d": 0.16},
	## --- İsabet/patlama efektleri ---
	## Kullanıcı bildirimi (2026-09-25): "ateş topunun patlama efekti parlamıyor" - flaş çok kısa/küçüktü (0.45 sn, r 62).
	## İkinci bildirim (aynı gün): hâlâ parlamıyordu - (1) ışık patlama sprite'ı 0,5 sn'de gizlenince kesiliyordu (d hiç
	## işlemiyordu, bkz. fx_animation.gd _release_flash_glow), (2) r 84 x GLOW_RADIUS_SCALE 0,65 = 55 birim, patlamanın
	## kendi yarıçapı ~40 birim (50 px x 1,6) - ışık neredeyse tamamen sprite'ın altında kalıp zemine taşmıyordu.
	## Artık diğer patlamalarla (fişek/korsan 110) aynı: r 110 -> ~72 birim. (3) Genel GLOW_ENERGY_CAP (0,4) patlamayı uçan
	## ateş topunun ışığıyla (o da 0,4) AYNI parlaklığa eşitliyordu - gerçek render'da eski/yeni hale neredeyse aynıydı.
	## 0,75 sn'lik flaş olduğu için bu ışığa özel tavan 0,65 ("cap") + e 1,2 (0,56 x 1,2 = 0,67 -> tepe 0,65).
	"res://scenes/fx_fire_impact.tscn": {"c": Color(1.0, 0.55, 0.2), "r": 110.0, "e": 1.2, "d": 0.75, "f": 0.2, "cap": 0.65},
	"res://scenes/fx_ice_impact.tscn": {"c": Color(0.55, 0.88, 1.0), "r": 54.0, "e": 0.85, "d": 0.4},
	"res://scenes/fx_tabanca_impact.tscn": {"c": Color(1.0, 0.7, 0.35), "r": 30.0, "e": 0.8, "d": 0.18},
	"res://scenes/fx_hit_tabanca_combo.tscn": {"c": Color(1.0, 0.72, 0.38), "r": 30.0, "e": 0.8, "d": 0.18},
	"res://scenes/fx_hit_bullet_burst.tscn": {"c": Color(1.0, 0.72, 0.38), "r": 30.0, "e": 0.8, "d": 0.18},
	"res://scenes/fx_hit_mini_spark.tscn": {"c": Color(1.0, 0.82, 0.45), "r": 22.0, "e": 0.7, "d": 0.15},
	"res://scenes/fx_hit_slash_streak.tscn": {"c": Color(1.0, 0.6, 0.35), "r": 26.0, "e": 0.6, "d": 0.15},
	## Arcane asasının isabet patlaması - 2026-09-25'te efekt %40 küçültüldü (fx_hit_purple_burst.tscn scale 1.4 -> 0.84),
	## ışık yarıçapı da orantılı 50 -> 30.
	"res://scenes/fx_hit_purple_burst.tscn": {"c": Color(0.85, 0.6, 1.0), "r": 30.0, "e": 0.9, "d": 0.35},
	"res://scenes/fx_hit_big_burst.tscn": {"c": Color(1.0, 0.75, 0.45), "r": 100.0, "e": 1.0, "d": 0.6, "f": 0.2},
	"res://scenes/fx_fisek_impact.tscn": {"c": Color(1.0, 0.8, 0.45), "r": 110.0, "e": 1.0, "d": 0.7, "f": 0.2},
	"res://scenes/fx_korsan_puff_spark.tscn": {"c": Color(1.0, 0.65, 0.25), "r": 30.0, "e": 0.7, "d": 0.3},
	"res://scenes/fx_korsan_explosion.tscn": {"cp": "tint", "c": Color(1.0, 0.6, 0.2), "r": 110.0, "e": 1.0, "d": 0.7, "f": 0.2},
	"res://scenes/fx_korsan_strike.tscn": {"c": Color(1.0, 0.6, 0.2), "r": 60.0, "e": 0.8, "d": 0.4},
	"res://scenes/fx_korsan_zone.tscn": {"c": Color(1.0, 0.55, 0.25), "r": 70.0, "e": 0.4},
	"res://scenes/fx_meteor_strike.tscn": {"c": Color(1.0, 0.5, 0.2), "r": 130.0, "e": 1.0, "f": 0.25},
	"res://scenes/fx_frost_nova_burst.tscn": {"c": Color(0.5, 0.85, 1.0), "r": 110.0, "e": 0.9, "d": 0.7},
	## Sağanak yıldırımı (2026-09-25): uyarıda hafif, çarpmada güçlü, sonra söner - güç fx_storm_strike.gd
	## get_night_glow_energy() kancasından.
	"res://scenes/fx_storm_strike.tscn": {"c": Color(0.75, 0.85, 1.0), "r": 120.0, "e": 1.0},
	## --- Şimşek: nokta yerine ışın/zincir boyunca (sahibin get_glow_segment() kancası) ---
	"res://scenes/fx_lightning_beam.tscn": {"c": Color(1.0, 0.9, 0.45), "r": 34.0, "e": 0.9, "f": 0.35},
	"res://scenes/fx_lightning_chain.tscn": {"c": Color(1.0, 0.9, 0.45), "r": 30.0, "e": 0.85, "f": 0.35},
	## --- Karakter yetenekleri ---
	"res://scenes/fx_arcane_skull_bounce.tscn": {"c": Color(0.7, 0.35, 1.0), "r": 40.0, "e": 0.8},
	"res://scenes/fx_mage_passive_burst.tscn": {"c": Color(0.85, 0.6, 1.0), "r": 60.0, "e": 0.8, "d": 0.5},
	"res://scenes/fx_buyucu_fastfire.tscn": {"c": Color(1.0, 0.75, 0.2), "r": 44.0, "e": 0.7, "d": 0.5},
	"res://scenes/fx_buyucu_tornado.tscn": {"c": Color(0.75, 0.85, 1.0), "r": 60.0, "e": 0.35},
	"res://scenes/fx_elara_double.tscn": {"c": Color(1.0, 0.82, 0.35), "r": 40.0, "e": 0.6, "d": 0.5},
	"res://scenes/fx_elara_true.tscn": {"c": Color(1.0, 0.75, 0.25), "r": 50.0, "e": 0.75, "d": 0.6},
	"res://scenes/fx_assasin_dash.tscn": {"c": Color(0.62, 0.3, 0.9), "r": 30.0, "e": 0.35, "d": 0.4},
	"res://scenes/fx_assasin_shadow_hit.tscn": {"c": Color(0.6, 0.4, 0.85), "r": 28.0, "e": 0.4, "d": 0.3},
	"res://scenes/fx_kalkan_yenileme.tscn": {"c": Color(0.4, 0.75, 1.0), "r": 50.0, "e": 0.6},
	"res://scenes/fx_shield_active.tscn": {"c": Color(0.45, 0.7, 1.0), "r": 46.0, "e": 0.45},
	"res://scenes/fx_paladin_cast.tscn": {"c": Color(1.0, 0.88, 0.45), "r": 60.0, "e": 0.75, "d": 0.6},
	"res://scenes/fx_paladin_shatter.tscn": {"c": Color(0.5, 0.82, 1.0), "r": 60.0, "e": 0.75, "d": 0.5},
	## Şovalye Q (Kışkırtma, açık kırmızı) ve E açıkken Şovalye'nin emilim efekti (mor-mavi) - 2026-09-25.
	"res://scenes/fx_sovalye_taunt.tscn": {"c": Color(1.0, 0.42, 0.42), "r": 60.0, "e": 0.55, "o": Vector2(0.0, 30.0)},
	"res://scenes/fx_sovalye_guard.tscn": {"c": Color(0.55, 0.52, 1.0), "r": 44.0, "e": 0.45},
	## Suriyeli Hadime (2026-09-25): Q laneti (uçan küre + kitaptan çıkış + düşüş) hastalıklı yeşil, E kara deliğin
	## birikim diski mor (5 sn). Karabasan (R) bilerek parlamaz (bkz. NO_GLOW_SCENES).
	"res://scenes/fx_hadime_curse.tscn": {"c": Color(0.5, 1.0, 0.35), "r": 30.0, "e": 0.6},
	"res://scenes/fx_hadime_curse_launch.tscn": {"c": Color(0.55, 1.0, 0.4), "r": 34.0, "e": 0.55, "d": 0.3},
	"res://scenes/fx_hadime_curse_impact.tscn": {"c": Color(0.5, 1.0, 0.35), "r": 60.0, "e": 0.8, "d": 0.5},
	"res://scenes/fx_hadime_black_hole.tscn": {"c": Color(0.78, 0.45, 1.0), "r": 56.0, "e": 0.55, "f": 0.15},
	"res://scenes/fx_melek_holy.tscn": {"c": Color(1.0, 0.88, 0.4), "r": 80.0, "e": 0.85},
	"res://scenes/fx_melek_heal_aura.tscn": {"c": Color(0.55, 1.0, 0.5), "r": 55.0, "e": 0.5},
	"res://scenes/fx_melek_shield_aura.tscn": {"c": Color(0.4, 0.6, 1.0), "r": 55.0, "e": 0.5},
	"res://scenes/fx_oyku_heal.tscn": {"c": Color(0.45, 1.0, 0.55), "r": 55.0, "e": 0.6},
	"res://scenes/fx_recovery_life.tscn": {"c": Color(0.45, 1.0, 0.6), "r": 50.0, "e": 0.55},
	"res://scenes/fx_recovery_life_flower.tscn": {"c": Color(0.45, 1.0, 0.6), "r": 50.0, "e": 0.55},
	"res://scenes/fx_recovery_mana.tscn": {"c": Color(0.35, 0.95, 1.0), "r": 50.0, "e": 0.55},
	"res://scenes/fx_revive_heart.tscn": {"c": Color(1.0, 0.4, 0.55), "r": 50.0, "e": 0.65},
	"res://scenes/fx_revive_rewind.tscn": {"c": Color(0.85, 0.95, 0.5), "r": 60.0, "e": 0.65},
	"res://scenes/fx_necro_summon.tscn": {"c": Color(0.45, 0.85, 0.75), "r": 60.0, "e": 0.7, "d": 0.8},
	"res://scenes/fx_oakley_leaf_barrier.tscn": {"c": Color(0.55, 0.95, 0.4), "r": 44.0, "e": 0.35},
	## Oakley Q Arı Sürüsü (2026-09-25 ikinci tasarım: Oakley'yi takip eden minik arılar) - gövde çevresinde hafif bal ışığı.
	"res://scenes/fx_oakley_bee_guard.tscn": {"c": Color(1.0, 0.86, 0.4), "r": 40.0, "e": 0.3, "o": Vector2(0.0, -8.0)},
	## Oakley R kullanım anı (altın mühür + yaprak girdabı) - kısa, sıcak-yeşil parlama.
	"res://scenes/fx_oakley_ward_cast.tscn": {"c": Color(0.85, 1.0, 0.55), "r": 50.0, "e": 0.5, "d": 0.7},
	"res://scenes/fx_shaman_cast_area.tscn": {"c": Color(0.7, 0.5, 1.0), "r": 50.0, "e": 0.6, "d": 0.6},
	"res://scenes/fx_shaman_cast_attack.tscn": {"c": Color(1.0, 0.6, 0.25), "r": 50.0, "e": 0.6, "d": 0.6},
	"res://scenes/fx_shaman_cast_shield.tscn": {"c": Color(0.45, 0.72, 1.0), "r": 50.0, "e": 0.6, "d": 0.6},
	"res://scenes/fx_totem_rune_flash.tscn": {"c": Color(0.6, 0.85, 1.0), "r": 40.0, "e": 0.6, "d": 0.4},
	"res://scenes/fx_spirit_adc.tscn": {"c": Color(1.0, 0.5, 0.15), "r": 60.0, "e": 0.7},
	"res://scenes/fx_spirit_can.tscn": {"c": Color(1.0, 0.88, 0.45), "r": 60.0, "e": 0.7},
	"res://scenes/fx_spirit_dukkan.tscn": {"c": Color(0.7, 0.5, 1.0), "r": 60.0, "e": 0.7},
	"res://scenes/fx_spirit_taktik.tscn": {"c": Color(0.7, 0.55, 1.0), "r": 60.0, "e": 0.7},
	"res://scenes/fx_spirit_tank.tscn": {"c": Color(0.6, 0.8, 1.0), "r": 60.0, "e": 0.7},
	"res://scenes/fx_talha_rage.tscn": {"c": Color(1.0, 0.25, 0.15), "r": 50.0, "e": 0.6},
	"res://scenes/fx_talon_chains.tscn": {"c": Color(1.0, 0.6, 0.2), "r": 36.0, "e": 0.45},
	"res://scenes/fx_talon_dash.tscn": {"c": Color(1.0, 0.92, 0.6), "r": 36.0, "e": 0.55, "d": 0.4},
	"res://scenes/fx_talon_form.tscn": {"c": Color(1.0, 0.88, 0.5), "r": 55.0, "e": 0.6},
	"res://scenes/fx_matthew_explosion.tscn": {"c": Color(1.0, 0.6, 0.22), "r": 90.0, "e": 0.95, "d": 0.6},
	"res://scenes/fx_matthew_claw_slash.tscn": {"c": Color(1.0, 0.58, 0.2), "r": 40.0, "e": 0.7, "d": 0.3},
	"res://scenes/fx_matthew_fox_strike.tscn": {"c": Color(1.0, 0.6, 0.18), "r": 44.0, "e": 0.75, "d": 0.35},
	"res://scenes/fx_matthew_fox_afterimage.tscn": {"c": Color(1.0, 0.7, 0.4), "r": 26.0, "e": 0.35, "d": 0.3},
	"res://scenes/fx_matthew_fox_shield.tscn": {"c": Color(1.0, 0.6, 0.25), "r": 50.0, "e": 0.6},
	"res://scenes/fx_matthew_sacrifice.tscn": {"c": Color(1.0, 0.7, 0.3), "r": 70.0, "e": 0.8},
	"res://scenes/fx_wave_beam.tscn": {"c": Color(0.5, 1.0, 0.6), "r": 30.0, "e": 0.7},
	"res://scenes/fx_skill_burst.tscn": {"cp": "glow_color", "c": Color(1.0, 0.9, 0.7), "r": 60.0, "e": 0.75, "d": 0.8},
	"res://scenes/fx_skill_ring.tscn": {"cp": "_color", "rp": "_radius", "rs": 0.7, "c": Color(1.0, 0.9, 0.7), "r": 60.0, "e": 0.6, "d": 0.6},
	## --- Durum efektleri (yanma/donma/zehir... - yaratığın/oyuncunun üstünde) ---
	## Yanma (2026-09-25: "boyutunu %10 küçültüp biraz daha parlamasını sağla") - güç 0.6 -> 0.85.
	"res://scenes/fx_burn_status.tscn": {"c": Color(1.0, 0.5, 0.15), "r": 34.0, "e": 0.85, "f": 0.45},
	"res://scenes/fx_enemy_burn_status.tscn": {"c": Color(1.0, 0.5, 0.15), "r": 34.0, "e": 0.85, "f": 0.45},
	"res://scenes/fx_ice_freeze_status.tscn": {"c": Color(0.5, 0.82, 1.0), "r": 30.0, "e": 0.45},
	"res://scenes/fx_poison_status.tscn": {"c": Color(0.55, 0.95, 0.35), "r": 24.0, "e": 0.35},
	"res://scenes/fx_poison_hit.tscn": {"c": Color(0.55, 0.95, 0.35), "r": 26.0, "e": 0.45, "d": 0.3},
	"res://scenes/fx_void_slow_status.tscn": {"c": Color(0.62, 0.3, 0.95), "r": 26.0, "e": 0.4},
	"res://scenes/fx_fear_status.tscn": {"c": Color(0.7, 0.55, 1.0), "r": 20.0, "e": 0.3},
	"res://scenes/fx_stun_stars.tscn": {"c": Color(1.0, 0.9, 0.5), "r": 20.0, "e": 0.35},
	"res://scenes/fx_taunt_status.tscn": {"c": Color(1.0, 0.45, 0.45), "r": 18.0, "e": 0.3},
	## --- Düşman büyüleri (soru-cevap seçimi) - sis içindeyken çizilmez ---
	## Kullanıcı bildirimi (2026-09-25): "yaratıkların atışlarının özel efektlerinin parıltısı aşırı fazla" - bütün "fog"
	## (düşman) girdileri güç x0.55, yarıçap x0.8 (üstüne genel parıltı -%30, bkz. atmosphere_overlay.gd).
	"res://scenes/enemy_projectile.tscn": {"cp": "tint", "c": Color(1.0, 0.55, 0.15), "r": 28.8, "e": 0.41, "fog": true},
}

## Sahnesiz, kodla kurulan (set_script / X.new()) efektler ve objeler.
const BY_SCRIPT := {
	"res://scripts/fx_arcane_impact.gd": {"c": Color(0.7, 0.5, 1.0), "r": 50.0, "e": 0.85, "d": 0.4},
	## Efsun sistemi (2026-09-25): tek seferlik pixel halka/dalga/ışık (renk efektin "color"ı), kalıcı alanlar (renk türe
	## göre enchant_area.gd get_night_glow_color kancasından), yaratığın üstündeki Şok durumu.
	"res://scripts/fx_enchant_pixel.gd": {"cp": "color", "c": Color(1.0, 0.9, 0.7), "r": 50.0, "e": 0.6, "d": 0.45},
	"res://scripts/enchant_area.gd": {"c": Color(1.0, 0.6, 0.25), "r": 50.0, "e": 0.45},
	"res://scripts/fx_shock_status.gd": {"c": Color(1.0, 0.9, 0.35), "r": 22.0, "e": 0.4},
	"res://scripts/fx_kalkan_bagi_link.gd": {"c": Color(0.45, 0.8, 1.0), "r": 24.0, "e": 0.4},
	"res://scripts/fx_matthew_dash_lines.gd": {"c": Color(1.0, 0.7, 0.4), "r": 30.0, "e": 0.4, "d": 0.3},
	"res://scripts/fx_melek_ally_aura.gd": {"c": Color(1.0, 0.9, 0.55), "r": 50.0, "e": 0.45},
	"res://scripts/fx_oakley_flower_bond.gd": {"c": Color(0.6, 1.0, 0.5), "r": 22.0, "e": 0.45},
	"res://scripts/fx_paladin_barrier.gd": {"cp": "color", "c": Color(0.35, 0.78, 1.0), "r": 50.0, "e": 0.45},
	## Seyyar satıcı baloncuğu (2026-09-25: eski Şovalye baloncuğunun satıcıya ayrılmış kopyası) - aynı ışık.
	"res://scripts/fx_merchant_bubble.gd": {"cp": "color", "c": Color(0.35, 0.78, 1.0), "r": 50.0, "e": 0.45},
	## Koruma Bariyeri (E) baloncuğu 2026-09-25'te mor-mavi sprite'a geçti - ışık da o renkte.
	"res://scripts/fx_paladin_barrier_link.gd": {"c": Color(0.55, 0.52, 1.0), "r": 40.0, "e": 0.4},
	"res://scripts/fx_paladin_overlay.gd": {"c": Color(1.0, 0.88, 0.45), "r": 40.0, "e": 0.4},
	"res://scripts/fx_pixel_burst.gd": {"pal": {"fire": Color(1.0, 0.55, 0.2), "spark": Color(1.0, 0.8, 0.4), "void": Color(0.7, 0.4, 1.0)}, "r": 44.0, "e": 0.7, "d": 0.45},
	"res://scripts/fx_ring.gd": {"cp": "color", "rp": "max_radius", "rs": 0.6, "c": Color(1.0, 0.9, 0.7), "r": 40.0, "e": 0.55, "d": 0.5},
	"res://scripts/fx_shield_hit.gd": {"c": Color(0.5, 0.7, 1.0), "r": 36.0, "e": 0.5, "d": 0.3},
	## Eşya kalkanı baloncuğu (player.tscn / remote_player.tscn ShieldVisual) - kullanıcı isteği 2026-09-25: "gece olduğunda
	## kalkan da hafif parıltı yaysın görünür olduğunda". Baloncuk gizliyken ışık da söner (night_glow is_visible_in_tree);
	## renk kalkan türüne göre shield_visual.gd get_night_glow_color() kancasından gelir.
	"res://scripts/shield_visual.gd": {"c": Color(0.3, 0.72, 1.0), "r": 44.0, "e": 0.4},
	"res://scripts/fx_spirit_blink.gd": {"c": Color(0.75, 0.55, 1.0), "r": 40.0, "e": 0.7, "d": 0.45},
	"res://scripts/fx_totem_fire_bolt.gd": {"cp": "bolt_color", "c": Color(1.0, 0.55, 0.25), "r": 34.0, "e": 0.85},
	"res://scripts/necro_skull.gd": {"c": Color(0.45, 0.9, 0.75), "r": 50.0, "e": 0.8},
	"res://scripts/totem_area.gd": {"c": Color(0.7, 0.5, 1.0), "r": 60.0, "e": 0.35},
	"res://scripts/totem_attack.gd": {"c": Color(1.0, 0.6, 0.3), "r": 34.0, "e": 0.45},
	"res://scripts/totem_shield.gd": {"c": Color(0.45, 0.75, 1.0), "r": 40.0, "e": 0.45},
	"res://scripts/totem_shield_wave.gd": {"c": Color(0.45, 0.75, 1.0), "r": 60.0, "e": 0.5, "d": 0.6},
	## (Vampir'in yarasa sürüsü ve kan efektleri (vampir_bat_swarm.gd / vampir_fx.gd) BİLEREK yok: kan/yarasa ışık
	## saçmaz - kan sıçramalarıyla aynı kural, bkz. NO_GLOW_SCENES.)
	"res://scripts/oakley_flower.gd": {"c": Color(1.0, 0.7, 0.85), "r": 30.0, "e": 0.35},
	"res://scripts/wraith_pet.gd": {"c": Color(0.6, 0.9, 1.0), "r": 36.0, "e": 0.35},
	## --- Görev objeleri (soru-cevap seçimi) ---
	"res://scripts/mission_collect_item.gd": {"c": Color(0.45, 1.0, 0.9), "r": 38.0, "e": 0.6, "o": Vector2(0.0, -10.0)},
	"res://scripts/mission_zone.gd": {"c": Color(0.55, 0.85, 1.0), "r": 70.0, "e": 0.5},
	"res://scripts/mission_van.gd": {"c": Color(1.0, 0.8, 0.45), "r": 70.0, "e": 0.6},
	"res://scripts/mission_tree.gd": {"c": Color(0.6, 1.0, 0.55), "r": 60.0, "e": 0.45},
	## --- Düşman büyüleri (soru-cevap seçimi) - sis içindeyken çizilmez ---
	"res://scripts/enemy_fireball.gd": {"c": Color(1.0, 0.5, 0.18), "r": 35.2, "e": 0.5, "f": 0.3, "fog": true},
	"res://scripts/enemy_laser.gd": {"c": Color(0.95, 0.6, 1.0), "r": 24.0, "e": 0.5, "fog": true},
	"res://scripts/enemy_acid_pool.gd": {"c": Color(0.5, 0.9, 0.25), "r": 40.0, "e": 0.25, "fog": true},
	"res://scripts/mission_copy_bolt.gd": {"c": Color(0.8, 0.35, 0.95), "r": 24.0, "e": 0.44, "fog": true},
	"res://scripts/fx_enemy_bolt_impact.gd": {"cp": "color", "c": Color(1.0, 0.55, 0.15), "r": 32.0, "e": 0.44, "d": 0.35, "fog": true},
	## Yaratık yeteneklerinin ortak sprite oynatıcısı - neyin oynadığına göre (hayalet/vampir sisi parlamaz).
	"res://scripts/fx_enemy_ability.gd": {"frames": {
		"laser_flash": {"c": Color(0.95, 0.6, 1.0), "r": 35.2, "e": 0.5, "d": 0.3, "fog": true},
		## İblis ateş topu patlaması - "patlama efekti parlamıyor" (2026-09-25): 0.5 güç / 0.45 sn neredeyse görünmüyordu.
		"fire_impact": {"c": Color(1.0, 0.5, 0.2), "r": 70.0, "e": 1.0, "d": 0.7, "f": 0.2, "fog": true},
		"necro/impact": {"c": Color(0.45, 0.85, 0.75), "r": 50.0, "e": 0.8, "d": 0.4},
		"shaman_area/pulse": {"c": Color(0.7, 0.5, 1.0), "r": 50.0, "e": 0.5, "d": 0.5},
		"shaman_area/wisp": {"c": Color(0.75, 0.6, 1.0), "r": 22.0, "e": 0.45},
	}},
}

## Silah UCU (asa kristali / fişek fitili): silah sahnesi yolu -> profil. Işık silahın "Icon" Sprite2D'sinin ÇOCUĞU
## olarak takılır, o yüzden "o" ofseti ikon DOKUSUNUN pikselidir (Sprite2D ortalı: doku merkezinden) - ikon dönünce/
## ölçeklenince/uzak oyuncuya taşınınca (remote_player.gd update_weapon_visuals ikonu weapon_root'tan alıp kendine
## ekliyor) ışık ucuyla birlikte gider. Ofsetler asaların _v3 dokularında (weapon.gd/remote_player.gd ikisi de _v3
## kullanıyor) sıcak/kristal piksellerin ağırlık merkezinden ölçüldü. Tabanca/tüfek için sürekli uç ışığı YOK - kullanıcı
## isteği "ateşlenince ucunda parıltı": o namlu ateşi efektinin (fx_revolver_muzzle/fx_tufek_muzzle) flaş ışığı.
const WEAPON_TIPS := {
	"res://scenes/weapon_fire.tscn": {"c": Color(1.0, 0.55, 0.18), "r": 30.0, "e": 0.7, "f": 0.35, "o": Vector2(47.0, -50.0)},
	"res://scenes/weapon_buz_asasi.tscn": {"c": Color(0.55, 0.88, 1.0), "r": 28.0, "e": 0.6, "o": Vector2(58.0, -62.0)},
	"res://scenes/weapon_lightning.tscn": {"c": Color(1.0, 0.92, 0.45), "r": 28.0, "e": 0.65, "f": 0.3, "o": Vector2(51.0, -55.0)},
	"res://scenes/weapon_arcane.tscn": {"c": Color(0.8, 0.6, 1.0), "r": 32.0, "e": 0.85, "f": 0.15, "o": Vector2(63.0, -66.0)},
	"res://scenes/weapon_fisek.tscn": {"c": Color(1.0, 0.65, 0.3), "r": 18.0, "e": 0.5, "f": 0.6, "o": Vector2(5.0, 60.0)},
}


## Düğüm için ham profil (boş = parlamaz). Önce sahne yolu, sonra script yolu.
static func profile_for(node: Node) -> Dictionary:
	var scene_path: String = node.scene_file_path
	if not scene_path.is_empty():
		if BY_SCENE.has(scene_path):
			return BY_SCENE[scene_path]
		if NO_GLOW_SCENES.has(scene_path):
			return {}
		if scene_path.begins_with("res://scenes/fx_"):
			return DEFAULT_FX_SCENE
	var scr: Script = node.get_script() as Script
	if scr == null:
		return {}
	return BY_SCRIPT.get(scr.resource_path, {})


## Ham profili sahibinin O ANKİ verisiyle çözer (renk/yarıçap alanları, palet, SpriteFrames) ve night_glow.gd'nin
## attach() biçimine çevirir. Boş sözlük = bu örnek parlamayacak.
static func resolve(node: Node, raw: Dictionary) -> Dictionary:
	if raw.is_empty():
		return {}
	var p: Dictionary = raw
	if raw.has("frames"):
		var frames: Variant = node.get("frames")
		var fpath: String = (frames as Resource).resource_path if frames is Resource else ""
		p = {}
		for key: String in raw["frames"]:
			if fpath.contains(key):
				p = raw["frames"][key]
				break
		if p.is_empty():
			return {}
	var col: Color = p.get("c", Color(1.0, 0.9, 0.7))
	if p.has("pal"):
		var pal: String = str(node.get("palette"))
		if not (p["pal"] as Dictionary).has(pal):
			return {}
		col = p["pal"][pal]
	if p.has("cp"):
		var v: Variant = node.get(StringName(p["cp"]))
		if v is Color:
			col = v
	col.a = 1.0
	var radius: float = float(p.get("r", 40.0))
	if p.has("rp"):
		var rv: Variant = node.get(StringName(p["rp"]))
		if rv is float or rv is int:
			radius = clampf(float(rv) * float(p.get("rs", 1.0)), 16.0, 160.0)
	return {
		"color": col,
		"radius": radius,
		"energy": float(p.get("e", 0.7)),
		"flicker": float(p.get("f", 0.0)),
		"decay": float(p.get("d", 0.0)),
		"offset": p.get("o", Vector2.ZERO),
		"hide_in_fog": bool(p.get("fog", false)),
		"energy_cap": float(p.get("cap", -1.0)),
	}
