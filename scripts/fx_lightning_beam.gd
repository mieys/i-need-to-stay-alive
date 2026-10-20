extends Node2D

## Şimşek Asası'nın kesintisiz ışını (namludan hedefe).
##
## YENİDEN TASARIM (kullanıcı isteği 2026-09-25: "yıldırım asasının yıldırım efektini v.s yeniden tasarlamanı istiyorum
## pixel tarzda sonrasında spritesheete dönüştür ki performans düşmesin"): eskiden her karede antialias'lı çizgi
## zikzakları + script'te tek tek hesaplanan kıvılcım parçacıkları çiziliyordu. Artık:
##  - ışın gövdesi: lightning_strip.gd (piksel şimşek karoları, FLICKER_INTERVAL'da bir yeniden karıştırılır),
##  - hedefte: "impact" sprite döngüsü (cızırdayan kıvılcım çekirdeği),
##  - namluda: "orb" sprite döngüsü (asanın ucunda titreyen elektrik topu).
## Hepsi tools/gen_lightning_staff_fx.py sayfaları, 1 sanat pikseli = 1 dünya birimi.
##
## top_level: hem yerelde (current_scene çocuğu) hem uzak oyuncuda (RemotePlayer çocuğu - ölçekli kök) AYNI dünya
## koordinatında, aynı boyda çizilir (eskiden uzak kopyanın boyu ebeveyn ölçeğine bağlıydı).

const LightningStrip := preload("res://scripts/lightning_strip.gd")
const ImpactFrames := preload("res://assets/fx/lightning_staff/impact_frames.tres")
const OrbFrames := preload("res://assets/fx/lightning_staff/orb_frames.tres")
const FLICKER_INTERVAL := 0.05
const AudioBusesScript := preload("res://scripts/audio_buses.gd")
## Işın uğultusu seviyesi (±1,5 dB titrer). 2026-10-19 (kullanıcı: "sesi düşük olan silahların sesini tatmin edici olacak şekilde arttır"):
## -7,5 -> -4,5 (ölçüm: etkin kısa süreli RMS -29,6 -> -26,6 dB; sürekli döngü olduğu için tek atışlı silahlardan ~5 dB alçakta).
## Aynı gün madde 294 (vuruş sesleri geldi): -4,5 -> -7,5 - vuruşlar uğultunun üstünde net duyulsun diye, her tikte DUCK_SEC boyunca DUCK_DB çöker.
const BEAM_SFX_DB := -7.5
var _remote_db: float = 0.0 ## uzak oyuncunun ışını: AudioBuses.remote_weapon_db() (setup_network)

## VURUŞ SESLERİ (2026-10-19, madde 294; kullanıcı: "hasar verdiğimizi hissettirsin" + "ilk yıldırım için de efekt istemiştim"): eskiden tikte
## yalnız oyuncunun ortak fire.mp3'ü çalıyordu (oyunda uğultunun ~13 dB altında = duyulmuyordu). Artık hedefte her tikte kısa vuruş (4 dosya,
## art arda aynısı yok, perde ±%6), kritik tikte ağır vuruş, ışın hedefe çakınca İLK ÇAKIŞ (sahip başına en fazla STRIKE_MIN_GAP_MS'de bir -
## kalabalıkta en yakın hedef sık değişir). Ses: tools/proto_20261019/yildirim_ses_proto.py "A - Çatırtı + Küt Darbe" (--oyuna dosyaları yazar
## ve buradaki dB'leri basar). Sesler ışın düğümünün çocuğu DEĞİL (öldüren tikten hemen sonra ışın silinir, ses kesilirdi): tek seferlik çalıcı.
## Kaster: weapon.gd (_process_continuous_beam / _deal_beam_tick, ağa "beam_hit"); uzak: remote_player.gd _start_beam_vfx / _beam_hit_sfx.
const HIT_STREAMS := [
	preload("res://assets/audio/lightning/vurus_1.wav"),
	preload("res://assets/audio/lightning/vurus_2.wav"),
	preload("res://assets/audio/lightning/vurus_3.wav"),
	preload("res://assets/audio/lightning/vurus_4.wav"),
]
const CRIT_STREAM: AudioStream = preload("res://assets/audio/lightning/kritik.wav")
const STRIKE_STREAM: AudioStream = preload("res://assets/audio/lightning/ilk_cakis.wav")
## 2026-10-20 (madde 344, kullanıcı: "yıldırım asasının sıçrama zap zap sesini kıs"): her tikte (~0,5 sn) çalan vuruş oyundaki EN SIK ve en yüksek
## tekrarlı silah sesiydi (-23,5; diğer atışlar -23..-28) -> tik +3 -> -2 (oyunda -28,5), kritik +1,7 -> -2,3 (-25). İlk çakış (tek olay) aynı.
const HIT_DB := -2.0 ## vuruş dosyaları anlık K -26,5 -> oyunda -28,5 (uğultu -27,8, her tikte çöker); kritik -25, ilk çakış -21
const CRIT_DB := -2.3
const STRIKE_DB := 0.3
const STRIKE_MIN_GAP_MS := 500
## Taban tik aralığı (beam_tick_interval 0,37 / saldırı hızı çarpanı 0,7). Daha sık tikte vuruş kazancı sqrt(aralık / bu): saniye başına ses
## enerjisi sabit kalır, yüksek saldırı hızında makineli tüfek gibi gürlemez.
const HIT_REF_INTERVAL := 0.5
const DUCK_DB := -4.0
const DUCK_SEC := 0.12
static var _last_hit_idx: int = -1
static var _last_strike_ms: Dictionary = {} ## sahip anahtarı (silah / uzak oyuncu instance id) -> son ilk çakış (ms)
var _hum_db: float = BEAM_SFX_DB
var _duck_left: float = 0.0

