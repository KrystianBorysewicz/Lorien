class_name SelectionTool
extends CanvasTool

# -------------------------------------------------------------------------------------------------
const BRUSH_STROKE = preload("res://BrushStroke/BrushStroke.tscn")
const TEXT_ELEMENT = preload("res://InfiniteCanvas/TextElement/TextElement.tscn")
const IMAGE_ELEMENT = preload("res://InfiniteCanvas/ImageElement/ImageElement.tscn")

const MAX_FLOAT := 2147483646.0
const MIN_FLOAT := -2147483646.0
const META_OFFSET := "offset"
const GROUP_SELECTED_STROKES := "selected_strokes" # selected strokes and text elements
const GROUP_STROKES_IN_SELECTION_RECTANGLE := "strokes_in_selection_rectangle" # elements that are in selection rectangle but not commit (i.e. the user is still selecting)
const GROUP_MARKED_FOR_DESELECTION := "strokes_marked_for_deselection" # elements that need to be deslected once LMB is released
const GROUP_COPIED_STROKES := "strokes_copied"

# -------------------------------------------------------------------------------------------------
enum State {
	NONE,
	SELECTING,
	MOVING,
	RESIZING
}

# -------------------------------------------------------------------------------------------------
@export var selection_rectangle_path: NodePath
var _selection_rectangle: SelectionRectangle
var _state := State.NONE
var _selecting_start_pos: Vector2 = Vector2.ZERO
var _selecting_end_pos: Vector2 = Vector2.ZERO
var _multi_selecting: bool
var _mouse_moved_during_pressed := false
var _stroke_positions_before_move := {} # BrushStroke -> Vector2
var _bounding_box_cache := {} # BrushStroke -> Rect2
var _resizing_image: ImageElement = null
var _resize_start_size: Vector2 = Vector2.ZERO

# ------------------------------------------------------------------------------------------------
func _ready() -> void:
	super()
	_selection_rectangle = get_node(selection_rectangle_path)
	_cursor.mode = SelectionCursor.Mode.SELECT

# ------------------------------------------------------------------------------------------------
func tool_event(event: InputEvent) -> void:
	var duplicate_pressed := Utils.is_action_pressed("duplicate_strokes", event)
	var copy_pressed := Utils.is_action_pressed("copy_strokes", event)
	var paste_pressed := Utils.is_action_pressed("paste_strokes", event)

	if copy_pressed || duplicate_pressed:
		var elements := get_selected_elements()
		if elements.size() > 0:
			Utils.remove_group_from_all_nodes(GROUP_COPIED_STROKES)
			for element in elements:
				element.add_to_group(GROUP_COPIED_STROKES)
			print("Copied %d elements" % elements.size())

	if paste_pressed || duplicate_pressed:
		var elements := get_tree().get_nodes_in_group(GROUP_COPIED_STROKES)
		if !elements.is_empty():
			deselect_all_strokes()
			_cursor.mode = SelectionCursor.Mode.MOVE
			_paste_elements(elements)

	if event is InputEventMouseButton && !disable_stroke:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# LMB down - decide if we should select/multiselect, move, or resize
			if event.pressed:
				_selecting_start_pos = _cursor.global_position

				# Check if clicking on a resize handle of a selected image
				var resize_result := _get_image_resize_handle_at(_cursor.global_position)
				if resize_result.image != null:
					_state = State.RESIZING
					_resizing_image = resize_result.image
					_resizing_image.start_resize(resize_result.handle, _cursor.global_position)
					_resize_start_size = _resizing_image.image_size
				elif event.shift_pressed:
					_state = State.SELECTING
					_multi_selecting = true
					_build_bounding_boxes()
				elif get_selected_elements().size() == 0:
					_state = State.SELECTING
					_multi_selecting = false
					_build_bounding_boxes()
				else:
					_state = State.MOVING
					_mouse_moved_during_pressed = false
					_offset_selected_elements(_cursor.global_position)
					for element in get_selected_elements():
						_stroke_positions_before_move[element] = element.global_position
			# LMB up - stop selection, movement, or resize
			else:
				if _state == State.SELECTING:
					_state = State.NONE
					_selection_rectangle.reset()
					_selection_rectangle.queue_redraw()
					_commit_elements_under_selection_rectangle()
					_deselect_marked_elements()
					if get_selected_elements().size() > 0:
						_cursor.mode = SelectionCursor.Mode.MOVE
				elif _state == State.MOVING:
					_state = State.NONE
					if _mouse_moved_during_pressed:
						_add_undoredo_action_for_moved_strokes()
						_stroke_positions_before_move.clear()
					else:
						deselect_all_strokes()
					_mouse_moved_during_pressed = false
				elif _state == State.RESIZING:
					_state = State.NONE
					if _resizing_image != null:
						_resizing_image.stop_resize()
						_resizing_image = null
						
		# RMB down - just deselect
		elif event.button_index == MOUSE_BUTTON_RIGHT && event.pressed && _state == State.NONE:
			deselect_all_strokes()
	
	# Mouse movement: move or resize the selection
	elif event is InputEventMouseMotion:
		var event_pos := _cursor.global_position
		if _state == State.SELECTING:
			_selecting_end_pos = event_pos
			compute_selection(_selecting_start_pos, _selecting_end_pos)
			_selection_rectangle.start_position = _selecting_start_pos
			_selection_rectangle.end_position = _selecting_end_pos
			_selection_rectangle.queue_redraw()
		elif _state == State.MOVING:
			_mouse_moved_during_pressed = true
			_move_selected_elements()
		elif _state == State.RESIZING:
			if _resizing_image != null:
				_resizing_image.update_resize(event_pos, event.shift_pressed)
	
	# Shift click - switch between move/select cursor mode
	elif event is InputEventKey:
		if event.keycode == KEY_SHIFT:
			if event.pressed:
				_cursor.mode = SelectionCursor.Mode.SELECT
			elif get_selected_elements().size() > 0:
				_cursor.mode = SelectionCursor.Mode.MOVE

