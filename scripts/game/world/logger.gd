# Простий логер з категоріями для системи генерації світу

extends Node
class_name WorldLogger

enum LogLevel {
	ERROR = 0,
	WARNING = 1,
	INFO = 2,
	DEBUG = 3,
	VERBOSE = 4
}

enum LogCategory {
	GENERAL,
	GENERATION,
	CHUNKING,
	PERFORMANCE,
	SAVE_LOAD,
	STRUCTURES,
	VEGETATION
}

# Поточний рівень логування
var current_level: LogLevel = LogLevel.INFO

# Включені категорії (якщо порожній - всі включені)
var enabled_categories: Array[LogCategory] = []

# Чи зберігати логи у файл
var save_to_file: bool = false
var log_file_path: String = "user://world_generation.log"

# Буфер логів для файлу
var log_buffer: Array[String] = []

func _ready():
	# Очищаємо старий лог файл при запуску
	if save_to_file:
		var file = FileAccess.open(log_file_path, FileAccess.WRITE)
		if file:
			file.store_string("=== World Generation Log Started ===\n")
			file.close()

func set_log_level(level: LogLevel):
	current_level = level

func enable_category(category: LogCategory):
	if not enabled_categories.has(category):
		enabled_categories.append(category)

func disable_category(category: LogCategory):
	enabled_categories.erase(category)

func enable_all_categories():
	enabled_categories.clear()

func log_error(message: String, category: LogCategory = LogCategory.GENERAL):
	if current_level >= LogLevel.ERROR:
		_log("[ERROR]", message, category)

func log_warning(message: String, category: LogCategory = LogCategory.GENERAL):
	if current_level >= LogLevel.WARNING:
		_log("[WARNING]", message, category)

func log_info(message: String, category: LogCategory = LogCategory.GENERAL):
	if current_level >= LogLevel.INFO:
		_log("[INFO]", message, category)

func log_debug(message: String, category: LogCategory = LogCategory.GENERAL):
	if current_level >= LogLevel.DEBUG:
		_log("[DEBUG]", message, category)

func log_verbose(message: String, category: LogCategory = LogCategory.GENERAL):
	if current_level >= LogLevel.VERBOSE:
		_log("[VERBOSE]", message, category)

func _log(level_prefix: String, message: String, category: LogCategory):
	# Перевіряємо чи категорія включена
	if not enabled_categories.is_empty() and not enabled_categories.has(category):
		return
	
	var category_name = _get_category_name(category)
	var timestamp = Time.get_datetime_string_from_system()
	var formatted_message = "%s [%s] %s: %s" % [timestamp, category_name, level_prefix, message]
	
	print(formatted_message)
	
	if save_to_file:
		log_buffer.append(formatted_message)
		# Записуємо у файл кожні 10 повідомлень
		if log_buffer.size() >= 10:
			_flush_logs()

func _get_category_name(category: LogCategory) -> String:
	match category:
		LogCategory.GENERAL: return "GENERAL"
		LogCategory.GENERATION: return "GENERATION"
		LogCategory.CHUNKING: return "CHUNKING"
		LogCategory.PERFORMANCE: return "PERFORMANCE"
		LogCategory.SAVE_LOAD: return "SAVE_LOAD"
		LogCategory.STRUCTURES: return "STRUCTURES"
		LogCategory.VEGETATION: return "VEGETATION"
		_: return "UNKNOWN"

func _flush_logs():
	if log_buffer.is_empty():
		return
	
	var file = FileAccess.open(log_file_path, FileAccess.READ_WRITE)
	if file:
		file.seek_end()
		for log_entry in log_buffer:
			file.store_string(log_entry + "\n")
		file.close()
	
	log_buffer.clear()

func _exit_tree():
	# Записуємо залишки логів при виході
	_flush_logs()

# Зручні методи для конкретних категорій
func generation(message: String, level: LogLevel = LogLevel.INFO):
	match level:
		LogLevel.ERROR: log_error(message, LogCategory.GENERATION)
		LogLevel.WARNING: log_warning(message, LogCategory.GENERATION)
		LogLevel.INFO: log_info(message, LogCategory.GENERATION)
		LogLevel.DEBUG: log_debug(message, LogCategory.GENERATION)
		LogLevel.VERBOSE: log_verbose(message, LogCategory.GENERATION)

func chunking(message: String, level: LogLevel = LogLevel.INFO):
	match level:
		LogLevel.ERROR: log_error(message, LogCategory.CHUNKING)
		LogLevel.WARNING: log_warning(message, LogCategory.CHUNKING)
		LogLevel.INFO: log_info(message, LogCategory.CHUNKING)
		LogLevel.DEBUG: log_debug(message, LogCategory.CHUNKING)
		LogLevel.VERBOSE: log_verbose(message, LogCategory.CHUNKING)

func performance(message: String, level: LogLevel = LogLevel.INFO):
	match level:
		LogLevel.ERROR: log_error(message, LogCategory.PERFORMANCE)
		LogLevel.WARNING: log_warning(message, LogCategory.PERFORMANCE)
		LogLevel.INFO: log_info(message, LogCategory.PERFORMANCE)
		LogLevel.DEBUG: log_debug(message, LogCategory.PERFORMANCE)
		LogLevel.VERBOSE: log_verbose(message, LogCategory.PERFORMANCE)
