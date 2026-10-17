extends RefCounted

## Assasin Çocuk ULTİ (Gölge Hücumu) efektleri - kullanıcı isteği (2026-10-16): "ultisi için yeni özel efekt hazırla, şuanki
## efektler çok gösterişsiz ve o suikastçı hızını hissettirmiyor". TEK kaynak: kaster (player.gd _skill_assasin_dash) ve
## diğer istemciler (network_manager.gd "assasin_fx" / "assasin_blink") AYNI fonksiyonları çağırır - iki ekran sapamaz
## (CLAUDE.md MP iki-yer kuralı). Hasar/hedef sadece kasterde; buradakiler kozmetik.
##  - spawn_blink: cast (vanish) ve dönüş (appear) anında gölge patlaması + her yöne fırlayan hız çizgileri (ult_blink).
##  - spawn_step:  her sıçrayışın yolunda kuyruktan başa açılıp kapanan ışık çizgisi + mor silüet hayaletler
##                 (fx_assasin_ult_streak.gd).
##  - spawn_cut:   hedefte uzun, ince, anında beliren ana kesik + çapraz ikinci kesik, ortadan ayrılıp kayar, ileri savrulan
##                 gölge kıymıkları (ult_cut) + rastgele bıçak sesi.
##  - trigger_passive: PASİF "Bıçak Uzmanlığı" (3 sn garantili kritik) görseli - gövdeye bağlı assasin_passive_fx.gd düğümünü kurar
##                 ya da yeniler (2026-10-16, "pasifin varlığı hiç belli olmuyor").
## Sayfalar: tools/gen_assasin_ult_fx.py + tools/gen_assasin_passive_fx.py. Eski efektler (fx_assasin_dash.tscn arka iz, fx_assasin_shadow_hit.tscn çapraz
## hilal) ultide artık kullanılmıyor; fx_assasin_dash.tscn Şahin Hamlesi'nde (Q) duruyor.

const FlashScript: GDScript = preload("res://scripts/fx_assasin_ult_flash.gd")
const StreakScript: GDScript = preload("res://scripts/fx_assasin_ult_streak.gd")
const PassiveFxScript: GDScript = preload("res://scripts/assasin_passive_fx.gd")
const PASSIVE_NODE := "AssasinPassiveFx"
const CUT_FRAMES: SpriteFrames = preload("res://assets/fx/assasin/ult_cut_frames.tres")
const BLINK_FRAMES: SpriteFrames = preload("res://assets/fx/assasin/ult_blink_frames.tres")
const HIT_SOUNDS: Array[String] = [
	"res://assets/audio/assasin_swing1.mp3",
	"res://assets/audio/assasin_swing2.mp3",
	"res://assets/audio/assasin_swing3.mp3",
]
## Eski fx_assasin_dash.tscn'in açılış sesi (cast anında) - aynı ses, aynı ayar.
const VANISH_SOUND := "res://assets/audio/claw_slash.mp3"
const FX_Z := 70
const STREAK_Z := 68


## vanish = true: cast anı (ses de çalar); false: zincir bitip cast noktasına dönüş.
static func spawn_blink(parent: Node, pos: Vector2, vanish: bool) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var fx: Node2D = FlashScript.new()
	fx.set("frames", BLINK_FRAMES)
	fx.z_index = FX_Z
	parent.add_child(fx)
	fx.global_position = pos
	if vanish:
		_play_sound(parent, pos, VANISH_SOUND, -6.0, 1.3 * randf_range(0.9, 1.1), 1500.0, 1.0)


## from -> to: sıçrayışın başı/sonu (oyuncu kökü), sweep_time: sıçrayış süresi (çizginin açılma hızı).
static func spawn_step(parent: Node, body: Node2D, from: Vector2, to: Vector2, sweep_time: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var fx: Node2D = StreakScript.new()
	fx.z_index = STREAK_Z
	parent.add_child(fx)
	fx.call("setup", from, to, sweep_time, body)


## angle: hamle yönü, flip: kesiği aynala (kaster rastgele seçer, ağdan AYNI değer gider), sound_idx: HIT_SOUNDS sırası.
## remote: diğer oyuncunun kopyası - ses eski "melee_hit" kopyasıyla AYNI kısıklıkta (-10 dB, 900 birim).
static func spawn_cut(parent: Node, pos: Vector2, angle: float, flip: bool, sound_idx: int, remote: bool) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var fx: Node2D = FlashScript.new()
	fx.set("frames", CUT_FRAMES)
	fx.set("flip", flip)
	fx.z_index = FX_Z
	fx.rotation = angle
	parent.add_child(fx)
	fx.global_position = pos
	var path: String = HIT_SOUNDS[posmod(sound_idx, HIT_SOUNDS.size())]
	if remote:
		_play_sound(parent, pos, path, -10.0, randf_range(0.92, 1.1), 900.0, 1.6)
	else:
		_play_sound(parent, pos, path, 0.0, randf_range(0.92, 1.1), 1200.0, 1.0)


## Pasif görselini kur/yenile (body: yerel Player ya da uzak kukla; duration: garantili kritik süresi).
static func trigger_passive(body: Node2D, duration: float) -> void:
	if body == null or not is_instance_valid(body) or not body.is_inside_tree():
		return
	var fx: Node = body.get_node_or_null(PASSIVE_NODE)
	if fx == null or fx.is_queued_for_deletion():
		fx = PassiveFxScript.new()
		fx.name = PASSIVE_NODE
		body.add_child(fx)
	fx.call("refresh", duration)


static func _play_sound(parent: Node, pos: Vector2, path: String, volume_db: float, pitch: float, max_distance: float, attenuation: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return
	var asp := AudioStreamPlayer2D.new()
	asp.stream = stream
	asp.volume_db = volume_db
	asp.pitch_scale = pitch
	asp.max_distance = max_distance
	asp.attenuation = attenuation
	parent.add_child(asp)
	asp.global_position = pos
	asp.finished.connect(asp.queue_free)
	asp.play()
