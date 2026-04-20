extends CanvasLayer

@onready var root: Control = $Root
@onready var prompt_label: Label = $Root/PromptLabel
@onready var main_panel: Panel = $Root/MainPanel
@onready var title_label: Label = $Root/MainPanel/TitleLabel
@onready var gold_label: Label = $Root/MainPanel/GoldLabel
@onready var options_container: VBoxContainer = $Root/MainPanel/OptionsContainer
@onready var close_button: Button = $Root/MainPanel/CloseButton

var current_mode: String = ""
var current_player: CharacterBody2D = null


func _ready() -> void:
	prompt_label.visible = false
	main_panel.visible = false
	close_button.pressed.connect(_on_close_button_pressed)


func show_prompt(text: String) -> void:
	if main_panel.visible:
		return
	prompt_label.text = text
	prompt_label.visible = true


func hide_prompt() -> void:
	prompt_label.visible = false


func open_ui(mode: String, player: CharacterBody2D) -> void:
	current_mode = mode
	current_player = player

	hide_prompt()
	main_panel.visible = true

	if current_player != null:
		current_player.can_move = false
		current_player.can_attack = false

	populate_ui()


func close_ui() -> void:
	main_panel.visible = false
	current_mode = ""
	current_player = null


func populate_ui() -> void:
	_clear_options()

	_update_gold_label()

	match current_mode:
		"upgrade":
			title_label.text = "Upgrade Station"
			_add_upgrade_button("Increase Max Health", 20)
			_add_upgrade_button("Increase Attack Damage", 30)
			_add_upgrade_button("Increase Speed", 25)

		"buy":
			title_label.text = "Buy Station"
			_add_buy_button("Health Potion", 15)
			_add_buy_button("Battle Axe", 40)
			_add_buy_button("Dash Charm", 35)

		_:
			title_label.text = "Shop"


func _clear_options() -> void:
	for child in options_container.get_children():
		child.queue_free()


func _update_gold_label() -> void:
	if current_player == null:
		gold_label.text = "Gold: ?"
		return

	if "gold" in current_player:
		gold_label.text = "Gold: " + str(current_player.gold)
	else:
		gold_label.text = "Gold: 0"


func _add_upgrade_button(upgrade_name: String, cost: int) -> void:
	var button := Button.new()
	button.text = upgrade_name + " - " + str(cost) + " gold"

	if current_player == null or not ("gold" in current_player) or current_player.gold < cost:
		button.disabled = true

	button.pressed.connect(func() -> void:
		_attempt_upgrade(upgrade_name, cost)
	)

	options_container.add_child(button)


func _add_buy_button(item_name: String, cost: int) -> void:
	var button := Button.new()
	button.text = item_name + " - " + str(cost) + " gold"

	if current_player == null or not ("gold" in current_player) or current_player.gold < cost:
		button.disabled = true

	button.pressed.connect(func() -> void:
		_attempt_purchase(item_name, cost)
	)

	options_container.add_child(button)


func _attempt_upgrade(upgrade_name: String, cost: int) -> void:
	if current_player == null:
		return

	if not ("gold" in current_player):
		push_warning("Current player has no gold variable.")
		return

	if current_player.gold < cost:
		return

	current_player.gold -= cost

	match upgrade_name:
		"Increase Max Health":
			current_player.max_health += 10
			current_player.health += 10

		"Increase Attack Damage":
			current_player.attack_damage += 5

		"Increase Speed":
			current_player.speed += 10.0

		_:
			push_warning("Unknown upgrade: " + upgrade_name)

	populate_ui()


func _attempt_purchase(item_name: String, cost: int) -> void:
	if current_player == null:
		return

	if not ("gold" in current_player):
		push_warning("Current player has no gold variable.")
		return

	if current_player.gold < cost:
		return

	current_player.gold -= cost

	if not ("inventory" in current_player):
		push_warning("Current player has no inventory variable.")
		populate_ui()
		return

	match item_name:
		"Health Potion":
			current_player.inventory.append("health_potion")

		"Battle Axe":
			current_player.inventory.append("battle_axe")

		"Dash Charm":
			current_player.inventory.append("dash_charm")

		_:
			push_warning("Unknown item: " + item_name)

	populate_ui()


func _on_close_button_pressed() -> void:
	if current_player != null:
		if current_player.has_method("close_shop_ui"):
			current_player.close_shop_ui()
		else:
			current_player.can_move = true
			main_panel.visible = false
			current_mode = ""
			current_player = null


func _unhandled_input(event: InputEvent) -> void:
	if main_panel.visible and event.is_action_pressed("ui_cancel"):
		_on_close_button_pressed()
