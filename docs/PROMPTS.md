# Все промпты для 3D-моделей (готовы к копированию)

Стиль-префикс вшит в каждый промпт. Режим **3D Model** (Meshy/Tripo/Mint) → GLB
→ оптимизировать (см. ASSETS.md) → в `assets/custom/` под именем файла.

✅ = уже сгенерено и в игре · ⬜ = нужно сделать

**Актуализировано 2026-07-14 — СМЕНА СТИЛЯ.** После сравнения с купленным
паком архитектуры/мебели («Interior Realistic», уровень Simplified Realism)
целевой стиль сдвинут от плоского мультика к **тёплому полуреализму**:
мягкие скруглённые края вместо острых углов, настоящая фактура материала
(дерево/ткань/металл), но всё ещё низкополигональная читаемая форма —
без фотореалистичной детализации. Причина: старый префикс (`clean cartoon
style, no fine detail`) давал более плоские и угловатые модели, чем нужно
для сочетания с паком архитектуры.

⚠️ **Уже готовые 19 моделей (✅) генерились под СТАРЫЙ префикс** — они
остаются как есть (это мелкие пропсы, разница не критична, переделывать
не нужно). Все промпты ниже уже переписаны под НОВЫЙ префикс — если решишь
перегенерить что-то из готового под новый стиль, бери промпт из файла
(он актуальный), а не то, что использовалось раньше.

Раздел «Мебель» — с тегами разрушаемости (🗄️🪚💥🔨⚡🎯, легенда — в начале
раздела), разбит по приоритету геймплея. Приоритет 0 — архитектурный кит
(стены/пол/карниз/дверь) закрыт покупным паком, эти промпты теперь резерв
на случай докупки штучных модулей. Итого в списке — 79 моделей (24 готово,
в старом стиле). Код (`ModelLib.place_stretch`) уже умеет подхватывать
архитектурные модели без правок — см. ASSETS.md.

## Как писать хорошие промпты (важно!)

Text-to-3D понимает слова буквально. «bear trap» → плюшевый мишка на мышеловке
(реальный факт из наших тестов). Правила:

1. **Никаких двусмысленных названий.** Не «bear trap», а «steel foothold trap
   with two semicircular spring jaws». Описывай МЕХАНИЗМ, а не жаргонное имя.
2. **Опиши форму и части**, а не только название: «X с Y и Z», из чего состоит,
   какого цвета, как стоит.
3. **Негативы в конце** отсекают ложные трактовки: `not an animal, not a toy`.
4. **Состояние/ракурс**: «open flat on the ground», «upright», «lid closed».
5. Держи стиль-префикс — он про look, а хвост — про сам предмет. Если модель
   вышла угловатой — усиль в хвосте `rounded edges, no sharp corners`,
   это сильнее одного упоминания в префиксе.

Шаблон: `<префикс>, <что это + форма + части + материал + цвет>, <состояние>, <негативы>`

**Текущий стиль-префикс (Simplified Realism, тёплый):**
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground`

---

## Приоритет 0 — АРХИТЕКТУРНЫЙ КИТ (важнее любой мебели!)

**Почему это приоритет 0:** сейчас стены/пол — плоские окрашенные ящики без
единой детали геометрии, и именно это делает дом «дешёвым» рядом с твоими
моделями предметов. Чтобы дом выглядел на уровне Meccha Chameleon (лепнина,
объём, фактура), каркас должен состоять из ТАКИХ ЖЕ сгенерённых модулей —
раскладку комнат по-прежнему строит код (это правильно и остаётся), но сам
модуль стены теперь настоящая 3D-модель с молдингом.

Код уже готов принять эти модели (`ModelLib.place_stretch` — точная
растяжка под размер сетки, без искажения детализации): как только положишь
файл в `assets/custom/`, стены на экране заменятся с ящика на модель
автоматически, без правки кода.

⬜ **wall_panel.glb** (сегмент стены — 1×3×тонкий, обязателен к пропорции!)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, style of a cozy co-op party game, a tall narrow flat interior wall panel section proportioned about one unit wide and three units tall and very thin, cream wallpaper surface, a white wooden baseboard molding strip along the bottom edge, a thin horizontal wood picture-rail trim strip about two thirds up the height, smooth flat wall between the trims, standalone flat panel, not a door, not a window, not furniture, not a room, no visible corners on the sides`

⬜ **wall_corner.glb** (внутренний угол стены — стыкует 2 панели, опционально)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, style of a cozy co-op party game, a tall narrow L-shaped interior wall corner piece about three units tall, matching cream wallpaper with a white baseboard molding wrapping around the corner, not a full room, not a door`

⬜ **floor_plank_tile.glb** (пол — 1×1 модуль, плитка под дерево)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, top-down centered, style of a cozy co-op party game, a small flat square floor tile module about one unit wide made of warm honey-colored wooden planks with visible plank seams, very thin, flat resting surface, not a rug, not furniture`

