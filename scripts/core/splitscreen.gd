## game_manager.gd
## Attach to the root "Main" node of main.tscn
##
## === MAIN.TSCN NODE TREE ===
## Main (Node2D)                        [script: game_manager.gd]
## ├── World (Node2D)                   ← shared game world, all rooms are children
## ├── ScreenDisplay (CanvasLayer)
## |   |   ViewportContainer (HBoxContainer) [full_rect anchors, mouse_filter=Ignore]
## │   |   ├── Left (SubViewportContainer)  [stretch=true, size_flags_horizontal=EXPAND_FILL]
## │   |   │   └── SubViewport              [size: half screen, world_2d: assign in code]
## │   |   └── Right (SubViewportContainer) [stretch=true, size_flags_horizontal=EXPAND_FILL]
## │   |  	   └── SubViewport              [size: half screen, world_2d: assign in code]
## └── UI (CanvasLayer)
##     ├── ReadyUpUI (Control)          [visible=false, full_rect]
##     │   ├── P1ReadyLabel (Label)
##     │   ├── P2ReadyLabel (Label)
##     │   └── Instructions (Label)     [text: "P1: Enter | P2: Numpad Enter"]
##     ├── ShopUI (Control)             [visible=false, full_rect]
##     └── RoundOverUI (Control)        [visible=false, full_rect]
##         ├── WinnerLabel (Label)
##         └── ScoreLabel (Label)

extends Node2D

# ─── ENUMS ───────────────────────────────────────────────
enum Phase { LOBBY, DUNGEON, SHOP_WAITING, SHOP, PVP, ROUND_END, GAME_OVER }
enum ScreenMode { SPLIT, SHARED }

# ─── EXPORTED ────────────────────────────────────────────
@export var dungeon_pool: DungeonPool  # assign dungeon_pool.tres in inspector
@export var lobby_room_scene: PackedScene    # assign lobby_room.tscn
@export var shop_room_scene: PackedScene     # assign shop_room.tscn
@export var pvp_room_scene: PackedScene      # assign pvp_room.tscn
@export var player_scene: PackedScene        # assign player.tscn

# ─── NODE REFERENCES ────────────────────────────────────
@onready var world: Node2D = $World
@onready var left_container: SubViewportContainer = $ScreenDisplay/ViewportContainer/Left
@onready var right_container: SubViewportContainer = $ScreenDisplay/ViewportContainer/Right
@onready var left_viewport: SubViewport = $ScreenDisplay/ViewportContainer/Left/SubViewport
@onready var right_viewport: SubViewport = $ScreenDisplay/ViewportContainer/Right/SubViewport
@onready var ready_up_ui: Control = $UI/ReadyUpUI
@onready var countdown_label: Label = $UI/ReadyUpUI/CountdownLabel
@onready var shop_ui: Control = $UI/ShopUI
@onready var round_over_ui: Control = $UI/RoundOverUI
@onready var duel_score_ui: Control = $UI/DuelScoreUI
@onready var p1_score_label: Label = $UI/DuelScoreUI/P1ScoreLabel
@onready var p2_score_label: Label = $UI/DuelScoreUI/P2ScoreLabel
@onready var duel_point_popup: Label = $UI/DuelScoreUI/DuelPointPopup
@onready var game_over_ui: Control = $UI/GameOverUI
@onready var game_over_title: Label = $UI/GameOverUI/Panel/TitleLabel
@onready var game_over_winner: Label = $UI/GameOverUI/Panel/WinnerLabel
@onready var game_over_score: Label = $UI/GameOverUI/Panel/FinalScoreLabel
@onready var game_over_restart: Label = $UI/GameOverUI/Panel/RestartLabel


var phase: Phase = Phase.LOBBY
var p1: CharacterBody2D
var p2: CharacterBody2D
var p1_wins: int = 0
var p2_wins: int = 0
var current_round: int = 0
var p1_ready: bool = false
var p2_ready: bool = false
var p1_room_index: int = 0
var p2_room_index: int = 0
var p1_finished_dungeon: bool = false
var p2_finished_dungeon: bool = false
var duel_resolved: bool = false
var ready_countdown_timer: Timer
var ready_countdown_remaining: int = 0
var ready_countdown_active: bool = false
var ready_countdown_target_phase: Phase = Phase.DUNGEON

const DUELS_TO_WIN := 3

# Room spacing in world coordinates
const ROOM_SPACING := 1000.0

