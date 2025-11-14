extends Node
# Остаточний реєстр блоків (на базі простої реалізації)

signal block_registered(block_id: String)
signal blocks_loaded()

var blocks = {}
var block_mesh_library: MeshLibrary = null
var id_to_mesh_index = {}
var next_mesh_index = 0

func _ready():
	block_mesh_library = MeshLibrary.new()
	_load_default_blocks()

func _load_default_blocks():
	_create_simple_block("grass", Color(0.4, 0.8, 0.2))
	_create_simple_block("dirt", Color(0.55, 0.27, 0.07))
	_create_simple_block("stone", Color(0.5, 0.5, 0.5))
	emit_signal("blocks_loaded")

func _create_simple_block(block_id: String, color: Color):
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1, 1, 1)  # Розмір блоку точно 1x1x1
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	material.metallic = 0.0
	mesh.material = material
	var shape = BoxShape3D.new()
	shape.size = Vector3(1, 1, 1)  # Колізія теж 1x1x1
	block_mesh_library.create_item(next_mesh_index)
	block_mesh_library.set_item_name(next_mesh_index, block_id.capitalize() + " Block")
	block_mesh_library.set_item_mesh(next_mesh_index, mesh)
	block_mesh_library.set_item_shapes(next_mesh_index, [shape, Transform3D.IDENTITY])
	# Примітка: Тіні контролюються через world.tscn (mesh_cast_shadow = 0)
	id_to_mesh_index[block_id] = next_mesh_index
	blocks[block_id] = {"id": block_id}
	print("Created block: ", block_id, " with index: ", next_mesh_index)
	next_mesh_index += 1

func get_mesh_library() -> MeshLibrary:
	return block_mesh_library

func get_mesh_index(block_id: String) -> int:
	return id_to_mesh_index.get(block_id, -1)
