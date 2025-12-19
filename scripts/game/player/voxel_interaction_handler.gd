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

# Використовуємо physics raycast для voxel targeting (Voxdot не має VoxelTool)

# Для оптимізації та дебагу
var _last_hit_info: Dictionary = {}
var _debug_mode: bool = false  # Ввімкнути DEBUG спам клавішею F12


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

	# Створити візуальні індикатори
	_create_preview_meshes()
	_update_preview_size()


func _create_preview_meshes() -> void:
	# Preview для копання (wireframe outline) - ЧЕРВОНИЙ
	dig_preview = MeshInstance3D.new()
	dig_preview.visible = false
	var dig_material = StandardMaterial3D.new()
	dig_material.albedo_color = Color(1.0, 0.0, 0.0, 0.7)  # Червоний з прозорістю
	dig_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dig_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dig_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	dig_preview.material_override = dig_material
	add_child(dig_preview)

	# Preview для будівництва (wireframe outline) - ЗЕЛЕНИЙ
	build_preview = MeshInstance3D.new()
	build_preview.visible = false
	var build_material = StandardMaterial3D.new()
	build_material.albedo_color = Color(0.0, 1.0, 0.0, 0.7)  # Зелений з прозорістю
	build_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	build_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	build_material.cull_mode = BaseMaterial3D.CULL_DISABLED
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


func _quantize_normal(normal: Vector3) -> Vector3:
	## Квантувати нормаль до найближчої осі (X, Y, або Z)
	var abs_n = normal.abs()
	var qn: Vector3

	if abs_n.x > abs_n.y and abs_n.x > abs_n.z:
		qn = Vector3(sign(normal.x), 0, 0)
	elif abs_n.y > abs_n.z:
		qn = Vector3(0, sign(normal.y), 0)
	else:
		qn = Vector3(0, 0, sign(normal.z))

	return qn




func _physics_raycast(max_distance: float = 100.0) -> Dictionary:
	## Physics raycast для voxel targeting через меш Voxdot
	## Voxdot не має власного raycast API, використовуємо physics raycast з surface offset
	if not camera or not voxdot_controller or not get_viewport() or not get_viewport().world_3d:
		return {}

	var from = camera.global_position
	var dir = -camera.global_transform.basis.z.normalized()
	var to = from + dir * max_distance

	var space_state = get_viewport().world_3d.direct_space_state
	if not space_state:
		return {}

	var query = PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to
	query.collision_mask = 1  # Основна collision mask
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var result = space_state.intersect_ray(query)
	return result


func _voxel_raycast(max_distance: float = 100.0) -> Variant:
	## Перетворює physics raycast в voxel targeting з РІЗНИМИ зсувами для копання/будівництва
	var hit = _physics_raycast(max_distance)
	if hit.is_empty():
		return null

	var hit_pos: Vector3 = hit.position
	var hit_normal: Vector3 = hit.normal.normalized()
	var voxel_scale = voxdot_controller.voxel_scale

	# КРИТИЧНО ВАЖЛИВО: РІЗНІ ЗСУВИ для копання та будівництва (згідно з аналізом API)
	var dig_pos = hit_pos - hit_normal * (voxel_scale * 0.2)      # Копання: всередину
	var build_pos = hit_pos + hit_normal * (voxel_scale * 1.1)    # Будівництво: назовні

	var dig_index = (dig_pos / voxel_scale).floor()
	var build_index = (build_pos / voxel_scale).floor()

	var quantized_normal = _quantize_normal(hit_normal)

	return {
		"dig_position": dig_index,       # Для копання
		"build_position": build_index,   # Для будівництва
		"normal": hit_normal,            # Оригінальна нормаль
		"quantized_normal": quantized_normal,  # Квантована нормаль
		"world_hit": hit_pos,            # Оригінальна позиція удару
		"raw_hit": hit                   # Сирий результат raycast
	}


func _update_preview_position() -> void:
	if not voxdot_controller or not camera:
		return

	if not is_inside_tree():
		return

	# Raycast
	var hit = _voxel_raycast()
	if hit == null:
		dig_preview.visible = false
		build_preview.visible = false
		return

	# Оновлюємо останню інформацію про hit для оптимізації
	_last_hit_info = hit

	if interaction_mode == InteractionMode.NORMAL:
		# NORMAL режим - показуємо preview для копання (червоний)
		var dig_center = voxel_index_to_world_center(hit.dig_position)
		dig_preview.global_position = dig_center
		dig_preview.visible = true
		build_preview.visible = false

	else:  # CREATIVE режим
		# CREATIVE режим - показуємо ОБИДВА preview
		# Червоний - для копання (в поточному вокселі)
		var dig_center = voxel_index_to_world_center(hit.dig_position)
		dig_preview.global_position = dig_center
		dig_preview.visible = true

		# Зелений - для будівництва (в сусідньому вокселі)
		var build_center = voxel_index_to_world_center(hit.build_position)
		build_preview.global_position = build_center
		build_preview.visible = true


