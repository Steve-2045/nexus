extends RigidBody2D

# Este nodo es SAD (Tijera)
var emotion_type = "sad"

# Variables de configuración
@export var speed_min: float = 150.0
@export var speed_max: float = 250.0
var current_speed: float  # Velocidad constante

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
	# Asegurar que la velocidad siempre sea constante
	if linear_velocity.length() > 0:
		linear_velocity = linear_velocity.normalized() * current_speed

func update_screen_bounds():
	var viewport = get_viewport()
	if viewport:
		screen_bounds = viewport.get_visible_rect()

func set_random_velocity():
	# Establecer velocidad constante
	current_speed = randf_range(speed_min, speed_max)
	
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
		# Sad vence a Angry
		other_body.change_to("sad")
	elif other_type == "happy":
		# Happy vence a Sad
		change_to("happy")
	
	# Efecto rebote después de colisión
	apply_collision_bounce(other_body)

func apply_collision_bounce(other_body):
	# Calcular dirección de separación
	var separation = (global_position - other_body.global_position).normalized()
	
	# Aplicar nueva dirección manteniendo velocidad constante
	linear_velocity = separation * current_speed
	
	# Añadir pequeña variación aleatoria a la dirección
	var random_angle = randf_range(-0.2, 0.2)  # ±11 grados
	linear_velocity = linear_velocity.rotated(random_angle)
	
	# Asegurar velocidad constante después del rebote
	linear_velocity = linear_velocity.normalized() * current_speed

func change_to(new_type: String):
	if new_type != emotion_type:
		emotion_type = new_type
		update_sprite()
		
		# Mantener la misma velocidad, solo cambiar dirección ligeramente
		var random_angle = randf_range(-0.1, 0.1)  # Pequeña variación
		linear_velocity = linear_velocity.rotated(random_angle)
		linear_velocity = linear_velocity.normalized() * current_speed

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
