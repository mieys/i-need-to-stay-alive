extends Node2D

## Shaman totem yeteneklerinin CAST (atma) efekti - PIXEL tarzı (kullanıcı isteği, 2026-09-21). Madde 215: kare kare
## prosedürel çizim SPRITE SAYFASINA pişirildi (assets/fx/baked/shaman_cast_<kind>_*, `tools/fx_bake.ps1`; özgün çizim kodu
## `tools/fx_bake_src/fx_shaman_cast.gd` - görünümü değiştirirsen oradan yeniden pişir). Tek AnimatedSprite2D, kare başı çizim yok.
## Yetenek görünümü sahneye gömülü `kind` ile seçilir (ağ yayını sahne YOLUNU taşıdığı için): shield (Kalkan Totemi, mavi),
## attack (Saldırı Totemi, ateş). Player/RemotePlayer'ın ÇOCUĞU olarak doğar, ömrü sabittir (DURATION).

const BakedFx := preload("res://scripts/baked_fx.gd")
const FRAMES := {
	"attack": preload("res://assets/fx/baked/shaman_cast_attack_frames.tres"),
	"shield": preload("res://assets/fx/baked/shaman_cast_shield_frames.tres"),
}
const TEXEL := 1.212 ## PixelDraw.TEXEL - 1 sanat pikseli

@export var kind: String = "shield"

const DURATION := 1.0

var _t: float = 0.0


func _ready() -> void:
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	BakedFx.attach(self, FRAMES.get(kind, FRAMES["shield"]), TEXEL, false)


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
