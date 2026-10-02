extends Node2D

## Efsun sprite sayfası oynatıcısı (2026-09-30 yeni efsun seti, tools/gen_enchant_fx.py -> assets/fx/enchant/<ad>_frames.tres).
## Tek seferlik ("play" animasyonu biter, düğüm silinir) ya da süreli döngü ("loop", loop_time sn sonra solar). Hem kasterde
## hem diğer oyuncularda AYNI yoldan kurulur: enchant_fx.gd "sprite" / "tiles" türleri (play -> broadcast_enchant_fx).
## Kök Node2D: AnimatedSprite2D kökünde stop()/play() tanımlamak projede ayrıştırma hatası (bkz. hafıza
## reference-gdscript-native-override-error).
##   sheet      sayfa adı (ör. "spin_slash")          rot        dönüş (radyan, sayfalar +x'e bakar)
##   scale      Vector2 çarpan (TEXEL üstüne)         loop_time  > 0 ise döngü süresi
##   ground     true = birimlerin altına (zemin efekti)  offset   sayfa içindeki kayma (sanat pikseli)
##   key        SÜREKLİ efekt: aynı anahtarla yeni istek gelince YENİ düğüm açılmaz, yaşayan düğümün loop_time'ı uzar,
##              yönü/ölçeği güncellenir (yön yumuşak döner). İstekler kesilince son loop_time sonunda söner. Kullanıcı
##              (2026-10-03, Destiny püskürtmesi): "spritesheet oynatılıp kapatılıyordu, sürekli devam etmesini istiyorum".
##              Her istemci aynı RPC'leri aldığı için uzak ekranlarda da aynı tek sürekli efekt olur.

const WeaponTip := preload("res://scripts/weapon_tip.gd")
const EnchantLayer := preload("res://scripts/enchant_layer.gd")
const TEXEL := 1.212
const DIR := "res://assets/fx/enchant/"
const FADE := 0.25
const SAFETY := 12.0

