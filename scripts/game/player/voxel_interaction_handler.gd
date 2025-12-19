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

# Константи для конфігурації
const MAX_DIG_RADIUS_VOXELS = 5
const SURFACE_OFFSET_EPSILON = 0.001
const PREVIEW_LINE_WIDTH = 2.0

# Мінімальні радіуси для кожного інструменту
const TOOL_MIN_RADIUSES = {
	ToolType.HANDS: 0,
	ToolType.SHOVEL: 1,
	ToolType.PICKAXE: 2
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

# Оптимізація preview оновлення (тимчасово відключена)
var _last_camera_position: Vector3
var _preview_update_frame_skip = 2  # Оновлювати preview кожні 3 кадри
var _frame_counter = 0


func _ready() -> void:
	# Отримати посилання на контролери з перевірками
	voxdot_controller = get_node_or_null(voxdot_controller_path) if voxdot_controller_path else null
	camera = get_node_or_null(camera_path) if camera_path else null

	if not voxdot_controller:
		push_warning("VoxelInteractionHandler: voxdot_controller не знайдено за шляхом: " + str(voxdot_controller_path))
		return

	if not camera:
		push_warning("VoxelInteractionHandler: camera не знайдена за шляхом: " + str(camera_path))
		return

	# Спробувати отримати VoxelTool з terrain
	if voxdot_controller.terrain and voxdot_controller.terrain.has_method("get_voxel_tool"):
		_voxel_tool = voxdot_controller.terrain.get_voxel_tool()
		if _voxel_tool:
			print("VoxelInteractionHandler: VoxelTool отримано успішно")
		else:
			push_warning("VoxelInteractionHandler: get_voxel_tool повернув null")

	# DEBUG: Перевірити ініціалізацію
	print("_voxel_tool:", _voxel_tool)
	print("voxdot_controller:", voxdot_controller)
	print("camera:", camera)

	# Ініціалізувати оптимізацію preview
	if camera:
		_last_camera_position = camera.global_position

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
	## Створити wireframe mesh для outline куба через цикли для скорочення коду
	var arr_mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var half_size = size * 0.5

	# Кубічні ребра: 12 ребер, кожне з 2 вершинами
	var edges = [
		# Нижня грань (Y = -half_size.y)
		[Vector3(-1, -1, -1), Vector3(1, -1, -1)],
		[Vector3(1, -1, -1), Vector3(1, -1, 1)],
		[Vector3(1, -1, 1), Vector3(-1, -1, 1)],
		[Vector3(-1, -1, 1), Vector3(-1, -1, -1)],
		# Верхня грань (Y = half_size.y)
		[Vector3(-1, 1, -1), Vector3(1, 1, -1)],
		[Vector3(1, 1, -1), Vector3(1, 1, 1)],
		[Vector3(1, 1, 1), Vector3(-1, 1, 1)],
		[Vector3(-1, 1, 1), Vector3(-1, 1, -1)],
		# Вертикальні ребра
		[Vector3(-1, -1, -1), Vector3(-1, 1, -1)],
		[Vector3(1, -1, -1), Vector3(1, 1, -1)],
		[Vector3(1, -1, 1), Vector3(1, 1, 1)],
		[Vector3(-1, -1, 1), Vector3(-1, 1, 1)]
	]

	for edge in edges:
		vertices.append(edge[0] * half_size)
		vertices.append(edge[1] * half_size)

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices

	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return arr_mesh


func _update_preview_size() -> void:
	if not voxdot_controller or not dig_preview or not build_preview:
		return

	var voxel_scale = voxdot_controller.voxel_scale
	var single_voxel_size = Vector3(voxel_scale, voxel_scale, voxel_scale)

	if interaction_mode == InteractionMode.NORMAL:
		# NORMAL режим - preview показує кубічну область копання розміром (2*radius_voxels + 1)^3
		var preview_diameter = dig_radius_voxels * 2 + 1
		var preview_size = Vector3(preview_diameter, preview_diameter, preview_diameter) * voxel_scale
		dig_preview.mesh = _create_wireframe_mesh(preview_size)
		build_preview.mesh = _create_wireframe_mesh(single_voxel_size)
	else:
		# CREATIVE режим - завжди один воксель (1x1x1) для обох preview
		var creative_size = Vector3(voxel_scale, voxel_scale, voxel_scale)
		dig_preview.mesh = _create_wireframe_mesh(creative_size)
		build_preview.mesh = _create_wireframe_mesh(creative_size)


func voxel_index_to_world_center(voxel_index: Vector3) -> Vector3:
	## Перетворити voxel index в center вокселя в world space
	## Формула: (index + 0.5) * scale дає центр вокселя з індексом index
	if not voxdot_controller:
		push_error("VoxelInteractionHandler: voxdot_controller is null in voxel_index_to_world_center")
		return voxel_index

	var scale := voxdot_controller.voxel_scale
	if scale <= 0:
		push_error("VoxelInteractionHandler: invalid voxel_scale: " + str(scale))
		return voxel_index

	return (voxel_index + Vector3.ONE * 0.5) * scale




func _voxel_raycast(max_distance: float = 100.0) -> Variant:
	## Raycast у voxel grid через VoxelTool
	## Повертає словник з 'position' (voxel_index) або null якщо немає попадання
	if not _voxel_tool or not camera or not voxdot_controller:
		return null

	var voxel_scale = voxdot_controller.voxel_scale

	# КРИТИЧНО: VoxelTool.raycast() працює у voxel space, не world space
	# Конвертуємо world координати у voxel space перед raycast
	var from_voxel = camera.global_position / voxel_scale
	var dir_voxel = -camera.global_transform.basis.z.normalized()  # Використовуємо transform замість basis

	var hit = _voxel_tool.raycast(from_voxel, dir_voxel, max_distance / voxel_scale)
	if hit == null:
		return null
	if not hit.has("position") or not hit.has("normal"):
		return null

	# КЛЮЧ: hit.position лежить на грані вокселя
	# Зсуваємо всередину поверхні вздовж нормалі на відстань пропорційну voxel_scale
	var surface_offset = SURFACE_OFFSET_EPSILON * voxel_scale
	var hit_pos = hit.position - hit.normal * surface_offset
	var voxel_index = hit_pos.floor()

	return {
		"position": voxel_index,  # Voxel index (головний результат)
		"normal": hit.normal      # Surface normal (для preview)
	}


func _update_preview_position() -> void:
	if not voxdot_controller or not camera:
		return

	if not is_inside_tree():
		return

	# Raycast - отримуємо voxel index або null
	var hit = _voxel_raycast()
	if hit == null or not hit.has("position"):
		dig_preview.visible = false
		build_preview.visible = false
		return

	var voxel_index = hit.position

	# Конвертуємо voxel index в world center
	var center = voxel_index_to_world_center(voxel_index)
	if center == voxel_index:
		dig_preview.visible = false
		build_preview.visible = false
		return

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
			dig_radius_voxels = min(dig_radius_voxels + 1, MAX_DIG_RADIUS_VOXELS)
			_update_preview_size()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var min_radius = TOOL_MIN_RADIUSES.get(current_tool, 0)
			dig_radius_voxels = max(dig_radius_voxels - 1, min_radius)
			_update_preview_size()


func handle_mouse_button(button: int) -> void:
	if not voxdot_controller or not camera:
		return

	if not is_inside_tree():
		return

	# Raycast - отримуємо voxel index або null
	var hit = _voxel_raycast()
	if hit == null or not hit.has("position"):
		return

	var voxel_index = hit.position

	# Конвертуємо voxel index в world center
	var center = voxel_index_to_world_center(voxel_index)
	if center == voxel_index:
		return

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
	if not voxdot_controller or not voxdot_controller.terrain:
		return

	var voxel_scale = voxdot_controller.voxel_scale

	# Видаляємо вокселі в кубічній області навколо center_index
	# TODO: Для великих радіусів можна оптимізувати через batch-операції VoxelTool замість окремих викликів
	var removed_count = 0
	for x in range(-dig_radius_voxels, dig_radius_voxels + 1):
		for y in range(-dig_radius_voxels, dig_radius_voxels + 1):
			for z in range(-dig_radius_voxels, dig_radius_voxels + 1):
				var target_index = center_index + Vector3(x, y, z)
				# Конвертуємо voxel index в world center для Voxdot API
				var target_center = voxel_index_to_world_center(target_index)
				if target_center != target_index:  # Перевірка що конвертація вдалася
					voxdot_controller.remove_voxel(target_center)
					removed_count += 1

	# Обробити dirty chunks після всіх видалень
	if removed_count > 0 and voxdot_controller.terrain.has_method("process_dirty_chunks"):
		var chunks_per_frame = voxdot_controller.chunks_per_frame if voxdot_controller.chunks_per_frame > 0 else 1
		voxdot_controller.terrain.process_dirty_chunks(chunks_per_frame, true)




func _physics_process(_delta: float) -> void:
	# Оновити позицію preview індикаторів
	_update_preview_position()
