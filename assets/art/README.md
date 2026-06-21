# Art Assets — Drop-in Convention

The previous art (the "Lords Of Pain" demo isometric pack, the unused Knight
sprite-sheets, and the derived `characters/` sets) was removed during the move to
a **CC0 / owned** art base (target: [Kenney.nl](https://kenney.nl) CC0 packs).

Until new art is dropped in, the game runs on its built-in placeholders:

- **Characters** render as `DebugCircle` nodes. `IsoCharacter` is present in the
  player/enemy scenes but `visible = false`, so missing sprites are harmless.
- **Floor** renders as a runtime procedural diamond tile
  (`IsometricRoom._make_placeholder_floor_texture()`), so the arena is never a
  black void.

Both loaders prefer real art the moment it exists at the paths below — no code
change needed to "switch on" the new pack.

## Where files go

| Asset | Expected path | Loaded by |
|-------|---------------|-----------|
| Floor tile | `res://assets/art/tiles/iso_floor_stone2.png` (64×32) | `isometric_room.gd` → `_get_floor_texture()` |
| Player sprites | `res://assets/art/characters/fayde/` | `IsoCharacter` (set `base_path` + `visible=true` in `PlayerController.tscn`) |
| Enemy sprites | `res://assets/art/characters/skeleton/` | `IsoCharacter` (set `base_path` + `visible=true` in `EnemyInstance.tscn`) |

> Note: `base_path` was cleared from the scenes during the wipe. Re-add it when
> real character art lands, and flip `visible` to `true` (and hide/remove the
> `DebugCircle` child) to switch from placeholder to art.

## IsoCharacter layout (current loader)

`IsoCharacter` (`src/characters/iso_character.gd`) scans, per logical animation:

```
{base_path}/{anim_folder}/{DIR}/*.png      # frames sorted alphabetically
```

- `{DIR}` is one of the **8 compass folders**: `E NE N NW W SW S SE`
- `configure({"idle": "fayde_idle", "walk": "fayde_walk", ...})` maps logical
  names → `{anim_folder}`
- Missing direction folders are skipped silently (no crash)

Kenney isometric character packs do **not** ship this 8-folder layout. Adapting
the loader to the chosen Kenney format is tracked separately — see the art
migration discussion. Do not assume the 8-folder convention survives that work.