# Room instance references
var lobby_instance: Node2D
var shop_instance: Node2D
var pvp_instance: Node2D
var p1_dungeon_rooms: Array[Node2D] = []
var p2_dungeon_rooms: Array[Node2D] = []

var difficulty_curves: Array = [
	[1, 1, 2, 2],
	[2, 2, 3, 3],
	[2, 2, 3, 3],
	[3, 3, 3, 3],
	[3, 3, 3, 3],
]

func _get_difficulty_curve() -> Array:
	var index = mini(current_round, difficulty_curves.size() - 1)
	return difficulty_curves[index]

func _ready():
	# Make both viewports render the same world
	left_viewport.world_2d = world.get_world_2d()
	right_viewport.world_2d = world.get_world_2d()
	ready_countdown_timer = Timer.new()
	ready_countdown_timer.wait_time = 1.0
	ready_countdown_timer.one_shot = false
	ready_countdown_timer.timeout.connect(_on_ready_countdown_tick)
	add_child(ready_countdown_timer)
	countdown_label.text = ""
	_set_screen_mode(ScreenMode.SPLIT)
	_spawn_players()
	reset_match_state()
	_transition_to(Phase.LOBBY)

func _process(_delta: float):
	if phase == Phase.LOBBY and lobby_instance:
		var lobby_spawn = lobby_instance.get_node("SpawnPoint") as Marker2D
		if lobby_spawn:
			_center_viewport_on(left_viewport, lobby_spawn.global_position, lobby_instance)
		return

	if phase == Phase.SHOP and shop_instance:
		var shop_spawn = shop_instance.get_node("SpawnPoint") as Marker2D
		if shop_spawn:
			_center_viewport_on(left_viewport, shop_spawn.global_position, shop_instance)
		return

	if phase == Phase.PVP and pvp_instance:
		var pvp_spawn = pvp_instance.get_node("SpawnPoint") as Marker2D
		if pvp_spawn:
			_center_viewport_on(left_viewport, pvp_spawn.global_position, pvp_instance)
		return

	if p1:
		if phase == Phase.SHOP_WAITING and p1_finished_dungeon and shop_instance:
			_center_viewport_on(left_viewport, p1.global_position, shop_instance)
		elif p1_room_index >= 0 and p1_room_index < p1_dungeon_rooms.size():
			_center_viewport_on(left_viewport, p1.global_position, p1_dungeon_rooms[p1_room_index])
	if p2:
		if phase == Phase.SHOP_WAITING and p2_finished_dungeon and shop_instance:
			_center_viewport_on(right_viewport, p2.global_position, shop_instance)
		elif p2_room_index >= 0 and p2_room_index < p2_dungeon_rooms.size():
			_center_viewport_on(right_viewport, p2.global_position, p2_dungeon_rooms[p2_room_index])
		
func _center_viewport_on(vp: SubViewport, target_pos: Vector2, room: Node2D) -> void:
	if room == null:
		return
		
	## print("room=", room.name, " top_left=", room.get_node_or_null("CamTopLeft"), " bottom_right=", room.get_node_or_null("CamBottomRight"))

	var top_left: Marker2D = room.get_node_or_null("CamTopLeft") as Marker2D
	var bottom_right := room.get_node_or_null("CamBottomRight") as Marker2D
		
	var half_size := Vector2(vp.size) / 2.0

	var clamped_x = clamp(
		target_pos.x,
		top_left.global_position.x + half_size.x,
		bottom_right.global_position.x - half_size.x
	)

	var clamped_y = clamp(
		target_pos.y,
		top_left.global_position.y + half_size.y,
		bottom_right.global_position.y - half_size.y
	)

	var clamped_target := Vector2(clamped_x, clamped_y)
	var offset := clamped_target - half_size
	vp.canvas_transform = Transform2D(0.0, -offset)


func _unhandled_input(event: InputEvent):
	# Ready-up handling
	if phase == Phase.LOBBY or phase == Phase.SHOP:
		if event.is_action_pressed("p1_ready"):
			p1_ready = !p1_ready
			if p1_ready:
				$Ready.play(1.5)
			else:
				$Unready.play()
			_update_ready_ui()
			_check_both_ready()
		if event.is_action_pressed("p2_ready"):
			p2_ready = !p2_ready
			if p2_ready:
				$Ready.play(1.5)
			else:
				$Unready.play()
			_update_ready_ui()
			_check_both_ready()


