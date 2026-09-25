# itch.io Page and Release Checklist — v0.9.0

## Page copy

**Title:** The Last Cipher

**Short description (under 120 characters):**
A bullet-hell roguelite where you arrange Prana into a grid to decide every spell you cast.

**Description:**

> The vault is sealed, and you are the last one who can read its cipher.
>
> Arrange elemental Prana on a 3×3 grid before each room: the pattern decides the
> spell you cast. Then fight through rooms of enemy bullet patterns. Dash through
> bullets for a Perfect Dodge, time your casts for a Perfect Cast, and unleash a
> Special when the meter fills.
>
> - Three floors, each ending in a boss, and a final boss that changes the arena
>   as it breaks
> - 20 sigils to shape each run, from stat boosts to burning dash trails and
>   lightning that arcs off every near miss
> - Cursed rooms, no-hit Challenge rooms, and Wayshrines that trade blood for power
> - Cipher Shards carry over between runs: unlock Heirlooms, then Hard Mode
> - Full keyboard and gamepad play, key rebinding, and options to reduce screen shake
>   and flashes

**Controls:** WASD / left stick move · Shift / X dash · Space / A cast ·
F, right mouse / Y special · Enter / Y confirm the grid · Esc pause. Keys can be
changed in Settings.

**Genre:** Action · **Tags:** bullet-hell, roguelite, pixel-art, isometric,
spellcasting, singleplayer · **Platforms:** Windows, Linux, HTML5

## Uploads

| File | Channel | Notes |
|------|---------|-------|
| `the-last-cipher-v0.9.0-windows.zip` | windows | Unzip and run the `.exe` |
| `the-last-cipher-v0.9.0-linux.zip` | linux | `chmod +x` the binary if needed |
| `the-last-cipher-v0.9.0-web.zip` | html5 | Upload as "played in browser", viewport 1152×648, enable fullscreen button |

## Screenshots to upload

From `production/qa/evidence/`: `round2-keeper-lattice.png`, `round2-cursed-room.png`,
`combat-coach-and-arrows.png`, `round2-main-menu.png`, `round2-settings.png`.
Cover image: 630×500, still to be made.

## Before publishing

- [ ] Play one full run on each build (Windows, Linux, Web) to the Keeper
- [ ] Web: check audio starts after the first click and fullscreen works
- [ ] Set `application/config/version` in `project.godot` if the number changes
- [ ] Page set to "Restricted" first; share the link with playtesters; then "Public"
- [ ] Add a devlog post with what changed since the last build

## Crash reports

File logging is on. Ask players for the newest file in:

- Windows: `%APPDATA%\Godot\app_userdata\The Last Cipher\logs\`
- Linux: `~/.local/share/godot/app_userdata/The Last Cipher/logs/`

Settings live in `settings.cfg` and progress in `progress.cfg` in the same folder.
Deleting `progress.cfg` resets progress; deleting `settings.cfg` resets options.

## Known issues

- Gamepad buttons cannot be rebound yet.
- The story (memory fragments) is not in this build.
