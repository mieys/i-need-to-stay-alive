extends RefCounted

## SABİT SİLAH SANATI (madde 402, 2026-11-06; eski adıyla "kademe sanatı" - madde 196/198 Zanaatkâr seti KALDIRILDI).
## Kullanıcı: "masaüstünde bulunan görünümleri mevcut halleriyle değiştirip diğer tüm silahları (yeni oluşturulan silahlar hariç)
## eski görünümleriyle değiştirip silahların geliştirilince görünüşünün değişmesi yerine parıldadığı sisteme geri döndür".
## - Bu tablodaki silahların ikonu SABİT bir dokudur, demirci kademesiyle DEĞİŞMEZ (kademe artık kontür parıltısıyla gösterilir:
##   enchant_weapon_glow.gd GLOW_ENABLED). Uzunkılıç + Arcane/Ateş/Buz/Gökkuşağı/Zehir Asası = kullanıcının çizimi (assets/weapons/yeni/,
##   çapraz: sap sol-alt, uç sağ-üst); Mızrak / Kalkan / Yin Yang Kitabı (Zanaatkâr'dan sonra yapılan, eski görünüşü olmayan silahlar)
##   Zanaatkâr 1. seviye çizimlerinde kalır. Yay + Arbalet (madde 413) = kullanıcının çizimi; Yay'ın 5 "draw" karesi çizimden
##   türetilir (tools/gen_yay_cekis.py: yalnız ip geri çekilir, ok karenin içinde - sahnedeki ayrı HeldArrow kullanılmaz).
## - Tabloda OLMAYAN silahlar (eskiden Topuz, Yıldırım Asası, Tabanca, Tüfek, Bumerang, Fişek; artık hepsinin çizimi var) Zanaatkâr
##   öncesi ESKİ ikonlarını kullanır: sahne dokusu/ölçeği/duruşu (weapon_*.tscn) + asalarda weapon.gd'nin v3 ikonu - bu dosya onlara
##   dokunmaz. Zanaatkâr dokuları (assets/weapons/zanaat/) silinmedi.
## Tek kaynak: yerel weapon.gd (_ready -> _apply_fixed_art), uzak kukla remote_player.gd (update_weapon_visuals) ve görev kopyası
## mission_player_copy.gd AYNI fonksiyonları çağırır - biri güncellenip diğeri unutulursa diğer oyuncuda eski/yanlış sanat görünür
## (CLAUDE.md "iki ayrı yer" hata sınıfı).

