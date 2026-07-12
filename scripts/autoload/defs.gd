extends Node
## Defs — все данные игры: персонажи, предметы, ловушки, комбо, локации, настройки матча.

# ---------------------------------------------------------------- ПЕРСОНАЖИ

const CHARACTERS := {
	"speedy": {
		"name": "Шустрик",
		"desc": "Самый быстрый в районе. Убегает от Санты, пока тот моргает.",
		"speed": 7.2,
		"place_mult": 1.0,
		"pocket_points": 10,
		"perk": "Скорость +30%",
		"shirt": Color(0.95, 0.55, 0.15), "pants": Color(0.25, 0.35, 0.55), "hat": Color(0.95, 0.55, 0.15),
	},
	"brains": {
		"name": "Умник",
		"desc": "Знает физику. Только он умеет ставить Сеть и Гирлянду-шокер.",
		"speed": 5.5,
		"place_mult": 1.0,
		"pocket_points": 8,
		"perk": "Эксклюзив: Сеть и Шокер. Карманы 8 оч.",
		"shirt": Color(0.35, 0.65, 0.85), "pants": Color(0.35, 0.3, 0.3), "hat": Color(0.9, 0.85, 0.6),
	},
	"tank": {
		"name": "Крепыш",
		"desc": "Тяжёлый на подъём, но из мешка Санты вырывается сам. Один раз.",
		"speed": 4.9,
		"place_mult": 1.15,
		"pocket_points": 12,
		"perk": "Сам вылезает из мешка (1 раз). Карманы 12 оч.",
		"shirt": Color(0.55, 0.75, 0.35), "pants": Color(0.4, 0.3, 0.25), "hat": Color(0.55, 0.75, 0.35),
	},
	"tiny": {
		"name": "Мелкая",
		"desc": "Мелкая и хитрая. Ставит ловушки почти вдвое быстрее, и Санта их хуже замечает.",
		"speed": 5.9,
		"place_mult": 0.6,
		"pocket_points": 9,
		"perk": "Установка x0.6, ловушки скрытнее",
		"shirt": Color(0.9, 0.4, 0.6), "pants": Color(0.5, 0.35, 0.55), "hat": Color(0.9, 0.4, 0.6),
	},
}

# ---------------------------------------------------------------- ПРЕДМЕТЫ (карманы)

const ITEMS := {
	"shards": {
		"name": "Битые игрушки", "cost": 1, "place_time": 1.2,
		"desc": "Россыпь стекла. Санта идёт по ним медленно и ойкает.",
		"only_char": "",
	},
	"tape": {
		"name": "Скотч", "cost": 1, "place_time": 1.0,
		"desc": "Полоса скотча липкой стороной вверх. Сильно тормозит, но хорошо заметна.",
		"only_char": "",
	},
	"rope": {
		"name": "Верёвка", "cost": 2, "place_time": 2.2,
		"desc": "Растяжка в проёме. Под люстрой — роняет люстру Санте на голову.",
		"only_char": "",
	},
	"oil": {
		"name": "Масло", "cost": 2, "place_time": 1.5,
		"desc": "Лужа масла. Санта поскальзывается. На плитке в ванной — вообще каток.",
		"only_char": "",
	},
	"glue": {
		"name": "Суперклей", "cost": 2, "place_time": 1.8,
		"desc": "Санта прилипает надолго. В дверном проёме — не отдерёшь.",
		"only_char": "",
	},
	"mousetrap": {
		"name": "Мышеловка", "cost": 2, "place_time": 1.0,
		"desc": "Классика. Щёлк — и Санта прыгает на одной ноге.",
		"only_char": "",
	},
	"cookie": {
		"name": "Печенье с молоком", "cost": 2, "place_time": 1.0,
		"desc": "Приманка! Санта не может пройти мимо. Пока жуёт — беззащитен. Ставь рядом с ловушками!",
		"only_char": "",
	},
	"firecracker": {
		"name": "Петарда", "cost": 3, "place_time": 1.6,
		"desc": "Санта пугается и убегает, бросив подарок. В камине — блокирует дымоход.",
		"only_char": "",
	},
	"bucket": {
		"name": "Ведро воды", "cost": 3, "place_time": 2.5,
		"desc": "Ставится только над дверным проёмом. Мокрый Санта — медленный Санта.",
		"only_char": "",
	},
	"garland_shock": {
		"name": "Гирлянда-шокер", "cost": 3, "place_time": 2.4,
		"desc": "Переделанная гирлянда Умника. Бьёт током, искрит, красиво.",
		"only_char": "brains",
	},
	"net": {
		"name": "Сеть", "cost": 4, "place_time": 3.0,
		"desc": "Инженерная ловушка Умника. Держит Санту дольше всего, ловить его проще.",
		"only_char": "brains",
	},
	"banana": {
		"name": "Банановая кожура", "cost": 1, "place_time": 0.8,
		"desc": "Классика жанра. Санта поскальзывается и улетает НАЗАД — прямо туда, откуда шёл. Комбинируй!",
		"only_char": "",
	},
	"marbles": {
		"name": "Шарики", "cost": 1, "place_time": 1.0,
		"desc": "Горсть стеклянных шариков. Санта теряет контроль и уезжает ВПЕРЁД по инерции.",
		"only_char": "",
	},
	"plate": {
		"name": "Нажимная плита", "cost": 2, "place_time": 1.8,
		"desc": "Самодельная плита-триггер. Рядом с люстрой или шкафом — роняет их С ЗАДЕРЖКОЙ, которую ты сам настраиваешь.",
		"only_char": "",
	},
	"perfume": {
		"name": "Бабушкины духи", "cost": 2, "place_time": 1.2,
		"desc": "Флакон «Сирень-ностальгия». Облако сбивает Санту с толку: голова кружится, все примеченные ловушки — забыты.",
		"only_char": "",
	},
}