static var _frames_cache: Dictionary = {}
## Gece ışığı (night_glow_catalog.gd BY_SCRIPT -> glow_color / glow_radius / get_night_glow_energy / get_glow_segment):
## sayfa adı -> [renk, güç (0..1, katalogdaki tabanla çarpılır), boyut çarpanı, koni boyu (sanat px; > 0 = kökten ileri
## çizgi ışık)]. Yarıçap = sayfanın GÖRSEL yarıçapı (karenin büyük kenarının yarısı x TEXEL x ölçek) x boyut çarpanı.
## Listede olmayan sayfalar (toz, kaya, çelik, ok, kan, rüzgar halkası...) parlamaz (night_glow_off) - CLAUDE.md "Gece ışığı".
## Kullanıcı bildirimi (2026-10-01): "efsunların parıltıları yok, karanlıkta parlamıyorlar" - eski listede sabit yarıçaplar
## efektin kendi boyutundan küçüktü (atmosphere_overlay GLOW_RADIUS_SCALE x0,65 sonrası ışık efektin ALTINDA kalıyordu, lav
## 50 -> 32 birim / havuz 45), güç 0,5 (etkin ~0,25) ve kara delik / kozmik disk / astral / can küresi / şok halkaları /
## iz-yarık karoları hiç yoktu. Genel parıltı ayarlarına (kullanıcının iki kez azalttığı güç x0,56 / tavan 0,4 / yarıçap
## x0,65) DOKUNULMADI - sadece efsunlar diğer yetenek efektleriyle aynı seviyeye çekildi.
const GLOW := {
	"spray_fire": [Color(1.0, 0.55, 0.2), 0.85, 0.7, 70.0], "spray_ice": [Color(0.55, 0.85, 1.0), 0.8, 0.7, 70.0],
	## Kullanıcının ateş püskürtme sanatı (tools/import_flame_spray.py): 51 px boyunca çizgi ışık.
	"flame_fire": [Color(1.0, 0.55, 0.2), 0.85, 0.7, 51.0], "flame_ice": [Color(0.55, 0.85, 1.0), 0.8, 0.7, 51.0],
	"spray_fire_big": [Color(1.0, 0.55, 0.2), 0.85, 0.7, 140.0], "spray_ice_big": [Color(0.55, 0.85, 1.0), 0.8, 0.7, 140.0],
	"lava_pool": [Color(1.0, 0.5, 0.18), 0.85, 1.5], "frost_ground": [Color(0.55, 0.85, 1.0), 0.75, 1.4],
	"radiation": [Color(0.7, 1.0, 0.35), 0.85, 1.5], "void_hole": [Color(0.7, 0.45, 1.0), 0.75, 1.3],
	"void_collapse": [Color(0.75, 0.5, 1.0), 0.9, 1.3], "zeus_burst": [Color(1.0, 0.95, 0.5), 0.9, 1.5],
	"trail_pop_fire": [Color(1.0, 0.55, 0.2), 0.9, 1.5], "trail_pop_volt": [Color(1.0, 0.95, 0.5), 0.9, 1.5],
	"mushroom": [Color(1.0, 0.6, 0.25), 0.95, 1.0], "fault_blast": [Color(1.0, 0.5, 0.18), 0.9, 1.1],
	"crack_x": [Color(1.0, 0.55, 0.2), 0.8, 1.4], "mini_pop": [Color(1.0, 0.7, 0.35), 0.85, 1.4],
	"mini_fw": [Color(1.0, 0.6, 0.25), 0.7, 3.5], "cosmic_blast": [Color(0.75, 0.5, 1.0), 0.85, 1.0],
	"charged_shock": [Color(1.0, 0.8, 0.5), 0.8, 0.9], "kinetic_blast": [Color(1.0, 0.9, 0.45), 0.75, 1.0],
	"cosmic_disk": [Color(0.7, 0.45, 1.0), 0.75, 1.1], "astral_orb": [Color(0.8, 0.55, 1.0), 0.75, 3.5],
	"heal_orb": [Color(0.55, 1.0, 0.5), 0.7, 3.5], "crystal_ice": [Color(0.55, 0.85, 1.0), 0.7, 2.2],
	"crystal_arcane": [Color(0.8, 0.55, 1.0), 0.7, 2.2], "crystal_ice_shard": [Color(0.55, 0.85, 1.0), 0.65, 3.0],
	"crystal_arcane_shard": [Color(0.8, 0.55, 1.0), 0.65, 3.0], "crystal_burst": [Color(0.55, 0.85, 1.0), 0.8, 1.5],
	"execute_mark": [Color(1.0, 0.35, 0.3), 0.7, 1.5], "bounce_spark": [Color(1.0, 0.9, 0.5), 0.65, 2.5],
	"shade_slash": [Color(0.7, 0.45, 1.0), 0.6, 1.4], "spin_slash": [Color(0.95, 0.95, 1.0), 0.35, 0.9],
	"vortex": [Color(0.9, 0.95, 1.0), 0.4, 1.0],
}

var sheet: String = ""
var loop_time: float = 0.0
var sprite_scale: Vector2 = Vector2.ONE
var sprite_offset: Vector2 = Vector2.ZERO
var ground: bool = false
var glow_color: Color = Color.WHITE
var glow_radius: float = 30.0
var glow_energy: float = 1.0
var night_glow_off: bool = true
var _glow_size: float = 1.0
var _glow_cone_px: float = 0.0

## SİLAH TAKİBİ (data "follow_slot" + "follow_peer"): düğüm silah ikonunun EBEVEYNİNE (yerelde weapon.gd kökü, uzakta
## RemotePlayer kuklası) bağlanır ve her karede ikonun çizili UCUNA oturur (weapon_tip.gd) - oyuncu yürüyüp asa dönerken
## efekt de onunla gider; ebeveynin (fizik interpolasyonlu) akıcı konumunu kendiliğinden izler. YÖN ise dünyada sabit
## "rot" kalır (gerçek hasar yönü): uzak kuklanın asası kendi hedef seçimiyle hafif farklı bakabilir, püskürtme yine de
## hasarın gittiği yere gitmeli (yerelde asa zaten aynı hedefe nişan alır - enchant_behavior.aim_target).
## Kullanıcı bildirimi (2026-09-30): "ejder nefesi efsunundaki ateş ve buz püskürtme efekti silahı takip etmiyor, konumu
## yanlış" - eskiden asanın ORTASINDAN dünyaya sabit bırakılıyordu. Silah bulunamazsa eski davranış (pos + rot, sabit).
var follow_icon: Sprite2D = null
var follow_fwd_deg: float = 0.0
var _world_rot: float = 0.0

