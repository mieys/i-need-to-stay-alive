extends Node2D

## Matthew'in tilkisinin pixel-tarzı vuruş/pençe efekti - hem oto saldırısında (bkz. player_pet.gd
## _spawn_slash_fx) hem Tilki Hücumu (Q) yeteneğinin her dash isabetinde (bkz. player.gd
## _matthew_fox_dash_sequence) kullanılıyor.
##
## DÜZELTME (kullanıcı bildirimi 2026-09-23: "vurduğu anda da gerçekten hasar verdiği hissedilmeli efekt
## olarak") - önceki sürüm 3 paralel pençe izini KADEMELİ olarak (sırayla belirip) çiziyordu, bu bir "vuruş"
## yerine dekoratif bir "tarama" gibi okunuyordu. Artık ÖNCE anlık, geniş, parlak bir "POW" flaşı + o anda
## HER YÖNE radyal olarak fışkıran sivri darbe çizgileri (klasik çizgi-roman "impact star" dili) - vuruşun
## kendisi ANINDA ve göze çarpan, pençe izleri ikincil/eşlik eden bir detay olarak kalıyor.
##
## rotation ÇAĞIRAN tarafından attack_dir.angle() olarak set edilir (bkz. mevcut _spawn_muzzle_flash/
## _spawn_slash_fx kullanımıyla AYNI desen).

const PixelDraw := preload("res://scripts/pixel_draw.gd")

const LIFETIME := 0.2

var _t: float = 0.0
var _claw_color: Color = Color(1.0, 0.55, 0.15, 1.0)
var _spike_angles: Array = []


## color verilmezse tilkinin kendi turuncu tonu kullanılır (bkz. player_pet.gd'nin eski modulate rengiyle
## AYNI, Color(1.0, 0.5, 0.1) - buraya biraz daha parlak bir varyantı sabit tutuldu).
func setup(color: Color = Color(1.0, 0.55, 0.15, 1.0)) -> void:
	_claw_color = color


func _ready() -> void:
	z_index = 60
	var rs := RandomNumberGenerator.new()
	rs.seed = get_instance_id()
	## Saldırı yönü merkezli, ama HER YÖNE dağılan 7 darbe çizgisi (tam bir daire değil, ön yarım küre
	## ağırlıklı - vuruşun "yönlü" hissi kaybolmasın).
	for i in range(7):
		_spike_angles.append(rs.randf_range(-1.5, 1.5))


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var frac: float = _t / LIFETIME
	var fade: float = 1.0 - frac
	## ANINDA, geniş, parlak "POW" flaşı - ilk %30'da hızla büyüyüp hemen sönüyor (vuruşun kendisi).
	if frac < 0.3:
		var k: float = frac / 0.3
		PixelDraw.disc(self, Vector2(3.0, 0.0), lerp(4.0, 14.0, k), Color(1.0, 0.95, 0.8, (1.0 - k) * 0.95))
	## Her yöne fışkıran sivri darbe çizgileri - hızla dışa büyüyüp sönüyor (impact star).
	for i in range(_spike_angles.size()):
		var ang: float = _spike_angles[i]
		var dir: Vector2 = Vector2(cos(ang), sin(ang))
		var grow: float = clampf(frac / 0.35, 0.0, 1.0)
		var reach: float = lerp(6.0, 24.0, grow) * (0.8 + 0.2 * sin(float(i) * 2.1))
		var a: float = fade * 0.95
		if a > 0.02:
			PixelDraw.line(self, dir * 5.0, dir * reach, Color(_claw_color, a), 2)
	## 3 paralel kavisli pençe izi - artık ANINDA (kademeli değil) beliriyor, sadece fade ile sönüyor -
	## vuruş flaşının/darbe çizgilerinin ARKASINDA ikincil bir detay olarak kalıyor.
	for i in range(3):
		var offset_y: float = float(i - 1) * 10.0
		var center: Vector2 = Vector2(-12.0, offset_y)
		var sweep_total: float = 1.2
		var col := _claw_color
		col.a *= fade * 0.7
		PixelDraw.ring(self, center, 22.0, col, 2, 0, 0, 0.0, -sweep_total * 0.5, sweep_total)
	## Uçuşan kıvılcım pikselleri.
	for i in range(_spike_angles.size()):
		var dist: float = 12.0 + frac * 40.0
		var p: Vector2 = Vector2(dist, 0.0).rotated(_spike_angles[i])
		var a: float = fade * 0.9
		if a > 0.02:
			PixelDraw.px(self, p, 2, Color(1.0, 0.8, 0.4, a))