# ---------------------------------------------------------------- ЛОВУШКИ
# ВАЖНО: ловушки, стоящие на соседних клетках, срабатывают ЦЕПОЧКОЙ,
# а установка рядом с другой ловушкой даёт комбо-бонус к качеству.

const TRAPS := {
	"shards": {
		"name": "Битые игрушки", "item": "shards",
		"slow": 0.35, "slow_dur": 2.5, "stun": 0.0, "vis": 0.65, "oneshot": false, "capture_mult": 1.0,
	},
	"tape": {
		"name": "Скотч", "item": "tape",
		"slow": 0.3, "slow_dur": 4.0, "stun": 1.0, "vis": 0.75, "oneshot": false, "capture_mult": 1.0,
	},
	"oil": {
		"name": "Масляная лужа", "item": "oil",
		"slow": 0.45, "slow_dur": 3.0, "stun": 2.8, "vis": 0.5, "oneshot": false, "capture_mult": 1.0,
	},
	"oil_tiles": {
		"name": "Каток в ванной", "item": "oil", "combo": "плитка",
		"slow": 0.35, "slow_dur": 4.0, "stun": 4.5, "vis": 0.4, "oneshot": false, "capture_mult": 1.2,
	},
	"glue": {
		"name": "Суперклей", "item": "glue",
		"slow": 1.0, "slow_dur": 0.0, "stun": 5.0, "vis": 0.55, "oneshot": true, "capture_mult": 1.0,
	},
	"glue_door": {
		"name": "Клей на пороге", "item": "glue", "combo": "дверь",
		"slow": 1.0, "slow_dur": 0.0, "stun": 7.0, "vis": 0.35, "oneshot": true, "capture_mult": 1.2,
	},
	"mousetrap": {
		"name": "Мышеловка", "item": "mousetrap",
		"slow": 0.6, "slow_dur": 3.0, "stun": 3.2, "vis": 0.45, "oneshot": true, "capture_mult": 1.0,
	},
	"rope_trip": {
		"name": "Растяжка", "item": "rope",
		"slow": 0.5, "slow_dur": 3.0, "stun": 4.0, "vis": 0.4, "oneshot": true, "capture_mult": 1.0,
	},
	"rope_chandelier": {
		"name": "Верёвка + Люстра", "item": "rope", "combo": "люстра",
		"slow": 0.5, "slow_dur": 4.0, "stun": 9.0, "vis": 0.35, "oneshot": true, "capture_mult": 1.5,
	},
	"bucket_door": {
		"name": "Ведро над дверью", "item": "bucket", "combo": "дверь",
		"slow": 0.45, "slow_dur": 10.0, "stun": 6.0, "vis": 0.25, "oneshot": true, "capture_mult": 1.2,
		"wet": true,
	},
	"firecracker": {
		"name": "Петарда", "item": "firecracker",
		"slow": 1.0, "slow_dur": 0.0, "stun": 0.5, "scare": true, "vis": 0.5, "oneshot": true, "capture_mult": 1.0,
	},
	"firecracker_chimney": {
		"name": "Петарда в камине", "item": "firecracker", "combo": "камин",
		"slow": 1.0, "slow_dur": 0.0, "stun": 0.0, "vis": 0.2, "oneshot": true, "capture_mult": 1.0,
		"blocks_entry": true,
	},
	"garland_shock": {
		"name": "Гирлянда-шокер", "item": "garland_shock",
		"slow": 0.6, "slow_dur": 4.0, "stun": 4.5, "vis": 0.5, "oneshot": true, "capture_mult": 1.3,
	},
	"net": {
		"name": "Сеть", "item": "net",
		"slow": 1.0, "slow_dur": 0.0, "stun": 8.0, "vis": 0.45, "oneshot": true, "capture_mult": 2.0,
	},
	"cookie": {
		"name": "Печенье с молоком", "item": "cookie",
		"slow": 1.0, "slow_dur": 0.0, "stun": 3.5, "vis": 0.12, "oneshot": true, "capture_mult": 1.4,
		"bait": true,
	},
	"banana": {
		"name": "Банановая кожура", "item": "banana",
		"slow": 1.0, "slow_dur": 0.0, "stun": 1.2, "vis": 0.45, "oneshot": true, "capture_mult": 1.0,
		"knock": -3.4,
	},
	"marbles": {
		"name": "Шарики", "item": "marbles",
		"slow": 0.5, "slow_dur": 3.0, "stun": 0.0, "vis": 0.5, "oneshot": false, "capture_mult": 1.0,
		"knock": 2.8,
	},
	"plate": {
		"name": "Нажимная плита", "item": "plate",
		"slow": 1.0, "slow_dur": 0.0, "stun": 1.0, "vis": 0.35, "oneshot": false, "capture_mult": 1.0,
	},
	"plate_link": {
		"name": "Плита-триггер", "item": "plate",
		"slow": 1.0, "slow_dur": 0.0, "stun": 0.5, "vis": 0.35, "oneshot": false, "capture_mult": 1.0,
		"linked": true,
	},
	"rope_link": {
		"name": "Растяжка-триггер", "item": "rope",
		"slow": 0.6, "slow_dur": 1.5, "stun": 1.0, "vis": 0.4, "oneshot": true, "capture_mult": 1.0,
		"linked": true,
	},
	"perfume": {
		"name": "Бабушкины духи", "item": "perfume",
		"slow": 0.85, "slow_dur": 4.0, "stun": 0.6, "vis": 0.4, "oneshot": true, "capture_mult": 1.15,
		"dizzy": 5.0, "disorient": true,
	},
}

