extends Node

## EFEKT BÜTÇESİ (2026-10-10, kullanıcı: "talonun E si fpsi inanılmaz düşürüyor, nedenini anlamaya çalış"). Ölçüm (gerçek Main + renderer, 250 yaratık, 5 silah): E'nin 5-6 kat saldırı hızı her isabette /
## kanama tikinde doğan efsun sprite efektlerini, gece ışıklarını ve isabet seslerini katlıyordu (saniyede ~900 düğüm, 81 -> 40 fps). Bütçeler: fx_enchant_sprite.gd MAX_ONESHOT, atmosphere.gd MAX_GLOWS,
## projectile.gd isabet sesi sıklığı. Hepsi SADECE kozmetik; hasar/etki efekt düğümlerine bağlı değildir.

const SpriteFx: GDScript = preload("res://scripts/fx_enchant_sprite.gd")
const EnchantFxScript: GDScript = preload("res://scripts/enchant_fx.gd")
const AtmosphereScript: GDScript = preload("res://scripts/atmosphere.gd")
const NightGlowScript: GDScript = preload("res://scripts/night_glow.gd")

var _made: Array[Node] = []


func _cleanup() -> void:
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()
	SpriteFx.reset_budget()


func _count_sprites() -> int:
	var n: int = 0
	for c: Node in get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("fx_enchant_sprite.gd"):
			n += 1
	return n


func test_one_shot_enchant_sprites_stop_spawning_at_the_budget_and_recover_after_they_end() -> void:
	get_tree().current_scene = self
	SpriteFx.reset_budget()
	var tree: SceneTree = get_tree()
	for i in range(SpriteFx.MAX_ONESHOT * 3):
		var n: Node2D = SpriteFx.spawn(tree, Vector2(i * 3, 0), {"sheet": "mini_pop"})
		if n != null:
			_made.append(n)
	assert(_made.size() == SpriteFx.MAX_ONESHOT, "bütçe dolunca yeni tek seferlik efekt doğmaz: %d" % _made.size())
	assert(SpriteFx.live_oneshots() == SpriteFx.MAX_ONESHOT and SpriteFx.over_budget({"sheet": "mini_pop"}))
	## EnchantFx.play bütçe doluyken yerelde doğurmaz (ağa da yollamaz)
	var before: int = _count_sprites()
	EnchantFxScript.play(tree, "sprite", Vector2(500, 0), {"sheet": "mini_pop"})
	assert(_count_sprites() == before, "play() bütçe doluyken efekt doğurmaz")
	## sürekli (anahtarlı) ve döngülü efektler bütçeye girmez
	var keyed: Node2D = SpriteFx.spawn(tree, Vector2(900, 0), {"sheet": "mini_pop", "key": "test_key", "loop_time": 1.0})
	assert(keyed != null, "anahtarlı sürekli efekt bütçeden bağımsız")
	_made.append(keyed)
	assert(not SpriteFx.over_budget({"sheet": "mini_pop", "key": "k"}) and not SpriteFx.over_budget({"sheet": "mini_pop", "loop_time": 2.0}) and not SpriteFx.over_budget({"sheet": "mini_pop", "follow_slot": 1}))
	## efektler bitince (ağaçtan çıkınca) sayaç düşer ve yeni efekt doğabilir
	for n: Node in _made:
		if n != keyed:
			n.free()
	_made = [keyed]
	assert(SpriteFx.live_oneshots() == 0, "efektler gidince sayaç sıfır: %d" % SpriteFx.live_oneshots())
	var again: Node2D = SpriteFx.spawn(tree, Vector2(0, 100), {"sheet": "mini_pop"})
	assert(again != null, "bütçe boşalınca yeniden doğar")
	_made.append(again)
	_cleanup()


func test_night_glow_attachments_stop_at_the_cap_but_existing_lights_stay() -> void:
	get_tree().current_scene = self
	var atmo := Node2D.new()
	atmo.set_script(AtmosphereScript)
	add_child(atmo)
	_made.append(atmo)
	var raw: Dictionary = {"c": Color(1, 0.8, 0.5), "r": 40.0, "e": 0.7}
	var lights: Array = []
	for i in range(AtmosphereScript.MAX_GLOWS + 40):
		var target := Node2D.new()
		add_child(target)
		_made.append(target)
		atmo._attach_glow(target, raw)
		if target.has_node("NightGlow"):
			lights.append(target)
	var total: int = get_tree().get_node_count_in_group(NightGlowScript.GROUP)
	assert(total <= AtmosphereScript.MAX_GLOWS, "ışık sayısı sınırı aşmaz: %d" % total)
	assert(lights.size() == AtmosphereScript.MAX_GLOWS - (total - lights.size()), "ilk gelenler ışık aldı, sonrakiler almadı")
	assert(AtmosphereScript.MAX_GLOWS >= 64, "sınır, normal yoğunlukta (oyuncular + silahlar + birkaç efekt) hiç devreye girmeyecek kadar geniş")
	_cleanup()
