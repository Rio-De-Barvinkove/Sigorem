extends Node
class_name PerfLogger

@export var enabled: bool = true
@export var report_interval: float = 1.5

var _accum_time := 0.0
var _add_time_usec := 0.0
var _add_count := 0
var _mesh_time_usec := 0.0
var _mesh_count := 0

func log_add_time(t_start_usec: int) -> void:
	if not enabled:
		return
	var dt := Time.get_ticks_usec() - t_start_usec
	_add_time_usec += dt
	_add_count += 1

func log_mesh_time(t_start_usec: int) -> void:
	if not enabled:
		return
	var dt := Time.get_ticks_usec() - t_start_usec
	_mesh_time_usec += dt
	_mesh_count += 1

func request_report() -> void:
	if not enabled:
		return
	_accum_time += get_process_delta_time()
	if _accum_time >= report_interval:
		_report()
		_accum_time = 0.0

func _report() -> void:
	var add_avg := (_add_time_usec / _add_count) if _add_count > 0 else 0.0
	var mesh_avg := (_mesh_time_usec / _mesh_count) if _mesh_count > 0 else 0.0
	print("[Perf] add: %.2f ms (%d) | mesh: %.2f ms (%d)" % [
		add_avg / 1000.0, _add_count,
		mesh_avg / 1000.0, _mesh_count
	])
	_add_time_usec = 0.0
	_add_count = 0
	_mesh_time_usec = 0.0
	_mesh_count = 0













