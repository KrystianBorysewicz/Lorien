extends PanelContainer
class_name TextInputDialog

signal text_confirmed(text: String)
signal dialog_closed

# -------------------------------------------------------------------------------------------------
@onready var _line_edit: LineEdit = $VBoxContainer/LineEdit
@onready var _confirm_button: Button = $VBoxContainer/HBoxContainer/ConfirmButton
@onready var _cancel_button: Button = $VBoxContainer/HBoxContainer/CancelButton

# -------------------------------------------------------------------------------------------------
func _ready() -> void:
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_line_edit.text_submitted.connect(_on_text_submitted)

# -------------------------------------------------------------------------------------------------
func show_dialog() -> void:
	_line_edit.text = ""
	visible = true
	_line_edit.grab_focus()

# -------------------------------------------------------------------------------------------------
func hide_dialog() -> void:
	visible = false
	dialog_closed.emit()

# -------------------------------------------------------------------------------------------------
func _on_confirm_pressed() -> void:
	_submit_text()

# -------------------------------------------------------------------------------------------------
func _on_cancel_pressed() -> void:
	hide_dialog()

# -------------------------------------------------------------------------------------------------
func _on_text_submitted(text: String) -> void:
	_submit_text()

# -------------------------------------------------------------------------------------------------
func _submit_text() -> void:
	var text := _line_edit.text.strip_edges()
	if !text.is_empty():
		text_confirmed.emit(text)
	hide_dialog()
