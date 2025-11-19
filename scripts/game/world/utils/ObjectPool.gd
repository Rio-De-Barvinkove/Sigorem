extends Node
class_name ObjectPool

# Memory Pooling - reuse objects замість new/delete
# Оптимізує створення часто використовуваних об'єктів

@export var max_pool_size := 100
@export var preload_count := 10  # Скільки об'єктів створити завчасно

var object_pools = {}  # scene_path -> pool array
var pool_stats = {}    # scene_path -> {"created": int, "reused": int, "active": int}

func _ready():
	# Можна додати автопопереднє завантаження популярних об'єктів
	pass

func get_object(scene_path: String, parent: Node = null) -> Node:
	"""Отримати об'єкт з пулу або створити новий"""
	if not object_pools.has(scene_path):
		object_pools[scene_path] = []
		pool_stats[scene_path] = {"created": 0, "reused": 0, "active": 0}

	var pool = object_pools[scene_path]
	var stats = pool_stats[scene_path]

	# Спробувати взяти з пулу
	if pool.size() > 0:
		var obj = pool.pop_back()
		stats["reused"] += 1
		stats["active"] += 1

		# Перезавантажити об'єкт
		_reset_object(obj)

		if parent:
			parent.add_child(obj)

		return obj

	# Створити новий об'єкт
	var obj = _create_object(scene_path)
	if obj:
		stats["created"] += 1
		stats["active"] += 1
	else:
		return null

	if parent:
		parent.add_child(obj)

	return obj

func return_object(obj: Node):
	"""Повернути об'єкт в пул"""
	if not obj:
		return

	var scene_path = _get_scene_path_from_object(obj)
	if not object_pools.has(scene_path):
		object_pools[scene_path] = []
		pool_stats[scene_path] = {"created": 0, "reused": 0, "active": 0}

	var pool = object_pools[scene_path]
	var stats = pool_stats[scene_path]

	# Перевірити розмір пулу
	if pool.size() >= max_pool_size:
		# Пул переповнений - видалити об'єкт
		obj.queue_free()
		return

	# Повернути в пул
	var parent := obj.get_parent()
	if parent:
		parent.remove_child(obj)
	pool.append(obj)
	stats["active"] -= 1

	# Деактивувати об'єкт
	_deactivate_object(obj)

func _create_object(scene_path: String) -> Node:
	"""Створити новий об'єкт"""
	var scene = load(scene_path)
	if scene:
		var instance = scene.instantiate()
		instance.set_meta("pool_scene_path", scene_path)
		return instance
	else:
		push_error("ObjectPool: Не вдалося завантажити сцену: " + scene_path)
		return null

func _reset_object(obj: Node):
	"""Перезавантажити об'єкт для повторного використання"""
	# Скинути позицію, ротацію, масштаб тільки для Node3D
	if obj is Node3D:
		var n3d := obj as Node3D
		n3d.position = Vector3.ZERO
		n3d.rotation = Vector3.ZERO
		n3d.scale = Vector3.ONE
		n3d.visible = true

	# Повернути процесинг
	obj.process_mode = Node.PROCESS_MODE_INHERIT

	# Викликати метод reset якщо він є
	if obj.has_method("reset"):
		obj.reset()

func _deactivate_object(obj: Node):
	"""Деактивувати об'єкт перед поверненням в пул"""
	# Приховати
	if obj is Node3D:
		obj.visible = false

	# Вимкнути процесинг
	obj.process_mode = Node.PROCESS_MODE_DISABLED

func _get_scene_path_from_object(obj: Node) -> String:
	"""Отримати шлях до сцени з об'єкта"""
	# Спробувати отримати з метаданих
	if obj.has_meta("pool_scene_path"):
		return obj.get_meta("pool_scene_path")

	# Спробувати визначити по імені файлу (спрощено)
	var scene_file = obj.scene_file_path
	if scene_file:
		return scene_file

	# Fallback - використовувати ім'я класу
	return obj.get_class()

func preload_objects(scene_path: String, count: int):
	"""Попередньо створити об'єкти для пулу"""
	if count <= 0:
		return

	if not object_pools.has(scene_path):
		object_pools[scene_path] = []
		pool_stats[scene_path] = {"created": 0, "reused": 0, "active": 0}

	var pool = object_pools[scene_path]
	var stats = pool_stats[scene_path]

	for i in range(count):
		var obj = _create_object(scene_path)
		if not obj:
			continue

		_deactivate_object(obj)
		pool.append(obj)
		stats["created"] += 1

func get_pool_stats(scene_path: String = "") -> Dictionary:
	"""Отримати статистику пулу"""
	if scene_path:
		return pool_stats.get(scene_path, {}).duplicate()
	else:
		return pool_stats.duplicate()

func clear_pool(scene_path: String = ""):
	"""Очистити пул"""
	if scene_path:
		if object_pools.has(scene_path):
			for obj in object_pools[scene_path]:
				obj.queue_free()
			object_pools[scene_path].clear()
			pool_stats[scene_path] = {"created": 0, "reused": 0, "active": 0}
	else:
		# Очистити всі пули
		for pool_scene_path in object_pools.keys():
			clear_pool(pool_scene_path)
		object_pools.clear()
		pool_stats.clear()

# Specialized pools - для конкретних типів об'єктів

func get_particle_effect(effect_path: String, parent: Node = null) -> Node:
	"""Отримати ефект частинок з пулу"""
	var effect = get_object(effect_path, parent)
	if effect and effect.has_method("restart"):
		effect.restart()
	return effect

func get_projectile(projectile_path: String, parent: Node = null) -> Node:
	"""Отримати снаряд з пулу"""
	return get_object(projectile_path, parent)

func get_enemy(enemy_path: String, parent: Node = null) -> Node:
	"""Отримати ворога з пулу"""
	return get_object(enemy_path, parent)

# Future features - заготовки

func get_object_with_data(scene_path: String, data: Dictionary, parent: Node = null) -> Node:
	"""Отримати об'єкт з ініціалізацією даними"""
	var obj = get_object(scene_path, parent)
	if obj and obj.has_method("initialize"):
		obj.initialize(data)
	return obj

func warmup_pool(scene_path: String, count: int):
	"""Попередній розігрів пулу"""
	preload_objects(scene_path, count)
