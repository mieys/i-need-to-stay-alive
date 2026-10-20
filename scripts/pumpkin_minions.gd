extends RefCounted

## BALKABAĞI KAFA'NIN MİNYONLARI (kullanıcı isteği 2026-10-09): "Pumpkinler oyunculara yaklaşınca patlayarak alan hasarı olarak 20 hasar verir. Yarasalar ısırınca kanama bırakarak her
## saniye 5 hasar verir. Balkabakları normal yaratıklara göre %20, yarasalar %30 daha hızlı; statları mevcut kademe yaratıklarının %70'i / %30'u" (hız + can oranları enemy_spawner.gd spawn_summon).
## Aileler: "kabak" (patlayan balkabağı) ve "yarasa" (kanatan yarasa) - enemy_abilities.gd bu sınıfı oluşturur; SADECE host/tek oyunculuda process() çalışır.
##   KABAK: hedefe EXPLODE_RANGE yaklaşınca durur, FUSE sn "saldırı" animasyonu (atlama + pençe), sonra patlar: PumpkinBlast alan hasarı (BLAST_DAMAGE, BLAST_RADIUS) + kendi parçalanma
##          animasyonu (kabak_death) ile ödülsüz dağılır (dismiss: öldürme sayılmaz, drop yok).
##   YARASA: normal temas ısırığı; isabette take_special_damage "bat_bite" (5 hasar) + player.gd apply_enemy_bleed (4 sn x 5/sn kanama). Hasar eşleşmesi handle_melee_hit'te.
## Minyonlar sahibi boss (meta "summoner") ölünce/yok olunca kendiliğinden ödülsüz dağılır.

const AbilitiesScript := preload("res://scripts/enemy_abilities.gd")

const BLAST_DAMAGE := 80.0 ## 2026-10-19 (kullanıcı: "balkabağı patlaması ve yarasa ısırığı hasarı 2 kat"): 40 -> 80. Eski: x0,8 kesintisi iptal edildi (32 -> 40). ## 2026-10-11: x0,8 (kullanıcı: "tüm yaratıkların hasarını %20 azalt"), 40 -> 32. 2026-10-10: 20 -> 40 (kullanıcı: "balkabağı bossunun hasarını 2 kat arttır")
const BLAST_RADIUS := 58.0
const EXPLODE_RANGE := 46.0
const FUSE := 0.5
const OWNER_CHECK := 0.5

var e: Node2D = null
var family: String = ""
var _fuse: float = -1.0
var _owner_t: float = 0.0


func setup(owner_enemy: Node2D, fam: String) -> void:
	e = owner_enemy
	family = fam


func process(delta: float, player: Node2D, dist: float) -> void:
	_owner_t += delta
	if _owner_t >= OWNER_CHECK:
		_owner_t = 0.0
		var boss: Variant = e.get_meta("summoner", null)
		if boss != null and (not is_instance_valid(boss) or (boss as Node).get("is_dead") == true):
			_dissolve()
			return
	if family != "kabak":
		return
	if _fuse >= 0.0:
		_fuse -= delta
		e.set("ability_move_lock", maxf(float(e.get("ability_move_lock")), 0.2))
		if _fuse <= 0.0:
			_explode()
		return
	if player != null and is_instance_valid(player) and player.get("is_dead") != true and dist <= EXPLODE_RANGE:
		_fuse = FUSE
		e.set("ability_move_lock", FUSE + 0.2)
		e.call("_play_ability_attack_anim")


func _explode() -> void:
	var pos: Vector2 = e.global_position
	var data: Dictionary = {"radius": BLAST_RADIUS}
	AbilitiesScript.spawn_world_fx(e.get_tree(), "pumpkin_blast", pos, data, true, e, BLAST_DAMAGE)
	AbilitiesScript._broadcast_world_fx("pumpkin_blast", pos, data)
	_dissolve()


## Ödülsüz dağıl (host + istemciler; enemy.gd on_ability_vfx "boss_event" k=dismiss).
func _dissolve() -> void:
	e.call("emit_ability_vfx", "boss_event", {"k": "dismiss"})


## Yarasa ısırığı: normal hasar yerine özel hasar (kanama player.gd take_special_damage "bat_bite"). true = vuruş burada işlendi.
func handle_melee_hit(target: Node) -> bool:
	if family != "yarasa":
		return false
	AbilitiesScript.deal_special_damage(target, float(e.get("contact_damage")), e, "bat_bite")
	return true