## Короткое описание эффектов ловушки — для списка вариантов в HUD.
static func trap_fx(trap_id: String) -> String:
	var d: Dictionary = TRAPS[trap_id]
	var parts: Array = []
	if d.get("linked", false):
		parts.append("таймер!")
	if float(d["stun"]) >= 2.0:
		parts.append("стан %.0fс" % float(d["stun"]))
	if float(d["slow"]) < 1.0 and float(d["slow_dur"]) > 0.0:
		parts.append("замедл. %d%%" % int((1.0 - float(d["slow"])) * 100))
	if float(d.get("knock", 0.0)) < 0.0:
		parts.append("отлёт назад")
	elif float(d.get("knock", 0.0)) > 0.0:
		parts.append("скольжение")
	if float(d.get("dizzy", 0.0)) > 0.0:
		parts.append("головокружение")
	if d.get("disorient", false):
		parts.append("амнезия")
	if d.get("scare", false):
		parts.append("паника")
	if d.get("bait", false):
		parts.append("приманка")
	if d.get("blocks_entry", false):
		parts.append("блок входа")
	return " · ".join(parts)

const CARPET_VIS_MULT := 0.3
const CARPET_OK := ["shards", "glue", "mousetrap", "oil", "tape", "banana", "marbles", "plate"]

