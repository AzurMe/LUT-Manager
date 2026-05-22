# LUT Manager Tag Taxonomy

LUT Manager uses typed tags instead of a flat tag list. Typed tags make filtering predictable and prevent vague tags from becoming hard to manage as the library grows.

## Recommended Tag Types

- `cameraCategory` - Camera class such as Cinema Camera, Mirrorless, Full Frame, APS-C, MFT, Drone, Action Camera.
- `cameraBrand` - Manufacturer such as Sony, Canon, Fujifilm, Panasonic, Nikon, DJI, Blackmagic.
- `cameraModel` - Specific model such as FX3, X-H2S, R5 C, S5II, Pocket 6K.
- `captureProfile` - Source profile such as S-Log3, C-Log3, F-Log2, V-Log, N-Log, D-Log M, BRAW Film.
- `function` - Technical purpose such as Log Correction, Monitoring LUT, Creative Look, Display Transform, Print Film Emulation.
- `style` - Visual style such as Vintage, Fresh, Clean Commercial, Filmic, Documentary, Moody, Cyberpunk, Pastel.
- `shadowTone` - Shadow treatment such as Teal Shadows, Warm Shadows, Lifted Blacks, Deep Contrast, Soft Fade.
- `highlightTone` - Highlight behavior such as Soft Highlights, Warm Highlights, Crisp White, Cream Roll-off.
- `colorBias` - Overall color direction such as Warm, Cool, Neutral, Low Saturation, Rich Color, Muted Green.
- `skinTone` - Skin handling such as Skin Protection, Rosy Skin, Bronze Skin, Pale Skin.
- `lightingScene` - Best scene type such as Daylight, Night, Interior, Mixed Light, Golden Hour, Overcast.
- `workflow` - Editing or use context such as DaVinci Resolve, Final Cut Pro, Premiere Pro, In-camera Monitoring, Rec.709 Delivery.
- `intensity` - Strength such as Soft, Medium, Strong, Extreme.
- `author` - Creator, studio, or source.

## Sidecar JSON Shape

```json
{
  "tags": [
    { "type": "cameraBrand", "value": "Sony" },
    { "type": "captureProfile", "value": "S-Log3" },
    { "type": "function", "value": "Log Correction" },
    { "type": "style", "value": "Clean Commercial" },
    { "type": "shadowTone", "value": "Teal Shadows" }
  ]
}
```
