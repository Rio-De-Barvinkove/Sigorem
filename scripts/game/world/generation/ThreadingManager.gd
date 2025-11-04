extends Node
class_name ThreadingManager

# Модуль для керування потоками генерації

var thread_pool: Array[Thread] = []
var max_threads := 4
var semaphore: Semaphore
var mutex: Mutex

var generation_queue: Array = []
var running := false

func _ready():
	semaphore = Semaphore.new()
	mutex = Mutex.new()

func start_generation():
	"""Запуск потокової генерації"""
	if running:
		return

	running = true

	# Створюємо потоки
	for i in range(max_threads):
		var thread = Thread.new()
		thread.start(_generation_worker)
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
	"""Виконати завдання генерації"""
	match task.type:
		"chunk":
			generate_chunk_threaded(task.chunk_pos, task.gridmap)
		"structure":
			generate_structure_threaded(task.structure_data)
		_:
			push_warning("ThreadingManager: Невідомий тип завдання: ", task.type)

func generate_chunk_threaded(chunk_pos: Vector2i, gridmap: GridMap):
	"""Генерація чанка в окремому потоці"""
	# Викликаємо генерацію чанка з головного модуля
	if get_parent().procedural_module:
		get_parent().procedural_module.generate_chunk(gridmap, chunk_pos)

func generate_structure_threaded(structure_data: Dictionary):
	"""Генерація структури в окремому потоці"""
	if get_parent().structure_module:
		# Тут буде виклик генерації структури
		pass

func get_queue_size() -> int:
	"""Отримати розмір черги завдань"""
	mutex.lock()
	var size = generation_queue.size()
	mutex.unlock()
	return size
