extends Node2D

## Ruhani Yetenek "Kalkan Bağı"nın piksel tarzı bağ görseli (kullanıcı isteği: "Kalkan bağı için pixel tarzda
## bir kalkan bağı efekti hazırla") - HER İKİ oyuncunun da KENDİ üstünde duran bir kopyası vardır (kaster VE
## partner, bkz. player.gd _ensure_kalkan_bagi_link_fx/receive_kalkan_bagi_bond - CLAUDE.md'nin "kaster
## görür, diğerleri görmez" hatasına düşmemek için FxPaladinBarrierLink ile AYNI desen). Şovalye'nin
## bariyerinden farkı: o SADECE sahibinin etrafında dönen soyut bir halka, bu GERÇEKTEN iki oyuncu arasına
## gerilen, partnerin CANLI konumunu her karede okuyan bir enerji hattı çiziyor.

##
## YENİDEN TASARIM (kullanıcı isteği 2026-09-25: "kalkan bağının özel efektini pixel tarzda spritesheet olacak şekilde,
## fazla göz yormayan minimalist bir kalkan bağı efekti olarak yeniden tasarla"). Eskiden her karede prosedürel çizilen,
## saniyede 46 birim HIZLA akan kesikli bir hat + iki uçta sürekli yanıp sönen kareler vardı - sürekli göz alıyordu.
## Artık üç küçük sprite (tools/gen_kalkan_bagi_fx.py, assets/fx/kalkan_bagi/):
##   - link_line.png: 1 piksellik yumuşak mavi hat döşemesi (soluk hale + 8 pikselde bir boncuk), hat boyunca tekrarlanır
##     (texture_repeat + region, enemy_laser.gd ile aynı teknik) ve ÇOK yavaş kayar.
##   - link_glint.png: minik kalkan rozeti - GLINT_PERIOD'da bir, bu uçtan partnere süzülür (belirir, parlar, söner).
##   - link_end.png: iki uçta nefes alan minik elmas.
## _draw() yok: sadece sprite konum/dönüş/region güncellemesi. Ölçek PixelDraw.TEXEL (karakterlerle aynı piksel yoğunluğu -
## bu düğüm Player/RemotePlayer'ın 0.5 ölçekli kökünün çocuğu, eski PixelDraw çizimiyle aynı boy).

const PixelDraw := preload("res://scripts/pixel_draw.gd")

const LINE_TEX_PATH := "res://assets/fx/kalkan_bagi/link_line.png"
const GLINT_TEX_PATH := "res://assets/fx/kalkan_bagi/link_glint.png"
const END_TEX_PATH := "res://assets/fx/kalkan_bagi/link_end.png"
const GLINT_FRAMES := 6
const END_FRAMES := 8
const LINE_HEIGHT_PX := 3.0
const LINE_SCROLL_SPEED := 5.0 ## sanat pikseli/sn - bilerek çok yavaş (göz yormasın)
const GLINT_PERIOD := 1.8
const GLINT_TRAVEL := 1.1
const END_FPS := 6.0

var _owner_ref: Node2D = null
var _t: float = 0.0
var _line: Sprite2D = null
var _glint: Sprite2D = null
var _end_a: Sprite2D = null
var _end_b: Sprite2D = null


func setup(owner_node: Node2D) -> void:
	_owner_ref = owner_node


func _ready() -> void:
	z_index = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_line = _make_sprite(LINE_TEX_PATH, 1)
	if _line:
		_line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		_line.centered = false
		_line.region_enabled = true
		_line.offset = Vector2(0.0, -LINE_HEIGHT_PX * 0.5)
	_end_a = _make_sprite(END_TEX_PATH, END_FRAMES)
	_end_b = _make_sprite(END_TEX_PATH, END_FRAMES)
	_glint = _make_sprite(GLINT_TEX_PATH, GLINT_FRAMES)


## Doku henüz import edilmemişse (yeni dosya, editör açılmadan) efekt sessizce görünmez kalır - hata/çökme yok.
func _make_sprite(path: String, hframes: int) -> Sprite2D:
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return null
	var s := Sprite2D.new()
	s.texture = tex
	s.hframes = hframes
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2.ONE * PixelDraw.TEXEL
	s.visible = false
	add_child(s)
	return s


func _process(delta: float) -> void:
	_t += delta
	if not is_instance_valid(_owner_ref):
		queue_free()
		return
	_update_sprites()


