class_name TextTool
extends CanvasTool

# -------------------------------------------------------------------------------------------------
const TEXT_ELEMENT_SCENE = preload("res://InfiniteCanvas/TextElement/TextElement.tscn")

# -------------------------------------------------------------------------------------------------
signal editing_started
signal editing_finished

# -------------------------------------------------------------------------------------------------
@export var pressure_curve: Curve

var _active_text_element: TextElement = null
var _is_editing: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
var _text_elements_parent: Node2D = null

# -------------------------------------------------------------------------------------------------
func _ready() -> void:
	super._ready()

# -------------------------------------------------------------------------------------------------
func set_text_elements_parent(parent: Node2D) -> void:
	_text_elements_parent = parent

# -------------------------------------------------------------------------------------------------
func tool_event(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventKey && _is_editing:
		_handle_key_input(event)

# -------------------------------------------------------------------------------------------------
func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	var click_pos := _cursor.global_position

	if event.pressed:
		# Check if clicking on existing text element
		var clicked_element := _find_text_element_at(click_pos)

		if clicked_element != null:
			if _active_text_element != null && _active_text_element != clicked_element:
				_finish_editing()

			_active_text_element = clicked_element
			_active_text_element.start_editing()
			_is_editing = true
			_is_dragging = false

			# Check if clicking on the text itself for dragging
			if event.shift_pressed:
				_is_dragging = true
				_drag_offset = _active_text_element.global_position - click_pos

			editing_started.emit()
		else:
			# Clicked on empty space
			if _is_editing:
				_finish_editing()
			else:
				# Create new text element
				_create_new_text_element(click_pos)
	else:
		# Mouse released
		_is_dragging = false

# -------------------------------------------------------------------------------------------------
func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _is_dragging && _active_text_element != null:
		_active_text_element.global_position = _cursor.global_position + _drag_offset

# -------------------------------------------------------------------------------------------------
func _handle_key_input(event: InputEventKey) -> void:
	if !event.pressed || _active_text_element == null:
		return

	# Handle special keys
	match event.keycode:
		KEY_ESCAPE:
			_finish_editing()
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			_finish_editing()
			get_viewport().set_input_as_handled()
		KEY_BACKSPACE:
			_active_text_element.delete_character_before()
			get_viewport().set_input_as_handled()
		KEY_DELETE:
			_active_text_element.delete_character_after()
			get_viewport().set_input_as_handled()
		KEY_LEFT:
			_active_text_element.move_caret_left()
			get_viewport().set_input_as_handled()
		KEY_RIGHT:
			_active_text_element.move_caret_right()
			get_viewport().set_input_as_handled()
		KEY_HOME:
			_active_text_element.move_caret_to_start()
			get_viewport().set_input_as_handled()
		KEY_END:
			_active_text_element.move_caret_to_end()
			get_viewport().set_input_as_handled()
		_:
			# Handle regular character input
			if event.unicode > 0:
				var chr := char(event.unicode)
				if chr.is_valid_identifier() || chr in " !@#$%^&*()_+-=[]{}|;':\",./<>?`~":
					_active_text_element.insert_character(chr)
					get_viewport().set_input_as_handled()

# -------------------------------------------------------------------------------------------------
func _create_new_text_element(position: Vector2) -> void:
	if _text_elements_parent == null:
		_text_elements_parent = _canvas._strokes_parent

	_active_text_element = TEXT_ELEMENT_SCENE.instantiate()
	_active_text_element.global_position = position
	_active_text_element.font_size = _canvas._brush_size * 4
	_active_text_element.text_color = _canvas._brush_color
	_text_elements_parent.add_child(_active_text_element)

	_active_text_element.start_editing()
	_is_editing = true
	editing_started.emit()

# -------------------------------------------------------------------------------------------------
func _find_text_element_at(position: Vector2) -> TextElement:
	var text_elements := get_tree().get_nodes_in_group(TextElement.GROUP_TEXT_ELEMENTS)
	for element in text_elements:
		if element is TextElement && element.contains_point(position):
			return element
	return null

# -------------------------------------------------------------------------------------------------
func _finish_editing() -> void:
	if _active_text_element != null:
		_active_text_element.stop_editing()

		# If text is empty, remove the element
		if _active_text_element.text.strip_edges().is_empty():
			_active_text_element.queue_free()
		# Otherwise keep the text element as-is (renders with draw_string)

		_active_text_element = null

	_is_editing = false
	_is_dragging = false
	editing_finished.emit()

# -------------------------------------------------------------------------------------------------
func is_editing() -> bool:
	return _is_editing

# -------------------------------------------------------------------------------------------------
func cancel_editing() -> void:
	if _active_text_element != null:
		_active_text_element.queue_free()
		_active_text_element = null
	_is_editing = false
	_is_dragging = false

# -------------------------------------------------------------------------------------------------
func reset() -> void:
	if _is_editing:
		_finish_editing()
	super.reset()

# -------------------------------------------------------------------------------------------------
func _on_brush_color_changed(color: Color) -> void:
	if _active_text_element != null:
		_active_text_element.text_color = color
		_active_text_element.queue_redraw()

# -------------------------------------------------------------------------------------------------
func _on_brush_size_changed(size: int) -> void:
	super._on_brush_size_changed(size)
	if _active_text_element != null:
		_active_text_element.font_size = size * 4
		_active_text_element.queue_redraw()

# -------------------------------------------------------------------------------------------------
func _process(delta: float) -> void:
	pass
