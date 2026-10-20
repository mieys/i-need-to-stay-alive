extends RefCounted

## ZANAATKÂR silah seti (madde 196): efsun kademesi 1-5 -> silah ikonunun sanatı (Paslı / Demir / Çelik / Kara Çelik / Yadigâr).
## Sanat: assets/weapons/zanaat/<anahtar>_L<n>.png (48x48, üretici tools/proto_20261016/silah_zanaat_proto.py); yay "draw" kareleri
## <yay>_L<n>_d<1..5>.png (ok çizimin İÇİNDE, eski ayrı HeldArrow sprite'ı kullanılmaz).
## Tek kaynak: yerel weapon.gd (set_enchant), uzak kukla remote_player.gd (update_weapon_visuals + _apply_enchant_glows) ve görev kopyası
## mission_player_copy.gd AYNI fonksiyonları çağırır - biri güncellenip diğeri unutulursa diğer oyuncuda eski/yanlış sanat görünür
## (CLAUDE.md "iki ayrı yer" hata sınıfı).

const DIR := "res://assets/weapons/zanaat/"

## Doku pikseli = 0,575 dünya px (2026-10-17: silahlar %15 büyütüldü; eski 0,5 = zoom 2'de tam 1:1, şimdi hafif karışık piksel kabul edildi).
const WORLD_PX := 0.575
## Oyuncu / uzak kukla / görev kopyası kök ölçeği (main.tscn Player, remote_player.tscn): ikon doğrudan bu kökün çocuğuysa yerel ölçek.
const OWNER_ROOT_SCALE := 0.5
const PUPPET_ICON_SCALE := WORLD_PX / OWNER_ROOT_SCALE

## Yeni sanatın duruşu (Vector2.angle ölçüsüyle ucun baktığı açı): çapraz çizilenler sol-alt -> sağ-üst (-45), tabanca/tüfek
## yatay (0), yay dikey kiriş solda (0, ok sağa), bumerang V tepesi yukarıda (-90), kalkan önden dik (0; dönmez, yönlü
## görünüşü scripts/kalkan_bash_math.gd seçer). Eski sanatın sahne değerleri (Uzunkılıç/Topuz
## yatay 0 + dinlenme -90, Tüftüf 134, Fişek -92) bu sanatla geçersiz.
const FORWARD := {
	"dagger": -45.0, "uzunkilic": -45.0, "topuz": -45.0, "pence": -45.0, "mizrak": -45.0, "kalkan": 0.0,
	"fire_staff": -45.0, "lightning_staff": -45.0, "arcane": -45.0, "buz_asasi": -45.0, "gokkusagi": -45.0,
	"tuftuf": -45.0, "crossbow": -45.0, "fisek": -45.0,
	"tabanca": 0.0, "tufek": 0.0, "boomerang": -90.0, "yay": 0.0,
	"yinyang": 0.0, ## açık kitap önden, dik (dönmez - weapon.gd _face_dir)
}
## Dinlenme pozunda ucu yukarı baksın (melee_icon_rest_rotation_deg): çapraz sanat -45 döner.
const REST := {"uzunkilic": -45.0, "topuz": -45.0, "mizrak": -45.0}

static var _tex_cache: Dictionary = {}
static var _frames_cache: Dictionary = {}


## Sahne dosyası -> mağaza anahtarı (weapon.gd _ready'de shop_key meta'sı henüz yok: player.gd add_child'dan SONRA atıyor).
const SCENE_KEYS := {
	"weapon_dagger": "dagger", "weapon_uzunkilic": "uzunkilic", "weapon_topuz": "topuz", "weapon_pence": "pence",
	"weapon_mizrak": "mizrak", "weapon_kalkan": "kalkan",
	"weapon_fire": "fire_staff", "weapon_lightning": "lightning_staff", "weapon_arcane": "arcane", "weapon_buz_asasi": "buz_asasi",
	"weapon_tabanca": "tabanca", "weapon_tufek": "tufek", "weapon_tuftuf": "tuftuf", "weapon_yay": "yay",
	"weapon_crossbow": "crossbow", "weapon_boomerang": "boomerang", "weapon_fisek": "fisek",
	"weapon_gokkusagi": "gokkusagi", "weapon_yinyang": "yinyang",
}


static func has_art(key: String) -> bool:
	return FORWARD.has(key)


static func key_from_scene(scene_path: String) -> String:
	return str(SCENE_KEYS.get(scene_path.get_file().get_basename(), ""))


## tier_for() 0 = efsun yok -> 1. seviye sanatı.
static func clamp_tier(tier: int) -> int:
	return clampi(tier, 1, 5)


static func texture(key: String, tier: int) -> Texture2D:
	var path: String = "%s%s_L%d.png" % [DIR, key, clamp_tier(tier)]
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[path]


## Yay: 5 karelik "draw" (yay_L<n>_d1..d5), weapon_yay.tscn'deki eski draw_frames.tres ile aynı ad/hız/döngü.
static func bow_frames(tier: int) -> SpriteFrames:
	var t: int = clamp_tier(tier)
	if not _frames_cache.has(t):
		var sf := SpriteFrames.new()
		if sf.has_animation(&"default"):
			sf.remove_animation(&"default")
		sf.add_animation(&"draw")
		sf.set_animation_loop(&"draw", false)
		sf.set_animation_speed(&"draw", 8.0)
		for k in range(1, 6):
			var path: String = "%syay_L%d_d%d.png" % [DIR, t, k]
			if ResourceLoader.exists(path):
				sf.add_frame(&"draw", load(path))
		_frames_cache[t] = sf
	return _frames_cache[t]


## Bumerang mermisi (boomerang_projectile.gd): 24 önceden döndürülmüş kare (15 derece, Godot rotation +), "spin" animasyonu.
static func boomerang_rot_frames(tier: int) -> SpriteFrames:
	var key: String = "rot%d" % clamp_tier(tier)
	if not _frames_cache.has(key):
		var path: String = "%sboomerang_rot_L%d.png" % [DIR, clamp_tier(tier)]
		var sf: SpriteFrames = null
		if ResourceLoader.exists(path):
			var sheet: Texture2D = load(path)
			sf = SpriteFrames.new()
			if sf.has_animation(&"default"):
				sf.remove_animation(&"default")
			sf.add_animation(&"spin")
			sf.set_animation_loop(&"spin", true)
			for k in range(24):
				var at := AtlasTexture.new()
				at.atlas = sheet
				at.region = Rect2(48 * k, 0, 48, 48)
				sf.add_frame(&"spin", at)
		_frames_cache[key] = sf
	return _frames_cache[key]


## Fişek mermisi (firework_projectile.gd): yeni sanat çapraz (burun FORWARD["fisek"] = -45) -> hareket yönüne göre düzeltme.
static func fisek_rotation_correction() -> float:
	return -deg_to_rad(float(FORWARD["fisek"]))


## İkonun dokusunu/karelerini kademe sanatıyla değiştirir (ölçeğe dokunmaz). true = değişti.
static func set_art(icon: Node, key: String, tier: int) -> bool:
	if icon == null or not has_art(key):
		return false
	if icon is AnimatedSprite2D:
		var sf: SpriteFrames = bow_frames(tier)
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
		var arrow: Node = a.get_node_or_null("HeldArrow")
		if arrow is Sprite2D:
			(arrow as Sprite2D).texture = null ## ok yeni karelerin içinde
	elif icon is Sprite2D:
		var tex: Texture2D = texture(key, tier)
		if tex == null:
			return false
		(icon as Sprite2D).texture = tex
	else:
		return false
	if icon is CanvasItem:
		(icon as CanvasItem).texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return true