⬜ **floor_tile_bath.glb** (пол ванной/плитка — 1×1 модуль)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, top-down centered, style of a cozy co-op party game, a small flat square glossy ceramic floor tile module about one unit wide, pale blue-white tile with thin grout lines, glossy reflective surface, very thin, not a rug`

⬜ **ceiling_cornice.glb** (потолочный карниз — декоративная кромка, опционально)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, style of a cozy co-op party game, a short straight decorative crown molding strip for a ceiling edge, white ornate plaster trim profile, about one unit long, not a wall panel, not a baseboard`

⬜ **door_interior.glb** (дверное полотно — на будущее, петли снимаются)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, upright, style of a cozy co-op party game, a simple flat wooden interior door leaf with a round handle and three visible hinges on one side, closed, not a door frame, not double doors, not a wall panel`

---

## Ловушки-предметы

✅ **saw.glb**
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a hand saw with wooden handle and metal blade`

✅ **mousetrap.glb**
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a classic wooden mousetrap with metal snap bar`

✅ **rope_coil.glb**
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a coiled rope loop, beige twisted cord`

✅ **banana_peel.glb**
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a yellow banana peel splayed on the floor`

✅ **firecracker.glb**
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a small red firecracker with a fuse`

✅ **marbles.glb**
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a small pile of colorful glass marbles`

✅ **pressure_plate.glb**
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a square metal pressure trap plate with a red button in the center`

✅ **perfume.glb**
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a vintage perfume bottle, pink glass with a gold cap`

✅ **wire_spool.glb**
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a spool of thin electric wire`

⬜ **shards.glb** (битые ёлочные игрушки)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, top-down centered, style of a cozy co-op party game, a small flat scatter of shattered christmas bauble pieces on the floor, sharp colorful glass fragments red green gold, spread in a low pile, not whole ornaments, not a plate`

✅ **tape.glb** (скотч)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a roll of duct tape`

⬜ **oil_puddle.glb** (масляная лужа)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, top-down centered, style of a cozy co-op party game, a flat glossy puddle of dark motor oil spread on the floor, irregular blob shape, very thin and flat, reflective black-brown liquid, not a container, not a barrel`

⬜ **glue_puddle.glb** (клей)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, top-down centered, style of a cozy co-op party game, a flat glossy puddle of sticky yellow glue spread on the floor, irregular blob shape, very thin and flat, glossy honey-colored liquid, not a bottle, not a container`

✅ **cookie_plate.glb** (печенье с молоком — приманка)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a plate of cookies with a glass of milk`

✅ **bucket.glb** (ведро воды — над дверью)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a metal bucket filled with water`

✅ **garland_shock.glb** (гирлянда-шокер)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a string of christmas lights with colorful bulbs`

⬜ **net.glb** (сеть)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, top-down centered, style of a cozy co-op party game, a square rope mesh capture net laid flat on the floor, thick beige rope grid with knotted intersections and weighted corner balls, spread open, not a hammock, not a bag, not a fishing rod`

## Новые ловушки (из списка связок)

✅ **iron.glb** (утюг — падает)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a household clothes iron`

✅ **weight.glb** (гиря-маятник)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a black round gym kettlebell weight`

⬜ **bowling_ball.glb**
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a glossy blue bowling ball`

⬜ **paint_bucket.glb** (ведро краски)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, upright centered, style of a cozy co-op party game, a cylindrical metal paint can with a wire handle, open top full of bright blue paint, one drip down the side, not a bucket of water, not a flower pot`

⬜ **flour_bag.glb** (мешок муки)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, upright centered, style of a cozy co-op party game, a plump paper flour sack standing upright, rolled top, cream-white paper with a simple flour label, dusty look, not a pillow, not a sandbag`

⬜ **bear_trap.glb** (капкан — стальной, с дугами-челюстями)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, top-down centered, style of a cozy co-op party game, a steel foothold hunting trap lying open flat on the floor, two semicircular spring-loaded metal jaws with blunt rounded teeth, a round flat pressure plate in the middle, a short chain, grey metal, not an animal, not a bear, not a teddy, not a mousetrap`

✅ **smoke_bomb.glb** (дымовая шашка)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, upright centered, style of a cozy co-op party game, a small cylindrical smoke grenade canister standing upright, metal tube with a ring pull on top, olive-green body, one simple stripe, not an explosion, not smoke clouds, not a bottle`

✅ **flowerpot.glb** (горшок — падает с окна)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a terracotta flower pot with a small plant`

