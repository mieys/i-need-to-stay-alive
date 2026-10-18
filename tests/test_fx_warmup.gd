extends Node

## Efekt ısıtma (scripts/fx_warmup.gd) - FPS turu (2026-10-18): ilk kullanımda diskten okunan kaynakların oyun açılırken yüklenip TUTULMASI.
## Liste scripts/fx_warmup_list.gd (tools/gen_fx_warmup_list.ps1 üretir); bu test listenin bayatlamadığını (silinen/adı değişen kaynak) ve adımlayıcının çalıştığını sınar.

const FxWarmupScript := preload("res://scripts/fx_warmup.gd")
const WarmListScript := preload("res://scripts/fx_warmup_list.gd")


func test_every_listed_resource_exists() -> void:
	var missing: Array[String] = []
	for p in WarmListScript.PATHS:
		if not ResourceLoader.exists(p):
			missing.append(p)
	assert(missing.is_empty(), "fx_warmup_list.gd'de olmayan kaynaklar var (tools/gen_fx_warmup_list.ps1 ile yeniden üret): %s" % str(missing.slice(0, 5)))
	assert(WarmListScript.PATHS.size() > 50, "liste boş gibi: %d" % WarmListScript.PATHS.size())


func test_extra_shader_files_are_shaders() -> void:
	var n: int = 0
	for p in FxWarmupScript.EXTRA_SHADERS:
		if not ResourceLoader.exists(p):
			continue ## henüz içe aktarılmamış / kaldırılmış olabilir: ısıtma atlar
		assert(load(p) is Shader, "%s bir Shader olmalı" % p)
		n += 1
	assert(n >= 5, "ısıtılacak shader dosyası çok az: %d" % n)


func test_background_warmup_loads_and_holds_every_resource_then_stops() -> void:
	var tree: SceneTree = get_tree()
	FxWarmupScript._start_background_warmup(tree)
	assert(FxWarmupScript._stepper.is_valid(), "adımlayıcı kurulmalı")
	var guard: int = 0
	while FxWarmupScript._stepper.is_valid() and guard < 4000:
		FxWarmupScript._step(tree) ## process_frame'i beklemeden elle ilerlet
		guard += 1
	assert(not FxWarmupScript._stepper.is_valid(), "iş bitince adımlayıcı kapanmalı")
	assert(FxWarmupScript._next_path >= WarmListScript.PATHS.size())
	assert(FxWarmupScript._held.size() >= WarmListScript.PATHS.size() - 3, "yüklenen kaynaklar TUTULMALI: %d / %d" % [FxWarmupScript._held.size(), WarmListScript.PATHS.size()])
	for r in FxWarmupScript._held:
		assert(r != null)
	## tutulan kaynak önbellekte kalır: yeniden load() aynı nesneyi verir (diskten okumaz)
	var probe: String = WarmListScript.PATHS[0]
	assert(load(probe) == load(probe))
	## ikinci başlatma (oyun yeniden başlayınca) iş kalmadığı için bir şey kurmaz
	FxWarmupScript._start_background_warmup(tree)
	assert(not FxWarmupScript._stepper.is_valid())
