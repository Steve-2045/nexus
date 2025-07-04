extends Node2D

## Main game scene that manages character spawning and game flow

var game_over: bool = false
var reset_button: Button

# ============================================================================
# CONFIGURATION
# ============================================================================

## Number of characters to spawn for each emotion type
@export var characters_per_type: int = 5

## Margin from screen edges for spawning
@export var spawn_margin: int = 100

## Radius for group spawning (how spread out each group is)
@export var group_radius: int = 80

## Minimum distance between groups (randomized within a range)
@export var min_group_distance: float = 200.0
@export var max_group_distance: float = 350.0

## Character scene resources
var character_scenes = {
	"happy": preload("res://personajes/happy.tscn"),
	"angry": preload("res://personajes/angry.tscn"),
	"sad": preload("res://personajes/sad.tscn")
}

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	setup_reset_button()
	clear_existing_characters()
	spawn_characters_randomly()

func _process(_delta):
	if not game_over:
		check_win_condition()

## Remove any existing character instances from the scene
func clear_existing_characters():
	var children_to_remove = []
	for child in get_children():
		if child.has_method("get_emotion_type"):
			children_to_remove.append(child)
	
	for child in children_to_remove:
		child.queue_free()

## Spawn characters in equidistant groups across the screen
func spawn_characters_randomly():
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Calculate group center positions (equidistant triangle formation)
	var group_centers = calculate_group_centers(viewport_size)
	
	# Spawn each emotion type in its designated group area
	var emotion_types = character_scenes.keys()
	for i in range(emotion_types.size()):
		var emotion_type = emotion_types[i]
		var group_center = group_centers[i]
		spawn_group(emotion_type, group_center)

## Calculate equidistant but randomized positions for the three groups
func calculate_group_centers(viewport_size: Vector2) -> Array[Vector2]:
	var centers: Array[Vector2] = []
	var center_x = viewport_size.x / 2
	var center_y = viewport_size.y / 2
	
	# Random distance from center for each game (equidistant but variable)
	var distance_from_center = randf_range(min_group_distance, max_group_distance)
	
	# Create an equilateral triangle formation with random rotation
	var base_rotation = randf() * TAU  # Random starting angle
	
	# Generate the three group centers at equal angles (120 degrees apart)
	for i in range(3):
		var angle = base_rotation + (i * TAU / 3.0)  # 120 degrees apart
		var group_center = Vector2(center_x, center_y) + Vector2(cos(angle), sin(angle)) * distance_from_center
		
		# Ensure the group center stays within screen bounds
		group_center.x = clamp(group_center.x, spawn_margin + group_radius, viewport_size.x - spawn_margin - group_radius)
		group_center.y = clamp(group_center.y, spawn_margin + group_radius, viewport_size.y - spawn_margin - group_radius)
		
		centers.append(group_center)
	
	return centers

## Spawn a group of characters around a center point
func spawn_group(emotion_type: String, group_center: Vector2):
	var character_scene = character_scenes[emotion_type]
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Randomly select which character will be the "wanderer" (appears anywhere)
	var wanderer_index = randi() % characters_per_type
	
	for i in range(characters_per_type):
		var character_instance = character_scene.instantiate()
		
		if i == wanderer_index:
			# Wanderer: spawn anywhere on the screen
			var random_x = randf_range(spawn_margin, viewport_size.x - spawn_margin)
			var random_y = randf_range(spawn_margin, viewport_size.y - spawn_margin)
			character_instance.position = Vector2(random_x, random_y)
		else:
			# Normal: spawn within group radius
			var angle = randf() * TAU
			var distance = randf_range(0, group_radius)
			var spawn_position = group_center + Vector2(cos(angle), sin(angle)) * distance
			character_instance.position = spawn_position
		
		# Add to scene
		add_child(character_instance)


## Check if only one emotion type remains (win condition)
func check_win_condition():
	var emotion_counts = {"happy": 0, "angry": 0, "sad": 0}
	
	# Count characters by emotion type
	var characters = get_tree().get_nodes_in_group("characters")
	for character in characters:
		if character and is_instance_valid(character):
			var emotion = character.get_emotion_type()
			if emotion in emotion_counts:
				emotion_counts[emotion] += 1
	
	# Check if only one emotion type remains
	var active_emotions = 0
	var winning_emotion = ""
	
	for emotion in emotion_counts:
		if emotion_counts[emotion] > 0:
			active_emotions += 1
			winning_emotion = emotion
	
	# Game over when only one emotion type remains
	if active_emotions <= 1:
		trigger_game_over(winning_emotion)

func setup_reset_button():
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 10
	add_child(canvas_layer)
	
	reset_button = Button.new()
	reset_button.text = "Reiniciar"
	reset_button.visible = false
	reset_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reset_button.pressed.connect(restart_game)
	
	canvas_layer.add_child(reset_button)
	
	reset_button.anchors_preset = Control.PRESET_CENTER_LEFT
	reset_button.anchor_left = 0.5
	reset_button.anchor_top = 0.5
	reset_button.anchor_right = 0.5
	reset_button.anchor_bottom = 0.5
	reset_button.offset_left = -50
	reset_button.offset_top = -20

func restart_game():
	get_tree().reload_current_scene()

func trigger_game_over(_winning_emotion: String):
	if game_over:
		return
		
	game_over = true
	
	var characters = get_tree().get_nodes_in_group("characters")
	for character in characters:
		if character and is_instance_valid(character):
			character.linear_velocity = Vector2.ZERO
			character.set_physics_process(false)
	
	reset_button.visible = true
	reset_button.mouse_filter = Control.MOUSE_FILTER_PASS
