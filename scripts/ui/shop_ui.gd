extends Control

@export var weapon_pool: WeaponPool = preload("res://scripts/weapons/weapon_pool.tres")
@export var shop_weapon_offer_count: int = 3
var pixel_font: FontFile = preload("res://assets/fonts/pixel_font.ttf")

@onready var p1_shop_ui: Control = $Root/P1ShopUI
@onready var p1_main_panel: Panel = $Root/P1ShopUI/MainPanel
@onready var p1_title_label: Label = $Root/P1ShopUI/MainPanel/TitleLabel
@onready var p1_gold_label: Label = $Root/P1ShopUI/MainPanel/GoldLabel
@onready var p1_options_scroll: ScrollContainer = $Root/P1ShopUI/MainPanel/OptionsScroll
@onready var p1_options_container: VBoxContainer = $Root/P1ShopUI/MainPanel/OptionsScroll/OptionsContainer
@onready var p1_desc_label: Label = $Root/P1ShopUI/MainPanel/DescLabel
@onready var p1_price_label: Label = $Root/P1ShopUI/MainPanel/PriceLabel
@onready var p1_item_preview: TextureRect = $Root/P1ShopUI/MainPanel/ItemPreview
@onready var p1_stats_title_label: Label = $Root/P1ShopUI/MainPanel/StatsLabel
@onready var p1_stats_label: Label = $Root/P1ShopUI/MainPanel/StatsLabel2

@onready var p2_shop_ui: Control = $Root/P2ShopUI
@onready var p2_main_panel: Panel = $Root/P2ShopUI/MainPanel
@onready var p2_title_label: Label = $Root/P2ShopUI/MainPanel/TitleLabel
@onready var p2_gold_label: Label = $Root/P2ShopUI/MainPanel/GoldLabel
@onready var p2_options_scroll: ScrollContainer = $Root/P2ShopUI/MainPanel/OptionsScroll
@onready var p2_options_container: VBoxContainer = $Root/P2ShopUI/MainPanel/OptionsScroll/OptionsContainer
@onready var p2_desc_label: Label = $Root/P2ShopUI/MainPanel/DescLabel
@onready var p2_price_label: Label = $Root/P2ShopUI/MainPanel/PriceLabel
@onready var p2_item_preview: TextureRect = $Root/P2ShopUI/MainPanel/ItemPreview
@onready var p2_stats_title_label: Label = $Root/P2ShopUI/MainPanel/StatsLabel
@onready var p2_stats_label: Label = $Root/P2ShopUI/MainPanel/StatsLabel2

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
var p1_just_opened: bool = false
var p2_just_opened: bool = false
var current_weapon_offers: Array[PackedScene] = []
var p1_displayed_weapons: Array[PackedScene] = []
var p2_displayed_weapons: Array[PackedScene] = []
var p1_default_preview_texture: Texture2D = null
var p2_default_preview_texture: Texture2D = null

var upgrade_data: Dictionary = {
	"+20 Max HP": {
		"description": "Increase maximum health by 20.",
		"cost": 25
	},
	"+10 Speed": {
		"description": "Increases movement speed by 10.",
		"cost": 15
	},
	"+1 Dash": {
		"description": "Adds an additional dash charge. Max 3.",
		"cost": 40
	}
}


func _ready() -> void:
	p1_main_panel.visible = false
	p2_main_panel.visible = false
	set_process(true)

	# Optional: tighter spacing between option buttons
	p1_options_container.add_theme_constant_override("separation", 6)
	p2_options_container.add_theme_constant_override("separation", 6)
	p1_default_preview_texture = p1_item_preview.texture
	p2_default_preview_texture = p2_item_preview.texture
	p1_item_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p1_item_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p2_item_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p2_item_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_set_stats_labels_visible(1, false)
	_set_stats_labels_visible(2, false)
	_clear_preview(1)
	_clear_preview(2)
	refresh_weapon_offers(0)


func refresh_weapon_offers(duels_occurred: int) -> void:
	current_weapon_offers.clear()
	if weapon_pool == null:
		push_warning("Weapon pool is not assigned on ShopUI")
		return

	var allowed_range := _get_power_range_for_duels(duels_occurred)
	var min_power: int = int(allowed_range.x)
	var max_power: int = int(allowed_range.y)
	var candidates := weapon_pool.get_weapons_in_power_range(min_power, max_power)
	if candidates.is_empty():
		push_warning("No shop weapon candidates for power range %d-%d" % [min_power, max_power])
		return

	candidates.shuffle()
	var offer_count := mini(shop_weapon_offer_count, candidates.size())
	for i in range(offer_count):
		current_weapon_offers.append(candidates[i])


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
		p1_just_opened = true
		populate_ui_for_player(1)
	elif player.player_id == 2:
		p2_current_mode = mode
		p2_current_player = player
		p2_main_panel.visible = true
		p2_just_opened = true
		populate_ui_for_player(2)


