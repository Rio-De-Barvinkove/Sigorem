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
		# NORMAL режим - preview розмір залежить від dig_radius
		var preview_size = Vector3(dig_radius * 2.0, dig_radius * 2.0, dig_radius * 2.0)
		dig_preview.mesh = _create_wireframe_mesh(preview_size)
		build_preview.mesh = _create_wireframe_mesh(single_voxel_size)
	else:
		# CREATIVE режим - завжди один воксель (1x1x1) для обох preview
		build_preview.mesh = _create_wireframe_mesh(single_voxel_size)
		dig_preview.mesh = _create_wireframe_mesh(single_voxel_size)


func voxel_index_to_world_center(voxel_index: Vector3) -> Vector3:
	## Перетворити цілочисельний voxel index в центр вокселя в world space
	## Формула: (voxel_index + 0.5) * voxel_scale
	## КРИТИЧНО: voxel_index має бути цілочисельним (після floor())
	if not voxdot_controller:
		return voxel_index
	var scale := voxdot_controller.voxel_scale
	return (voxel_index + Vector3(0.5, 0.5, 0.5)) * scale


func world_pos_to_voxel_center(world_pos: Vector3) -> Vector3:
	## Перетворити світову позицію в центр найближчого вокселя
	## 1. Знайти індекс вокселя: floor(world_pos / voxel_scale)
	## 2. Перетворити індекс в центр вокселя
	if not voxdot_controller:
		return world_pos
	var voxel_scale = voxdot_controller.voxel_scale
	var voxel_index = (world_pos / voxel_scale).floor()
	return voxel_index_to_world_center(voxel_index)


func _snap_to_voxel_center(pos: Vector3, voxel_scale: float) -> Vector3:
	## Допоміжна функція для ідеального вирівнювання по сітці вокселів
	## Використовується для гарантованого позиціонування в центрі вокселя
	## 1. Ділимо на масштаб, щоб отримати індекс (наприклад 1.55 -> 15.5)
	var idx_x = floor(pos.x / voxel_scale)
	var idx_y = floor(pos.y / voxel_scale)
	var idx_z = floor(pos.z / voxel_scale)
	
	# 2. Повертаємо координати центру цього індексу
	# Центр вокселя [15, 0, 0] це (15 * 0.1) + (0.1 / 2) = 1.55
	var center_offset = voxel_scale * 0.5
	
	return Vector3(
		idx_x * voxel_scale + center_offset,
		idx_y * voxel_scale + center_offset,
		idx_z * voxel_scale + center_offset
	)


func _voxel_raycast(max_distance: float = 100.0) -> Dictionary:
	## Raycast у voxel grid або через фізичний raycast як fallback
	## Повертає Dictionary з:
	## - 'position' (voxel index або world_pos залежно від джерела)
	## - 'world_pos' (world position для точного зсуву)
	## - 'normal' (для будівництва)
	## КРИТИЧНО: якщо 'position' це voxel_index, використовувати безпосередньо, інакше використовувати 'world_pos'
	if not camera or not voxdot_controller:
		return {}
	
	var from = camera.global_position
	var dir = -camera.global_basis.z.normalized()
	var to = from + dir * max_distance
	
	# Спочатку пробуємо через VoxelTool (якщо доступний)
	if _voxel_tool != null and _voxel_tool.has_method("raycast"):
		var hit = _voxel_tool.raycast(from, dir, max_distance)
		if hit != null and typeof(hit) == TYPE_DICTIONARY and hit.has("position"):
			# Перевіряємо наявність normal, якщо відсутня - переходимо до fallback
			if not hit.has("normal") or hit.get("normal", Vector3.ZERO).length() < 0.001:
				# Normal відсутня, переходимо до fallback
				pass
			else:
				# VoxelTool повертає voxel_index, додаємо world_pos для зсуву
				var voxel_index = hit.position
				if typeof(voxel_index) == TYPE_VECTOR3:
					var world_pos = voxel_index_to_world_center(voxel_index)
					hit["world_pos"] = world_pos
				return hit
	
	# Fallback: фізичний raycast через mesh (для сумісності)
	var space_state = get_viewport().world_3d.direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result.is_empty():
		return {}
	
	# Конвертуємо world position в voxel index
	var hit_pos: Vector3 = result.position
	var hit_normal: Vector3 = result.normal.normalized()
	var voxel_scale = voxdot_controller.voxel_scale
	
	# Якщо normal невалідна, обчислюємо fallback normal з напрямку камери
	if hit_normal.length() < 0.001:
		# Використовуємо напрямок від камери до точки попадання як fallback
		var cam_to_hit = (hit_pos - from).normalized()
		hit_normal = -cam_to_hit
	
	# КРИТИЧНО: Зсуваємо всередину вокселя для правильного визначення індексу
	# Використовуємо дуже малий offset (0.01) щоб гарантовано потрапити в правильний воксель
	var offset_dist = voxel_scale * 0.01
	var point_inside = hit_pos - (hit_normal * offset_dist)
	
	# Обчислюємо voxel index через floor
	var voxel_index = (point_inside / voxel_scale).floor()
	
	return {
		"position": voxel_index,
		"world_pos": hit_pos,  # Зберігаємо world_pos для зсуву
		"normal": hit_normal
	}


