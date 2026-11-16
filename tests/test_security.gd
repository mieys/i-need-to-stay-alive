extends Node

## HİLE KORUMASI (kullanıcı isteği 2026-11-12): mühürlü kayıt (secure_cfg.gd), korumalı sayı (protected_int.gd), geliştirici kapısı +
## bütünlük bayrağı (security_guard.gd), korumalı altın/parçacık (game_manager.gd), uzaktan sahne yolu + gönderen kontrolü (network_manager.gd).
## Hepsi GEÇİCİ dosyalarda - kullanıcının gerçek kaydına dokunmaz. Testler editör ikilisinde koşar (dev_allowed true); exported davranışı
## (debug kapalı, ortam değişkeni kapalı) `dev_allowed()` bayrağına bağlı olduğu için orada doğrudan sınanamaz.

const SecureCfg: GDScript = preload("res://scripts/security/secure_cfg.gd")
const Guard: GDScript = preload("res://scripts/security/security_guard.gd")
const ProtectedInt: GDScript = preload("res://scripts/security/protected_int.gd")
const MetaProgressScript: GDScript = preload("res://scripts/meta_progress.gd")
const RunRecordsScript: GDScript = preload("res://scripts/run_records.gd")
const FragmentPeerScript: GDScript = preload("res://scripts/net/fragment_peer.gd")

const ENC_HEADER: PackedByteArray = [0x47, 0x44, 0x45, 0x43]

var _tmp: String = ""


func _begin(ext: String = "cfg") -> void:
	_tmp = "user://test_security_%d.%s" % [Time.get_ticks_usec(), ext]
	Guard.clear_flags()


func _end() -> void:
	for suffix in ["", ".tmp", ".bak", ".bozuk", ".r"]:
		if FileAccess.file_exists(_tmp + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_tmp + suffix))
	MetaProgressScript.set_path_override("")
	RunRecordsScript.set_path_override("")
	Guard.clear_flags()
	_tmp = ""


func _sample_cfg() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "shards", 321)
	cfg.set_value("meta", "ratio", 0.1)
	cfg.set_value("unlocked", "char", [3, 5])
	cfg.set_value("keys", "ana", 2)
	return cfg