# Триггеры и объекты дома: верёвка/плита рядом с люстрой или шкафом
# роняет их с настраиваемой задержкой (колесо мыши во время установки).
const LINK_RANGE := 2                                # клеток до объекта
const LINK_DELAYS := [0.0, 0.5, 1.0, 1.5, 2.0, 3.0] # варианты задержки, сек
const CHANDELIER_AOE := 1.7                          # радиус удара упавшей люстры
const SHELF_AOE := 1.5                               # радиус падающего шкафа
const WET_DURATION := 12.0                           # сколько Санта «мокрый» после ведра

# ---------------------------------------------------------------- ЛОКАЦИИ

const LOCATIONS := {
	"cabin": {
		"name": "Дача у Лёхи",
		"desc": "Камин с дымоходом (блокируется петардой), две люстры, кабинет деда и веранда. 5 входов.",
		"size": Vector2i(24, 14),
		"rooms": [
			{"name": "Гостиная", "rect": Rect2i(0, 0, 10, 8), "floor": Color(0.72, 0.52, 0.34), "tag": ""},
			{"name": "Кухня", "rect": Rect2i(10, 0, 8, 5), "floor": Color(0.8, 0.86, 0.88), "tag": ""},
			{"name": "Спальня", "rect": Rect2i(10, 5, 8, 7), "floor": Color(0.65, 0.45, 0.3), "tag": ""},
			{"name": "Прихожая", "rect": Rect2i(0, 8, 10, 4), "floor": Color(0.6, 0.42, 0.28), "tag": ""},
			{"name": "Кабинет", "rect": Rect2i(18, 0, 6, 7), "floor": Color(0.58, 0.4, 0.26), "tag": ""},
			{"name": "Веранда", "rect": Rect2i(10, 12, 8, 2), "floor": Color(0.68, 0.55, 0.4), "tag": ""},
		],
		"doorways": [
			[Vector2i(9, 2), Vector2i(10, 2)],
			[Vector2i(3, 7), Vector2i(3, 8)],
			[Vector2i(13, 4), Vector2i(13, 5)],
			[Vector2i(9, 9), Vector2i(10, 9)],
			[Vector2i(17, 2), Vector2i(18, 2)],
			[Vector2i(17, 5), Vector2i(18, 5)],
			[Vector2i(13, 11), Vector2i(13, 12)],
		],
		"entries": [
			{"type": "door", "cell": Vector2i(4, 11), "out_dir": Vector2i(0, 1)},
			{"type": "chimney", "cell": Vector2i(0, 2), "out_dir": Vector2i(-1, 0)},
			{"type": "window", "cell": Vector2i(13, 0), "out_dir": Vector2i(0, -1)},
			{"type": "window", "cell": Vector2i(23, 3), "out_dir": Vector2i(1, 0)},
			{"type": "door", "cell": Vector2i(17, 13), "out_dir": Vector2i(1, 0)},
		],
		"props": [
			{"type": "chandelier", "cell": Vector2i(5, 4)},
			{"type": "chandelier", "cell": Vector2i(13, 8)},
			{"type": "fireplace", "cell": Vector2i(0, 2)},
			{"type": "tree", "cell": Vector2i(8, 6)},
		],
		"carpets": [Rect2i(4, 3, 3, 2), Rect2i(12, 7, 2, 2), Rect2i(19, 2, 3, 2)],
		"furniture": [
			{"type": "sofa", "cells": [Vector2i(3, 0), Vector2i(4, 0)], "rot": 180},
			{"type": "armchair", "cells": [Vector2i(6, 0)], "rot": 180},
			{"type": "tv", "cells": [Vector2i(4, 7), Vector2i(5, 7)], "rot": 0},
			{"type": "shelf", "cells": [Vector2i(0, 6)], "rot": 90},
			{"type": "table", "cells": [Vector2i(8, 1)], "rot": 0},
			{"type": "counter", "cells": [Vector2i(11, 0), Vector2i(12, 0)], "rot": 180},
			{"type": "fridge", "cells": [Vector2i(17, 0)], "rot": 270},
			{"type": "table", "cells": [Vector2i(14, 3), Vector2i(15, 3)], "rot": 0},
			{"type": "bed", "cells": [Vector2i(16, 6), Vector2i(17, 6), Vector2i(16, 7), Vector2i(17, 7)], "rot": 90},
			{"type": "wardrobe", "cells": [Vector2i(11, 11), Vector2i(12, 11)], "rot": 0},
			{"type": "lamp", "cells": [Vector2i(10, 5)], "rot": 0},
			{"type": "bench", "cells": [Vector2i(6, 11)], "rot": 0},
			{"type": "coat_rack", "cells": [Vector2i(0, 11)], "rot": 0},
			{"type": "boxes", "cells": [Vector2i(9, 11)], "rot": 0},
			{"type": "table", "cells": [Vector2i(20, 0), Vector2i(21, 0)], "rot": 180},
			{"type": "shelf", "cells": [Vector2i(23, 0)], "rot": 270},
			{"type": "armchair", "cells": [Vector2i(19, 6)], "rot": 0},
			{"type": "lamp", "cells": [Vector2i(23, 6)], "rot": 0},
			{"type": "bench", "cells": [Vector2i(10, 12)], "rot": 90},
			{"type": "boxes", "cells": [Vector2i(16, 12)], "rot": 0},
		],
		"present_spots": [Vector2i(7, 6), Vector2i(8, 4), Vector2i(16, 9), Vector2i(16, 1), Vector2i(1, 10), Vector2i(21, 4), Vector2i(14, 12)],
		"kid_spawn": Vector2i(5, 5),
	},
	"flat": {
		"name": "Квартира Макса",
		"desc": "Камина нет — Санта лезет через балкон. Куча дверей под вёдра, плитка в ванной, детская и кабинет.",
		"size": Vector2i(20, 12),
		"rooms": [
			{"name": "Гостиная", "rect": Rect2i(0, 0, 10, 4), "floor": Color(0.74, 0.56, 0.38), "tag": ""},
			{"name": "Кухня", "rect": Rect2i(10, 0, 6, 6), "floor": Color(0.8, 0.86, 0.88), "tag": ""},
			{"name": "Коридор", "rect": Rect2i(6, 4, 4, 8), "floor": Color(0.62, 0.46, 0.32), "tag": ""},
			{"name": "Ванная", "rect": Rect2i(0, 4, 6, 4), "floor": Color(0.72, 0.88, 0.92), "tag": "плитка"},
			{"name": "Кладовка", "rect": Rect2i(0, 8, 6, 4), "floor": Color(0.55, 0.42, 0.3), "tag": ""},
			{"name": "Спальня", "rect": Rect2i(10, 6, 6, 6), "floor": Color(0.68, 0.5, 0.34), "tag": ""},
			{"name": "Детская", "rect": Rect2i(16, 0, 4, 6), "floor": Color(0.75, 0.6, 0.5), "tag": ""},
			{"name": "Кабинет", "rect": Rect2i(16, 6, 4, 6), "floor": Color(0.6, 0.44, 0.3), "tag": ""},
		],
		"doorways": [
			[Vector2i(7, 3), Vector2i(7, 4)],
			[Vector2i(9, 1), Vector2i(10, 1)],
			[Vector2i(9, 5), Vector2i(10, 5)],
			[Vector2i(9, 8), Vector2i(10, 8)],
			[Vector2i(5, 5), Vector2i(6, 5)],
			[Vector2i(5, 9), Vector2i(6, 9)],
			[Vector2i(15, 3), Vector2i(16, 3)],
			[Vector2i(15, 8), Vector2i(16, 8)],
			[Vector2i(18, 5), Vector2i(18, 6)],
		],
		"entries": [
			{"type": "door", "cell": Vector2i(7, 11), "out_dir": Vector2i(0, 1)},
			{"type": "window", "cell": Vector2i(12, 0), "out_dir": Vector2i(0, -1)},
			{"type": "balcony", "cell": Vector2i(0, 1), "out_dir": Vector2i(-1, 0)},
			{"type": "window", "cell": Vector2i(19, 2), "out_dir": Vector2i(1, 0)},
		],
		"props": [
			{"type": "chandelier", "cell": Vector2i(5, 2)},
			{"type": "chandelier", "cell": Vector2i(12, 8)},
			{"type": "tree", "cell": Vector2i(1, 1)},
		],
		"carpets": [Rect2i(4, 1, 3, 2), Rect2i(12, 8, 2, 2), Rect2i(17, 2, 2, 2)],
		"furniture": [
			{"type": "sofa", "cells": [Vector2i(4, 0), Vector2i(5, 0)], "rot": 180},
			{"type": "tv", "cells": [Vector2i(4, 3), Vector2i(5, 3)], "rot": 0},
			{"type": "shelf", "cells": [Vector2i(9, 0)], "rot": 90},
			{"type": "counter", "cells": [Vector2i(10, 0), Vector2i(11, 0)], "rot": 180},
			{"type": "fridge", "cells": [Vector2i(13, 0)], "rot": 180},
			{"type": "table", "cells": [Vector2i(12, 4), Vector2i(13, 4)], "rot": 0},
			{"type": "shelf", "cells": [Vector2i(6, 11)], "rot": 0},
			{"type": "boxes", "cells": [Vector2i(9, 11)], "rot": 0},
			{"type": "tub", "cells": [Vector2i(0, 4), Vector2i(1, 4)], "rot": 180},
			{"type": "sink", "cells": [Vector2i(4, 4)], "rot": 180},
			{"type": "toilet", "cells": [Vector2i(0, 7)], "rot": 90},
			{"type": "boxes", "cells": [Vector2i(0, 8)], "rot": 0},
			{"type": "boxes", "cells": [Vector2i(0, 11)], "rot": 0},
			{"type": "boxes", "cells": [Vector2i(4, 11)], "rot": 0},
			{"type": "bed", "cells": [Vector2i(14, 6), Vector2i(15, 6), Vector2i(14, 7), Vector2i(15, 7)], "rot": 90},
			{"type": "wardrobe", "cells": [Vector2i(10, 11), Vector2i(11, 11)], "rot": 0},
			{"type": "lamp", "cells": [Vector2i(15, 11)], "rot": 0},
			{"type": "bed", "cells": [Vector2i(18, 4), Vector2i(19, 4)], "rot": 90},
			{"type": "boxes", "cells": [Vector2i(16, 0)], "rot": 0},
			{"type": "shelf", "cells": [Vector2i(19, 0)], "rot": 270},
			{"type": "table", "cells": [Vector2i(17, 7), Vector2i(18, 7)], "rot": 0},
			{"type": "armchair", "cells": [Vector2i(16, 11)], "rot": 0},
			{"type": "shelf", "cells": [Vector2i(19, 11)], "rot": 270},
		],
		"present_spots": [Vector2i(2, 2), Vector2i(3, 3), Vector2i(14, 1), Vector2i(14, 10), Vector2i(2, 10), Vector2i(18, 1), Vector2i(18, 10)],
		"kid_spawn": Vector2i(8, 8),
	},
}

