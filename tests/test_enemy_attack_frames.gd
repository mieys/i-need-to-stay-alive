extends Node

## SALDIRI KARESİ C++'TA (2026-10-19, madde 286): saldırı durumundaki (EW_A_HOLD) kare süresini ve kareyi enemy.gd _advance_frame_sprite yerine C++ (enemy_world.cpp
## step_loco_anim + write_views) yazar, saldırı süresi boyunca yaratık köprünün uyku listesine girebilir. Bu dosya eski yolla (EW_HOLD=0: her fizik karesi GDScript tiki)
## AYNI sonucu verdiğini kanıtlar: her fizik karesinin sonunda sprite karesi + durum, yürüyen bir oyuncuya (bakış satırı değişir) saldıran yaratıklarda aynı tohumla.

const EnemyScript := preload("res://scripts/enemy.gd")
const BridgeScript: GDScript = preload("res://scripts/enemy_world/enemy_world_bridge.gd")

const DT := 1.0 / 60.0
const IDS := ["golem1", "iskelet1", "mantar1", "demon1", "lich1", "iblis1", "hayalet1", "vampire1"]

var _spawned: Array[Node] = []


class _FakePlayer extends Node2D:
	var is_dead: bool = false
	var hits: int = 0
	func take_damage(_amount: float = 0.0, _src: Node = null) -> void:
		hits += 1


func _cleanup() -> void:
	get_tree().paused = false
	## Sahne = bu düğüm: yaratıklar, oyuncu, köprü VE yeteneklerin doğurduğu efektler (ateş topu...) hep çocuğu; hepsi gitsin ki iki koşu aynı boş sahneden başlasın.
	_spawned.clear()
	for node: Node in get_children():
		node.free()
	BridgeScript.set("_instance", null)
	EnemyScript._ew_hold_on = true
	EnemyScript._ew_dormancy_on = true


func _make(id: String, pos: Vector2) -> Node2D:
	var packed: PackedScene = load("res://scenes/creatures/enemy_%s.tscn" % id)
	var e: Node2D = packed.instantiate()
	e.set_meta("creature_id", id)
	add_child(e)
	e.global_position = pos
	_spawned.append(e)
	return e


func _step(b: Node, frames: int) -> void:
	b.set_physics_process(false)
	for i: int in range(frames):
		b._physics_process(DT)
	b.set_physics_process(true)


## Oyuncu yarıçap 60'ta daire çizerek yürür (yaratıklar peşinden gelir, bakış satırı değişir); 12 sn. Döner: kare / durum / uyku dizileri.
func _scenario(hold: bool, dormancy: bool, rng_seed: int, ids: Array = IDS) -> Dictionary:
	await get_tree().physics_frame ## motor fizik karesi sayacı ilerlesin: enemy.gd'nin "bu kare" önbellekleri (Şovalye kubbe sahipleri, Savaş Şevki...) önceki koşudan kalma değerle başlamasın
	seed(rng_seed)
	get_tree().paused = true ## köprünün kendi fizik geçişleri çalışmasın: `await process_frame` sırasında 0-2 fazladan geçiş yaratık sayaçlarını koşudan koşuya 1-2 kare kaydırıyordu (adımlar elle)
	EnemyScript._ew_hold_on = hold
	EnemyScript._ew_dormancy_on = dormancy
	var player := _FakePlayer.new()
	player.add_to_group("player")
	add_child(player)
	_spawned.append(player)
	player.global_position = Vector2(0.0, 0.0)
	var cs: Array = []
	for i in range(ids.size()):
		var ang: float = TAU * float(i) / float(ids.size())
		cs.append(_make(ids[i], Vector2(cos(ang), sin(ang)) * 70.0))
	await get_tree().process_frame
	var b: Node = BridgeScript._instance
	_step(b, 2)
	var frames: Array = []
	var states: Array = []
	var max_asleep_attacking: int = 0
	var attacks: int = 0
	for t in range(720):
		var a: float = float(t) * 0.012
		player.global_position = Vector2(cos(a), sin(a)) * 60.0
		seed(rng_seed * 100003 + t) ## her karede yeniden tohumla: rastgele çekim akışı kareler arasında birikmesin (uyku, çekimin kare içindeki yerini değiştirebilir)
		_step(b, 1)
		var f_row: PackedInt32Array = PackedInt32Array()
		var s_row: PackedInt32Array = PackedInt32Array()
		var asleep_att: int = 0
		for c in cs:
			f_row.append(int(c.frame_sprite.frame) if c.frame_sprite != null else -1)
			s_row.append(int(c._state))
			if c._ew_dormant and c._state == EnemyScript.State.ATTACK:
				asleep_att += 1
			if c._state == EnemyScript.State.ATTACK:
				attacks += 1
		frames.append(f_row)
		states.append(s_row)
		max_asleep_attacking = maxi(max_asleep_attacking, asleep_att)
	var res: Dictionary = {"frames": frames, "states": states, "asleep_attacking": max_asleep_attacking, "attack_ticks": attacks, "hits": player.hits}
	_cleanup()
	return res