func _update_preview_position() -> void:
	if not voxdot_controller or not camera:
		return

	if not is_inside_tree():
		return

	# Raycast у voxel grid замість mesh
	var hit = _voxel_raycast()
	if hit.is_empty() or not hit.has("position"):
		dig_preview.visible = false
		build_preview.visible = false
		return

	# Отримуємо world_pos та normal для точного позиціонування
	var hit_pos: Vector3
	var hit_normal: Vector3
	var voxel_scale = voxdot_controller.voxel_scale
	
	if hit.has("world_pos"):
		hit_pos = hit.world_pos
	else:
		# Якщо world_pos відсутня, використовуємо voxel_index
		var voxel_index: Vector3 = hit.position.floor()
		hit_pos = voxel_index_to_world_center(voxel_index)
	
	if hit.has("normal") and hit.normal.length() > 0.001:
		hit_normal = hit.normal.normalized()
	else:
		hit_normal = (camera.global_position - hit_pos).normalized()

	# NORMAL режим - показувати preview для копання з правильним зсувом
	if interaction_mode == InteractionMode.NORMAL:
		# Зсуваємо всередину для точного копання
		var dig_pos = hit_pos - hit_normal * (voxel_scale * 0.2)
		var dig_voxel_center = world_pos_to_voxel_center(dig_pos)
		dig_preview.global_position = dig_voxel_center
		dig_preview.visible = true
		build_preview.visible = false
	# CREATIVE режим - показувати preview для будівництва з правильним зсувом
	else:
		# Зсуваємо назовні для будівництва
		var build_pos = hit_pos + hit_normal * (voxel_scale * 1.1)
		var build_voxel_center = world_pos_to_voxel_center(build_pos)
		build_preview.global_position = build_voxel_center
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

	# Raycast у voxel grid замість mesh
	var hit = _voxel_raycast()
	if hit.is_empty() or not hit.has("position"):
		return

	# hit.position - це позиція в voxel space, але може бути float (наприклад 12.99998)
	# КРИТИЧНО: потрібно floor() для отримання цілочисельного індексу
	var voxel_index: Vector3 = hit.position.floor()
	
	# Потрібно перетворити в центр вокселя в world space
	# voxel_index_to_world_center() вже дає правильний центр, подвійне snap не потрібно
	var voxel_center = voxel_index_to_world_center(voxel_index)

	match interaction_mode:
		InteractionMode.NORMAL:
			# NORMAL режим - тільки копання/руйнування (ЛКМ) з радіусом dig_radius
			if button == MOUSE_BUTTON_LEFT:
				# Отримуємо world_pos для зсуву (якщо доступний)
				var hit_pos: Vector3
				var hit_normal: Vector3
				if hit.has("world_pos"):
					hit_pos = hit.world_pos
				else:
					# Якщо world_pos відсутня, використовуємо voxel_center як наближення
					hit_pos = voxel_center
				
				if hit.has("normal") and hit.normal.length() > 0.001:
					hit_normal = hit.normal.normalized()
				else:
					# Fallback normal
					hit_normal = (camera.global_position - hit_pos).normalized()
				
				_dig_area(hit_pos, hit_normal)
		
		InteractionMode.CREATIVE:
			# CREATIVE режим - руйнування/будівництва по одному вокселю
			if button == MOUSE_BUTTON_LEFT:
				# Руйнування одного вокселя (LMB в CREATIVE)
				# КРИТИЧНО: зсуваємо всередину для точного копання
				var hit_pos: Vector3
				var hit_normal: Vector3
				var voxel_scale = voxdot_controller.voxel_scale
				
				if hit.has("world_pos"):
					hit_pos = hit.world_pos
				else:
					hit_pos = voxel_center
				
				if hit.has("normal") and hit.normal.length() > 0.001:
					hit_normal = hit.normal.normalized()
				else:
					hit_normal = (camera.global_position - hit_pos).normalized()
				
				# Зсуваємо всередину для точного копання
				var dig_pos = hit_pos - hit_normal * (voxel_scale * 0.2)
				var dig_voxel_center = world_pos_to_voxel_center(dig_pos)
				voxdot_controller.remove_voxel(dig_voxel_center)
				
			elif button == MOUSE_BUTTON_RIGHT:
				# Будівництво одного вокселя (RMB в CREATIVE)
				# КРИТИЧНО: для будівництва потрібен сусідній порожній воксель
				# Зсуваємо назовні для правильного будівництва
				var hit_pos: Vector3
				var hit_normal: Vector3
				var voxel_scale = voxdot_controller.voxel_scale
				
				if hit.has("world_pos"):
					hit_pos = hit.world_pos
				else:
					hit_pos = voxel_center
				
				if hit.has("normal") and hit.normal.length() > 0.001:
					hit_normal = hit.normal.normalized()
				else:
					hit_normal = (camera.global_position - hit_pos).normalized()
				
				# Зсуваємо назовні для будівництва
				var build_pos = hit_pos + hit_normal * (voxel_scale * 1.1)
				var build_voxel_center = world_pos_to_voxel_center(build_pos)
				voxdot_controller.place_voxel(build_voxel_center, 2)


