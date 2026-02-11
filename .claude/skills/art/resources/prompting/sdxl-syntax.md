# SDXL & Pony Prompt Syntax

## In Plain Language
SDXL-based models (including Pony V6 XL) work best with tag-style prompts — comma-separated keywords rather than full sentences. Think of it like filling out a form, not writing a paragraph.

## What You Need to Know

### Basic Format
```
quality tags, subject, action, setting, style, lighting, details
```

### Quality Tags by Model

**Pony V6 XL** (always include these first):
```
score_9, score_8_up, score_7_up
```
These are Pony-specific quality boosters. Without them, output quality drops noticeably.

**Standard SDXL**:
```
masterpiece, best quality, high resolution
```

**Both**:
```
highly detailed, sharp focus
```

### Common Style Tags
| Tag | Effect |
|-----|--------|
| `painterly` | Visible brushwork, fine art feel |
| `digital painting` | Clean digital art |
| `anime` | Anime style (works best on Pony) |
| `photorealistic` | Tries to look like a photograph |
| `concept art` | Loose, exploratory feel |
| `watercolor` | Watercolor texture and bleeding |
| `oil painting` | Rich, textured oil paint look |
| `flat color` | Solid fills, minimal shading |
| `lineart` | Emphasis on line work |

### Lighting Tags
| Tag | Effect |
|-----|--------|
| `golden hour` | Warm, golden sunlight |
| `dramatic lighting` | Strong contrast, moody |
| `soft lighting` | Even, gentle illumination |
| `rim lighting` | Bright edge outline on subjects |
| `chiaroscuro` | Strong light/dark contrast |
| `studio lighting` | Clean, professional |
| `volumetric lighting` | Light rays through atmosphere |

### Weighting (SDXL syntax)
```
(important word:1.3)     — 30% more emphasis
(very important:1.5)     — 50% more emphasis
(less important:0.7)     — 30% less emphasis
```
Keep weights between 0.5 and 1.5. Extreme values cause artifacts.

### Pony-Specific Tags
Pony understands booru-style character/scene tags:
```
1girl, 1boy, solo, multiple girls
long hair, short hair, blonde hair, red eyes
looking at viewer, from above, from side
simple background, white background, outdoors
```

### CLIP Skip
Pony requires **clip_skip: 2**. Standard SDXL uses clip_skip: 1. Using the wrong value produces noticeably worse results.

## Why This Matters
Using natural language with SDXL/Pony produces mediocre results. The models were trained on tag-formatted data, so tag-formatted prompts communicate more clearly with them.

## Sources
- [Pony V6 Prompting Guide](https://civitai.com/articles/4248)
- [SDXL Prompting Tips](https://stable-diffusion-art.com/sdxl-prompts/)
