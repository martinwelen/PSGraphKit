# PSGraphKit — Brand Sheet

Curated PowerShell cmdlets for Entra ID & Microsoft Graph

## The mark
A rounded "chip" tile carrying the `PS>` prompt. Corner radius = 24% of tile size.
At 16px (favicon) the mark reduces to a single "P".

## Color palette
| Role | Hex |
|---|---|
| Brand blue (chip) | `#2F5FD8` |
| Blue, on-dark accent | `#5B8BFF` |
| Ink (dark bg / dark text) | `#0B1220` |
| Wordmark on light | `#101828` |
| Wordmark on dark | `#EEF2F8` |
| Paper (light bg) | `#FBFCFE` |
| Muted text, light bg | `#7A879C` |
| Muted text, dark bg | `#8291AB` |

Optional semantic accents (same lightness/chroma, hue-shifted):
core `oklch(0.55 0.17 264)` · active `oklch(0.55 0.17 210)` · preview `oklch(0.55 0.17 300)`

## Typography
- **Mark / code / taglines:** JetBrains Mono Bold (700)
- **Wordmark / headings:** Space Grotesk Bold (700); body 500

## Files
| File | Use |
|---|---|
| icon-512/256/128.png | PowerShell Gallery `IconUri`, app icon (transparent PNG) |
| favicon-16/32/48.png | favicons (16px uses the "P"-only mark) |
| lockup-light/dark.png (.svg) | mark + wordmark, transparent, per background |
| readme-banner-light/dark.png | README hero, 2560×640 (display at width=1280) |
| social-preview-1280x640.png | GitHub Settings → Social preview |
| icon.svg, lockup-*.svg | vector source (fonts embedded) |

## Rules
- PNG for anything Gallery-facing (the Gallery does not render SVG).
- Blue chip works unchanged on light and dark; only the wordmark color swaps.
- No thin strokes or sub-14px text inside the mark — it must survive ~40px.
- No Microsoft/Entra/Azure trademarked marks. All iconography original.
- Exports are canvas-generated: no EXIF, no watermark, no embedded attribution.
