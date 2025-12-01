extends Node2D
class_name ImageElement

# -------------------------------------------------------------------------------------------------
const GROUP_IMAGE_ELEMENTS := "image_elements"
const HANDLE_SIZE := 8.0
const MIN_SIZE := Vector2(20, 20)

enum ResizeHandle {
	NONE,
	TOP_LEFT,
	TOP_RIGHT,
	BOTTOM_LEFT,
	BOTTOM_RIGHT,
	TOP,
	BOTTOM,
	LEFT,
	RIGHT
}

# -------------------------------------------------------------------------------------------------
@export var image_texture: ImageTexture = null

var image_size: Vector2 = Vector2(100, 100)
var is_selected: bool = false
var is_resizing: bool = false
var active_handle: ResizeHandle = ResizeHandle.NONE
var _resize_start_mouse_pos: Vector2 = Vector2.ZERO
var _resize_start_size: Vector2 = Vector2.ZERO
var _resize_start_global_pos: Vector2 = Vector2.ZERO
var _bounds: Rect2 = Rect2()

# -------------------------------------------------------------------------------------------------
func _ready() -> void:
	add_to_group(GROUP_IMAGE_ELEMENTS)

# -------------------------------------------------------------------------------------------------
func _draw() -> void:
	if image_texture == null:
		# Draw placeholder
		draw_rect(Rect2(Vector2.ZERO, image_size), Color(0.3, 0.3, 0.3, 0.5), true)
		draw_rect(Rect2(Vector2.ZERO, image_size), Color.WHITE, false, 2.0)
		return

	# Draw the image
	draw_texture_rect(image_texture, Rect2(Vector2.ZERO, image_size), false)

	# Update bounds
	_bounds = Rect2(Vector2.ZERO, image_size)

	# Draw selection outline and handles when selected
	if is_selected:
		draw_rect(_bounds, Color(0.4, 0.6, 1.0, 0.8), false, 2.0)
		_draw_resize_handles()

# -------------------------------------------------------------------------------------------------
func _draw_resize_handles() -> void:
	var handle_color := Color(0.4, 0.6, 1.0, 1.0)
	var handle_positions := _get_handle_positions()

	for pos in handle_positions.values():
		var handle_rect := Rect2(pos - Vector2(HANDLE_SIZE / 2, HANDLE_SIZE / 2), Vector2(HANDLE_SIZE, HANDLE_SIZE))
		draw_rect(handle_rect, handle_color, true)
		draw_rect(handle_rect, Color.WHITE, false, 1.0)

# -------------------------------------------------------------------------------------------------
func _get_handle_positions() -> Dictionary:
	return {
		ResizeHandle.TOP_LEFT: Vector2.ZERO,
		ResizeHandle.TOP_RIGHT: Vector2(image_size.x, 0),
		ResizeHandle.BOTTOM_LEFT: Vector2(0, image_size.y),
		ResizeHandle.BOTTOM_RIGHT: image_size,
		ResizeHandle.TOP: Vector2(image_size.x / 2, 0),
		ResizeHandle.BOTTOM: Vector2(image_size.x / 2, image_size.y),
		ResizeHandle.LEFT: Vector2(0, image_size.y / 2),
		ResizeHandle.RIGHT: Vector2(image_size.x, image_size.y / 2),
	}

# -------------------------------------------------------------------------------------------------
func get_handle_at_position(local_pos: Vector2) -> ResizeHandle:
	var handle_positions := _get_handle_positions()
	var hit_radius := HANDLE_SIZE

	for handle in handle_positions.keys():
		var handle_pos: Vector2 = handle_positions[handle]
		if local_pos.distance_to(handle_pos) <= hit_radius:
			return handle

	return ResizeHandle.NONE

# -------------------------------------------------------------------------------------------------
func start_resize(handle: int, mouse_pos: Vector2) -> void:
	is_resizing = true
	active_handle = handle
	_resize_start_mouse_pos = mouse_pos
	_resize_start_size = image_size
	_resize_start_global_pos = global_position

# -------------------------------------------------------------------------------------------------
func update_resize(mouse_pos: Vector2, maintain_aspect: bool = false) -> void:
	if !is_resizing:
		return

	var delta := mouse_pos - _resize_start_mouse_pos
	var new_size := _resize_start_size
	var new_pos := _resize_start_global_pos

	match active_handle:
		ResizeHandle.BOTTOM_RIGHT:
			new_size = _resize_start_size + delta
		ResizeHandle.TOP_LEFT:
			new_size = _resize_start_size - delta
			new_pos = _resize_start_global_pos + delta
		ResizeHandle.TOP_RIGHT:
			new_size.x = _resize_start_size.x + delta.x
			new_size.y = _resize_start_size.y - delta.y
			new_pos.y = _resize_start_global_pos.y + delta.y
		ResizeHandle.BOTTOM_LEFT:
			new_size.x = _resize_start_size.x - delta.x
			new_size.y = _resize_start_size.y + delta.y
			new_pos.x = _resize_start_global_pos.x + delta.x
		ResizeHandle.TOP:
			new_size.y = _resize_start_size.y - delta.y
			new_pos.y = _resize_start_global_pos.y + delta.y
		ResizeHandle.BOTTOM:
			new_size.y = _resize_start_size.y + delta.y
		ResizeHandle.LEFT:
			new_size.x = _resize_start_size.x - delta.x
			new_pos.x = _resize_start_global_pos.x + delta.x
		ResizeHandle.RIGHT:
			new_size.x = _resize_start_size.x + delta.x

	# Maintain aspect ratio if shift is held
	if maintain_aspect && image_texture != null:
		var aspect := _resize_start_size.x / _resize_start_size.y
		if active_handle in [ResizeHandle.LEFT, ResizeHandle.RIGHT]:
			new_size.y = new_size.x / aspect
		elif active_handle in [ResizeHandle.TOP, ResizeHandle.BOTTOM]:
			new_size.x = new_size.y * aspect
		else:
			# Corner handles - use the larger dimension
			if abs(delta.x) > abs(delta.y):
				new_size.y = new_size.x / aspect
			else:
				new_size.x = new_size.y * aspect

	# Enforce minimum size
	new_size = new_size.max(MIN_SIZE)

	# Apply changes
	image_size = new_size
	global_position = new_pos
	queue_redraw()

# -------------------------------------------------------------------------------------------------
func stop_resize() -> void:
	is_resizing = false
	active_handle = ResizeHandle.NONE

# -------------------------------------------------------------------------------------------------
func set_image(texture: ImageTexture) -> void:
	image_texture = texture
	if texture != null:
		image_size = texture.get_size()
	queue_redraw()

# -------------------------------------------------------------------------------------------------
func set_image_from_image(img: Image) -> void:
	var texture := ImageTexture.create_from_image(img)
	set_image(texture)

# -------------------------------------------------------------------------------------------------
func get_bounds() -> Rect2:
	return Rect2(global_position, image_size)

# -------------------------------------------------------------------------------------------------
func contains_point(point: Vector2) -> bool:
	return get_bounds().has_point(point)

# -------------------------------------------------------------------------------------------------
func select() -> void:
	is_selected = true
	queue_redraw()

# -------------------------------------------------------------------------------------------------
func deselect() -> void:
	is_selected = false
	is_resizing = false
	active_handle = ResizeHandle.NONE
	queue_redraw()
