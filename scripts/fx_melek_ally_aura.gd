extends AnimatedSprite2D

## Kullanıcı isteği ("efekt sistemi" - iyileşme.png/kalkan.png): "iyileşme ve
## kalkan spriteları melek iyileşme ve kalkanı yeteneğiyle dost bireye can
## veya kalkan verdiğinde dost bireyin içinde belirecek. (bu efekt yeteneğin
## süresine bağlı olarak sprite sheetin ortalarında looplanacak ve efekt
## bitmeye yakın sona gelecek) iyileşme bağı kesilirse efekt de kapanmalı.
## ayrıca meleğin üzerindede aynı şekilde gerçekleşecek ama bağ kopma olayı
## olmadığı için stabil bir biçimde süreye bağlı olarak dost bireylerle aynı
## şekilde çalışacak."
##
## Bu TEK script hem Can Basma (fx_melek_heal_aura.tscn) hem Kalkan Yenileme
## (fx_melek_shield_aura.tscn) sahnelerinde kullanılıyor - ikisi de aynı
## intro->loop->outro mantığına sahip, sadece kaynak sprite farklı (bkz.
## player.gd _aura_scene_for).
##
## İKİ kullanım modu:
##   1) MELEK'İN KENDİSİ (bkz. setup(duration)) - sabit süreli, bağ kopması
##      diye bir şey yok, duration dolunca otomatik outro'ya geçip silinir.
##      Varsayılan _duration=6.0 (yeteneğin bilinen sabit süresi) - ağ
##      üzerinden gelen kozmetik kopyalarda setup() hiç çağrılmaz (bkz.
##      player.gd _skill_heal/_skill_kalkan_yenileme - _broadcast_skill_scene
##      ile giden kopyalar), bu yüzden güvenli bir varsayılana düşer.
##   2) MÜTTEFİKTEKİ KULLANIM (bkz. stop()) - bağ HÂLÂ bağlıyken LOOP fazında
##      sonsuza dek kalır (yukarıdaki 6.0's varsayılan, bağlantı hâlâ
##      sürüyorsa stop() gelmeden dolarsa bile zarasız outro'ya girer -
##      sadece görsel bir "biraz erken kapandı" hissi verir, oyun durumu
##      etkilenmez), bağ koptuğunda/yetenek bitince player.gd/remote_player.gd
##      DIŞARIDAN stop() çağırır, outro oynayıp kendini siler.
##
## 3 fazlı elle sürülen kare kontrolü - Ice.png'deki (fx_ice_freeze_status.gd)
## AYNI teknik.
##
## DÜZELTME (kullanıcı bildirimi: "kenarlarına smooth eklemeni istemiştim...
## keskin bir şekilde bitiyordu") - texture_filter=1 (Linear, .tscn'de) SADECE
## piksel ÖRNEKLEMESİNİ (scale=3.9 ile büyütülünce oluşan pikselli görünümü)
## yumuşatıyordu, kaynak PNG'deki sert alfa kesimini (parıltıların keskin
## bitmesi) DEĞİŞTİRMİYORDU - o yüzden fark edilmiyordu. assets/generated/
## fx_melek_heal_aura.png/fx_melek_shield_aura.png artık HER KARE kendi
## sınırları içinde ayrı ayrı (kareler arası bulaşma olmadan) hafif bir
## Gaussian blur ile yeniden üretildi (bkz. kenar yumuşatma script'i, tek
## seferlik - kaynak .tres/.tscn hiç değişmedi, sadece piksel verisi).

const FRAME_COUNT := 13
const INTRO_END := 3   ## 0..3 intro (4 kare)
const LOOP_START := 3
const LOOP_END := 9    ## 3..9 loop (7 kare, ileri-geri sekilir)
const OUTRO_START := 9 ## 9..12 outro (4 kare)

const INTRO_TIME := 0.35
const OUTRO_TIME := 0.45
const LOOP_FRAME_TIME := 0.09