func _diff_report(a: Dictionary, b: Dictionary, ids: Array = IDS) -> Array:
	var fa: Array = a["frames"]
	var fb: Array = b["frames"]
	var sa: Array = a["states"]
	var sb: Array = b["states"]
	var bad_frames: int = 0
	var bad_states: int = 0
	var first: String = ""
	for t in range(fa.size()):
		for k in range(ids.size()):
			if fa[t][k] != fb[t][k]:
				bad_frames += 1
				if first == "":
					first = "tik %d %s kare eski=%d yeni=%d durum eski=%d yeni=%d" % [t, ids[k], fa[t][k], fb[t][k], sa[t][k], sb[t][k]]
			if sa[t][k] != sb[t][k]:
				bad_states += 1
	return [bad_frames, bad_states, first]


## Yeteneksiz yaratıklar (golem / iskelet / mantar...) aynı sahnede: rastgele çekim sırası uykuyla değişemez -> kare kare AYNI.
func test_attack_frames_in_cpp_match_the_gdscript_path_tick_for_tick() -> void:
	var ids: Array = ["golem1", "iskelet1", "mantar1", "golem2", "iskelet2"]
	for sd in [101, 202]:
		var old: Dictionary = await _scenario(false, true, sd, ids)
		var cur: Dictionary = await _scenario(true, true, sd, ids)
		assert(int(old["attack_ticks"]) > 200, "senaryoda yeterince saldırı olmalı (saldırı-yaratık-tik: %d)" % int(old["attack_ticks"]))
		assert(int(old["asleep_attacking"]) == 0, "eski yolda saldırı sırasında uyuyan olmamalı")
		assert(int(cur["asleep_attacking"]) >= 2, "yeni yolda saldırı sırasında uyuyan yaratık olmalı (en çok: %d)" % int(cur["asleep_attacking"]))
		var rep: Array = _diff_report(old, cur, ids)
		assert(int(rep[1]) == 0, "durum (saldırı bitiş zamanı) eski yolla AYNI olmalı: %d farklı tik, ilk: %s" % [int(rep[1]), str(rep[2])])
		assert(int(rep[0]) == 0, "sprite karesi eski yolla AYNI olmalı: %d farklı kare, ilk: %s" % [int(rep[0]), str(rep[2])])
		assert(int(old["hits"]) == int(cur["hits"]), "vuruş sayısı aynı olmalı (%d / %d)" % [int(old["hits"]), int(cur["hits"])])


## Yetenekli aileler (iblis / hayalet / vampir / demon / lich) TEK başına: birden çok yetenekli yaratıkta global rastgele çekim sırası uykuyla zaten kayar
## (madde 278 notu), tek yaratıkta kayma yok -> kare kare AYNI olmalı.
func test_attack_frames_match_for_each_ability_family_alone() -> void:
	for id in ["iblis1", "hayalet1", "vampire1", "demon1", "lich1"]:
		var ids: Array = [id]
		var old: Dictionary = await _scenario(false, true, 55, ids)
		var cur: Dictionary = await _scenario(true, true, 55, ids)
		var rep: Array = _diff_report(old, cur, ids)
		assert(int(rep[1]) == 0 and int(rep[0]) == 0, "%s: %d farklı durum, %d farklı kare, ilk: %s" % [id, int(rep[1]), int(rep[0]), str(rep[2])])


func test_switch_off_keeps_the_gdscript_frame_path() -> void:
	var off: Dictionary = await _scenario(false, true, 303)
	assert(int(off["asleep_attacking"]) == 0)
	assert(int(off["attack_ticks"]) > 100)




## Köprü saati: olay aşamasında uyandırılan yaratığın sayaçları bu geçişin delta'sını İKİ kez saymaz (eskiden uyanış _clock'a, yani bu geçiş dahil işliyor, aynı geçişin tiki yine
## çıkarıyordu: yetenek bekleme sayacı ve saldırı süresi 1 kare erken bitiyordu). Hayalet / iblis tek başına, uykulu ve uykusuz kare kare AYNI.
func test_event_wake_counts_each_tick_once() -> void:
	for id in ["iblis1", "hayalet1"]:
		var ids: Array = [id]
		var awake: Dictionary = await _scenario(false, false, 77, ids)
		var asleep: Dictionary = await _scenario(false, true, 77, ids)
		var rep: Array = _diff_report(awake, asleep, ids)
		assert(int(rep[1]) == 0 and int(rep[0]) == 0, "%s: uykulu ve uykusuz koşu AYNI olmalı: %d farklı durum, %d farklı kare, ilk: %s" % [id, int(rep[1]), int(rep[0]), str(rep[2])])
