extends Node2D

## Ruhani Yetenek "Adc" (F): 10 sn saldırı hızı / kalkan delme / can emme. Görünüm = prototip "B Rün Mührü" (madde 730, kullanıcı
## seçimi 2026-11-16, madde 734) - eski kızıl zemin + 12 kareli alev + dönen elmaslar + kıvılcım serpintisi silindi.
##  - ayak altında kızıl mühür: iki ince halka 0,25 sn'de saat yönünde çizilerek açılır (assets/fx/ruhani/adc_sigil.png, 5 kare)
##    + üzerinde dönen 3 krem elmas
##  - açılışta genişleyen tek açık sarı yer halkası
##  - süre boyunca 0,42 sn'de bir, gövdenin iki yanından sırayla yükselen çift ok başı (hız ritmi; yüzü örtmez)
## Mühür karakterin ARKASINDA (show_behind_parent), ok başları önünde. Kök ayakta, 1 yerel birim = 1 dünya birimi.

const U := preload("res://scripts/spirit_fx_util.gd")
const SpiritualSkillsScript: GDScript = preload("res://scripts/spiritual_skills.gd")
const SIGIL_TEX := preload("res://assets/fx/ruhani/adc_sigil.png")
const RING_TEX := preload("res://assets/fx/ruhani/ring_ground.png")

const FADE := 0.5
const SIGIL_RX := 15.8
const SIGIL_RY := 6.6
const CHEV_EVERY := 0.42
const CHEV_LIFE := 0.75

var _t: float = 0.0
var _duration: float = SpiritualSkillsScript.ADC_DURATION
var _top: Node2D = null ## mühür dokusunun üstüne elmaslar (aynı z, sonra çizilir)
var _front: Node2D = null


func _ready() -> void:
	U.setup_root(self)
	show_behind_parent = true
	_top = Node2D.new()
	add_child(_top)
	_top.draw.connect(_draw_top)
	_front = U.front_layer(self, _draw_front)


func _process(delta: float) -> void:
	_t += delta
	if _t >= _duration + FADE:
		queue_free()
		return
	modulate.a = U.band(clampf((_duration + FADE - _t) / FADE, 0.0, 1.0), 4)
	queue_redraw()
	_top.queue_redraw()
	_front.queue_redraw()


func _sweep() -> float:
	return clampf(_t / 0.25, 0.0, 1.0)


func _draw() -> void:
	var f: float = _sweep()
	if f > 0.04:
		U.frame(self, SIGIL_TEX, 5, int(ceilf(f * 5.0)) - 1, 0.0, 0.0, Color.WHITE)
	if _t < 0.32:
		var kk: float = _t / 0.32
		var rx: float = 8.0 + 16.0 * U.ease_out(kk)
		U.frame(self, RING_TEX, 23, int(roundf(rx)) - 4, 0.0, 0.0, U.with_a(U.FIRE4, U.band(1.0 - kk, 4)))


func _draw_top() -> void:
	var f: float = _sweep()
	for k in range(3):
		if float(k) / 3.0 > f:
			continue
		var an: float = -PI / 2.0 + float(k) * TAU / 3.0 + _t * 1.1
		U.glyph(_top, U.DIAM, SIGIL_RX * cos(an), SIGIL_RY * sin(an), U.CREAM)


func _draw_front() -> void:
	var n: int = int(_t / CHEV_EVERY)
	for i in range(maxi(0, n - 3), n + 1):
		var born: float = 0.15 + float(i) * CHEV_EVERY
		if born >= _duration:
			continue
		var age: float = _t - born
		if age < 0.0 or age >= CHEV_LIFE:
			continue
		var k: float = age / CHEV_LIFE
		var s: float = -1.0 if i % 2 == 0 else 1.0
		var cx: float = s * 13.0
		var cy: float = -5.0 - 28.0 * U.ease_out(k)
		var al: float = U.band(1.0 - pow(k, 1.5), 4)
		U.glyph(_front, U.CHEVRON, cx, cy + 1.0, U.with_a(U.FIRE2, al * 0.8))
		U.glyph(_front, U.CHEVRON, cx, cy, U.with_a(U.CREAM, al))
		U.glyph(_front, U.CHEVRON, cx, cy + 3.0, U.with_a(U.FIRE3, al * 0.7))
