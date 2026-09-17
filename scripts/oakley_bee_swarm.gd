extends Node2D

## Oakley'in Arı Sürüsü yeteneği (R, kullanıcı isteği: "Oakley yeni
## yetenekleri" 3. Yetenek - SADECE Oakley, Melek'e dokunulmadı, bkz.
## characters.gd DEFS[2] skill3). Bulunduğu konumda 10sn süren bir alan -
## içindeki yaratıklara
## saniyede 1 zehir yükü (en fazla 10) biriktirir.
##
## DÜZELTME (kullanıcı isteği: "senkronize et, ben nasıl görüyosam diğer
## oyuncular da öyle görmeli") - bu efekt SABİT bir konumda durduğu için
## (oakley_vine.gd'nin aksine hareket etmiyor) sürekli konum senkronuna hiç
## gerek yok: player.gd _skill_oakley_bee_swarm() artık "hitscan_impact"/
## "skill_ring" ile AYNI TEK SEFERLİK broadcast_player_vfx deseniyle
## (network_manager.gd "oakley_bee_swarm_spawn" dalı) diğer istemcilere de
## SADECE görsel halkayı (oakley_bee_swarm_ring.gd) gösteriyor - bu KOZMETİK
## kopya asla apply_bee_poison() ÇAĞIRMAZ (enemy.gd host-yetkili olduğu için
## her istemcinin kendi kopyası aynı yaratıklara ayrı ayrı istek gönderirse
## hasar/yük KATLANIRDI - gerçek yük/hasar SADECE döken oyuncunun kendi
## istemcisindeki bu script çalışır).
## class_name: RADIUS/DURATION'ın network_manager.gd'de İKİNCİ bir kopyası
## YAZILMASIN diye (bkz. CLAUDE.md paylaşılan sabit kuralı).
class_name OakleyBeeSwarm

const RADIUS := 130.0
const DURATION := 10.0
const STACK_INTERVAL := 1.0
const DAMAGE_RATIO_PER_STACK := 0.20 ## saldırı gücünün %20'si, 4sn'ye yayılı (bkz. enemy.gd apply_bee_poison)

var _damage_bonus: float = 0.0
var _duration_remaining: float = DURATION
var _stack_timer: float = 0.0
var _visual: Node2D = null


func setup(caster_damage_bonus: float) -> void:
	_damage_bonus = caster_damage_bonus


func _ready() -> void:
	z_index = 3
	_visual = Node2D.new()
	_visual.set_script(preload("res://scripts/oakley_bee_swarm_ring.gd"))
	add_child(_visual)
	if _visual.has_method("setup"):
		_visual.call("setup", RADIUS)


func _process(delta: float) -> void:
	_duration_remaining -= delta
	if _duration_remaining <= 0.0:
		queue_free()
		return
	_stack_timer -= delta
	if _stack_timer <= 0.0:
		_stack_timer += STACK_INTERVAL
		_apply_stacks()


func _apply_stacks() -> void:
	var per_stack_tick_damage: float = (_damage_bonus * DAMAGE_RATIO_PER_STACK) / 4.0 ## bkz. enemy.gd apply_bee_poison - 4sn'ye yayılı, 1sn'lik tik
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if global_position.distance_to(e.global_position) <= RADIUS:
			if e.has_method("apply_bee_poison"):
				e.call("apply_bee_poison", per_stack_tick_damage)
