extends RefCounted

## Efekt shader ısıtma (madde 215): mermi izi / totem ateş topu / Melek R halkası shader'ları ilk kez çizildiği karede boru hattı
## derlemesi yüzünden takılma (ölçüm: ilk Melek R'de ~190 ms) yapıyordu. Oyun sahnesi açılırken her shader'ı neredeyse görünmez,
## ekran köşesinde tek örnekle birkaç kare çizeriz; sonra silinir. class_name yok (preload ile kullanılır).

const TrailShader := preload("res://shaders/particle_trail.gdshader")
const BoltShader := preload("res://shaders/totem_bolt.gdshader")
const RingShader := preload("res://shaders/melek_holy_ring.gdshader")
const TrailSheet := preload("res://assets/fx/projectile_trails/arcane_c_sheet.png")


static func run(host: Node) -> void:
	if host == null or not host.is_inside_tree():
		return
	var layer := CanvasLayer.new()
	layer.layer = 100
	var root := Node2D.new()
	root.modulate = Color(1, 1, 1, 0.01)
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(root)
	var quad := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(4, 4), Vector2(0, 4)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	for sh in [TrailShader, BoltShader]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_custom_data = true
		mm.mesh = quad
		mm.instance_count = 1
		mm.set_instance_transform_2d(0, Transform2D(0.0, Vector2(2, 2)))
		mm.set_instance_custom_data(0, Color(0, 0, 0, 0))
		var mmi := MultiMeshInstance2D.new()
		mmi.multimesh = mm
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mmi.material = mat
		if sh == TrailShader:
			mmi.texture = TrailSheet
		root.add_child(mmi)
	var ring := Node2D.new()
	var ring_mat := ShaderMaterial.new()
	ring_mat.shader = RingShader
	ring_mat.set_shader_parameter("radius1", 2.0)
	ring.material = ring_mat
	ring.draw.connect(func() -> void: ring.draw_rect(Rect2(0, 0, 4, 4), Color.WHITE))
	root.add_child(ring)
	host.add_child(layer)
	host.get_tree().create_timer(0.5).timeout.connect(layer.queue_free)
