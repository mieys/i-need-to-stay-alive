extends Node2D
class_name FxPaladinBarrierLink

## Şovalye Adam'ın Koruma Bariyeri (skill3, id 29) - buflanmış bir dostun
## KENDİ üstünde (kendi karakterinin çocuğu olarak) duran, "2 yandan
## parantez gibi" dönen iki yay çizen saf görsel efekt. Oyun durumuna hiç
## etkisi yoktur - gerçek mekanik (hasar yansıtma) player.gd damage_
## redirect_*/take_damage() üzerinden çalışır, bu SADECE o durumun kimin
## üstünde göründüğünü gösterir.
##
## Kullanıcı isteği doğrultusunda (CLAUDE.md'nin "kaster görür, diğerleri
## görmez" hata sınıfına düşmemek için) bu node hem buflanan oyuncunun
## KENDİ client'ında hem HERKESİN ekranındaki kuklasında ayrı ayrı
## oluşturulur (bkz. player.gd/remote_player.gd _refresh_barrier_link_
## visual) - senkronize edilen tek şey basit bir "aktif mi" bayrağıdır.

var _time: float = 0.0
const RADIUS := 26.0
const COLOR := Color(0.95, 0.85, 0.35, 0.9)

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	## "Parantez" hissi: her biri dairenin yaklaşık yarısını kaplayan iki
	## yay, karşılıklı iki yandan, yavaşça dönerek.
	var spin: float = _time * 1.4
	var arc_span: float = PI * 0.7
	draw_arc(Vector2.ZERO, RADIUS, spin - arc_span * 0.5, spin + arc_span * 0.5, 20, COLOR, 3.0, true)
	draw_arc(Vector2.ZERO, RADIUS, spin + PI - arc_span * 0.5, spin + PI + arc_span * 0.5, 20, COLOR, 3.0, true)
