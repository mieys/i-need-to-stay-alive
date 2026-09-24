extends RefCounted

## Fizik interpolasyonu (project.godot physics/common/physics_interpolation=true).
## Kullanıcı bildirimi: "hareket ettiğimde sanki kamera fpsi düşük şekilde takip ediyor da
## o yüzden harita kasıyor gibi görünüyor". Kök neden: project.godot'taki ayar satırına bir
## yorum karışmıştı, interpolasyon HİÇ açık olmamıştı. Oyuncu (ve ona bağlı Camera2D) sadece
## 60 Hz fizik adımlarında yer değiştiriyor, ekran vsync kapalıyken çok daha sık çiziliyordu
## -> kamera kesik kesik. Ölçüm (gerçek girdiyle yürüme, çizim başına kamera hızının
## değişkenlik katsayısı): kapalı 2.06, açık 0.21.
##
## NEDEN "kökte KAPALI, sadece seçilenler AÇIK": interpolasyon AÇIK bir düğüm _process'te
## (ya da varsayılan idle Tween'le) hareket ettirilirse titrer; bu projede onlarca FX/pet/
## düşen eşya _process'te hareket ediyor. Kök KAPALI olunca dokunulmayan her şey BUGÜNKÜ
## gibi davranır; sadece _physics_process'te hareket eden ana varlıklar (oyuncu + kamera +
## silahlar, uzak oyuncular, yaratıklar, mermiler) opt_in ile açılır.
##
## Yeni bir şey EKLERKEN:
##  - _physics_process'te hareket eden, dünyada serbest (top_level ya da sahne kökünde)
##    bir görsel -> _ready'de PhysicsInterp.opt_in(self) çağır.
##  - opt_in'li bir düğüme ÇOCUK eklenirse otomatik KAPALI olur (ebeveynin akıcı konumunu
##    izler, kendi yerel hareketi olduğu gibi kalır) - ekstra bir şey gerekmez.
##  - opt_in'li bir düğümü IŞINLIYORSAN (ev giriş/çıkışı gibi) konumu verdikten sonra
##    reset_physics_interpolation() çağır, yoksa bir kare boyunca eski yerden kayar.
##  - opt_in eklenen düğüm add_child'dan SONRA konumlansa bile sorun yok: opt_in ertelenmiş
##    bir reset yapar (ölçüldü: aksi halde ilk karelerde (0,0)'dan hedefe kayarak görünüyordu).

static func setup_root(tree: SceneTree) -> void:
	tree.root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


## node'u interpolasyona alır. Mevcut VE sonradan eklenecek doğrudan çocuklarını KAPALI
## yapar; keep_on(child) true dönen çocuklar AÇIK kalır (ör. oyuncunun Camera2D'si).
static func opt_in(node: Node, keep_on: Callable = Callable()) -> void:
	node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	for c: Node in node.get_children():
		_apply_child(c, keep_on)
	node.child_entered_tree.connect(func(c: Node) -> void: _apply_child(c, keep_on))
	node.reset_physics_interpolation.call_deferred()


## _process'te bir opt_in varlığına YAPIŞAN (onun global_position'ını her karede kopyalayan)
## görseller için: varlığın EKRANDA çizildiği interpolasyonlu konum. Ham global_position
## fizik adımının sonundaki konumdur, çizilen ise bir önceki adımla arasındadır - ham konuma
## yapışan bir aura/hasar sayısı varlığa göre 60 Hz'de 1-3 px titrer. Varlığın kendi
## _physics_process'inin EN BAŞINDA _interp_prev_pos/_interp_prev_frame'i doldurması gerekir
## (player.gd / remote_player.gd / enemy.gd); doldurmayan düğümde ham konum döner.
static func visual_position(n: Node2D) -> Vector2:
	var cur: Vector2 = n.global_position
	if not n.is_physics_interpolated_and_enabled() or not ("_interp_prev_pos" in n):
		return cur
	if int(n.get("_interp_prev_frame")) != Engine.get_physics_frames():
		return cur ## bu adımda fizik işlenmedi (ör. kapalı) - önceki konum bayat
	var prev: Vector2 = n.get("_interp_prev_pos")
	if prev.distance_squared_to(cur) > 64.0 * 64.0:
		return cur ## ışınlama
	return prev.lerp(cur, Engine.get_physics_interpolation_fraction())


static func _apply_child(c: Node, keep_on: Callable) -> void:
	if keep_on.is_valid() and bool(keep_on.call(c)):
		c.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	else:
		c.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
