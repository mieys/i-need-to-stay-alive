extends Node
class_name CameraMapLimits

## KULLANICI İSTEĞİ (2026-09-21): "Oyuncular haritanın dışını görememeli, yani haritanın sonuna yaklaştığımızda kamera
## haritanın dışını göstermeyecek şekilde sabit kalmalı."
##
## Aktif Camera2D'nin (oyuncunun kamerası, ölünce sahneye taşınan izleyici kamerası - ikisi de AYNI node) limit_*
## değerlerini haritanın dünya dikdörtgenine (GameManager.get_map_world_rect) kilitler. Kamera haritanın kenarına
## geldiğinde durur, oyuncu kamerayı geçip kenara doğru yürüyebilir.
##
## EV İÇİ İSTİSNASI: ev içi haritanın 20000 birim yanında ayrı bir yerde (bkz. house_interior.gd INTERIOR_OFFSET) -
## kamera haritadan bu kadar uzaktaysa (OUTSIDE_MARGIN) limit KALDIRILIR, yoksa ev içini gösteremezdi. Ne oyuncunun
## içeri girip çıkması ne de izleyicinin evdeki bir müttefiğe geçmesi için ayrıca bir çağrı gerekiyor: kameranın
## konumuna bakıp limiti kendiliğinden açıp kapatıyor.

## Haritanın bu kadar dışına kadar kamera hâlâ "harita üstünde" sayılır (kenardan taşan oyuncu/yaratık için pay).
const OUTSIDE_MARGIN := 2048.0
## Camera2D'nin varsayılan (limitsiz) değeri.
const NO_LIMIT := 10000000

var _last_camera_id: int = 0
var _last_limited: bool = false
var _has_state: bool = false


func _process(_delta: float) -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return
	var rect: Rect2 = GameManager.get_map_world_rect()
	if rect.size == Vector2.ZERO:
		return
	var limited: bool = rect.grow(OUTSIDE_MARGIN).has_point(cam.global_position)
	var cam_id: int = cam.get_instance_id()
	if _has_state and cam_id == _last_camera_id and limited == _last_limited:
		return
	_has_state = true
	_last_camera_id = cam_id
	_last_limited = limited
	apply_limits(cam, rect if limited else Rect2())


## rect boş (Rect2()) ise limit kaldırılır. Testler doğrudan çağırabilsin diye ayrı.
static func apply_limits(cam: Camera2D, rect: Rect2) -> void:
	if rect.size == Vector2.ZERO:
		cam.limit_left = -NO_LIMIT
		cam.limit_top = -NO_LIMIT
		cam.limit_right = NO_LIMIT
		cam.limit_bottom = NO_LIMIT
		return
	cam.limit_left = int(floor(rect.position.x))
	cam.limit_top = int(floor(rect.position.y))
	cam.limit_right = int(ceil(rect.end.x))
	cam.limit_bottom = int(ceil(rect.end.y))
