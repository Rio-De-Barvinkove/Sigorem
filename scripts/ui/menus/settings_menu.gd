extends Control

signal settings_closed

const RESOLUTIONS := [
	Vector2i(640, 480),
	Vector2i(800, 600),
	Vector2i(1024, 768),
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3200, 1800),
	Vector2i(3840, 2160)
]

@onready var _option_button: OptionButton = %ResolutionOption
@onready var _fullscreen_toggle: CheckButton = %FullscreenToggle

var _custom_item_index: int = -1

func _ready():
	hide()
	_populate_resolution_list()
	_option_button.item_selected.connect(_on_resolution_selected)
	_fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	%ApplyButton.pressed.connect(_on_apply_pressed)
	%CloseButton.pressed.connect(_on_close_pressed)

func open():
	_refresh_state()
	show()
	grab_focus()

func close():
	hide()
	settings_closed.emit()

func _populate_resolution_list():
	_option_button.clear()
	for resolution in RESOLUTIONS:
		var label := "%d x %d" % [resolution.x, resolution.y]
		var index := _option_button.get_item_count()
		_option_button.add_item(label)
		_option_button.set_item_metadata(index, resolution)

func _refresh_state():
	_option_button.select(-1)
	_remove_custom_resolution()

	var current_mode := DisplayServer.window_get_mode()
	var current_size := DisplayServer.window_get_size()

	var matched_index := _find_matching_resolution_index(current_size)
	if matched_index == -1:
		_custom_item_index = _option_button.get_item_count()
		var label := "%d x %d (current)" % [current_size.x, current_size.y]
		_option_button.add_item(label)
		_option_button.set_item_metadata(_custom_item_index, current_size)
		_option_button.select(_custom_item_index)
	else:
		_option_button.select(matched_index)

	_fullscreen_toggle.button_pressed = current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

func _remove_custom_resolution():
	if _custom_item_index != -1 and _custom_item_index < _option_button.get_item_count():
		_option_button.remove_item(_custom_item_index)
	_custom_item_index = -1

func _find_matching_resolution_index(size: Vector2i) -> int:
	var count := _option_button.get_item_count()
	for index in count:
		var metadata: Variant = _option_button.get_item_metadata(index)
		if metadata is Vector2i and metadata == size:
			return index
	return -1

func _on_resolution_selected(_index: int):
	if not _fullscreen_toggle.button_pressed:
		_apply_selected_resolution()

func _on_fullscreen_toggled(pressed: bool):
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
		_apply_selected_resolution()

func _on_apply_pressed():
	if _fullscreen_toggle.button_pressed:
		return
	_apply_selected_resolution()

func _apply_selected_resolution():
	var index := _option_button.get_selected()
	if index < 0:
		return
	var metadata: Variant = _option_button.get_item_metadata(index)
	if metadata is not Vector2i:
		return
	var target_size: Vector2i = metadata
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
	DisplayServer.window_set_size(target_size)
	get_tree().root.content_scale_size = target_size

func _on_close_pressed():
	close()