## Doku pikseli = 0,575 dünya px (Zanaatkâr ile aynı yoğunluk; kullanıcının ~32 px çizimleri böylece eski silah boylarına denk gelir).
const WORLD_PX := 0.575
## Oyuncu / uzak kukla / görev kopyası kök ölçeği (main.tscn Player, remote_player.tscn): ikon doğrudan bu kökün çocuğuysa yerel ölçek.
const OWNER_ROOT_SCALE := 0.5
const PUPPET_ICON_SCALE := WORLD_PX / OWNER_ROOT_SCALE
## Anahtar başına ek boyut çarpanı: çizimi diğerlerinden uzun olan silah (pompalı 62 px, öbürleri ~32) sırıtmasın.
## Tırpan x1,57 (2026-11-09, kullanıcı: "tırpan biraz daha büyük görünmeli böyle balta gibi olmuş"): 40 px çizim 0,575 ile ~23 dünya px
## kalıyordu; x1,57 = 0,903 dünya px/piksel = KARAKTER pikseliyle aynı ızgara, boyu ~36 dünya px (karakter boyu kadar).
## 2026-11-11 (kullanıcı: "son eklediğin silahlar biraz küçük"): 32x32 yeni çizimler eski ikonlarının ~%57-75'i kalıyordu
## (dünya boyu: Tabanca 18 -> 31, Topuz 24 -> 32, Yıldırım 24 -> 38 eski); Tabanca x1,5 / Topuz x1,3 / Yıldırım x1,5 eski boya yaklaştırır.
## Tüfek (35 vs 38 eski) zaten yakın, dokunulmadı.
## 2026-11-11 (madde 589): Tırpan YENİ 32x32 çizim (Desktop\tırpan.png, yatay aynalı: sap sol-alt, bıçak sağa kıvrık) -> x1,74 =
## 1,0 dünya px/piksel, boyu eski 40 px'lik tırpanınki kadar (~31 dünya px). Çakram (eski Bumerang, 32x32) x1,3 = 0,75 dünya
## px/piksel, çapı ~22 dünya px = eski bumerangın eni.
## 2026-11-13 (kullanıcı: "bazı silahlar çok ufakken bazıları çok büyük, hepsi makul görünürlükte olsun"): görünür boy (çizimin en uzun
## uzantısı, dünya px; karakter ~30-35) 18-35 arasına dağılmıştı -> standart (kılıç/asa/yay/arbalet) ~25-26, Mızrak ~30, Tırpan ~30, Tüfek ~30,
## Pompalı ~28, Kalkan ~21, Yin Yang ~23; Bıçak/Balyoz/Tabanca/Çakram/Fişek aynı. Çakram DEĞİŞMEZ: mermi sanatı + değirmen efekti 1,3'e bağlı
## (boomerang_projectile.gd ART_WORLD_PX, chakram_mill_fx.gd, tools/gen_chakram_fx.py). Anahtarı olmayan = 1,0.
const SIZE_MULT := {
	"uzunkilic": 1.06, "mizrak": 1.26, "pence": 1.55, "kalkan": 1.2, "yinyang": 1.15,
	"fire_staff": 1.07, "arcane": 1.06, "tuftuf": 1.09, "gokkusagi": 1.15, "buz_asasi": 1.22, "lightning_staff": 1.09,
	"yay": 1.22, "crossbow": 1.2, "tufek": 1.1, "pompali": 0.78, "makineli": 0.78, ## Tüfek 0,86 -> 1,1 (2026-11-13, kullanıcı: "tüfek çok küçük görünüyor"): 64 px çizim ~40 dünya px (karakterden biraz uzun, tüfeğe yakışır)
	"tabanca": 1.5, "topuz": 1.3, "boomerang": 1.3, "fisek": 1.3, ## Dinamit (madde 651) = Çakram pikseli; firework_projectile.gd ART_WORLD_PX aynı
}


static func size_mult(key: String) -> float:
	return float(SIZE_MULT.get(key, 1.0))

