extends Control

const AK47_SCENE: PackedScene = preload("res://scenes/entities/weapons/ak47.tscn")
const FIFTY_CAL_SCENE: PackedScene = preload("res://scenes/entities/weapons/50cal.tscn")
const GOLD_AK_SCENE: PackedScene = preload("res://scenes/entities/weapons/goldak47.tscn")

@onready var p1_shop_ui: Control = $Root/P1ShopUI
@onready var p1_main_panel: Panel = $Root/P1ShopUI/MainPanel
@onready var p1_title_label: Label = $Root/P1ShopUI/MainPanel/TitleLabel
@onready var p1_gold_label: Label = $Root/P1ShopUI/MainPanel/GoldLabel
@onready var p1_options_scroll: ScrollContainer = $Root/P1ShopUI/MainPanel/OptionsScroll
@onready var p1_options_container: VBoxContainer = $Root/P1ShopUI/MainPanel/OptionsScroll/OptionsContainer

@onready var p2_shop_ui: Control = $Root/P2ShopUI
@onready var p2_main_panel: Panel = $Root/P2ShopUI/MainPanel
@onready var p2_title_label: Label = $Root/P2ShopUI/MainPanel/TitleLabel
@onready var p2_gold_label: Label = $Root/P2ShopUI/MainPanel/GoldLabel
@onready var p2_options_scroll: ScrollContainer = $Root/P2ShopUI/MainPanel/OptionsScroll
@onready var p2_options_container: VBoxContainer = $Root/P2ShopUI/MainPanel/OptionsScroll/OptionsContainer

var p1_current_mode: String = ""
var p2_current_mode: String = ""
@export var option_button_height: float = 12.0
@export var option_button_width_reduction: int = 20

var p1_current_player: CharacterBody2D = null
var p2_current_player: CharacterBody2D = null
var p1_option_buttons: Array[Button] = []
var p2_option_buttons: Array[Button] = []
var p1_selected_index: int = 0
var p2_selected_index: int = 0


func _ready() -> void:
	p1_main_panel.visible = false
	p2_main_panel.visible = false
	set_process(true)

	# Optional: tighter spacing between option buttons
	p1_options_container.add_theme_constant_override("separation", 6)
	p2_options_container.add_theme_constant_override("separation", 6)


func _process(_delta: float) -> void:
	if p1_main_panel.visible:
		_handle_player_shop_input(1)
	if p2_main_panel.visible:
		_handle_player_shop_input(2)


func open_ui(mode: String, player: CharacterBody2D) -> void:
	if player == null:
		return

	if player.player_id == 1:
		p1_current_mode = mode
		p1_current_player = player
		p1_main_panel.visible = true
		populate_ui_for_player(1)
	elif player.player_id == 2:
		p2_current_mode = mode
		p2_current_player = player
		p2_main_panel.visible = true
		populate_ui_for_player(2)


func close_ui_for_player(player_id: int) -> void:
	if player_id == 1:
		p1_main_panel.visible = false
		p1_current_mode = ""
		p1_current_player = null
		p1_option_buttons.clear()
		p1_selected_index = 0
		_clear_options(p1_options_container)
	elif player_id == 2:
		p2_main_panel.visible = false
		p2_current_mode = ""
		p2_current_player = null
		p2_option_buttons.clear()
		p2_selected_index = 0
		_clear_options(p2_options_container)


func close_ui() -> void:
	p1_main_panel.visible = false
	p2_main_panel.visible = false

	p1_current_mode = ""
	p2_current_mode = ""

	p1_current_player = null
	p2_current_player = null
	p1_option_buttons.clear()
	p2_option_buttons.clear()
	p1_selected_index = 0
	p2_selected_index = 0

	_clear_options(p1_options_container)
	_clear_options(p2_options_container)


func populate_ui_for_player(player_id: int) -> void:
	var player: CharacterBody2D = null
	var mode: String = ""
	var title_label: Label = null
	var gold_label: Label = null
	var options_container: VBoxContainer = null
	var options_scroll: ScrollContainer = null

	if player_id == 1:
		player = p1_current_player
		mode = p1_current_mode
		title_label = p1_title_label
		gold_label = p1_gold_label
		options_container = p1_options_container
		options_scroll = p1_options_scroll
		p1_option_buttons.clear()
		p1_selected_index = 0
	else:
		player = p2_current_player
		mode = p2_current_mode
		title_label = p2_title_label
		gold_label = p2_gold_label
		options_container = p2_options_container
		options_scroll = p2_options_scroll
		p2_option_buttons.clear()
		p2_selected_index = 0

	_clear_options(options_container)
	_update_gold_label(player, gold_label)

	match mode.to_lower():
		"upgrade":
			title_label.text = "Upgrade"
			_add_upgrade_button(player_id, options_container, "+10 Max HP", 20)
			_add_upgrade_button(player_id, options_container, "+10 Speed", 25)
			_add_dash_upgrade_buttons(player_id, options_container)
		"buy":
			title_label.text = "Buy"
			_add_buy_button(player_id, options_container, "AK47", 50)
			_add_buy_button(player_id, options_container, "50Cal", 80)
			_add_buy_button(player_id, options_container, "Gold AK", 100)

		_:
			title_label.text = "Shop"

	# Reset scroll to top whenever menu refreshes
	if options_scroll != null:
		options_scroll.scroll_vertical = 0

	_refresh_selection(player_id)


