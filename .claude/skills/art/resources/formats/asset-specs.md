# Asset Specifications

## In Plain Language
Different uses need different image sizes and formats. A social media avatar is tiny and square; a banner is wide and large. This reference covers common dimensions so you don't have to look them up every time.

## What You Need to Know

### Generation Resolutions (What to Generate At)

Models have native resolutions — generating at these sizes gives the best quality:

| Model Family | Native Resolution | Other Good Sizes |
|-------------|-------------------|-----------------|
| SDXL / Pony | 1024 x 1024 | 832 x 1216 (portrait), 1216 x 832 (landscape) |
| Flux | 1024 x 1024 | 768 x 1344 (portrait), 1344 x 768 (landscape) |

**Important**: Always generate at the model's native resolution, then resize to your target. Generating directly at non-native sizes causes quality issues.

### Common Export Dimensions

#### Social Media

| Platform | Asset Type | Dimensions | Aspect Ratio |
|----------|-----------|------------|--------------|
| Twitter/X | Profile picture | 400 x 400 | 1:1 |
| Twitter/X | Header | 1500 x 500 | 3:1 |
| Twitter/X | In-feed image | 1200 x 675 | 16:9 |
| Instagram | Square post | 1080 x 1080 | 1:1 |
| Instagram | Portrait post | 1080 x 1350 | 4:5 |
| Instagram | Story | 1080 x 1920 | 9:16 |
| Discord | Server icon | 512 x 512 | 1:1 |
| Discord | Emoji | 128 x 128 | 1:1 |
| Discord | Banner | 960 x 540 | 16:9 |

#### Web

| Use | Dimensions | Notes |
|-----|------------|-------|
| Hero image | 1920 x 1080 | Full-width banner |
| Blog header | 1200 x 630 | Also good for Open Graph |
| Thumbnail | 400 x 300 | Card preview |
| Favicon | 512 x 512 | Generate large, browser scales down |
| Open Graph | 1200 x 630 | Social share preview |

#### Print (300 DPI)

| Use | Dimensions (px) | Physical Size |
|-----|-----------------|---------------|
| A4 | 2480 x 3508 | 8.3 x 11.7 in |
| Letter | 2550 x 3300 | 8.5 x 11 in |
| Poster (small) | 3600 x 5400 | 12 x 18 in |
| Business card | 1050 x 600 | 3.5 x 2 in |

**Note**: AI-generated images at 1024x1024 won't look good printed large. For print, consider upscaling (via model or tool) before export.

### Formats

| Format | Best For | Transparency | File Size |
|--------|---------|-------------|-----------|
| **PNG** | Lossless quality, graphics with transparency | Yes | Large |
| **WebP** | Web use — good quality at small size | Yes | Small |
| **JPEG** | Photos, social media, general sharing | No | Small |

#### When to Use What

- **Working / archiving**: PNG (lossless, no quality loss)
- **Web delivery**: WebP (best size-to-quality ratio)
- **Social media**: JPEG at quality 90+ (universal compatibility)
- **Transparent backgrounds**: PNG or WebP

### Export Quality Settings

| Quality Level | JPEG Quality | WebP Quality | When to Use |
|--------------|-------------|-------------|-------------|
| Maximum | 100 | 100 | Archive, source files |
| High | 90-95 | 85-90 | General use, social media |
| Medium | 75-85 | 70-80 | Web thumbnails, previews |
| Low | 60-70 | 50-65 | Placeholder, draft |

## Why This Matters
Exporting at the wrong size means either blurry upscaled images or unnecessarily large files. Getting dimensions right from the start saves rework.
