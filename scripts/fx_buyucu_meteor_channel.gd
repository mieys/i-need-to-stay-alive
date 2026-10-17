extends Node2D

## Büyücü Kız Meteor Patlaması kanalı (2026-10-17, madde 188; kullanıcı: "yeni hazırladığın meteorlar iyiydi onlar kalsın"): ayak altında
## 2:1 rün çemberi - üstünde KANAL İLERLEMESİ ateş yayı süre boyunca dolar, rün çentikleri sırayla yanar; şapka ucundan göğe kor yükselir;
## bitince çember parlayıp parçalanır. player.gd _skill_buyucu_meteor -> _play_and_broadcast_skill_fx (props duration) - uzak kopya aynı sahne.
## Çember yerde kalır (Yükseliş havalanmasında da); korlar karakterin o anki offset'ini (havalanma) ve yönünü izler.
## Eski kanal görünümü: karakterin turuncu modulate'ı (kaldırıldı). "Yükseliş" görünümü (buyucu_levitate.gd) ESKİ hâlinde.

const BuyucuFxScript := preload("res://scripts/buyucu_fx.gd")
const EMBER_FPS := 15.0

var duration: float = 3.0

var _ring: Node = null
var _embers: Sprite2D = null
var _t: float = 0.0
var _ended: bool = false


func _ready() -> void:
	var p: Node = get_parent()
	var frames: float = float(BuyucuFxScript.SHEETS["r_ring"])
	_ring = BuyucuFxScript.char_layer(self, p, "r_ring", -1, frames / maxf(duration, 0.1))
	_ring.call("finish_after", "r_ring_end")
	_ring.tree_exited.connect(queue_free)
	_embers = BuyucuFxScript.char_layer(self, p, "r_embers", 2, EMBER_FPS, BuyucuFxScript.facing_left(p), true)


func _process(delta: float) -> void:
	_t += delta
	var p: Node = get_parent()
	if is_instance_valid(_embers) and p != null:
		var anim: Variant = p.get("anim")
		if anim is AnimatedSprite2D:
			_embers.offset = (anim as AnimatedSprite2D).offset
		_embers.flip_h = BuyucuFxScript.facing_left(p)
	if _ended:
		return
	var dead: bool = p != null and (p.get("is_dead") == true or p.get("is_downed") == true)
	if _t >= duration or dead:
		_ended = true
		if is_instance_valid(_embers):
			_embers.queue_free()
		if dead and is_instance_valid(_ring):
			_ring.call("finish", "r_ring_end")
