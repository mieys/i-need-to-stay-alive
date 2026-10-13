extends Node2D

## Cadı E (Uçan Süpürge) - süpürge görseli. Cadının karakter sprite'ının (AnimatedSprite2D) ÇOCUĞU: karakterle AYNI ölçek
## (1 sayfa pikseli = 1 karakter pikseli), CadiMath.set_broom_visual açar/kapatır - yerel oyuncuda ve uzak kuklada AYNI düğüm.
##  - Yan (sol/sağ): broom_side sayfası, karakterin ARKASINDA; satır = yolcu sayısı (sap yolcu başına uzar). Sağ = aynalanır.
##  - Aşağı / yukarı: broom_vert sayfası, karakterin ÖNÜNDE (aşağı: kucaktan kameraya uzanan sap; yukarı: ayakların altından
##    sarkan saman). DÜZ durur (çapraz hali kullanıcı tarafından "yamuk" bulundu). Yukarı bakarken saman son yolcunun altındadır.
## Yükseklik (ride_lift) sprite ofsetiyle verilir; binenler süpürgeye göre RIDE_SIT_DROP kadar aşağıda oturur (kendi ofsetleri -
## player.gd / remote_player.gd rider_lift).

const CadiMath := preload("res://scripts/cadi_math.gd")

## Süpürgeyi süren cadı (Player / RemotePlayer) - yön, biniş süresi ve yolcu sayısı buradan okunur.
var host: Node = null

var _side: AnimatedSprite2D = null
var _vert: AnimatedSprite2D = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_side = AnimatedSprite2D.new()
	_side.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_side.sprite_frames = CadiMath.frames("broom_side")
	_side.show_behind_parent = true
	add_child(_side)
	_vert = AnimatedSprite2D.new()
	_vert.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_vert.sprite_frames = CadiMath.frames("broom_vert")
	add_child(_vert)
	## Yan süpürge karakterin arkasında: bu düğümün kendisi de ebeveynin (karakter sprite'ı) arkasında çizilir; dikey parça
	## ayrı bir çocuk olarak üstte kalsın diye onun z'si bir üstte.
	show_behind_parent = true
	_vert.z_index = 1
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if host == null or not is_instance_valid(host):
		return
	var facing: String = CadiMath.facing_of(host)
	var t: float = float(host.call("cadi_broom_time")) if host.has_method("cadi_broom_time") else 0.0
	var lift: float = CadiMath.ride_lift(t)
	var base: Vector2 = Vector2(host.get("cadi_base_offset")) if "cadi_base_offset" in host else Vector2.ZERO
	var riders: int = CadiMath.riders_of(host.get_tree(), int(host.call("cadi_peer")) if host.has_method("cadi_peer") else 0).size()
	var horizontal: bool = facing == "left" or facing == "right"
	_side.visible = horizontal
	_vert.visible = not horizontal
	if horizontal:
		var clip := StringName("side_%d" % clampi(riders, 0, CadiMath.MAX_PASSENGERS))
		if _side.animation != clip or not _side.is_playing():
			_side.play(clip)
		_side.flip_h = facing == "right"
		var ox: float = CadiMath.BROOM_SIDE_OFFSET_ART.x * (-1.0 if facing == "right" else 1.0)
		_side.offset = base + Vector2(ox, CadiMath.BROOM_SIDE_OFFSET_ART.y - lift)
	else:
		var vclip := StringName(facing)
		if _vert.animation != vclip or not _vert.is_playing():
			_vert.play(vclip)
		## Yukarı bakarken saman en arkadaki yolcunun altında (yolcular ekranda cadının altına dizilir).
		var tail: float = CadiMath.SEAT_VERT_ART * riders if facing == "up" else 0.0
		_vert.offset = base + Vector2(0.0, CadiMath.BROOM_VERT_OFFSET_ART.y - lift + tail)