# ------------------------------------------------------------------------------------------------
func compute_selection(start_pos: Vector2, end_pos: Vector2) -> void:
	var selection_rect : Rect2 = Utils.calculate_rect(start_pos, end_pos)
	# Select strokes
	for stroke: BrushStroke in _canvas.get_strokes_in_camera_frustrum():
		var bounding_box: Rect2 = _bounding_box_cache[stroke]
		if selection_rect.intersects(bounding_box):
			for point: Vector2 in stroke.points:
				var abs_point: Vector2 = stroke.position + point
				if selection_rect.has_point(abs_point):
					_set_element_selected(stroke)
					break
	# Select text elements
	for text_element in get_tree().get_nodes_in_group(TextElement.GROUP_TEXT_ELEMENTS):
		if text_element is TextElement && !text_element.is_editing:
			var bounds: Rect2 = text_element.get_bounds()
			if selection_rect.intersects(bounds):
				_set_element_selected(text_element)
	# Select image elements
	for image_element in get_tree().get_nodes_in_group(ImageElement.GROUP_IMAGE_ELEMENTS):
		if image_element is ImageElement:
			var bounds: Rect2 = image_element.get_bounds()
			if selection_rect.intersects(bounds):
				_set_element_selected(image_element)
	_canvas.info.selected_lines = get_selected_elements().size()