@onready var sfx: AudioStreamPlayer2D = get_node_or_null("Sfx")

var _origin: Node2D = null
var _target: Node2D = null

## Ağ (remote) modu: uzak oyuncularda gerçek bir Enemy node referansı yok, broadcast_player_vfx ile sadece hedefin ve
## namlunun konumu gelir (bkz. remote_player.gd _start_beam_vfx/_update_beam_vfx, network_manager.gd "beam_start"/
## "beam_update").
var _use_network_target: bool = false
var _network_target_pos: Vector2 = Vector2.ZERO
var _network_origin_pos: Vector2 = Vector2.ZERO

var _from_local: Vector2 = Vector2.ZERO
var _tiles := PackedInt32Array()
var _flicker_timer: float = 0.0
var _impact: AnimatedSprite2D = null
var _orb: AnimatedSprite2D = null
## Hedef yaratıktan dökülen hafif kıvılcımlar (madde 299; staff_tip_fx.gd "elec_hit"). Sahne kökünde: ışın bitince kalanlar söner.
const StaffTipFxScript := preload("res://scripts/staff_tip_fx.gd")
var _hit_fx: Node2D = null


func _ready() -> void:
	top_level = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	## Eski sahnedeki kullanılmayan sprite düğümleri (varsa) gizli kalsın.
	for old_name in ["Bolt", "Spark"]:
		var old: CanvasItem = get_node_or_null(old_name) as CanvasItem
		if old:
			old.visible = false
	_impact = _make_sprite(ImpactFrames)
	_orb = _make_sprite(OrbFrames)
	_hit_fx = StaffTipFxScript.make_hit_emitter(self)
	if sfx:
		sfx.volume_db = BEAM_SFX_DB
		sfx.finished.connect(sfx.play)
		sfx.play()


func _make_sprite(frames: SpriteFrames) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(s)
	s.play("loop")
	s.frame = randi() % frames.get_frame_count("loop")
	return s


func setup(origin: Node2D, target: Node2D) -> void:
	_origin = origin
	_target = target
	_use_network_target = false


## Uzak oyuncularda çağrılır. Orijin olarak silahın gerçek namlu konumu, hedef olarak da ağdan gelen hedef konumu
## kullanılır; eksik eski paketlerde RemotePlayer konumu güvenli geri dönüş olarak korunur.
func setup_network(target_pos: Vector2, extra_data: Dictionary) -> void:
	_origin = null
	_target = null
	_remote_db = AudioBusesScript.remote_weapon_db()
	_hum_db = BEAM_SFX_DB + _remote_db
	if sfx:
		sfx.volume_db = _hum_db
	_use_network_target = true
	_network_target_pos = target_pos
	var fallback_origin: Vector2 = get_parent().global_position if get_parent() is Node2D else target_pos
	_network_origin_pos = Vector2(extra_data.get("from_pos", fallback_origin))


## Uzak oyuncularda hedef ve silah namlusu pozisyonunu tazeler.
func update_target(target_pos: Vector2, origin_pos: Vector2 = Vector2.ZERO) -> void:
	_network_target_pos = target_pos
	if origin_pos != Vector2.ZERO:
		_network_origin_pos = origin_pos


