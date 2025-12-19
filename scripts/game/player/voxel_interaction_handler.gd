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
var dig_radius: float = 0.3  # Динамічний радіус копання

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
				# Налаштувати channel як в референсі
				if _voxel_tool.has_method("set") and _voxel_tool.has("channel"):
					_voxel_tool.set("channel", 0)  # VoxelBuffer.CHANNEL_TYPE = 0
			else:
				print("VoxelInteractionHandler: get_voxel_tool повернув null")
		else:
			print("VoxelInteractionHandler: terrain не має методу get_voxel_tool")

	# Створити візуальні індикатори
	_create_preview_meshes()


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
	var voxel_scale = voxdot_controller.voxel_scale if voxdot_controller else 0.1
	# Розмір одного вокселя (відповідає remove_voxel/place_voxel)
	var single_voxel_size = Vector3(voxel_scale, voxel_scale, voxel_scale)

	# Для руйнування (NORMAL режим) - один воксель
	dig_preview.mesh = _create_wireframe_mesh(single_voxel_size)

	# Для будівництва (CREATIVE режим) - один воксель
	build_preview.mesh = _create_wireframe_mesh(single_voxel_size)


func _get_targeted_voxel_position(hit_pos: Vector3, hit_normal: Vector3, is_digging: bool) -> Vector3:
	## Отримати точну позицію центру одного вокселя
	## КРИТИЧНО: Використовуємо floor + 0.5 для точної центровки по сітці
	##
	## Для одного вокселя: half_size = voxel_scale * 0.5, повний розмір = voxel_scale
	## Центр має бути точно в центрі вокселя
	## Формула: offset → floor → +0.5 → * voxel_scale (центр вокселя)
	if not voxdot_controller:
		return hit_pos
	
	var voxel_scale = voxdot_controller.voxel_scale
	var normal = hit_normal.normalized()
	
	# Обчислюємо offset залежно від напрямку
	var offset: Vector3
	if is_digging:
		# Для копання: зсуваємо всередину на 20% вокселя для надійності
		offset = -normal * voxel_scale * 0.2
	else:
		# Для будівництва: зсуваємо назовні на 1 воксель + 10% запасу
		offset = normal * voxel_scale * 1.1
	
	# ОБОВ'ЯЗКОВО: floor для вирівнювання по сітці
	var adjusted = hit_pos + offset
	var voxel_index = (adjusted / voxel_scale).floor()
	
	# Для одного вокселя: центр = (voxel_index + 0.5) * voxel_scale
	# Це ставить центр точно в центр вокселя
	return (voxel_index + Vector3(0.5, 0.5, 0.5)) * voxel_scale


func _update_preview_position() -> void:
	if not voxdot_controller or not camera:
		return

	if not is_inside_tree():
		return

	var from = camera.global_position
	var to = from - camera.global_basis.z * 100.0

	var space_state = get_viewport().world_3d.direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)

	if result.is_empty():
		dig_preview.visible = false
		build_preview.visible = false
		return

	var hit_pos: Vector3 = result.position
	var hit_normal: Vector3 = result.normal

	# NORMAL режим - показувати preview тільки для руйнування (чорний outline)
	if interaction_mode == InteractionMode.NORMAL:
		var dig_voxel_pos = _get_targeted_voxel_position(hit_pos, hit_normal, true)
		dig_preview.global_position = dig_voxel_pos
		dig_preview.visible = true
		build_preview.visible = false
	# CREATIVE режим - показувати preview тільки для будівництва (білий outline)
	elif interaction_mode == InteractionMode.CREATIVE:
		var build_voxel_pos = _get_targeted_voxel_position(hit_pos, hit_normal, false)
		build_preview.global_position = build_voxel_pos
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
			_update_preview_visibility()

		# 1-3 - перемикання інструментів для руйнування (тільки в NORMAL режимі)
		elif event.keycode == KEY_1 and interaction_mode == InteractionMode.NORMAL:
			current_tool = ToolType.HANDS
			dig_radius = 0.3
			_update_preview_size()
		elif event.keycode == KEY_2 and interaction_mode == InteractionMode.NORMAL:
			current_tool = ToolType.SHOVEL
			dig_radius = 0.8
			_update_preview_size()
		elif event.keycode == KEY_3 and interaction_mode == InteractionMode.NORMAL:
			current_tool = ToolType.PICKAXE
			dig_radius = 1.2
			_update_preview_size()

	# Прокрутка миші - зміна розміру області для руйнування (тільки в NORMAL режимі)
	if event is InputEventMouseButton and event.pressed and interaction_mode == InteractionMode.NORMAL:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			dig_radius = min(dig_radius + 0.1, 3.0)  # Максимум 3.0
			_update_preview_size()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var min_radius = 0.1
			match current_tool:
				ToolType.HANDS: min_radius = 0.1
				ToolType.SHOVEL: min_radius = 0.5
				ToolType.PICKAXE: min_radius = 0.8
			dig_radius = max(dig_radius - 0.1, min_radius)
			_update_preview_size()


func handle_mouse_button(button: int) -> void:
	if not voxdot_controller or not camera:
		return

	if not is_inside_tree():
		return

	var from = camera.global_position
	var to = from - camera.global_basis.z * 100.0

	var space_state = get_viewport().world_3d.direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	if result.is_empty():
		return

	var hit_pos: Vector3 = result.position
	var hit_normal: Vector3 = result.normal

	match interaction_mode:
		InteractionMode.NORMAL:
			# NORMAL режим - тільки копання/руйнування (ЛКМ) - завжди один воксель
			if button == MOUSE_BUTTON_LEFT:
				var dig_voxel_pos = _get_targeted_voxel_position(hit_pos, hit_normal, true)
				_dig_area(dig_voxel_pos, hit_normal)
		
		InteractionMode.CREATIVE:
			# CREATIVE режим - руйнування/будівництва по одному вокселю
			if button == MOUSE_BUTTON_LEFT:
				# Руйнування одного вокселя (LMB в CREATIVE)
				var dig_voxel_pos = _get_targeted_voxel_position(hit_pos, hit_normal, true)
				voxdot_controller.remove_voxel(dig_voxel_pos)
			elif button == MOUSE_BUTTON_RIGHT:
				# Будівництво одного вокселя (RMB в CREATIVE)
				var build_voxel_pos = _get_targeted_voxel_position(hit_pos, hit_normal, false)
				voxdot_controller.place_voxel(build_voxel_pos, 2)


func _dig_area(center_pos: Vector3, normal: Vector3) -> void:
	## Копати - завжди видалити точно один воксель (NORMAL режим)
	## Усі інструменти (HANDS, SHOVEL, PICKAXE) видаляють один воксель
	## Для великих областей використовується CREATIVE режим
	voxdot_controller.remove_voxel(center_pos)


func _build_area(center_pos: Vector3, normal: Vector3) -> void:
	## Будувати - завжди ставити 1 воксель
	voxdot_controller.place_voxel(center_pos, 2)


func _physics_process(_delta: float) -> void:
	# Оновити позицію preview індикаторів
	_update_preview_position()
