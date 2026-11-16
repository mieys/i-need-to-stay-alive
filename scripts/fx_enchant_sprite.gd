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
##   loop_sfx   (2026-10-11) SÜREKLİ efektin döngü sesi (res:// .wav): efekt yaşadıkça çalar, efektle birlikte solar. Veri RPC'yle
##              gittiği için diğer oyuncularda da aynı ses (Ateş Asası püskürtmesi: assets/audio/fire_staff_spray_loop.wav).
##   sfx_db     loop_sfx ses seviyesi (dB, varsayılan LOOP_SFX_DB)
##   flip_left  (madde 639) sola bakarken sayfa dikey aynalanır (yukarı kabaran alev bulutu hep yukarıda kalsın), ofsetin y'si de döner
##   bright     (madde 639) sprite parlaklığı (1 = aynen; Ateş Asası Isınan Nefes)
##   bend_len   (madde 640) > 0: alev BÜKÜLÜR - asa dönünce uç geride kalıp kavis çizer (flame_bend.gd + shaders/flame_bend.gdshader).
##              AnimatedSprite gizli kalır (zamanlama/kare onda), çizimi ağız merkezli büyük bir dörtlü yapar. Her ekran kendi gördüğü
##              yönü kaydeder (ağ alanı yok). Değer = alevin boyu (sanat px).
## Sayfada "start" / "end" animasyonu varsa (madde 639, Ateş Asası flamethrower): döngülü efekt önce "start"ı oynar, sonra "loop";
## ömrü bitince solmak yerine "end"i oynar ve silinir (end sürerken aynı anahtarla gelen istek YENİ efekt açar = yine "start"tan).

const WeaponTip := preload("res://scripts/weapon_tip.gd")
const EnchantLayer := preload("res://scripts/enchant_layer.gd")
const TEXEL := 1.212
const DIR := "res://assets/fx/enchant/"
const FADE := 0.25
const LOOP_SFX_DB := -9.0
const LOOP_SFX_FADE_IN := 0.08
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
	## Alev Sağanağı (madde 550, tools/gen_alev_saganagi_fx.py): damlaların vardığı boy kadar çizgi ışık.
	"flame_shower_fire": [Color(1.0, 0.55, 0.2), 0.85, 0.7, 137.0], "flame_shower_ice": [Color(0.55, 0.85, 1.0), 0.8, 0.7, 137.0],
	"flame_shower_fire_big": [Color(1.0, 0.55, 0.2), 0.85, 0.6, 201.0], "flame_shower_ice_big": [Color(0.55, 0.85, 1.0), 0.8, 0.6, 201.0],
	## Ateş Asası flamethrower (madde 639, tools/gen_flamethrower_fx.py): alev boyu (177 sanat px) kadar çizgi ışık.
	"flamethrower_fire": [Color(1.0, 0.55, 0.2), 0.85, 0.55, 177.0], "flamethrower_ice": [Color(0.55, 0.85, 1.0), 0.8, 0.55, 177.0],
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
	"rainbow_dazzle": [Color(1.0, 0.95, 0.85), 0.8, 0.8], ## Gökkuşağı Asası kamaşma anı (madde 306)
	## Arcane "C - Kaos Yarığı" yankısı (madde 749): açılan yarık hafif, patlama halkası güçlü pembe-mor.
	"void_rift_open": [Color(0.94, 0.44, 1.0), 0.55, 0.6], "void_rift_pop_45": [Color(0.94, 0.44, 1.0), 0.85, 0.9],
	"void_rift_pop_60": [Color(0.94, 0.44, 1.0), 0.85, 0.9],
}

var sheet: String = ""
var loop_sfx: String = ""
var sfx_db: float = LOOP_SFX_DB
var _sfx: AudioStreamPlayer2D = null
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
var flip_left: bool = false
var _flipped: bool = false
var bright: float = 1.0
var _ending: bool = false ## "end" animasyonu oynuyor (bkz. dosya başı)
const FLIP_EPS := 0.15 ## dikey bakışta aynalama titremesin (cos eşik payı)
const FlameBend := preload("res://scripts/weapon_traits/flame_bend.gd")
const FlameShape := preload("res://scripts/weapon_traits/flamethrower_shape.gd")
const BEND_SHADER := preload("res://shaders/flame_bend.gdshader")
var bend_len: float = 0.0
var _bend: RefCounted = null ## FlameBend (yön geçmişi)
var _bend_spr: Sprite2D = null
static var _bend_quads: Dictionary = {} ## kare boyu -> boş doku (dörtlü)