# ─── SCREEN MODE ─────────────────────────────────────────
func _set_screen_mode(mode: ScreenMode):
	match mode:
		ScreenMode.SPLIT:
			left_container.visible = true
			right_container.visible = true
			left_viewport.size = Vector2i(224, 252)
			right_viewport.size = Vector2i(224, 252)
		ScreenMode.SHARED:
			left_container.visible = true
			right_container.visible = false
			# Full logical width when taking the whole screen
			left_viewport.size = Vector2i(448, 252)


# ─── PLAYER SPAWNING ────────────────────────────────────
func _spawn_players():
	p1 = player_scene.instantiate() as CharacterBody2D
	p1.name = "Player1"
	p1.player_id = 1                    # set BEFORE add_child
	p1.health_ui = $UI/HealthUILeft
	p1.coin_ui = $UI/CoinUILeft
	p1.ammo_ui = $UI/AmmoUILeft
	p1.set_meta("player_id", 1)
	world.add_child(p1)                 # _ready() fires here

	p2 = player_scene.instantiate() as CharacterBody2D
	p2.name = "Player2"
	p2.player_id = 2                    # set BEFORE add_child
	p2.health_ui = $UI/HealthUIRight
	p2.coin_ui = $UI/CoinUIRight
	p2.ammo_ui = $UI/AmmoUIRight
	p2.set_meta("player_id", 2)
	world.add_child(p2)


# ─── STATE TRANSITIONS ──────────────────────────────────
func reset_match_state() -> void:
	p1_wins = 0
	p2_wins = 0
	current_round = 0
	duel_resolved = false
	p1_ready = false
	p2_ready = false
	p1_room_index = 0
	p2_room_index = 0
	p1_finished_dungeon = false
	p2_finished_dungeon = false
	_sync_player_ready_states()
	_update_duel_score_ui()
	
	if game_over_ui:
		game_over_ui.visible = false