## DÜZELTME (kullanıcı isteği geçmişi: 1.0 -> 0.3 -> 0.15 -> "opaklığını %80
## düzeyine sabitle") - sabit, hiç değişmeyen bir opaklık (bkz. _ready() - bir
## kez set edilip intro/loop/outro boyunca hiç dokunulmuyor, "sabit" zaten
## böyle çalışıyordu, sadece hedef değer değişti).
## DÜZELTME (kullanıcı bildirimi: "görünürlüğünü arttır çok saydam nerdeyse
## hiç görünmüyor") - %80 hâlâ çok soluk bulundu, tam opak (%100) yapıldı.
## Kaynak PNG'lerin (fx_melek_heal_aura.png/fx_melek_shield_aura.png) alfa
## kanalı da AYRICA "shift edge" (kenarları dilate edip SONRA blur uygulama -
## sadece blur, alanı küçültüp söndürür) tekniğiyle hem daha yumuşak hem daha
## belirgin hale getirildi (tek seferlik, kaynak .tres/.tscn değişmedi).
const AURA_OPACITY := 1.0

## DÜZELTME (kullanıcı isteği: "karakterin ayaklarından başlaması gerekiyor
## efektin konumu çok yanlış") - bu sprite dikey uzun bir ışık/parıltı sütunu
## (16x48 piksel/kare) ve centered=true (varsayılan) olduğu için Vector2.ZERO'
## da (oyuncunun GÖVDE MERKEZİ - bkz. player.tscn Shadow node'unun position=
## (0,55) olması, yani gerçek ayak hizası kökten 55px AŞAĞIDA) simetrik
## çizilince kafanın üstünden ayakların epey altına kadar uzanan dev bir dikey
## şerit gibi görünüyordu. FOOT_LEVEL, aynı player.tscn Shadow referansı -
## _ready() sonunda dokunun (scale dahil) GERÇEK piksel yüksekliğinden bu
## noktaya göre yukarı kaydırılıyor, böylece efekt ayaklardan başlayıp yukarı
## doğru yükseliyor (aşağı taşmıyor).
const FOOT_LEVEL := 55.0

var _duration: float = 6.0
var _elapsed: float = 0.0
var _loop_timer: float = 0.0
var _loop_forward: bool = true
var _loop_frame: int = LOOP_START
var _stopping: bool = false
var _outro_elapsed: float = 0.0


func _ready() -> void:
	animation = "all"
	frame = 0
	modulate.a = AURA_OPACITY
	## bkz. FOOT_LEVEL üstündeki kök neden notu - centered=true sprite'ı
	## kendi (ölçeklenmiş) piksel yüksekliğinin yarısı kadar yukarı kaydırıp
	## alt kenarını tam ayak hizasına oturtuyor.
	position = Vector2.ZERO
	var tex: Texture2D = sprite_frames.get_frame_texture("all", 0) if sprite_frames else null
	if tex:
		var scaled_height: float = tex.get_size().y * scale.y
		position = Vector2(0.0, FOOT_LEVEL - scaled_height * 0.5)


func setup(duration: float) -> void:
	_duration = max(duration, 0.1)


## Müttefik modunda bağ koptuğunda/yetenek bitince dışarıdan çağrılır.
## DÜZELTME: "stop" ismi AnimatedSprite2D'nin kendi yerleşik stop() metoduyla
## çakışıp motor uyarısı/hatasına yol açtığı için stop_aura olarak adlandırıldı.
func stop_aura() -> void:
	if _stopping:
		return
	_stopping = true
	_outro_elapsed = 0.0


func _process(delta: float) -> void:
	_elapsed += delta

	if _elapsed <= INTRO_TIME:
		var t: float = _elapsed / INTRO_TIME
		frame = clampi(int(round(t * float(INTRO_END))), 0, INTRO_END)
		return

	if not _stopping and _elapsed >= _duration - OUTRO_TIME:
		_stopping = true
		_outro_elapsed = 0.0

	if _stopping:
		_outro_elapsed += delta
		var ot: float = _outro_elapsed / OUTRO_TIME
		var f: int = OUTRO_START + int(round(clampf(ot, 0.0, 1.0) * float(FRAME_COUNT - 1 - OUTRO_START)))
		frame = clampi(f, OUTRO_START, FRAME_COUNT - 1)
		if ot >= 1.0:
			queue_free()
		return

	## LOOP: intro_end..loop_end arasında ileri-geri sekerek "canlı" bir
	## sürekli parıltı hissi verir.
	_loop_timer -= delta
	if _loop_timer <= 0.0:
		_loop_timer = LOOP_FRAME_TIME
		if _loop_forward:
			_loop_frame += 1
			if _loop_frame >= LOOP_END:
				_loop_frame = LOOP_END
				_loop_forward = false
		else:
			_loop_frame -= 1
			if _loop_frame <= LOOP_START:
				_loop_frame = LOOP_START
				_loop_forward = true
		frame = _loop_frame