⬜ **toaster.glb** (тостер-ловушка)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, upright centered, style of a cozy co-op party game, a classic two-slot pop-up kitchen toaster, rounded chrome body with two slots on top and a side lever, light blue and chrome, not bread, not a microwave`

⬜ **hair_dryer.glb** (фен — в воду)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, style of a cozy co-op party game, a handheld blow dryer with a round barrel nozzle and a pistol grip handle and a cord, pastel pink and white, not a gun, not a vacuum`

✅ **spray_can.glb** (баллончик)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, upright centered, style of a cozy co-op party game, a tall cylindrical aerosol spray can standing upright with a round push-button cap on top, glossy metal body with one color label band, not a bottle, not a barrel`

⬜ **fire_extinguisher.glb**
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a red fire extinguisher`

⬜ **roller_skates.glb** (коньки)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a single quad roller skate boot with four wheels on the bottom, white boot with red laces, side view upright, not ice skates, not a shoe without wheels`

⬜ **lego_bricks.glb** (лего россыпью)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, top-down centered, style of a cozy co-op party game, a small flat scatter of loose colorful toy building blocks with round studs on top, red blue yellow green, spread on the floor, not stacked, not a built model`

⬜ **soap_bar.glb** (мыло)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a single rounded rectangular bar of soap lying flat, glossy pastel blue, smooth rounded edges, not a sponge, not a box`

⬜ **alarm_clock.glb** (будильник — приманка)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, upright centered, style of a cozy co-op party game, a retro round analog alarm clock standing on two little feet, two bells on top with a hammer between them, red frame with a white clock face, not a wall clock, not a smartphone`

⬜ **glitter_bomb.glb**
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, upright centered, style of a cozy co-op party game, a small closed cardboard tube canister standing upright, pink and gold label, sealed lid, a party popper container, not an explosion, not scattered glitter, not confetti in the air`

## Инструменты

✅ **screwdriver.glb**
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a screwdriver with a red handle`

✅ **ladder.glb**
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a small wooden step ladder`

✅ **suitcase.glb** (стартовый чемодан)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, an open suitcase full of gadgets and tools`

✅ **hammer.glb** (молоток — заколотить окно)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a claw hammer with a wooden handle`

✅ **scissors.glb** (ножницы — резать провод)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a pair of scissors with orange handles`

⬜ **crowbar.glb** (лом — грабитель взламывает)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a red metal crowbar`

## Драгоценности (цель игры)

✅ **jewel_ring.glb**
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a diamond ring with a gold band and a sparkling gem`

⬜ **jewel_necklace.glb**
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a looped string of round white pearls with a small gold clasp, laid in a coil, not a chain, not a rope`

⬜ **jewel_crown.glb**
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, upright centered, style of a cozy co-op party game, a small round golden royal crown with five pointed tips, each tip topped with a red gem, gold band base, upright, not a hat, not a ring`

⬜ **jewel_gold_bar.glb**
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a single shiny trapezoidal gold bullion ingot lying flat, smooth polished gold, one stamped rectangle on top, not a stack, not a brick wall`

⬜ **jewel_gem.glb**
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, upright centered, style of a cozy co-op party game, a single large faceted red ruby gemstone, classic diamond cut with flat facets, translucent glossy red, pointed bottom flat top, not a sphere, not a crystal cluster`

⬜ **safe.glb** (сейф — жирный куш)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, upright centered, style of a cozy co-op party game, a small heavy cube-shaped vault safe standing on the floor, a single closed metal door with a round combination dial and a lever handle, dark grey steel with gold trim, door closed, not a cabinet, not a box, not a fridge`

## Мебель (заменить Kenney-плейсхолдеры) — с разрушаемостью

**Легенда поведения** (что мебель умеет в игре, помимо картинки):
🗄️ обыскивается (E — ищем лут/драгоценность) · 🪚 подпиливается (падает от
растяжки) · 💥 переворачивается/роняется целиком · 🔨 взламывается
(петли/замок) · ⚡ электро-объект · 🎯 просто декор/препятствие.

Для 🗄️/💥 модель нужна ЦЕЛОЙ, закрытой — открывание и опрокидывание делает
код (тот же приём, что уже работает для шкафа/холодильника: тряска, наклон,
запись «топлено»). Отдельных «открытых» вариантов генерить НЕ нужно, если
не хочешь заметно другую картинку нараспашку.

### Приоритет 1 — то, что двигает геймплей (обыск/падение)

⬜ **wardrobe.glb** 🗄️💥 (шкаф — обыскивается И роняется)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a tall wooden wardrobe closet with two front doors and a small top cornice, closed doors, not open, not a bookshelf`

⬜ **shelf.glb** 🗄️💥🪚 (стеллаж — обыскивается, роняется, ножки подпиливаются)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a tall wooden bookshelf with several rows of books and small knick-knacks, four visible short legs at the bottom, not a wardrobe, not a cabinet with doors`

⬜ **fridge.glb** 🗄️💥⚡ (холодильник — лут, роняется, разливает молоко)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a rounded retro kitchen refrigerator with a single door and a metal handle, pastel mint-green body, closed door, not open, not a cabinet`