func _transition_to(new_phase: Phase):
	phase = new_phase
	p1_ready = false
	p2_ready = false
	_sync_player_ready_states()
	_cancel_ready_countdown()
	_hide_all_ui()
	
	

	match phase:
		Phase.LOBBY:
			_clear_rooms()
			
			p1.set_phase_state(true, true, false)
			p2.set_phase_state(true, true, false)
			
			lobby_instance = _place_room(lobby_room_scene, Vector2.ZERO)
			_set_screen_mode(ScreenMode.SHARED)
			var spawn = lobby_instance.get_node("SpawnPoint") as Marker2D
			p1.respawn_at(spawn.global_position + Vector2(-40, 0))
			p2.respawn_at(spawn.global_position + Vector2(40, 0))
			_enable_players(true)
			_set_players_combat(false)
			ready_up_ui.visible = true
			_update_ready_ui()
			

		Phase.DUNGEON:
			_clear_rooms()
			
			p1.set_phase_state(false, true, true)
			p2.set_phase_state(false, true, true)
			
			_set_screen_mode(ScreenMode.SPLIT)
			p1_room_index = 0
			p2_room_index = 0
			p1_finished_dungeon = false
			p2_finished_dungeon = false
			_generate_dungeon_rooms()
			_teleport_to_dungeon_room(1, 0)
			_teleport_to_dungeon_room(2, 0)
			_enable_players(true)

		Phase.SHOP_WAITING:
			# One player is in shop, other still in dungeon
			# Stay splitscreen
			_set_screen_mode(ScreenMode.SPLIT)
			# Only the player who reached shop should be safe from dungeon damage.
			if p1_finished_dungeon:
				p1.set_phase_state(false, false, false)
			else:
				p1.set_phase_state(false, true, true)

			if p2_finished_dungeon:
				p2.set_phase_state(false, false, false)
			else:
				p2.set_phase_state(false, true, true)
			if shop_ui and shop_ui.has_method("refresh_weapon_offers"):
				shop_ui.refresh_weapon_offers(current_round)
			shop_ui.visible = true

		Phase.SHOP:
			_set_screen_mode(ScreenMode.SHARED)
			
			p1.set_phase_state(false, false, false)
			p2.set_phase_state(false, false, false)
			if shop_ui and shop_ui.has_method("refresh_weapon_offers"):
				shop_ui.refresh_weapon_offers(current_round)
			
			if not shop_instance:
				shop_instance = _place_room(shop_room_scene, Vector2(ROOM_SPACING * 5, 0))
			var spawn = shop_instance.get_node("SpawnPoint") as Marker2D
			# In SHOP_WAITING, players are already teleported to the shop as they finish dungeon rooms.
			# Avoid relocating the player who is already shopping when the other player arrives.
			if not p1_finished_dungeon:
				p1.teleport_to_position(spawn.global_position + Vector2(-40, 0))
			if not p2_finished_dungeon:
				p2.teleport_to_position(spawn.global_position + Vector2(40, 0))
			shop_ui.visible = true
			ready_up_ui.visible = true
			_update_ready_ui()

		Phase.PVP:
			duel_resolved = false
			_set_screen_mode(ScreenMode.SHARED)
			p1.reset_for_round()
			p2.reset_for_round()
			p1.set_phase_state(true, true, false)
			p2.set_phase_state(true, true, false)
			
			pvp_instance = _place_room(pvp_room_scene, Vector2(ROOM_SPACING * 6, 0))
			var spawn = pvp_instance.get_node("SpawnPoint") as Marker2D
			p1.teleport_to_position(spawn.global_position + Vector2(-80, 0))
			p2.teleport_to_position(spawn.global_position + Vector2(80, 0))
			_enable_players(true)
			_set_players_combat(true)
			# Start a countdown timer here if desired

		Phase.ROUND_END:
			_enable_players(false)
			_set_players_combat(false)
			
			if p1_wins >= DUELS_TO_WIN:
				_transition_to(Phase.GAME_OVER)
			elif p2_wins >= DUELS_TO_WIN:
				_transition_to(Phase.GAME_OVER)
			else:
				round_over_ui.visible = true
				var winner_label = round_over_ui.get_node("WinnerLabel") as Label
				var score_label = round_over_ui.get_node("ScoreLabel") as Label

				winner_label.text = "Duel %d Complete" % current_round
				score_label.text = "Score: %d - %d" % [p1_wins, p2_wins]

				get_tree().create_timer(3.0).timeout.connect(
					func(): _transition_to(Phase.LOBBY)
				)
			#round_over_ui.visible = true
			#var winner_label = round_over_ui.get_node("WinnerLabel") as Label
			#var score_label = round_over_ui.get_node("ScoreLabel") as Label
			#score_label.text = "Score: %d - %d" % [p1_wins, p2_wins]
			#if p1_wins >= DUELS_TO_WIN:
				#winner_label.text = "Player 1 Wins the Match!"
				#phase = Phase.GAME_OVER
			#elif p2_wins >= DUELS_TO_WIN:
				#winner_label.text = "Player 2 Wins the Match!"
				#phase = Phase.GAME_OVER
			#else:
				#winner_label.text = "Round %d Complete" % current_round
				## Auto-advance after delay
				#get_tree().create_timer(3.0).timeout.connect(
					#func(): _transition_to(Phase.LOBBY)
				#)
			

		Phase.GAME_OVER:
			_enable_players(false)
			_set_players_combat(false)
			_set_screen_mode(ScreenMode.SHARED)
			
			var winner_id := 1 if p1_wins >= DUELS_TO_WIN else 2
			_show_game_over_screen(winner_id)
			#round_over_ui.visible = true


# ─── DUNGEON GENERATION ─────────────────────────────────
func _generate_dungeon_rooms():
	p1_dungeon_rooms.clear()
	p2_dungeon_rooms.clear()

	var curve = _get_difficulty_curve()

	for i in range(4):
		var difficulty: int = curve[i]

		# Player 1 gets a random room of this difficulty
		var p1_scene = dungeon_pool.get_room(difficulty)
		var p1_room = _place_room(
			p1_scene,
			Vector2(ROOM_SPACING * (i + 1), 0)
		)
		p1_room.name = "P1_Room_%d" % i
		if p1_room.has_signal("room_cleared"):
			p1_room.connect("room_cleared", _on_room_cleared.bind(1))
		else:
			push_warning("Room %s is missing 'room_cleared' signal" % p1_room.name)
		if p1_room.has_method("set_room_active"):
			p1_room.set_room_active(false)
		p1_dungeon_rooms.append(p1_room)

		# Player 2 gets an independently random room of the same difficulty
		var p2_scene = dungeon_pool.get_room(difficulty)
		var p2_room = _place_room(
			p2_scene,
			Vector2(ROOM_SPACING * (i + 1), ROOM_SPACING)
		)
		p2_room.name = "P2_Room_%d" % i
		if p2_room.has_signal("room_cleared"):
			p2_room.connect("room_cleared", _on_room_cleared.bind(2))
		else:
			push_warning("Room %s is missing 'room_cleared' signal" % p2_room.name)
		if p2_room.has_method("set_room_active"):
			p2_room.set_room_active(false)
		p2_dungeon_rooms.append(p2_room)


