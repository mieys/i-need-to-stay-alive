extends Node

## Kubbe/baloncuk içindeyken DIŞARIDA çalan konumlu sesleri (AudioStreamPlayer2D) boğuk + yankılı MUFFLE bus'ına yollayan TEK
## yönlendirici (2026-10-17, madde 218). Kubbeleri dome_sound_muffle.gd bildirir (yerel oyuncu içindeyken her kare set_dome).
##
## NEDEN Area2D DEĞİL: eskiden kubbenin dışını kaplayan audio_bus_override'lı halka Area2D kuruluyordu; Godot 4.7.2'de bu
## AudioStreamPlayer2D'nin bus'ını HİÇ değiştirmiyor (ölçüldü: headless Dummy sürücü gerçek karıştırır, AudioEffectCapture ile; alan
## fizik sorgusunda bulunuyor ama ses birebir aynı seviyede çıkıyor - boş bir projede, fizik iş parçacığı açık da kapalı da). Yani dış
## sesler hiç boğulmuyordu. Şimdi çalıcının KENDİ `bus`'ı konumuna göre değiştirilir (doğrudan bus atamak çalışıyor).
##
## NASIL: yerel oyuncu en az bir kubbedeyken açılır: ağaçtaki tüm AudioStreamPlayer2D'ler bir kez taranır + node_added ile yenileri
## yakalanır. Bus'ı Master olup kubbelerin dışında kalan -> MUFFLE, MUFFLE olup kubbeye giren -> Master; başka bus'lara (taç silahı
## BarrierRimWeapon - audio_buses.gd route_rim_sound) dokunmaz. Oyuncu/kukla sesleri (sınırı geçebilir) her kare, geri kalanı
## (yaratık/dünya sesleri - yaratık kubbeye giremez) karede SWEEP_PER_FRAME tane döner. Kubbeden çıkınca hepsi Master'a döner.
## Yeni ses düğümü eklenir eklenmez (ebeveyninin konumuyla) ve kare sonunda (asıl konumu atanmış olarak) yönlendirilir.

const AudioBuses := preload("res://scripts/audio_buses.gd")
const PaladinDome := preload("res://scripts/paladin_dome.gd")
const SWEEP_PER_FRAME := 96
const OWNER_SEARCH_DEPTH := 4 ## ses düğümünün kaç ata yukarısına kadar oyuncu aranır

static var _instance: Node = null

## anahtar (kubbe düğümünün instance id'si) -> [merkez: Vector2, yarıçap: float, elips: bool]
var _domes: Dictionary = {}
var _hot: Array = [] ## oyuncu/kukla sesleri: her kare
var _cold: Array = [] ## diğerleri: sırayla
var _sweep: int = 0
var _active: bool = false
var _tree: SceneTree = null


static func set_dome(tree: SceneTree, key: int, center: Vector2, radius: float, elliptic: bool) -> void:
	if tree == null:
		return
	if _instance == null or not is_instance_valid(_instance):
		_instance = (load("res://scripts/dome_sound_router.gd") as GDScript).new()
		_instance.name = "DomeSoundRouter"
		tree.root.add_child.call_deferred(_instance)
	_instance._domes[key] = [center, radius, elliptic]
	if not _instance._active:
		_instance._activate(tree)


static func clear_dome(key: int) -> void:
	if _instance == null or not is_instance_valid(_instance):
		return
	_instance._domes.erase(key)
	if _instance._domes.is_empty():
		_instance._deactivate()


## `pos` yerel oyuncunun içinde olduğu kubbelerin hepsinin dışında mı (= boğuk duyulmalı).
static func is_outside(pos: Vector2) -> bool:
	if _instance == null or not is_instance_valid(_instance) or _instance._domes.is_empty():
		return false
	return _instance._outside(pos)


func _outside(pos: Vector2) -> bool:
	for d: Array in _domes.values():
		var inside: bool = PaladinDome.contains(d[0], d[1], pos) if d[2] else pos.distance_to(d[0]) <= float(d[1])
		if inside:
			return false
	return true


func _activate(tree: SceneTree) -> void:
	_active = true
	_tree = tree
	AudioBuses.muffle_bus() ## bus'ı kur
	_hot.clear()
	_cold.clear()
	_sweep = 0
	for n in tree.root.find_children("*", "AudioStreamPlayer2D", true, false):
		_track(n as AudioStreamPlayer2D)
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)


func _deactivate() -> void:
	_active = false
	if _tree != null and _tree.node_added.is_connected(_on_node_added):
		_tree.node_added.disconnect(_on_node_added)
	_tree = null
	for list: Array in [_hot, _cold]:
		for p in list:
			if is_instance_valid(p) and (p as AudioStreamPlayer2D).bus == AudioBuses.MUFFLE_BUS:
				(p as AudioStreamPlayer2D).bus = &"Master"
	_hot.clear()
	_cold.clear()


func _on_node_added(n: Node) -> void:
	if n is AudioStreamPlayer2D:
		_track(n as AudioStreamPlayer2D)
		_route_later.call_deferred(n)


func _track(p: AudioStreamPlayer2D) -> void:
	if p == null:
		return
	(_hot if _belongs_to_player(p) else _cold).append(p)
	_route(p)


func _belongs_to_player(n: Node) -> bool:
	var a: Node = n.get_parent()
	for _i in range(OWNER_SEARCH_DEPTH):
		if a == null:
			return false
		if a.is_in_group("player") or a.is_in_group("remote_players"):
			return true
		a = a.get_parent()
	return false


func _route_later(p: Variant) -> void:
	if is_instance_valid(p) and _active:
		_route(p as AudioStreamPlayer2D)


func _route(p: AudioStreamPlayer2D) -> void:
	if not p.is_inside_tree():
		return
	var b: StringName = p.bus
	if b != &"Master" and b != AudioBuses.MUFFLE_BUS:
		return
	var want: StringName = AudioBuses.MUFFLE_BUS if _outside(p.global_position) else &"Master"
	if b != want:
		p.bus = want


func _physics_process(_delta: float) -> void:
	if not _active:
		return
	var i: int = 0
	while i < _hot.size():
		var p: Variant = _hot[i]
		if not is_instance_valid(p):
			_hot[i] = _hot[_hot.size() - 1]
			_hot.pop_back()
			continue
		_route(p as AudioStreamPlayer2D)
		i += 1
	var done: int = 0
	while done < SWEEP_PER_FRAME and not _cold.is_empty():
		if _sweep >= _cold.size():
			_sweep = 0
		var q: Variant = _cold[_sweep]
		if not is_instance_valid(q):
			_cold[_sweep] = _cold[_cold.size() - 1]
			_cold.pop_back()
			continue
		_route(q as AudioStreamPlayer2D)
		_sweep += 1
		done += 1
