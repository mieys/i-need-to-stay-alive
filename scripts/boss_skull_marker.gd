extends Node2D

## Boss'un ÜSTÜNDEKİ kafatası işareti (kullanıcı isteği 2026-10-05: "bossların üstündeki can ve kalkan barına gerek yok, arayüze bağlı
## bir can/kalkan barı zaten var, sadece kuru kafa sembolü üstlerinde dursun"). Can ve kalkan artık SADECE üst ortadaki boss barında
## (boss_bar_top.gd) görünür; burada altın kenarlı demir plaka içinde kafatası var (prototip O1'in kafatası parçası).
##
## İşaret kafanın PLATE_GAP üstünde durur ve o anki sprite karesine göre kafayla birlikte hafifçe süzülür (enemy.gd
## get_boss_marker_offset, boss_bar_art.gd head_top_local). Boss ölünce gizlenir. enemy.gd'nin eski çubuk arayüzünü
## (set_offset/set_health/set_shield) korur: o çağrılar değişmeden çalışır, sadece can/kalkan burada çizilmez.
## Plaka 15 yerel birim = 30 ekran px (1 yerel birim = 2 ekran px, kamera zoom 2).

const ArtScript: GDScript = preload("res://scripts/boss_bar_art.gd")
## Yumuşatma hızı (1/sn): kareden kareye ±1-2 texel'lik kafa oynamasını biraz sönümler, durum geçişlerinde (saldırı kolu) kayar.
const SMOOTH := 18.0

## Plakanın ÜST kenarının boss köküne göre yerel y'si (tam birime yuvarlanır - piksel ızgarası).
var y_offset: float = -80.0
var _y_smooth: float = -80.0
var _enemy: Node = null


func _ready() -> void:
	_enemy = get_parent()
	set_process(_enemy != null and _enemy.has_method("get_boss_marker_offset"))


func set_offset(offset: float) -> void:
	_y_smooth = offset
	y_offset = roundf(offset)
	queue_redraw()


## Eski çubuk arayüzü: can/kalkan artık üst barda gösteriliyor, burada bilerek yok.
func set_health(_current: float, _max_value: float) -> void:
	pass


func set_shield(_current: float, _max_value: float) -> void:
	pass


func _process(delta: float) -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		return
	if _enemy.get("is_dead") == true:
		visible = false
		return
	var target: float = _enemy.call("get_boss_marker_offset")
	_y_smooth = lerpf(_y_smooth, target, 1.0 - exp(-SMOOTH * delta))
	var y: float = roundf(_y_smooth)
	if y != y_offset:
		y_offset = y
		queue_redraw()


@warning_ignore("integer_division")
func _draw() -> void:
	ArtScript.skull_plate(self, Vector2(-float(ArtScript.PLATE_SIZE / 2), y_offset), 1.0)
