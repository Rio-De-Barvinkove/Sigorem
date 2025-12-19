extends Node
class_name VoxelInteractionHandler
## Обробляє взаємодію з вокселями: копання, будівництво, візуальні індикатори

enum InteractionMode {
	NORMAL,     # Звичайний режим - тільки руйнування/копання
	CREATIVE    # Creative режим - тільки будівництво
}

enum ToolType {
	HANDS,      # Руки - малий радіус
	SHOVEL,     # Лопата - середній радіус
	PICKAXE     # Кирка - великий радіус
}

@export var voxdot_controller_path: NodePath
@export var camera_path: NodePath

var voxdot_controller: VoxdotController
var camera: Camera3D
var interaction_mode: InteractionMode = InteractionMode.NORMAL
var current_tool: ToolType = ToolType.HANDS
var dig_radius_voxels: int = 0  # Радіус копання в voxel units (0 = один воксель)

# Візуальні індикатори для preview областей
var dig_preview: MeshInstance3D
var build_preview: MeshInstance3D

# VoxelTool для raycast (якщо доступний)
var _voxel_tool = null


func _ready() -> void:
	# Отримати посилання на контролери
	if voxdot_controller_path:
		voxdot_controller = get_node_or_null(voxdot_controller_path)
	if camera_path:
		camera = get_node_or_null(camera_path)

	# Спробувати отримати VoxelTool з terrain (як в референсі)
	if voxdot_controller and voxdot_controller.terrain:
		var terrain = voxdot_controller.terrain
		if terrain.has_method("get_voxel_tool"):
			_voxel_tool = terrain.get_voxel_tool()
			if _voxel_tool:
				print("VoxelInteractionHandler: VoxelTool отримано! Клас: ", _voxel_tool.get_class())
			else:
				print("VoxelInteractionHandler: get_voxel_tool повернув null")
		else:
			print("VoxelInteractionHandler: terrain не має методу get_voxel_tool")

	# Створити візуальні індикатори
	_create_preview_meshes()
	_update_preview_size()


func _create_preview_meshes() -> void:
	# Preview для копання (wireframe outline)
	dig_preview = MeshInstance3D.new()
	dig_preview.visible = false
	var dig_material = StandardMaterial3D.new()
	dig_material.albedo_color = Color.BLACK
	dig_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dig_material.no_depth_test = true  # Outline має бути видимий поверх всього
	dig_preview.material_override = dig_material
	add_child(dig_preview)

	# Preview для будівництва (wireframe outline)
	build_preview = MeshInstance3D.new()
	build_preview.visible = false
	var build_material = StandardMaterial3D.new()
	build_material.albedo_color = Color.WHITE
	build_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	build_material.no_depth_test = true
	build_preview.material_override = build_material
	add_child(build_preview)


func _update_preview_visibility() -> void:
	# Preview керується в _update_preview_position() залежно від режиму
	# Функція залишається для сумісності
	pass


func _create_wireframe_mesh(size: Vector3) -> ArrayMesh:
	## Створити wireframe mesh для outline (чорні лінії по краях куба)
	var arr_mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var half_size = size * 0.5
	
	# Нижня грань (4 лінії)
	vertices.append(Vector3(-half_size.x, -half_size.y, -half_size.z))
	vertices.append(Vector3(half_size.x, -half_size.y, -half_size.z))
	vertices.append(Vector3(half_size.x, -half_size.y, -half_size.z))
	vertices.append(Vector3(half_size.x, -half_size.y, half_size.z))
	vertices.append(Vector3(half_size.x, -half_size.y, half_size.z))
	vertices.append(Vector3(-half_size.x, -half_size.y, half_size.z))
	vertices.append(Vector3(-half_size.x, -half_size.y, half_size.z))
	vertices.append(Vector3(-half_size.x, -half_size.y, -half_size.z))
	
	# Верхня грань (4 лінії)
	vertices.append(Vector3(-half_size.x, half_size.y, -half_size.z))
	vertices.append(Vector3(half_size.x, half_size.y, -half_size.z))
	vertices.append(Vector3(half_size.x, half_size.y, -half_size.z))
	vertices.append(Vector3(half_size.x, half_size.y, half_size.z))
	vertices.append(Vector3(half_size.x, half_size.y, half_size.z))
	vertices.append(Vector3(-half_size.x, half_size.y, half_size.z))
	vertices.append(Vector3(-half_size.x, half_size.y, half_size.z))
	vertices.append(Vector3(-half_size.x, half_size.y, -half_size.z))
	
	# Вертикальні лінії (4 лінії)
	vertices.append(Vector3(-half_size.x, -half_size.y, -half_size.z))
	vertices.append(Vector3(-half_size.x, half_size.y, -half_size.z))
	vertices.append(Vector3(half_size.x, -half_size.y, -half_size.z))
	vertices.append(Vector3(half_size.x, half_size.y, -half_size.z))
	vertices.append(Vector3(half_size.x, -half_size.y, half_size.z))
	vertices.append(Vector3(half_size.x, half_size.y, half_size.z))
	vertices.append(Vector3(-half_size.x, -half_size.y, half_size.z))
	vertices.append(Vector3(-half_size.x, half_size.y, half_size.z))
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return arr_mesh


