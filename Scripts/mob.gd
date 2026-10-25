extends Node2D
# Моб ходит по клеткам так же, как игрок: шаг за шагом, без наезда на других.
# Все числа настраиваются в Инспекторе справа, у каждого моба свои.
# Новый моб = продублировать сцену моба и поменять числа в Инспекторе.

const CELL = 32  # размер клетки в пикселях (такой же, как в player.gd)

@export_group("Бой")
@export var hp: float = 5.0
@export var attack_damage: float = 1.0     # сколько урона наносит игроку
@export var attack_cooldown: float = 1.0   # секунд между ударами
@export var xp_reward: float = 10.0        # опыт игроку за убийство

@export_group("Движение")
@export var wander_step_time: float = 0.6  # секунд на шаг, когда бродит
@export var chase_step_time: float = 0.35  # секунд на шаг, когда гонится (у игрока 0.15, значит моб медленнее)

@export_group("Зрение")
@export var see_range_cells: int = 5       # на сколько клеток видит игрока
@export var lose_range_cells: int = 8      # дальше этого теряет игрока

var player = null
var chasing := false
var moving := false
var dead := false
var step_target: Vector2      # куда моб идёт прямо сейчас (клетка уже занята)
var wait_time := 0.0
var cooldown := 0.0


func _ready():
	add_to_group("mobs")
	step_target = position


# ---------- ОБЩИЕ ФУНКЦИИ (их же вызывает игрок) ----------

# занята ли эта точка мобом (стоит в ней или идёт в неё)
func occupies(pos: Vector2) -> bool:
	if position.distance_to(pos) < CELL * 0.5:
		return true
	return moving and step_target.distance_to(pos) < CELL * 0.5


func take_damage(amount: float):
	if dead:
		return
	hp -= amount
	print("моб получил ", amount, ", осталось ", hp)
	if hp <= 0:
		die()
		return
	# мигнуть при ударе
	var flash = create_tween()
	flash.tween_property(self, "modulate:a", 0.3, 0.05)
	flash.tween_property(self, "modulate:a", 1.0, 0.05)


func die():
	dead = true
	remove_from_group("mobs")   # сразу перестаём мешать и получать удары
	if player:
		player.stats.add_xp(xp_reward)
	queue_free()


# ---------- ПОВЕДЕНИЕ ----------

func _physics_process(delta):
	if dead:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		return
	cooldown = max(cooldown - delta, 0.0)
	if moving:
		return   # ждём, пока закончится шаг

	update_state()
	if chasing:
		if dist_to_player() <= 1.1:   # игрок рядом: бьём, а не идём сквозь него
			try_attack()
		else:
			chase_step()
	else:
		wander(delta)


func dist_to_player() -> float:   # расстояние в клетках
	return position.distance_to(player.position) / CELL


func update_state():
	if player.dead:
		chasing = false
		return
	var dist = dist_to_player()
	if chasing and dist > lose_range_cells:
		chasing = false
	elif not chasing and dist <= see_range_cells:
		chasing = true


func try_attack():
	if cooldown > 0.0:
		return
	cooldown = attack_cooldown
	player.take_damage(attack_damage)
	# маленький выпад в сторону игрока
	moving = true
	step_target = position
	var dir = (player.position - position).normalized()
	var lunge = create_tween()
	lunge.tween_property(self, "position", position + dir * 8.0, 0.06)
	lunge.tween_property(self, "position", position, 0.06)
	await lunge.finished
	moving = false


func chase_step():
	var diff = player.position - position
	var horizontal = Vector2(signf(diff.x), 0)
	var vertical = Vector2(0, signf(diff.y))
	# сначала идём по той оси, где дальше; если там стена, пробуем другую
	var dirs = [horizontal, vertical]
	if absf(diff.y) > absf(diff.x):
		dirs = [vertical, horizontal]
	for d in dirs:
		if d != Vector2.ZERO and can_enter(position + d * CELL):
			start_step(d, chase_step_time)
			return


func wander(delta):
	if wait_time > 0.0:
		wait_time -= delta
		return
	var dirs = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	dirs.shuffle()
	for d in dirs:
		if can_enter(position + d * CELL):
			start_step(d, wander_step_time)
			break
	wait_time = randf_range(0.3, 1.0)


# можно ли встать в эту точку: проходимая клетка, нет игрока, нет других мобов
func can_enter(pos: Vector2) -> bool:
	var world = player.world
	if not world.is_walkable(world.ground.local_to_map(pos)):
		return false
	if player.occupies(pos):
		return false
	for other in get_tree().get_nodes_in_group("mobs"):
		if other != self and other.occupies(pos):
			return false
	return true


func start_step(dir: Vector2, time: float):
	moving = true
	step_target = position + dir * CELL   # клетка занята сразу, до конца шага
	var tween = create_tween()
	tween.tween_property(self, "position", step_target, time)
	await tween.finished
	moving = false
