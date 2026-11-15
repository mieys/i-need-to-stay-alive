extends RefCounted

## Sandık sanatı TEK KAYNAK. Kullananlar: chest_drop.gd (dünya), chest_open_anim.gd (ödül ekranı + efsun ekranı girişi),
## chest_pass_fx.gd (sıradakine uçan sandık), gold_reward_fx.gd (altın fışkıran sandık).
##
## 2026-11-11 (madde 557, kullanıcı: "sandıklar, sandık açılışları ve yere düştüğü halleri de dahil, eskilerini silersin"): kullanıcının
## yeni 32x32 çizimleri. İki sandık var - SIRADAN (kahverengi, altın dolu) ve ELİT (mor kristal, gümüş çerçeve); her biri iki durumdan
## oluşan 64x32'lik sayfa: kare 0 = KAPALI (yerdeki hâli, açılmadan önce), kare 1 = AÇIK. Kademe bandı artık sandığın görünüşünü
## DEĞİŞTİRMEZ (tek sıradan sandık var; chest_tier yalnız ödül/başlık için duruyor). Işık sütunu, üretilmiş gölge ve eski paket sayfaları
## silindi. Sayfalar tools/chest_sanat/gen_sandik.py ile çizime dokunmadan dizilir (kapalı kare 3 px aşağı kaydırılır: açık çizimin
## gövde tabanı 31'de, kapalınınki 28'de - sandık açılırken yerinde kalsın).
## Açılış hareketi çizimden DEĞİL koddan: kısa sallanma (kare 0, +-1 px yatay) -> kare 1'e geçiş. Yerdeki sandığın gölgesi sandığın
## kendisinde yok -> diğer yer objeleri gibi standart drop_shadow.gd gölgesi (chest_drop.gd).

const TEXEL := 0.8 ## dünya px / sanat px (ilk sürümden beri aynı)
const FRAME_PX := 32
const FRAME_WU := FRAME_PX * TEXEL
const FRAME_COUNT := 2
const FRAME_CLOSED := 0
const FRAME_OPEN := 1
## Sandığın alt-orta noktası (doku px): iki karede de taban y=31, yatay ortası 16.
const CHEST_ANCHOR_PX := Vector2(16, 31)

const NORMAL_SHEET := preload("res://assets/sprites/chests/sandik_normal.png")
const ELITE_SHEET := preload("res://assets/sprites/chests/sandik_elit.png")


static func sheet(elite: bool) -> Texture2D:
	return ELITE_SHEET if elite else NORMAL_SHEET