# ---------------------------------------------------------------- СКИНЫ

const SKINS := {
	"base": {"name": "Свой стиль", "cost": 0},
	"frost": {"name": "Морозный", "cost": 150, "shirt": Color(0.55, 0.8, 0.95), "pants": Color(0.2, 0.3, 0.5), "hat": Color(0.9, 0.95, 1.0)},
	"elf": {"name": "Эльф-предатель", "cost": 250, "shirt": Color(0.2, 0.65, 0.3), "pants": Color(0.7, 0.15, 0.15), "hat": Color(0.2, 0.65, 0.3)},
	"gold": {"name": "Золотой", "cost": 400, "shirt": Color(0.95, 0.8, 0.25), "pants": Color(0.55, 0.4, 0.1), "hat": Color(0.95, 0.8, 0.25)},
}

const PERK_POCKET_COST := 500

# ---------------------------------------------------------------- МАТЧ (дефолты; лобби может менять)

const PREP_TIME := 45.0
const MATCH_TIME := 240.0
const PREP_OPTIONS := [30.0, 45.0, 60.0, 90.0]
const TIME_OPTIONS := [180.0, 240.0, 300.0, 360.0]
const ENRAGE_TIME := 60.0
const COOKIE_LURE_RANGE := 14.0
const CHAIN_DELAY := 0.35    # задержка цепного срабатывания соседних ловушек
const CHAIN_RANGE := 1.9     # Санта должен быть рядом, чтобы цепь его задела
const COMBO_QUALITY_BONUS := 0.08  # к качеству за каждую соседнюю ловушку

