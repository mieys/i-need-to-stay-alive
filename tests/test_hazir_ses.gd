extends Node

## Madde 533 (kullanıcının masaüstü "hazır ses" klasörü): yeni ses dosyaları, Hadime / Don Nova ses senkronu, final boss ses aralığı,
## görünmezken kendi ekranının kararması (stealth_vision.gd). Ses dosyaları tools/hazir_ses/gen_hazir_ses.py ile hazırlandı.

const PlayerScript: GDScript = preload("res://scripts/player.gd")
const LevelUpScript: GDScript = preload("res://scripts/level_up_screen.gd")
const KitScript: GDScript = preload("res://scripts/demon_boss.gd")
const StealthVisionScript: GDScript = preload("res://scripts/stealth_vision.gd")
const HadimeMath: GDScript = preload("res://scripts/hadime_math.gd")

var _spawned: Array = []


class FakeBoss extends Node2D:
	var events: Array = []
	var no_body_block: bool = false

	func emit_ability_vfx(kind: String, data: Dictionary) -> void:
		events.append([kind, data])


func _cleanup() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.queue_free()
	_spawned.clear()


func test_new_sound_files_load() -> void:
	var paths: Array[String] = [
		"res://assets/audio/level_atlama.wav", "res://assets/audio/level_kart_secme.wav", "res://assets/audio/evrim_kart_secme.wav",
		"res://assets/audio/boss/seytan_ses.wav", "res://assets/audio/boss/seytan_yetenek.wav",
		"res://assets/audio/skills/melek_ulti.wav", "res://assets/audio/skills/shaman_golem_q.wav",
		"res://assets/audio/skills/shaman_golem_e.wav", "res://assets/audio/skills/shaman_golem_oto.wav",
		"res://assets/audio/skills/buyucu_don_nova.wav", "res://assets/audio/skills/hadime_kara_delik.wav",
		"res://assets/audio/skills/assasin_gorunmezlik.wav",
	]
	for path in paths:
		var s: AudioStream = load(path) as AudioStream
		assert(s != null and s.get_length() > 0.3, "%s yüklenmeli" % path)
	## Golem dosyalarının 8 sn'lik sessiz tabanı kırpıldı.
	for key in ["shaman_golem_q", "shaman_golem_e", "shaman_golem_oto"]:
		var g: AudioStream = load("res://assets/audio/skills/%s.wav" % key) as AudioStream
		assert(g.get_length() < 2.5, "%s kırpılmış olmalı: %.2f sn" % [key, g.get_length()])
	## Assasin E odak sesi: odak (2 sn) kadar sürer, görünmez olunan anda biter.
	var pc: Dictionary = PlayerScript.get_script_constant_map()
	var inv: AudioStream = load(String(pc["ASSASIN_INVIS_SOUND"])) as AudioStream
	assert(inv != null and absf(inv.get_length() - float(pc["ASSASIN_INVIS_FOCUS_TIME"])) < 0.1, "Assasin sesi odak kadar: %.2f sn" % (inv.get_length() if inv else -1.0))
	var sfx: Dictionary = PlayerScript.get_script_constant_map()["SKILL_SFX"]
	assert(sfx.has("melek_ulti") and not sfx.has("melek_fear"), "Melek R yeni ses")
	var c: Dictionary = LevelUpScript.get_script_constant_map()
	assert(c["LEVEL_UP_STREAM"] is AudioStream and c["CARD_PICK_STREAM"] is AudioStream and c["EVO_PICK_STREAM"] is AudioStream, "level ekranı sesleri")


## Hadime kara deliği: ses deliğin çöküşüne kadar sürer (uzatılmış dosya: çöküş vuruşu HOLE_DURATION + outro'nun 4. karesi = 6,25 sn).
func test_hadime_hole_sound_spans_the_hole() -> void:
	var c: Dictionary = PlayerScript.get_script_constant_map()
	var s: AudioStream = load(String(c["HADIME_HOLE_SOUND"])) as AudioStream
	var collapse: float = HadimeMath.HOLE_DURATION + 4.0 / 16.0
	assert(s != null and s.get_length() > collapse + 0.6 and s.get_length() < collapse + 2.0,
		"ses çöküşü kapsar ve sonrasında söner: %.2f sn (çöküş %.2f)" % [s.get_length() if s else -1.0, collapse])
	## Senkron perdeye bağlı: _play_skill_sfx'in rastgele perdesiyle çalınmamalı.
	var src: String = FileAccess.get_file_as_string("res://scripts/player.gd")
	assert(src.contains("_play_networked_sound(HADIME_HOLE_SOUND, 1.0, HADIME_HOLE_SOUND_DB)"), "kara delik sesi perde 1.0")


## Final boss: kendi sesi / yetenek sesi host'ta karar, boss_event "voice" ile; VOICE_MIN_GAP içinde ikinci ses çıkmaz.
func test_demon_voice_gap() -> void:
	var e := FakeBoss.new()
	add_child(e)
	_spawned.append(e)
	var kit: RefCounted = KitScript.new()
	kit.setup(e)
	kit._voice(true)
	kit._voice(false)
	var voices: Array = e.events.filter(func(ev: Array) -> bool: return ev[0] == "boss_event" and str(ev[1].get("k", "")) == "voice")
	assert(voices.size() == 1 and int(voices[0][1]["v"]) == 1, "ilk ses çalar, aralık içinde ikincisi susar: %s" % str(voices))
	kit._voice_since = KitScript.VOICE_MIN_GAP
	kit._voice(false)
	voices = e.events.filter(func(ev: Array) -> bool: return ev[0] == "boss_event" and str(ev[1].get("k", "")) == "voice")
	assert(voices.size() == 2 and int(voices[1][1]["v"]) == 0, "aralık geçince kendi sesi: %s" % str(voices))
	assert(KitScript.VOICE_MIN_GAP >= (KitScript.VOICE_STREAMS[1] as AudioStream).get_length(), "yetenek sesi biri bitmeden yenisi başlamasın")
	kit.on_boss_event({"k": "voice", "v": 1}) ## başsızda sessiz çıkar, hata vermemeli
	_cleanup()


## Görünmezken kendi ekranı: miktar FADE_IN'de açılır, FADE_OUT'ta kapanır; kapalıyken çizim yok.
func test_stealth_vision_fades() -> void:
	var sv: CanvasLayer = StealthVisionScript.new()
	add_child(sv)
	_spawned.append(sv)
	var rect: ColorRect = sv.get_node("StealthVision") as ColorRect
	assert(not rect.visible, "başta kapalı")
	sv.set_amount_toward(1.0, StealthVisionScript.FADE_IN * 0.5)
	assert(is_equal_approx(sv.amount, 0.5) and rect.visible, "yarı yolda yarı: %s" % sv.amount)
	sv.set_amount_toward(1.0, StealthVisionScript.FADE_IN)
	assert(is_equal_approx(sv.amount, 1.0), "tam")
	sv.set_amount_toward(0.0, StealthVisionScript.FADE_OUT)
	assert(sv.amount == 0.0 and not rect.visible, "kapandı")
	_cleanup()