func _process(delta: float) -> void:
	var from: Vector2 = global_position
	if _use_network_target:
		from = _network_origin_pos
	elif _origin and is_instance_valid(_origin):
		from = _origin.global_position
	var to: Vector2 = global_position
	if _use_network_target:
		to = _network_target_pos
	elif _target and is_instance_valid(_target):
		to = _target.global_position
	## Kök hedefte (isabet ucu) durur; ışın yerel olarak namludan köke çizilir.
	global_position = to
	if _hit_fx != null and is_instance_valid(_hit_fx):
		_hit_fx.emit_hit(to, delta)
	_from_local = from - to
	_orb.position = _from_local
	_flicker_timer -= delta
	if _flicker_timer <= 0.0 or _tiles.size() < LightningStrip.tile_count(from, to):
		_flicker_timer = FLICKER_INTERVAL
		_tiles = LightningStrip.reroll(LightningStrip.tile_count(from, to))
	## Dinamik elektrik cızırtısı (sesin kendisi aynı) - hafif perde/ses dalgalanması.
	if sfx and sfx.playing:
		sfx.pitch_scale = lerp(sfx.pitch_scale, randf_range(0.94, 1.08), 0.4)
		_hum_db = lerp(_hum_db, BEAM_SFX_DB + _remote_db + randf_range(-1.5, 1.5), 0.4)
		## Tikte çökme (yan zincir hissi): kalan sürenin karesiyle geri gelir.
		var duck_db: float = 0.0
		if _duck_left > 0.0:
			_duck_left = maxf(0.0, _duck_left - delta)
			duck_db = DUCK_DB * pow(_duck_left / DUCK_SEC, 2.0)
		sfx.volume_db = _hum_db + duck_db
	queue_redraw()


## Vuruş tiki (kaster: weapon.gd _deal_beam_tick): sesi seçer + çalar + uğultuyu çökertir; ağa gidecek alanları döner ("beam_hit": aynı ses
## dosyası (i), perde (p), sıklık kısması (r), kritik).
func play_tick_sfx(pos: Vector2, crit: bool, interval: float) -> Dictionary:
	var idx: int = randi() % HIT_STREAMS.size()
	if idx == _last_hit_idx:
		idx = (idx + 1) % HIT_STREAMS.size()
	_last_hit_idx = idx
	var data := {"crit": crit, "i": idx, "p": randf_range(0.94, 1.06), "r": rate_db(interval)}
	play_hit_at(get_tree(), pos, data, _remote_db, _use_network_target)
	duck()
	return data


## İlk çakış (kaster: weapon.gd yeni hedef; uzak: remote_player.gd _start_beam_vfx, setup_network'ten SONRA).
func play_strike_sfx(pos: Vector2, owner_key: int) -> void:
	var now: int = Time.get_ticks_msec()
	if now - int(_last_strike_ms.get(owner_key, -100000)) < STRIKE_MIN_GAP_MS:
		return
	_last_strike_ms[owner_key] = now
	_one_shot(get_tree(), pos, STRIKE_STREAM, STRIKE_DB + _remote_db, randf_range(0.97, 1.03), _use_network_target)


func duck() -> void:
	_duck_left = DUCK_SEC


## Tik aralığına göre vuruş kısması (dB, <= 0).
static func rate_db(interval: float) -> float:
	return 10.0 * log(clampf(interval / HIT_REF_INTERVAL, 0.05, 1.0)) / log(10.0)


## Vuruş sesini konumda çalar (kaster ve uzak AYNI kural). extra_db: uzak oyuncu kısması; remote: başkasının silahı gibi daha erken söner.
static func play_hit_at(tree: SceneTree, pos: Vector2, data: Dictionary, extra_db: float, remote: bool) -> void:
	var crit: bool = bool(data.get("crit", false))
	var stream: AudioStream = CRIT_STREAM if crit else HIT_STREAMS[clampi(int(data.get("i", 0)), 0, HIT_STREAMS.size() - 1)]
	var db: float = (CRIT_DB if crit else HIT_DB) + float(data.get("r", 0.0)) + extra_db
	_one_shot(tree, pos, stream, db, float(data.get("p", 1.0)), remote)


static func _one_shot(tree: SceneTree, pos: Vector2, stream: AudioStream, db: float, pitch: float, remote: bool) -> void:
	if tree == null:
		return
	var parent: Node = tree.current_scene if tree.current_scene else tree.root
	var asp := AudioStreamPlayer2D.new()
	asp.stream = stream
	asp.volume_db = db
	asp.pitch_scale = pitch
	## Başkasının silahı: network_manager.gd "weapon_sound" ile aynı mesafe kuralı; kendi ışını uğultuyla aynı (1500, doğrusal).
	asp.max_distance = 900.0 if remote else 1500.0
	asp.attenuation = 1.6 if remote else 1.0
	parent.add_child(asp)
	asp.global_position = pos
	asp.finished.connect(asp.queue_free)
	asp.play()


func _draw() -> void:
	LightningStrip.draw(self, _from_local, Vector2.ZERO, _tiles)


## Gece ışığı (bkz. night_glow.gd / night_glow_catalog.gd): ışık tek noktada değil, namludan hedefe ışın boyunca.
func get_glow_segment() -> Array:
	return [to_global(_from_local), global_position]


func _exit_tree() -> void:
	if _hit_fx != null and is_instance_valid(_hit_fx):
		_hit_fx.release()
		_hit_fx = null