# ------------------------------------------------------------------------------------------------
func _paste_elements(elements: Array) -> void:
	# Calculate offset at center
	var top_left := Vector2(MAX_FLOAT, MAX_FLOAT)
	var bottom_right := Vector2(MIN_FLOAT, MIN_FLOAT)

	for element in elements:
		if element is BrushStroke:
			top_left.x = min(top_left.x, element.top_left_pos.x + element.position.x)
			top_left.y = min(top_left.y, element.top_left_pos.y + element.position.y)
			bottom_right.x = max(bottom_right.x, element.bottom_right_pos.x + element.position.x)
			bottom_right.y = max(bottom_right.y, element.bottom_right_pos.y + element.position.y)
		elif element is TextElement:
			var bounds: Rect2 = element.get_bounds()
			top_left.x = min(top_left.x, bounds.position.x)
			top_left.y = min(top_left.y, bounds.position.y)
			bottom_right.x = max(bottom_right.x, bounds.end.x)
			bottom_right.y = max(bottom_right.y, bounds.end.y)
		elif element is ImageElement:
			var bounds: Rect2 = element.get_bounds()
			top_left.x = min(top_left.x, bounds.position.x)
			top_left.y = min(top_left.y, bounds.position.y)
			bottom_right.x = max(bottom_right.x, bounds.end.x)
			bottom_right.y = max(bottom_right.y, bounds.end.y)
	var offset := _cursor.global_position - (top_left + (bottom_right - top_left) / 2.0)

	# Duplicate the elements
	var stroke_duplicates := []
	for element in elements:
		if element is BrushStroke:
			var dup := _duplicate_stroke(element, offset)
			dup.add_to_group(GROUP_SELECTED_STROKES)
			dup.modulate = Config.DEFAULT_SELECTION_COLOR
			stroke_duplicates.append(dup)
		elif element is TextElement:
			var dup := _duplicate_text_element(element, offset)
			dup.add_to_group(GROUP_SELECTED_STROKES)
			dup.modulate = Config.DEFAULT_SELECTION_COLOR
		elif element is ImageElement:
			var dup := _duplicate_image_element(element, offset)
			dup.add_to_group(GROUP_SELECTED_STROKES)
			dup.modulate = Config.DEFAULT_SELECTION_COLOR

	if !stroke_duplicates.is_empty():
		_canvas.add_strokes(stroke_duplicates)
	print("Pasted %d elements (offset: %s)" % [elements.size(), offset])

# ------------------------------------------------------------------------------------------------
func _duplicate_stroke(stroke: BrushStroke, offset: Vector2) -> BrushStroke:
	var dup: BrushStroke = BRUSH_STROKE.instantiate()
	dup.global_position = stroke.global_position
	dup.size = stroke.size
	dup.color = stroke.color
	dup.pressures = stroke.pressures.duplicate()
	for point: Vector2 in stroke.points:
		dup.points.append(point + offset)
	return dup

# ------------------------------------------------------------------------------------------------
func _duplicate_text_element(text_element: TextElement, offset: Vector2) -> TextElement:
	var dup: TextElement = TEXT_ELEMENT.instantiate()
	dup.global_position = text_element.global_position + offset
	dup.font_size = text_element.font_size
	dup.text_color = text_element.text_color
	dup.text = text_element.text
	_canvas._strokes_parent.add_child(dup)
	return dup

# ------------------------------------------------------------------------------------------------
func _duplicate_image_element(image_element: ImageElement, offset: Vector2) -> ImageElement:
	var dup: ImageElement = IMAGE_ELEMENT.instantiate()
	dup.global_position = image_element.global_position + offset
	dup.image_size = image_element.image_size
	dup.image_texture = image_element.image_texture
	_canvas._strokes_parent.add_child(dup)
	return dup

# ------------------------------------------------------------------------------------------------
func _build_bounding_boxes() -> void:
	_bounding_box_cache.clear()
	_bounding_box_cache = Utils.calculte_bounding_boxes(_canvas.get_all_strokes())
	#$"../Viewport/DebugDraw".set_bounding_boxes(_bounding_box_cache.values())

# ------------------------------------------------------------------------------------------------
func _get_image_resize_handle_at(pos: Vector2) -> Dictionary:
	# Check selected images for resize handles
	for element in get_selected_elements():
		if element is ImageElement:
			var local_pos := pos - element.global_position
			var handle: int = element.get_handle_at_position(local_pos)
			if handle != ImageElement.ResizeHandle.NONE:
				return {"image": element, "handle": handle}
	return {"image": null, "handle": ImageElement.ResizeHandle.NONE}
	
# ------------------------------------------------------------------------------------------------
func _set_element_selected(element: Node2D) -> void:
	if element.is_in_group(GROUP_SELECTED_STROKES):
		element.modulate = Color.WHITE
		element.add_to_group(GROUP_MARKED_FOR_DESELECTION)
		if element is ImageElement:
			element.is_selected = false
			element.queue_redraw()
	else:
		element.modulate = Config.DEFAULT_SELECTION_COLOR
		element.add_to_group(GROUP_STROKES_IN_SELECTION_RECTANGLE)
		if element is ImageElement:
			element.is_selected = true
			element.queue_redraw()
			
