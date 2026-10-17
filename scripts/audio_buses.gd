extends RefCounted

## Çalışma anında kurulan ses yolları (proje default_bus_layout.tres kullanmıyor - sadece Master var). TEK kaynak:
##  - AMBIENT: dünyanın konumsuz ortam sesleri (yağmur/rüzgar/fırtına döngüleri, uzak gök gürültüsü, orman ambiyansı).
##    Şovalye Koruma Baloncuğu'nun içindeyken alçak geçiren filtresi açılır (bkz. fx_paladin_barrier.gd). Kullanıcı
##    bildirimi (2026-09-25): "şovalye adamın kalkanının içindeyken sesler boğuklaşmıyor" - dışarıyı en çok belli eden bu ortam
##    sesleri konumsuz AudioStreamPlayer'dı ve hiç etkilenmiyordu (konumlu sesler Area2D ile boğuluyor SANILIYORDU - aşağıda MUFFLE).
##  - MUFFLE: kubbenin dışında çalan konumlu (2D) sesler (dome_sound_router.gd çalıcının bus'ını konumuna göre değiştirir; Area2D
##    audio_bus_override Godot 4.7.2'de AudioStreamPlayer2D'yi YÖNLENDİRMİYOR - ölçüldü 2026-10-17, madde 218).
## İkisi de Master'a gönderir -> ana ses ayarı (ui_sound.gd Master) aynen geçerli.

const AMBIENT_BUS := &"Ambient"
const MUFFLE_BUS := &"BarrierMuffle"
## Kullanıcı bildirimi (2026-09-26): "kalkanın içindeyken dışardan içeri hiç ses çıkmıyor, yağmur boğuk gelmiyor" - eski
## 500 Hz + -6 dB, kulağın en duyarlı olduğu 2-5 kHz'i silip sesi neredeyse YOK ediyordu. Ölçüm (ses dosyalarının kendisi,
## Godot'nun biquad alçak geçireni rezonans 0.5, A-ağırlıklı = algılanan): yağmur -19.6 dB, fırtına rüzgarı -16.2, rüzgar
## -12.6. Şimdi 1200 Hz (tek aşama = varsayılan) + -1 dB: tizler hâlâ sert kesilir (4 kHz'de ~-22 dB, boğuk "duvarın
## arkasından" tını) ama sesin gövdesi kalır - yağmur -8.0, fırtına rüzgarı -5.4, rüzgar -3.3 dB.
const MUFFLE_CUTOFF_HZ := 1200.0
const MUFFLE_VOLUME_DB := -1.0
## RIM_WEAPON: Şovalye kubbesinin tacından (dome_weapon_ring.gd) ateşlenen SİLAH sesleri. 2026-10-15: "kubbenin içindeyken dışardaki
## silahları duyabiliyoruz, boğuk duymalıydık" -> 650 Hz + -5 dB yapılmıştı; ölçüm (2026-10-17, headless Dummy sürücü GERÇEK karıştırır):
## tabanca -13 dB, tizler -32 dB, uzak oyuncunun silahı -59 dB = "şovalye adam dışındakiler dışardaki sesi duyamıyor hiç". Kullanıcı:
## "kubbenin içindeyken ses efektinin kısıktan ziyade boğuk ve yankılı olmasını istiyorum. efektli olmalı" -> kısma YOK: alçak geçiren
## (hafif rezonanslı, cam fanus tınısı) + belirgin yankı (Reverb: oda + ön gecikme geri beslemesi = tekrarlayan yankı), ses seviyesi
## telafili (filtrenin yediği gövde geri verilir). Sayılar ölçüldü: bkz. docs/notlar madde 218.
const RIM_WEAPON_BUS := &"BarrierRimWeapon"
const RIM_WEAPON_CUTOFF_HZ := 1000.0
const RIM_WEAPON_RESONANCE := 0.9
const RIM_WEAPON_VOLUME_DB := 1.0
## Yankı ayarları [oda, sönüm, ön gecikme ms, ön gecikme geri beslemesi, yayılım, alt kesim (0-1), kuru, ıslak].
## MUFFLE: kubbenin dışındaki tüm konumlu sesler (dome_sound_router.gd yönlendirir) - biraz daha uzak/geniş, daha az ıslak.
const MUFFLE_REVERB := [0.65, 0.55, 55.0, 0.3, 0.9, 0.15, 0.9, 0.35]
const RIM_WEAPON_REVERB := [0.7, 0.4, 85.0, 0.45, 0.8, 0.1, 0.9, 0.5]