const ART := {
	"uzunkilic": "res://assets/weapons/yeni/uzunkilic.png",
	"dagger": "res://assets/weapons/yeni/bicak.png", ## 2026-11-09 (madde 522): Bıçak = kullanıcının 32x32 eğri hançer çizimi (sap sol-alt, uç sağ-üst)
	"arcane": "res://assets/weapons/yeni/arcane.png",
	"fire_staff": "res://assets/weapons/yeni/fire_staff.png",
	"buz_asasi": "res://assets/weapons/yeni/buz_asasi.png",
	"gokkusagi": "res://assets/weapons/yeni/gokkusagi.png",
	"tuftuf": "res://assets/weapons/yeni/zehir_asasi.png", ## 2026-11-06: Tüftüf artık ZEHİR ASASI (anahtar aynı: kayıt/ağ uyumu)
	"yay": "res://assets/weapons/yeni/yay.png", ## arayüz ikonu (ip düz, oksuz); oyundaki silah BOW_FRAMES karelerini oynatır
	"crossbow": "res://assets/weapons/yeni/arbalet.png",
	"topuz": "res://assets/weapons/yeni/topuz.png", ## 2026-11-10: kullanıcının 32x32 çizimi (sap sol-alt, baş sağ-üst); vuruş tutma noktası topuz_slam_math.gd TEX_GRIPS
	"lightning_staff": "res://assets/weapons/yeni/yildirim_asasi.png", ## 2026-11-10: kullanıcının 32x32 çizimi (Desktop\yıldırım asası.png; anahtar aynı)
	"tabanca": "res://assets/weapons/yeni/tabanca.png", ## 2026-11-10: kullanıcının 32x32 Luger çizimi (namlu sağa, yatay)
	"tufek": "res://assets/weapons/yeni/tufek.png", ## 2026-11-10: kullanıcının 64x32 dürbünlü tüfek çizimi (namlu sağa, yatay)
	"pence": "res://assets/weapons/yeni/tirpan.png", ## Pençe artık TIRPAN (madde 505; anahtar `pence` aynı: kayıt/ağ uyumu); 2026-11-11 yeni 32x32 çizim (madde 589)
	"boomerang": "res://assets/weapons/yeni/chakram.png", ## 2026-11-11 (madde 589): Bumerang artık ÇAKRAM (kullanıcının 32x32 çizimi; anahtar `boomerang` aynı)
	"mizrak": "res://assets/weapons/zanaat/mizrak_L1.png",
	"kalkan": "res://assets/weapons/zanaat/kalkan_L1.png", ## yönlü görünüşü scripts/kalkan_bash_math.gd seçer (1. seviye sayfası)
	"yinyang": "res://assets/weapons/zanaat/yinyang_L1.png",
	"fisek": "res://assets/weapons/yeni/dinamit.png", ## 2026-11-13 (madde 651): Fişek artık DİNAMİT (kullanıcının 32x32 çizimi, gövde sol-alt -> fitil sağ-üst; anahtar `fisek` aynı)
	"pompali": "res://assets/weapons/pompali/icon.png", ## madde 448: kullanıcının çizimi (64x64 tuvalde ortalı), namlu sağa
	"makineli": "res://assets/weapons/makineli/icon.png", ## madde 652: kullanıcının 60x32 makineli çizimi (64x64 tuvalde ortalı), namlu sağa
}

## Sanatın duruşu (Vector2.angle ölçüsüyle ucun baktığı açı): çapraz çizilenler sol-alt -> sağ-üst (-45; Arbalet: dipçik sol-alt, yay
## sağ-üst), Yay +45 (ip sol-üst köşegende, kabza sağ-altta -> ok sağ-alta uçar), kalkan önden dik (0; dönmez,
## yönlü görünüşü scripts/kalkan_bash_math.gd seçer), Yin Yang açık kitap önden dik (0; dönmez - weapon.gd _face_dir).
const FORWARD := {
	"uzunkilic": -45.0, "dagger": -45.0, "mizrak": -45.0, "kalkan": 0.0,
	"fire_staff": -45.0, "arcane": -45.0, "topuz": -45.0, "lightning_staff": -45.0, "buz_asasi": -45.0, "gokkusagi": -45.0, "tuftuf": -45.0,
	"crossbow": -45.0, "yay": 45.0, "fisek": -45.0,
	"pence": -62.0, ## tırpan (madde 589 çizimi): sap sol-alttan (3,30) başa (16,4) -62 derece, bıçak baştan sağa-aşağı kıvrık
	"boomerang": -90.0, ## çakram dört kat simetrik daire: eski bumerangın açısı (-90,9) - nişanda dönüşü göze batmaz
	"yinyang": 0.0, "pompali": 0.0, "makineli": 0.0, "tabanca": 0.0, "tufek": 0.0,
}
## Dinlenme pozunda ucu yukarı baksın (melee_icon_rest_rotation_deg): çapraz sanat -45 döner; tırpan -90 - (-62) = -28.
const REST := {"topuz": -45.0, "uzunkilic": -45.0, "mizrak": -45.0, "pence": -28.0} ## tırpan dinlenmede dik: baş üstte, bıçak sağa kıvrık

## Yay "draw" kareleri (weapon_yay.tscn'deki eski draw_frames.tres ile aynı ad/hız/döngü; kare 1 = çizim + ipte ok).
const BOW_FRAMES := "res://assets/weapons/yeni/yay_d%d.png"
const BOW_FRAME_COUNT := 5

static var _tex_cache: Dictionary = {}
static var _bow_frames: SpriteFrames = null


