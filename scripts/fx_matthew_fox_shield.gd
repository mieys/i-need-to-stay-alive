extends Node2D
class_name MatthewFoxShieldFx

## Matthew'ün ULTİ'sinin (Feda Kalkanı) tilki kulaklı pixel-art sihirli bariyeri.
## Hem kaster'da hem (remote_player.gd _ensure_matthew_dome_visual) diğer istemcilerde AYNI sahne kullanılır.
##
## DÜZELTME (kullanıcı bildirimi 2026-09-24: "matthewin r'si fpsi tam tamına 100 azaltıyor" - bkz.
## performans denetimi): GÖRÜNÜM artık PROSEDUREL DEĞİL. Eskiden _draw() içinde 4 halka + 2x14x13
## kulak deseni + dönen ateş küreleri + tarama dolgusu karede ~500-700 draw_rect() çağrısıyla
## YENİDEN ÇİZİLİYORDU - kalkan aktif olduğu SÜRE boyunca kesintisiz. Artık görünüm tools/gen_
## heavy_fx_perf_sprite.py ile PNG'ye "pişirildi":
##  - assets/fx/matthew_fox_shield/loop_sheet.png: kalkan AKTİFKEN dönen sürekli döngü (en
##    baskın hareket olan tilki ateşi yörüngesi - t*1.5 rad/s - TAM BİR periyot, 60 kare, ~4.19sn
##    - dash-dönen halka gibi daha hızlı ikincil detaylarda küçük faz sıçraması kabul edildi).
##  - assets/fx/matthew_fox_shield/pop_sheet.png: pop() çağrılınca oynayan 0.4sn'lik kırılma
##    patlaması (tek seferlik, 20 kare).
## draw_rect sayısı ~500-700 -> 1'e indi.
## ÖLÇEK NOTU: PNG "1 raster piksel = 1 world birimi" pişirildi (bkz. o script'in ÖLÇEK NOTU) -
## PixelDraw.TEXEL ile AYRICA ölçeklenmez.

const LoopFrames := preload("res://assets/fx/matthew_fox_shield/loop_frames.tres")
const PopFrames := preload("res://assets/fx/matthew_fox_shield/pop_frames.tres")

var _sprite: AnimatedSprite2D = null
var popping: bool = false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.sprite_frames = LoopFrames
	_sprite.centered = true
	add_child(_sprite)
	_sprite.play("loop")
	## Steady-state döngü rastgele bir başlangıç fazından başlasın (birden fazla oyuncu aynı anda
	## kalkan açarsa hepsi TIPATIP aynı karede olmasın).
	_sprite.frame = randi() % LoopFrames.get_frame_count("loop")


func pop() -> void:
	if popping:
		return
	popping = true
	_sprite.sprite_frames = PopFrames
	_sprite.animation_finished.connect(queue_free)
	_sprite.play("pop")