# --- ХАОС-КОМБО: цепочки попаданий за короткое окно копят «стиль»
const COMBO_WINDOW := 4.5    # секунд между попаданиями, чтобы цепь не оборвалась
const COMBO_BASE_STYLE := 30 # очков стиля за звено (умножается на длину цепи)
const STYLE_TO_COINS := 12   # столько очков стиля = 1 монета в награду

## Именованные связки: если id ловушек цепочки содержат последовательность seq
## (как подпоследовательность, по порядку) — комбо получает имя и бонус.
## secret=true — не показываем в подсказках, игрок открывает сам.
const NAMED_COMBOS := [
	{"name": "КАРУСЕЛЬ", "seq": ["marbles", "banana", "marbles"], "bonus": 120, "secret": true,
		"desc": "Шарики → банан → снова шарики: Санта катается туда-сюда."},
	{"name": "МОКРОЕ ДЕЛО", "seq": ["bucket_door", "garland_shock"], "bonus": 150, "secret": true,
		"desc": "Окати водой, потом шокер — ток проходит идеально."},
	{"name": "ПРЕИСПОДНЯЯ", "seq": ["firecracker", "fire"], "bonus": 140, "secret": true,
		"desc": "Петарда поджигает масляную лужу."},
	{"name": "ГРАВИТАЦИЯ", "seq": ["chandelier_drop"], "bonus": 100, "secret": false,
		"desc": "Урони люстру триггером в нужный момент."},
	{"name": "ЛИПКИЙ ОБЕД", "seq": ["glue", "cookie"], "bonus": 90, "secret": true,
		"desc": "Клей вплотную к печенью — Санта жуёт, приклеившись."},
	{"name": "КАТОК", "seq": ["oil_tiles", "shards"], "bonus": 80, "secret": false,
		"desc": "Масло на плитке в связке с битыми игрушками."},
	{"name": "НОКАУТ", "seq": ["shelf_drop"], "bonus": 100, "secret": false,
		"desc": "Завали Санту шкафом."},
	{"name": "ТЕЛЕМАСТЕР", "seq": ["tv_spark"], "bonus": 90, "secret": false,
		"desc": "Ударь Санту током от телевизора."},
	{"name": "МОКРОЕ КОРОТКОЕ", "seq": ["bucket_door", "tv_spark"], "bonus": 170, "secret": true,
		"desc": "Окати водой из ведра, потом шибани телевизором — короткое замыкание."},
	{"name": "КОВЁР-САМОЛЁТ", "seq": ["rug_pull"], "bonus": 85, "secret": false,
		"desc": "Выдерни ковёр прямо из-под Санты."},
	{"name": "ФОКУСНИК", "seq": ["fridge_drop", "shards"], "bonus": 110, "secret": true,
		"desc": "Молоко из холодильника прячет ловушки — Санта влетает в спрятанные битые игрушки."},
]