## Sahne dosyası -> mağaza anahtarı (weapon.gd _ready'de shop_key meta'sı henüz yok: player.gd add_child'dan SONRA atıyor).
## Sanatı olmayan silahlar da burada: anahtar asa ucu partikülleri (staff_tip_fx.gd) ve şarjör (gun_mag_math.gd) için de kullanılır.
const SCENE_KEYS := {
	"weapon_dagger": "dagger", "weapon_uzunkilic": "uzunkilic", "weapon_topuz": "topuz", "weapon_pence": "pence",
	"weapon_mizrak": "mizrak", "weapon_kalkan": "kalkan",
	"weapon_fire": "fire_staff", "weapon_lightning": "lightning_staff", "weapon_arcane": "arcane", "weapon_buz_asasi": "buz_asasi",
	"weapon_tabanca": "tabanca", "weapon_tufek": "tufek", "weapon_tuftuf": "tuftuf", "weapon_yay": "yay",
	"weapon_crossbow": "crossbow", "weapon_boomerang": "boomerang", "weapon_fisek": "fisek",
	"weapon_gokkusagi": "gokkusagi", "weapon_yinyang": "yinyang", "weapon_pompali": "pompali", "weapon_makineli": "makineli",
}


static func has_art(key: String) -> bool:
	return ART.has(key)


static func key_from_scene(scene_path: String) -> String:
	return str(SCENE_KEYS.get(scene_path.get_file().get_basename(), ""))


## Demirci kademesi (tier_for: 0 = efsunsuz) -> 1..5 (uç parıltısı WeaponFollowMath.has_glint, kalkan görünüşü vb. için).
static func clamp_tier(tier: int) -> int:
	return clampi(tier, 1, 5)


## Silahın sabit dokusu (sanatı yoksa null -> çağıran eski ikonu kullanır). Kademe parametresi geriye uyum için; görünüş kademeyle değişmez.
static func texture(key: String, _tier: int = 1) -> Texture2D:
	var path: String = str(ART.get(key, ""))
	if path == "":
		return null
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[path]


## Yay'ın çekiş animasyonu (tüm yaylar aynı SpriteFrames'i paylaşır; yalnız okunur).
static func bow_frames() -> SpriteFrames:
	if _bow_frames == null:
		var sf := SpriteFrames.new()
		if sf.has_animation(&"default"):
			sf.remove_animation(&"default")
		sf.add_animation(&"draw")
		sf.set_animation_loop(&"draw", false)
		sf.set_animation_speed(&"draw", 8.0)
		for k in range(1, BOW_FRAME_COUNT + 1):
			var path: String = BOW_FRAMES % k
			if ResourceLoader.exists(path):
				sf.add_frame(&"draw", load(path))
		_bow_frames = sf
	return _bow_frames


## İkonun dokusunu sabit sanatla değiştirir (ölçeğe dokunmaz). true = değişti. AnimatedSprite2D = Yay (çekiş kareleri; yerel
## weapon.gd, kukla remote_player.gd ve görev kopyası aynı yoldan geçer).
static func set_art(icon: Node, key: String, _tier: int = 1) -> bool:
	if icon is AnimatedSprite2D:
		if key != "yay":
			return false
		var sf: SpriteFrames = bow_frames()
		if sf.get_frame_count(&"draw") == 0:
			return false
		var a := icon as AnimatedSprite2D
		var playing: bool = a.is_playing()
		var fr: int = a.frame
		a.sprite_frames = sf
		a.animation = &"draw"
		a.frame = mini(fr, sf.get_frame_count(&"draw") - 1)
		if playing:
			a.play(&"draw")
		a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var arrow: Node = a.get_node_or_null("HeldArrow")
		if arrow is Sprite2D:
			(arrow as Sprite2D).texture = null ## ok çekiş karelerinin içinde
		return true
	if not (icon is Sprite2D):
		return false
	var tex: Texture2D = texture(key)
	if tex == null:
		return false
	(icon as Sprite2D).texture = tex
	(icon as Sprite2D).texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return true