## SİLAH TAKİBİ (data "follow_slot" + "follow_peer"): düğüm silah ikonunun EBEVEYNİNE (yerelde weapon.gd kökü, uzakta
## RemotePlayer kuklası) bağlanır ve her karede ikonun çizili UCUNA oturur (weapon_tip.gd) - oyuncu yürüyüp asa dönerken
## efekt de onunla gider; ebeveynin (fizik interpolasyonlu) akıcı konumunu kendiliğinden izler. YÖN ise dünyada sabit
## "rot" kalır (gerçek hasar yönü): uzak kuklanın asası kendi hedef seçimiyle hafif farklı bakabilir, püskürtme yine de
## hasarın gittiği yere gitmeli (yerelde asa zaten aynı hedefe nişan alır - enchant_behavior.aim_target).
## 2026-10-08 (kullanıcı: "ateş asasının alevi ateş asasıyla ayrı yerlerde olabiliyor, birbiriyle senkronize değil"): dünyada sabit yön
## iki yerde asadan KOPUYORDU - (1) uzak ekranda kuklanın asası kendi yerel hedefine döner, alev ise kasterin yayınladığı açıya
## bakardı; (2) yerelde asa yumuşak döner (AIM_EASE_RATE) ama alev yönünü yalnız tikte (0,25 sn'de bir) alırdı, hedef/oyuncu hareket
## edince ikisi ayrı yöne bakardı. Çözüm "follow_aim": yön her karede ASANIN ÇİZİLİ BAKIŞ yönünden (ikon dönüşü + ileri açı) +
## "rot_offset" (koni parçasının asa eksenine göre açısı) alınır -> her ekranda alev asanın baktığı yere, asanın ucundan çıkar.
## Kullanıcı bildirimi (2026-09-30): "ejder nefesi efsunundaki ateş ve buz püskürtme efekti silahı takip etmiyor, konumu
## yanlış" - eskiden asanın ORTASINDAN dünyaya sabit bırakılıyordu. Silah bulunamazsa eski davranış (pos + rot, sabit).
var follow_icon: Sprite2D = null
var follow_fwd_deg: float = 0.0
var _world_rot: float = 0.0
var follow_aim: bool = false ## true: yön = asanın bakışı + aim_rot_offset (bkz. yukarıdaki 2026-10-08 notu)
var aim_rot_offset: float = 0.0
## DÜNYA TAKİBİ (data "under": true; madde 550, kullanıcı: "ateş asası ... karakterin üstünü de kapatıyor"): düğüm silahın
## çocuğu DEĞİL, sahne kökünde efsun katmanında (EnchantLayer.Z = oyuncuların ALTI) durur ve her karede asanın ucuna + bakışına
## konur. Silahın çocuğuyken oyuncunun altına inemez: mutlak z 0 verilse bile Player sahne kökünün 0. çocuğu olduğu için
## haritadan ÖNCE çizilir = zeminin altında kalır (madde 510 tuzağı). Sahne kökündeki düğüm fizik interpolasyonu almaz ->
## uç konumuna sahibin (oyuncu / kukla) çizilen-ham konum farkı eklenir (PhysicsInterp.visual_position), yoksa yürürken titrer.
var follow_world: bool = false
var _follow_holder: Node2D = null
const PhysicsInterp := preload("res://scripts/physics_interp.gd")

var _spr: AnimatedSprite2D = null
var _t: float = 0.0

