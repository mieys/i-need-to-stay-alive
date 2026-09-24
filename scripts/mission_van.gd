extends Node2D
class_name MissionVan

## "Konvoyu Koru" (Escort the van) - kullanıcı isteği: "ufak bir daire olucak o daireye yakın
## durarak hedefe itmesini sağlıcaz uzaklaşırsak daire geri döner yavaşça (gidiş hızının
## %20si kadar)". Bu script SALT GÖRSEL - gerçek itme/geri kayma hesabı world_event_manager.gd
## _tick_mission'da (host-only) yapılır, sonuç world_event_progress (value=0..1 ilerleme)
## ile TÜM istemcilere yayılır; bu Node HER istemcide (host dahil) o ilerlemeden konumunu
## türetir (bkz. set_progress) - Capture the Point'in aynı "host hesaplar, herkes aynı
## formülle çizer" mantığı.
## "Geçici temsili görsel" (kullanıcı isteği) - basit bir kutu/tekerlek, gerçek sanat değil.

var start_pos: Vector2 = Vector2.ZERO
var end_pos: Vector2 = Vector2.ZERO
var push_radius: float = 130.0
var _progress: float = 0.0
var _pushed: bool = false ## son ilerleme yönü ileri miydi (sadece görsel - tekerlek/renk ipucu)


func setup(p_start: Vector2, p_end: Vector2, p_push_radius: float) -> void:
	start_pos = p_start
	end_pos = p_end
	push_radius = p_push_radius
	global_position = start_pos
	rotation = (end_pos - start_pos).angle()


func _ready() -> void:
	z_index = 4


func set_progress(value: float, target: float, pushed: bool) -> void:
	_progress = clamp(value / maxf(target, 0.001), 0.0, 1.0)
	_pushed = pushed
	global_position = start_pos.lerp(end_pos, _progress)
	queue_redraw()


func _draw() -> void:
	## İtme yarıçapı (kullanıcı isteği: "ufak bir daire") - dünya dönüşünden bağımsız
	## görünsün diye ters rotasyon uygulanmış bir daire.
	draw_arc(Vector2.ZERO, push_radius, 0, TAU, 40, Color(0.55, 0.9, 1.0, 0.4).lerp(Color(1.0, 0.55, 0.3, 0.5), 0.0 if _pushed else 1.0), 2.5)
	## Konvoy (kutu gövde + iki tekerlek) - "geçici temsili görsel".
	draw_rect(Rect2(-24, -16, 48, 26), Color(0.5, 0.32, 0.16, 1.0))
	draw_rect(Rect2(-24, -16, 48, 26), Color(0.2, 0.12, 0.05, 0.8), false, 2.0)
	draw_circle(Vector2(-15, 12), 7.0, Color(0.12, 0.1, 0.08, 1.0))
	draw_circle(Vector2(15, 12), 7.0, Color(0.12, 0.1, 0.08, 1.0))
	## İlerleme çubuğu (küçük, konvoyun üstünde)
	var bar_w := 50.0
	draw_rect(Rect2(-bar_w * 0.5, -34.0, bar_w, 6.0), Color(0.08, 0.06, 0.05, 0.9))
	draw_rect(Rect2(-bar_w * 0.5, -34.0, bar_w * _progress, 6.0), Color(0.95, 0.8, 0.25, 1.0))