func close_ui_for_player(player_id: int) -> void:
	if player_id == 1:
		p1_main_panel.visible = false
		p1_current_mode = ""
		p1_current_player = null
		p1_option_buttons.clear()
		p1_selected_index = 0
		_clear_options(p1_options_container)
		_clear_preview(1)
	elif player_id == 2:
		p2_main_panel.visible = false
		p2_current_mode = ""
		p2_current_player = null
		p2_option_buttons.clear()
		p2_selected_index = 0
		_clear_options(p2_options_container)
		_clear_preview(2)


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
	_clear_preview(1)
	_clear_preview(2)


func populate_ui_for_player(player_id: int, preserve_selection: bool = false) -> void:
	var player: CharacterBody2D = null
	var mode: String = ""
	var title_label: Label = null
	var gold_label: Label = null
	var options_container: VBoxContainer = null
	var options_scroll: ScrollContainer = null
	var previous_selected_index: int = 0

	if player_id == 1:
		previous_selected_index = p1_selected_index
		player = p1_current_player
		mode = p1_current_mode
		title_label = p1_title_label
		gold_label = p1_gold_label
		options_container = p1_options_container
		options_scroll = p1_options_scroll
		p1_option_buttons.clear()
		if not preserve_selection:
			p1_selected_index = 0
	else:
		previous_selected_index = p2_selected_index
		player = p2_current_player
		mode = p2_current_mode
		title_label = p2_title_label
		gold_label = p2_gold_label
		options_container = p2_options_container
		options_scroll = p2_options_scroll
		p2_option_buttons.clear()
		if not preserve_selection:
			p2_selected_index = 0

	_clear_options(options_container)
	_update_gold_label(player, gold_label)
	_set_stats_labels_visible(player_id, false)

	match mode.to_lower():
		"upgrade":
			title_label.text = "Upgrades"
			_add_upgrade_button(player_id, options_container, "+20 Max HP", upgrade_data["+20 Max HP"]["cost"])
			_add_upgrade_button(player_id, options_container, "+10 Speed", upgrade_data["+10 Speed"]["cost"])
			_add_dash_upgrade_buttons(player_id, options_container)
		"buy":
			title_label.text = "Weapons"
			_set_stats_labels_visible(player_id, true)
			var displayed_weapons := _build_displayed_weapon_list(player)
			if player_id == 1:
				p1_displayed_weapons = displayed_weapons
			else:
				p2_displayed_weapons = displayed_weapons
			for weapon_scene in displayed_weapons:
				_add_buy_button(player_id, options_container, weapon_scene)

		_:
			title_label.text = "Shop"
			if player_id == 1:
				p1_displayed_weapons.clear()
			else:
				p2_displayed_weapons.clear()

	# Reset scroll to top whenever menu refreshes
	if options_scroll != null:
		options_scroll.scroll_vertical = 0

	if preserve_selection:
		if player_id == 1:
			p1_selected_index = previous_selected_index
		else:
			p2_selected_index = previous_selected_index

	_refresh_selection(player_id)


func _clear_options(container: VBoxContainer) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _update_gold_label(player: CharacterBody2D, gold_label: Label) -> void:
	if player == null:
		gold_label.text = "?"
		return

	gold_label.text = str(player.gold)