var _spr: AnimatedSprite2D = null
var _t: float = 0.0

## Sürekli (anahtarlı) efektler - bkz. dosya başı "key".
static var _live: Dictionary = {}
const ROT_SMOOTH := 14.0 ## 1/sn - anahtarlı efektin yeni yöne dönüş hızı
var key: String = ""
var _target_rot: float = 0.0


static func frames(name: String) -> SpriteFrames:
	if not _frames_cache.has(name):
		var path: String = DIR + name + "_frames.tres"
		_frames_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return _frames_cache[name]


static func spawn(tree: SceneTree, pos: Vector2, data: Dictionary) -> Node2D:
	if tree == null or tree.current_scene == null:
		return null
	var k: String = str(data.get("key", ""))
	if k != "":
		var live = _live.get(k) ## tipsiz: silinmiş düğüm tipli değişkene atanırken hata verirdi
		if is_instance_valid(live) and not live.is_queued_for_deletion():
			live.call("_refresh", pos, data)
			return live
	var n: Node2D = (load("res://scripts/fx_enchant_sprite.gd") as GDScript).new()
	n.sheet = str(data.get("sheet", ""))
	n.loop_time = float(data.get("loop_time", 0.0))
	var sc: Variant = data.get("scale", 1.0)
	n.sprite_scale = sc if sc is Vector2 else Vector2.ONE * float(sc)
	n.sprite_offset = Vector2(data.get("offset", Vector2.ZERO))
	n.ground = bool(data.get("ground", false))
	n.rotation = float(data.get("rot", 0.0))
	n._target_rot = n.rotation
	if k != "":
		n.key = k
		_live[k] = n
	if GLOW.has(n.sheet):
		var g: Array = GLOW[n.sheet]
		n.night_glow_off = false
		n.glow_color = g[0]
		n.glow_energy = float(g[1])
		n._glow_size = float(g[2])
		n._glow_cone_px = float(g[3]) if g.size() > 3 else 0.0
	## Dünyadaki efsun sprite'ları karakterlerin ALTINDA (bkz. enchant_layer.gd) - çağıranın verdiği "z" (eskiden 8/9 =
	## karakterin üstü) bu katmanı aşamaz. Silah ikonuna yapışan (follow_slot) sprite'lar silahın kendi katmanında kalır.
	n.z_index = mini(int(data.get("z", EnchantLayer.Z)), EnchantLayer.Z)
	if data.has("follow_slot"):
		n.z_index = int(data.get("z", 2))
		var info: Array = weapon_icon_info(tree, int(data.get("follow_peer", 0)), int(data["follow_slot"]))
		if info.size() == 2 and is_instance_valid(info[0]) and (info[0] as Node).get_parent() is Node2D:
			n.follow_icon = info[0]
			n.follow_fwd_deg = float(info[1])
			n._world_rot = n.rotation
			(info[0] as Node).get_parent().add_child(n)
			n._follow_update()
			return n
	n.position = pos
	tree.current_scene.add_child(n)
	n.global_position = pos
	return n


## Sahibin (peer <= 0 ya da bu makinenin kendisi -> yerel oyuncu, yoksa uzak kukla) ağ slotundaki silah ikonu:
## [Sprite2D, sprite_forward_angle_deg] ya da boş dizi.
static func weapon_icon_info(tree: SceneTree, peer: int, slot: int) -> Array:
	var holder: Node = null
	var mp: MultiplayerAPI = tree.root.multiplayer
	var mine: bool = peer <= 0 or not NetworkManager.is_multiplayer_active or (mp.has_multiplayer_peer() and peer == mp.get_unique_id())
	if mine:
		holder = tree.get_first_node_in_group("player")
	elif NetworkManager.has_method("_find_remote_player"):
		holder = NetworkManager._find_remote_player(peer)
	if holder == null or not holder.has_method("get_weapon_icon_info"):
		return []
	return holder.get_weapon_icon_info(slot)