## Sürekli (anahtarlı) efektler - bkz. dosya başı "key".
static var _live: Dictionary = {}
## EFEKT BÜTÇESİ (2026-10-10, kullanıcı: "talonun E si fpsi inanılmaz düşürüyor, nedenini anlamaya çalış"). KÖK NEDEN (gerçek Main + gerçek renderer ölçümü, 250 yaratık, 5 silah):
## silahların kalıcı efsun özellikleri (kanama tikleri, Sismik Dalga, rüzgar kılıcı...) her isabette / her kanama tikinde (0,5 sn, kanayan HER yaratıkta) tek seferlik bir sprite efekti
## doğurur; Talon E (Silah Salvosu) atış hızını 5-6 katına çıkarınca isabet ve tik sayısı da katlanıyordu: saniyede ~900 düğüm (327'si bu efekt), kare 12 -> 25 ms (81 -> 40 fps), 50-60 ms takılmalar.
## Düzeltme: aynı anda canlı TEK SEFERLİK efekt sayısı en çok MAX_ONESHOT (üstü atlanır; sadece kozmetik - hasar/etki efektin düğümüne bağlı DEĞİL). Sürekli (anahtarlı/döngülü) ve silaha
## yapışık efektler bütçeye girmez. Atlanan efekt ağdan da yayınlanmaz (enchant_fx.gd play).
const MAX_ONESHOT := 40
static var _oneshots: int = 0
var _counted: bool = false
const ROT_SMOOTH := 14.0 ## 1/sn - anahtarlı efektin yeni yöne dönüş hızı
var key: String = ""
## Başkasının silahına yapışık (KİŞİSEL) sürekli efekt - Ateş Nefesi alevi gibi: AllyFxDensity çarpanı (1.0 = tam). Sürekli efekt kök modulate.a'yı her
## karede kendisi yazdığı için çarpan dışarıdan modulate'a değil buraya konur (madde 425/426).
var ally_alpha: float = 1.0
const AllyFxDensity := preload("res://scripts/ally_fx_density.gd")
var _target_rot: float = 0.0


static func frames(name: String) -> SpriteFrames:
	if not _frames_cache.has(name):
		var path: String = DIR + name + "_frames.tres"
		_frames_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return _frames_cache[name]


## Bu istek tek seferlik bir efekt mi (bütçeye girer): anahtarsız, döngüsüz, silaha yapışık değil.
static func is_oneshot(data: Dictionary) -> bool:
	return str(data.get("key", "")) == "" and not data.has("follow_slot") and float(data.get("loop_time", 0.0)) <= 0.0


## Bütçe dolu mu (yeni tek seferlik efekt atlanmalı mı). enchant_fx.gd play() yerelde doğurmadan ve ağa yollamadan önce sorar.
static func over_budget(data: Dictionary) -> bool:
	return is_oneshot(data) and _oneshots >= MAX_ONESHOT


## Testler: sayaç + önbellek sıfırla.
static func reset_budget() -> void:
	_oneshots = 0


static func live_oneshots() -> int:
	return _oneshots


