extends RigidBody2D

# Este nodo es SAD (Tijera)
var emotion_type = "sad"

# Variables de configuración
@export var speed_min: float = 150.0
@export var speed_max: float = 250.0
var current_speed: float  # Velocidad constante
var base_speed: float     # Velocidad base sin modificadores

# Variables de caza
var is_hunting = false
var is_being_hunted = false
var hunting_target = null
var hunters = []  # Lista de quien me está cazando

# Referencias a las texturas
@export var happy_texture: Texture
@export var sad_texture: Texture  
@export var angry_texture: Texture

# Variables internas
var screen_bounds: Rect2
var sprite: Sprite2D

func _ready():
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
	
	# Obtener límites de pantalla
	call_deferred("update_screen_bounds")

func _physics_process(_delta):
	# Actualizar límites de pantalla
	update_screen_bounds()
	
	# Verificar colisiones con bordes
	check_screen_boundaries()
	
	# IMPORTANTE: Mantener velocidad constante
	maintain_constant_speed()

func maintain_constant_speed():
	# Si está cazando, perseguir a la presa
	if is_hunting and hunting_target and is_instance_valid(hunting_target):
		var direction = (hunting_target.global_position - global_position).normalized()
		linear_velocity = direction * current_speed
	else:
		# Mantener velocidad constante en dirección actual
		if linear_velocity.length() > 0:
			linear_velocity = linear_velocity.normalized() * current_speed

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
	var pos = global_position
	var vel = linear_velocity
	var sprite_size = Vector2(50, 50)
	
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

func _on_body_entered(body):
	# Verificar que es otro objeto emoción
	if body.has_method("get_emotion_type") and body != self:
		var other_type = body.get_emotion_type()
		if other_type != emotion_type:
			process_collision(body)

func process_collision(other_body):
	var other_type = other_body.get_emotion_type()
	
	# SAD (Tijera) lógica:
	# - Vence a ANGRY (Papel)
	# - Pierde contra HAPPY (Piedra)
	
	if other_type == "angry":
		# Sad vence a Angry - Solo el ganador transforma
		other_body.change_to("sad")


func change_to(new_type: String):
	if new_type != emotion_type:
		emotion_type = new_type
		update_sprite()

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
		
		# Solo cazar si puedo vencer a este tipo
		if can_hunt(other_type):
			hunting_target = body
			is_hunting = true
			
			# Notificar al otro que está siendo cazado
			if body.has_method("_being_hunted_by"):
				body._being_hunted_by(self)
			
			update_speed()

func _on_detection_area_exited(body):
	if body == hunting_target:
		hunting_target = null
		is_hunting = false
		
		# Notificar al otro que ya no lo cazo
		if body.has_method("_no_longer_hunted_by"):
			body._no_longer_hunted_by(self)
		
		update_speed()

func can_hunt(other_type: String) -> bool:
	# SAD (Tijera) puede cazar ANGRY (Papel)
	return other_type == "angry"

func _being_hunted_by(hunter):
	if not hunters.has(hunter):
		hunters.append(hunter)
		is_being_hunted = true
		update_speed()

func _no_longer_hunted_by(hunter):
	hunters.erase(hunter)
	is_being_hunted = (hunters.size() > 0)
	update_speed()

func update_speed():
	if is_hunting and is_being_hunted:
		current_speed = base_speed * 1.0  # Neutral
	elif is_hunting:
		current_speed = base_speed * 1.25  # Más rápido
	elif is_being_hunted:
		current_speed = base_speed * 0.75  # Más lento
	else:
		current_speed = base_speed  # Normal

func load_textures():
	# Cargar texturas con manejo de errores
	var happy_path = "res://sprites/emote_faceHappy.png"
	var sad_path = "res://sprites/emote_faceSad.png"
	var angry_path = "res://sprites/emote_faceAngry.png"
	
	if ResourceLoader.exists(happy_path):
		happy_texture = load(happy_path)
	else:
		push_warning("No se encontró: " + happy_path)
	
	if ResourceLoader.exists(sad_path):
		sad_texture = load(sad_path)
	else:
		push_warning("No se encontró: " + sad_path)
	
	if ResourceLoader.exists(angry_path):
		angry_texture = load(angry_path)
	else:
		push_warning("No se encontró: " + angry_path)
