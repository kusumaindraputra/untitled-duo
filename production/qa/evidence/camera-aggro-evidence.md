# Evidence: Combat Camera View and Enemy Aggro (ADR-0024)

Captured 2026-09-25 from `main.tscn` under xvfb (Godot 4.6.2, opengl3, 1152×648,
`--fixed-fps 60`), about 1 s into the first combat of Floor 1. The room roster is
random per run, so enemy placement differs between shots.

| File | What it shows |
|------|---------------|
| `camera-aggro/before-zoom-1.5.png` | Old combat zoom 1.5× (768×432 game px) |
| `camera-aggro/after-zoom-2.0.png` | New default 2.0× (576×324 game px) |
| `camera-aggro/option-diablo-zoom-2.4.png` | Diablo-close 2.4× (480×270), not the default |
| `camera-aggro/after-alert-mark.png` | Two enemies waking with the "!" mark as Fayde enters their aggro area |

Runtime log from the capture (dormant = `d=true`), Fayde at (-512, 0):

```
frame 20  enemies (448,0) d=true  (384,64) d=true  (-352,80) d=true  (-352,-16) d=true  (-320,-96) d=true
frame 70  enemies (448,0) d=true  (384,64) d=true  (-352,80) d=false (-410,-10) d=false (-372,-70) d=false
```

The pack about 160 px from Fayde woke, and the enemies ~900 px away across the
arena stayed dormant instead of firing from off screen.
