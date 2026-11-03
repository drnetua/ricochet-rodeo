# Промпти

## Концепт-арт (ChatGPT / gpt-image, альбомний 16:9, 1536×1024)

Порада: якщо стиль «пливе», згенеруй №1, а наступні проси «in the exact same art style as the previous image».

### 1. Дикий Захід — базовий трюк
```
Concept art for a PC video game, rendered like an in-game screenshot, landscape 16:9. First-person view. Art style: chunky, exaggerated cartoon shapes (oversized gloved hand, thick stubby gun barrel, rounded rubbery proportions) combined with photorealistic PBR textures — real scratched metal, worn wood grain, cracked bone, wet glass. Thin dark outlines, bold silhouettes, absurd slapstick tone.

Scene: the dusty backyard of a Wild West saloon at golden hour. In the lower right, the player's right hand in a leather cowboy glove holds a huge cartoonish six-shooter revolver with a fat cylinder, smoke curling from the barrel, muzzle flash just fading. In the center of the screen, at the top of its arc, a bison skull spins in mid-air with a surprised expression. A bright yellow bullet tracer hits the skull and ricochets in a sharp zig-zag into a row of glass bottles on a wooden fence, which explode into glittering shards. A floating gold text "+50$" pops up near the bottles, "RICOCHET!" in a bold western font. Minimal HUD: money counter top-left, six bullet icons bottom-right, "x2" combo near the round crosshair. Background: saloon wall, cactus, tumbleweed, distant mesas, soft depth of field.
```

### 2. Ярмарок — хаос і комбо
```
Concept art for a PC video game, rendered like an in-game screenshot, landscape 16:9. First-person view. Art style: chunky, exaggerated cartoon shapes combined with photorealistic PBR textures — real metal, wood, pumpkin skin, rubber. Thin dark outlines, bold silhouettes, absurd slapstick tone.

Scene: a colorful farm county fair at noon, slow-motion moment. Both hands hold a chunky double-barrel shotgun aimed up and to the left; the left hand grips the fore-end, the right finger is on the trigger. The sky is full of thrown objects frozen mid-flight: a spinning pumpkin bursting into orange chunks, a rubber chicken, a horseshoe, a stack of gold coins scattering, a wooden crate. Shotgun pellets streak through them with motion trails. A slow-motion blue vignette tints the edges of the screen. Big bold text in the center-top: "CHAIN x4!" and "COMBO x3.5". Floating money numbers "+75$", "+30$", "+20$" pop above hit objects. Background: carousel with moving target boards, striped tents, hay bales, a confused farmer in the distance. Minimal HUD: money top-left, two shell icons bottom-right.
```

### 3. Чикаго 1920-х — штраф за цивільного
```
Concept art for a PC video game, rendered like an in-game screenshot, landscape 16:9. First-person view. Art style: chunky, exaggerated cartoon shapes combined with photorealistic PBR textures — real brick, polished chrome, steel, cracked glass. Thin dark outlines, bold silhouettes, absurd slapstick tone.

Scene: a rainy 1920s Chicago street at night, neon signs reflecting on wet cobblestones. The player's right hand in a pinstripe suit sleeve holds a chunky cartoon pistol, recoiling upward. A heavy steel safe falls through the center of the frame; the bullet tracer ricochets off its door, punches through a shop display window (glass shattering outward), and knocks the hat off a startled cartoon newspaper boy whose papers fly into the air in a burst of confetti — no blood, pure comedy. Large red text "-100$ CIVILIAN!" with a cartoon "oops" stamp. The combo meter in the HUD cracks and resets to "x1". Background: art-deco storefronts, a vintage car, steam rising from a manhole.
```

### 4. Піратський корабель — перезарядка двома руками
```
Concept art for a PC video game, rendered like an in-game screenshot, landscape 16:9. First-person view. Art style: chunky, exaggerated cartoon shapes combined with photorealistic PBR textures — real wet wood planks, tarred rope, brass, iron. Thin dark outlines, bold silhouettes, absurd slapstick tone.

Scene: the deck of a pirate ship in a stormy sea, the horizon tilted as the deck rocks. Reload animation: both hands work a chunky lever-action rifle — the left hand pulls the oversized brass lever down, a spent shell casing flips through the air, the right hand holds the stock. Above, thrown objects arc across the screen: a cannonball, a squawking parrot, a rum barrel with a lit fuse. A previously hit barrel explodes in a cartoon fireball, blasting gold coins everywhere. Waves splash over the railing, lightning flashes in the dark clouds. A cartoon ship's cook with a cooking pot peeks out of a hatch (a civilian to avoid). HUD: "RELOADING..." near the crosshair, empty bullet icons bottom-right, money counter top-left.
```

### 5. Корабель прибульців — невагомість і бластер
```
Concept art for a PC video game, rendered like an in-game screenshot, landscape 16:9. First-person view. Art style: chunky, exaggerated cartoon shapes combined with photorealistic PBR textures — real brushed aluminum, glossy plastic, glowing glass. Thin dark outlines, bold silhouettes, absurd slapstick tone, synthwave color palette of magenta, cyan and purple.

Scene: the interior of an alien spaceship cargo bay in zero gravity. The player's right hand in a bulky astronaut glove holds a chunky retro-futuristic alien ray gun with glowing coils. A bright cyan laser beam bounces five times in a dazzling zig-zag: off a floating cosmic cow wearing a tiny space helmet, off a hexagonal energy shield panel, off a drifting flying-saucer dinner plate, then into a cluster of glowing alien eggs that pop into sparkles. Objects drift slowly instead of falling. Bold text: "5x RICOCHET! +250$". In the background, a cute green alien janitor with a mop floats by looking alarmed (a civilian to avoid). Through a big round window: a purple nebula and a ringed planet. HUD: money top-left, a heat gauge instead of ammo bottom-right.
```