func _update_sprites() -> void:
	var to_partner: Vector2 = _partner_local_pos()
	var dist: float = to_partner.length()
	var show: bool = dist >= 4.0
	for s: Sprite2D in [_line, _glint, _end_a, _end_b]:
		if s:
			s.visible = show
	if not show:
		return
	if _line:
		_line.rotation = to_partner.angle()
		## Döşeme 8 piksel - kaydırma o periyotta sarılır (uzun oyunda büyüyen sayı hassasiyet kaybetmesin).
		_line.region_rect = Rect2(-fmod(_t * LINE_SCROLL_SPEED, 8.0), 0.0, dist / PixelDraw.TEXEL, LINE_HEIGHT_PX)
	var end_frame: int = int(_t * END_FPS) % END_FRAMES
	if _end_a:
		_end_a.position = Vector2.ZERO
		_end_a.frame = end_frame
	if _end_b:
		_end_b.position = PixelDraw.snap(to_partner)
		_end_b.frame = (end_frame + END_FRAMES / 2) % END_FRAMES ## iki uç aynı anda değil, sırayla nefes alır
	if _glint:
		var phase: float = fmod(_t, GLINT_PERIOD)
		if phase < GLINT_TRAVEL:
			var u: float = phase / GLINT_TRAVEL
			_glint.position = PixelDraw.snap(to_partner * smoothstep(0.0, 1.0, u))
			_glint.frame = clampi(int(u * float(GLINT_FRAMES)), 0, GLINT_FRAMES - 1)
		else:
			_glint.visible = false


## Sahibin peer id'si: RemotePlayer kuklasında kendi peer_id alanı, yerel oyuncuda (player.gd'de peer_id YOK) bu istemcinin id'si.
func _owner_peer_id() -> int:
	if "peer_id" in _owner_ref:
		return int(_owner_ref.get("peer_id"))
	return multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0


## Bağın karşı ucu: bir RemotePlayer kuklası YA DA (sahip bir kuklaysa ve partner BU istemcinin oyuncusuysa) yerel oyuncu.
func _find_partner(pid: int) -> Node2D:
	for rp in get_tree().get_nodes_in_group("remote_players"):
		if is_instance_valid(rp) and "peer_id" in rp and int(rp.peer_id) == pid:
			return rp as Node2D
	if multiplayer.has_multiplayer_peer() and pid == multiplayer.get_unique_id():
		return get_tree().get_first_node_in_group("player") as Node2D
	return null


## Partnerin KENDİ (owner'ın) yerel uzayındaki konumu - bulunamazsa ya da bu hattı karşı uç çiziyorsa ZERO (çizilmez).
## DÜZELTME (kullanıcı bildirimi: "kalkan bağı ... bar birbirimize yanlış görünüyor kendimizde de yanlış görünüyor"):
## eskiden (partner.global_position - owner.global_position) DÜNYA farkı doğrudan yerel çizim koordinatı olarak
## kullanılıyordu - ama bu efekt Player/RemotePlayer'ın çocuğu ve ikisinin de kök düğümünde scale = 0.5 var
## (main.tscn / remote_player.tscn), yani hat partnerin sadece YARISINA kadar uzanıyordu. to_local() sahibin
## ölçeğini (ve ileride eklenebilecek her dönüşümü) hesaba katıyor; piksel boyutu (TEXEL) karakterlerle aynı kalıyor.
func _partner_local_pos() -> Vector2:
	if not is_instance_valid(_owner_ref) or not ("_kalkan_bagi_partner_peer_id" in _owner_ref):
		return Vector2.ZERO
	var pid: int = int(_owner_ref.get("_kalkan_bagi_partner_peer_id"))
	if pid <= 0:
		return Vector2.ZERO
	var partner: Node2D = _find_partner(pid)
	if partner == null or not is_instance_valid(partner):
		return Vector2.ZERO
	## Bağın İKİ ucunda da bu efektin bir kopyası var (bkz. dosya başı) - ikisi de karşılıklı olarak birbirini
	## gösteriyorsa hattı SADECE küçük peer id'li uç çizer, yoksa üst üste iki kesikli hat (çift parlaklık,
	## faz kayması) görünürdü. Karşılıklı DEĞİLSE ve partner yerel oyuncuysa çizilmez: yerel taraf bağı zaten
	## bitirmiş, kuklanın bayrağı sadece bir sonraki durum paketine kadar bayat.
	var owner_pid: int = _owner_peer_id()
	var mutual: bool = "_kalkan_bagi_partner_peer_id" in partner and int(partner.get("_kalkan_bagi_partner_peer_id")) == owner_pid
	if mutual and owner_pid > pid:
		return Vector2.ZERO
	if not mutual and not ("peer_id" in partner):
		return Vector2.ZERO
	return to_local(partner.global_position)


## Gece ışığı (bkz. night_glow.gd): iki oyuncu arasındaki bağ hattı boyunca hafif mavi. Hattı çizmeyen uç (bkz.
## _partner_local_pos notu) ışık da vermez - çift parlaklık olmasın.
func get_glow_segment() -> Array:
	var to_partner: Vector2 = _partner_local_pos()
	if to_partner.length() < 4.0:
		return []
	return [global_position, to_global(to_partner)]