static func spawn(tree: SceneTree, pos: Vector2, data: Dictionary) -> Node2D:
	if tree == null or tree.current_scene == null:
		return null
	if over_budget(data):
		return null
	var k: String = str(data.get("key", ""))
	if k != "":
		var live = _live.get(k) ## tipsiz: silinmiş düğüm tipli değişkene atanırken hata verirdi
		## Silaha yapışık efektin silahı silinmişse (asa değişti / yeniden alındı, aynı slot = aynı anahtar) eski düğüm sahipsiz kalır:
		## onu yenilemek yerine kapat, yeni silaha yeni efekt aç (madde 639; eskiden finalde anahtar değiştiği için görünmüyordu).
		if is_instance_valid(live) and data.has("follow_slot") and live.get("follow_icon") == null:
			live.queue_free()
			_live.erase(k)
		elif is_instance_valid(live) and not live.is_queued_for_deletion():
			live.call("_refresh", pos, data)
			return live
	var n: Node2D = (load("res://scripts/fx_enchant_sprite.gd") as GDScript).new()
	n.sheet = str(data.get("sheet", ""))
	n.loop_sfx = str(data.get("loop_sfx", ""))
	n.sfx_db = float(data.get("sfx_db", LOOP_SFX_DB))
	n.loop_time = float(data.get("loop_time", 0.0))
	var sc: Variant = data.get("scale", 1.0)
	n.sprite_scale = sc if sc is Vector2 else Vector2.ONE * float(sc)
	n.sprite_offset = Vector2(data.get("offset", Vector2.ZERO))
	n.ground = bool(data.get("ground", false))
	n.flip_left = bool(data.get("flip_left", false))
	n.bright = float(data.get("bright", 1.0))
	n.bend_len = float(data.get("bend_len", 0.0))
	n.rotation = float(data.get("rot", 0.0))
	n._target_rot = n.rotation
	if k != "":
		n.key = k
		_live[k] = n
	if is_oneshot(data):
		n._counted = true
		_oneshots += 1
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
			n.follow_aim = bool(data.get("follow_aim", false))
			n.aim_rot_offset = float(data.get("rot_offset", 0.0))
			## Başkasının silahına yapışık efekt (uzak kopya) = KİŞİSEL: Ateş Nefesi alevi vb. soluklaşır (formdaki kasterde ve Tam modda tam).
			var fpeer: int = int(data.get("follow_peer", 0))
			if fpeer > 0 and NetworkManager.is_multiplayer_active and tree.root.multiplayer.has_multiplayer_peer() \
					and fpeer != tree.root.multiplayer.get_unique_id():
				n.ally_alpha = AllyFxDensity.mult_for(n, NetworkManager._find_remote_player(fpeer))
			if bool(data.get("under", false)):
				n.follow_world = true
				n.z_index = EnchantLayer.Z
				n._follow_holder = _interp_holder(info[0])
				tree.current_scene.add_child(n)
			else:
				(info[0] as Node).get_parent().add_child(n)
			n._follow_update()
			return n
	n.position = pos
	tree.current_scene.add_child(n)
	n.global_position = pos
	if str(data.get("sfx", "")) != "":
		_play_oneshot_sfx(tree, pos, str(data["sfx"]), float(data.get("sfx_db", LOOP_SFX_DB)), float(data.get("sfx_pitch", 1.0)))
	return n


## Tek seferlik ses (madde 749, data "sfx" / "sfx_db" / "sfx_pitch"): veri RPC'yle gittiği için diğer oyuncularda da aynı ses.
## Arcane Kaos Yarığı patlaması (eskiden Korsan patlamasının ATEŞ sesini çalıyordu). Sık tetiklenirse 40 ms'de bir.
static var _sfx_cache: Dictionary = {}


static func _play_oneshot_sfx(tree: SceneTree, pos: Vector2, path: String, db: float, pitch: float) -> void:
	if NetworkManager.should_throttle("enchant_sprite_sfx_" + path, 0.04):
		return
	if not _sfx_cache.has(path):
		_sfx_cache[path] = load(path) if ResourceLoader.exists(path) else null
	var st: AudioStream = _sfx_cache[path]
	if st == null:
		return
	var s := AudioStreamPlayer2D.new()
	s.stream = st
	s.volume_db = db
	s.pitch_scale = pitch * randf_range(0.95, 1.05)
	s.max_distance = 1500.0
	tree.current_scene.add_child(s)
	s.global_position = pos
	s.play()
	s.finished.connect(s.queue_free)


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
	aim_rot_offset = float(data.get("rot_offset", aim_rot_offset))
	var sc: Variant = data.get("scale", 1.0)
	sprite_scale = sc if sc is Vector2 else Vector2.ONE * float(sc)
	if _spr:
		_spr.scale = sprite_scale * TEXEL
	if _bend_spr:
		_bend_spr.scale = sprite_scale * TEXEL
	sprite_offset = Vector2(data.get("offset", sprite_offset))
	bright = float(data.get("bright", 1.0))
	if _spr:
		_apply_flip()
	loop_time = _t + maxf(0.05, float(data.get("loop_time", loop_time - _t)))
	if follow_icon == null:
		global_position = pos


