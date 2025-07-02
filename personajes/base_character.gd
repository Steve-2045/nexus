extends RigidBody2D
class_name BaseCharacter

@export_enum("happy", "angry", "sad") var emotion_type: String = "happy"

# Variables de configuración
@export var speed_min: float = 75.0
@export var speed_max: float = 125.0
var current_speed: float  # Velocidad constante
var base_speed: float     # Velocidad base sin modificadores

# Variables de caza
var is_hunting = false
var is_being_hunted = false
var hunting_target = null
var hunters = []  # Lista de quien me está cazando

# Variables para el rebote
var bounce_cooldown: float = 0.0  # Tiempo para respetar el rebote
var bounce_direction: Vector2 = Vector2.ZERO  # Dirección del rebote

# Referencias a las texturas
@export var happy_texture: Texture
@export var sad_texture: Texture  
@export var angry_texture: Texture

# Variables internas
var screen_bounds: Rect2
var sprite: Sprite2D
var cached_sprite_size: Vector2

func _ready():
	# Añadir al grupo para poder encontrar todas las entidades
	add_to_group("characters")
	
	# Configurar detección de colisiones
	contact_monitor = true
	max_contacts_reported = 10
	
	# Configuración física
	mass = 1.0
	gravity_scale = 0  # Sin gravedad
	lock_rotation = true  # IMPORTANTE: Evita que el sprite rote
	
	# Obtener referencia al sprite
	sprite = $Sprite2D
	
	# Conectar señales
	body_entered.connect(_on_body_entered)
	
	# Conectar señales del Area2D para detección de caza
	$Area2D.body_entered.connect(_on_detection_area_entered)
	$Area2D.body_exited.connect(_on_detection_area_exited)
	
	# Cargar texturas
	load_textures()
	update_sprite()
	
	# Configurar velocidad inicial aleatoria y constante
	set_random_velocity()
	
	# Configurar collision layers iniciales
	update_collision_layers()
	
	# Los límites se actualizarán cuando sea necesario

func _physics_process(delta):
	# Actualizar cooldown del rebote
	if bounce_cooldown > 0:
		bounce_cooldown -= delta
	
	# Verificar colisiones con bordes (incluye actualización de límites)
	check_screen_boundaries()
	
	# IMPORTANTE: Mantener velocidad constante
	maintain_constant_speed()

func maintain_constant_speed():
	# Si acabamos de rebotar, usar la dirección del rebote
	if bounce_cooldown > 0 and bounce_direction != Vector2.ZERO:
		linear_velocity = bounce_direction * current_speed
		return
	
	# Si está cazando, perseguir a la presa
	if is_hunting and hunting_target and is_instance_valid(hunting_target):
		# Verificar si el objetivo aún es válido para cazar
		var other_type = hunting_target.get_emotion_type()
		if can_hunt(other_type):
			var direction = (hunting_target.global_position - global_position).normalized()
			linear_velocity = direction * current_speed
		else:
			# El objetivo ya no es válido, dejar de cazarlo
			stop_hunting()
	# Si está siendo cazado, huir del cazador más cercano
	elif is_being_hunted and hunters.size() > 0:
		var closest_hunter = null
		var closest_distance = INF
		
		# Encontrar el cazador más cercano válido
		for hunter in hunters:
			if is_instance_valid(hunter):
				var distance = global_position.distance_to(hunter.global_position)
				if distance < closest_distance:
					closest_distance = distance
					closest_hunter = hunter
		
		if closest_hunter:
			# Huir en dirección opuesta al cazador más cercano
			var flee_direction = (global_position - closest_hunter.global_position).normalized()
			linear_velocity = flee_direction * current_speed
		else:
			# Limpiar cazadores inválidos
			hunters = hunters.filter(func(h): return is_instance_valid(h))
			is_being_hunted = hunters.size() > 0
			update_speed()
			# Mantener velocidad actual
			if linear_velocity.length() > 0:
				linear_velocity = linear_velocity.normalized() * current_speed
	else:
		# Mantener velocidad constante en dirección actual
		if linear_velocity.length() > 0:
			linear_velocity = linear_velocity.normalized() * current_speed
		else:
			# Si por alguna razón la velocidad es 0, establecer una nueva dirección
			set_random_velocity()

func update_screen_bounds():
	var viewport = get_viewport()
	if viewport:
		screen_bounds = viewport.get_visible_rect()

func set_random_velocity():
	# Establecer velocidad base constante
	base_speed = randf_range(speed_min, speed_max)
	current_speed = base_speed
	
	# Dirección aleatoria
	var angle = randf() * TAU
	linear_velocity = Vector2(cos(angle), sin(angle)) * current_speed

