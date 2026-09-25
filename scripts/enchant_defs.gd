class_name EnchantDefs
extends RefCounted

## EFSUN SİSTEMİ - TEK VERİ KAYNAĞI (tasarım belgesi: claude.ai/code/artifact/71096889-a741-4268-8db1-7a097bba9f2d).
## Kart ekranı (enchant_screen.gd), havuz (enchant_pool.gd), silah davranışları (scripts/enchants/*.gd) ve durum
## çözümü (resolve) hep buradan okur - bir efsunun adı/adımı/sayısı TEK yerde değişir (bkz. CLAUDE.md hata sınıfı:
## "iki ayrı yer, biri unutulmuş").
##
## Yapı: her efsun 7 karttan oluşur - adım 0 = Temel, 1..5 = I..V, 6 = Final (katalizör eşya ister).
## Bir adımın "set" alanları kalıcı davranış/sayı olarak YAZILIR (sonraki adım aynı anahtarı ezer). Ortak anahtarları
## (zehir/yanma/kanama/şok/donma/işaret/delme/sekme/yelpaze/seri/hız...) enchant_behavior.gd işler; efsuna özgü
## anahtarları o efsunun scripti. Nadirlik (Tier 1-4) sayıları değil "efsun gücünü" büyütür: Temel ve I-V kartlarının her
## biri CARD_POWER x tier kadar güç ekler; güç "power" alanındaki etkiyi çarpar (power_label = kartta ne yazdığı).
## Aşkın kartları (efsun tamamlanınca) aynı güce ASKIN_POWER x tier ekler - sınırsız.
##
## KART METİNLERİ (kullanıcı geri bildirimi 2026-09-25: "efsun açıklamaları çok belirsiz, bir şey anlaşılmıyor"):
## tam cümle, kısaltma yok ("SG" değil "saldırı gücü"), sayı değişimi "önce -> sonra" (ör. "Zehir tavanı: 20 → 50 yük"),
## her efsunun "desc"i efsunun ne yaptığını tek cümlede anlatır.
## Efsun ekranı nereden gelir: 2026-09-25'ten beri SADECE elit sandıklar (boss garanti, yüksek kademe yaratıklar nadiren,
## görev ödülü) - bkz. enemy.gd _drop_chest / main.gd _show_elite_chest.

const TIER_POWER := [1.0, 1.5, 2.0, 2.5] ## Items.ITEM_TIER_POWER ile aynı
const CARD_POWER := 0.10 ## Temel/I-V kartı başına efsun gücü (Tier 1: +%10, Tier 4: +%25)
const ASKIN_POWER := 0.08 ## Aşkın kartı başına (Tier 1: +%8, Tier 4: +%20)
const GENERAL_REACTION_POWER := 0.03 ## genel Aşkın kartı: Tepkime Gücü
const GENERAL_DAMAGE_PERCENT := 0.02 ## genel Aşkın kartı: hasar
const FINAL_STEP := 6
const STEP_COUNT := 7
const STEP_LABELS := ["Temel", "I / V", "II / V", "III / V", "IV / V", "V / V", "Final"]
const BANISH_PER_RUN := 3

const ELEMENTS := {
	"zehir": {"name": "Zehir", "color": Color("#8fd65a")},
	"yanma": {"name": "Yanma", "color": Color("#ff8a3c")},
	"donma": {"name": "Donma", "color": Color("#8fd0ff")},
	"kanama": {"name": "Kanama", "color": Color("#e0484e")},
	"sok": {"name": "Şok", "color": Color("#ffe35a")},
	"isaret": {"name": "İşaret", "color": Color("#c98cff")},
	"kaos": {"name": "Kaos", "color": Color("#e08cff")},
	"kutsal": {"name": "Kutsal", "color": Color("#fff2b0")},
	"fiziksel": {"name": "Fiziksel", "color": Color("#d9d2c4")},
}

## Silah anahtarı -> o silahın 5 efsunu (kart sırası).
const BY_WEAPON := {
	"dagger": ["hancer_kanli", "hancer_zehir", "hancer_golge", "hancer_firtina", "hancer_sok"],
	"fire_staff": ["ates_kor", "ates_meteor", "ates_sel", "ates_buhar", "ates_anka"],
	"lightning_staff": ["yildirim_zincir", "yildirim_gerilim", "yildirim_firtina", "yildirim_catal", "yildirim_miknatis"],
	"tabanca": ["tabanca_isaret", "tabanca_seri", "tabanca_sekme", "tabanca_ates", "tabanca_duello"],
	"tuftuf": ["tuftuf_zehir", "tuftuf_salgin", "tuftuf_coklu", "tuftuf_uyku", "tuftuf_simsek"],
	"tufek": ["tufek_delici", "tufek_nisanci", "tufek_patlayici", "tufek_buz", "tufek_geritepme"],
	"arcane": ["arcane_kuyruklu", "arcane_sekme", "arcane_kaos", "arcane_mana", "arcane_kara"],
	"yay": ["yay_yagmur", "yay_alev", "yay_ruzgar", "yay_zehir", "yay_cekis"],
	"crossbow": ["crossbow_patlayici", "crossbow_tekrarli", "crossbow_zirh", "crossbow_kanca", "crossbow_sok"],
	"boomerang": ["bumerang_kenar", "bumerang_cift", "bumerang_kasirga", "bumerang_yildirim", "bumerang_alev"],
	"buz_asasi": ["buz_buzul", "buz_mizrak", "buz_firtina", "buz_kristal", "buz_kalp"],
	"fisek": ["fisek_gosteri", "fisek_napalm", "fisek_fitil", "fisek_sersem", "fisek_simsek"],
	"pence": ["pence_vahsi", "pence_hucum", "pence_dortlu", "pence_kan", "pence_buz"],
	"topuz": ["topuz_deprem", "topuz_kutsal", "topuz_ates", "topuz_agir", "topuz_simsek"],
	"uzunkilic": ["kilic_dalga", "kilic_kanli", "kilic_karsi", "kilic_alev", "kilic_ruzgar"],
}

const WEAPON_NAMES := {
	"dagger": "Bıçak", "fire_staff": "Ateş Asası", "lightning_staff": "Yıldırım Asası", "tabanca": "Tabanca",
	"tuftuf": "Tüftüf", "tufek": "Tüfek", "arcane": "Arcane Asası", "yay": "Yay", "crossbow": "Arbalet",
	"boomerang": "Bumerang", "buz_asasi": "Buz Asası", "fisek": "Fişek", "pence": "Pençe", "topuz": "Topuz",
	"uzunkilic": "Uzunkılıç",
}