func _set_active_dungeon_room(player_id: int, room_index: int) -> void:
	var rooms = p1_dungeon_rooms if player_id == 1 else p2_dungeon_rooms
	var player = p1 if player_id == 1 else p2
	for i in range(rooms.size()):
		var room = rooms[i]
		if room == null or not is_instance_valid(room):
			continue
		if room.has_method("set_room_active"):
			room.set_room_active(i == room_index, player)


func _teleport_to_dungeon_room(player_id: int, room_index: int):
	var rooms = p1_dungeon_rooms if player_id == 1 else p2_dungeon_rooms
	var player = p1 if player_id == 1 else p2
	if room_index < rooms.size():
		_set_active_dungeon_room(player_id, room_index)
		var spawn = rooms[room_index].get_node("SpawnPoint") as Marker2D
		print("Teleporting P%d to room %d at %s" % [player_id, room_index, spawn.global_position])
		player.teleport_to_position(spawn.global_position)
		if room_index % 4 != 0:
			$Teleport.play()
		else:
			$Enter.play()
	else:
		print("ERROR: room_index %d out of range for P%d" % [player_id, room_index])


func _on_room_cleared(player_id: int):
	# Defer room transitions to avoid mutating physics objects during Area2D query flush.
	call_deferred("_handle_room_cleared", player_id)


func _handle_room_cleared(player_id: int):
	if player_id == 1:
		p1_room_index += 1
		if p1_room_index >= 4:
			_player_finished_dungeon(1)
		else:
			_teleport_to_dungeon_room(1, p1_room_index)
	else:
		p2_room_index += 1
		if p2_room_index >= 4:
			_player_finished_dungeon(2)
		else:
			_teleport_to_dungeon_room(2, p2_room_index)


func _player_finished_dungeon(player_id: int):
	if player_id == 1:
		p1_finished_dungeon = true
	else:
		p2_finished_dungeon = true
	_set_active_dungeon_room(player_id, -1)

	# Place shop if not already placed
	if not shop_instance:
		shop_instance = _place_room(shop_room_scene, Vector2(ROOM_SPACING * 5, 0))

	# Teleport finished player to shop
	var player = p1 if player_id == 1 else p2
	var spawn = shop_instance.get_node("SpawnPoint") as Marker2D
	player.teleport_to_position(spawn.global_position)

	if p1_finished_dungeon and p2_finished_dungeon:
		$Teleport.play()
		_transition_to(Phase.SHOP)
	else:
		$Teleport.play()
		_transition_to(Phase.SHOP_WAITING)


# ─── PVP RESOLUTION / LOBBY RESPAWN ────────────────────
func register_duel_result(loser_id: int) -> void:
	var winner_id := 2 if loser_id == 1 else 1
	
	if winner_id == 1:
		p1_wins += 1
	else:
		p2_wins += 1
	current_round += 1
	_update_duel_score_ui()
	_show_duel_point_popup(winner_id)
	
	await get_tree().create_timer(1.5).timeout
	_transition_to(Phase.ROUND_END)
	
func _show_duel_point_popup(winner_id: int) -> void:
	duel_point_popup.visible = true
	duel_point_popup.text = "PLAYER %d CLAIMS A DUEL POINT!" % winner_id

	duel_point_popup.scale = Vector2(0.6, 0.6)
	duel_point_popup.modulate.a = 0.0

	var tween = create_tween()
	tween.parallel().tween_property(duel_point_popup, "scale", Vector2(1.2, 1.2), 0.2)
	tween.parallel().tween_property(duel_point_popup, "modulate:a", 1.0, 0.2)
	tween.tween_interval(0.8)
	tween.parallel().tween_property(duel_point_popup, "scale", Vector2(1.0, 1.0), 0.2)
	tween.parallel().tween_property(duel_point_popup, "modulate:a", 0.0, 0.2)


## Call this from the player script when a player dies
func on_player_died(player_id: int):
	if phase == Phase.LOBBY:
		var player = p1 if player_id == 1 else p2
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			if phase == Phase.LOBBY and lobby_instance:
				var spawn = lobby_instance.get_node("SpawnPoint") as Marker2D
				player.respawn_at(spawn.global_position)
		)
		return
	if phase != Phase.PVP or duel_resolved:
		return
	duel_resolved = true
	register_duel_result(player_id)
	