func check_screen_boundaries():
	# Actualizar límites solo si es necesario
	if screen_bounds.size == Vector2.ZERO:
		update_screen_bounds()
	
	var pos = global_position
	var vel = linear_velocity
	
	# Usar sprite size cacheado para mejor rendimiento
	if cached_sprite_size == Vector2.ZERO and sprite and sprite.texture:
		cached_sprite_size = sprite.texture.get_size() * sprite.scale
	var sprite_size = cached_sprite_size if cached_sprite_size != Vector2.ZERO else Vector2(50, 50)
	
	var velocity_changed = false
	
	# Rebote horizontal - solo cambiar dirección, mantener velocidad
	if pos.x <= sprite_size.x/2 and vel.x < 0:
		linear_velocity.x = abs(vel.x)
		global_position.x = sprite_size.x/2
		velocity_changed = true
	elif pos.x >= screen_bounds.size.x - sprite_size.x/2 and vel.x > 0:
		linear_velocity.x = -abs(vel.x)
		global_position.x = screen_bounds.size.x - sprite_size.x/2
		velocity_changed = true
	
	# Rebote vertical - solo cambiar dirección, mantener velocidad
	if pos.y <= sprite_size.y/2 and vel.y < 0:
		linear_velocity.y = abs(vel.y)
		global_position.y = sprite_size.y/2
		velocity_changed = true
	elif pos.y >= screen_bounds.size.y - sprite_size.y/2 and vel.y > 0:
		linear_velocity.y = -abs(vel.y)
		global_position.y = screen_bounds.size.y - sprite_size.y/2
		velocity_changed = true
	
	# Si cambió la velocidad, normalizarla y aplicar velocidad constante
	if velocity_changed:
		linear_velocity = linear_velocity.normalized() * current_speed
		# IMPORTANTE: Guardar la dirección del rebote y activar cooldown
		bounce_direction = linear_velocity.normalized()
		bounce_cooldown = 0.3  # Respetar el rebote por 0.3 segundos

func _on_body_entered(body):
	# Verificar que es otro objeto emoción
	if body.has_method("get_emotion_type") and body != self:
		var other_type = body.get_emotion_type()
		if other_type != emotion_type:
			process_collision(body)

func process_collision(other_body):
	var other_type = other_body.get_emotion_type()
	
	# Lógica dinámica de transformación basada en piedra-papel-tijera
	if can_hunt(other_type):
		# Solo el ganador transforma al perdedor
		other_body.change_to(emotion_type)

func change_to(new_type: String):
	if new_type != emotion_type:
		# Guardar mi tipo anterior para notificaciones
		var old_type = emotion_type
		
		# Limpiar estados de hunting antes de cambiar tipo
		clear_hunting_states()
		
		# Cambiar tipo
		emotion_type = new_type
		update_sprite()
		update_collision_layers()
		
		# IMPORTANTE: Notificar a TODOS los personajes cercanos sobre mi transformación
		notify_transformation_to_nearby_characters()
		
		# Forzar re-evaluación de todas las entidades en el área de detección
		refresh_detection_area()

func notify_transformation_to_nearby_characters():
	# Obtener todos los personajes que pueden verme (dentro de sus áreas de detección)
	var all_characters = get_tree().get_nodes_in_group("characters")
	
	for character in all_characters:
		if character != self and is_instance_valid(character):
			# Verificar si estoy en el área de detección del otro personaje
			var other_area = character.get_node("Area2D")
			if other_area and other_area.overlaps_body(self):
				# Notificar al otro personaje que debe re-evaluar si soy presa o cazador
				if character.has_method("re_evaluate_character"):
					character.re_evaluate_character(self)

func re_evaluate_character(transformed_character):
	# Llamado cuando otro personaje se transforma y necesito re-evaluar mi relación con él
	var other_type = transformed_character.get_emotion_type()
	
	# Si actualmente lo estoy cazando pero ya no puedo cazarlo
	if hunting_target == transformed_character and not can_hunt(other_type):
		stop_hunting()
	
	# Si no estoy cazando y ahora puedo cazarlo
	if not is_hunting and can_hunt(other_type):
		hunting_target = transformed_character
		is_hunting = true
		
		# Notificar al otro que está siendo cazado
		if transformed_character.has_method("add_hunter"):
			transformed_character.add_hunter(self)
		
		update_speed()
	
	# Si ahora puede cazarme
	if is_hunted_by(other_type):
		# IMPORTANTE: Agregar directamente como cazador
		# No esperar confirmación - debo huir de cualquier cazador cercano
		add_hunter(transformed_character)
		
		# También notificar por si quiere cazarme activamente
		if transformed_character.has_method("notify_prey_detected"):
			transformed_character.notify_prey_detected(self)
	
	# Si ya no puede cazarme (pero antes sí)
	elif transformed_character in hunters:
		remove_hunter(transformed_character)

func get_emotion_type() -> String:
	return emotion_type

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

func _on_detection_area_entered(body):
	if body.has_method("get_emotion_type") and body != self:
		var other_type = body.get_emotion_type()
		
		# Verificar si puedo cazar a este tipo
		if can_hunt(other_type):
			# Solo cazar si no estoy cazando a nadie más
			if not is_hunting:
				hunting_target = body
				is_hunting = true
				
				# Notificar al otro que está siendo cazado
				if body.has_method("add_hunter"):
					body.add_hunter(self)
				
				update_speed()
		
		# Verificar si este tipo puede cazarme
		elif is_hunted_by(other_type):
			# IMPORTANTE: Agregar directamente al cazador sin esperar confirmación
			# Todas las presas deben huir de cualquier cazador cercano
			add_hunter(body)
			
			# También notificar al cazador por si quiere cazarme
			if body.has_method("notify_prey_detected"):
				body.notify_prey_detected(self)

