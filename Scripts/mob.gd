extends Node2D
# Моб ходит свободно во все стороны, как игрок.
# Бродит: идёт в случайную сторону, стоит, снова идёт.
# Видит игрока: бежит к нему, подходит вплотную и бьёт.
# Все числа настраиваются в Инспекторе справа, у каждого моба свои.
# Новый моб = продублировать сцену моба и поменять числа в Инспекторе.

const CELL = 32  # размер клетки мира в пикселях

@export_group("Бой")
@export var hp: float = 5.0
@export var attack_damage: float = 1.0     # сколько урона наносит игроку
@export var attack_cooldown: float = 1.0   # секунд между ударами
@export var attack_range: float = 34.0     # с какого расстояния (в пикселях) может ударить
@export var xp_reward: float = 10.0        # опыт игроку за убийство

@export_group("Движение")
@export var wander_speed: float = 50.0     # пикселей в секунду, когда бродит
@export var chase_speed: float = 120.0     # когда гонится (у игрока 200, значит моб медленнее)
@export var body_size: float = 28.0        # размер тела (квадрат)

@export_group("Зрение")
@export var see_range_cells: float = 5.0   # на сколько клеток видит игрока
@export var lose_range_cells: float = 8.0  # дальше этого теряет игрока

var player = null
var chasing := false
var dead := false
var busy := false              # занят выпадом, в это время не ходит
var cooldown := 0.0
var wander_dir := Vector2.ZERO # куда бредёт (ноль = стоит)
var wander_time := 0.0         # сколько ещё идти/стоять


func _ready():
	add_to_group("mobs")


# ---------- УРОН ----------

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
	if busy:
		return

	update_state()
	if chasing:
		if position.distance_to(player.position) <= attack_range:
			try_attack()   # игрок рядом: бьём, а не идём сквозь него
		else:
			var dir = (player.position - position).normalized()
			move(dir * chase_speed * delta)
	else:
		wander(delta)


func update_state():
	if player.dead:
		chasing = false
		return
	var dist = position.distance_to(player.position) / CELL   # в клетках
	if chasing and dist > lose_range_cells:
		chasing = false
	elif not chasing and dist <= see_range_cells:
		chasing = true


func wander(delta):
	wander_time -= delta
	if wander_time <= 0.0:
		if wander_dir == Vector2.ZERO:
			# стоял — теперь идём в случайную сторону (любой угол)
			wander_dir = Vector2.RIGHT.rotated(randf() * TAU)
			wander_time = randf_range(0.5, 1.5)
		else:
			# шёл — теперь постоим
			wander_dir = Vector2.ZERO
			wander_time = randf_range(0.5, 2.0)
	if wander_dir != Vector2.ZERO:
		var before = position
		move(wander_dir * wander_speed * delta)
		if position == before:
			wander_time = 0.0   # упёрлись в стену: сразу выбрать новое направление


# сдвинуться на offset, по X и Y отдельно (так скользим вдоль стен, как игрок)
func move(offset: Vector2):
	var try_x = position + Vector2(offset.x, 0)
	if can_stand(try_x):
		position = try_x
	var try_y = position + Vector2(0, offset.y)
	if can_stand(try_y):
		position = try_y


# можно ли стоять в точке pos: не в горе, не в игроке, не в другом мобе
func can_stand(pos: Vector2) -> bool:
	if not player.world.body_fits(pos, body_size):
		return false
	if too_close(player.position, pos):
		return false
	for other in get_tree().get_nodes_in_group("mobs"):
		if other != self and too_close(other.position, pos):
			return false
	return true


# слишком ли близко к чужому телу. Отходить от него всегда можно (иначе слипнутся навсегда)
func too_close(other_pos: Vector2, pos: Vector2) -> bool:
	var gap = CELL * 0.8
	return other_pos.distance_to(pos) < gap and other_pos.distance_to(pos) < other_pos.distance_to(position)


func try_attack():
	if cooldown > 0.0:
		return
	cooldown = attack_cooldown
	player.take_damage(attack_damage)
	# маленький выпад в сторону игрока
	busy = true
	var start = position
	var dir = (player.position - position).normalized()
	var lunge = create_tween()
	lunge.tween_property(self, "position", start + dir * 8.0, 0.06)
	lunge.tween_property(self, "position", start, 0.06)
	await lunge.finished
	busy = false
