extends Node
## SaveGame — прогрессия: монеты, опыт персонажей, скины, перки. user://save.json

const PATH := "user://save.json"

var data: Dictionary = {}

func _ready() -> void:
	load_save()

func _default() -> Dictionary:
	var chars := {}
	for id in Defs.CHARACTERS:
		chars[id] = {"xp": 0, "skins": ["base"], "skin": "base"}
	return {"coins": 0, "chars": chars, "perk_pocket": false, "catches": 0}

func load_save() -> void:
	data = _default()
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			# аккуратно домёрживаем, чтобы старые сейвы не ломались при апдейтах
			for k in parsed:
				if k == "chars":
					for cid in parsed["chars"]:
						if data["chars"].has(cid):
							for f2 in parsed["chars"][cid]:
								data["chars"][cid][f2] = parsed["chars"][cid][f2]
				else:
					data[k] = parsed[k]

func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  "))

# ---------------------------------------------------------------- ПРОГРЕССИЯ

func coins() -> int:
	return int(data["coins"])

func add_coins(n: int) -> void:
	data["coins"] = coins() + n
	save()

func char_level(id: String) -> int:
	return clampi(1 + int(data["chars"][id]["xp"]) / 100, 1, 10)

func char_xp(id: String) -> int:
	return int(data["chars"][id]["xp"])

func add_xp(id: String, n: int) -> void:
	data["chars"][id]["xp"] = char_xp(id) + n
	save()

## Множитель скорости установки ловушек от уровня: -3% за уровень, до -27%.
func place_level_mult(id: String) -> float:
	return 1.0 - 0.03 * float(char_level(id) - 1)

## Бонусные очки карманов: +1 на 3/6/9 уровнях, +1 за перк из магазина.
func bonus_pocket_points(id: String) -> int:
	var lv := char_level(id)
	var bonus := 0
	for threshold in [3, 6, 9]:
		if lv >= threshold:
			bonus += 1
	if data.get("perk_pocket", false):
		bonus += 1
	return bonus

func pocket_points(id: String) -> int:
	return int(Defs.CHARACTERS[id]["pocket_points"]) + bonus_pocket_points(id)

# ---------------------------------------------------------------- СКИНЫ

func owns_skin(char_id: String, skin_id: String) -> bool:
	return skin_id in data["chars"][char_id]["skins"]

func buy_skin(char_id: String, skin_id: String) -> bool:
	var cost := int(Defs.SKINS[skin_id]["cost"])
	if owns_skin(char_id, skin_id) or coins() < cost:
		return false
	data["coins"] = coins() - cost
	data["chars"][char_id]["skins"].append(skin_id)
	data["chars"][char_id]["skin"] = skin_id
	save()
	return true

func set_skin(char_id: String, skin_id: String) -> void:
	if owns_skin(char_id, skin_id):
		data["chars"][char_id]["skin"] = skin_id
		save()

## Итоговые цвета персонажа с учётом активного скина.
func char_colors(char_id: String) -> Dictionary:
	var base: Dictionary = Defs.CHARACTERS[char_id]
	var skin_id: String = data["chars"][char_id]["skin"]
	var skin: Dictionary = Defs.SKINS.get(skin_id, {})
	return {
		"shirt": skin.get("shirt", base["shirt"]),
		"pants": skin.get("pants", base["pants"]),
		"hat": skin.get("hat", base["hat"]),
	}

func buy_perk_pocket() -> bool:
	if data.get("perk_pocket", false) or coins() < Defs.PERK_POCKET_COST:
		return false
	data["coins"] = coins() - Defs.PERK_POCKET_COST
	data["perk_pocket"] = true
	save()
	return true