func _is_sealed(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var head: PackedByteArray = f.get_buffer(4)
	f.close()
	return head == ENC_HEADER


## ------------------------------------------------------------------ mühürlü kayıt
func test_sealed_file_roundtrips_and_is_not_plain_text() -> void:
	_begin()
	assert(SecureCfg.save_cfg(_sample_cfg(), _tmp, "meta") == OK, "mühürlü yazım başarılı")
	assert(_is_sealed(_tmp), "dosya şifreli başlıkla başlar (düz ConfigFile değil)")
	assert(not FileAccess.get_file_as_string(_tmp).contains("shards"), "düz metin alan adı dosyada görünmez")
	var res: Dictionary = SecureCfg.load_cfg(_tmp, "meta")
	assert(int(res["status"]) == SecureCfg.Status.OK, "geri okunur")
	var cfg: ConfigFile = res["cfg"]
	assert(int(cfg.get_value("meta", "shards", 0)) == 321 and float(cfg.get_value("meta", "ratio", 0.0)) == 0.1, "değerler aynı")
	assert((cfg.get_value("unlocked", "char", []) as Array) == [3, 5] and int(cfg.get_value("keys", "ana", 0)) == 2)
	assert(not FileAccess.file_exists(_tmp + ".tmp"), "geçici dosya kalmaz (atomik yazım)")
	_end()


func test_missing_file_reports_missing() -> void:
	_begin()
	assert(int(SecureCfg.load_cfg(_tmp, "meta")["status"]) == SecureCfg.Status.MISSING)
	_end()


func test_edited_sealed_file_is_rejected() -> void:
	_begin()
	SecureCfg.save_cfg(_sample_cfg(), _tmp, "meta")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(_tmp)
	assert(bytes.size() > 60)
	bytes[bytes.size() - 20] = bytes[bytes.size() - 20] ^ 0x5a ## tek bayt çevir
	var f := FileAccess.open(_tmp, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()
	assert(int(SecureCfg.load_cfg(_tmp, "meta")["status"]) == SecureCfg.Status.TAMPERED, "değişen mühürlü dosya geçersiz")
	_end()


func test_other_file_kind_key_does_not_open_it() -> void:
	_begin()
	SecureCfg.save_cfg(_sample_cfg(), _tmp, "meta")
	assert(int(SecureCfg.load_cfg(_tmp, "records")["status"]) == SecureCfg.Status.TAMPERED, "records anahtarı meta dosyasını açamaz")
	_end()


func test_plain_legacy_file_is_accepted_in_editor_and_flagged_legacy() -> void:
	_begin()
	var plain := _sample_cfg()
	plain.save(_tmp)
	assert(not _is_sealed(_tmp))
	var res: Dictionary = SecureCfg.load_cfg(_tmp, "meta")
	assert(int(res["status"]) == SecureCfg.Status.LEGACY, "eski düz kayıt: taşıma için LEGACY (editörde süre sınırı yok)")
	assert(int((res["cfg"] as ConfigFile).get_value("meta", "shards", 0)) == 321)
	_end()


func test_real_file_tampered_falls_back_to_backup_and_quarantines() -> void:
	_begin()
	SecureCfg.save_cfg(_sample_cfg(), _tmp, "meta", true) ## ilk yazım (yedek yok)
	var second := _sample_cfg()
	second.set_value("meta", "shards", 400)
	SecureCfg.save_cfg(second, _tmp, "meta", true) ## önceki geçerli dosya .bak olur
	assert(FileAccess.file_exists(_tmp + ".bak"), ".bak yazıldı")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(_tmp)
	bytes[bytes.size() - 20] = bytes[bytes.size() - 20] ^ 0x5a ## geçerli başlık + bozuk içerik (sözdizimi hatası basmadan "elle düzenlenmiş")
	var f := FileAccess.open(_tmp, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()
	var res: Dictionary = SecureCfg.load_cfg(_tmp, "meta", true)
	assert(bool(res["restored"]) and int(res["status"]) == SecureCfg.Status.OK, "son iyi yedeğe dönülür")
	assert(int((res["cfg"] as ConfigFile).get_value("meta", "shards", 0)) == 321, "yedek = ilk yazımdaki değer")
	assert(FileAccess.file_exists(_tmp + ".bozuk") and not FileAccess.file_exists(_tmp), "bozuk dosya kenara alındı")
	_end()


## ------------------------------------------------------------------ meta + rekor gerçekten mühürlü yazar
func test_meta_progress_saves_sealed_and_reloads_from_disk() -> void:
	_begin()
	MetaProgressScript.set_path_override(_tmp)
	var d: Dictionary = MetaProgressScript.load_all()
	d["shards"] = 77
	d["total_earned"] = 77
	MetaProgressScript.commit(d)
	assert(_is_sealed(_tmp), "meta kaydı mühürlü")
	MetaProgressScript.set_path_override(_tmp) ## önbelleği boşalt: gerçekten DOSYADAN okunsun
	assert(MetaProgressScript.shards() == 77, "dosyadan okundu")
	_end()


func test_records_saves_sealed_and_reloads_from_disk() -> void:
	_begin()
	RunRecordsScript.set_path_override(_tmp)
	RunRecordsScript.note_progress({"time": 600.0, "tier": 6, "kills": 120, "layer": 0, "victory": false, "solo": true, "char_id": 1})
	assert(_is_sealed(_tmp), "rekor kaydı mühürlü")
	assert(int(RunRecordsScript.load_all()["best_tier"]) == 6, "dosyadan okundu")
	_end()


func test_tampered_session_does_not_write_progress() -> void:
	_begin()
	MetaProgressScript.set_path_override(_tmp)
	var d: Dictionary = MetaProgressScript.load_all()
	d["shards"] = 10
	d["total_earned"] = 10
	MetaProgressScript.commit(d)
	Guard.report("test hilesi")
	var d2: Dictionary = MetaProgressScript.load_all()
	d2["shards"] = 99999
	d2["total_earned"] = 99999
	MetaProgressScript.commit(d2) ## hileli oturum: yazılmaz
	Guard.clear_flags()
	MetaProgressScript.set_path_override(_tmp)
	assert(MetaProgressScript.shards() == 10, "hile bayrağı varken kıymık yazılmadı")
	RunRecordsScript.set_path_override(_tmp + ".r")
	Guard.report("test hilesi")
	RunRecordsScript.note_progress({"time": 600.0, "tier": 6, "kills": 120, "layer": 0, "victory": false, "solo": true, "char_id": 1})
	Guard.clear_flags()
	assert(not FileAccess.file_exists(_tmp + ".r"), "hile bayrağı varken rekor dosyası yazılmadı")
	_end()


## ------------------------------------------------------------------ korumalı sayı
func test_protected_int_roundtrip_values() -> void:
	_begin()
	var p = ProtectedInt.new("t", 5)
	for v in [0, 1, 5, 999999, -7, 9223372036854775807, -9223372036854775807]:
		p.set_value(v)
		assert(p.get_value() == v, "değer korunur: %d" % v)
	p.set_value(10)
	assert(p.add(5) == 15 and p.get_value() == 15, "add")
	assert(not Guard.tampered, "temiz kullanım bayrak kaldırmaz: %s" % str(Guard.reasons))
	_end()


func test_protected_int_hides_plain_value_and_rekeys_each_write() -> void:
	_begin()
	var p = ProtectedInt.new("t", 1234)
	assert(p._enc != 1234, "bellekte düz değer yok")
	var k1: int = p._key
	p.set_value(1234)
	assert(p._key != k1, "her yazışta anahtar değişir (dondurma/değer tarama işe yaramaz)")
	_end()


func test_protected_int_detects_memory_edit_and_flags_session() -> void:
	_begin()
	var p = ProtectedInt.new("gold_test", 500)
	p._enc = 999999 ## Cheat Engine'in yaptığı: şifreli alana değer yaz
	assert(p.get_value() == 0, "bozulan değer 0'a düşer")
	assert(Guard.tampered and Guard.reasons.size() == 1, "oturum tampered + neden günlüğe: %s" % str(Guard.reasons))
	_end()


func test_game_manager_gold_and_weapon_shards_are_protected_properties() -> void:
	_begin()
	var gm: Node = Engine.get_main_loop().root.get_node("GameManager")
	var old_gold: int = gm.gold
	var old_shards: int = gm.weapon_shards
	gm.gold = 100
	gm.gold += 25
	assert(gm.gold == 125, "altın normal kullanılır")
	gm.weapon_shards = 0
	gm.add_weapon_shards(3)
	assert(gm.weapon_shards == 3, "parçacık ekleme çalışır")
	assert(gm._gold_p._enc != 125, "altının düz kopyası bellekte yok")
	gm.gold = old_gold
	gm.weapon_shards = old_shards
	assert(not Guard.tampered, "gm: %s" % str(Guard.reasons))
	_end()


## ------------------------------------------------------------------ geliştirici kapısı
func test_dev_gate_matches_editor_build_and_env_only_in_editor() -> void:
	assert(Guard.dev_allowed() == OS.has_feature("editor"), "kapı = editör ikilisi")
	OS.set_environment("LS_SEC_TEST", "1")
	assert(Guard.dev_env("LS_SEC_TEST") == ("1" if Guard.dev_allowed() else ""), "ortam değişkeni yalnız editörde okunur")
	OS.unset_environment("LS_SEC_TEST")
	var gm: Node = Engine.get_main_loop().root.get_node("GameManager")
	assert(gm.debug_allowed() == Guard.dev_allowed(), "debug izni kapıyla aynı")


func test_debug_flag_can_only_open_when_dev_allowed() -> void:
	var gm: Node = Engine.get_main_loop().root.get_node("GameManager")
	gm.debug_mode_unlocked = true
	assert(gm.debug_mode_unlocked == Guard.dev_allowed(), "exportta debug bayrağı hiç true olmaz")
	gm.debug_mode_unlocked = false
	assert(not gm.debug_mode_unlocked)


## Madde 741: "Debug Modu" düğmesiyle başlayan oyunda (content_unlock_mode) chat kodu exportta da debug açabilir; kendiliğinden açılmaz.
func test_content_mode_allows_chat_code_debug() -> void:
	var gm: Node = Engine.get_main_loop().root.get_node("GameManager")
	gm.content_unlock_mode = true
	assert(gm.debug_allowed(), "kilit açık modda chat kodu çalışır")
	assert(not gm.debug_mode_unlocked, "debug kendiliğinden açılmaz, kod gerekir")
	gm.content_unlock_mode = false
	assert(gm.debug_allowed() == Guard.dev_allowed(), "mod kapanınca eski kapı")


func test_install_scan_is_silent_in_editor() -> void:
	_begin()
	Guard.scan_install()
	assert(not Guard.tampered, "editörde kurulum taraması bayrak kaldırmaz: %s" % str(Guard.reasons))
	_end()


## ------------------------------------------------------------------ ağ
func test_remote_scene_path_validation() -> void:
	var nm: Node = Engine.get_main_loop().root.get_node("NetworkManager")
	assert(nm._vfx_scene_ok("res://scenes/fx_frost_nova_burst.tscn"), "meşru efekt sahnesi geçer")
	for bad in ["res://scenes/main.tscn", "res://scenes/main_menu.tscn", "res://scenes/harita_baked.tscn", "res://scenes/../project.godot",
			"res://scripts/player.gd", "user://x.tscn", "res://scenes/zindan/x.tscn", "res://scenes/creatures/x.tscn", "", "res://scenes/yok_boyle_bir_sahne.tscn"]:
		assert(not nm._vfx_scene_ok(bad), "reddedilmeli: %s" % bad)


func test_sender_check_passes_offline_and_limits() -> void:
	var nm: Node = Engine.get_main_loop().root.get_node("NetworkManager")
	assert(nm._sender_may_act_for(5), "çevrimdışı/yerel çağrı her zaman geçer")
	assert(nm.MAX_CHAT_LEN > 0 and nm.MAX_CHAT_LEN <= 500 and nm.MAX_NAME_LEN <= 64)


func test_fragment_peer_caps_are_sane() -> void:
	assert(FragmentPeerScript.MAX_FRAGMENTS >= 512 and FragmentPeerScript.MAX_FRAGMENTS <= 8192, "meşru büyük mesaja yeter, bellek şişirmeyi keser")
	assert(FragmentPeerScript.MAX_PARTIALS >= 16)


## ------------------------------------------------------------------ kimlik çalma + bağlantı doğrulaması + hasar sınırları (madde 613, 2. tur)
func _nm() -> Node:
	return Engine.get_main_loop().root.get_node("NetworkManager")


func test_sane_float_helper() -> void:
	var nm: Node = _nm()
	assert(nm._sane_f(NAN, 0.0, 10.0) == 0.0, "NaN -> alt sınır")
	assert(nm._sane_f(INF, 0.0, 10.0) == 10.0, "sonsuz -> üst sınır")
	assert(nm._sane_f(-5.0, 0.0, 10.0) == 0.0, "negatif -> alt sınır")
	assert(nm._sane_f(3.0, 0.0, 10.0) == 3.0, "makul değer aynen")


func test_identity_proof_rules() -> void:
	var nm: Node = _nm()
	var proof: String = ("proof|abc").sha256_text()
	var ver: String = proof.sha256_text()
	assert(nm.identity_proof_ok(proof, ""), "doğrulayıcı yokken ilk kayıt kabul (öğrenilir)")
	assert(nm.identity_proof_ok(proof, ver), "aynı sahibin kanıtı kabul")
	assert(not nm.identity_proof_ok(("proof|baskasi").sha256_text(), ver), "başkasının kanıtı REDDEDİLİR (uid çalma)")
	assert(not nm.identity_proof_ok("", ""), "kanıtsız kayıt reddedilir")
	assert(not nm.identity_proof_ok("zz".repeat(32), ""), "onaltılık olmayan kanıt reddedilir")
	assert(not nm.identity_proof_ok(proof.left(10), ver), "kısa kanıt reddedilir")


func test_host_own_identity_is_always_known() -> void:
	var nm: Node = _nm()
	var p: String = nm.local_player_proof()
	assert(p.length() == 64 and p.is_valid_hex_number(false), "kanıt 64 onaltılık")
	assert(nm._expected_verifier(nm.local_player_uid) == p.sha256_text(), "host'un kendi uid'i için doğrulayıcı hep bilinir (istemci üstlenemez)")
	assert(nm._expected_verifier("baska-kimlik-yok") == "", "bilinmeyen uid: henüz öğrenilmedi")
	assert(not nm.identity_proof_ok(("proof|x").sha256_text(), nm._expected_verifier(nm.local_player_uid)), "host uid'ine yanlış kanıt")


func test_redirect_bond_bookkeeping() -> void:
	var nm: Node = _nm()
	nm.note_redirect_bond(777, 0.5, 5.0)
	assert(nm._redirect_bonds.has(777), "bağ kuruldu")
	nm.note_redirect_bond(777, 0.0, 0.0)
	assert(not nm._redirect_bonds.has(777), "bağ bitti")


func test_unadmitted_gate_is_open_offline() -> void:
	assert(not _nm()._from_unadmitted_peer(), "çevrimdışı / yerel çağrı engellenmez")


## Regresyon bekçisi: host'ta işlenen her any_peer RPC doğrulanmamış eşi reddetmeli (yeni RPC eklerken unutulmasın).
## İstisna: _rpc_auth_response (doğrulamanın kendisi).
func test_every_host_handled_rpc_rejects_unadmitted_peers() -> void:
	var src: PackedStringArray = FileAccess.get_file_as_string("res://scripts/network_manager.gd").split("\n")
	var bad: Array[String] = []
	var checked: int = 0
	var i: int = 0
	while i < src.size():
		if src[i].begins_with("@rpc("):
			var j: int = i + 1
			while j < src.size() and not src[j].begins_with("func "):
				j += 1
			if j >= src.size():
				break
			var fname: String = src[j].substr(5, src[j].find("(") - 5)
			var k: int = j + 1
			while k < src.size() and (src[k].strip_edges() == "" or src[k].strip_edges().begins_with("#")):
				k += 1
			var first: String = src[k].strip_edges() if k < src.size() else ""
			if first.begins_with("if not is_host") and fname != "_rpc_auth_response":
				checked += 1
				if not first.contains("_from_unadmitted_peer()"):
					bad.append(fname)
			i = j
		i += 1
	assert(checked >= 25, "taranan host RPC sayısı beklenenden az: %d" % checked)
	assert(bad.is_empty(), "doğrulanmamış eş kontrolü eksik: %s" % str(bad))