func _update_duel_score_ui() -> void:
	p1_score_label.text = "P1 " + _make_win_markers(p1_wins)
	p2_score_label.text = "P2 " + _make_win_markers(p2_wins)
	
func _make_win_markers(wins: int) -> String:
	var text := ""
	
	for i in range (DUELS_TO_WIN):
		if i < wins:
			text += "◆ "
		else:
			text += "◇ "
	return text
	
func _show_game_over_screen(winner_id: int) -> void:
	game_over_ui.visible = true

	game_over_title.text = "RIVAL ASCENDED"
	game_over_winner.text = "PLAYER %d WINS THE MATCH" % winner_id
	game_over_score.text = "Final Score: %d - %d" % [p1_wins, p2_wins]
	game_over_restart.text = "Both players press Ready to restart"

	var panel = $UI/GameOverUI/Panel
	panel.scale = Vector2(0.8, 0.8)
	panel.modulate.a = 0.0

	var tween = create_tween()
	tween.parallel().tween_property(panel, "scale", Vector2(1.0, 1.0), 0.35)
	tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.35)


# ─── READY-UP ───────────────────────────────────────────
func _check_both_ready():
	match phase:
		Phase.LOBBY:
			if p1_ready and p2_ready:
				_start_ready_countdown(Phase.DUNGEON)
			else:
				_cancel_ready_countdown()
		Phase.SHOP:
			if p1_ready and p2_ready:
				_start_ready_countdown(Phase.PVP)
			else:
				_cancel_ready_countdown()


func _update_ready_ui():
	var p1_label = ready_up_ui.get_node("P1ReadyLabel") as Label
	var p2_label = ready_up_ui.get_node("P2ReadyLabel") as Label
	p1_label.text = "P1: READY" if p1_ready else "P1: Not Ready"
	p2_label.text = "P2: READY" if p2_ready else "P2: Not Ready"
	_sync_player_ready_states()


func _start_ready_countdown(target_phase: Phase) -> void:
	if ready_countdown_active and ready_countdown_target_phase == target_phase:
		return
	ready_countdown_active = true
	ready_countdown_target_phase = target_phase
	ready_countdown_remaining = 5
	countdown_label.text = "%d" % ready_countdown_remaining
	ready_countdown_timer.start()


func _cancel_ready_countdown() -> void:
	ready_countdown_active = false
	ready_countdown_remaining = 0
	if ready_countdown_timer:
		ready_countdown_timer.stop()
	if countdown_label:
		countdown_label.text = ""


func _on_ready_countdown_tick() -> void:
	if not ready_countdown_active:
		ready_countdown_timer.stop()
		return

	if (phase != Phase.LOBBY and phase != Phase.SHOP) or not (p1_ready and p2_ready):
		_cancel_ready_countdown()
		return

	ready_countdown_remaining -= 1
	if ready_countdown_remaining <= 0:
		var target_phase = ready_countdown_target_phase
		_cancel_ready_countdown()
		_transition_to(target_phase)
		return

	countdown_label.text = "%d" % ready_countdown_remaining
	$Count.play()


func _sync_player_ready_states() -> void:
	if p1 and p1.has_method("set_ready_state"):
		p1.set_ready_state(p1_ready)
	if p2 and p2.has_method("set_ready_state"):
		p2.set_ready_state(p2_ready)
		



# ─── HELPERS ─────────────────────────────────────────────
func _place_room(scene: PackedScene, pos: Vector2) -> Node2D:
	var instance = scene.instantiate() as Node2D
	instance.position = pos
	world.add_child(instance)
	return instance


func _clear_rooms():
	for child in world.get_children():
		if child == p1 or child == p2:
			print("Skipping player: ", child.name)
			continue
		print("Freeing: ", child.name)
		child.queue_free()
	p1_dungeon_rooms.clear()
	p2_dungeon_rooms.clear()
	lobby_instance = null
	shop_instance = null
	pvp_instance = null


func _hide_all_ui():
	ready_up_ui.visible = false
	shop_ui.visible = false
	round_over_ui.visible = false


func _enable_players(enabled: bool):
	p1.set("can_move", enabled)
	p2.set("can_move", enabled)


func _set_players_combat(enabled: bool):
	p1.set("can_attack", enabled)
	p2.set("can_attack", enabled)
