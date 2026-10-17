extends RefCounted

## HARİTANIN DIŞ ÇERÇEVESİ (2026-10-13, CLAUDE.md madde 119): oyun alanı (eski 256x256 hücre, tüm hücre/dünya koordinatları aynı) + dışına eklenen geçilmez
## orman / su çerçevesi (Harita.tmx artık SONSUZ harita; çerçeve negatif ve 256+ hücrelerde). Çerçeve hücrelerinin hepsi `Orman parçaları/Orman parçaları`
## katmanında dolu (saydam karo = görünmez engel + görüş engeli), yani oyuncu/yaratık/doğuş/ışınlanma sorgularının hepsi çerçeveyi duvar olarak görür.
## Kamera sınırı çerçeve DAHİL (GameManager.get_camera_world_rect), diğer tüm "harita sınırı" kullanımları oyun alanı (GameManager.get_map_world_rect).

## Oyun alanı = eski harita (hücre koordinatı, katman yerel).
const PLAY_CELLS := Rect2i(0, 0, 256, 256)
## Çerçeve kalınlığı (hücre): sol/sağ ve üst/alt. Kamera yarı görüşü zoom 2,0'da 480x270 px (30 x 16,9 hücre); oyuncu kenardan 16 px (1 hücre) içeride durur.
const RING_X := 32
const RING_Y := 20
## Yol bulma / görüş ızgarası çerçevenin sadece bu kadar hücresini tutar (derindeki hücrelere hiçbir yaratık ulaşamaz; ızgara boyu/kurulum süresi küçük kalsın).
const PATH_RING_KEEP := 8


## cell oyun alanının PATH_RING_KEEP payı içinde mi (yol bulma ızgarasına girer).
static func in_path_grid(cell: Vector2i) -> bool:
	return PLAY_CELLS.grow(PATH_RING_KEEP).has_point(cell)