func _update_preview_size() -> void:
	if not voxdot_controller:
		return
	var voxel_scale = voxdot_controller.voxel_scale
	var single_voxel_size = Vector3(voxel_scale, voxel_scale, voxel_scale)

	if interaction_mode == InteractionMode.NORMAL:
		# NORMAL режим - preview показує кубічну область копання розміром (2*radius_voxels + 1)^3
		# Центр preview співпадає з центром центрального вокселя (center_index)
		var preview_diameter = dig_radius_voxels * 2 + 1  # Наприклад: radius=2 -> 5x5x5
		var preview_size = Vector3(preview_diameter, preview_diameter, preview_diameter) * voxel_scale
		dig_preview.mesh = _create_wireframe_mesh(preview_size)
		build_preview.mesh = _create_wireframe_mesh(single_voxel_size)
	else:
		# CREATIVE режим - завжди один воксель (1x1x1) для обох preview
		build_preview.mesh = _create_wireframe_mesh(single_voxel_size)
		dig_preview.mesh = _create_wireframe_mesh(single_voxel_size)


func voxel_index_to_world_center(voxel_index: Vector3) -> Vector3:
	## Перетворити voxel index в center вокселя в world space
	## Формула: (index + 0.5) * scale дає центр вокселя з індексом index
	## Наприклад: index (0,0,0) -> center (0.5*scale, 0.5*scale, 0.5*scale)
	if not voxdot_controller:
		return voxel_index
	var scale := voxdot_controller.voxel_scale
	return (voxel_index + Vector3.ONE * 0.5) * scale




func _voxel_raycast(max_distance: float = 100.0) -> Variant:
	## Raycast у voxel grid через VoxelTool
	## Повертає voxel index (Vector3) або null якщо немає попадання
	if not _voxel_tool or not camera or not voxdot_controller:
		return null

	var voxel_scale = voxdot_controller.voxel_scale

	# КРИТИЧНО: VoxelTool.raycast() працює у voxel space, не world space
	# Конвертуємо world координати у voxel space перед raycast
	var from_voxel = camera.global_position / voxel_scale
	var dir_voxel = (-camera.global_basis.z).normalized()

	var hit = _voxel_tool.raycast(from_voxel, dir_voxel, max_distance / voxel_scale)
	if hit == null or not hit.has("position"):
		return null

	return hit.position.floor()  # Voxel index вже у voxel space


func _update_preview_position() -> void:
	if not voxdot_controller or not camera:
		return

	if not is_inside_tree():
		return

	# Raycast - отримуємо voxel index або null
	var voxel_index = _voxel_raycast()
	if voxel_index == null:
		dig_preview.visible = false
		build_preview.visible = false
		return

	# Конвертуємо voxel index в world center
	var center = voxel_index_to_world_center(voxel_index)

	# NORMAL режим - preview для копання
	if interaction_mode == InteractionMode.NORMAL:
		dig_preview.global_position = center
		dig_preview.visible = true
		build_preview.visible = false

	# CREATIVE режим - preview для будівництва (той самий voxel, бо це preview)
	else:
		build_preview.global_position = center
		build_preview.visible = true
		dig_preview.visible = false


