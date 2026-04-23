extends Control

@export var is_left: bool = false
@export var panel_size: Vector2 = Vector2(24, 72)
@export var used_alpha: float = 0.5
@export var full_alpha: float = 1.0
@export var min_sprite_padding: float = 2.0

@onready var ammo_panel: Panel = $AmmoPanel
@onready var ammo_stack: Control = $AmmoPanel/AmmoStack
@onready var reload_bar: ProgressBar = $ReloadBar

var _weapon: Node = null
var _slots: Array[TextureRect] = []


func _ready() -> void:
	if is_left:
		position = Vector2(1, 142)
		reload_bar.position = Vector2(5, -6.0)
	else:
		position = Vector2(423, 142)
		reload_bar.position = Vector2(-2, -6.0)

	ammo_panel.custom_minimum_size = panel_size
	ammo_panel.size = panel_size
	ammo_stack.custom_minimum_size = panel_size
	ammo_stack.size = panel_size
	reload_bar.custom_minimum_size = Vector2(panel_size.x + 6.0, 4.0)
	reload_bar.min_value = 0.0
	reload_bar.max_value = 100.0
	reload_bar.value = 0.0
	reload_bar.show_percentage = false
	reload_bar.visible = false

	_apply_style()


func set_weapon(weapon: Node) -> void:
	_disconnect_from_current_weapon()
	_weapon = weapon
	if _weapon == null:
		_clear_slots()
		reload_bar.visible = false
		return

	if _weapon.has_signal("ammo_changed"):
		_weapon.ammo_changed.connect(_on_ammo_changed)
	if _weapon.has_signal("reload_started"):
		_weapon.reload_started.connect(_on_reload_started)
	if _weapon.has_signal("reload_progress"):
		_weapon.reload_progress.connect(_on_reload_progress)
	if _weapon.has_signal("reload_finished"):
		_weapon.reload_finished.connect(_on_reload_finished)

	var max_ammo := int(_weapon.get("max_ammo"))
	var current_ammo := int(_weapon.get("current_ammo"))
	var icon := _weapon.get("ammo_icon") as Texture2D
	_build_slots(max_ammo, icon)
	_apply_ammo_alpha(current_ammo, max_ammo)
	reload_bar.visible = false


func _disconnect_from_current_weapon() -> void:
	if _weapon == null:
		return
	if _weapon.has_signal("ammo_changed") and _weapon.ammo_changed.is_connected(_on_ammo_changed):
		_weapon.ammo_changed.disconnect(_on_ammo_changed)
	if _weapon.has_signal("reload_started") and _weapon.reload_started.is_connected(_on_reload_started):
		_weapon.reload_started.disconnect(_on_reload_started)
	if _weapon.has_signal("reload_progress") and _weapon.reload_progress.is_connected(_on_reload_progress):
		_weapon.reload_progress.disconnect(_on_reload_progress)
	if _weapon.has_signal("reload_finished") and _weapon.reload_finished.is_connected(_on_reload_finished):
		_weapon.reload_finished.disconnect(_on_reload_finished)


func _clear_slots() -> void:
	for child in ammo_stack.get_children():
		child.queue_free()
	_slots.clear()


func _build_slots(max_ammo: int, icon: Texture2D) -> void:
	_clear_slots()
	if max_ammo <= 0:
		return

	var icon_size: Vector2 = Vector2(panel_size.x, 8.0)
	if icon != null:
		icon_size = icon.get_size()
	icon_size.x = maxf(icon_size.x, 1.0)
	icon_size.y = maxf(icon_size.y, 1.0)

	var step_y: float = icon_size.y + min_sprite_padding
	if max_ammo > 1:
		var available_step: float = (panel_size.y - icon_size.y) / float(max_ammo - 1)
		step_y = minf(step_y, maxf(available_step, 0.0))
	var total_height: float = icon_size.y + (step_y * float(max_ammo - 1))
	var top_padding: float = maxf((panel_size.y - total_height) * 0.5, 0.0)
	var x_offset: float = (panel_size.x - icon_size.x) * 0.5

	for i in range(max_ammo):
		var slot := TextureRect.new()
		slot.custom_minimum_size = icon_size
		slot.size = icon_size
		slot.position = Vector2(x_offset, top_padding + (float(i) * step_y))
		slot.texture = icon
		slot.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.flip_h = not is_left
		slot.modulate = Color(1.0, 1.0, 1.0, full_alpha)
		ammo_stack.add_child(slot)
		_slots.append(slot)


func _apply_ammo_alpha(current_ammo: int, max_ammo: int) -> void:
	if _slots.is_empty() or max_ammo <= 0:
		return

	var spent_count: int = clampi(max_ammo - current_ammo, 0, max_ammo)
	for i in range(_slots.size()):
		var alpha: float = used_alpha if i < spent_count else full_alpha
		_slots[i].modulate = Color(1.0, 1.0, 1.0, alpha)


func _apply_style() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.16, 0)
	ammo_panel.add_theme_stylebox_override("panel", panel_style)
	ammo_panel.clip_contents = true

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.18, 0.85, 0.46, 1.0)
	reload_bar.add_theme_stylebox_override("fill", fill)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.13, 0.85)
	reload_bar.add_theme_stylebox_override("background", bg)


func _on_ammo_changed(current: int, max_ammo: int) -> void:
	if _slots.size() != max_ammo:
		var icon := _weapon.get("ammo_icon") as Texture2D
		_build_slots(max_ammo, icon)
	_apply_ammo_alpha(current, max_ammo)


func _on_reload_started(_duration: float) -> void:
	reload_bar.visible = true
	reload_bar.value = 0.0


func _on_reload_progress(progress: float) -> void:
	reload_bar.visible = true
	reload_bar.value = clampf(progress, 0.0, 1.0) * 100.0


func _on_reload_finished() -> void:
	reload_bar.visible = false
	reload_bar.value = 0.0