func _dig_area(center_pos: Vector3, normal: Vector3) -> void:
	## Копати область з радіусом dig_radius в NORMAL режимі
	## Видаляє вокселі в сферичній області навколо center_pos
	## КРИТИЧНО: зсуваємо всередину для точного копання перед визначенням центру області
	var voxel_scale = voxdot_controller.voxel_scale
	
	# Зсуваємо всередину для точного копання
	var dig_pos = center_pos - normal * (voxel_scale * 0.2)
	
	# Визначаємо центр області копання
	var center_voxel_center = world_pos_to_voxel_center(dig_pos)
	var center_index = (dig_pos / voxel_scale).floor()
	
	# Радіус в вокселях
	var radius_voxels = int(ceil(dig_radius / voxel_scale))
	
	# Видаляємо вокселі в сферичній області
	for x in range(-radius_voxels, radius_voxels + 1):
		for y in range(-radius_voxels, radius_voxels + 1):
			for z in range(-radius_voxels, radius_voxels + 1):
				var offset = Vector3(x, y, z)
				
				# Перевірка відстані (сферична область)
				var dist = offset.length() * voxel_scale
				if dist <= dig_radius:
					var target_index = center_index + offset
					var target_center = voxel_index_to_world_center(target_index)
					voxdot_controller.remove_voxel(target_center)


func _build_area(center_pos: Vector3, normal: Vector3) -> void:
	## Будувати - завжди ставити 1 воксель
	voxdot_controller.place_voxel(center_pos, 2)


func _physics_process(_delta: float) -> void:
	# Оновити позицію preview індикаторів
	_update_preview_position()
