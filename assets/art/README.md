# Art Assets

Character art is pixel art generated in code, so it can be re-made after any
design change. The environment floor, walls and backdrop are procedural
(ADR-0021) and have no image files here. The full visual rules are in
`design/art/art-bible.md` (§4 colour, §5 characters, §8.6 sprite specs).

## Characters — `characters/`

One PNG sheet per character, written by
`tools/art-gen/generate_character_sprites.gd` (ADR-0022, ADR-0034):

```
godot --headless --path . -s tools/art-gen/generate_character_sprites.gd
```

Every sheet is **4 columns × 3 rows**, one sheet pixel = one world pixel:

| Row | Ayden / Faith | Enemies | Played |
|-----|-------|---------|--------|
| 0 | idle | idle | loops at 6 fps |
| 1 | move | move | loops at 6 fps while the parent moves |
| 2 | cast (wind-up, release, hold, recover) | attack wind-up | once, over the cast / telegraph |

Sheets face right; the game mirrors them for left. Feet sit on the bottom
centre of each frame.

| Sheet | Frame | Used by |
|-------|-------|---------|
| `ayden.png` / `faith.png` + `_glow`, `_casts`, `_crumple` | 20×32 | The two brothers (ADR-0058), swapped on the shared player rig by `DuoLooks`; `MenuBackdrop` shows both (glow is white, tinted with the active Prana) |
| `fayde*.png` | 20×32 | Pre-duo single protagonist; still the rig's fallback sheet in `PlayerController.tscn` |
| `drifter`, `charger`, `cluster`, `weaver`, `mortar`, `rifter`, `sniper`, `spinner`, `splitter` | 14–26 px a side | `assets/data/enemy_types/enemy_*.tres` → `sprite_sheet` |
| `vault_sentinel.png` | 96×96 | Floor 1 boss |
| `warped_warden.png` | 96×96 | Floor 2 boss |
| `cipher_keeper.png` | 144×144 | Floor 3 final boss |

`PixelCharacter` (`src/visual/pixel_character.gd`) plays the sheet. Enemies set
`sprite_pixel_scale = 1` in their `EnemyType`; the node counter-scales for
`base_scale`, so bosses keep the active brother's pixel size however large their hitbox is.

### Changing a character

- Edit the design in the generator (Ayden and Faith are ASCII maps; enemies and bosses are
  shape code using `pixel_painter.gd`) and re-run it, then run
  `godot --headless --import` so the new PNGs are imported.
- Or paint over a PNG in Aseprite. Keep the 4×3 layout, the frame size, a 1 px
  `#17121A` outline and the palette in art bible §4. Re-running the generator
  overwrites hand edits.
- Colours: body neutrals ≤ 40 % saturation, Prana markers 50–60 %, and each boss
  has one reserved colour (§4.3): Sentinel teal, Warden violet, Keeper rose.

### Effects

Hit flash (solid white), the cast flash and the death dissolve are not in the
sheets. They run in `assets/shaders/pixel_character.gdshader`; timings are in
`assets/data/character_fx_tuning.tres` (ADR-0034).

## Other art

- Spell and bullet VFX are procedural (`PixelVFX`, ADR-0023).
- `assets/art/vfx/spell_cast/` is read by `PlayerController` if present; it is
  optional.