func handle_input(event: InputEvent) -> void:
	# Обробка клавіш
	if event is InputEventKey and event.pressed:
		# B - перемикання Build mode (CREATIVE режим для будівництва)
		if event.keycode == KEY_B:
			interaction_mode = InteractionMode.CREATIVE if interaction_mode == InteractionMode.NORMAL else InteractionMode.NORMAL
			var mode_name = "BUILD MODE (ON) - будівництво" if interaction_mode == InteractionMode.CREATIVE else "NORMAL MODE - руйнування/копання"
			print("VoxelInteractionHandler: ", mode_name)
			_update_preview_size()

		# 1-3 - перемикання інструментів для руйнування (тільки в NORMAL режимі)
		elif event.keycode == KEY_1 and interaction_mode == InteractionMode.NORMAL:
			current_tool = ToolType.HANDS
			dig_radius_voxels = 0  # Один воксель
			_update_preview_size()
		elif event.keycode == KEY_2 and interaction_mode == InteractionMode.NORMAL:
			current_tool = ToolType.SHOVEL
			dig_radius_voxels = 2  # 5x5x5 voxel cube
			_update_preview_size()
		elif event.keycode == KEY_3 and interaction_mode == InteractionMode.NORMAL:
			current_tool = ToolType.PICKAXE
			dig_radius_voxels = 3  # 7x7x7 voxel cube
			_update_preview_size()

	# Прокрутка миші - зміна розміру області для руйнування (тільки в NORMAL режимі)
	if event is InputEventMouseButton and event.pressed and interaction_mode == InteractionMode.NORMAL:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			dig_radius_voxels = min(dig_radius_voxels + 1, 5)  # Максимум 5 voxel
			_update_preview_size()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var min_radius = 0  # Дозволяємо 0 для одного вокселя
			match current_tool:
				ToolType.HANDS: min_radius = 0    # Один воксель
				ToolType.SHOVEL: min_radius = 1   # Мінімум 3x3x3
				ToolType.PICKAXE: min_radius = 2  # Мінімум 5x5x5
			dig_radius_voxels = max(dig_radius_voxels - 1, min_radius)
			_update_preview_size()


func handle_mouse_button(button: int) -> void:
	if not voxdot_controller or not camera:
		return

	if not is_inside_tree():
		return

	# Raycast - отримуємо voxel index або null
	var voxel_index = _voxel_raycast()
	if voxel_index == null:
		return

	# Конвертуємо voxel index в world center
	var center = voxel_index_to_world_center(voxel_index)

	match interaction_mode:
		InteractionMode.NORMAL:
			# NORMAL режим - кубічне копання (ЛКМ) в області (2*dig_radius_voxels + 1)^3 вокселів
			if button == MOUSE_BUTTON_LEFT:
				_dig_area(voxel_index)

		InteractionMode.CREATIVE:
			# CREATIVE режим - копання/будівництво по одному вокселю
			if button == MOUSE_BUTTON_LEFT:
				# Копання одного вокселя
				voxdot_controller.remove_voxel(center)
				# Обробити dirty chunks після видалення
				if voxdot_controller.terrain and voxdot_controller.terrain.has_method("process_dirty_chunks"):
					voxdot_controller.terrain.process_dirty_chunks(voxdot_controller.chunks_per_frame, true)

			elif button == MOUSE_BUTTON_RIGHT:
				# Будівництво одного вокселя
				voxdot_controller.place_voxel(center, 2)
				# Обробити dirty chunks після додавання
				if voxdot_controller.terrain and voxdot_controller.terrain.has_method("process_dirty_chunks"):
					voxdot_controller.terrain.process_dirty_chunks(voxdot_controller.chunks_per_frame, true)

func _dig_area(center_index: Vector3) -> void:
	## Кубічне копання: видаляє вокселі в області (2*radius_voxels + 1)^3 навколо center_index
	## Наприклад: radius_voxels=0 -> 1x1x1, radius_voxels=1 -> 3x3x3, radius_voxels=2 -> 5x5x5
	var voxel_scale = voxdot_controller.voxel_scale

	# Видаляємо вокселі в кубічній області навколо center_index
	var removed_count = 0
	for x in range(-dig_radius_voxels, dig_radius_voxels + 1):
		for y in range(-dig_radius_voxels, dig_radius_voxels + 1):
			for z in range(-dig_radius_voxels, dig_radius_voxels + 1):
				var target_index = center_index + Vector3(x, y, z)
				# Конвертуємо voxel index в world center для Voxdot API
				var target_center = voxel_index_to_world_center(target_index)
				voxdot_controller.remove_voxel(target_center)
				removed_count += 1

	# Обробити dirty chunks після всіх видалень
	if removed_count > 0 and voxdot_controller.terrain and voxdot_controller.terrain.has_method("process_dirty_chunks"):
		voxdot_controller.terrain.process_dirty_chunks(voxdot_controller.chunks_per_frame, true)




func _physics_process(_delta: float) -> void:
	# Оновити позицію preview індикаторів
	_update_preview_position()
