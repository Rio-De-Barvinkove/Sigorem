extends Control
class_name PerformanceMonitor
## UI для моніторингу продуктивності в режимі розробки
##
## Відображає:
## - FPS
## - Час кадру
## - Використання пам'яті (MB)
## - Кількість активних чанків
## - Кількість об'єктів у сцені
## - Кількість Draw Calls

@onready var fps_label: Label = $Panel/VBoxContainer/FPSLabel
@onready var frame_time_label: Label = $Panel/VBoxContainer/FrameTimeLabel
@onready var memory_label: Label = $Panel/VBoxContainer/MemoryLabel
@onready var chunks_label: Label = $Panel/VBoxContainer/ChunksLabel
@onready var objects_label: Label = $Panel/VBoxContainer/ObjectsLabel
@onready var draw_calls_label: Label = $Panel/VBoxContainer/DrawCallsLabel
@onready var toggle_button: Button = $ToggleButton
@onready var panel: Panel = $Panel

@export var update_interval: float = 0.5  ## Інтервал оновлення UI в секундах
@export var visible_by_default: bool = false  ## Чи показувати за замовчуванням

var _time_since_update: float = 0.0


func _ready() -> void:
	## Ініціалізація монітора
	visible = visible_by_default
	panel.visible = visible_by_default

	toggle_button.connect("pressed", Callable(self, "_on_toggle_pressed"))

	if visible:
		_update_display()


func _process(delta: float) -> void:
	## Оновлення відображення
	if not visible:
		return

	_time_since_update += delta
	if _time_since_update >= update_interval:
		_time_since_update = 0.0
		_update_display()


func _update_display() -> void:
	## Оновлення всіх лейблів з поточними метриками
	# Всі методи PerformanceLogger статичні, тому перевірка не потрібна

	# FPS
	var avg_fps = PerformanceLogger.get_average_fps()
	var min_fps = PerformanceLogger.get_min_fps()
	var max_fps = PerformanceLogger.get_max_fps()
	fps_label.text = "FPS: %.1f (min: %.1f, max: %.1f)" % [avg_fps, min_fps, max_fps]

	# Час кадру
	var avg_frame_time = PerformanceLogger.get_average_frame_time()
	frame_time_label.text = "Frame Time: %.2f ms" % avg_frame_time

	# Пам'ять
	var current_memory = PerformanceLogger.get_current_memory_usage()
	var peak_memory = PerformanceLogger.get_peak_memory_usage()
	var current_mb = current_memory / 1000000.0
	var peak_mb = peak_memory / 1000000.0
	memory_label.text = "Memory: %.1f MB (peak: %.1f MB)" % [current_mb, peak_mb]

	# Чанки
	var total_chunks = PerformanceLogger.get_total_chunks_generated()
	chunks_label.text = "Total Chunks: %d" % total_chunks

	# Статистика рендерингу
	var total_objects = Performance.get_monitor(Performance.OBJECT_COUNT)  # реальна кількість об'єктів
	var draw_calls = PerformanceLogger.get_average_draw_calls()  # середня кількість draw calls
	objects_label.text = "Objects: %d" % total_objects
	draw_calls_label.text = "Draw Calls: %d" % draw_calls


func _on_toggle_pressed() -> void:
	## Перемикання видимості панелі
	visible = !visible
	if visible:
		_update_display()  # Оновити відразу при показі


func show_monitor() -> void:
	## Показати монітор
	visible = true
	_update_display()


func hide_monitor() -> void:
	## Сховати монітор
	visible = false


func toggle_monitor() -> void:
	## Перемкнути видимість
	if visible:
		hide_monitor()
	else:
		show_monitor()


## Статичні методи для глобального керування
static func show_global() -> void:
	## Показати глобальний монітор
	var monitor = get_global_monitor()
	if monitor:
		monitor.show_monitor()


static func hide_global() -> void:
	## Сховати глобальний монітор
	var monitor = get_global_monitor()
	if monitor:
		monitor.hide_monitor()


static func toggle_global() -> void:
	## Перемкнути глобальний монітор
	var monitor = get_global_monitor()
	if monitor:
		monitor.toggle_monitor()


static func get_global_monitor() -> PerformanceMonitor:
	## Отримати єдиний екземпляр монітора з сцени
	var tree = Engine.get_main_loop()
	if not tree:
		return null
	return tree.root.find_child("PerformanceMonitor", true, false) as PerformanceMonitor