func handle_input(event: InputEvent) -> void:
	# Обробка клавіш
	if event is InputEventKey and event.pressed:
		# F12 - перемикання дебаг режиму
		if event.keycode == KEY_F12:
			_debug_mode = not _debug_mode
			print("VoxelInteractionHandler: DEBUG режим", "ВВІМКНЕНО" if _debug_mode else "ВИМКНЕНО")

		# B - перемикання Build mode (CREATIVE режим для будівництва)
		elif event.keycode == KEY_B:
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

	# Якщо немає збереженої інформації про hit, робимо новий raycast
	if _last_hit_info.is_empty():
		_last_hit_info = _voxel_raycast()
		if _last_hit_info == null:
			return

	match interaction_mode:
		InteractionMode.NORMAL:
			# NORMAL режим - кубічне копання (ЛКМ)
			if button == MOUSE_BUTTON_LEFT:
				print("VoxelInteractionHandler: Копання області радіусом ", dig_radius_voxels)
				_dig_area(_last_hit_info.dig_position)

				# ДЕБАГ ІНФО для NORMAL режиму
				if _debug_mode:
					print("=== ДЕБАГ ІНФО NORMAL ===")
					print("Радіус копання:", dig_radius_voxels)
					print("Центр копання (voxel index):", _last_hit_info.dig_position if _last_hit_info.has("dig_position") else "N/A")
					print("Центр копання (world center):", voxel_index_to_world_center(_last_hit_info.dig_position) if _last_hit_info.has("dig_position") else "N/A")
					print("Voxel scale:", voxdot_controller.voxel_scale if voxdot_controller else "N/A")

		InteractionMode.CREATIVE:
			# CREATIVE режим - копання/будівництво по одному вокселю
			if button == MOUSE_BUTTON_LEFT:
				# Копання одного вокселя
				var dig_center = voxel_index_to_world_center(_last_hit_info.dig_position)
				print("VoxelInteractionHandler: Видалення вокселя в ", dig_center)
				if _debug_mode:
					print("VoxelInteractionHandler: Відправлено команду для вокселя: позиція=", dig_center, " матеріал=AIR_MATERIAL (255)")
				voxdot_controller.remove_voxel(dig_center)

			elif button == MOUSE_BUTTON_RIGHT:
				# Будівництво одного вокселя
				var build_center = voxel_index_to_world_center(_last_hit_info.build_position)
				print("VoxelInteractionHandler: Будівництво вокселя в ", build_center)
				if _debug_mode:
					print("VoxelInteractionHandler: Відправлено команду для вокселя: позиція=", build_center, " матеріал=", 2)
				voxdot_controller.place_voxel(build_center, 2)

	# Обробити dirty chunks один раз після всієї операції
	if voxdot_controller.terrain and voxdot_controller.terrain.has_method("process_dirty_chunks"):
		voxdot_controller.terrain.process_dirty_chunks(voxdot_controller.chunks_per_frame, true)

	# ДЕБАГ ІНФО
	if _debug_mode:
		print("=== ДЕБАГ ІНФО ===")
		print("Режим:", "CREATIVE" if interaction_mode == InteractionMode.CREATIVE else "NORMAL")
		print("Кнопка:", "ЛКМ" if button == MOUSE_BUTTON_LEFT else "ПКМ")
		print("Позиція копання:", _last_hit_info.dig_position if _last_hit_info.has("dig_position") else "N/A")
		print("Позиція будівництва:", _last_hit_info.build_position if _last_hit_info.has("build_position") else "N/A")
		print("VoxdotController:", "OK" if voxdot_controller else "NULL")
		print("Terrain:", "OK" if voxdot_controller and voxdot_controller.terrain else "NULL")

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

				voxdot_controller.remove_voxel(target_center)  # ПЕРЕДАЄМО WORLD CENTER!
				if _debug_mode:
					print("VoxelInteractionHandler: Відправлено команду для вокселя: позиція=", target_center, " матеріал=AIR_MATERIAL (255)")
				removed_count += 1

	# Обробити dirty chunks після всіх видалень
	if removed_count > 0 and voxdot_controller.terrain.has_method("process_dirty_chunks"):
		var chunks_per_frame = voxdot_controller.chunks_per_frame if voxdot_controller.chunks_per_frame > 0 else 1
		voxdot_controller.terrain.process_dirty_chunks(chunks_per_frame, true)




func _physics_process(_delta: float) -> void:
	# Оновити позицію preview індикаторів
	_update_preview_position()
