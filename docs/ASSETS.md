# Список моделей и промпты (стиль Meccha Chameleon)

Как пользоваться:
1. Копируй промпт в Meshy / Tripo / Mint (режим **3D Model**, не World).
2. Экспортируй **GLB**.
3. Клади в `assets/custom/` под именем из колонки **файл** (без изменений).
4. Раз открой проект в Godot (импорт) — модель подхватится сама.

## Единый промпт-префикс (клей стиля — добавляй к КАЖДОМУ)

> `low-poly, clean cartoon style, soft matte colors, smooth simple shapes,
> subtle bevels, no fine detail, readable silhouette, neutral studio lighting,
> single object, centered, resting on ground, style of a cozy co-op party game`

Это держит все модели в одном мире. Ниже — только «предметная» часть, префикс дописывай сам (или вставь один раз в системный промпт Meshy).

---

## Приоритет 1 — уникальные пропсы (нужны позарез, паков нет)

| файл | предметная часть промпта |
|---|---|
| `saw.glb` | a hand saw with wooden handle and metal blade |
| `rope_coil.glb` | a coiled rope loop, beige twisted cord |
| `bucket.glb` | a metal bucket, slightly dented, empty |
| `mousetrap.glb` | a classic wooden mousetrap with metal snap bar |
| `firecracker.glb` | a small red firecracker with a fuse |
| `banana_peel.glb` | a yellow banana peel splayed on the floor |
| `marbles.glb` | a small pile of colorful glass marbles |
| `pressure_plate.glb` | a square metal pressure trap plate, red button center |
| `glue_puddle.glb` | a glossy yellow glue puddle, flat on floor |
| `oil_puddle.glb` | a dark oil puddle, flat glossy on floor |
| `perfume.glb` | a vintage perfume bottle, pink glass, gold cap |
| `wire_spool.glb` | a spool of thin electric wire |
| `screwdriver.glb` | a screwdriver with red handle |
| `ladder.glb` | a small wooden step ladder |
| `suitcase.glb` | an open suitcase full of gadgets and tools |

## Приоритет 2 — драгоценности (цель игры, видны в руках грабителя)

| файл | предметная часть промпта |
|---|---|
| `jewel_ring.glb` | a diamond ring, gold band, sparkling gem |
| `jewel_necklace.glb` | a pearl and gold necklace |
| `jewel_crown.glb` | a small golden crown with red gems |
| `jewel_gold_bar.glb` | a shiny gold bar / ingot |
| `jewel_gem.glb` | a large cut ruby gemstone, faceted red |

## Приоритет 3 — персонажи (сложнее: нужен риг+анимации)

Персонажей НЕ генерим статичным GLB — им нужен скелет и анимации
(бег, установка, взлом). Путь: базовый риггованный персонаж (Meshy
Character mode с авто-ригом ИЛИ Mixamo-совместимая модель) + анимации
из Mixamo. Это отдельный этап после пропсов — не блокирует остальное.

Пока персонажи остаются процедурными (`minifig.gd`) как плейсхолдер.

| файл | предметная часть промпта (для будущего) |
|---|---|
| `kid_base.glb` | a small cartoon kid character, T-pose, simple proportions, rigged humanoid |
| `robber_base.glb` | a cartoon burglar in dark hoodie and beanie, T-pose, rigged humanoid |

## Приоритет 4 — мебель (пока хватает Kenney/KayKit-плейсхолдеров)

Заменяем позже точечно, если конкретный предмет выбивается из стиля.
Промпты по образцу: `a cozy living room sofa`, `a wooden wardrobe`,
`a kitchen fridge`, `a chandelier`, `a bookshelf`, `a fireplace`.

---

## Как проверять попадание в стиль

После добавления 2–3 моделей — прогони скриншот-тест
(`SANTA_SHOT=<папка> Godot --path .`) и глянь их в игре под нашим
контуром+светом. Если модель выбивается — крути промпт (обычно спасают
слова `flat colors`, `less detail`, `toy-like`). Сначала добиваемся
единства на паре моделей, потом гоним весь батч.