func _on_detection_area_exited(body):
	if body == hunting_target:
		stop_hunting()
	
	# Si era un cazador que salió del área, ya no necesito huir de él
	if body in hunters:
		remove_hunter(body)

func stop_hunting():
	if hunting_target and is_instance_valid(hunting_target):
		# Notificar a la presa que ya no la cazo
		if hunting_target.has_method("remove_hunter"):
			hunting_target.remove_hunter(self)
	
	hunting_target = null
	is_hunting = false
	update_speed()

func can_hunt(other_type: String) -> bool:
	# Lógica dinámica basada en el tipo actual
	match emotion_type:
		"happy":  # Piedra
			return other_type == "sad"  # Vence a Tijera
		"angry":  # Papel
			return other_type == "happy"  # Vence a Piedra
		"sad":  # Tijera
			return other_type == "angry"  # Vence a Papel
	return false

func is_hunted_by(other_type: String) -> bool:
	# Verificar si soy cazado por este tipo
	match emotion_type:
		"happy":  # Piedra
			return other_type == "angry"  # Es cazado por Papel
		"angry":  # Papel
			return other_type == "sad"  # Es cazado por Tijera
		"sad":  # Tijera
			return other_type == "happy"  # Es cazado por Piedra
	return false

func add_hunter(hunter):
	if not hunter in hunters:
		hunters.append(hunter)
		is_being_hunted = true
		update_speed()

func remove_hunter(hunter):
	hunters.erase(hunter)
	is_being_hunted = hunters.size() > 0
	update_speed()

func notify_prey_detected(prey):
	# Llamado cuando detecto una presa en mi área
	if not is_hunting and can_hunt(prey.get_emotion_type()):
		hunting_target = prey
		is_hunting = true
		prey.add_hunter(self)
		update_speed()

func update_speed():
	if is_hunting and is_being_hunted:
		current_speed = base_speed * 1.0  # Neutral
	elif is_hunting:
		current_speed = base_speed * 1.25  # Más rápido cazando
	elif is_being_hunted:
		current_speed = base_speed * 0.75  # Más lento huyendo
	else:
		current_speed = base_speed  # Normal

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

func clear_hunting_states():
	# Dejar de cazar
	stop_hunting()
	
	# Notificar a todos los cazadores que ya no existo como presa
	for hunter in hunters:
		if is_instance_valid(hunter) and hunter.has_method("notify_prey_lost"):
			hunter.notify_prey_lost(self)
	
	# Limpiar todos los estados
	hunters.clear()
	is_being_hunted = false
	
	# Resetear velocidad a normal
	update_speed()

func notify_prey_lost(prey):
	# Llamado cuando mi presa cambió de tipo o fue destruida
	if prey == hunting_target:
		stop_hunting()

func refresh_detection_area():
	# Re-evaluar todas las entidades actualmente en el área de detección
	var bodies_in_area = $Area2D.get_overlapping_bodies()
	for body in bodies_in_area:
		if body.has_method("get_emotion_type") and body != self:
			var other_type = body.get_emotion_type()
			
			# Si ahora puedo cazar a este tipo, empezar a cazarlo
			if can_hunt(other_type) and not is_hunting:
				hunting_target = body
				is_hunting = true
				
				# Notificar al otro que está siendo cazado
				if body.has_method("add_hunter"):
					body.add_hunter(self)
				
				update_speed()
				break  # Solo cazar un objetivo a la vez
			
			# Si este tipo ahora puede cazarme
			elif is_hunted_by(other_type):
				# IMPORTANTE: Agregar directamente como cazador
				add_hunter(body)
				
				# También notificar por si quiere cazarme
				if body.has_method("notify_prey_detected"):
					body.notify_prey_detected(self)

func update_collision_layers():
	# Configurar las capas para detectar tanto presas como depredadores
	# Layers: 1=Happy(bit 0), 2=Angry(bit 1), 4=Sad(bit 2)
	
	match emotion_type:
		"happy":  # Piedra
			collision_layer = 1  # Soy bit 0 (valor 1)
			collision_mask = 4   # Detecto colisiones con Sad (mi presa)
			$Area2D.collision_layer = 1
			$Area2D.collision_mask = 6  # Detecto Angry (mi cazador, bit 1) y Sad (mi presa, bit 2)
		"angry":  # Papel
			collision_layer = 2  # Soy bit 1 (valor 2)
			collision_mask = 1   # Detecto colisiones con Happy (mi presa)
			$Area2D.collision_layer = 2
			$Area2D.collision_mask = 5  # Detecto Happy (mi presa, bit 0) y Sad (mi cazador, bit 2)
		"sad":  # Tijera
			collision_layer = 4  # Soy bit 2 (valor 4)
			collision_mask = 2   # Detecto colisiones con Angry (mi presa)
			$Area2D.collision_layer = 4
			$Area2D.collision_mask = 3  # Detecto Happy (mi cazador, bit 0) y Angry (mi presa, bit 1)
