# Negative Prompts

## In Plain Language
Negative prompts tell the model what to avoid. They're like guardrails — they prevent common AI art problems (weird hands, blurry backgrounds, watermarks) and unwanted styles.

## What You Need to Know

### Universal Negatives (Safe for Any Model)
These prevent common AI artifacts:
```
worst quality, low quality, blurry, watermark, signature, text, logo, username, jpeg artifacts
```

### SDXL / Standard Negatives
```
worst quality, low quality, normal quality, lowres, blurry, watermark, signature, text, logo, bad anatomy, bad hands, extra fingers, fewer fingers, extra limbs, missing fingers, cropped, out of frame
```

### Pony V6 XL Negatives
Pony has its own quality scale. Include these:
```
score_6, score_5, score_4, source_pony, source_furry
```
Add standard negatives too:
```
worst quality, low quality, blurry, watermark, bad anatomy, bad hands, extra fingers, deformed
```

**Note**: `source_pony` and `source_furry` are Pony-specific tags that filter out certain training data categories. Include them unless you specifically want those styles.

### Flux Negatives
Flux is better at self-regulation, so heavy negatives are less necessary. A light touch works:
```
blurry, low quality, watermark, text overlay
```
Or often no negative prompt at all works fine with Flux.

### Style-Specific Negatives

**When you want illustrated, NOT photorealistic:**
```
photograph, photo, photorealistic, 3d render, realistic skin texture
```

**When you want photorealistic, NOT illustrated:**
```
painting, drawing, illustration, anime, cartoon, sketch, digital art
```

**When you want clean, NOT busy:**
```
cluttered, busy background, excessive detail, overcrowded
```

### From Eye Preferences

Always check `grimoire/eye.md` for the artist's anti-preferences:
- **AVOID** items → add to negative with normal weight
- **NEVER** items → add to negative with emphasis `(item:1.3)` or place first in the negative prompt

## Why This Matters
A good negative prompt can be the difference between a clean output and one with distracting artifacts. But don't overdo it — too many negatives can confuse the model and reduce quality. Start with the basics and add more only if you see specific problems.

## Sources
- [Negative Prompt Guide](https://stable-diffusion-art.com/how-to-use-negative-prompts/)