# ------------------------------------------------------------------------------------------------
func _add_undoredo_action_for_moved_strokes() -> void:
	var project: Project = ProjectManager.get_active_project()
	project.undo_redo.create_action("Move Elements")
	for element in _stroke_positions_before_move.keys():
		project.undo_redo.add_do_property(element, "global_position", element.global_position)
		project.undo_redo.add_undo_property(element, "global_position", _stroke_positions_before_move[element])
	project.undo_redo.commit_action()
	project.dirty = true

# -------------------------------------------------------------------------------------------------
func _offset_selected_elements(offset: Vector2) -> void:
	for element in get_selected_elements():
		element.set_meta(META_OFFSET, element.position - offset)

# -------------------------------------------------------------------------------------------------
func _move_selected_elements() -> void:
	for element in get_selected_elements():
		element.global_position = element.get_meta(META_OFFSET) + _cursor.global_position

# ------------------------------------------------------------------------------------------------
func _commit_elements_under_selection_rectangle() -> void:
	for element in get_tree().get_nodes_in_group(GROUP_STROKES_IN_SELECTION_RECTANGLE):
		element.remove_from_group(GROUP_STROKES_IN_SELECTION_RECTANGLE)
		element.add_to_group(GROUP_SELECTED_STROKES)
		if element is ImageElement:
			element.is_selected = true
			element.queue_redraw()

# ------------------------------------------------------------------------------------------------
func _deselect_marked_elements() -> void:
	for element in get_tree().get_nodes_in_group(GROUP_MARKED_FOR_DESELECTION):
		element.remove_from_group(GROUP_MARKED_FOR_DESELECTION)
		element.remove_from_group(GROUP_SELECTED_STROKES)
		element.modulate = Color.WHITE

# ------------------------------------------------------------------------------------------------
func deselect_all_strokes() -> void:
	var selected_elements: Array = get_selected_elements()
	if selected_elements.size():
		for element in selected_elements:
			if element is ImageElement:
				element.is_selected = false
				element.queue_redraw()
		get_tree().set_group(GROUP_SELECTED_STROKES, "modulate", Color.WHITE)
		get_tree().set_group(GROUP_STROKES_IN_SELECTION_RECTANGLE, "modulate", Color.WHITE)
		Utils.remove_group_from_all_nodes(GROUP_SELECTED_STROKES)
		Utils.remove_group_from_all_nodes(GROUP_MARKED_FOR_DESELECTION)
		Utils.remove_group_from_all_nodes(GROUP_STROKES_IN_SELECTION_RECTANGLE)

	_canvas.info.selected_lines = 0
	_cursor.mode = SelectionCursor.Mode.SELECT

# ------------------------------------------------------------------------------------------------
func is_selecting() -> bool:
	return _state == State.SELECTING

# ------------------------------------------------------------------------------------------------
func get_selected_strokes() -> Array[BrushStroke]:
	# Can't cast from Array[Node] to Array[BrushStroke] directly (godot bug/missing feature?)
	# so let's do it per item
	var strokes: Array[BrushStroke]
	for element in get_tree().get_nodes_in_group(GROUP_SELECTED_STROKES):
		if element is BrushStroke:
			strokes.append(element as BrushStroke)
	return strokes

# ------------------------------------------------------------------------------------------------
func get_selected_elements() -> Array[Node2D]:
	# Returns all selected elements (strokes and text elements)
	var elements: Array[Node2D]
	for element in get_tree().get_nodes_in_group(GROUP_SELECTED_STROKES):
		elements.append(element as Node2D)
	return elements

# ------------------------------------------------------------------------------------------------
func _on_brush_color_changed(color: Color) -> void:
	for element in get_selected_elements():
		if element is BrushStroke:
			element.color = color
		elif element is TextElement:
			element.text_color = color
			element.queue_redraw()

# ------------------------------------------------------------------------------------------------
func reset() -> void:
	_state = State.NONE
	_selection_rectangle.reset()
	_selection_rectangle.queue_redraw()
	_commit_elements_under_selection_rectangle()
	deselect_all_strokes()