⬜ **nightstand.glb** 🗄️🪚 (тумбочка — лут, ножки подпиливаются)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a small bedside nightstand with one drawer and short thin legs, closed drawer, not open`

⬜ **counter.glb** 🗄️ (кухонная тумба — лут)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a kitchen counter cabinet with two closed cupboard doors and a flat countertop, not open, not a fridge`

⬜ **desk.glb** 🗄️🪚 (письменный стол — лут в ящике, ножки подпиливаются)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a wooden office desk with one side drawer and four thin straight legs, not a dining table`

⬜ **boxes.glb** 🗄️💥 (коробки — лут, легко опрокидываются)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a stack of three closed cardboard moving boxes of different sizes, tape seams visible, not open boxes`

⬜ **bed.glb** 🗄️ (кровать — лут под подушкой)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a cozy single bed with a thick blanket and one pillow, low wooden bed frame`

### Приоритет 2 — падающие/бьющиеся объекты (не обыскиваются)

⬜ **table.glb** 🪚💥 (стол — ножки подпиливаются, падает утварь)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a simple round wooden dining table with four thin straight legs, bare tabletop, not a desk`

⬜ **chair.glb** 🪚💥 (стул — подпиленный ломается под весом)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a simple wooden dining chair with a straight backrest and four thin legs, not an armchair, not a stool`

⬜ **tv.glb** 💥⚡ (телевизор — искрит, падает с тумбы)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a retro boxy television set with a rounded screen and two antenna prongs on top, dark grey plastic body, screen off, not a monitor, not a laptop`

⬜ **chandelier.glb** 💥 (люстра — падает)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, style of a cozy co-op party game, a round metal ceiling chandelier with a central column and several curved arms holding candle-shaped bulbs, a short chain on top, warm gold metal, hanging orientation, not a lamp, not a ceiling fan`

⬜ **lamp.glb** 💥 (торшер — опрокидывается)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a standing floor lamp with a round base, a thin pole, and a cone-shaped fabric shade on top, not a table lamp`

### Приоритет 3 — декор / чистое препятствие (без разрушения)

⬜ **sofa.glb** 🎯
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a cozy two-seat living room sofa with rolled armrests`

⬜ **armchair.glb** 🎯
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a single comfy armchair with rounded padded arms`

⬜ **bench.glb** 🎯
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a simple wooden bench without a backrest`

⬜ **coat_rack.glb** 🎯💥 (можно опрокинуть, спотыкач)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a standing wooden coat rack with several curved hooks and two coats hanging on it, tripod base`

## Ванная / кухня

⬜ **tub.glb** 🎯 (ванна — маслом/пеной ловушка на скольжение)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a white clawfoot bathtub, rounded shape, four short curved feet`

⬜ **sink.glb** 🎯⚡ (раковина — фен в воду)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a pedestal bathroom sink with a single faucet, white ceramic, standing on one central column`

⬜ **toilet.glb** 🎯
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a white ceramic toilet with a closed lid, simple rounded shape`

⬜ **stove.glb** 🎯⚡ (плита — искрит/поджигает)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a kitchen stove with four round burners on top and one oven door in front, closed oven door, not a fridge`

## Праздничный декор

⬜ **christmas_tree.glb**
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a decorated christmas tree with a star on top`

⬜ **wreath.glb** (венок)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, style of a cozy co-op party game, a green christmas wreath with a red bow`

⬜ **gift_box.glb** (подарок)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a wrapped gift box with a ribbon bow`

⬜ **stocking.glb** (носок)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, style of a cozy co-op party game, a red christmas stocking`

⬜ **fireplace.glb** (камин)
`low-poly stylized realism, warm cozy color palette, soft rounded edges and gentle bevels (no sharp hard corners), subtle realistic material texture such as visible wood grain, woven fabric or brushed metal as fits the object, soft warm lighting, clean readable silhouette, single object, centered, resting on ground, style of a cozy co-op party game, a brick fireplace with a mantel`

## Персонажи (нужен риг+анимации — см. ANIMATION.md)

⬜ **kid_base.glb** (мелкий — базовый)
`low-poly, clean cartoon style, soft matte colors, smooth simple shapes, subtle bevels, no fine detail, readable silhouette, neutral studio lighting, single character, T-pose, rigged humanoid, style of a cozy co-op party game, a small cute cartoon kid in casual clothes`

⬜ **robber_base.glb** (грабитель)
`low-poly, clean cartoon style, soft matte colors, smooth simple shapes, subtle bevels, no fine detail, readable silhouette, neutral studio lighting, single character, T-pose, rigged humanoid, style of a cozy co-op party game, a cartoon burglar in a dark striped shirt and beanie hat`
