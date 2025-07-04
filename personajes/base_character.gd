extends RigidBody2D
class_name BaseCharacter

## Rock-Paper-Scissors Game Entity
## This class represents a character that can be one of three emotions:
## - Happy (Rock): Beats Sad (Scissors)
## - Angry (Paper): Beats Happy (Rock)  
## - Sad (Scissors): Beats Angry (Paper)

# ============================================================================
# EXPORTED PROPERTIES
# ============================================================================

## The current emotion type of this character
@export_enum("happy", "angry", "sad") var emotion_type: String = "happy"

## Standard movement speed for all characters
@export var standard_speed: float = 100.0

## Texture resources for each emotion state
@export var happy_texture: Texture
@export var sad_texture: Texture  
@export var angry_texture: Texture

# ============================================================================
# MOVEMENT & PHYSICS VARIABLES
# ============================================================================

## Current actual speed (with hunting modifiers applied)
var current_speed: float
## Base speed without any modifiers
var base_speed: float

## Screen boundary rectangle for collision detection
var screen_bounds: Rect2
## Cached sprite size for performance optimization
var cached_sprite_size: Vector2

# ============================================================================
# BOUNCING MECHANICS
# ============================================================================

## Cooldown timer to respect wall bounce direction
var bounce_cooldown: float = 0.0
## Direction vector for wall bouncing
var bounce_direction: Vector2 = Vector2.ZERO

# ============================================================================
# HUNTING SYSTEM VARIABLES
# ============================================================================

## Whether this character is currently hunting another
var is_hunting: bool = false
## Whether this character is being hunted by others
var is_being_hunted: bool = false
## Reference to the character being hunted
var hunting_target: BaseCharacter = null
## Array of characters hunting this one
var hunters: Array[BaseCharacter] = []

# ============================================================================
# INTERNAL REFERENCES
# ============================================================================

## Reference to the sprite node
var sprite: Sprite2D

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	# Add to character group for global reference
	add_to_group("characters")
	
	# Configure collision detection for transformation events
	contact_monitor = true
	max_contacts_reported = 10
	
	# Setup physics properties
	_setup_physics()
	
	# Get sprite reference
	sprite = $Sprite2D
	
	# Connect collision signals
	_connect_signals()
	
	# Initialize visual appearance
	load_textures()
	update_sprite()
	
	# Setup initial movement
	set_random_velocity()
	
	# Configure collision layers for selective interaction
	update_collision_layers()

## Configure physics properties for the character
func _setup_physics():
	mass = 1.0
	gravity_scale = 0.0  # Disable gravity for 2D top-down movement
	lock_rotation = true  # Prevent sprite rotation during collisions

## Connect all necessary signals for collision detection
func _connect_signals():
	# RigidBody2D collision for transformation events
	body_entered.connect(_on_body_entered)
	
	# Area2D detection for hunting behavior
	$Area2D.body_entered.connect(_on_detection_area_entered)
	$Area2D.body_exited.connect(_on_detection_area_exited)

# ============================================================================
# PHYSICS & MOVEMENT PROCESSING
# ============================================================================

func _physics_process(delta):
	# Update bounce cooldown timer
	if bounce_cooldown > 0:
		bounce_cooldown -= delta
	
	# Handle screen boundary collisions
	check_screen_boundaries()
	
	# Maintain constant movement speed
	maintain_constant_speed()

## Maintains constant movement speed while handling hunting/fleeing behaviors
func maintain_constant_speed():
	# Prioritize bounce direction during cooldown period
	if bounce_cooldown > 0 and bounce_direction != Vector2.ZERO:
		linear_velocity = bounce_direction * current_speed
		return
	
	# Hunting behavior: pursue target
	if is_hunting and hunting_target and is_instance_valid(hunting_target):
		var other_type = hunting_target.get_emotion_type()
		if can_hunt(other_type):
			var direction = (hunting_target.global_position - global_position).normalized()
			linear_velocity = direction * current_speed
		else:
			# Target is no longer valid, stop hunting
			stop_hunting()
	
	# Fleeing behavior: escape from closest hunter
	elif is_being_hunted and hunters.size() > 0:
		var closest_hunter = _find_closest_valid_hunter()
		
		if closest_hunter:
			# Flee in opposite direction from closest hunter
			var flee_direction = (global_position - closest_hunter.global_position).normalized()
			linear_velocity = flee_direction * current_speed
		else:
			# Clean up invalid hunters and maintain current movement
			_cleanup_invalid_hunters()
			_maintain_current_movement()
	else:
		# Normal movement: maintain current direction and speed
		_maintain_current_movement()