## Тир цепочки по длине — цвет и подпись для HUD.
static func combo_tier(mult: int) -> Dictionary:
	if mult >= 5:
		return {"name": "ЛЕГЕНДАРНЫЙ ХАОС", "color": Color(1.0, 0.35, 0.85)}
	elif mult >= 4:
		return {"name": "БЕЗУМИЕ", "color": Color(1.0, 0.4, 0.3)}
	elif mult >= 3:
		return {"name": "ХАОС", "color": Color(1.0, 0.6, 0.2)}
	elif mult >= 2:
		return {"name": "КОМБО", "color": Color(1.0, 0.82, 0.35)}
	return {"name": "", "color": Color(0.9, 0.9, 1.0)}

const CAPTURE_NEED := 100.0
const CAPTURE_RATE := 30.0
const CAPTURE_DECAY := 5.0
const CAPTURE_RANGE := 3.5
const SACK_RANGE := 1.6
const SACK_COOLDOWN := 12.0
const SACK_MASH_NEED := 10

# Фишки Санты-игрока
const SANTA_SENSE_CD := 18.0   # Q — «чуйка»: подсветить ловушки рядом
const SANTA_SENSE_RANGE := 9.0
const SANTA_HOHO_CD := 15.0    # R — «ХО-ХО-ХО»: пугает пацанов, сбивает установку
const SANTA_HOHO_RANGE := 7.0
const SANTA_PSENSE_CD := 10.0  # F — «чуйка на подарки»: примерные зоны доставки
const PSENSE_SPOT_FUZZ := 1.6  # случайный сдвиг подсказки от точного места (клеток)
const PSENSE_REVEAL := 2.6     # с какого расстояния метка доставки «теплеет» Санте