## Yerel oyuncu şu an bir kubbenin (Şovalye R / satıcı baloncuğu) içinde mi - set_ambient_muffled günceller.
static var in_dome: bool = false


static func _ensure(bus_name: StringName) -> int:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		return idx
	AudioServer.add_bus()
	idx = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, &"Master")
	var rim: bool = bus_name == RIM_WEAPON_BUS
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = RIM_WEAPON_CUTOFF_HZ if rim else MUFFLE_CUTOFF_HZ
	if rim:
		lp.resonance = RIM_WEAPON_RESONANCE
	AudioServer.add_bus_effect(idx, lp)
	## Ambient'in filtresi varsayılan KAPALI (sadece kubbe içindeyken açılır); Muffle/Rim yolları zaten sadece dış sesleri taşır.
	AudioServer.set_bus_effect_enabled(idx, 0, bus_name != AMBIENT_BUS)
	## Yankı: sadece konumlu dış sesler (yağmur/rüzgar döngüsüne yankı gövde katmaz, bulanıklaştırır).
	if bus_name == MUFFLE_BUS or rim:
		AudioServer.add_bus_effect(idx, make_reverb(RIM_WEAPON_REVERB if rim else MUFFLE_REVERB))
	var vol: float = 0.0
	if bus_name == MUFFLE_BUS:
		vol = MUFFLE_VOLUME_DB
	elif rim:
		vol = RIM_WEAPON_VOLUME_DB
	AudioServer.set_bus_volume_db(idx, vol)
	return idx


static func make_reverb(cfg: Array) -> AudioEffectReverb:
	var rv := AudioEffectReverb.new()
	rv.room_size = cfg[0]
	rv.damping = cfg[1]
	rv.predelay_msec = cfg[2]
	rv.predelay_feedback = cfg[3]
	rv.spread = cfg[4]
	rv.hipass = cfg[5]
	rv.dry = cfg[6]
	rv.wet = cfg[7]
	return rv


## Taç silah sesi çalıcısını (AudioStreamPlayer2D) boğuk + yankılı yola alır / normale döndürür. `on`: kubbe tacından mı çalıyor.
## Her atışta çağrılır (silah taca girip çıkabilir); varsayılana dönünce bus Master (kubbenin dışındaysa dome_sound_router.gd
## sonraki karede Muffle'a alır). Sadece YEREL oyuncu bir kubbenin içindeyken (in_dome) etkili: dışarıdaki dinleyici normal duyar.
static func route_rim_sound(p: AudioStreamPlayer2D, on: bool) -> void:
	if p == null:
		return
	if on and in_dome:
		_ensure(RIM_WEAPON_BUS)
		p.bus = RIM_WEAPON_BUS
	elif p.bus == RIM_WEAPON_BUS:
		p.bus = &"Master"


## Konumsuz ortam sesi çalarları bus = ambient_bus() ile kurulur.
static func ambient_bus() -> StringName:
	_ensure(AMBIENT_BUS)
	return AMBIENT_BUS


static func muffle_bus() -> StringName:
	_ensure(MUFFLE_BUS)
	return MUFFLE_BUS


static func set_ambient_muffled(on: bool) -> void:
	in_dome = on
	var idx: int = _ensure(AMBIENT_BUS)
	AudioServer.set_bus_effect_enabled(idx, 0, on)
	AudioServer.set_bus_volume_db(idx, MUFFLE_VOLUME_DB if on else 0.0)
