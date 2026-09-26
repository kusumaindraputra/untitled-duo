# UI fonts (ADR-0035)

| File | Font | Licence | Use |
|------|------|---------|-----|
| `DotGothic16-Regular.ttf` | DotGothic16 by Fontworks (github.com/fontworks-fonts/DotGothic16), subset to Latin, punctuation, arrows, shapes and symbols | SIL OFL 1.1 (`DotGothic16-OFL.txt`) | Theme default: titles, buttons, HUD |
| `AtkinsonHyperlegible-Regular.ttf`, `-Bold.ttf` | Atkinson Hyperlegible by the Braille Institute | SIL OFL 1.1 (`AtkinsonHyperlegible-OFL.txt`) | Long prose (`BodyLabel`, RichTextLabel) and pixel-font fallback |

`pixel_font.tres` wraps DotGothic16 with Atkinson as its fallback. Both fonts come from
github.com/google/fonts. To re-subset DotGothic16:

```
pyftsubset DotGothic16-Regular.ttf --layout-features='*' \
  --unicodes="U+0020-007E,U+00A0-017F,U+2000-206F,U+20AC,U+2122,U+2190-21FF,U+2500-257F,U+25A0-25FF,U+2600-26FF,U+2700-27BF"
```