## Find the closest valid hunter from the hunters array
func _find_closest_valid_hunter() -> BaseCharacter:
	var closest_hunter: BaseCharacter = null
	var closest_distance: float = INF
	
	for hunter in hunters:
		if is_instance_valid(hunter):
			var distance = global_position.distance_to(hunter.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_hunter = hunter
	
	return closest_hunter

## Remove invalid hunters from the hunters array
func _cleanup_invalid_hunters():
	hunters = hunters.filter(func(h): return is_instance_valid(h))
	is_being_hunted = hunters.size() > 0
	update_speed()

## Maintain current movement or set random direction if stopped
func _maintain_current_movement():
	if linear_velocity.length() > 0:
		linear_velocity = linear_velocity.normalized() * current_speed
	else:
		# If velocity is zero, set a new random direction
		set_random_velocity()

# ============================================================================
# MOVEMENT SETUP & UTILITIES
# ============================================================================

## Update screen boundaries from viewport
func update_screen_bounds():
	var viewport = get_viewport()
	if viewport:
		screen_bounds = viewport.get_visible_rect()

## Set initial random velocity and standard speed
func set_random_velocity():
	# Set standard speed for all characters
	base_speed = standard_speed
	current_speed = base_speed
	
	# Set random direction
	var angle = randf() * TAU
	linear_velocity = Vector2(cos(angle), sin(angle)) * current_speed

# ============================================================================
# SCREEN BOUNDARY COLLISION
# ============================================================================

## Check and handle collisions with screen boundaries
func check_screen_boundaries():
	# Update screen bounds if not initialized
	if screen_bounds.size == Vector2.ZERO:
		update_screen_bounds()
	
	var pos = global_position
	var vel = linear_velocity
	
	# Cache sprite size for performance optimization
	if cached_sprite_size == Vector2.ZERO and sprite and sprite.texture:
		cached_sprite_size = sprite.texture.get_size() * sprite.scale
	var sprite_size = cached_sprite_size if cached_sprite_size != Vector2.ZERO else Vector2(50, 50)
	
	var velocity_changed = false
	
	# Handle horizontal boundaries
	if pos.x <= sprite_size.x/2 and vel.x < 0:
		linear_velocity.x = abs(vel.x)
		global_position.x = sprite_size.x/2
		velocity_changed = true
	elif pos.x >= screen_bounds.size.x - sprite_size.x/2 and vel.x > 0:
		linear_velocity.x = -abs(vel.x)
		global_position.x = screen_bounds.size.x - sprite_size.x/2
		velocity_changed = true
	
	# Handle vertical boundaries
	if pos.y <= sprite_size.y/2 and vel.y < 0:
		linear_velocity.y = abs(vel.y)
		global_position.y = sprite_size.y/2
		velocity_changed = true
	elif pos.y >= screen_bounds.size.y - sprite_size.y/2 and vel.y > 0:
		linear_velocity.y = -abs(vel.y)
		global_position.y = screen_bounds.size.y - sprite_size.y/2
		velocity_changed = true
	
	# Apply bounce effect if velocity changed
	if velocity_changed:
		linear_velocity = linear_velocity.normalized() * current_speed
		bounce_direction = linear_velocity.normalized()
		bounce_cooldown = 0.3  # Respect bounce direction for 0.3 seconds

# ============================================================================
# COLLISION & TRANSFORMATION SYSTEM
# ============================================================================

## Handle collision with another character (transformation events)
func _on_body_entered(body):
	# Verify it's another emotion character
	if body.has_method("get_emotion_type") and body != self:
		var other_type = body.get_emotion_type()
		if other_type != emotion_type:
			process_collision(body)

## Process collision logic and apply rock-paper-scissors rules
func process_collision(other_body):
	var other_type = other_body.get_emotion_type()
	
	# Apply rock-paper-scissors transformation rules
	if can_hunt(other_type):
		# Winner transforms the loser
		other_body.change_to(emotion_type)

## Transform this character to a new emotion type
func change_to(new_type: String):
	if new_type != emotion_type:
		# Clear all hunting states before transformation
		clear_hunting_states()
		
		# Apply transformation
		emotion_type = new_type
		update_sprite()
		update_collision_layers()
		
		# Notify nearby characters about the transformation
		notify_transformation_to_nearby_characters()
		
		# Force re-evaluation of all entities in detection area
		refresh_detection_area()

# ============================================================================
# TRANSFORMATION NOTIFICATION SYSTEM
# ============================================================================

## Notify nearby characters about this character's transformation
func notify_transformation_to_nearby_characters():
	# Get all characters that can see me (within their detection areas)
	var all_characters = get_tree().get_nodes_in_group("characters")
	
	for character in all_characters:
		if character != self and is_instance_valid(character):
			# Check if I'm within the other character's detection area
			var other_area = character.get_node("Area2D")
			if other_area and other_area.overlaps_body(self):
				# Notify the other character to re-evaluate our relationship
				if character.has_method("re_evaluate_character"):
					character.re_evaluate_character(self)

## Re-evaluate relationship with a character that just transformed
func re_evaluate_character(transformed_character):
	# Called when another character transforms and I need to re-evaluate our relationship
	var other_type = transformed_character.get_emotion_type()
	
	# If I'm currently hunting them but can no longer hunt them
	if hunting_target == transformed_character and not can_hunt(other_type):
		stop_hunting()
	
	# If I'm not hunting and can now hunt them
	if not is_hunting and can_hunt(other_type):
		hunting_target = transformed_character
		is_hunting = true
		
		# Notify the other character that it's being hunted
		if transformed_character.has_method("add_hunter"):
			transformed_character.add_hunter(self)
		
		update_speed()
	
	# If they can now hunt me
	if is_hunted_by(other_type):
		# Add them as a hunter immediately - must flee from any nearby hunters
		add_hunter(transformed_character)
		
		# Also notify them in case they want to actively hunt me
		if transformed_character.has_method("notify_prey_detected"):
			transformed_character.notify_prey_detected(self)
	
	# If they can no longer hunt me (but could before)
	elif transformed_character in hunters:
		remove_hunter(transformed_character)

# ============================================================================
# GETTER FUNCTIONS
# ============================================================================

## Get the current emotion type of this character
func get_emotion_type() -> String:
	return emotion_type

# ============================================================================
# VISUAL UPDATE SYSTEM
# ============================================================================

## Update sprite texture based on current emotion type
func update_sprite():
	if not sprite:
		return
		
	match emotion_type:
		"happy":
			if happy_texture:
				sprite.texture = happy_texture
		"sad":
			if sad_texture:
				sprite.texture = sad_texture
		"angry":
			if angry_texture:
				sprite.texture = angry_texture

# ============================================================================
# DETECTION AREA SIGNAL HANDLERS
# ============================================================================

## Handle when another character enters the detection area
func _on_detection_area_entered(body):
	if body.has_method("get_emotion_type") and body != self:
		var other_type = body.get_emotion_type()
		
		# Check if I can hunt this type
		if can_hunt(other_type):
			# Only hunt if not already hunting someone else
			if not is_hunting:
				hunting_target = body
				is_hunting = true
				
				# Notify the other character that it's being hunted
				if body.has_method("add_hunter"):
					body.add_hunter(self)
				
				update_speed()
		
		# Check if this type can hunt me
		elif is_hunted_by(other_type):
			# Add them as a hunter immediately - all prey must flee from nearby hunters
			add_hunter(body)
			
			# Also notify the hunter in case they want to hunt me
			if body.has_method("notify_prey_detected"):
				body.notify_prey_detected(self)

## Handle when another character exits the detection area
func _on_detection_area_exited(body):
	if body == hunting_target:
		stop_hunting()
	
	# If it was a hunter that left the area, no longer need to flee from it
	if body in hunters:
		remove_hunter(body)

# ============================================================================
# HUNTING MANAGEMENT FUNCTIONS
# ============================================================================

## Stop hunting the current target
func stop_hunting():
	if hunting_target and is_instance_valid(hunting_target):
		# Notify the prey that I'm no longer hunting it
		if hunting_target.has_method("remove_hunter"):
			hunting_target.remove_hunter(self)
	
	hunting_target = null
	is_hunting = false
	update_speed()

# ============================================================================
# GAME LOGIC FUNCTIONS (Rock-Paper-Scissors Rules)
# ============================================================================

## Check if this character can hunt the other type
func can_hunt(other_type: String) -> bool:
	# Rock-paper-scissors logic based on current type
	match emotion_type:
		"happy":  # Rock
			return other_type == "sad"  # Rock beats Scissors
		"angry":  # Paper
			return other_type == "happy"  # Paper beats Rock
		"sad":  # Scissors
			return other_type == "angry"  # Scissors beats Paper
	return false

## Check if this character is hunted by the other type
func is_hunted_by(other_type: String) -> bool:
	# Check if I'm prey to this type
	match emotion_type:
		"happy":  # Rock
			return other_type == "angry"  # Rock is beaten by Paper
		"angry":  # Paper
			return other_type == "sad"  # Paper is beaten by Scissors
		"sad":  # Scissors
			return other_type == "happy"  # Scissors is beaten by Rock
	return false

# ============================================================================
# HUNTER/PREY RELATIONSHIP MANAGEMENT
# ============================================================================

## Add a hunter to the hunters list
func add_hunter(hunter):
	if not hunter in hunters:
		hunters.append(hunter)
		is_being_hunted = true
		update_speed()

## Remove a hunter from the hunters list
func remove_hunter(hunter):
	hunters.erase(hunter)
	is_being_hunted = hunters.size() > 0
	update_speed()

## Called when a prey is detected in my area
func notify_prey_detected(prey):
	if not is_hunting and can_hunt(prey.get_emotion_type()):
		hunting_target = prey
		is_hunting = true
		prey.add_hunter(self)
		update_speed()

# ============================================================================
# SPEED MODIFICATION SYSTEM
# ============================================================================

## Update movement speed based on hunting/fleeing state
func update_speed():
	if is_hunting and is_being_hunted:
		current_speed = base_speed * 1.1  # Slight boost when both hunting and fleeing
	elif is_hunting:
		current_speed = base_speed * 1.3  # Faster when hunting
	elif is_being_hunted:
		current_speed = base_speed * 0.85  # Slightly slower when fleeing (mild panic effect)
	else:
		current_speed = base_speed  # Normal speed

# ============================================================================
# RESOURCE LOADING SYSTEM
# ============================================================================

## Load emotion textures from the sprites directory
func load_textures():
	var texture_paths = {
		"happy": "res://sprites/emote_faceHappy.png",
		"sad": "res://sprites/emote_faceSad.png",
		"angry": "res://sprites/emote_faceAngry.png"
	}
	
	for emotion in texture_paths:
		var path = texture_paths[emotion]
		if ResourceLoader.exists(path):
			var texture = load(path)
			if texture:
				match emotion:
					"happy":
						happy_texture = texture
					"sad":
						sad_texture = texture
					"angry":
						angry_texture = texture
			else:
				push_error("Failed to load texture: " + path)
		else:
			push_error("Texture file not found: " + path)

# ============================================================================
# STATE CLEANUP & UTILITY FUNCTIONS
# ============================================================================

## Clear all hunting states (used during transformation)
func clear_hunting_states():
	# Stop hunting current target
	stop_hunting()
	
	# Notify all hunters that I no longer exist as prey
	for hunter in hunters:
		if is_instance_valid(hunter) and hunter.has_method("notify_prey_lost"):
			hunter.notify_prey_lost(self)
	
	# Clear all states
	hunters.clear()
	is_being_hunted = false
	
	# Reset speed to normal
	update_speed()

## Called when my prey changed type or was destroyed
func notify_prey_lost(prey):
	if prey == hunting_target:
		stop_hunting()

## Re-evaluate all entities currently in the detection area
func refresh_detection_area():
	var bodies_in_area = $Area2D.get_overlapping_bodies()
	for body in bodies_in_area:
		if body.has_method("get_emotion_type") and body != self:
			var other_type = body.get_emotion_type()
			
			# If I can now hunt this type, start hunting it
			if can_hunt(other_type) and not is_hunting:
				hunting_target = body
				is_hunting = true
				
				# Notify the other character that it's being hunted
				if body.has_method("add_hunter"):
					body.add_hunter(self)
				
				update_speed()
				break  # Only hunt one target at a time
			
			# If this type can now hunt me
			elif is_hunted_by(other_type):
				# Add them as a hunter immediately
				add_hunter(body)
				
				# Also notify them in case they want to hunt me
				if body.has_method("notify_prey_detected"):
					body.notify_prey_detected(self)

# ============================================================================
# COLLISION LAYER CONFIGURATION
# ============================================================================

## Configure collision layers for selective interaction between emotion types
func update_collision_layers():
	# Configure layers to detect both prey and predators
	# Layers: 1=Happy(bit 0), 2=Angry(bit 1), 4=Sad(bit 2)
	
	match emotion_type:
		"happy":  # Rock
			collision_layer = 1  # I am bit 0 (value 1)
			collision_mask = 4   # Detect collisions with Sad (my prey)
			$Area2D.collision_layer = 1
			$Area2D.collision_mask = 6  # Detect Angry (my hunter, bit 1) and Sad (my prey, bit 2)
		"angry":  # Paper
			collision_layer = 2  # I am bit 1 (value 2)
			collision_mask = 1   # Detect collisions with Happy (my prey)
			$Area2D.collision_layer = 2
			$Area2D.collision_mask = 5  # Detect Happy (my prey, bit 0) and Sad (my hunter, bit 2)
		"sad":  # Scissors
			collision_layer = 4  # I am bit 2 (value 4)
			collision_mask = 2   # Detect collisions with Angry (my prey)
			$Area2D.collision_layer = 4
			$Area2D.collision_mask = 3  # Detect Happy (my hunter, bit 0) and Angry (my prey, bit 1)
