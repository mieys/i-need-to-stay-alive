extends Node

## 2026-10-18 (kullanıcı: "tüftüfte bişey olunca zehirli duman yazıyor yazmasın. gereksiz yazıları tespit et oyunda savaşırken"):
## savaşta tekrar tekrar çıkan, bilgi taşımayan yazılar çıkmaz.
##  (1) Element tepkimesinin ADI (Zehirli Duman, Buhar Patlaması...) yaratığın üstüne yazılmaz - etkisi (hasar/bulut/patlama) aynen kalır.
##  (2) Necromancer her öldürmede "+N Ruh" yazmaz - ruh sayısı yine artar (toplam pasif simgesinde).
## Sayım yöntemi: yazılar floating_text.tscn sahnesinden sahne köküne eklenir.

const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_rat1.tscn")
const PlayerSceneForText: PackedScene = preload("res://scenes/player.tscn")
const ElementReactions := preload("res://scripts/element_reactions.gd")
const EnchantFx := preload("res://scripts/enchant_fx.gd")
const FLOATING_TEXT_PATH := "res://scenes/floating_text.tscn"

var _made: Array[Node] = []


func _ensure_scene() -> void:
	NetworkManager.is_multiplayer_active = false
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	_clear_floating_texts()


func _floating_texts() -> Array[Node]:
	var out: Array[Node] = []
	for c in get_tree().current_scene.get_children():
		if c.scene_file_path == FLOATING_TEXT_PATH:
			out.append(c)
	return out


func _clear_floating_texts() -> void:
	for c in _floating_texts():
		c.free()


func _cleanup() -> void:
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()
	_clear_floating_texts()


func _new_enemy() -> Node:
	var e: Node = EnemyScene.instantiate()
	add_child(e)
	_made.append(e)
	return e


## Kontrol: sayım yöntemi gerçek bir yazıyı görüyor mu (yoksa aşağıdaki "yazı yok" assert'leri boş geçerdi).
func test_floating_text_count_sees_a_real_popup() -> void:
	_ensure_scene()
	EnchantFx.play(get_tree(), "text", Vector2.ZERO, {"text": "deneme", "color": Color.WHITE})
	assert(_floating_texts().size() == 1, "kontrol: EnchantFx 'text' bir yazı sahnesi eklemeli")
	_cleanup()


## Her tepkime gerçekten tetiklenir (bekleme süresi damgalanır) ama adını yazmaz.
func test_element_reactions_do_not_write_their_names() -> void:
	_ensure_scene()
	assert(not ElementReactions.SHOW_REACTION_NAMES, "tepkime adı yazısı kapalı olmalı")
	for key: String in ElementReactions.REACTIONS:
		_clear_floating_texts()
		var e: Node = _new_enemy()
		ElementReactions.trigger(e, key)
		assert(e._reaction_cd.has(key), "tepkime çalışmalı (bekleme damgası): %s" % key)
		assert(_floating_texts().is_empty(), "tepkime adı yazılmamalı: %s" % key)
	_cleanup()


## Kullanıcının gördüğü durum: yanan yaratığa Tüftüf zehri değince (gerçek apply_burn/apply_poison kancası) "Zehirli Duman" yazısı çıkıyordu.
func test_poison_on_a_burning_enemy_writes_no_zehirli_duman() -> void:
	_ensure_scene()
	var e: Node = _new_enemy()
	e.call("apply_burn", 2.0, 3.0)
	e.call("apply_poison", 5.0, 5.0, 4.0)
	assert(e._reaction_cd.has("yanma+zehir"), "yanma+zehir tepkimesi tetiklenmeli")
	assert(_floating_texts().is_empty(), "'Zehirli Duman' yazısı çıkmamalı")
	_cleanup()


func test_necro_kill_adds_souls_without_a_popup() -> void:
	_ensure_scene()
	var p: Node = PlayerSceneForText.instantiate()
	add_child(p)
	_made.append(p)
	p.necro_souls = 0
	p._necro_on_kill(false)
	assert(p.necro_souls == 1, "normal öldürmede 1 ruh: %d" % p.necro_souls)
	p._necro_on_kill(true)
	assert(p.necro_souls == 6, "boss öldürmede +5 ruh (toplam 6): %d" % p.necro_souls)
	assert(_floating_texts().is_empty(), "öldürme başına '+N Ruh' yazısı çıkmamalı")
	## Kontrol: aynı oyuncunun gerekli uyarıları (ör. yetersiz ruh) hâlâ yazıyor.
	p._spawn_floating_text("RUH YETERSİZ (8)", Color.WHITE)
	assert(_floating_texts().size() == 1, "gerekli uyarı yazıları çıkmaya devam etmeli")
	_cleanup()
