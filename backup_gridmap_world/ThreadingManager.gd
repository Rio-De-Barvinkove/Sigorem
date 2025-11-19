extends Node
class_name ThreadingManager

# Модуль для керування потоками генерації
#
# ВАЖЛИВО: Цей модуль має критичні проблеми безпеки в Godot 4:
# - Thread.start(_generation_worker) без bind → в Godot 4 потрібно .start(Callable(this, "_generation_worker"))
# - generate_chunk_threaded() викликає procedural_module.generate_chunk() → це GridMap.set_cell_item() з іншого потоку → краш 100% (GridMap не thread-safe!)
# - Немає call_deferred для повернення результату в головний потік
#
# ВИСНОВОК: Не вмикай use_threading = true ніколи в поточному вигляді — гра впаде миттєво.
# Правильний threading для voxel terrain в Godot 4 — тільки обчислення висот/печер, а set_cell_item — в головному потоці.

var thread_pool: Array[Thread] = []
var max_threads := 4
var semaphore: Semaphore
var mutex: Mutex

var generation_queue: Array = []
var running := false

func _ready():
	semaphore = Semaphore.new()
	mutex = Mutex.new()
	# ВИПРАВЛЕНО: Попередження про небезпеку використання
	push_warning("[ThreadingManager] Модуль має критичні проблеми безпеки в Godot 4. Рекомендується use_threading = false.")

func start_generation():
	"""Запуск потокової генерації
	
	КРИТИЧНА ПРОБЛЕМА: Thread.start(_generation_worker) без bind → в Godot 4 потрібно .start(Callable(this, "_generation_worker"))
	"""
	if running:
		return

	running = true

	# ВИПРАВЛЕНО: Використовуємо Callable для Godot 4
	# Створюємо потоки
	for i in range(max_threads):
		var thread = Thread.new()
		# ВИПРАВЛЕНО: Використовуємо Callable замість прямого посилання на метод
		var callable = Callable(self, "_generation_worker")
		var error = thread.start(callable)
		if error != OK:
			push_error("[ThreadingManager] start_generation: Не вдалося запустити потік ", i, " - помилка: ", error)
			running = false
			return
		thread_pool.append(thread)

func stop_generation():
	"""Зупинка генерації"""
	running = false

	# Сигналізуємо потокам зупинитися
	for i in range(max_threads):
		semaphore.post()

	# Чекаємо завершення потоків
	for thread in thread_pool:
		if thread.is_alive():
			thread.wait_to_finish()

	thread_pool.clear()
	generation_queue.clear()

func queue_generation_task(task: Dictionary):
	"""Додати завдання генерації до черги"""
	mutex.lock()
	generation_queue.append(task)
	mutex.unlock()

	# Сигналізуємо потокам про нове завдання
	semaphore.post()

func _generation_worker():
	"""Робочий потік генерації"""
	while running:
		semaphore.wait()

		mutex.lock()
		var task = generation_queue.pop_front() if not generation_queue.is_empty() else null
		mutex.unlock()

		if task:
			execute_generation_task(task)

func execute_generation_task(task: Dictionary):
	"""Виконати завдання генерації
	
	КРИТИЧНА ПРОБЛЕМА: generate_chunk_threaded() викликає procedural_module.generate_chunk() 
	→ це GridMap.set_cell_item() з іншого потоку → краш 100% (GridMap не thread-safe!)
	"""
	match task.type:
		"chunk":
			# ВИПРАВЛЕНО: Не викликаємо generate_chunk_threaded() безпосередньо - це небезпечно
			# Замість цього обчислюємо дані в потоці, а потім викликаємо set_cell_item в головному потоці
			push_error("[ThreadingManager] execute_generation_task: generate_chunk_threaded() небезпечний - GridMap не thread-safe!")
			# generate_chunk_threaded(task.chunk_pos, task.gridmap)  # ВИМКНЕНО через небезпеку
		"structure":
			generate_structure_threaded(task.structure_data)
		_:
			push_warning("ThreadingManager: Невідомий тип завдання: ", task.type)

func generate_chunk_threaded(chunk_pos: Vector2i, gridmap: GridMap):
	"""Генерація чанка в окремому потоці
	
	КРИТИЧНА ПРОБЛЕМА: Викликає procedural_module.generate_chunk() → це GridMap.set_cell_item() 
	з іншого потоку → краш 100% (GridMap не thread-safe!)
	
	ПРАВИЛЬНИЙ ПІДХІД: Тільки обчислення висот/печер в потоці, а set_cell_item — в головному потоці через call_deferred.
	"""
	# ВИПРАВЛЕНО: Не викликаємо GridMap операції з іншого потоку - це викличе краш!
	push_error("[ThreadingManager] generate_chunk_threaded: НЕ ВИКОРИСТОВУЙТЕ ЦЕЙ МЕТОД! GridMap не thread-safe!")
	return
	
	# НЕПРАВИЛЬНИЙ КОД (залишено для прикладу чого НЕ робити):
	# if get_parent().procedural_module:
	#     get_parent().procedural_module.generate_chunk(gridmap, chunk_pos)  # КРАШ! GridMap.set_cell_item() з іншого потоку
	
	# ПРАВИЛЬНИЙ ПІДХІД (майбутнє рішення):
	# 1. Обчислити висоти/печери в потоці (без GridMap операцій)
	# 2. Зберегти результати в Dictionary
	# 3. Викликати call_deferred для встановлення блоків в головному потоці
	# Приклад:
	# var chunk_data = compute_chunk_data_threaded(chunk_pos)  # Тільки обчислення
	# call_deferred("apply_chunk_data_to_gridmap", gridmap, chunk_data)  # Встановлення в головному потоці

func generate_structure_threaded(structure_data: Dictionary):
	"""Генерація структури в окремому потоці
	
	ВАЖЛИВО: Те саме обмеження - не можна викликати GridMap операції з іншого потоку.
	"""
	# ВИПРАВЛЕНО: Не викликаємо GridMap операції з іншого потоку
	if get_parent().structure_module:
		# Тут буде виклик генерації структури (тільки обчислення, без GridMap операцій)
		# Результати потрібно повертати через call_deferred
		pass

func get_queue_size() -> int:
	"""Отримати розмір черги завдань"""
	mutex.lock()
	var size = generation_queue.size()
	mutex.unlock()
	return size