## Звуки (MusicGPT, WAV)

Мінімальна тривалість у MusicGPT — 5 с, тому короткі звуки просимо серією з паузами; `tools/audio/slice_sfx.py` ріже їх на варіації.
Ліва частина — ім'я файлу (MusicGPT додає номер варіації 1–4), права — промпт.

### P0 — ядро гри
```
sfx_gun_revolver_shot | Three separate cartoon western revolver gunshots, punchy and loud with a sharp crack and a short dusty canyon echo, one second of silence between shots, no music
sfx_gun_dry_click | Four separate empty revolver dry-fire clicks, metallic hammer snap on an empty chamber, close-up and dry, silence between clicks
sfx_gun_revolver_reload | Old west revolver reload: the cylinder swings open with a metallic clack, six brass cartridges are inserted one by one with small clicks, then a quick cylinder spin and a firm snap shut, close-up, no music
sfx_gun_rifle_shot | Three separate lever-action rifle gunshots, deeper and heavier than a pistol, booming crack with a rolling desert echo, silence between shots
sfx_gun_lever_cycle | Four lever-action rifle cocking sounds, crisp metallic cha-chack, each followed by a brass shell casing bouncing on wooden planks, silence between each
sfx_ricochet | Four different classic cartoon bullet ricochets, high-pitched whistling ptiiing with a quick doppler fade, western movie style, silence between each
sfx_hit_bone | Four comedic bullet hits on a hollow bone skull, dry wooden bonk with a cartoon boing undertone, short, silence between each
sfx_hit_wood | Four bullet impacts on a wooden crate, sharp thunk with splintering wood crackle, short, silence between each
sfx_hit_coin | Four bright tiny pings of a bullet striking a spinning gold coin in mid-air, sparkly metallic ting, silence between each
sfx_hit_rubber_chicken | Four cartoon rubber chicken squeaks and squawks when hit, funny and exaggerated, silence between each
sfx_hit_gong | A bullet striking a hanging steel gong plate, bright metallic clang that rings and wobbles for three seconds
sfx_glass_bottle | Four glass bottles shattering on a wooden fence after gunshots, crisp breaking glass with tinkling shards falling, silence between each
sfx_glass_window | A large saloon window pane shattering, big crash of glass with shards raining down onto a wooden porch
sfx_throw_whoosh | Four whooshes of objects tossed into the air, from a light airy swish to a heavy slow swoosh, silence between each
sfx_cash | Four short cartoon cash register ka-ching sounds with jingling coins, cheerful, silence between each
sfx_civilian_oops | Cartoon slide whistle falling down, then a goofy oof and a springy boing, comedic penalty sound
sfx_combo_break | Comedic combo break: a short glass crack followed by a descending sad trombone wah-wah, cartoon style
sfx_slowmo | Cinematic slow-motion: a deep whoosh pitching down into a muffled heartbeat, a pause, then a quick reverse swoosh snapping back to normal speed
```

### P1 — вертикальний зріз
```
sfx_target_bullseye | A bullet thunking into a wooden target followed by a bright carnival bell ding
sfx_hit_anvil | A heavy blacksmith anvil struck by a bullet, deep resonant clang, cartoon exaggerated
sfx_land_dirt | Four objects landing on dry dirt, from a light patter to a heavy dusty thud, silence between each
sfx_combo_up | Four rising western guitar twang plucks, each one higher, cheerful and quick, silence between each
sfx_crowd_ooh | A small saloon crowd reacting to an amazing trick shot: an impressed ooooh turning into whistles and short applause
sfx_gun_twirl | A revolver spun on a finger: fast metallic whirring spin ending with a crisp catch in a leather glove
sfx_star | Three magical sparkle chimes, each slightly higher in pitch, for awarding stars, silence between each
sfx_ui_click | Four soft wooden UI clicks like tapping a plank, with a subtle leather creak, silence between each
sfx_shop_buy | A leather coin pouch jingling followed by a satisfying metal stamp thunk, purchase confirmed
sfx_civilian_hic | A cartoon drunk cowboy hiccuping, three separate silly hic sounds, silence between each
sfx_saloon_doors | Saloon swinging doors creaking open and flapping shut several times
sfx_level_complete | Short playful western victory stinger: trumpet fanfare with acoustic guitar strum and a final whip crack
amb_wildwest_loop | Wild West town ambience, 30 seconds: dry desert wind, a creaking wooden saloon sign, distant honky-tonk piano from inside the saloon, an occasional far-off horse whinny, no voices
```

### Музика
```
mus_wildwest_gameplay | Upbeat comedic spaghetti-western surf rock, twangy reverb guitar, whistled melody, galloping drums, playful and absurd, 120 BPM, seamless loop, instrumental
mus_shop | Laid-back honky-tonk saloon piano with light banjo, relaxed and cheeky, seamless loop, instrumental
```
