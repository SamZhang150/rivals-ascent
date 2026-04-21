extends Control

@onready var p1_shop_ui: Control = $Root/P1ShopUI
@onready var p1_main_panel: Panel = $Root/P1ShopUI/MainPanel
@onready var p1_title_label: Label = $Root/P1ShopUI/MainPanel/TitleLabel
@onready var p1_gold_label: Label = $Root/P1ShopUI/MainPanel/GoldLabel
@onready var p1_options_scroll: ScrollContainer = $Root/P1ShopUI/MainPanel/OptionsScroll
@onready var p1_options_container: VBoxContainer = $Root/P1ShopUI/MainPanel/OptionsScroll/OptionsContainer
@onready var p1_close_button: Button = $Root/P1ShopUI/MainPanel/CloseButton

@onready var p2_shop_ui: Control = $Root/P2ShopUI
@onready var p2_main_panel: Panel = $Root/P2ShopUI/MainPanel
@onready var p2_title_label: Label = $Root/P2ShopUI/MainPanel/TitleLabel
@onready var p2_gold_label: Label = $Root/P2ShopUI/MainPanel/GoldLabel
@onready var p2_options_scroll: ScrollContainer = $Root/P2ShopUI/MainPanel/OptionsScroll
@onready var p2_options_container: VBoxContainer = $Root/P2ShopUI/MainPanel/OptionsScroll/OptionsContainer
@onready var p2_close_button: Button = $Root/P2ShopUI/MainPanel/CloseButton

var p1_current_mode: String = ""
var p2_current_mode: String = ""

var p1_current_player: CharacterBody2D = null
var p2_current_player: CharacterBody2D = null


func _ready() -> void:
	p1_main_panel.visible = false
	p2_main_panel.visible = false

	p1_close_button.pressed.connect(_on_p1_close_button_pressed)
	p2_close_button.pressed.connect(_on_p2_close_button_pressed)

	# Optional: tighter spacing between option buttons
	p1_options_container.add_theme_constant_override("separation", 6)
	p2_options_container.add_theme_constant_override("separation", 6)


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
		_clear_options(p1_options_container)
	elif player_id == 2:
		p2_main_panel.visible = false
		p2_current_mode = ""
		p2_current_player = null
		_clear_options(p2_options_container)


func close_ui() -> void:
	p1_main_panel.visible = false
	p2_main_panel.visible = false

	p1_current_mode = ""
	p2_current_mode = ""

	p1_current_player = null
	p2_current_player = null

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
	else:
		player = p2_current_player
		mode = p2_current_mode
		title_label = p2_title_label
		gold_label = p2_gold_label
		options_container = p2_options_container
		options_scroll = p2_options_scroll

	_clear_options(options_container)
	_update_gold_label(player, gold_label)

	match mode:
		"upgrade":
			title_label.text = "Upgrade"
			_add_upgrade_button(player_id, options_container, "Increase Max Health", 20)
			_add_upgrade_button(player_id, options_container, "Increase Attack Damage", 30)
			_add_upgrade_button(player_id, options_container, "Increase Speed", 25)

		"buy":
			title_label.text = "Buy"
			_add_buy_button(player_id, options_container, "Health Potion", 15)
			_add_buy_button(player_id, options_container, "Battle Axe", 40)
			_add_buy_button(player_id, options_container, "Dash Charm", 35)

		_:
			title_label.text = "Shop"

	# Reset scroll to top whenever menu refreshes
	if options_scroll != null:
		options_scroll.scroll_vertical = 0


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
	button.custom_minimum_size = Vector2(0, 24)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if player == null or player.gold < cost:
		button.disabled = true

	button.pressed.connect(func() -> void:
		_attempt_upgrade(player_id, upgrade_name, cost)
	)

	container.add_child(button)


func _add_buy_button(player_id: int, container: VBoxContainer, item_name: String, cost: int) -> void:
	var player := _get_player_by_id(player_id)

	var button := Button.new()
	button.text = item_name + " - " + str(cost) + "g"
	button.custom_minimum_size = Vector2(0, 24)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if player == null or player.gold < cost:
		button.disabled = true

	button.pressed.connect(func() -> void:
		_attempt_purchase(player_id, item_name, cost)
	)

	container.add_child(button)


func _attempt_upgrade(player_id: int, upgrade_name: String, cost: int) -> void:
	var player := _get_player_by_id(player_id)
	if player == null:
		return

	if player.gold < cost:
		return

	player.gold -= cost

	match upgrade_name:
		"Increase Max Health":
			player.max_health += 10
			player.health += 10

		"Increase Attack Damage":
			player.attack_damage += 5

		"Increase Speed":
			player.speed += 10.0

		_:
			push_warning("Unknown upgrade: " + upgrade_name)

	populate_ui_for_player(player_id)


func _attempt_purchase(player_id: int, item_name: String, cost: int) -> void:
	var player := _get_player_by_id(player_id)
	if player == null:
		return

	if player.gold < cost:
		return

	player.gold -= cost

	match item_name:
		"Health Potion":
			player.inventory.append("health_potion")

		"Battle Axe":
			player.inventory.append("battle_axe")

		"Dash Charm":
			player.inventory.append("dash_charm")

		_:
			push_warning("Unknown item: " + item_name)

	populate_ui_for_player(player_id)


func _get_player_by_id(player_id: int) -> CharacterBody2D:
	if player_id == 1:
		return p1_current_player
	elif player_id == 2:
		return p2_current_player
	return null


func _on_p1_close_button_pressed() -> void:
	if p1_current_player != null and p1_current_player.has_method("close_shop_ui"):
		p1_current_player.close_shop_ui()


func _on_p2_close_button_pressed() -> void:
	if p2_current_player != null and p2_current_player.has_method("close_shop_ui"):
		p2_current_player.close_shop_ui()