func _clear_options(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()


func _update_gold_label(player: CharacterBody2D, gold_label: Label) -> void:
	if player == null:
		gold_label.text = "Gold: ?"
		return

	gold_label.text = "Gold: " + str(player.gold)


func _add_upgrade_button(player_id: int, container: VBoxContainer, upgrade_name: String, cost: int) -> void:
	var player := _get_player_by_id(player_id)

	var button := Button.new()
	button.text = upgrade_name + " - " + str(cost) + "g"
	button.custom_minimum_size = Vector2(0, option_button_height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 10)

	if player == null or player.gold < cost:
		button.disabled = true

	button.pressed.connect(func() -> void:
		_attempt_upgrade(player_id, upgrade_name, cost)
	)

	_add_button_row(container, button)
	_register_option_button(player_id, button)


func _add_buy_button(player_id: int, container: VBoxContainer, item_name: String, cost: int) -> void:
	var player := _get_player_by_id(player_id)

	var button := Button.new()
	button.text = item_name + " - " + str(cost) + "g"
	button.custom_minimum_size = Vector2(0, option_button_height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 8)

	var disable := false
	if player == null or player.gold < cost:
		disable = true

	if player != null:
		match item_name:
			"AK47":
				if player.inventory.has("ak47"):
					disable = true
					button.text = "AK47 - Owned"
			"50Cal":
				if player.inventory.has("50cal"):
					disable = true
					button.text = "50Cal - Owned"
			"Gold AK":
				if player.inventory.has("gold_ak"):
					disable = true
					button.text = "Gold AK - Owned"

	button.disabled = disable

	button.pressed.connect(func() -> void:
		_attempt_purchase(player_id, item_name, cost)
	)

	_add_button_row(container, button)
	_register_option_button(player_id, button)


func _add_button_row(container: VBoxContainer, button: Button) -> void:
	var inset := maxi(option_button_width_reduction / 2, 0)
	if inset == 0:
		container.add_child(button)
		return

	var row := MarginContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("margin_left", inset)
	row.add_theme_constant_override("margin_right", inset)
	row.add_child(button)
	container.add_child(row)


func _register_option_button(player_id: int, button: Button) -> void:
	if player_id == 1:
		p1_option_buttons.append(button)
	else:
		p2_option_buttons.append(button)


func _handle_player_shop_input(player_id: int) -> void:
	var prefix := "p1_" if player_id == 1 else "p2_"

	if Input.is_action_just_pressed(prefix + "up"):
		_move_selection(player_id, -1)
	elif Input.is_action_just_pressed(prefix + "down"):
		_move_selection(player_id, 1)

	if Input.is_action_just_pressed(prefix + "attack"):
		_activate_selection(player_id)


func _move_selection(player_id: int, direction: int) -> void:
	var buttons := p1_option_buttons if player_id == 1 else p2_option_buttons
	if buttons.is_empty():
		return

	if player_id == 1:
		p1_selected_index = wrapi(p1_selected_index + direction, 0, buttons.size())
	else:
		p2_selected_index = wrapi(p2_selected_index + direction, 0, buttons.size())

	_refresh_selection(player_id)


func _activate_selection(player_id: int) -> void:
	var buttons := p1_option_buttons if player_id == 1 else p2_option_buttons
	if buttons.is_empty():
		return

	var selected_index := p1_selected_index if player_id == 1 else p2_selected_index
	if selected_index < 0 or selected_index >= buttons.size():
		return

	var selected_button := buttons[selected_index]
	if selected_button == null or not is_instance_valid(selected_button):
		return
	if selected_button.disabled:
		return

	selected_button.pressed.emit()


func _refresh_selection(player_id: int) -> void:
	var buttons := p1_option_buttons if player_id == 1 else p2_option_buttons
	if buttons.is_empty():
		return

	var selected_index := p1_selected_index if player_id == 1 else p2_selected_index
	selected_index = clampi(selected_index, 0, buttons.size() - 1)
	if player_id == 1:
		p1_selected_index = selected_index
	else:
		p2_selected_index = selected_index

	for i in range(buttons.size()):
		var button := buttons[i]
		if button == null or not is_instance_valid(button):
			continue
		button.modulate = Color(1.0, 0.95, 0.65, 1.0) if i == selected_index else Color(1.0, 1.0, 1.0, 1.0)

	var selected_button := buttons[selected_index]
	if selected_button != null and is_instance_valid(selected_button):
		var options_scroll := p1_options_scroll if player_id == 1 else p2_options_scroll
		if options_scroll != null:
			options_scroll.ensure_control_visible(selected_button)


func _attempt_upgrade(player_id: int, upgrade_name: String, cost: int) -> void:
	var player := _get_player_by_id(player_id)
	if player == null:
		return

	if player.gold < cost:
		return

	player.gold -= cost
	if player.has_method("_update_coin_ui"):
		player._update_coin_ui()

	if not Global.player_stats.has(player_id):
		return

	var stats: Dictionary = Global.player_stats[player_id]

	match upgrade_name:
		"+10 Max HP":
			stats["max_health"] = int(stats.get("max_health", 100)) + 10
			stats["health"] = int(stats.get("health", 100)) + 10
			if player.has_method("_update_health_ui"):
				player._update_health_ui()

		"+10 Speed":
			stats["speed"] = float(stats.get("speed", player.speed)) + 10.0

		_:
			push_warning("Unknown upgrade: " + upgrade_name)

	populate_ui_for_player(player_id)


func _attempt_purchase(player_id: int, item_name: String, cost: int) -> void:
	var player := _get_player_by_id(player_id)
	if player == null:
		return

	if item_name == "AK47" and player.inventory.has("ak47"):
		return
	if item_name == "50Cal" and player.inventory.has("50cal"):
		return
	if item_name == "Gold AK" and player.inventory.has("gold_ak"):
		return

	if player.gold < cost:
		return

	player.gold -= cost
	if player.has_method("_update_coin_ui"):
		player._update_coin_ui()

	match item_name:
		"AK47":
			if AK47_SCENE == null:
				push_warning("AK47 scene is missing")
				return
			if player.has_method("add_weapon_to_inventory"):
				player.add_weapon_to_inventory("ak47", true)
			elif player.has_method("equip_weapon_scene"):
				player.equip_weapon_scene(AK47_SCENE)
				if not player.inventory.has("ak47"):
					player.inventory.append("ak47")

		"50Cal":
			if FIFTY_CAL_SCENE == null:
				push_warning("50Cal scene is missing")
				return
			if player.has_method("add_weapon_to_inventory"):
				player.add_weapon_to_inventory("50cal", true)
			elif player.has_method("equip_weapon_scene"):
				player.equip_weapon_scene(FIFTY_CAL_SCENE)
				if not player.inventory.has("50cal"):
					player.inventory.append("50cal")

		"Gold AK":
			if GOLD_AK_SCENE == null:
				push_warning("Gold AK scene is missing")
				return
			if player.has_method("add_weapon_to_inventory"):
				player.add_weapon_to_inventory("gold_ak", true)
			elif player.has_method("equip_weapon_scene"):
				player.equip_weapon_scene(GOLD_AK_SCENE)
				if not player.inventory.has("gold_ak"):
					player.inventory.append("gold_ak")

		_:
			push_warning("Unknown item: " + item_name)

	populate_ui_for_player(player_id)


func _add_dash_upgrade_buttons(player_id: int, container: VBoxContainer) -> void:
	var player := _get_player_by_id(player_id)
	if player == null:
		return

	if not Global.player_stats.has(player_id):
		return

	var stats: Dictionary = Global.player_stats[player_id]
	var dashes_max: int = int(stats.get("dashes_max", 0))
	var cost: int = 40

	# Allow purchasing up to 3 dash upgrades
	if dashes_max < 3:
		var button := Button.new()
		var charge_num := dashes_max + 1
		button.text = "+1 Dash (" + str(charge_num) + "/3) - " + str(cost) + "g"
		button.custom_minimum_size = Vector2(0, option_button_height)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.add_theme_font_size_override("font_size", 10)

		if player.gold < cost:
			button.disabled = true

		button.pressed.connect(func() -> void:
			_attempt_dash_upgrade(player_id, cost)
		)

		_add_button_row(container, button)
		_register_option_button(player_id, button)


func _attempt_dash_upgrade(player_id: int, cost: int) -> void:
	var player := _get_player_by_id(player_id)
	if player == null:
		return

	if player.gold < cost:
		return

	if not Global.player_stats.has(player_id):
		return

	var stats: Dictionary = Global.player_stats[player_id]
	var dashes_max: int = int(stats.get("dashes_max", 0))

	if dashes_max >= 3:
		return

	player.gold -= cost
	if player.has_method("_update_coin_ui"):
		player._update_coin_ui()

	dashes_max += 1
	stats["dashes_max"] = dashes_max
	stats["dashes_available"] = dashes_max

	populate_ui_for_player(player_id)


func _get_player_by_id(player_id: int) -> CharacterBody2D:
	if player_id == 1:
		return p1_current_player
	elif player_id == 2:
		return p2_current_player
	return null
