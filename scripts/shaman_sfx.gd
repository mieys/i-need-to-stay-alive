extends RefCounted

## Shaman totem sesleri (assets/audio/shaman/*.wav, tools/gen_shaman_assets.py) için tek yardımcı. Konumlu (2D) tek atımlık oynatıcı
## sahneye eklenir, bitince kendini siler. Totemin ve efektlerin kendisi HER istemcide (gerçek + kozmetik kopya) çalıştığı için bu
## sesler de herkesin ekranında/kulağında aynıdır - ayrı ağ yayını gerekmez (bkz. proje kökündeki CLAUDE.md).

const DIR := "res://assets/audio/shaman/"
const PLANT := {
	"shield": DIR + "shaman_plant_shield.wav",
	"attack": DIR + "shaman_plant_attack.wav",
	"area": DIR + "shaman_plant_area.wav",
}
const EXPIRE := DIR + "shaman_expire.wav"
const SHIELD_PULSE := DIR + "shaman_shield_pulse.wav"
const BOLT_SHOT := DIR + "shaman_bolt_shot.wav"
const BOLT_HIT := DIR + "shaman_bolt_hit.wav"
const AREA_PULSE := DIR + "shaman_area_pulse.wav"

static var _cache: Dictionary = {}


static func play_at(parent: Node, path: String, world_pos: Vector2, volume_db: float = -6.0, pitch_jitter: float = 0.05) -> AudioStreamPlayer2D:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var stream: AudioStream = _cache.get(path)
	if stream == null:
		stream = load(path) as AudioStream
		_cache[path] = stream
	if stream == null:
		return null
	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = stream
	sfx.volume_db = volume_db
	sfx.max_distance = 1100.0
	sfx.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	parent.add_child(sfx)
	sfx.global_position = world_pos
	sfx.finished.connect(sfx.queue_free)
	sfx.play()
	return sfx