## Döngü sesi: wav çalışma anında döngüye alınır (.import ayarı gerekmez, atmosphere.gd ile aynı yol). Ses düğümü efekte bağlı
## (follow_slot'lu alev asayla yürür) - efekt silinince ses de biter.
## Başlangıçlı döngü (2026-11-13, Ateş Asası): .import'ta loop_mode/loop_begin AYARLIYSA (edit/loop_mode=2) dosyanın başı tek seferlik
## "başlangıç" sesidir, sonra loop_begin..loop_end döner - o zaman ayar korunur ve ses BAŞTAN çalar.
func _start_loop_sfx() -> void:
	var stream: AudioStream = load(loop_sfx)
	var intro: bool = stream is AudioStreamWAV and (stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED \
			and (stream as AudioStreamWAV).loop_begin > 0
	if stream is AudioStreamWAV and not intro:
		var wav := (stream as AudioStreamWAV).duplicate() as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(round(wav.get_length() * float(wav.mix_rate)))
		stream = wav
	_sfx = AudioStreamPlayer2D.new()
	_sfx.name = "LoopSfx"
	_sfx.stream = stream
	_sfx.volume_db = sfx_db - 30.0
	_sfx.max_distance = 1500.0
	add_child(_sfx)
	if intro:
		_sfx.play() ## başlangıç sesi duyulsun
	else:
		_sfx.play(randf() * maxf(0.0, stream.get_length() - 0.1)) ## rastgele noktadan: iki asa aynı anda çalınca üst üste binmesin


func _exit_tree() -> void:
	if key != "" and _live.get(key) == self:
		_live.erase(key)
	if _counted:
		_counted = false
		_oneshots = maxi(0, _oneshots - 1)


## Silah ikonunun ÇİZİLİ bakış yönü (dünya radyanı). weapon.gd _update_aim / remote_player.gd _update_local_weapon_aim ile aynı bağıntı:
## normal ikon rotation = yön - ileri; aynalı (flip_h, tabanca gibi) rotation = yön - PI + ileri.
static func icon_aim_angle(icon: Sprite2D, forward_deg: float) -> float:
	var f: float = deg_to_rad(forward_deg)
	return icon.global_rotation + ((PI - f) if icon.flip_h else f)


## İkonun fizik interpolasyonlu sahibi (yerel Player / uzak kukla): çizilen konumu PhysicsInterp.visual_position verir.
static func _interp_holder(icon: Node) -> Node2D:
	var p: Node = icon.get_parent()
	while p != null:
		if p is Node2D and "_interp_prev_pos" in p:
			return p as Node2D
		p = p.get_parent()
	return null


func _follow_update() -> void:
	if not is_instance_valid(follow_icon):
		follow_icon = null
		return
	if follow_world:
		var tip: Vector2 = WeaponTip.tip_global(follow_icon, follow_fwd_deg)
		if is_instance_valid(_follow_holder):
			tip += PhysicsInterp.visual_position(_follow_holder) - _follow_holder.global_position
		global_position = tip
		if follow_aim:
			_world_rot = icon_aim_angle(follow_icon, follow_fwd_deg) + aim_rot_offset
		global_rotation = _world_rot
		return
	var par: Node2D = get_parent() as Node2D
	if par == null:
		return
	var gs: Vector2 = par.global_scale
	scale = Vector2(1.0 / maxf(absf(gs.x), 0.001), 1.0 / maxf(absf(gs.y), 0.001))
	position = WeaponTip.tip_in_parent(follow_icon, follow_fwd_deg)
	if follow_aim:
		_world_rot = icon_aim_angle(follow_icon, follow_fwd_deg) + aim_rot_offset
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
	if loop_sfx != "" and loop_time > 0.0 and ResourceLoader.exists(loop_sfx) and DisplayServer.get_name() != "headless":
		_start_loop_sfx()
	if bend_len > 0.0:
		_setup_bend()
	_apply_flip()
	if loop_time > 0.0 and _spr.sprite_frames.has_animation(&"start"):
		_spr.play(&"start")
		_spr.animation_finished.connect(_on_anim_finished)
	elif loop_time > 0.0 and _spr.sprite_frames.has_animation(&"loop"):
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


## flip_left / bright uygulaması (bkz. dosya başı). Aynalama eşik paylı: dik bakışta her karede dönüp titremesin.
func _apply_flip() -> void:
	if _spr == null:
		return
	if flip_left:
		var c: float = cos(global_rotation if is_inside_tree() else rotation)
		if c < -FLIP_EPS:
			_flipped = true
		elif c > FLIP_EPS:
			_flipped = false
	_spr.flip_v = _flipped
	_spr.offset = Vector2(sprite_offset.x, -sprite_offset.y if _flipped else sprite_offset.y)
	_spr.self_modulate = Color(bright, bright, bright, 1.0)
	if _bend_spr:
		_bend_spr.self_modulate = _spr.self_modulate


## Bükülen alev (bkz. dosya başı "bend_len"): gizli AnimatedSprite karesini ağız merkezli dörtlüye shader'la çizer.
func _setup_bend() -> void:
	var tex: Texture2D = _spr.sprite_frames.get_frame_texture(_spr.animation if _spr.sprite_frames.has_animation(_spr.animation) else &"loop", 0)
	if not (tex is AtlasTexture):
		bend_len = 0.0
		return
	var at := tex as AtlasTexture
	var side: int = int(ceil(bend_len + 16.0)) * 2
	var quad: Texture2D = _bend_quads.get(side)
	if quad == null:
		## OPAK BEYAZ: Godot 4'te canvas shader'ındaki COLOR dörtlünün kendi doku rengiyle ÇARPILMIŞ gelir - saydam yer tutucu
		## alevi tamamen siliyordu (başsız testte görünmez, gerçek çizicide alev yoktu).
		var img: Image = Image.create(side, side, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		quad = ImageTexture.create_from_image(img)
		_bend_quads[side] = quad
	_bend_spr = Sprite2D.new()
	_bend_spr.name = "Bend"
	_bend_spr.texture = quad
	_bend_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bend_spr.scale = sprite_scale * TEXEL
	var mat := ShaderMaterial.new()
	mat.shader = BEND_SHADER
	mat.set_shader_parameter("sheet", at.atlas)
	mat.set_shader_parameter("sheet_size", Vector2(at.atlas.get_size()))
	## Ortalı sprite ofseti (sanat px) = kare yarısı - ağız -> ağız = kare yarısı - ofset.
	mat.set_shader_parameter("nozzle", at.region.size * 0.5 - sprite_offset)
	mat.set_shader_parameter("quad_px", Vector2(side, side))
	mat.set_shader_parameter("flen", bend_len)
	_bend_spr.material = mat
	add_child(_bend_spr)
	_spr.visible = false ## kare/zamanlama onda sürer, çizim Bend'de
	_bend = FlameBend.new()
	_bend.call("reset", Time.get_ticks_msec() / 1000.0, global_rotation if is_inside_tree() else rotation)
	_update_bend()


func _update_bend() -> void:
	if _bend_spr == null or _spr == null:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	_bend.call("push", now, global_rotation)
	var mat := _bend_spr.material as ShaderMaterial
	var tex: Texture2D = _spr.sprite_frames.get_frame_texture(_spr.animation, _spr.frame)
	if tex is AtlasTexture:
		var r: Rect2 = (tex as AtlasTexture).region
		mat.set_shader_parameter("region", Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
	mat.set_shader_parameter("flip_y", -1.0 if _flipped else 1.0)
	mat.set_shader_parameter("bend", _bend.call("angles", now, bend_len))


func _on_anim_finished() -> void:
	if _spr == null:
		return
	if _ending:
		queue_free()
	elif _spr.animation == &"start" and _spr.sprite_frames.has_animation(&"loop"):
		_spr.play(&"loop")


## Ömür bitti: "end" animasyonu varsa onu oynat (anahtar boşalır: yeni istek yeni efekt açar), yoksa sil.
func _begin_end() -> bool:
	if _ending:
		return true
	if _spr == null or not _spr.sprite_frames.has_animation(&"end"):
		return false
	_ending = true
	if key != "" and _live.get(key) == self:
		_live.erase(key)
	if not _spr.animation_finished.is_connected(_on_anim_finished):
		_spr.animation_finished.connect(_on_anim_finished)
	_spr.play(&"end")
	return true


## Gece ışığı kancaları (night_glow.gd). Güç: sayfanın GLOW gücü (katalogdaki tabanla çarpılır).
func get_night_glow_energy() -> float:
	return glow_energy


## Işık görselin MERKEZİNDE (ofsetli sayfalar - mantar, balista - kökte değil); koni sayfaları (püskürtme) kökten ileri
## çizgi ışık (asanın ucundan koni boyunca). Boyu sıfır çizgi = nokta ışık (atmosphere_overlay _push_segment).
func get_glow_segment() -> Array:
	if _spr == null or not is_instance_valid(_spr):
		return [global_position, global_position]
	if _bend_spr != null and _bend != null and _glow_cone_px > 0.0:
		return _bent_glow_path()
	if _glow_cone_px > 0.0:
		var dir: Vector2 = Vector2.from_angle(global_rotation)
		var along: float = _glow_cone_px * TEXEL * absf(sprite_scale.x)
		return [global_position + dir * along * 0.15, global_position + dir * along]
	var c: Vector2 = _spr.global_transform * _spr.offset
	return [c, c]


## Bükülen alevin (madde 640) gece ışığı: düz çizgi yerine alevin ORTA ÇİZGİSİ boyunca çok noktalı yol (madde 647). Her x'te alevin
## [üst, alt] bandının ortası (uçtaki yukarı kabaran bulut ışığı da yukarı çeker) + shader'daki aynı büküm: P = R(theta(x)) * (x, y).
## Başlangıç animasyonunda alev henüz kısadır: yol karenin ulaştığı boyda biter. Dönüş: [p0, p1, ...] dünya konumları (>= 3 nokta).
func _bent_glow_path() -> Array:
	var length: float = FlameShape.LENGTH
	var reach: float = length
	if _spr != null and _spr.animation == &"start":
		reach = minf(length, float(FlameShape.INTRO_REACH[clampi(_spr.frame, 0, FlameShape.INTRO_REACH.size() - 1)]))
	var bend: PackedFloat32Array = _bend.call("angles", Time.get_ticks_msec() / 1000.0, bend_len)
	var rot: float = global_rotation
	var fwd: Vector2 = Vector2.from_angle(rot)
	var side: Vector2 = Vector2(-fwd.y, fwd.x)
	var unit: float = TEXEL * absf(sprite_scale.x)
	var out: Array = []
	var from_x: float = reach * 0.12
	const POINTS := 9
	for i in POINTS:
		var x: float = lerpf(from_x, reach, float(i) / float(POINTS - 1))
		var band: Vector2 = FlameShape.band_at(x)
		var y: float = (band.x + band.y) * 0.5
		if _flipped:
			y = -y
		var p: Vector2 = Vector2(x, y).rotated(FlameBend.theta_at(bend, x, length))
		out.append(global_position + (fwd * p.x + side * p.y) * unit)
	return out


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
			if not follow_aim:
				_world_rot = lerp_angle(_world_rot, _target_rot, w)
		else:
			rotation = lerp_angle(rotation, _target_rot, w)
	if follow_icon != null:
		_follow_update()
	if flip_left and _spr:
		_apply_flip()
	if _bend_spr:
		_update_bend()
	if _ending:
		## "end" animasyonu kendi söner; ses kısılır, güvenlik için SAFETY.
		modulate.a = ally_alpha
		if _sfx != null:
			_sfx.volume_db = maxf(-80.0, _sfx.volume_db - delta * 120.0)
		if _t >= loop_time + SAFETY:
			queue_free()
	elif loop_time > 0.0:
		var staged: bool = _spr != null and _spr.sprite_frames != null and _spr.sprite_frames.has_animation(&"end")
		if staged:
			modulate.a = ally_alpha ## start/end animasyonu görünüp kaybolmayı kendi çizer
		else:
			modulate.a = clampf(minf(_t / 0.12, (loop_time - _t) / FADE), 0.0, 1.0) * ally_alpha
		if _sfx != null:
			var a: float = clampf(minf(_t / LOOP_SFX_FADE_IN, (loop_time - _t) / FADE), 0.0, 1.0)
			_sfx.volume_db = sfx_db + linear_to_db(maxf(a, 0.001))
		if _t >= loop_time and not _begin_end():
			queue_free()
	elif _t >= SAFETY:
		queue_free()