func _add_upgrade_button(player_id: int, container: VBoxContainer, upgrade_name: String, cost: int) -> void:
	var player := _get_player_by_id(player_id)

	var button := Button.new()
	button.text = upgrade_name
	button.custom_minimum_size = Vector2(0, option_button_height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_override("font", pixel_font)
	button.add_theme_font_size_override("font_size", 10)

	var is_unaffordable: bool = player == null or player.gold < cost
	button.set_meta("unaffordable", is_unaffordable)
	button.disabled = false

	button.pressed.connect(func() -> void:
		_attempt_upgrade(player_id, upgrade_name, cost)
	)

	_add_button_row(container, button)
	_register_option_button(player_id, button)


func _add_buy_button(player_id: int, container: VBoxContainer, weapon_scene: PackedScene) -> void:
	var player := _get_player_by_id(player_id)
	if weapon_scene == null:
		return
	var item_name := _get_weapon_display_name(weapon_scene)
	var cost := _get_weapon_price(weapon_scene)

	var button := Button.new()
	button.text = item_name
	button.custom_minimum_size = Vector2(0, option_button_height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_override("font", pixel_font)
	button.add_theme_font_size_override("font_size", 8)

	var is_owned: bool = player != null and player.has_method("has_weapon_scene") and player.has_weapon_scene(weapon_scene)
	var is_unaffordable: bool = player == null or player.gold < cost

	button.disabled = is_owned
	button.set_meta("unaffordable", is_unaffordable and not is_owned)

	button.pressed.connect(func() -> void:
		_attempt_purchase(player_id, weapon_scene)
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
	if player_id == 1 and p1_just_opened:
		p1_just_opened = false
		return
	if player_id == 2 and p2_just_opened:
		p2_just_opened = false
		return

	var prefix := "p1_" if player_id == 1 else "p2_"

	if Input.is_action_just_pressed(prefix + "up"):
		_move_selection(player_id, -1)
	elif Input.is_action_just_pressed(prefix + "down"):
		_move_selection(player_id, 1)

	if Input.is_action_just_pressed(prefix + "interact"):
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
		var mode := p1_current_mode if player_id == 1 else p2_current_mode
		if mode.to_lower() == "upgrade":
			_show_default_preview(player_id)
		else:
			_clear_preview(player_id)
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
		var base_tint := _get_shop_button_tint(button)
		if i == selected_index:
			button.modulate = base_tint * Color(1.0, 0.95, 0.65, 1.0)
		else:
			button.modulate = base_tint

	var selected_button := buttons[selected_index]
	if selected_button != null and is_instance_valid(selected_button):
		var options_scroll := p1_options_scroll if player_id == 1 else p2_options_scroll
		if options_scroll != null:
			options_scroll.ensure_control_visible(selected_button)

	_update_selected_weapon_preview(player_id)


func _get_shop_button_tint(button: Button) -> Color:
	if button == null:
		return Color(1.0, 1.0, 1.0, 1.0)
	if button.has_meta("unaffordable") and bool(button.get_meta("unaffordable")):
		return Color(1.0, 0.4, 0.4, 1.0)
	return Color(1.0, 1.0, 1.0, 1.0)


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
		"+20 Max HP":
			stats["max_health"] = int(stats.get("max_health", 100)) + 20
			stats["health"] = int(stats.get("health", 100)) + 20
			if player.has_method("_update_health_ui"):
				player._update_health_ui()

		"+10 Speed":
			stats["speed"] = float(stats.get("speed", player.speed)) + 10.0

		_:
			push_warning("Unknown upgrade: " + upgrade_name)

	populate_ui_for_player(player_id, true)


func _attempt_purchase(player_id: int, weapon_scene: PackedScene) -> void:
	var player := _get_player_by_id(player_id)
	if player == null:
		return
	if weapon_scene == null:
		return

	var item_name := _get_weapon_display_name(weapon_scene)
	var cost := _get_weapon_price(weapon_scene)

	if player.has_method("has_weapon_scene") and player.has_weapon_scene(weapon_scene):
		return

	if player.gold < cost:
		return

	player.gold -= cost
	if player.has_method("_update_coin_ui"):
		player._update_coin_ui()

	if player.has_method("add_weapon_scene_to_inventory"):
		var added: bool = player.add_weapon_scene_to_inventory(weapon_scene, true)
		if not added:
			push_warning("Failed to purchase weapon scene: " + item_name)
			player.gold += cost
			if player.has_method("_update_coin_ui"):
				player._update_coin_ui()
			return
	elif player.has_method("equip_weapon_scene"):
		player.equip_weapon_scene(weapon_scene)
	else:
		push_warning("Player cannot equip purchased weapon: " + item_name)
		player.gold += cost
		if player.has_method("_update_coin_ui"):
			player._update_coin_ui()
		return

	populate_ui_for_player(player_id, true)


func _add_dash_upgrade_buttons(player_id: int, container: VBoxContainer) -> void:
	var player := _get_player_by_id(player_id)
	if player == null:
		return

	if not Global.player_stats.has(player_id):
		return

	var stats: Dictionary = Global.player_stats[player_id]
	var dashes_max: int = int(stats.get("dashes_max", 0))
	var cost: int = _get_dash_upgrade_cost(dashes_max)

	# Allow purchasing up to 3 dash upgrades
	if dashes_max < 3:
		var button := Button.new()
		var charge_num := dashes_max + 1
		button.text = "+1 Dash (" + str(charge_num - 1) + "->" + str(charge_num) + ")"
		button.custom_minimum_size = Vector2(0, option_button_height)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.add_theme_font_size_override("font_size", 10)
		button.add_theme_font_override("font", pixel_font)

		var is_unaffordable: bool = player.gold < cost
		button.set_meta("unaffordable", is_unaffordable)
		button.disabled = false

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

	populate_ui_for_player(player_id, true)


func _build_displayed_weapon_list(player: CharacterBody2D) -> Array[PackedScene]:
	var result: Array[PackedScene] = []
	for weapon_scene in current_weapon_offers:
		if weapon_scene == null:
			continue
		if not result.has(weapon_scene):
			result.append(weapon_scene)

	for weapon_scene in _get_owned_weapon_scenes(player):
		if weapon_scene == null:
			continue
		if not result.has(weapon_scene):
			result.append(weapon_scene)

	return result


func _get_owned_weapon_scenes(player: CharacterBody2D) -> Array[PackedScene]:
	var owned_scenes: Array[PackedScene] = []
	if player == null:
		return owned_scenes
	if not ("inventory" in player):
		return owned_scenes

	var inventory: Array = player.inventory
	for weapon_key_var in inventory:
		var weapon_key := String(weapon_key_var)
		var weapon_scene := _get_player_weapon_scene_by_key(player, weapon_key)
		if weapon_scene == null:
			continue
		if not owned_scenes.has(weapon_scene):
			owned_scenes.append(weapon_scene)

	return owned_scenes


func _get_player_weapon_scene_by_key(player: CharacterBody2D, weapon_key: String) -> PackedScene:
	if player != null and player.has_method("get_weapon_scene_for_key"):
		return player.call("get_weapon_scene_for_key", weapon_key) as PackedScene
	return null


func _get_dash_upgrade_cost(current_dashes_max: int) -> int:
	if current_dashes_max <= 1:
		return 40
	return 60


func _get_player_by_id(player_id: int) -> CharacterBody2D:
	if player_id == 1:
		return p1_current_player
	elif player_id == 2:
		return p2_current_player
	return null


func _get_power_range_for_duels(duels_occurred: int) -> Vector2i:
	if duels_occurred <= 0:
		return Vector2i(1, 1)
	if duels_occurred == 1:
		return Vector2i(1, 2)
	if duels_occurred == 2:
		return Vector2i(2, 3)
	if duels_occurred == 3:
		return Vector2i(2, 3)
	if duels_occurred == 4:
		return Vector2i(2, 3)
	if duels_occurred == 4:
		return Vector2i(3, 3)
	return Vector2i(2, 4)


func _get_weapon_display_name(weapon_scene: PackedScene) -> String:
	if weapon_scene == null:
		return "Unknown"
	var path := weapon_scene.resource_path
	if path.is_empty():
		return "Weapon"
	var file_name := path.get_file().get_basename()
	var pretty := file_name.replace("_", " ")
	return pretty.capitalize()


func _get_weapon_price(weapon_scene: PackedScene) -> int:
	var shop_data := _get_weapon_shop_data(weapon_scene)
	return int(shop_data.get("price", 0))


func _update_selected_weapon_preview(player_id: int) -> void:
	var mode := p1_current_mode if player_id == 1 else p2_current_mode
	if mode.to_lower() == "upgrade":
		_update_selected_upgrade_preview(player_id)
		return
	if mode.to_lower() != "buy":
		_show_default_preview(player_id)
		return

	var displayed_weapons := p1_displayed_weapons if player_id == 1 else p2_displayed_weapons
	var selected_index := p1_selected_index if player_id == 1 else p2_selected_index
	if selected_index < 0 or selected_index >= displayed_weapons.size():
		_clear_preview(player_id)
		return

	var weapon_scene := displayed_weapons[selected_index]
	if weapon_scene == null:
		_clear_preview(player_id)
		return

	var shop_data := _get_weapon_shop_data(weapon_scene)
	var preview := p1_item_preview if player_id == 1 else p2_item_preview
	var price_label := p1_price_label if player_id == 1 else p2_price_label
	var desc_label := p1_desc_label if player_id == 1 else p2_desc_label
	var stats_label := p1_stats_label if player_id == 1 else p2_stats_label
	var player := _get_player_by_id(player_id)
	var is_owned := false
	if player != null and player.has_method("has_weapon_scene"):
		is_owned = player.has_weapon_scene(weapon_scene)

	preview.texture = shop_data.get("icon", null)
	price_label.text = "Owned" if is_owned else str(int(shop_data.get("price", 0)))
	desc_label.text = String(shop_data.get("description", ""))
	stats_label.text = "%d\n%d\n%s\n%ss" % [
		int(shop_data.get("damage", 0)),
		int(shop_data.get("clip_size", 0)),
		_format_decimal(float(shop_data.get("fire_rate", 0.0))),
		_format_decimal(float(shop_data.get("reload_time", 0.0))),
	]

func _update_selected_upgrade_preview(player_id: int) -> void:
	var buttons := p1_option_buttons if player_id == 1 else p2_option_buttons
	var selected_index := p1_selected_index if player_id == 1 else p2_selected_index
	var price_label := p1_price_label if player_id == 1 else p2_price_label
	var desc_label := p1_desc_label if player_id == 1 else p2_desc_label
	var player := _get_player_by_id(player_id)

	if selected_index < 0 or selected_index >= buttons.size():
		_show_default_preview(player_id)
		return

	var button := buttons[selected_index]
	if button == null or not is_instance_valid(button):
		_show_default_preview(player_id)
		return

	var matched_key := ""
	for key in upgrade_data.keys():
		if button.text.begins_with(key) or button.text.contains(key.substr(0, 6)):
			matched_key = key
			break

	if matched_key.is_empty():
		if button.text.contains("Dash"):
			matched_key = "+1 Dash"

	if matched_key.is_empty():
		_show_default_preview(player_id)
		return

	_show_default_preview(player_id)

	if matched_key == "+1 Dash" and player != null and Global.player_stats.has(player_id):
		var stats: Dictionary = Global.player_stats[player_id]
		var dashes_max: int = int(stats.get("dashes_max", 0))
		price_label.text = str(_get_dash_upgrade_cost(dashes_max))
		desc_label.text = String(upgrade_data[matched_key]["description"])
		return

	var data: Dictionary = upgrade_data[matched_key]
	price_label.text = str(data["cost"])
	desc_label.text = data["description"]

func _clear_preview(player_id: int) -> void:
	var preview := p1_item_preview if player_id == 1 else p2_item_preview
	var price_label := p1_price_label if player_id == 1 else p2_price_label
	var desc_label := p1_desc_label if player_id == 1 else p2_desc_label
	var stats_label := p1_stats_label if player_id == 1 else p2_stats_label
	preview.texture = null
	price_label.text = ""
	desc_label.text = ""
	stats_label.text = ""


func _set_stats_labels_visible(player_id: int, visible: bool) -> void:
	var stats_title_label := p1_stats_title_label if player_id == 1 else p2_stats_title_label
	var stats_value_label := p1_stats_label if player_id == 1 else p2_stats_label
	stats_title_label.visible = visible
	stats_value_label.visible = visible


func _show_default_preview(player_id: int) -> void:
	var preview := p1_item_preview if player_id == 1 else p2_item_preview
	var price_label := p1_price_label if player_id == 1 else p2_price_label
	var desc_label := p1_desc_label if player_id == 1 else p2_desc_label
	var stats_label := p1_stats_label if player_id == 1 else p2_stats_label
	var default_texture := p1_default_preview_texture if player_id == 1 else p2_default_preview_texture
	preview.texture = default_texture
	price_label.text = ""
	desc_label.text = ""
	stats_label.text = ""


func _get_weapon_shop_data(weapon_scene: PackedScene) -> Dictionary:
	if weapon_scene == null:
		return {"price": 0, "description": "", "icon": null}
	var weapon_instance := weapon_scene.instantiate()
	if weapon_instance == null:
		return {"price": 0, "description": "", "icon": null}

	var price := 0
	if "price" in weapon_instance:
		price = int(weapon_instance.price)
	var description := ""
	if "description" in weapon_instance:
		description = String(weapon_instance.description)
	var icon: Texture2D = null
	if "shop_icon" in weapon_instance:
		icon = weapon_instance.shop_icon
	var damage := 0
	if "damage" in weapon_instance:
		damage = int(weapon_instance.damage)
	var clip_size := 0
	if "max_ammo" in weapon_instance:
		clip_size = int(weapon_instance.max_ammo)
	var fire_rate := 0.0
	if "fire_rate" in weapon_instance:
		fire_rate = float(weapon_instance.fire_rate)
	var reload_time := 0.0
	if "reload_time" in weapon_instance:
		reload_time = float(weapon_instance.reload_time)
	weapon_instance.queue_free()
	return {
		"price": max(price, 0),
		"description": description,
		"icon": icon,
		"damage": max(damage, 0),
		"clip_size": max(clip_size, 0),
		"fire_rate": max(fire_rate, 0.0),
		"reload_time": max(reload_time, 0.0),
	}


func _format_decimal(value: float) -> String:
	return str(snappedf(value, 0.01)).trim_suffix("0").trim_suffix(".")
