extends Node
class_name VoxelInteractionHandler
## Обробляє взаємодію з вокселями: копання, будівництво, візуальні індикатори

enum InteractionMode {
	NORMAL,     # Звичайний режим (видалити/поставити один блок)
	CREATIVE    # Режим копання/будівництва з динамічною областю
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


func _ready() -> void:
	# Отримати посилання на контролери
	if voxdot_controller_path:
		voxdot_controller = get_node_or_null(voxdot_controller_path)
	if camera_path:
		camera = get_node_or_null(camera_path)

	# Створити візуальні індикатори
	_create_preview_meshes()


func _create_preview_meshes() -> void:
	# Preview для копання (червоний куб)
	dig_preview = MeshInstance3D.new()
	dig_preview.visible = false

	var dig_material = StandardMaterial3D.new()
	dig_material.albedo_color = Color(1.0, 0.2, 0.2, 0.4)  # Напівпрозорий червоний
	dig_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dig_preview.material_override = dig_material
	add_child(dig_preview)

	# Preview для будівництва (зелений куб)
	build_preview = MeshInstance3D.new()
	build_preview.visible = false

	var build_material = StandardMaterial3D.new()
	build_material.albedo_color = Color(0.2, 1.0, 0.2, 0.4)  # Напівпрозорий зелений
	build_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	build_preview.material_override = build_material
	add_child(build_preview)


func _update_preview_visibility() -> void:
	var show_previews = (interaction_mode == InteractionMode.CREATIVE)
	dig_preview.visible = show_previews
	build_preview.visible = show_previews


func _update_preview_size() -> void:
	var voxel_scale = voxdot_controller.voxel_scale if voxdot_controller else 0.1

	match current_tool:
		ToolType.HANDS:
			# Для рук - маленький куб
			_update_preview_mesh(BoxMesh.new(), Vector3(voxel_scale, voxel_scale, voxel_scale))

		ToolType.SHOVEL:
			# Для лопати - плоский прямокутник
			_update_preview_mesh(BoxMesh.new(), Vector3(dig_radius * 2, voxel_scale * 0.5, dig_radius * 2))

		ToolType.PICKAXE:
			# Для кирки - вертикальний прямокутник
			_update_preview_mesh(BoxMesh.new(), Vector3(voxel_scale * 0.8, dig_radius * 2, voxel_scale * 0.8))


func _update_preview_mesh(mesh_type: Mesh, size: Vector3) -> void:
	if dig_preview:
		dig_preview.mesh = mesh_type.duplicate()
		if dig_preview.mesh is BoxMesh:
			var box_mesh: BoxMesh = dig_preview.mesh as BoxMesh
			box_mesh.size = size

	if build_preview:
		build_preview.mesh = mesh_type.duplicate()
		if build_preview.mesh is BoxMesh:
			var box_mesh: BoxMesh = build_preview.mesh as BoxMesh
			box_mesh.size = size


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

	# Показувати обидва preview в creative режимі
	if interaction_mode == InteractionMode.CREATIVE:
		dig_preview.global_position = hit_pos - hit_normal * 0.1
		build_preview.global_position = hit_pos + hit_normal * 0.1


func handle_input(event: InputEvent) -> void:
	# Обробка клавіш
	if event is InputEventKey and event.pressed:
		# B - перемикання creative режиму
		if event.keycode == KEY_B:
			interaction_mode = InteractionMode.CREATIVE if interaction_mode == InteractionMode.NORMAL else InteractionMode.NORMAL
			print("Switched to %s mode" % ("CREATIVE" if interaction_mode == InteractionMode.CREATIVE else "NORMAL"))
			_update_preview_visibility()

		# 1-3 - перемикання інструментів
		elif event.keycode == KEY_1:
			current_tool = ToolType.HANDS
			dig_radius = 0.3
			print("Selected HANDS tool")
			_update_preview_size()
		elif event.keycode == KEY_2:
			current_tool = ToolType.SHOVEL
			dig_radius = 0.8
			print("Selected SHOVEL tool")
			_update_preview_size()
		elif event.keycode == KEY_3:
			current_tool = ToolType.PICKAXE
			dig_radius = 1.2
			print("Selected PICKAXE tool")
			_update_preview_size()