## Her adım: "text" (kartta görünen), "set" (resolve ile istatistiklere yazılır).
## power: efsun gücünün çarptığı etki - "hit" (silah vuruşu), "poison", "burn", "bleed", "shock", "area" (efsunun kendi
## alan/ek hasarları), "heal", "shield". power_label: kartta "Efsun gücü: %100 → %110 (<power_label> bu oranla çarpılır)".
const DEFS := {
	## ------------------------------------------------------------------ HANÇER
	"hancer_kanli": {
		"weapon": "dagger", "name": "Kanlı Hançer", "element": "kanama", "catalyst": "vampir_disi",
		"power": "bleed", "power_label": "kanama hasarı",
		"desc": "Bıçak kanatır; kanama yükleri üst üste birikip her saniye hasar verir.",
		"steps": [
			{"text": "Her isabet 1 kanama yükü bırakır. Her yük saniyede saldırı gücünün %3'ü kadar hasar verir (en fazla 5 yük).",
				"set": {"bleed_stacks": 1, "bleed_cap": 5, "bleed_ap": 0.03}},
			{"text": "Kanama tavanı: 5 → 10 yük.", "set": {"bleed_cap": 10}},
			{"text": "İsabet başına kanama yükü: 1 → 2.", "set": {"bleed_stacks": 2}},
			{"text": "Kanayan düşmanlara bıçak %20 fazla vurur.", "set": {"bleeding_bonus": 0.2}},
			{"text": "Kanama iki kat hızlı işler (saniyede 2 kez hasar verir).", "set": {"bleed_fast": true}},
			{"text": "Kanayan düşman ölünce kanama yükleri en yakın düşmana geçer.", "set": {"bleed_transfer": true}},
			{"text": "KAN ŞELALESİ: kanama tavanı kalkar. Hedefteki yük sayısı her 10'a ulaştığında hedef patlar (60 px, saldırı gücünün %50'si) ve patlama hasarının %5'i kadar can kazanırsın.",
				"set": {"bleed_cap": 1000000, "bleed_burst": true}},
		],
	},
	"hancer_zehir": {
		"weapon": "dagger", "name": "Zehirli Hançer", "element": "zehir", "catalyst": "keskin_uclar",
		"power": "poison", "power_label": "zehir hasarı",
		"desc": "Bıçak zehirler; zehir yükleri birikip her saniye hasar verir.",
		"steps": [
			{"text": "Ana hedefe her vuruş 1 zehir yükü bırakır. Her yük 10 sn boyunca saniyede saldırı gücünün %2'si kadar hasar verir (en fazla 15 yük).",
				"set": {"poison_stacks": 1, "poison_cap": 15, "poison_dur": 10.0, "poison_dps": 0.02, "primary_only": true}},
			{"text": "Savuruşun değdiği çevredeki düşmanlar da zehirlenir.", "set": {"primary_only": false}},
			{"text": "Zehir tavanı: 15 → 30 yük.", "set": {"poison_cap": 30}},
			{"text": "Zehir süresi: 10 → 15 sn.", "set": {"poison_dur": 15.0}},
			{"text": "Zehirli düşmanlara kritik vuruş şansın +%15.", "set": {"crit_vs_poisoned": 0.15}},
			{"text": "Bu bıçakla 20 ya da daha fazla zehir yükü bıraktığın düşmana vurunca yerinde 3 sn zehirli duman çıkar (içindekiler zehirlenir).", "set": {"smoke_at": 20}},
			{"text": "ENGEREK DİŞİ: zehir hasarı düşman kalkanını tamamen deler. Zehirli düşman ölünce yerinde 3 sn zehir bulutu bırakır.",
				"set": {"poison_true": true, "death_cloud": true}},
		],
	},
	"hancer_golge": {
		"weapon": "dagger", "name": "Gölge Adımı", "element": "fiziksel", "catalyst": "deri_cizme",
		"power": "area", "power_label": "gölge hançer hasarı",
		"desc": "Belli aralıklarla hedefe doğru uçan gölge hançerler fırlatır.",
		"steps": [
			{"text": "Her 8. saldırında hedefe doğru bir gölge hançer uçar ve yolundaki tüm düşmanlara saldırı gücünün %80'i kadar vurur.",
				"set": {"shadow_every": 8, "shadow_count": 1}},
			{"text": "Gölge sıklığı: her 8. → her 6. saldırı.", "set": {"shadow_every": 6}},
			{"text": "Gölge hançer sayısı: 1 → 2.", "set": {"shadow_count": 2}},
			{"text": "Gölgenin vurduğu düşmanlar 3 İşaret yükü alır (her yük aldıkları tüm hasarı %1 artırır).", "set": {"shadow_mark": 3}},
			{"text": "Hareket ederken saldırı hızın +%15.", "set": {"move_attack_speed": 0.15}},
			{"text": "Gölge sıklığı: her 6. → her 4. saldırı.", "set": {"shadow_every": 4}},
			{"text": "GÖLGE DANSI: gölgeler 3 hançerlik bir yelpaze hâlinde çıkar. Bir saldırıdan sıyrıldığında (kaçındığında) etrafına 8 gölge hançer saçarsın.",
				"set": {"shadow_dance": true}},
		],
	},
	"hancer_firtina": {
		"weapon": "dagger", "name": "Fırtına Bıçakları", "element": "fiziksel", "catalyst": "eldiven",
		"power": "hit", "power_label": "bıçak hasarı",
		"desc": "Bıçak her saldırıda daha çok ve daha hızlı saplar.",
		"steps": [
			{"text": "Her saldırıdaki darbe sayısı: 3 → 4.", "set": {"segments": 4}},
			{"text": "Saldırı hızın +%15.", "set": {"attack_speed": 0.15}},
			{"text": "Aynı düşmana art arda her vuruş %4 daha fazla hasar verir (en fazla +%40, hedef değişince sıfırlanır).",
				"set": {"combo_ramp": 0.04, "combo_cap": 0.4}},
			{"text": "Darbe sayısı: 4 → 5.", "set": {"segments": 5}},
			{"text": "Bıçağın menzili +%20.", "set": {"range_mult": 1.2}},
			{"text": "Saldırı hızı: +%15 → +%30.", "set": {"attack_speed": 0.3}},
			{"text": "BİN KESİK: darbe sayısı 8 olur. Eldiven'in isabet başına düz hasar bonusu her darbeye ayrı ayrı eklenir.",
				"set": {"segments": 8, "flat_per_segment": true}},
		],
	},
	"hancer_sok": {
		"weapon": "dagger", "name": "Şok Bıçağı", "element": "sok", "catalyst": "yetenek_kitabi",
		"power": "shock", "power_label": "şok sıçraması",
		"desc": "Bıçak şoklar: şoklu düşmana gelen her vuruşun bir kısmı yakındaki düşmana da vurur.",
		"steps": [
			{"text": "Her 3. isabet hedefi 4 sn şoklar. Şoklu düşmana gelen her vuruşun %25'i en yakın düşmana da vurur.",
				"set": {"shock_every": 3, "shock_dur": 4.0, "shock_jump": 0.25, "shock_jumps": 1}},
			{"text": "Sıçrayan hasar: %25 → %35.", "set": {"shock_jump": 0.35}},
			{"text": "Şoklama: her 3. → her 2. isabet.", "set": {"shock_every": 2}},
			{"text": "Şoklu düşmanlara bıçak %15 fazla vurur.", "set": {"shocked_bonus": 0.15}},
			{"text": "Şok 1 yerine 2 düşmana sıçrar.", "set": {"shock_jumps": 2}},
			{"text": "Şoklu düşman ölünce üstüne yıldırım düşer (60 px, saldırı gücünün %50'si).", "set": {"shock_death_bolt": true}},
			{"text": "STATİK FIRTINA: her isabet şoklar. Bir yetenek kullandığında ekrandaki tüm şoklu düşmanlara yıldırım düşer (saldırı gücünün %100'ü).",
				"set": {"shock_every": 1, "static_storm": true}},
		],
	},
	## ------------------------------------------------------------------ ATEŞ ASASI
	"ates_kor": {
		"weapon": "fire_staff", "name": "Kor Asa", "element": "yanma", "catalyst": "sigara",
		"power": "burn", "power_label": "yanma hasarı",
		"desc": "Ateş topunun patlaması düşmanları tutuşturur.",
		"steps": [
			{"text": "Ateş topunun patlaması vurduğu düşmanları 3 sn yakar (saniyede saldırı gücünün %10'u).",
				"set": {"burn_ap": 0.10, "burn_dur": 3.0}},
			{"text": "Yanma süresi: 3 → 5 sn.", "set": {"burn_dur": 5.0}},
			{"text": "Yanan düşman ölünce ateş 60 px'teki düşmanlara sıçrar.", "set": {"burn_spread": true}},
			{"text": "Yanan düşmanlara patlama %25 fazla vurur.", "set": {"burning_bonus": 0.25}},
			{"text": "Yanma hasarı: saniyede %10 → %15 saldırı gücü.", "set": {"burn_ap": 0.15}},
			{"text": "Yanma 3 kez üst üste birikebilir (her birikim hasarı katlar).", "set": {"burn_stacks": 3}},
			{"text": "CEHENNEM TOHUMU: yanan düşman ölünce yerinde patlar (80 px, saldırı gücünün %60'ı). Sigara'nın hasar bonusu yanmaya iki kat işler.",
				"set": {"burn_death_blast": true}},
		],
	},
	"ates_meteor": {
		"weapon": "fire_staff", "name": "Meteor Asası", "element": "yanma", "catalyst": "kaos_kitabi",
		"power": "area", "power_label": "meteor hasarı",
		"desc": "Belli atışlarda hedefin üstüne gökten meteor düşürür.",
		"steps": [
			{"text": "Her 5. atışında hedefin üstüne ayrıca bir meteor düşer: 1 sn uyarı halkası, sonra 110 px alanda saldırı gücünün %200'ü kadar hasar.",
				"set": {"meteor_every": 5}},
			{"text": "Meteor sıklığı: her 5. → her 4. atış.", "set": {"meteor_every": 4}},
			{"text": "Meteor alanı +%25.", "set": {"meteor_radius": 1.25}},
			{"text": "Meteor düştüğü yeri 3 sn yakar.", "set": {"meteor_lava": true}},
			{"text": "Meteor sayısı: 1 → 2 (ikincisi yakındaki başka bir düşmana).", "set": {"meteor_count": 2}},
			{"text": "Meteor vurduğu düşmanları 0,5 sn sersemletir (bosslar hariç).", "set": {"meteor_stun": 0.5}},
			{"text": "KIYAMET YAĞMURU: her 10 sn'de menzilindeki düşmanlara 6 meteor yağar. Kaos Kitabı'nın çift atış şansı bu yağmuru ikiye katlayabilir.",
				"set": {"meteor_rain": true}},
		],
	},
	"ates_sel": {
		"weapon": "fire_staff", "name": "Alev Seli", "element": "yanma", "catalyst": "steroid",
		"power": "hit", "power_label": "ateş topu hasarı",
		"desc": "Asa aynı anda birden fazla ateş topu fırlatır.",
		"steps": [
			{"text": "Her atışta yanına ikinci bir ateş topu atar (%50 hasarla).", "set": {"multi_count": 2, "multi_dmg": 0.5, "fan_deg": 10.0}},
			{"text": "Ateş topu sayısı: 2 → 3 (yelpaze).", "set": {"multi_count": 3}},
			{"text": "Ateş topları 1 düşmanı delip geçer ve her deldiğinde patlar.", "set": {"pierce": 1, "pierce_pct": 1.0}},
			{"text": "Patlama alanı +%30.", "set": {"aoe_mult": 1.3}},
			{"text": "Ateş topları %40 daha hızlı; ek topların hasarı: %50 → %70.", "set": {"proj_speed": 1.4, "multi_dmg": 0.7}},
			{"text": "Ateş topu sayısı: 3 → 5.", "set": {"multi_count": 5}},
			{"text": "EJDER NEFESİ: her 6 sn'de önüne 1,5 sn süren bir alev konisi püskürtür (saniyede 6 kez; saldırı gücünün %40'ı + maksimum canının %2'si).",
				"set": {"dragon": true}},
		],
	},
	"ates_buhar": {
		"weapon": "fire_staff", "name": "Buhar Ustası", "element": "yanma", "catalyst": "kitelama_seti",
		"power": "area", "power_label": "Buhar Patlaması hasarı",
		"desc": "Ateşle buzu birleştirerek Buhar Patlaması tepkimesi yaratır.",
		"steps": [
			{"text": "Her 4. atış buz-ateş mermisi olur: vurduğu düşmanı önce dondurur, sonra yakar ve Buhar Patlaması tepkimesini tetikler (80 px, saldırı gücünün %60'ı; bosslar donmadığı için onlarda olmaz).",
				"set": {"steam_every": 4}},
			{"text": "Bu asanın tetiklediği tüm tepkimeler %20 daha güçlü.", "set": {"reaction_power": 0.2}},
			{"text": "Buz-ateş mermisi: her 4. → her 3. atış.", "set": {"steam_every": 3}},
			{"text": "Buhar Patlaması alanı +%30.", "set": {"steam_radius": 1.3}},
			{"text": "Buhar Patlaması %50 yavaşlatır (önce %30).", "set": {"steam_slow": 0.5}},
			{"text": "Buhar Patlaması alanındaki düşmanları 3 sn yakar.", "set": {"steam_burn": true}},
			{"text": "KAYNAYAN SİS: Buhar Patlaması 4 sn duran bir sis bırakır; içindekiler %40 yavaşlar ve saniyede saldırı gücünün %30'u kadar hasar alır.",
				"set": {"steam_fog": true}},
		],
	},
	"ates_anka": {
		"weapon": "fire_staff", "name": "Anka Kuşu", "element": "yanma", "catalyst": "vitamin",
		"power": "area", "power_label": "kuş hasarı",
		"desc": "Öldürdükçe etrafında dönen ateşten bir kuş çağırır.",
		"steps": [
			{"text": "Her 20 öldürmende 6 sn boyunca etrafında dönen bir ateş kuşu belirir; değdiği düşmanları yakar.", "set": {"bird_kills": 20, "bird_dur": 6.0}},
			{"text": "Kuş için gereken öldürme: 20 → 15.", "set": {"bird_kills": 15}},
			{"text": "Kuş süresi: 6 → 10 sn.", "set": {"bird_dur": 10.0}},
			{"text": "Her seferinde 2 kuş çıkar.", "set": {"bird_count": 2}},
			{"text": "Kuş değdiği düşmana ayrıca saldırı gücünün %60'ı kadar vurur.", "set": {"bird_dmg": 0.6}},
			{"text": "Kuş kaybolurken patlar (120 px, saldırı gücünün %150'si).", "set": {"bird_blast": true}},
			{"text": "KÜLLERİNDEN DOĞUŞ: kuşların kalıcı olur. Ölümcül bir darbe aldığında bir kez %50 canla kalkarsın ve çevrende büyük bir patlama olur (180 sn'de bir).",
				"set": {"phoenix_rebirth": true}},
		],
	},
	## ------------------------------------------------------------------ YILDIRIM ASASI
	"yildirim_zincir": {
		"weapon": "lightning_staff", "name": "Zincir Yıldırım", "element": "sok", "catalyst": "yetenek_kitabi",
		"power": "hit", "power_label": "ışın ve sıçrama hasarı",
		"desc": "Işın daha çok düşmana sıçrar ve sıçradıklarını şoklar.",
		"steps": [
			{"text": "Işın 1 düşmana daha sıçrar (toplam 2 düşmana sıçrar). Sıçradığı düşmanlar 4 sn şoklanır (şoklu düşmana gelen vuruşun %25'i yakınına sıçrar).", "set": {"chain_add": 1, "chain_shock": true}},
			{"text": "Sıçrama hasarı: %50 → %65.", "set": {"chain_pct": 0.65}},
			{"text": "Sıçrama: +1 (toplam 3 düşman).", "set": {"chain_add": 2}},
			{"text": "Sıçrama menzili +%30.", "set": {"chain_range": 1.3}},
			{"text": "Sıçrama: +1 (toplam 4 düşman).", "set": {"chain_add": 3}},
			{"text": "Her sıçramanın %10 ihtimalle ana hedefe geri dönüp bir kez daha vurma şansı var.", "set": {"chain_return": 0.1}},
			{"text": "GÖK KUBBE: sıçrama sayısı iki katına çıkar (8). Zincirin son halkasına saniyede bir dev yıldırım düşer (saldırı gücünün %150'si).",
				"set": {"chain_add": 7, "chain_bolt": true}},
		],
	},
	"yildirim_gerilim": {
		"weapon": "lightning_staff", "name": "Aşırı Gerilim", "element": "sok", "catalyst": "kalkan_yuzugu",
		"power": "hit", "power_label": "ışın hasarı",
		"desc": "Işın aynı düşmanda kaldıkça güçlenir.",
		"steps": [
			{"text": "Işın aynı düşmanda kaldıkça hasarı saniyede %10 artar (en fazla +%60). Hedef değişince sıfırlanır.", "set": {"ramp_rate": 0.10, "ramp_cap": 0.6}},
			{"text": "Birikim tavanı: +%60 → +%100.", "set": {"ramp_cap": 1.0}},
			{"text": "Birikim hızı: saniyede %10 → %15.", "set": {"ramp_rate": 0.15}},
			{"text": "Tavana ulaşınca hedef 0,5 sn sersemler (bosslar hariç).", "set": {"ramp_stun": true}},
			{"text": "Hedef değişince birikimin yarısı korunur.", "set": {"ramp_keep": 0.5}},
			{"text": "Tavandayken ışın düşman kalkanının %30'unu deler.", "set": {"ramp_pen": 0.3}},
			{"text": "TESLA BOBİNİ: tavandayken kalkanın saniyede %2 dolar. Kalkanın doluyken ışın %30 fazla vurur.", "set": {"tesla": true}},
		],
	},
	"yildirim_firtina": {
		"weapon": "lightning_staff", "name": "Fırtına Asası", "element": "sok", "catalyst": "kaos_kitabi",
		"power": "area", "power_label": "yıldırım hasarı",
		"desc": "Işının hedefine düzenli olarak gökten yıldırım düşer.",
		"steps": [
			{"text": "Her 4 sn'de ışının hedefine gökten yıldırım düşer (70 px, saldırı gücünün %120'si).", "set": {"storm_cd": 4.0}},
			{"text": "Yıldırım sıklığı: 4 → 3 sn.", "set": {"storm_cd": 3.0}},
			{"text": "Yıldırımın vurduğu düşmanlar 4 sn şoklanır (şoklu düşmana gelen vuruşun %25'i yakınına sıçrar).", "set": {"storm_shock": true}},
			{"text": "Yıldırım sayısı: 1 → 2 (ikincisi yakındaki rastgele bir düşmana).", "set": {"storm_count": 2}},
			{"text": "Yıldırım alanı +%30.", "set": {"storm_radius": 1.3}},
			{"text": "Yıldırım düştüğü yerde 2 sn elektrik alanı bırakır (içindekiler saniyede saldırı gücünün %30'u kadar hasar alır).", "set": {"storm_field": true}},
			{"text": "BİTMEYEN FIRTINA: her saniye yıldırım düşer. Kaos Kitabı'nın çift atış şansıyla üç yıldırım birden düşebilir.",
				"set": {"storm_cd": 1.0, "storm_chaos": true}},
		],
	},
	"yildirim_catal": {
		"weapon": "lightning_staff", "name": "Çatal Işın", "element": "sok", "catalyst": "eldiven",
		"power": "hit", "power_label": "ek ışın hasarı",
		"desc": "Asa aynı anda birden fazla düşmana ışın bağlar.",
		"steps": [
			{"text": "Işın ayrıca en yakın 1 düşmana daha bağlanır (%50 hasar).", "set": {"forks": 1, "fork_pct": 0.5}},
			{"text": "Ek ışın hasarı: %50 → %70.", "set": {"fork_pct": 0.7}},
			{"text": "Ek ışın: 1 → 2 düşman.", "set": {"forks": 2}},
			{"text": "Asanın menzili +%20.", "set": {"range_mult": 1.2}},
			{"text": "Ek ışınların bağlandığı düşmanlar %20 yavaşlar.", "set": {"fork_slow": 0.2}},
			{"text": "Ek ışın: 2 → 3 düşman.", "set": {"forks": 3}},
			{"text": "ÖRÜMCEK AĞI: ışınla bağlı düşmanların arasındaki hatlar da yakınlarındaki düşmanlara vurur. Işın %30 daha sık hasar verir.",
				"set": {"web": true, "attack_speed": 0.3}},
		],
	},
	"yildirim_miknatis": {
		"weapon": "lightning_staff", "name": "Mıknatıs Asa", "element": "sok", "catalyst": "hasat_cantasi",
		"power": "area", "power_label": "patlama hasarı",
		"desc": "Işının hedefi çevresindeki düşmanları kendine çeker.",
		"steps": [
			{"text": "Işının hedefinin 80 px çevresindeki düşmanlar hedefe doğru çekilir.", "set": {"pull_radius": 80.0}},
			{"text": "Çekim alanı: 80 → 120 px.", "set": {"pull_radius": 120.0}},
			{"text": "Çekilen düşmanlar %20 yavaşlar.", "set": {"pull_slow": 0.2}},
			{"text": "Çekim gücü +%50.", "set": {"pull_force": 1.5}},
			{"text": "Hedefin yakınında toplanan her 3 düşman ışın hasarını %10 artırır.", "set": {"pull_bonus": true}},
			{"text": "Her 5 sn'de çekim merkezi patlar (100 px, saldırı gücünün %80'i).", "set": {"pull_blast": true}},
			{"text": "KARA DELİK: her 8 sn'de ışının hedefinde 3 sn'lik bir kara delik açılır: 200 px'teki düşmanları çeker, saniyede saldırı gücünün %50'si kadar vurur, sonunda patlar. Yakındaki tecrübe kürelerini de sana çeker.",
				"set": {"black_hole": true}},
		],
	},
	## ------------------------------------------------------------------ TABANCA
	"tabanca_isaret": {
		"weapon": "tabanca", "name": "Avcı İşareti", "element": "isaret", "catalyst": "keskin_uclar",
		"power": "hit", "power_label": "tabanca hasarı",
		"desc": "Tabanca düşmanları işaretler; işaretli düşman herkesten fazla hasar alır.",
		"steps": [
			{"text": "Her isabet 2 İşaret yükü bırakır (en fazla 20). Her yük düşmanın herkesten aldığı hasarı %1 artırır.", "set": {"mark_stacks": 2, "mark_cap": 20}},
			{"text": "İşaret tavanı: 20 → 40.", "set": {"mark_cap": 40}},
			{"text": "İşaretler 20 yerine 60 sn kalır.", "set": {"mark_dur": 60.0}},
			{"text": "Bu tabancayla 20+ işaret bıraktığın düşmana her zaman kritik vurursun.", "set": {"mark_crit": 20}},
			{"text": "İşaret yükü başına hasar artışı: %1 → %1,5.", "set": {"mark_pct": 0.015}},
			{"text": "İşaretli düşman ölünce işaretlerinin yarısı en yakın düşmana geçer.", "set": {"mark_transfer": true}},
			{"text": "ÖLÜM FERMANI: işaret tavanı 50. 50 işaretli bir düşmanın canı %15'in altına inince anında ölür (bosslar bunun yerine bir kez saldırı gücünün %200'ü kadar hasar alır).",
				"set": {"decree": true, "mark_cap": 50}},
		],
	},
	"tabanca_seri": {
		"weapon": "tabanca", "name": "Seri Ateş", "element": "fiziksel", "catalyst": "eldiven",
		"power": "hit", "power_label": "tabanca hasarı",
		"desc": "Belli aralıklarla hızlı bir seri atış yapar.",
		"steps": [
			{"text": "Her 6 atıştan sonra 3 hızlı ek atış yapar.", "set": {"volley_every": 6, "volley_count": 3, "volley_delay": 0.08}},
			{"text": "Seri: 3 → 4 ek atış.", "set": {"volley_count": 4}},
			{"text": "Saldırı hızın +%15.", "set": {"attack_speed": 0.15}},
			{"text": "Seri mermileri %30 daha büyük.", "set": {"volley_scale": 1.3}},
			{"text": "Seri sıklığı: her 6 → her 5 atış.", "set": {"volley_every": 5}},
			{"text": "Seri sırasında 2 sn boyunca %20 daha hızlı koşarsın.", "set": {"volley_speed": 0.2}},
			{"text": "ALTIPATLAR FIRTINASI: seri 6 mermilik bir yelpaze olur. Her seriden sonra 2 sn boyunca saldırı hızın +%50.",
				"set": {"volley_fan": true, "volley_count": 6, "frenzy": 0.5}},
		],
	},
	"tabanca_sekme": {
		"weapon": "tabanca", "name": "Sekme Mermisi", "element": "fiziksel", "catalyst": "sansli_zar",
		"power": "hit", "power_label": "tabanca hasarı",
		"desc": "Mermi vurduktan sonra yakındaki düşmanlara seker.",
		"steps": [
			{"text": "Mermi vurduktan sonra 1 kez yakındaki bir düşmana seker (%70 hasarla).", "set": {"bounce": 1, "bounce_pct": 0.7}},
			{"text": "Sekme: 1 → 2.", "set": {"bounce": 2}},
			{"text": "Sekme hasarı: %70 → %85.", "set": {"bounce_pct": 0.85}},
			{"text": "Sekme: 2 → 3.", "set": {"bounce": 3}},
			{"text": "Sekme menzili +%50.", "set": {"bounce_range": 1.5}},
			{"text": "Her sekme merminin kritik vurma şansını %15 artırır.", "set": {"bounce_crit": 0.15}},
			{"text": "BİLARDO: sekme sınırsız. Her sekmede mermi %10 ihtimalle ikiye bölünür (şansın bu ihtimali artırır).",
				"set": {"bounce": 99, "bounce_split": 0.1}},
		],
	},
	"tabanca_ates": {
		"weapon": "tabanca", "name": "Ateşli Mermi", "element": "yanma", "catalyst": "sigara",
		"power": "burn", "power_label": "yanma ve patlama hasarı",
		"desc": "Mermiler yakar ve yanan düşmanlarda küçük patlamalar çıkarır.",
		"steps": [
			{"text": "Mermiler vurduğu düşmanı 3 sn yakar (saniyede saldırı gücünün %10'u).", "set": {"burn_ap": 0.10, "burn_dur": 3.0}},
			{"text": "Yanma hasarı: saniyede %10 → %15 saldırı gücü.", "set": {"burn_ap": 0.15}},
			{"text": "Yanan düşmana isabet 40 px küçük bir patlama yapar (saldırı gücünün %30'u).", "set": {"burn_pop": 40.0}},
			{"text": "Yanma süresi: 3 → 5 sn.", "set": {"burn_dur": 5.0}},
			{"text": "Patlama alanı: 40 → 60 px.", "set": {"burn_pop": 60.0}},
			{"text": "Yanan düşmanlara kritik hasarın +%30.", "set": {"crit_damage_vs_burning": 0.3}},
			{"text": "BARUT FIÇISI: her 10. mermi 150 px'lik dev bir patlama yapar (saldırı gücünün %250'si), düşmanları yakar ve geri iter.",
				"set": {"keg_every": 10}},
		],
	},
	"tabanca_duello": {
		"weapon": "tabanca", "name": "Düello", "element": "fiziksel", "catalyst": "hasat_cantasi",
		"power": "hit", "power_label": "tabanca hasarı",
		"desc": "Tabanca menzilindeki en güçlü düşmana kilitlenir.",
		"steps": [
			{"text": "Menzilindeki en yüksek canlı düşmanı hedef alır ve ona %20 fazla vurur.", "set": {"duel": true, "duel_bonus": 0.2}},
			{"text": "Bosslara +%30 hasar.", "set": {"boss_bonus": 0.3}},
			{"text": "Aynı düşmana her 5. isabet onu 1 sn sersemletir (bosslar hariç).", "set": {"duel_stun": 5}},
			{"text": "Hedef bonusu: %20 → %35.", "set": {"duel_bonus": 0.35}},
			{"text": "Hedefin ölünce sonraki 3 atışın kesin kritik vurur.", "set": {"duel_kill_crit": 3}},
			{"text": "Düşman kalkanının %25'ini delersin.", "set": {"shield_pen": 0.25}},
			{"text": "KELLE AVCISI: öldürdüğün her boss, tabancanın hasarını kalıcı olarak %3 artırır (sınırsız).", "set": {"headhunter": true}},
		],
	},
	## ------------------------------------------------------------------ TÜFTÜF
	"tuftuf_zehir": {
		"weapon": "tuftuf", "name": "Zehirli Tüftüf", "element": "zehir", "catalyst": "vitamin",
		"power": "poison", "power_label": "zehir hasarı",
		"desc": "Dartlar zehirler; zehir yükleri üst üste birikip her saniye hasar verir.",
		"steps": [
			{"text": "Her dart 1 zehir yükü bırakır. Her yük 10 sn boyunca saniyede saldırı gücünün %2'si kadar hasar verir (en fazla 20 yük).",
				"set": {"poison_stacks": 1, "poison_cap": 20, "poison_dur": 10.0, "poison_dps": 0.02}},
			{"text": "Zehir tavanı: 20 → 50 yük.", "set": {"poison_cap": 50}},
			{"text": "Zehir süresi: 10 → 20 sn.", "set": {"poison_dur": 20.0}},
			{"text": "Yük başına hasar: saniyede %2 → %3 saldırı gücü.", "set": {"poison_dps": 0.03}},
			{"text": "Dart başına zehir yükü: 1 → 2.", "set": {"poison_stacks": 2}},
			{"text": "Zehir tavanı: 50 → 100 yük. Tüftüf önce canı yüksek, sonra zehirsiz düşmanları hedefler.", "set": {"poison_cap": 100, "poison_priority": true}},
			{"text": "SONSUZ ZEHİR: zehir tavanı kalkar, yükler sınırsız birikir. Yakınındaki her zehirli düşman için saniyede 0,1 can yenilersin (en fazla 5).",
				"set": {"poison_cap": 1000000, "poison_regen": 0.1}},
		],
	},
	"tuftuf_salgin": {
		"weapon": "tuftuf", "name": "Salgın", "element": "zehir", "catalyst": "hasat_cantasi",
		"power": "poison", "power_label": "zehir hasarı",
		"desc": "Zehir ölen düşmandan yakındakilere bulaşır; salgın gibi yayılır.",
		"steps": [
			{"text": "Her dart 1 zehir yükü bırakır (en fazla 10). Zehirli düşman ölünce yüklerinin yarısı 80 px'teki düşmanlara bulaşır.",
				"set": {"poison_stacks": 1, "poison_cap": 10, "poison_dur": 10.0, "poison_dps": 0.02, "plague_radius": 80.0, "plague_ratio": 0.5}},
			{"text": "Bulaşma alanı: 80 → 120 px.", "set": {"plague_radius": 120.0}},
			{"text": "Bulaşan yük oranı: %50 → %75.", "set": {"plague_ratio": 0.75}},
			{"text": "Dart 1 düşmanı delip geçer.", "set": {"pierce": 1, "pierce_pct": 0.6}},
			{"text": "10+ yükü olan düşman 2 sn'de bir en yakınına 1 zehir yükü bulaştırır.", "set": {"plague_cough": true}},
			{"text": "Bulaşan yükler tam süreyle başlar (yarıda kalmaz).", "set": {"plague_refresh": true}},
			{"text": "VEBA DALGASI: zehirli her ölüm sana 3 sn %10 hareket hızı verir. Her 20 zehirli ölümde ekrandaki tüm zehirli düşmanlara 5 yük daha eklenir.",
				"set": {"plague_final": true}},
		],
	},
	"tuftuf_coklu": {
		"weapon": "tuftuf", "name": "Çoklu Üfleme", "element": "fiziksel", "catalyst": "kaos_kitabi",
		"power": "hit", "power_label": "dart hasarı",
		"desc": "Tüftüf aynı anda birden fazla dart üfler.",
		"steps": [
			{"text": "Her atışta 2 dart yelpaze hâlinde atılır.", "set": {"multi_count": 2}},
			{"text": "Dart hızı +%30.", "set": {"proj_speed": 1.3}},
			{"text": "Dart sayısı: 2 → 3.", "set": {"multi_count": 3}},
			{"text": "Dartlar isabetten sonra 1 kez yakındaki başka bir düşmana seker.", "set": {"bounce": 1, "bounce_pct": 0.7}},
			{"text": "Dart sayısı: 3 → 4.", "set": {"multi_count": 4}},
			{"text": "Saldırı hızın +%20.", "set": {"attack_speed": 0.20}},
			{"text": "DİKEN YAĞMURU: her 3. saldırında etrafına 8 dartlık bir halka atarsın. Kaos Kitabı'nın çift atış şansı bunu da ikiye katlar.",
				"set": {"ring_every": 3, "ring_count": 8}},
		],
	},
	"tuftuf_uyku": {
		"weapon": "tuftuf", "name": "Uyku Okları", "element": "fiziksel", "catalyst": "kitelama_seti",
		"power": "hit", "power_label": "dart hasarı",
		"desc": "Belli dartlar düşmanı uyutur; uyuyan düşman savunmasızdır.",
		"steps": [
			{"text": "Her 4. dart vurduğu düşmanı 1,5 sn uyutur (hasar alınca uyanır, bosslar uyumaz).", "set": {"sleep_every": 4, "sleep_dur": 1.5, "sleep_break": true}},
			{"text": "Uyku süresi: 1,5 → 2 sn.", "set": {"sleep_dur": 2.0}},
			{"text": "Uyutma: her 4. → her 3. dart.", "set": {"sleep_every": 3}},
			{"text": "Uyuyan düşmana ilk vuruş %50 fazla hasar verir.", "set": {"sleep_bonus": 0.5}},
			{"text": "Uyku, vurulan düşmanın 50 px çevresindekilere de yayılır.", "set": {"sleep_radius": 50.0}},
			{"text": "Uyanan düşman 3 sn %30 yavaş kalır.", "set": {"sleep_wake_slow": 0.3}},
			{"text": "DERİN UYKU: uyku 3 sn sürer ve hasarla bozulmaz. Uyuyan düşman tüm oyunculardan %40 fazla hasar alır.",
				"set": {"sleep_dur": 3.0, "sleep_break": false, "sleep_vuln": 0.4}},
		],
	},
	"tuftuf_simsek": {
		"weapon": "tuftuf", "name": "Şimşek Dikeni", "element": "sok", "catalyst": "yetenek_kitabi",
		"power": "shock", "power_label": "şok ve kovan hasarı",
		"desc": "Dartlar şoklar: şoklu düşmana gelen vuruşların bir kısmı yakındakilere de vurur.",
		"steps": [
			{"text": "Dart vurduğu düşmanı 4 sn şoklar. Şoklu düşmana gelen her vuruşun %25'i en yakın düşmana da vurur.",
				"set": {"shock_dur": 4.0, "shock_jump": 0.25, "shock_jumps": 1}},
			{"text": "Şoklu düşmanlara dart %20 fazla vurur.", "set": {"shocked_bonus": 0.2}},
			{"text": "Sıçrayan hasar: %25 → %40.", "set": {"shock_jump": 0.4}},
			{"text": "Şok süresi: 4 → 6 sn.", "set": {"shock_dur": 6.0}},
			{"text": "Şok 1 yerine 2 düşmana sıçrar.", "set": {"shock_jumps": 2}},
			{"text": "Şoklu düşman saniyede bir yakınındaki bir düşmana kıvılcım atar (saldırı gücünün %20'si).", "set": {"shock_spark": 0.2}},
			{"text": "FIRTINA KOVANI: dart vurduğu yere 4 sn sonra patlayan bir elektrik kovanı bırakır (120 px, saldırı gücünün %120'si, şoklar). Bir yetenek kullandığında tüm kovanlar hemen patlar.",
				"set": {"hive": true}},
		],
	},
	## ------------------------------------------------------------------ TÜFEK
	"tufek_delici": {
		"weapon": "tufek", "name": "Delici Mermi", "element": "fiziksel", "catalyst": "keskin_uclar",
		"power": "hit", "power_label": "tüfek hasarı",
		"desc": "Mermi arkasındaki düşmanları da delip geçer.",
		"steps": [
			{"text": "Mermi 1 düşman daha delip geçer (artık 3 düşmana değer); delinen düşmanlara giden hasar: %30 → %50.", "set": {"pierce": 1, "pierce_pct": 0.5}},
			{"text": "Delme: +1 düşman daha.", "set": {"pierce": 2}},
			{"text": "Delinen düşmanlara giden hasar: %50 → %70.", "set": {"pierce_pct": 0.7}},
			{"text": "Delme: +2 düşman daha.", "set": {"pierce": 4}},
			{"text": "Mermi deldiği her düşmandan sonra %10 daha güçlü vurur.", "set": {"pierce_ramp": 0.10}},
			{"text": "Delme sınırsız.", "set": {"pierce": 99}},
			{"text": "RAYLI TOP: her 5. atış ekranı boydan boya geçen kalın bir ışın olur (saldırı gücünün %300'ü, kalkanları tamamen deler).", "set": {"rail_every": 5}},
		],
	},
	"tufek_nisanci": {
		"weapon": "tufek", "name": "Nişancı", "element": "fiziksel", "catalyst": "sansli_zar",
		"power": "hit", "power_label": "tüfek hasarı",
		"desc": "Uzaktan ve kritik vuruşlarla ölümcül olur.",
		"steps": [
			{"text": "Kritik vuruş şansın +%15.", "set": {"crit_chance": 0.15}},
			{"text": "Kritik hasarın +%40.", "set": {"crit_damage": 0.4}},
			{"text": "Menzilinin %70'inden uzaktaki düşmanlara %30 fazla vurursun.", "set": {"far_bonus": 0.3}},
			{"text": "Kritik şansı: +%15 → +%30.", "set": {"crit_chance": 0.3}},
			{"text": "Kritik vuruşlar 1 sn sersemletir (bosslar hariç).", "set": {"crit_stun": 1.0}},
			{"text": "1 sn kıpırdamadan durunca saldırı hızın +%30.", "set": {"still_speed": 0.3}},
			{"text": "TEK ATIŞ TEK ÖLÜM: kritik vuruşlarının %25'i iki kat daha güçlü olur (süper kritik). Canı %20'nin altındaki normal düşmanlar tek atışta ölür.",
				"set": {"super_crit": 0.25, "execute": 0.2}},
		],
	},
	"tufek_patlayici": {
		"weapon": "tufek", "name": "Patlayıcı Mermi", "element": "yanma", "catalyst": "sigara",
		"power": "area", "power_label": "patlama hasarı",
		"desc": "Mermi ilk vurduğu düşmanda patlayıp çevresini yakar.",
		"steps": [
			{"text": "Mermi ilk vurduğu düşmanda patlar (70 px, saldırı gücünün %60'ı) ve patlamadakileri 3 sn yakar.", "set": {"blast_radius": 70.0, "blast_pct": 0.6}},
			{"text": "Patlama alanı: 70 → 90 px.", "set": {"blast_radius": 90.0}},
			{"text": "Deldiği her düşmanda da küçük bir patlama olur.", "set": {"blast_each": true}},
			{"text": "Yanma hasarı: saniyede %10 → %15 saldırı gücü.", "set": {"blast_burn": 0.15}},
			{"text": "Patlama hasarı: %60 → %90.", "set": {"blast_pct": 0.9}},
			{"text": "Patlama yerinde 3 sn yanan bir alan bırakır.", "set": {"blast_lava": true}},
			{"text": "NAPALM: mermi geçtiği yol boyunca 4 sn yanan bir şerit bırakır.", "set": {"napalm": true}},
		],
	},
	"tufek_buz": {
		"weapon": "tufek", "name": "Buz Mermisi", "element": "donma", "catalyst": "kitelama_seti",
		"power": "hit", "power_label": "tüfek hasarı",
		"desc": "Mermi yavaşlatır; tekrar tekrar vurunca dondurur.",
		"steps": [
			{"text": "Mermi vurduğu düşmanı 2 sn %40 yavaşlatır; aynı düşmana 3. isabette onu 2 sn dondurur.",
				"set": {"slow_pct": 0.4, "slow_dur": 2.0, "freeze_after": 3, "freeze_dur": 2.0, "primary_only": true}},
			{"text": "Donma için gereken isabet: 3 → 2.", "set": {"freeze_after": 2}},
			{"text": "Mermi deldiği düşmanları da yavaşlatır.", "set": {"primary_only": false}},
			{"text": "Donmuş düşmanlara %40 fazla vurursun.", "set": {"frozen_bonus": 0.4}},
			{"text": "Donmuş düşmana isabet buzunu parçalar: ek olarak saldırı gücünün %80'i kadar vurur ve çevreye 3 buz kıymığı saçar.", "set": {"shatter_hit": true}},
			{"text": "Her isabet dondurur.", "set": {"freeze_after": 1}},
			{"text": "MUTLAK SIFIR: mermi yolu boyunca 3 sn duran bir buz koridoru bırakır. İçine giren düşmanlar donar, bosslar %50 yavaşlar.", "set": {"ice_corridor": true}},
		],
	},
	"tufek_geritepme": {
		"weapon": "tufek", "name": "Geri Tepme", "element": "fiziksel", "catalyst": "steroid",
		"power": "hit", "power_label": "tüfek hasarı",
		"desc": "Mermi düşmanları geri iter.",
		"steps": [
			{"text": "Mermi vurduğu düşmanları 60 px geri iter.", "set": {"knockback": 60.0}},
			{"text": "İtme: 60 → 100 px.", "set": {"knockback": 100.0}},
			{"text": "Vurduğun düşmanlar 0,5 sn sersemler (bosslar hariç).", "set": {"stun_on_hit": 0.5}},
			{"text": "Her atıştan sonra 0,5 sn boyunca %20 daha az hasar alırsın.", "set": {"recoil_dr": 0.2}},
			{"text": "İtilen düşman arkasındakilere çarpar (saldırı gücünün %40'ı).", "set": {"push_collide": 0.4}},
			{"text": "İtme: 100 → 140 px.", "set": {"knockback": 140.0}},
			{"text": "TOP GÜLLESİ: her 4. atış dev bir gülle olur: her şeyi deler, düşmanları sürükler ve deldiği her düşmandan sonra %20 daha güçlü vurur.",
				"set": {"cannon_every": 4}},
		],
	},
	## ------------------------------------------------------------------ ARCANE ASASI
	"arcane_kuyruklu": {
		"weapon": "arcane", "name": "Kuyruklu Yıldız", "element": "kaos", "catalyst": "kaos_kitabi",
		"power": "area", "power_label": "iz ve yıldız hasarı",
		"desc": "Büyü hedefini takip eder ve geçtiği yolda hasar veren bir iz bırakır.",
		"steps": [
			{"text": "Mermi hedefini takip eder. Vurduğunda geldiği yol boyunca 1 sn duran bir iz bırakır (içindekiler saniyede saldırı gücünün %20'si kadar hasar alır).",
				"set": {"homing": true, "trail_dur": 1.0}},
			{"text": "İz süresi: 1 → 2 sn.", "set": {"trail_dur": 2.0}},
			{"text": "Mermi %30 daha hızlı.", "set": {"proj_speed": 1.3}},
			{"text": "İz genişliği +%50.", "set": {"trail_width": 1.5}},
			{"text": "İzdeki düşmanlar saniyede 1 İşaret yükü alır (her yük aldıkları hasarı %1 artırır).", "set": {"trail_mark": true}},
			{"text": "Her atışta 2 kuyruklu yıldız fırlatırsın.", "set": {"multi_count": 2, "fan_deg": 14.0}},
			{"text": "YILDIZ YAĞMURU: vurduğun yere gökten bir yıldız düşer ve patlar (130 px, saldırı gücünün %180'i).", "set": {"starfall": true}},
		],
	},
	"arcane_sekme": {
		"weapon": "arcane", "name": "Arcane Sekme", "element": "kaos", "catalyst": "vampir_disi",
		"power": "hit", "power_label": "büyü hasarı",
		"desc": "Büyü düşmandan düşmana seker.",
		"steps": [
			{"text": "Mermi vurduktan sonra 2 kez yakındaki düşmanlara seker (tam hasarla).", "set": {"bounce": 2, "bounce_pct": 1.0}},
			{"text": "Sekme: 2 → 3.", "set": {"bounce": 3}},
			{"text": "Her sekme merminin hasarını %15 artırır.", "set": {"bounce_ramp": 0.15}},
			{"text": "Sekme: 3 → 4.", "set": {"bounce": 4}},
			{"text": "Sekme, yakındaki en yüksek canlı düşmanı seçer.", "set": {"bounce_prefer_hp": true}},
			{"text": "Son sekmeden sonra patlar (80 px, saldırı gücünün %60'ı).", "set": {"bounce_end_blast": true}},
			{"text": "SONSUZ DÖNGÜ: sekme 10 olur. Her sekme sana 1 can kazandırır (saniyede en fazla 5).", "set": {"bounce": 10, "bounce_heal": 1.0}},
		],
	},
	"arcane_kaos": {
		"weapon": "arcane", "name": "Kaos Büyüsü", "element": "kaos", "catalyst": "yetenek_kitabi",
		"power": "area", "power_label": "element etkileri",
		"desc": "Her atış rastgele bir element taşır; element tepkimelerinin motoru.",
		"steps": [
			{"text": "Her atış rastgele bir element taşır: yanma, donma, zehir, kanama ya da şok.", "set": {"chaos": 1}},
			{"text": "Her atış 2 farklı element taşır.", "set": {"chaos": 2}},
			{"text": "Element seçimi, hedefte tepkime çıkaracak olanı tercih eder.", "set": {"chaos_smart": true}},
			{"text": "Bu asanın tetiklediği tepkimeler %30 daha güçlü.", "set": {"reaction_power": 0.3}},
			{"text": "Tetiklediğin her tepkime 10 sn boyunca asanın hasarını %5 artırır (en fazla +%50).", "set": {"chaos_ramp": true}},
			{"text": "Her atış 3 farklı element taşır.", "set": {"chaos": 3}},
			{"text": "ELEMENT FIRTINASI: bir yetenek kullandığında 5 sn boyunca her atış beş elementin hepsini birden taşır.", "set": {"chaos_all": true}},
		],
	},
	"arcane_mana": {
		"weapon": "arcane", "name": "Mana Kalkanı", "element": "kaos", "catalyst": "kalkan_yuzugu",
		"power": "shield", "power_label": "kalkana dönen miktar",
		"desc": "Verdiğin hasarın bir kısmı kalkanına dönüşür.",
		"steps": [
			{"text": "Bu asayla verdiğin hasarın %3'ü kalkanına eklenir.", "set": {"mana_leech": 0.03}},
			{"text": "Kalkana dönen: %3 → %5.", "set": {"mana_leech": 0.05}},
			{"text": "Kalkanın doluyken asa %20 fazla vurur.", "set": {"full_shield_bonus": 0.2}},
			{"text": "Kalkanın kırılınca çevrende arcane patlaması olur (150 px, saldırı gücünün %100'ü; 20 sn'de bir).", "set": {"mana_burst": 20.0}},
			{"text": "Kalkana dönen: %5 → %7.", "set": {"mana_leech": 0.07}},
			{"text": "Patlamanın bekleme süresi: 20 → 12 sn.", "set": {"mana_burst": 12.0}},
			{"text": "ARCANE BARİYER: kalkanın doluyken aldığın hasarın %30'u saldırana geri yansır. Patlama 8 sn'de bir.",
				"set": {"mana_reflect": 0.3, "mana_burst": 8.0}},
		],
	},
	"arcane_kara": {
		"weapon": "arcane", "name": "Kara Büyü", "element": "isaret", "catalyst": "hasat_cantasi",
		"power": "area", "power_label": "lanet patlaması",
		"desc": "Düşmanları lanetler; lanetliler ölünce güç toplarsın.",
		"steps": [
			{"text": "Her isabet 3 İşaret yükü bırakır (en fazla 20; her yük düşmanın aldığı tüm hasarı %1 artırır).", "set": {"mark_stacks": 3, "mark_cap": 20}},
			{"text": "İsabet başına İşaret: 3 → 5.", "set": {"mark_stacks": 5}},
			{"text": "İşaretli düşman ölünce ruhu sana geçer: 10 sn boyunca asanın hasarı %1 artar (10 kez birikir).", "set": {"mark_soul": true, "soul_buff": true}},
			{"text": "İşaret tavanı: 20 → 40.", "set": {"mark_cap": 40}},
			{"text": "İşaret, vurduğun düşmanın yakınındaki 2 düşmana da bulaşır.", "set": {"mark_spread": true}},
			{"text": "İşaretli düşman ölünce patlar (80 px, saldırı gücünün %60'ı).", "set": {"mark_death_blast": true}},
			{"text": "RUH HASADI: topladığın her 50 ruh saldırı gücünü kalıcı olarak 1 artırır (sınırsız).", "set": {"soul_harvest": true}},
		],
	},
	## ------------------------------------------------------------------ YAY
	"yay_yagmur": {
		"weapon": "yay", "name": "Ok Yağmuru", "element": "fiziksel", "catalyst": "eldiven",
		"power": "hit", "power_label": "ok hasarı",
		"desc": "Yay her atışta daha çok ok fırlatır.",
		"steps": [
			{"text": "Yayın 'her 3. atışta +1 ok' özelliği güçlenir: her 3. atışta 2 ek ok atarsın (%80 hasarla).",
				"set": {"volley_every": 3, "volley_count": 2, "volley_dmg": 0.8}},
			{"text": "Ek oklar: her 3. → her 2. atışta.", "set": {"volley_every": 2}},
			{"text": "Ek ok sayısı: 2 → 3.", "set": {"volley_count": 3}},
			{"text": "Ek oklar yelpaze hâlinde açılır (farklı düşmanlara değebilir).", "set": {"volley_fan": true}},
			{"text": "Ek okların hasarı: %80 → %100.", "set": {"volley_dmg": 1.0}},
			{"text": "Her atışta ek ok atarsın.", "set": {"volley_every": 1}},
			{"text": "GÖK DELEN: her 5 sn'de göğe 20 ok atarsın; 2 sn sonra en yakın düşmanın olduğu alana yağarlar (her ok saldırı gücünün %60'ı).", "set": {"rain": true}},
		],
	},
	"yay_alev": {
		"weapon": "yay", "name": "Alevli Ok", "element": "yanma", "catalyst": "vitamin",
		"power": "burn", "power_label": "yanma hasarı",
		"desc": "Oklar alev alır ve düşmanları yakar.",
		"steps": [
			{"text": "Oklar vurduğu düşmanı 3 sn yakar (saniyede saldırı gücünün %10'u).", "set": {"burn_ap": 0.10, "burn_dur": 3.0}},
			{"text": "Yanan düşmanlara oklar %20 fazla vurur.", "set": {"burning_bonus": 0.2}},
			{"text": "Okun vurduğu noktada 40 px alev çıkar (çevredekiler de yanar).", "set": {"flame_splash": 40.0}},
			{"text": "Yanma süresi: 3 → 5 sn.", "set": {"burn_dur": 5.0}},
			{"text": "Alevli ok 1 düşmanı delip geçer.", "set": {"pierce": 1, "pierce_pct": 0.8}},
			{"text": "Yanma 3 kez üst üste birikebilir (her birikim hasarı katlar).", "set": {"burn_stacks": 3}},
			{"text": "ANKA OKU: her 4. ok büyük bir ateş kuşuna dönüşür: yolundaki her şeyi deler ve yakar; yaktığı her düşman için 0,5 can kazanırsın.",
				"set": {"phoenix_every": 4}},
		],
	},
	"yay_ruzgar": {
		"weapon": "yay", "name": "Rüzgâr Oku", "element": "fiziksel", "catalyst": "deri_cizme",
		"power": "hit", "power_label": "ok hasarı",
		"desc": "Oklar hızlanır, uzağa gider ve düşmanları deler.",
		"steps": [
			{"text": "Oklar 2 düşmanı delip geçer.", "set": {"pierce": 2, "pierce_pct": 0.8}},
			{"text": "Ok hızı +%40.", "set": {"proj_speed": 1.4}},
			{"text": "Yayın menzili +%25.", "set": {"range_mult": 1.25}},
			{"text": "Delme: 2 → 4 düşman.", "set": {"pierce": 4}},
			{"text": "Ok deldiği her düşmandan sonra %10 daha güçlü vurur.", "set": {"pierce_ramp": 0.10}},
			{"text": "Her isabet sana 2 sn boyunca %10 hareket hızı verir.", "set": {"hit_speed_buff": 0.10}},
			{"text": "KASIRGA OKU: her 6. ok vurduğu yerden okun yönünde ilerleyen küçük bir kasırga doğurur; kasırga düşmanları sürükler ve keser.",
				"set": {"tornado_every": 6}},
		],
	},
	"yay_zehir": {
		"weapon": "yay", "name": "Zehirli Ok", "element": "zehir", "catalyst": "vampir_disi",
		"power": "poison", "power_label": "zehir hasarı",
		"desc": "Oklar zehirler; zehir yükleri birikip her saniye hasar verir.",
		"steps": [
			{"text": "Her ok 2 zehir yükü bırakır. Her yük 10 sn boyunca saniyede saldırı gücünün %2'si kadar hasar verir (en fazla 20 yük).",
				"set": {"poison_stacks": 2, "poison_cap": 20, "poison_dur": 10.0, "poison_dps": 0.02}},
			{"text": "Zehir tavanı: 20 → 40 yük.", "set": {"poison_cap": 40}},
			{"text": "Zehirli düşmanlara oklar %15 fazla vurur.", "set": {"poisoned_bonus": 0.15}},
			{"text": "Ok başına zehir yükü: 2 → 3.", "set": {"poison_stacks": 3}},
			{"text": "Zehir süresi: 10 → 15 sn.", "set": {"poison_dur": 15.0}},
			{"text": "Zehirli düşman ölünce 100 px'teki düşmanlara 3 zehir yükü bulaşır.", "set": {"poison_death_burst": 3}},
			{"text": "KOBRA OKU: 20+ zehir yükü olan düşmana isabet, tüm yüklerin 3 sn'lik hasarını anında vurur (yükler silinmez); bu hasarın %2'si kadar can kazanırsın.",
				"set": {"kobra": true}},
		],
	},
	"yay_cekis": {
		"weapon": "yay", "name": "Tam Çekiş", "element": "fiziksel", "catalyst": "sansli_zar",
		"power": "hit", "power_label": "ok hasarı",
		"desc": "Kıpırdamadan beklediğinde yay tam gerilir ve çok güçlü bir ok atar.",
		"steps": [
			{"text": "1 sn kıpırdamadan durursan yay tam gerilir (yay ikonu parlar): sıradaki ok 2 kat hasar verir ve 2 düşmanı deler.",
				"set": {"charge_time": 1.0, "charge_mult": 2.0, "charge_pierce": 2}},
			{"text": "Tam gerilme süresi: 1 → 0,8 sn.", "set": {"charge_time": 0.8}},
			{"text": "Tam gerilmiş okun kritik şansı +%30.", "set": {"charge_crit": 0.3}},
			{"text": "Tam gerilmiş ok yolundaki herkesi deler.", "set": {"charge_pierce": 99}},
			{"text": "Hareket ederken de gerilir (yarı hızla).", "set": {"charge_moving": 0.5}},
			{"text": "Tam gerilmiş ok ilk isabette ikiye bölünür.", "set": {"charge_split": 2}},
			{"text": "KARTAL GÖZÜ: tam gerilmiş ok ekranın ötesine kadar uçar; deldiği her düşmandan sonra kritik şansı %10 artar.", "set": {"kartal": true}},
		],
	},
	## ------------------------------------------------------------------ CROSSBOW
	"crossbow_patlayici": {
		"weapon": "crossbow", "name": "Patlayıcı Cıvata", "element": "yanma", "catalyst": "sansli_zar",
		"power": "area", "power_label": "patlama hasarı",
		"desc": "Cıvatalar saplanır ve kısa süre sonra patlar.",
		"steps": [
			{"text": "Cıvata vurduğu yere saplanır ve 1 sn sonra patlar (60 px, saldırı gücünün %60'ı).", "set": {"sticky_delay": 1.0, "sticky_radius": 60.0, "sticky_pct": 0.6}},
			{"text": "Patlama alanı: 60 → 80 px.", "set": {"sticky_radius": 80.0}},
			{"text": "Aynı düşmana kısa sürede 3 cıvata saplanırsa büyük patlama olur (2 kat hasar).", "set": {"sticky_triple": true}},
			{"text": "Patlama hasarı: %60 → %90.", "set": {"sticky_pct": 0.9}},
			{"text": "Patlama yakar.", "set": {"sticky_burn": true}},
			{"text": "Patlama gecikmesi: 1 → 0,5 sn.", "set": {"sticky_delay": 0.5}},
			{"text": "ZİNCİRLEME REAKSİYON: patlamada ölen düşman da patlar. Her zincir patlaması %3 ihtimalle 1 altın kazandırır.", "set": {"chain_explode": true}},
		],
	},
	"crossbow_tekrarli": {
		"weapon": "crossbow", "name": "Tekrarlı Arbalet", "element": "fiziksel", "catalyst": "eldiven",
		"power": "hit", "power_label": "cıvata hasarı",
		"desc": "Daha hızlı ve çift cıvata atar.",
		"steps": [
			{"text": "Saldırı hızın +%20.", "set": {"attack_speed": 0.2}},
			{"text": "Her 4. atışta bir cıvata daha atarsın.", "set": {"volley_every": 4, "volley_count": 1, "volley_delay": 0.1}},
			{"text": "Saldırı hızı: +%20 → +%40.", "set": {"attack_speed": 0.4}},
			{"text": "Çift cıvata: her 4. → her 3. atış.", "set": {"volley_every": 3}},
			{"text": "Cıvata hızı +%40.", "set": {"proj_speed": 1.4}},
			{"text": "Çift cıvata: her 3. → her 2. atış.", "set": {"volley_every": 2}},
			{"text": "MAKİNELİ ARBALET: her 12 sn'de 3 sn boyunca saldırı hızın üç katına çıkar.", "set": {"frenzy_cd": 12.0}},
		],
	},
	"crossbow_zirh": {
		"weapon": "crossbow", "name": "Zırh Delen", "element": "isaret", "catalyst": "keskin_uclar",
		"power": "hit", "power_label": "cıvata hasarı",
		"desc": "Kalkanları deler ve düşmanları zayıflatır.",
		"steps": [
			{"text": "Cıvatalar düşman kalkanının %20'sini deler.", "set": {"shield_pen": 0.2}},
			{"text": "Her isabet 1 İşaret yükü bırakır (her yük düşmanın aldığı tüm hasarı %1 artırır, en fazla 20).", "set": {"mark_stacks": 1, "mark_cap": 20}},
			{"text": "Kalkan delme: %20 → %35.", "set": {"shield_pen": 0.35}},
			{"text": "Bosslara %25 fazla vurursun.", "set": {"boss_bonus": 0.25}},
			{"text": "İsabet başına İşaret: 1 → 2.", "set": {"mark_stacks": 2}},
			{"text": "İşaret tavanı: 20 → 40.", "set": {"mark_cap": 40}},
			{"text": "KUŞATMA CIVATASI: cıvatalar kalkanı tamamen yok sayar ve bosslara %40 fazla vurur.", "set": {"shield_pen": 1.0, "boss_bonus": 0.4}},
		],
	},
	"crossbow_kanca": {
		"weapon": "crossbow", "name": "Kanca Cıvatası", "element": "fiziksel", "catalyst": "kitelama_seti",
		"power": "hit", "power_label": "cıvata hasarı",
		"desc": "Belirli cıvatalar düşmanı sana doğru çeker.",
		"steps": [
			{"text": "Her 5. cıvata vurduğu düşmanı sana doğru 80 px çeker.", "set": {"hook_every": 5, "hook_pull": 80.0}},
			{"text": "Çekilen düşman 1 sn sersemler (bosslar hariç).", "set": {"hook_stun": 1.0}},
			{"text": "Kanca: her 5. → her 4. cıvata.", "set": {"hook_every": 4}},
			{"text": "Çekilen düşman yolundakilere çarpar (saldırı gücünün %50'si).", "set": {"hook_collide": 0.5}},
			{"text": "Kanca vurduğu düşmanla birlikte en yakınını da çeker.", "set": {"hook_targets": 2}},
			{"text": "Çektikten sonra 2 sn boyunca %15 daha az hasar alırsın.", "set": {"hook_dr": 0.15}},
			{"text": "HARPUN: kanca düşmanı yerine çiviler (2 sn; bosslar 1 sn neredeyse durur) ve bu sürede düşman tüm oyunculardan %30 fazla hasar alır.",
				"set": {"harpoon": true}},
		],
	},
	"crossbow_sok": {
		"weapon": "crossbow", "name": "Şok Cıvatası", "element": "sok", "catalyst": "yetenek_kitabi",
		"power": "shock", "power_label": "şok ve kule hasarı",
		"desc": "Cıvatalar şoklar; kritik vuruşlar şoku yayar.",
		"steps": [
			{"text": "Cıvata vurduğu düşmanı 4 sn şoklar: şoklu düşmana gelen her vuruşun %25'i en yakın düşmana sıçrar.",
				"set": {"shock_dur": 4.0, "shock_jump": 0.25, "shock_jumps": 1}},
			{"text": "Şoklu düşmanlara kritik şansın +%20.", "set": {"crit_vs_shocked": 0.2}},
			{"text": "Sıçrayan hasar: %25 → %40.", "set": {"shock_jump": 0.4}},
			{"text": "Kritik vuruş şoku yakındaki 2 düşmana da yayar.", "set": {"crit_spread": true}},
			{"text": "Şok süresi: 4 → 6 sn.", "set": {"shock_dur": 6.0}},
			{"text": "Şoklu düşman ölünce üstüne yıldırım düşer (60 px, saldırı gücünün %50'si).", "set": {"shock_death_bolt": true}},
			{"text": "TESLA CIVATASI: cıvata vurduğu yere 4 sn duran bir tesla kulesi kurar; kule saniyede bir yakındaki düşmana yıldırım atar (saldırı gücünün %40'ı). Aynı anda en fazla 3 kule.",
				"set": {"tesla_turret": true}},
		],
	},
	## ------------------------------------------------------------------ BUMERANG
	"bumerang_kenar": {
		"weapon": "boomerang", "name": "Keskin Kenar", "element": "kanama", "catalyst": "vampir_disi",
		"power": "bleed", "power_label": "kanama hasarı",
		"desc": "Bumerang geçtiği her düşmanı kanatır.",
		"steps": [
			{"text": "Bumerang her geçişte 1 kanama yükü bırakır. Her yük saniyede saldırı gücünün %3'ü kadar hasar verir (en fazla 10).",
				"set": {"bleed_stacks": 1, "bleed_cap": 10, "bleed_ap": 0.03}},
			{"text": "Dönüşte 2 kanama yükü bırakır.", "set": {"return_bleed": 2}},
			{"text": "Kanayan düşmanlara bumerang %20 fazla vurur.", "set": {"bleeding_bonus": 0.2}},
			{"text": "Kanama tavanı: 10 → 15.", "set": {"bleed_cap": 15}},
			{"text": "Bumerang %20 büyür (daha geniş keser).", "set": {"proj_scale": 1.2}},
			{"text": "Kanama iki kat hızlı işler.", "set": {"bleed_fast": true}},
			{"text": "KAN ÇARKI: bumerangı yakaladığında 3 sn boyunca etrafında dönen bir kan çarkı çıkar; değdiği düşmanlara vurur ve hasarın %30'u kadar can kazanırsın.",
				"set": {"blood_wheel": true}},
		],
	},
	"bumerang_cift": {
		"weapon": "boomerang", "name": "Çift Bumerang", "element": "fiziksel", "catalyst": "kaos_kitabi",
		"power": "hit", "power_label": "bumerang hasarı",
		"desc": "Aynı anda birden fazla bumerang atar.",
		"steps": [
			{"text": "Aynı anda 2 bumerang atarsın (ikincisi başka bir düşmana).", "set": {"extra_boomerangs": 1}},
			{"text": "Bumeranglar %20 daha hızlı.", "set": {"proj_speed": 1.2}},
			{"text": "Bumerang sayısı: 2 → 3.", "set": {"extra_boomerangs": 2}},
			{"text": "Dönen bir bumerangı yakalayınca 2 sn boyunca saldırı hızın +%15.", "set": {"catch_buff": 0.15}},
			{"text": "Bumerangların menzili +%20.", "set": {"range_mult": 1.2}},
			{"text": "Bumerang sayısı: 3 → 4.", "set": {"extra_boomerangs": 3}},
			{"text": "BUMERANG FIRTINASI: her bumerang en uzak noktada ikiye bölünür; ikinci parça yakındaki başka bir düşmana gider.", "set": {"split_return": true}},
		],
	},
	"bumerang_kasirga": {
		"weapon": "boomerang", "name": "Kasırga Bumerang", "element": "fiziksel", "catalyst": "deri_cizme",
		"power": "hit", "power_label": "bumerang hasarı",
		"desc": "Bumerang en uzak noktada durup dönerek keser.",
		"steps": [
			{"text": "Bumerang en uzak noktada 1 sn dönerek durur ve oradaki düşmanları tekrar tekrar keser.", "set": {"apex_pause": 1.0}},
			{"text": "Durma süresi: 1 → 1,5 sn.", "set": {"apex_pause": 1.5}},
			{"text": "Dururken çevresindeki düşmanları kendine çeker.", "set": {"apex_pull": true}},
			{"text": "Bumerang %30 büyür.", "set": {"proj_scale": 1.3}},
			{"text": "Durduğu yerdeki düşmanlar %30 yavaşlar.", "set": {"apex_slow": 0.3}},
			{"text": "Durma süresi: 1,5 → 2 sn.", "set": {"apex_pause": 2.0}},
			{"text": "HORTUM ÇARKI: bumerangı yakaladığında 4 sn boyunca etrafında dönen bir hortum çıkar; yanına gelen düşmanları sürekli keser (saldırı gücünün %40'ı).",
				"set": {"tornado_follow": true}},
		],
	},
	"bumerang_yildirim": {
		"weapon": "boomerang", "name": "Yıldırım Bumerang", "element": "sok", "catalyst": "hasat_cantasi",
		"power": "area", "power_label": "elektrik hattı hasarı",
		"desc": "Bumerangla arana bir elektrik hattı gerilir.",
		"steps": [
			{"text": "Bumerang havadayken seninle arasında bir elektrik hattı oluşur; hattan geçen düşmanlar saldırı gücünün %20'si kadar hasar alır ve şoklanır.",
				"set": {"tether_dmg": 0.2}},
			{"text": "Hat hasarı: %20 → %30.", "set": {"tether_dmg": 0.3}},
			{"text": "Bumerangın kendisi de vurduğu düşmanları şoklar.", "set": {"shock_dur": 3.0, "shock_jump": 0.25, "shock_jumps": 1}},
			{"text": "Hat genişliği +%50.", "set": {"tether_width": 1.5}},
			{"text": "Şoklu düşmanlara bumerang %25 fazla vurur.", "set": {"shocked_bonus": 0.25}},
			{"text": "Bumerangı yakalayınca hat 2 sn daha yerinde kalır.", "set": {"tether_linger": true}},
			{"text": "ENERJİ KIRBACI: bumerangın gittiği yol 3 sn boyunca elektrik ağı olarak kalır; ağın değdiği tecrübe küreleri sana çekilir.", "set": {"tether_net": true}},
		],
	},
	"bumerang_alev": {
		"weapon": "boomerang", "name": "Alevli Çark", "element": "yanma", "catalyst": "steroid",
		"power": "burn", "power_label": "yanma hasarı",
		"desc": "Bumerang yakar ve gittiği yolda alev izi bırakır.",
		"steps": [
			{"text": "Bumerang vurduğu düşmanları 3 sn yakar; yakaladığında gittiği yol 1 sn boyunca yanar.",
				"set": {"burn_ap": 0.10, "burn_dur": 3.0, "fire_trail": 1.0}},
			{"text": "Alev izi süresi: 1 → 2 sn.", "set": {"fire_trail": 2.0}},
			{"text": "Yanan düşmanlara bumerang %20 fazla vurur.", "set": {"burning_bonus": 0.2}},
			{"text": "Alev izi %50 daha geniş.", "set": {"trail_width": 1.5}},
			{"text": "Bumerangı yakalayınca etrafında alev halkası patlar (80 px, saldırı gücünün %50'si).", "set": {"catch_ring": true}},
			{"text": "Yanma 3 kez üst üste birikebilir.", "set": {"burn_stacks": 3}},
			{"text": "GÜNEŞ DİSKİ: bumerang iki kat büyük bir ateş diskine dönüşür ve yolundaki her şeyi yakar.", "set": {"sun_disc": true, "proj_scale": 2.0}},
		],
	},
	## ------------------------------------------------------------------ BUZ ASASI
	"buz_buzul": {
		"weapon": "buz_asasi", "name": "Buzul Asa", "element": "donma", "catalyst": "kitelama_seti",
		"power": "hit", "power_label": "asa hasarı",
		"desc": "Donmalar uzar; donmuş düşmanlar daha çok hasar alır.",
		"steps": [
			{"text": "Asanın dondurduğu düşmanlar 3 yerine 4 sn donar.", "set": {"freeze_dur": 4.0}},
			{"text": "Donmuş düşmanlara asa %30 fazla vurur.", "set": {"frozen_bonus": 0.3}},
			{"text": "Bosslar 10 yerine 8 isabette donar.", "set": {"boss_freeze_hits": 8}},
			{"text": "Donma süresi: 4 → 5 sn.", "set": {"freeze_dur": 5.0}},
			{"text": "Donmuş düşman ölünce çevreye 3 buz kıymığı saçar (saldırı gücünün %40'ı).", "set": {"frozen_shards": true}},
			{"text": "Buz kıymıkları vurdukları düşmanı da dondurur.", "set": {"shards_freeze": true}},
			{"text": "EBEDİ KIŞ: donma bittiğinde düşman 3 sn %50 yavaş kalır. Donmuş bir düşmana değen düşman da donar.",
				"set": {"linger_slow": 0.5, "contagious": true}},
		],
	},
	"buz_mizrak": {
		"weapon": "buz_asasi", "name": "Buz Mızrağı", "element": "donma", "catalyst": "kitelama_seti",
		"power": "hit", "power_label": "mızrak hasarı",
		"desc": "Buz mermisi mızrağa dönüşür ve düşmanları delip dondurur.",
		"steps": [
			{"text": "Buz mermisi 2 düşmanı delip geçer (deldiklerini de dondurur).", "set": {"pierce": 2, "pierce_pct": 0.8}},
			{"text": "Delme: 2 → 3 düşman.", "set": {"pierce": 3}},
			{"text": "Mızrak %40 büyür.", "set": {"proj_scale": 1.4}},
			{"text": "Donmuş düşmanlara mızrak %25 fazla vurur.", "set": {"frozen_bonus": 0.25}},
			{"text": "Delme: 3 → 5 düşman.", "set": {"pierce": 5}},
			{"text": "Mızrak son deldiği düşmanda buz patlaması yapar (80 px, dondurur).", "set": {"end_burst": true}},
			{"text": "BUZUL MIZRAK YAĞMURU: her 3. atış 5 mızraklık bir yelpaze olur; mızraklar düşmanları geri iter.", "set": {"spear_every": 3}},
		],
	},
	"buz_firtina": {
		"weapon": "buz_asasi", "name": "Kar Fırtınası", "element": "donma", "catalyst": "vitamin",
		"power": "area", "power_label": "fırtına hasarı",
		"desc": "Düzenli olarak etrafında kar fırtınası çıkarır.",
		"steps": [
			{"text": "Her 6 sn'de etrafında 2 sn süren bir kar fırtınası çıkar: içindeki düşmanlar saniyede saldırı gücünün %30'u kadar hasar alır ve %30 yavaşlar.",
				"set": {"blizzard_cd": 6.0, "blizzard_dur": 2.0, "blizzard_radius": 120.0}},
			{"text": "Fırtına sıklığı: 6 → 5 sn.", "set": {"blizzard_cd": 5.0}},
			{"text": "Fırtına alanı: 120 → 160 px.", "set": {"blizzard_radius": 160.0}},
			{"text": "Fırtınada 2 sn kalan düşman donar.", "set": {"blizzard_freeze": true}},
			{"text": "Fırtına süresi: 2 → 3 sn.", "set": {"blizzard_dur": 3.0}},
			{"text": "Fırtına seninle birlikte hareket eder.", "set": {"blizzard_follow": true}},
			{"text": "KUTUP GİRDABI: fırtına kalıcı olur. İçindeki her düşman için saniyede 0,3 can yenilersin (en fazla 3).", "set": {"blizzard_aura": true}},
		],
	},
	"buz_kristal": {
		"weapon": "buz_asasi", "name": "Buz Kristali", "element": "donma", "catalyst": "kalkan_yuzugu",
		"power": "area", "power_label": "kristal hasarı",
		"desc": "Yanına ateş eden buz kristali taretleri kurar.",
		"steps": [
			{"text": "Her 8 sn'de yanına 8 sn duran bir buz kristali kurar; kristal saniyede bir yakındaki düşmana buz oku atar (saldırı gücünün %40'ı, yavaşlatır).",
				"set": {"turret_cd": 8.0, "turret_dur": 8.0}},
			{"text": "Kristal sıklığı: 8 → 6 sn.", "set": {"turret_cd": 6.0}},
			{"text": "Kristalin okları yavaşlatmak yerine dondurur.", "set": {"turret_freeze": true}},
			{"text": "Aynı anda 2 kristal durabilir.", "set": {"turret_max": 2}},
			{"text": "Kristalin süresi bitince patlar ve 100 px'teki düşmanları dondurur.", "set": {"turret_blast": true}},
			{"text": "Kristal süresi: 8 → 12 sn.", "set": {"turret_dur": 12.0}},
			{"text": "KRİSTAL ORDU: kalkanın kırıldığında etrafında 4 kristal birden doğar (20 sn'de bir); kristaller iki kat hızlı ateş eder.", "set": {"crystal_army": true}},
		],
	},
	"buz_kalp": {
		"weapon": "buz_asasi", "name": "Donmuş Kalp", "element": "donma", "catalyst": "sansli_zar",
		"power": "area", "power_label": "buz kıymığı hasarı",
		"desc": "Donmuş ve canı azalmış düşmanları tek vuruşta paramparça eder.",
		"steps": [
			{"text": "Donmuş bir düşmanın canı %15'in altındaysa asanın vuruşu onu paramparça eder (bosslar hariç).", "set": {"shatter_th": 0.15}},
			{"text": "Paramparça eşiği: %15 → %20 can.", "set": {"shatter_th": 0.2}},
			{"text": "Paramparça olan düşmandan 3 buz kıymığı saçılır (saldırı gücünün %40'ı).", "set": {"shatter_shards": 3}},
			{"text": "Eşik: %20 → %25 can.", "set": {"shatter_th": 0.25}},
			{"text": "Paramparça olan düşmanın 60 px çevresindekiler donar.", "set": {"shatter_freeze_aoe": 60.0}},
			{"text": "Eşik: %25 → %30 can.", "set": {"shatter_th": 0.3}},
			{"text": "BUZ TAHTI: paramparça ettiğin her düşman %10 ihtimalle 3 sn boyunca tüm silahlarına %20 saldırı hızı verir (şansın bu ihtimali artırır).",
				"set": {"ice_throne": true}},
		],
	},
	## ------------------------------------------------------------------ FİŞEK
	"fisek_gosteri": {
		"weapon": "fisek", "name": "Havai Fişek Gösterisi", "element": "fiziksel", "catalyst": "sansli_zar",
		"power": "area", "power_label": "parçacık hasarı",
		"desc": "Patlama renkli parçacıklara ayrılır.",
		"steps": [
			{"text": "Patlama 3 küçük parçacığa ayrılır; her biri 40 px alanda saldırı gücünün %30'u kadar vurur.", "set": {"sparks": 3}},
			{"text": "Parçacık sayısı: 3 → 4.", "set": {"sparks": 4}},
			{"text": "Parçacık alanı +%30.", "set": {"spark_radius": 1.3}},
			{"text": "Parçacık sayısı: 4 → 6.", "set": {"sparks": 6}},
			{"text": "Her parçacık 2 mini parçacığa daha ayrılır.", "set": {"spark_split": true}},
			{"text": "Parçacıklar rastgele bir element taşır (yanma, donma, zehir ya da şok).", "set": {"spark_element": true}},
			{"text": "BAYRAM GECESİ: her 12 sn'de rastgele düşmanlara 10 fişek atarsın (şansın fişek sayısını artırır).", "set": {"festival": true}},
		],
	},
	"fisek_napalm": {
		"weapon": "fisek", "name": "Napalm Fişeği", "element": "yanma", "catalyst": "sigara",
		"power": "burn", "power_label": "yanma hasarı",
		"desc": "Patlama yeri yanan zemine döner.",
		"steps": [
			{"text": "Patlama alanı 3 sn yanan zemine döner; içindekiler yanar (saniyede saldırı gücünün %10'u).",
				"set": {"lava_dur": 3.0, "burn_ap": 0.10, "burn_dur": 3.0}},
			{"text": "Zemin süresi: 3 → 5 sn.", "set": {"lava_dur": 5.0}},
			{"text": "Yanma hasarı: saniyede %10 → %15 saldırı gücü.", "set": {"burn_ap": 0.15}},
			{"text": "Yanan zemin %30 daha geniş.", "set": {"lava_scale": 1.3}},
			{"text": "Yanma 3 kez üst üste birikebilir.", "set": {"burn_stacks": 3}},
			{"text": "Yanan zeminin üstünde durursan saldırı hızın +%10.", "set": {"lava_haste": 0.1}},
			{"text": "CEHENNEM ATEŞİ: patlama alanı iki katına çıkar, zemin 8 sn yanar.", "set": {"aoe_mult": 2.0, "lava_dur": 8.0}},
		],
	},
	"fisek_fitil": {
		"weapon": "fisek", "name": "Hızlı Fitil", "element": "fiziksel", "catalyst": "kaos_kitabi",
		"power": "hit", "power_label": "fişek hasarı",
		"desc": "Fişekler çok daha sık atılır.",
		"steps": [
			{"text": "Atış hızın +%25.", "set": {"attack_speed": 0.25}},
			{"text": "Atış hızı: +%25 → +%45.", "set": {"attack_speed": 0.45}},
			{"text": "Fişekler %40 daha hızlı uçar.", "set": {"proj_speed": 1.4}},
			{"text": "Her 3. atışta bir fişek daha atarsın.", "set": {"volley_every": 3, "volley_count": 1, "volley_delay": 0.15}},
			{"text": "Atış hızı: +%45 → +%65.", "set": {"attack_speed": 0.65}},
			{"text": "Her atışta 2 fişek atarsın.", "set": {"multi_count": 2, "fan_deg": 0.0}},
			{"text": "ROKET BATARYASI: her atışta ayrıca 4 mini roket fırlatırsın (her biri %40 hasarla).", "set": {"rockets": 4}},
		],
	},
	"fisek_sersem": {
		"weapon": "fisek", "name": "Sersemletici Bomba", "element": "fiziksel", "catalyst": "deri_cizme",
		"power": "hit", "power_label": "fişek hasarı",
		"desc": "Patlama düşmanları sersemletir.",
		"steps": [
			{"text": "Patlama vurduğu düşmanları 0,8 sn sersemletir (bosslar hariç).", "set": {"stun_on_hit": 0.8}},
			{"text": "Sersemletme: 0,8 → 1,2 sn.", "set": {"stun_on_hit": 1.2}},
			{"text": "Sersemlettiğin düşmanlar 2 sn boyunca tüm oyunculardan %25 fazla hasar alır.", "set": {"stun_vuln": 0.25}},
			{"text": "Patlama alanı +%30.", "set": {"aoe_mult": 1.3}},
			{"text": "Bosslar sersemlemez ama 2 sn %50 yavaşlar.", "set": {"boss_slow": 0.5}},
			{"text": "Sersemleme bitince düşmanlar 2 sn daha %40 yavaş kalır.", "set": {"stun_slow": 0.4}},
			{"text": "IŞIK BOMBASI: patlama düşmanları dışarı iter ve 2 sn şaşkın dolaştırır; sen de 2 sn %20 hızlanırsın.", "set": {"flashbang": true}},
		],
	},
	"fisek_simsek": {
		"weapon": "fisek", "name": "Şimşek Fişeği", "element": "sok", "catalyst": "yetenek_kitabi",
		"power": "area", "power_label": "yıldırım hasarı",
		"desc": "Patlama şoklar ve çevreye yıldırım dalları saçar.",
		"steps": [
			{"text": "Patlama vurduğu düşmanları 4 sn şoklar (şoklu düşmana gelen vuruşun %25'i yakınına sıçrar).",
				"set": {"shock_dur": 4.0, "shock_jump": 0.25, "shock_jumps": 1}},
			{"text": "Sıçrayan hasar: %25 → %40.", "set": {"shock_jump": 0.4}},
			{"text": "Patlama çevresine 3 yıldırım dalı saçar (150 px, her biri saldırı gücünün %35'i).", "set": {"branches": 3}},
			{"text": "Şok süresi: 4 → 6 sn.", "set": {"shock_dur": 6.0}},
			{"text": "Yıldırım dalı: 3 → 5.", "set": {"branches": 5}},
			{"text": "Şoklu düşman ölünce üstüne yıldırım düşer (60 px, saldırı gücünün %50'si).", "set": {"shock_death_bolt": true}},
			{"text": "ELEKTRİK FIRTINASI: patlama noktasında 4 sn duran bir elektrik bulutu kalır; saniyede 3 kez rastgele düşmanlara yıldırım düşer.", "set": {"storm_cloud": true}},
		],
	},
	## ------------------------------------------------------------------ PENÇE
	"pence_vahsi": {
		"weapon": "pence", "name": "Vahşi Pençe", "element": "kanama", "catalyst": "vampir_disi",
		"power": "bleed", "power_label": "kanama hasarı",
		"desc": "Pençeler derin yaralar açar; kanama yükleri birikir.",
		"steps": [
			{"text": "Her pençe darbesi 1 kanama yükü bırakır. Her yük saniyede saldırı gücünün %3'ü kadar hasar verir (en fazla 8).",
				"set": {"bleed_stacks": 1, "bleed_cap": 8, "bleed_ap": 0.03}},
			{"text": "Darbe başına kanama: 1 → 2 yük.", "set": {"bleed_stacks": 2}},
			{"text": "Kanama tavanı: 8 → 12.", "set": {"bleed_cap": 12}},
			{"text": "Kanayan düşmanlara %20 fazla vurursun.", "set": {"bleeding_bonus": 0.2}},
			{"text": "Bu pençeyle 10+ kanama yükü bıraktığın düşmana her vuruş onu parçalar: ayrıca saldırı gücünün %60'ı kadar vurur.", "set": {"rend": true}},
			{"text": "Saldırı hızın +%15.", "set": {"attack_speed": 0.15}},
			{"text": "KURT KANI: kanayan düşmanlara vurduğun hasarın %3'ü kadar can kazanırsın. Canın %50'nin altındayken saldırı hızın +%40.", "set": {"wolf_blood": true}},
		],
	},
	"pence_hucum": {
		"weapon": "pence", "name": "Hayvan Hücumu", "element": "fiziksel", "catalyst": "deri_cizme",
		"power": "area", "power_label": "atılma hasarı",
		"desc": "Belli aralıklarla bir düşmana atılırsın.",
		"steps": [
			{"text": "4 sn'de bir 200 px içindeki bir düşmana atılırsın; yolundaki düşmanlara saldırı gücünün %60'ı kadar vurur.", "set": {"dash_cd": 4.0}},
			{"text": "Atılma sıklığı: 4 → 3 sn.", "set": {"dash_cd": 3.0}},
			{"text": "Atıldıktan sonra 2 sn saldırı hızın +%30.", "set": {"dash_haste": 0.3}},
			{"text": "Atılmanın vurduğu düşmanlar 0,5 sn sersemler (bosslar hariç).", "set": {"dash_stun": 0.5}},
			{"text": "Atılma zincirlenir: ilk hedeften sonra yakındaki ikinci bir düşmana da atılırsın.", "set": {"dash_chain": 2}},
			{"text": "Atılma sırasında hasar almazsın.", "set": {"dash_invuln": true}},
			{"text": "SÜRÜ LİDERİ: her atılmada 5 sn boyunca düşmanlara saldıran 2 hayalet kurt çağırırsın (her ısırık saldırı gücünün %40'ı).", "set": {"pack_leader": true}},
		],
	},
	"pence_dortlu": {
		"weapon": "pence", "name": "Dörtlü Pençe", "element": "fiziksel", "catalyst": "eldiven",
		"power": "hit", "power_label": "pençe hasarı",
		"desc": "Pençe her saldırıda daha çok darbe indirir.",
		"steps": [
			{"text": "Her saldırıdaki pençe darbesi: 2 → 3.", "set": {"segments": 3}},
			{"text": "Darbe sayısı: 3 → 4.", "set": {"segments": 4}},
			{"text": "Çevredeki düşmanlara giden hasar: %50 → %70.", "set": {"aoe_pct": 0.7}},
			{"text": "Pençenin vuruş alanı +%25.", "set": {"aoe_mult": 1.25}},
			{"text": "Darbe sayısı: 4 → 5.", "set": {"segments": 5}},
			{"text": "Saldırı hızın +%20.", "set": {"attack_speed": 0.2}},
			{"text": "PENÇE FIRTINASI: her 5. saldırında etrafında 360° bir pençe dönüşü yaparsın (140 px, saldırı gücünün %120'si).", "set": {"claw_storm_every": 5}},
		],
	},
	"pence_kan": {
		"weapon": "pence", "name": "Kan Emici", "element": "kanama", "catalyst": "vitamin",
		"power": "heal", "power_label": "can çalma",
		"desc": "Vurduğun hasar sana can olarak döner.",
		"steps": [
			{"text": "Pençeyle verdiğin hasarın %1'i kadar can kazanırsın.", "set": {"lifesteal": 0.01}},
			{"text": "Her öldürmende 2 can kazanırsın.", "set": {"kill_heal": 2.0}},
			{"text": "Can çalma: %1 → %1,5.", "set": {"lifesteal": 0.015}},
			{"text": "Canın doluyken kazandığın can kalkanına eklenir.", "set": {"overheal_shield": true}},
			{"text": "Can çalma: %1,5 → %2.", "set": {"lifesteal": 0.02}},
			{"text": "Canın %30'un altındayken can çalma iki kat.", "set": {"low_hp_double": true}},
			{"text": "KAN LORDU: canın doluyken kazandığın fazla canın %10'u kalıcı maksimum cana dönüşür (sınırsız).", "set": {"blood_lord": true}},
		],
	},
	"pence_buz": {
		"weapon": "pence", "name": "Buz Pençesi", "element": "donma", "catalyst": "steroid",
		"power": "hit", "power_label": "pençe hasarı",
		"desc": "Pençeler buz keser: yavaşlatır ve dondurur.",
		"steps": [
			{"text": "Pençe darbeleri 2 sn %25 yavaşlatır; aynı düşmana 4. isabette onu 2 sn dondurur.",
				"set": {"slow_pct": 0.25, "slow_dur": 2.0, "freeze_after": 4, "freeze_dur": 2.0}},
			{"text": "Donma için gereken isabet: 4 → 3.", "set": {"freeze_after": 3}},
			{"text": "Donmuş düşmana vuruş çevresine buz kıymıkları saçar (saldırı gücünün %30'u).", "set": {"frozen_shatter": 0.3}},
			{"text": "Yavaşlatma: %25 → %40.", "set": {"slow_pct": 0.4}},
			{"text": "Donma süresi: 2 → 4 sn.", "set": {"freeze_dur": 4.0}},
			{"text": "Donmuş düşmanlara %35 fazla vurursun.", "set": {"frozen_bonus": 0.35}},
			{"text": "YETİ PENÇESİ: her 3. saldırında 150 px'lik bir buz depremi yaparsın (saldırı gücünün %100'ü + maksimum canının %3'ü) ve vurduğu düşmanları dondurursun.",
				"set": {"yeti_every": 3}},
		],
	},
	## ------------------------------------------------------------------ TOPUZ
	"topuz_deprem": {
		"weapon": "topuz", "name": "Deprem", "element": "fiziksel", "catalyst": "steroid",
		"power": "hit", "power_label": "topuz ve dalga hasarı",
		"desc": "Topuz yeri sarsar ve düşmanları sersemletir.",
		"steps": [
			{"text": "Topuzun vurduğu her düşman 0,5 sn sersemler (bosslar hariç).", "set": {"stun_on_hit": 0.5}},
			{"text": "Topuzun vuruş alanı +%25.", "set": {"aoe_mult": 1.25}},
			{"text": "Her 3. vuruşta yere bir şok dalgası yayılır (150 px, vuruş hasarının %60'ı).", "set": {"wave_every": 3, "wave_radius": 150.0, "wave_ratio": 0.6}},
			{"text": "Sersemletme: 0,5 → 0,8 sn.", "set": {"stun_on_hit": 0.8}},
			{"text": "Şok dalgası 2 sn %40 yavaşlatır.", "set": {"wave_slow": 0.4}},
			{"text": "Şok dalgası: her 3. → her 2. vuruş.", "set": {"wave_every": 2}},
			{"text": "TEKTONİK DARBE: her 6. vuruşun 250 px'lik dev bir darbe olur (saldırı gücünün %250'si + maksimum canının %3'ü, 1,5 sn sersemletir).",
				"set": {"slam_every": 6}},
		],
	},
	"topuz_kutsal": {
		"weapon": "topuz", "name": "Kutsal Topuz", "element": "kutsal", "catalyst": "kalkan_yuzugu",
		"power": "shield", "power_label": "kalkan ve iyileştirme",
		"desc": "Vuruşların seni ve dostlarını korur.",
		"steps": [
			{"text": "Topuzun vurduğu her düşman için 1 kalkan kazanırsın (vuruş başına en fazla 8 düşman).", "set": {"shield_per_hit": 1.0}},
			{"text": "Düşman başına kalkan: 1 → 2.", "set": {"shield_per_hit": 2.0}},
			{"text": "Kalkanın doluyken topuz %20 fazla vurur.", "set": {"full_shield_bonus": 0.2}},
			{"text": "Her 10. vuruşta çevrende kutsal ışık parlar: 150 px içindeki sen ve dostların 10 can kazanır.", "set": {"light_every": 10, "light_heal": 10.0}},
			{"text": "Düşman başına kalkan: 2 → 3.", "set": {"shield_per_hit": 3.0}},
			{"text": "Kutsal ışık: her 10. → her 6. vuruş.", "set": {"light_every": 6}},
			{"text": "PALADİN ÇEKİCİ: kutsal ışık düşmanlara da vurur (saldırı gücünün %150'si) ve dostlarına kalkan da verir. Kalkanın kırılınca ışık kendiliğinden parlar (15 sn'de bir).",
				"set": {"light_final": true}},
		],
	},
	"topuz_ates": {
		"weapon": "topuz", "name": "Ateş Topuzu", "element": "yanma", "catalyst": "sigara",
		"power": "burn", "power_label": "yanma hasarı",
		"desc": "Topuz tutuşur; vurduğu yer lava döner.",
		"steps": [
			{"text": "Topuzun vurduğu düşmanlar 3 sn yanar (saniyede saldırı gücünün %10'u).", "set": {"burn_ap": 0.10, "burn_dur": 3.0}},
			{"text": "Yanma hasarı: saniyede %10 → %15 saldırı gücü.", "set": {"burn_ap": 0.15}},
			{"text": "Vurduğun yerde 2 sn yanan bir lav gölü kalır (60 px).", "set": {"lava_dur": 2.0, "lava_radius": 60.0}},
			{"text": "Lav gölü: 60 → 100 px.", "set": {"lava_radius": 100.0}},
			{"text": "Yanan düşmanlara topuz %25 fazla vurur.", "set": {"burning_bonus": 0.25}},
			{"text": "Lav süresi: 2 → 4 sn.", "set": {"lava_dur": 4.0}},
			{"text": "VOLKAN: her 5. vuruşunda vurduğun yerde 5 sn duran küçük bir volkan çıkar ve çevresine lav topları fırlatır.", "set": {"volcano_every": 5}},
		],
	},
	"topuz_agir": {
		"weapon": "topuz", "name": "Ağır Darbe", "element": "fiziksel", "catalyst": "keskin_uclar",
		"power": "hit", "power_label": "topuz hasarı",
		"desc": "Belli vuruşlar çok ağır iner.",
		"steps": [
			{"text": "Her 4. vuruşun ağır darbe olur: 2 kat hasar.", "set": {"heavy_every": 4, "heavy_mult": 2.0}},
			{"text": "Ağır darbe: her 4. → her 3. vuruş.", "set": {"heavy_every": 3}},
			{"text": "Ağır darbe düşman kalkanının %50'sini deler.", "set": {"heavy_pen": 0.5}},
			{"text": "Ağır darbe hasarı: 2 → 2,5 kat.", "set": {"heavy_mult": 2.5}},
			{"text": "Ağır darbe bosslara ayrıca %50 fazla vurur.", "set": {"heavy_boss": 0.5}},
			{"text": "Ağır darbeden sonra 1 sn boyunca %30 daha az hasar alırsın.", "set": {"heavy_dr": 0.3}},
			{"text": "KAFATASI KIRICI: ağır darbe hedefte kalıcı bir çatlak bırakır; her çatlak o düşmanın aldığı tüm hasarı %10 artırır (bosslar dahil, sınırsız).",
				"set": {"crack": true}},
		],
	},
	"topuz_simsek": {
		"weapon": "topuz", "name": "Şimşek Çekici", "element": "sok", "catalyst": "steroid",
		"power": "area", "power_label": "yıldırım hasarı",
		"desc": "Topuz şoklar ve çevreye yıldırım dalları saçar.",
		"steps": [
			{"text": "Topuzun vurduğu düşmanlar 4 sn şoklanır: şoklu düşmana gelen her vuruşun %25'i en yakın düşmana sıçrar.",
				"set": {"shock_dur": 4.0, "shock_jump": 0.25, "shock_jumps": 1}},
			{"text": "Şoklu düşmanlara topuz %20 fazla vurur.", "set": {"shocked_bonus": 0.2}},
			{"text": "Her vuruş çevresine 2 yıldırım dalı saçar (150 px, her biri saldırı gücünün %35'i).", "set": {"branches": 2}},
			{"text": "Şok süresi: 4 → 6 sn.", "set": {"shock_dur": 6.0}},
			{"text": "Yıldırım dalı: 2 → 4.", "set": {"branches": 4}},
			{"text": "Şoklu düşman ölünce üstüne yıldırım düşer (60 px, saldırı gücünün %50'si).", "set": {"shock_death_bolt": true}},
			{"text": "GÖK GÜRÜLTÜSÜ: her 8 sn'de topuzunu fırlatırsın; topuz gidip döner, yolundaki düşmanlara vurur ve çevresine yıldırım saçar. Maksimum canın arttıkça büyür.",
				"set": {"hammer_throw": true}},
		],
	},
	## ------------------------------------------------------------------ UZUNKILIÇ (etrafında dönen kılıç - "sn" = kılıcın çeyrek turu: temel hızda ~1 sn,
	## saldırı hızıyla kısalır; bkz. weapon.gd ENCHANT_SWING_ARC)
	"kilic_dalga": {
		"weapon": "uzunkilic", "name": "Kılıç Dalgası", "element": "fiziksel", "catalyst": "keskin_uclar",
		"power": "area", "power_label": "dalga hasarı",
		"desc": "Etrafında dönen kılıç düzenli olarak ileriye enerji dalgası fırlatır.",
		"steps": [
			{"text": "Kılıç her 3 sn'de bir en yakın düşmana doğru 220 px ilerleyen bir enerji dalgası fırlatır; yolundaki düşmanlara saldırı gücünün %60'ı kadar vurur (saldırı hızın arttıkça sıklaşır).",
				"set": {"wave_every_rev": 3}},
			{"text": "Dalga sıklığı: 3 sn → 2 sn.", "set": {"wave_every_rev": 2}},
			{"text": "Dalga %50 daha geniş.", "set": {"wave_width": 1.5}},
			{"text": "Dalga hasarı: %60 → %80.", "set": {"wave_pct": 0.8}},
			{"text": "Dalga aynı anda ters yöne de çıkar.", "set": {"wave_double": true}},
			{"text": "Dalga sıklığı: 2 sn → 1 sn.", "set": {"wave_every_rev": 1}},
			{"text": "GÖĞÜ YARAN: dalga ekranı boydan boya geçer ve geçtiği yerde 1 sn sonra ikinci kez vuran bir kesik bırakır.", "set": {"sky_split": true}},
		],
	},
	"kilic_kanli": {
		"weapon": "uzunkilic", "name": "Kanlı Kılıç", "element": "kanama", "catalyst": "hasat_cantasi",
		"power": "bleed", "power_label": "kanama hasarı",
		"desc": "Dönen kılıç kanatır.",
		"steps": [
			{"text": "Kılıcın her vuruşu 1 kanama yükü bırakır. Her yük saniyede saldırı gücünün %3'ü kadar hasar verir (en fazla 10).",
				"set": {"bleed_stacks": 1, "bleed_cap": 10, "bleed_ap": 0.03}},
			{"text": "Vuruş başına kanama: 1 → 2 yük.", "set": {"bleed_stacks": 2}},
			{"text": "Kanayan düşmanlara kılıç %20 fazla vurur.", "set": {"bleeding_bonus": 0.2}},
			{"text": "Kanama tavanı: 10 → 15.", "set": {"bleed_cap": 15}},
			{"text": "Kılıç aynı düşmana %20 daha sık vurur.", "set": {"orbit_cd_mult": 0.8}},
			{"text": "Kanayan düşman ölünce kan patlaması olur (60 px, saldırı gücünün %40'ı).", "set": {"bleed_death_blast": true}},
			{"text": "KAN YEMİNİ: kanayan 20 düşman öldürdükçe 10 sn kan öfkesine girersin: kılıcın vuruş alanı 1,5 katına çıkar ve kılıçla verdiğin hasarın %5'i kadar can kazanırsın.",
				"set": {"bleed_kill": true, "blood_oath": true}},
		],
	},
	"kilic_karsi": {
		"weapon": "uzunkilic", "name": "Karşı Saldırı", "element": "fiziksel", "catalyst": "kalkan_yuzugu",
		"power": "hit", "power_label": "kılıç hasarı",
		"desc": "Hasar aldığında kılıç karşılık verir; bazı saldırıları engellersin.",
		"steps": [
			{"text": "Hasar aldıktan sonraki 1 sn boyunca kılıç iki kat vurur.", "set": {"counter_mult": 2.0}},
			{"text": "Gelen saldırıların %10'unu tamamen engellersin.", "set": {"block": 0.10}},
			{"text": "Karşılık süresince kılıcın vuruş alanı %50 büyür.", "set": {"counter_aoe": 1.5}},
			{"text": "Engelleme şansı: %10 → %15.", "set": {"block": 0.15}},
			{"text": "Engellediğin bir saldırı da karşılık süresini başlatır.", "set": {"block_counter": true}},
			{"text": "Engelleme şansı: %15 → %20.", "set": {"block": 0.20}},
			{"text": "MÜKEMMEL SAVUNMA: kalkanın doluyken engelleme şansın %35. Engellediğin her saldırı, hasarın iki katı olarak saldırana geri döner ve 2 sn boyunca %30 fazla vurursun.",
				"set": {"perfect_guard": true}},
		],
	},
	"kilic_alev": {
		"weapon": "uzunkilic", "name": "Alevli Kılıç", "element": "yanma", "catalyst": "sigara",
		"power": "burn", "power_label": "yanma hasarı",
		"desc": "Kılıç tutuşur; dönerken alev halkası bırakır.",
		"steps": [
			{"text": "Kılıcın vurduğu düşmanlar 3 sn yanar (saniyede saldırı gücünün %10'u).", "set": {"burn_ap": 0.10, "burn_dur": 3.0}},
			{"text": "Yanma hasarı: saniyede %10 → %15 saldırı gücü.", "set": {"burn_ap": 0.15}},
			{"text": "Her 2 sn'de kılıcın döndüğü çemberde 1 sn yanan bir alev halkası kalır (saldırı hızın arttıkça sıklaşır).", "set": {"flame_ring_every": 2, "ring_dur": 1.0}},
			{"text": "Yanan düşmanlara kılıç %25 fazla vurur.", "set": {"burning_bonus": 0.25}},
			{"text": "Alev halkası süresi: 1 → 2 sn.", "set": {"ring_dur": 2.0}},
			{"text": "Yanma 3 kez üst üste birikebilir.", "set": {"burn_stacks": 3}},
			{"text": "ATEŞ KILICI: kılıcın vuruş alanı iki katına çıkar ve her 2 sn'de çevresine alev dalgası salar (saldırı gücünün %60'ı, yakar).",
				"set": {"fire_sword": true, "aoe_mult": 2.0}},
		],
	},
	"kilic_ruzgar": {
		"weapon": "uzunkilic", "name": "Rüzgâr Kılıcı", "element": "fiziksel", "catalyst": "deri_cizme",
		"power": "hit", "power_label": "kılıç ve kasırga hasarı",
		"desc": "Kılıç daha sık vurur ve etrafında kasırgalar çıkarır.",
		"steps": [
			{"text": "Kılıç aynı düşmana %15 daha sık vurur.", "set": {"orbit_cd_mult": 0.85}},
			{"text": "Kılıcın vuruş alanı +%15.", "set": {"aoe_mult": 1.15}},
			{"text": "Her 5 sn'de çevrende bir kasırga döner (120 px, saldırı gücünün %80'i) (saldırı hızın arttıkça sıklaşır).", "set": {"whirl_every": 5}},
			{"text": "Kılıç aynı düşmana %30 daha sık vurur.", "set": {"orbit_cd_mult": 0.7}},
			{"text": "Kasırga sıklığı: 5 sn → 4 sn.", "set": {"whirl_every": 4}},
			{"text": "Kasırga düşmanları içeri çeker.", "set": {"whirl_pull": true}},
			{"text": "KILIÇ USTASI: hareket halindeyken kılıç iki kat vurur. Bir saldırıdan sıyrıldığında 3 sn boyunca yarım saniyede bir kasırga çıkar.",
				"set": {"sword_master": true}},
		],
	},
}


