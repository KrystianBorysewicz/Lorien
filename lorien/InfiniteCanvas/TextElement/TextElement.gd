extends Node2D
class_name TextElement

# -------------------------------------------------------------------------------------------------
signal text_changed(text: String)
signal editing_finished

# -------------------------------------------------------------------------------------------------
const GROUP_TEXT_ELEMENTS := "text_elements"

@export var font_size: int = 32
@export var text_color: Color = Color.WHITE

var text: String = ""
var is_editing: bool = false
var caret_position: int = 0
var _caret_visible: bool = true
var _caret_timer: float = 0.0
var _bounds: Rect2 = Rect2()

# -------------------------------------------------------------------------------------------------
func _ready() -> void:
	add_to_group(GROUP_TEXT_ELEMENTS)

# -------------------------------------------------------------------------------------------------
func _process(delta: float) -> void:
	if is_editing:
		_caret_timer += delta
		if _caret_timer >= 0.5:
			_caret_timer = 0.0
			_caret_visible = !_caret_visible
			queue_redraw()

# -------------------------------------------------------------------------------------------------
func _draw() -> void:
	if text.is_empty() && !is_editing:
		return

	var font := ThemeDB.fallback_font
	var line_height := font.get_height(font_size)
	var ascent := font.get_ascent(font_size)

	# Draw text
	var current_x := 0.0
	for i in text.length():
		var chr := text[i]
		var char_size := font.get_string_size(chr, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(font, Vector2(current_x, ascent), chr, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
		current_x += char_size.x

	# Draw caret if editing
	if is_editing && _caret_visible:
		var caret_x := 0.0
		for i in caret_position:
			if i < text.length():
				var chr := text[i]
				caret_x += font.get_string_size(chr, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

		draw_line(Vector2(caret_x, 0), Vector2(caret_x, line_height), text_color, 2.0)

	# Update bounds
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	_bounds = Rect2(Vector2.ZERO, Vector2(max(text_size.x, 10), line_height))

	# Draw selection box when editing
	if is_editing:
		draw_rect(_bounds.grow(4), Color(text_color, 0.2), false, 1.0)

# -------------------------------------------------------------------------------------------------
func start_editing() -> void:
	is_editing = true
	caret_position = text.length()
	_caret_visible = true
	_caret_timer = 0.0
	queue_redraw()

# -------------------------------------------------------------------------------------------------
func stop_editing() -> void:
	is_editing = false
	queue_redraw()
	editing_finished.emit()

# -------------------------------------------------------------------------------------------------
func insert_character(chr: String) -> void:
	text = text.insert(caret_position, chr)
	caret_position += chr.length()
	_caret_visible = true
	_caret_timer = 0.0
	text_changed.emit(text)
	queue_redraw()

# -------------------------------------------------------------------------------------------------
func delete_character_before() -> void:
	if caret_position > 0:
		text = text.erase(caret_position - 1, 1)
		caret_position -= 1
		text_changed.emit(text)
		queue_redraw()

# -------------------------------------------------------------------------------------------------
func delete_character_after() -> void:
	if caret_position < text.length():
		text = text.erase(caret_position, 1)
		text_changed.emit(text)
		queue_redraw()

# -------------------------------------------------------------------------------------------------
func move_caret_left() -> void:
	if caret_position > 0:
		caret_position -= 1
		_caret_visible = true
		_caret_timer = 0.0
		queue_redraw()

# -------------------------------------------------------------------------------------------------
func move_caret_right() -> void:
	if caret_position < text.length():
		caret_position += 1
		_caret_visible = true
		_caret_timer = 0.0
		queue_redraw()

# -------------------------------------------------------------------------------------------------
func move_caret_to_start() -> void:
	caret_position = 0
	_caret_visible = true
	_caret_timer = 0.0
	queue_redraw()

# -------------------------------------------------------------------------------------------------
func move_caret_to_end() -> void:
	caret_position = text.length()
	_caret_visible = true
	_caret_timer = 0.0
	queue_redraw()

# -------------------------------------------------------------------------------------------------
func get_bounds() -> Rect2:
	return Rect2(global_position + _bounds.position, _bounds.size)

# -------------------------------------------------------------------------------------------------
func contains_point(point: Vector2) -> bool:
	return get_bounds().grow(8).has_point(point)

# -------------------------------------------------------------------------------------------------
func set_text(new_text: String) -> void:
	text = new_text
	caret_position = text.length()
	queue_redraw()

# -------------------------------------------------------------------------------------------------
func get_character_paths(scale: float) -> Array:
	# Returns stroke paths for converting to brush strokes
	var all_paths: Array = []
	var char_offset := 0.0
	var s := scale * 16  # Base character size (same as in _get_single_character_paths)
	var char_width := s * 1.6  # Character width with extra spacing between letters
	var space_width := s * 1.0  # Space width

	for i in text.length():
		var chr := text[i]
		if chr == " ":
			char_offset += space_width
			continue

		var paths := _get_single_character_paths(chr, scale)
		for path: Array in paths:
			var offset_path: Array[Vector2] = []
			for point: Vector2 in path:
				offset_path.append(point + Vector2(char_offset, 0))
			all_paths.append(offset_path)

		# Use consistent character width based on stroke scale
		char_offset += char_width

	return all_paths

# -------------------------------------------------------------------------------------------------
func _get_single_character_paths(chr: String, scale: float) -> Array:
	var paths: Array = []
	var s := scale * 16

	match chr.to_upper():
		"A":
			paths.append([Vector2(0, s*2), Vector2(s*0.5, 0), Vector2(s, s*2)])
			paths.append([Vector2(s*0.25, s), Vector2(s*0.75, s)])
		"B":
			paths.append([Vector2(0, 0), Vector2(0, s*2)])
			paths.append([Vector2(0, 0), Vector2(s*0.6, 0), Vector2(s*0.8, s*0.25), Vector2(s*0.6, s)])
			paths.append([Vector2(0, s), Vector2(s*0.6, s), Vector2(s*0.8, s*1.25), Vector2(s*0.8, s*1.75), Vector2(s*0.6, s*2), Vector2(0, s*2)])
		"C":
			paths.append([Vector2(s, s*0.3), Vector2(s*0.5, 0), Vector2(0, s*0.5), Vector2(0, s*1.5), Vector2(s*0.5, s*2), Vector2(s, s*1.7)])
		"D":
			paths.append([Vector2(0, 0), Vector2(0, s*2)])
			paths.append([Vector2(0, 0), Vector2(s*0.5, 0), Vector2(s, s*0.5), Vector2(s, s*1.5), Vector2(s*0.5, s*2), Vector2(0, s*2)])
		"E":
			paths.append([Vector2(0, 0), Vector2(0, s*2)])
			paths.append([Vector2(0, 0), Vector2(s, 0)])
			paths.append([Vector2(0, s), Vector2(s*0.7, s)])
			paths.append([Vector2(0, s*2), Vector2(s, s*2)])
		"F":
			paths.append([Vector2(0, 0), Vector2(0, s*2)])
			paths.append([Vector2(0, 0), Vector2(s, 0)])
			paths.append([Vector2(0, s), Vector2(s*0.7, s)])
		"G":
			paths.append([Vector2(s, s*0.3), Vector2(s*0.5, 0), Vector2(0, s*0.5), Vector2(0, s*1.5), Vector2(s*0.5, s*2), Vector2(s, s*1.5), Vector2(s, s)])
			paths.append([Vector2(s*0.5, s), Vector2(s, s)])
		"H":
			paths.append([Vector2(0, 0), Vector2(0, s*2)])
			paths.append([Vector2(s, 0), Vector2(s, s*2)])
			paths.append([Vector2(0, s), Vector2(s, s)])
		"I":
			paths.append([Vector2(s*0.5, 0), Vector2(s*0.5, s*2)])
			paths.append([Vector2(s*0.2, 0), Vector2(s*0.8, 0)])
			paths.append([Vector2(s*0.2, s*2), Vector2(s*0.8, s*2)])
		"J":
			paths.append([Vector2(s, 0), Vector2(s, s*1.5), Vector2(s*0.5, s*2), Vector2(0, s*1.5)])
		"K":
			paths.append([Vector2(0, 0), Vector2(0, s*2)])
			paths.append([Vector2(s, 0), Vector2(0, s)])
			paths.append([Vector2(0, s), Vector2(s, s*2)])
		"L":
			paths.append([Vector2(0, 0), Vector2(0, s*2)])
			paths.append([Vector2(0, s*2), Vector2(s, s*2)])
		"M":
			paths.append([Vector2(0, s*2), Vector2(0, 0), Vector2(s*0.5, s), Vector2(s, 0), Vector2(s, s*2)])
		"N":
			paths.append([Vector2(0, s*2), Vector2(0, 0), Vector2(s, s*2), Vector2(s, 0)])
		"O":
			paths.append([Vector2(s*0.5, 0), Vector2(0, s*0.5), Vector2(0, s*1.5), Vector2(s*0.5, s*2), Vector2(s, s*1.5), Vector2(s, s*0.5), Vector2(s*0.5, 0)])
		"P":
			paths.append([Vector2(0, 0), Vector2(0, s*2)])
			paths.append([Vector2(0, 0), Vector2(s*0.7, 0), Vector2(s, s*0.3), Vector2(s, s*0.7), Vector2(s*0.7, s), Vector2(0, s)])
		"Q":
			paths.append([Vector2(s*0.5, 0), Vector2(0, s*0.5), Vector2(0, s*1.5), Vector2(s*0.5, s*2), Vector2(s, s*1.5), Vector2(s, s*0.5), Vector2(s*0.5, 0)])
			paths.append([Vector2(s*0.6, s*1.4), Vector2(s*1.1, s*2.1)])
		"R":
			paths.append([Vector2(0, 0), Vector2(0, s*2)])
			paths.append([Vector2(0, 0), Vector2(s*0.7, 0), Vector2(s, s*0.3), Vector2(s, s*0.7), Vector2(s*0.7, s), Vector2(0, s)])
			paths.append([Vector2(s*0.5, s), Vector2(s, s*2)])
		"S":
			paths.append([Vector2(s, s*0.3), Vector2(s*0.5, 0), Vector2(0, s*0.3), Vector2(0, s*0.7), Vector2(s*0.5, s), Vector2(s, s*1.3), Vector2(s, s*1.7), Vector2(s*0.5, s*2), Vector2(0, s*1.7)])
		"T":
			paths.append([Vector2(s*0.5, 0), Vector2(s*0.5, s*2)])
			paths.append([Vector2(0, 0), Vector2(s, 0)])
		"U":
			paths.append([Vector2(0, 0), Vector2(0, s*1.5), Vector2(s*0.5, s*2), Vector2(s, s*1.5), Vector2(s, 0)])
		"V":
			paths.append([Vector2(0, 0), Vector2(s*0.5, s*2), Vector2(s, 0)])
		"W":
			paths.append([Vector2(0, 0), Vector2(s*0.25, s*2), Vector2(s*0.5, s), Vector2(s*0.75, s*2), Vector2(s, 0)])
		"X":
			paths.append([Vector2(0, 0), Vector2(s, s*2)])
			paths.append([Vector2(s, 0), Vector2(0, s*2)])
		"Y":
			paths.append([Vector2(0, 0), Vector2(s*0.5, s)])
			paths.append([Vector2(s, 0), Vector2(s*0.5, s)])
			paths.append([Vector2(s*0.5, s), Vector2(s*0.5, s*2)])
		"Z":
			paths.append([Vector2(0, 0), Vector2(s, 0), Vector2(0, s*2), Vector2(s, s*2)])
		"0":
			paths.append([Vector2(s*0.5, 0), Vector2(0, s*0.5), Vector2(0, s*1.5), Vector2(s*0.5, s*2), Vector2(s, s*1.5), Vector2(s, s*0.5), Vector2(s*0.5, 0)])
			paths.append([Vector2(s*0.2, s*1.6), Vector2(s*0.8, s*0.4)])
		"1":
			paths.append([Vector2(s*0.3, s*0.4), Vector2(s*0.5, 0), Vector2(s*0.5, s*2)])
			paths.append([Vector2(s*0.2, s*2), Vector2(s*0.8, s*2)])
		"2":
			paths.append([Vector2(0, s*0.5), Vector2(s*0.5, 0), Vector2(s, s*0.5), Vector2(0, s*2), Vector2(s, s*2)])
		"3":
			paths.append([Vector2(0, s*0.3), Vector2(s*0.5, 0), Vector2(s, s*0.5), Vector2(s*0.5, s)])
			paths.append([Vector2(s*0.5, s), Vector2(s, s*1.5), Vector2(s*0.5, s*2), Vector2(0, s*1.7)])
		"4":
			paths.append([Vector2(0, 0), Vector2(0, s), Vector2(s, s)])
			paths.append([Vector2(s*0.7, 0), Vector2(s*0.7, s*2)])
		"5":
			paths.append([Vector2(s, 0), Vector2(0, 0), Vector2(0, s), Vector2(s*0.7, s), Vector2(s, s*1.3), Vector2(s, s*1.7), Vector2(s*0.5, s*2), Vector2(0, s*1.7)])
		"6":
			paths.append([Vector2(s, s*0.3), Vector2(s*0.5, 0), Vector2(0, s*0.5), Vector2(0, s*1.5), Vector2(s*0.5, s*2), Vector2(s, s*1.5), Vector2(s, s*1.2), Vector2(s*0.5, s), Vector2(0, s*1.2)])
		"7":
			paths.append([Vector2(0, 0), Vector2(s, 0), Vector2(s*0.3, s*2)])
		"8":
			paths.append([Vector2(s*0.5, 0), Vector2(0, s*0.3), Vector2(0, s*0.7), Vector2(s*0.5, s), Vector2(s, s*0.7), Vector2(s, s*0.3), Vector2(s*0.5, 0)])
			paths.append([Vector2(s*0.5, s), Vector2(0, s*1.3), Vector2(0, s*1.7), Vector2(s*0.5, s*2), Vector2(s, s*1.7), Vector2(s, s*1.3), Vector2(s*0.5, s)])
		"9":
			paths.append([Vector2(0, s*1.7), Vector2(s*0.5, s*2), Vector2(s, s*1.5), Vector2(s, s*0.5), Vector2(s*0.5, 0), Vector2(0, s*0.5), Vector2(0, s*0.8), Vector2(s*0.5, s), Vector2(s, s*0.8)])
		".":
			paths.append([Vector2(s*0.4, s*1.8), Vector2(s*0.5, s*1.9), Vector2(s*0.6, s*1.8), Vector2(s*0.5, s*2), Vector2(s*0.4, s*1.8)])
		",":
			paths.append([Vector2(s*0.5, s*1.8), Vector2(s*0.5, s*2), Vector2(s*0.3, s*2.2)])
		"!":
			paths.append([Vector2(s*0.5, 0), Vector2(s*0.5, s*1.4)])
			paths.append([Vector2(s*0.4, s*1.8), Vector2(s*0.5, s*1.9), Vector2(s*0.6, s*1.8), Vector2(s*0.5, s*2), Vector2(s*0.4, s*1.8)])
		"?":
			paths.append([Vector2(0, s*0.3), Vector2(s*0.5, 0), Vector2(s, s*0.3), Vector2(s, s*0.7), Vector2(s*0.5, s), Vector2(s*0.5, s*1.4)])
			paths.append([Vector2(s*0.4, s*1.8), Vector2(s*0.5, s*1.9), Vector2(s*0.6, s*1.8), Vector2(s*0.5, s*2), Vector2(s*0.4, s*1.8)])
		"-":
			paths.append([Vector2(s*0.2, s), Vector2(s*0.8, s)])
		"+":
			paths.append([Vector2(s*0.2, s), Vector2(s*0.8, s)])
			paths.append([Vector2(s*0.5, s*0.7), Vector2(s*0.5, s*1.3)])
		"=":
			paths.append([Vector2(s*0.2, s*0.7), Vector2(s*0.8, s*0.7)])
			paths.append([Vector2(s*0.2, s*1.3), Vector2(s*0.8, s*1.3)])
		":":
			paths.append([Vector2(s*0.4, s*0.5), Vector2(s*0.5, s*0.6), Vector2(s*0.6, s*0.5), Vector2(s*0.5, s*0.4), Vector2(s*0.4, s*0.5)])
			paths.append([Vector2(s*0.4, s*1.5), Vector2(s*0.5, s*1.6), Vector2(s*0.6, s*1.5), Vector2(s*0.5, s*1.4), Vector2(s*0.4, s*1.5)])
		"'":
			paths.append([Vector2(s*0.5, 0), Vector2(s*0.5, s*0.4)])
		"\"":
			paths.append([Vector2(s*0.3, 0), Vector2(s*0.3, s*0.4)])
			paths.append([Vector2(s*0.7, 0), Vector2(s*0.7, s*0.4)])
		"(":
			paths.append([Vector2(s*0.7, 0), Vector2(s*0.3, s*0.5), Vector2(s*0.3, s*1.5), Vector2(s*0.7, s*2)])
		")":
			paths.append([Vector2(s*0.3, 0), Vector2(s*0.7, s*0.5), Vector2(s*0.7, s*1.5), Vector2(s*0.3, s*2)])
		"/":
			paths.append([Vector2(s, 0), Vector2(0, s*2)])
		"@":
			paths.append([Vector2(s, s*0.8), Vector2(s*0.6, s*0.6), Vector2(s*0.4, s*0.8), Vector2(s*0.4, s*1.2), Vector2(s*0.6, s*1.4), Vector2(s, s*1.2), Vector2(s, s*0.5), Vector2(s*0.5, 0), Vector2(0, s*0.5), Vector2(0, s*1.5), Vector2(s*0.5, s*2), Vector2(s, s*1.7)])
		"#":
			paths.append([Vector2(s*0.3, 0), Vector2(s*0.2, s*2)])
			paths.append([Vector2(s*0.8, 0), Vector2(s*0.7, s*2)])
			paths.append([Vector2(0, s*0.7), Vector2(s, s*0.7)])
			paths.append([Vector2(0, s*1.3), Vector2(s, s*1.3)])
		_:
			# For lowercase, use uppercase
			if chr >= "a" && chr <= "z":
				return _get_single_character_paths(chr.to_upper(), scale * 0.8)
			# Default: small rectangle
			paths.append([Vector2(0, 0), Vector2(s*0.8, 0), Vector2(s*0.8, s*2), Vector2(0, s*2), Vector2(0, 0)])

	return paths