	# Прокрутка миші - зміна розміру області
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and interaction_mode == InteractionMode.CREATIVE:
			dig_radius = min(dig_radius + 0.1, 3.0)  # Максимум 3.0
			print("Area radius increased to: %.1f" % dig_radius)
			_update_preview_size()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and interaction_mode == InteractionMode.CREATIVE:
			var min_radius = 0.1
			match current_tool:
				ToolType.HANDS: min_radius = 0.1
				ToolType.SHOVEL: min_radius = 0.5
				ToolType.PICKAXE: min_radius = 0.8
			dig_radius = max(dig_radius - 0.1, min_radius)
			print("Area radius decreased to: %.1f" % dig_radius)
			_update_preview_size()


func handle_mouse_button(button: int) -> void:
	print("VoxelInteractionHandler: handle_mouse_button called with button ", button)
	if not voxdot_controller or not camera:
		print("VoxelInteractionHandler: voxdot_controller or camera is null")
		return

	if not is_inside_tree():
		print("VoxelInteractionHandler: not in scene tree")
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

	match button:
		MOUSE_BUTTON_LEFT:
			if interaction_mode == InteractionMode.CREATIVE:
				# Creative режим - копати з динамічною областю залежно від інструменту
				_dig_area(hit_pos - hit_normal * 0.1, hit_normal)
			else:
				# Звичайний режим - малий радіус
				print("VoxelInteractionHandler: Calling remove_voxel on controller")
				voxdot_controller.remove_voxel(hit_pos - hit_normal * 0.1, 0.2)
				print("Removed voxel at: ", hit_pos)

		MOUSE_BUTTON_RIGHT:
			if interaction_mode == InteractionMode.CREATIVE:
				# Creative режим - будувати з динамічною областю
				_build_area(hit_pos + hit_normal * 0.1, hit_normal)
			else:
				# Звичайний режим
				print("VoxelInteractionHandler: Calling place_voxel on controller")
				voxdot_controller.place_voxel(hit_pos + hit_normal * 0.1, 2)
				print("Placed voxel at: ", hit_pos + hit_normal * 0.1)

		MOUSE_BUTTON_MIDDLE:
			# Повністю знищити сферу (як було)
			print("VoxelInteractionHandler: Calling place_sphere on controller")
			voxdot_controller.place_sphere(hit_pos, 1.0, 0)
			print("Destroyed sphere at: ", hit_pos)


func _dig_area(center_pos: Vector3, normal: Vector3) -> void:
	## Копати область залежно від інструменту
	var voxel_scale = voxdot_controller.voxel_scale if voxdot_controller else 0.1

	match current_tool:
		ToolType.HANDS:
			# Руки - видалити один воксель
			voxdot_controller.remove_voxel(center_pos, voxel_scale * 0.5)
			print("Hands: Removed single voxel at: ", center_pos)

		ToolType.SHOVEL:
			# Лопата - плоска область паралельно поверхні
			var area_size = Vector3(dig_radius * 2, voxel_scale * 0.5, dig_radius * 2)
			voxdot_controller.place_cube(center_pos, area_size, 0)  # 0 = видалити
			print("Shovel: Removed flat area at: ", center_pos, " size: ", area_size)

		ToolType.PICKAXE:
			# Кирка - вертикальна область
			var depth = dig_radius * 2
			var area_size = Vector3(voxel_scale * 0.8, depth, voxel_scale * 0.8)
			voxdot_controller.place_cube(center_pos, area_size, 0)  # 0 = видалити
			print("Pickaxe: Removed vertical area at: ", center_pos, " size: ", area_size)


func _build_area(center_pos: Vector3, normal: Vector3) -> void:
	## Будувати область залежно від інструменту
	var voxel_scale = voxdot_controller.voxel_scale if voxdot_controller else 0.1

	match current_tool:
		ToolType.HANDS:
			# Руки - поставити один воксель
			voxdot_controller.place_voxel(center_pos, 2)
			print("Hands: Placed single voxel at: ", center_pos)

		ToolType.SHOVEL:
			# Лопата - заповнити плоску область
			var area_size = Vector3(dig_radius * 2, voxel_scale * 0.5, dig_radius * 2)
			voxdot_controller.place_cube(center_pos, area_size, 2)
			print("Shovel: Built flat area at: ", center_pos, " size: ", area_size)

		ToolType.PICKAXE:
			# Кирка - будувати вертикальну стіну
			var height = dig_radius * 2
			var area_size = Vector3(voxel_scale * 0.8, height, voxel_scale * 0.8)
			voxdot_controller.place_cube(center_pos, area_size, 2)
			print("Pickaxe: Built vertical wall at: ", center_pos, " size: ", area_size)


func _physics_process(_delta: float) -> void:
	# Оновити позицію preview індикаторів
	_update_preview_position()