static func get_def(id: String) -> Dictionary:
	return DEFS.get(id, {})


static func has_weapon(weapon_key: String) -> bool:
	return BY_WEAPON.has(weapon_key)


static func element_color(element: String) -> Color:
	return Color(ELEMENTS.get(element, ELEMENTS["fiziksel"])["color"])


static func element_name(element: String) -> String:
	return str(ELEMENTS.get(element, ELEMENTS["fiziksel"])["name"])


## Bir silah kopyasının efsun kaydını ({"id", "steps": [güç...], "askin": float}) davranış scriptinin okuyacağı düz
## istatistik sözlüğüne çevirir. "power_mult" = 1 + (alınan kartların gücü + Aşkın gücü); "power_on" gücün neyi çarptığı.
static func resolve(ench: Dictionary) -> Dictionary:
	var def: Dictionary = get_def(str(ench.get("id", "")))
	if def.is_empty():
		return {}
	var steps_taken: Array = ench.get("steps", [])
	var stats: Dictionary = {"id": ench["id"], "element": def.get("element", "fiziksel"), "step_count": steps_taken.size(),
		"power_on": str(def.get("power", "hit"))}
	var power: float = float(ench.get("askin", 0.0))
	var def_steps: Array = def["steps"]
	for i in range(mini(steps_taken.size(), def_steps.size())):
		var step: Dictionary = def_steps[i]
		for k in step.get("set", {}):
			stats[k] = step["set"][k]
		for k in step.get("add", {}):
			stats[k] = float(stats.get(k, 0.0)) + float(step["add"][k])
		power += float(steps_taken[i])
	stats["power_mult"] = 1.0 + power
	stats["is_final"] = steps_taken.size() >= STEP_COUNT
	return stats


## Karttaki "efsun gücü" artışı (Temel, I-V). Final kartı güç eklemez.
static func card_power(tier: int) -> float:
	return CARD_POWER * float(TIER_POWER[clampi(tier, 1, 4) - 1])


static func askin_power(tier: int) -> float:
	return ASKIN_POWER * float(TIER_POWER[clampi(tier, 1, 4) - 1])
