extends Sprite2D

## Lich büyülü atışı "A - Ruh Alevi" (madde 280; prototip tools/proto_20261019/lich_mermi_proto.py, sayfalar tools/gen_lich_ruh_alevi.py).
## enemy_projectile.gd `style` > 0 iken fx_projectile_orb.gd'nin yerine bu Sprite2D çizer: satır = uçuş yönü (32 yön, her yön sanat
## çözünürlüğünde AYRI çizilmiş - döndürülen piksel sprite'ı tırtıklı oluyordu), sütun = 6 karelik titreme (14 fps). Kare ilerletmesi
## merminin kendi _physics_process'inden `advance` ile (mermi başına ayrı _process geri çağrısı yok). 1 sanat px = PixelDraw.TEXEL dünya
## px (lich pikseli ~1,23). Ayrıca enemy.gd'nin lich'e özel atış kuralları (stil, renk, asa ucu, parlama karesi) burada TEK yerde.

const PixelDraw := preload("res://scripts/pixel_draw.gd")
const SHEET: Texture2D = preload("res://assets/fx/lich/ruh_alevi.png")
const SHEET_SMALL: Texture2D = preload("res://assets/fx/lich/ruh_alevi_kucuk.png")
const NDIR := 32
const NF := 6
const ANIM_FPS := 14.0

## enemy_projectile.gd `style` değerleri - ağda da bu sayı gider (NetworkManager.broadcast_enemy_projectile).
const STYLE_ORB := 0 ## aile renginde piksel küre (Demon / İblis / Röntgen)
const STYLE_SPELL := 1 ## lich büyüsü (enemy.gd _fire_ranged_attack)
const STYLE_SMALL := 2 ## lich normal atışı (enemy.gd _fire_homing_attack) - aynı alevin küçük hâli

## Mermi rengi = isabet efekti + gece ışığı (night_glow_catalog "tint"): lich asa parlamasının turkuazı. Lich sahnelerindeki
## projectile_tint (eski limon yeşili) artık kullanılmıyor.
const TINT := Color(0.24, 0.94, 0.8)

## Saldırı klibi bu kareden başlar (8 karelik Attack sayfasında asa parlaması 5-6. kare; eskiden mermi 0. karede çıkıyor, asa ~0,6 sn
## SONRA parlıyordu). Saldırı durumunun SÜRESİ (= hareket kilidi, EW_F_ATTACK_LOCK) değişmez, klip son karede bekler.
const FLASH_FRAME := 6
## Asa parlaması haçının merkezi (doku px, 64 px hücre merkezine göre), satır sırası enemy.gd ROW_DOWN / ROW_UP / ROW_LEFT / ROW_RIGHT.
## Lich 1/2/3 Attack sayfalarının 6. karesinden ölçüldü (üçünde aynı).
const STAFF_TIP: Array[Vector2] = [Vector2(9.5, -9.5), Vector2(-10.5, -9.5), Vector2(-18.5, -14.5), Vector2(18.5, -14.5)]
const LICH_SCENE_PREFIX := "res://scenes/creatures/enemy_lich"

var _t: float = 0.0
var _row: int = 0


static func is_lich(enemy: Node) -> bool:
	return enemy != null and enemy.scene_file_path.begins_with(LICH_SCENE_PREFIX)


## Yön -> sayfa satırı (0 = +x, açı saat yönünde artar = Vector2.angle()).
static func dir_row(dir: Vector2) -> int:
	if dir.length_squared() < 0.000001:
		return 0
	return posmod(int(round(dir.angle() / TAU * float(NDIR))), NDIR)


## Asa ucunun dünya konumu: sprite'ın o anki satırındaki parlama noktası (sprite ölçeği / elit büyümesi / ofset to_global'da).
static func staff_tip_global(sprite: Sprite2D, row: int) -> Vector2:
	var tip: Vector2 = STAFF_TIP[clampi(row, 0, STAFF_TIP.size() - 1)]
	if sprite.flip_h:
		tip.x = -tip.x
	return sprite.to_global(sprite.offset + tip)


func setup(dir: Vector2, small: bool) -> void:
	texture = SHEET_SMALL if small else SHEET
	hframes = NF
	vframes = NDIR
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scale = Vector2(PixelDraw.TEXEL, PixelDraw.TEXEL)
	_t = randf() * float(NF) / ANIM_FPS ## art arda atılan alevler aynı karede titremesin
	set_direction(dir)


func set_direction(dir: Vector2) -> void:
	_row = dir_row(dir)
	frame = _row * NF + int(_t * ANIM_FPS) % NF


func advance(delta: float) -> void:
	var before: int = int(_t * ANIM_FPS)
	_t += delta
	var now: int = int(_t * ANIM_FPS)
	if now != before:
		frame = _row * NF + now % NF