## Aynı anahtarla gelen yeni istek (bkz. spawn): ömrü uzat, yönü/ölçeği/konumu güncelle - animasyon kesilmeden sürer.
func _refresh(pos: Vector2, data: Dictionary) -> void:
	_target_rot = float(data.get("rot", _target_rot))
	var sc: Variant = data.get("scale", 1.0)
	sprite_scale = sc if sc is Vector2 else Vector2.ONE * float(sc)
	if _spr:
		_spr.scale = sprite_scale * TEXEL
	sprite_offset = Vector2(data.get("offset", sprite_offset))
	if _spr:
		_spr.offset = sprite_offset
	loop_time = _t + maxf(0.05, float(data.get("loop_time", loop_time - _t)))
	if follow_icon == null:
		global_position = pos


func _exit_tree() -> void:
	if key != "" and _live.get(key) == self:
		_live.erase(key)


func _follow_update() -> void:
	if not is_instance_valid(follow_icon):
		follow_icon = null
		return
	var par: Node2D = get_parent() as Node2D
	if par == null:
		return
	var gs: Vector2 = par.global_scale
	scale = Vector2(1.0 / maxf(absf(gs.x), 0.001), 1.0 / maxf(absf(gs.y), 0.001))
	position = WeaponTip.tip_in_parent(follow_icon, follow_fwd_deg)
	global_rotation = _world_rot


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr = AnimatedSprite2D.new()
	_spr.name = "Sprite"
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.sprite_frames = frames(sheet)
	_spr.scale = sprite_scale * TEXEL
	_spr.offset = sprite_offset
	add_child(_spr)
	if _spr.sprite_frames == null:
		queue_free()
		return
	if loop_time > 0.0 and _spr.sprite_frames.has_animation(&"loop"):
		_spr.play(&"loop")
	elif _spr.sprite_frames.has_animation(&"play"):
		_spr.play(&"play")
		_spr.animation_finished.connect(queue_free)
	else:
		_spr.play(&"loop")
		if loop_time <= 0.0:
			loop_time = 1.0
	## Işık yarıçapı sayfanın görsel boyutundan (bkz. GLOW notu) - atmosfer ışığı bir sonraki boşta (deferred) takar,
	## yani burada (add_child sırasında) hesaplanan değeri okur.
	if not night_glow_off:
		var tex: Texture2D = _spr.sprite_frames.get_frame_texture(_spr.animation, 0)
		if tex:
			var vis_r: float = 0.5 * maxf(float(tex.get_width()), float(tex.get_height())) * TEXEL \
				* maxf(absf(sprite_scale.x), absf(sprite_scale.y))
			glow_radius = vis_r * _glow_size
	if ground:
		_place_on_ground.call_deferred()


## Gece ışığı kancaları (night_glow.gd). Güç: sayfanın GLOW gücü (katalogdaki tabanla çarpılır).
func get_night_glow_energy() -> float:
	return glow_energy


## Işık görselin MERKEZİNDE (ofsetli sayfalar - mantar, balista - kökte değil); koni sayfaları (püskürtme) kökten ileri
## çizgi ışık (asanın ucundan koni boyunca). Boyu sıfır çizgi = nokta ışık (atmosphere_overlay _push_segment).
func get_glow_segment() -> Array:
	if _spr == null or not is_instance_valid(_spr):
		return [global_position, global_position]
	if _glow_cone_px > 0.0:
		var dir: Vector2 = Vector2.from_angle(global_rotation)
		var along: float = _glow_cone_px * TEXEL * absf(sprite_scale.x)
		return [global_position + dir * along * 0.15, global_position + dir * along]
	var c: Vector2 = _spr.global_transform * _spr.offset
	return [c, c]


func _place_on_ground() -> void:
	var root: Node = get_tree().current_scene if is_inside_tree() else null
	if root == null or get_parent() != root:
		return
	var harita: Node = root.get_node_or_null("Harita")
	if harita:
		root.move_child(self, harita.get_index() + 1)


func _process(delta: float) -> void:
	_t += delta
	if key != "":
		## Sürekli efekt yeni yönüne yumuşak döner (tik başına sıçramasın).
		var w: float = minf(1.0, delta * ROT_SMOOTH)
		if follow_icon != null:
			_world_rot = lerp_angle(_world_rot, _target_rot, w)
		else:
			rotation = lerp_angle(rotation, _target_rot, w)
	if follow_icon != null:
		_follow_update()
	if loop_time > 0.0:
		modulate.a = clampf(minf(_t / 0.12, (loop_time - _t) / FADE), 0.0, 1.0)
		if _t >= loop_time:
			queue_free()
	elif _t >= SAFETY:
		queue_free()
