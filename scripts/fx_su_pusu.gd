extends Node2D

## SUDAN PUSU uyarısı + sıçraması (Kara Bataklık, bataklik_tehlike.gd). enemy_spawner.gd (host) yaratığın çıkacağı her noktaya kurar ve
## `_rpc_water_ambush_fx` ile herkese gönderir -> her ekran kendinde çizer (konum + saat yeterli, durum yok).
##  - UYARI (0..WARN sn): suyun yüzünde kabarcıklar - küçük 1-2 px halkalar beliren / patlayan, gitgide sıklaşan (oyuncuya kaçma payı).
##  - SIÇRAMA (WARN..WARN+SPLASH sn): yaratık tam bu anda doğar; iki genişleyen elips halka + yukarı fırlayıp düşen damlalar.
## Dünya pikselinde, düz alfa (dither yok), renkler haritanın su_doku'su (wade_fx.gd ayak örtüsüyle aynı su).

const BataklikTehlike := preload("res://scripts/bataklik_tehlike.gd")
const MapProfilesScript := preload("res://scripts/map_profiles.gd")
const SPLASH := 0.6
const BUBBLE_R := 10.0     ## kabarcıkların yayıldığı yarıçap (px)
const RING_MAX := 16.0     ## sıçrama halkasının en büyük yatay yarıçapı (px)
const DROPS := 7

var warn: float = BataklikTehlike.PUSU_WARN
var _t: float = 0.0
var _su := Color(0.141, 0.404, 0.294)
var _sirt := Color(0.537, 0.729, 0.569)
var _seed: int = 0


func _ready() -> void:
	name = "FxSuPusu"
	z_index = 0 ## karakterler z 1: halkalar / kabarcıklar ayakların altında, suyun üstünde
	_seed = int(absf(global_position.x) * 7.0 + absf(global_position.y) * 13.0)
	var doku: Variant = MapProfilesScript.current().get("su_doku", {})
	if doku is Dictionary:
		_su = (doku as Dictionary).get("renk", _su)
		_sirt = (doku as Dictionary).get("sirt", _sirt)


func _process(delta: float) -> void:
	_t += delta
	if _t >= warn + SPLASH:
		queue_free()
		return
	queue_redraw()


func _px(p: Vector2, c: Color) -> void:
	draw_rect(Rect2(p.floor(), Vector2.ONE), c)


## 1 px elips halka (oyunun 2:1'e yakın zemin elipsleri, wade_fx halkalarıyla aynı oran).
func _ring(rx: float, c: Color) -> void:
	var ry: float = maxf(1.0, rx * 0.42)
	var n: int = maxi(12, int(rx * 5.0))
	var seen := {}
	for i in range(n):
		var a: float = TAU * float(i) / float(n)
		var p := Vector2(roundf(cos(a) * rx), roundf(sin(a) * ry))
		if seen.has(p):
			continue
		seen[p] = true
		_px(p, c)


func _draw() -> void:
	if _t < warn:
		## kabarcıklar: her biri kendi evresinde belirip büyür ve patlar; uyarı ilerledikçe daha çok kabarcık aynı anda
		var k: float = _t / maxf(warn, 0.01)
		var count: int = 2 + int(k * 5.0)
		for i in range(count):
			var h: int = (_seed + i * 977) % 1000
			var a: float = TAU * float(h) / 1000.0
			var r: float = BUBBLE_R * (0.25 + 0.75 * float((h * 37) % 100) / 100.0)
			var p := Vector2(cos(a) * r, sin(a) * r * 0.42).round()
			var ph: float = fmod(_t * 3.2 + float(h % 97) / 97.0, 1.0)
			var c := Color(_sirt.r, _sirt.g, _sirt.b, 0.9 if ph < 0.75 else 0.45)
			if ph < 0.45:
				_px(p, c)
			elif ph < 0.85:
				_px(p + Vector2(-1, 0), c)
				_px(p + Vector2(1, 0), c)
				_px(p + Vector2(0, -1), c)
				_px(p + Vector2(0, 1), c)
		return
	## sıçrama
	var s: float = clampf((_t - warn) / SPLASH, 0.0, 1.0)
	var alpha: float = 0.9 if s < 0.6 else 0.45
	var light := Color(lerpf(_su.r, _sirt.r, 0.8), lerpf(_su.g, _sirt.g, 0.8), lerpf(_su.b, _sirt.b, 0.8), alpha)
	_ring(roundf(4.0 + s * RING_MAX), light)
	if s > 0.25:
		_ring(roundf(2.0 + (s - 0.25) * RING_MAX), Color(light.r, light.g, light.b, alpha * 0.6))
	for i in range(DROPS):
		var h: int = (_seed + i * 613) % 1000
		var dir: float = (float(i) / float(DROPS - 1) - 0.5) * 2.0 ## -1..1 yanlara
		var vx: float = dir * (14.0 + float(h % 7))
		var vy: float = -(46.0 + float(h % 9)) ## yerçekimi 160 px/sn²: ~7-9 px yükselir, ~0,6 sn'de suya döner
		var tt: float = s * SPLASH
		var p := Vector2(vx * tt, vy * tt + 80.0 * tt * tt)
		if p.y > 1.0:
			continue
		_px(p, Color(_sirt.r, _sirt.g, _sirt.b, alpha))