const REWARD_CATCH := [120, 60]
const REWARD_SCARE := [40, 30]
const REWARD_LOSE := [10, 10]

# ---------------------------------------------------------------- INPUT

func _ready() -> void:
	_add_key("move_fwd", KEY_W)
	_add_key("move_back", KEY_S)
	_add_key("move_left", KEY_A)
	_add_key("move_right", KEY_D)
	_add_key("jump", KEY_SPACE)
	_add_key("sprint", KEY_SHIFT)
	_add_key("trap_mode", KEY_F)
	_add_key("interact", KEY_E)
	_add_key("ability1", KEY_Q)
	_add_key("ability2", KEY_R)
	_add_key("pause", KEY_ESCAPE)

func _add_key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)

# ---------------------------------------------------------------- ХЕЛПЕРЫ

static func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x + 0.5, 0.0, cell.y + 0.5)

static func world_to_cell(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x), floori(pos.z))

static func flat_mat(color: Color, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m

# --- текстурные материалы (шум вместо плоской заливки — живая поверхность)

static var _tex_wood: NoiseTexture2D
static var _tex_plaster: NoiseTexture2D
static var _tex_fabric: NoiseTexture2D

static func _noise_tex(freq: float, from: Color, to: Color) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n.frequency = freq
	n.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.noise = n
	t.seamless = true
	t.width = 256
	t.height = 256
	var g := Gradient.new()
	g.set_color(0, from)
	g.set_color(1, to)
	t.color_ramp = g
	return t

static func _base_textured(tex: NoiseTexture2D, color: Color, rough: float, scale: Vector3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = tex
	m.uv1_triplanar = true
	m.uv1_scale = scale
	m.roughness = rough
	return m

## Дерево: вытянутые прожилки (растяжка по двум осям, чтобы и пол, и стойки были в полоску).
static func wood_mat(color: Color) -> StandardMaterial3D:
	if _tex_wood == null:
		_tex_wood = _noise_tex(0.012, Color(0.8, 0.77, 0.74), Color(1, 1, 1))
	return _base_textured(_tex_wood, color, 0.75, Vector3(0.35, 5.0, 5.0))

## Штукатурка/камень: мягкие пятна.
static func plaster_mat(color: Color) -> StandardMaterial3D:
	if _tex_plaster == null:
		_tex_plaster = _noise_tex(0.05, Color(0.88, 0.87, 0.85), Color(1, 1, 1))
	return _base_textured(_tex_plaster, color, 0.95, Vector3(0.6, 0.6, 0.6))

## Ткань: мелкое зерно.
static func fabric_mat(color: Color) -> StandardMaterial3D:
	if _tex_fabric == null:
		_tex_fabric = _noise_tex(0.35, Color(0.82, 0.8, 0.8), Color(1, 1, 1))
	return _base_textured(_tex_fabric, color, 1.0, Vector3(2.0, 2.0, 2.0))
