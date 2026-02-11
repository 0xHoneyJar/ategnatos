# LoRA Strength Guide

## In Plain Language
When you use a LoRA (a trained style or character add-on), you control how strongly it affects the output. This is called "strength" or "weight" — a number between 0 and 1. At 0 the LoRA has no effect. At 1.0 it has maximum effect. Finding the right strength is the difference between "subtle enhancement" and "melted faces."

## What You Need to Know

### How Strength Works

```
0.0  ─────────────────────────────────────────  1.0
 │                                                │
 No effect                                  Full effect
 (base model only)                    (maximum LoRA influence)
```

Most LoRAs have a "sweet spot" — a range where the style is clearly visible but the image quality stays high. Above the sweet spot, quality degrades. Below it, the style is too subtle to notice.

### Typical Sweet Spots by Type

| LoRA Type | Sweet Spot | Why |
|-----------|-----------|-----|
| Style | 0.5–0.8 | Style needs room to blend with base model |
| Character | 0.7–1.0 | Character identity needs stronger signal |
| Object | 0.6–0.9 | Objects need clear definition |
| Concept | 0.4–0.7 | Abstract concepts work best subtle |

### What Happens at Each Range

#### 0.0–0.3: Whisper
- Style is barely perceptible
- Base model dominates completely
- Useful for: very subtle color shifts, background influence
- Problem: if you need this range, the LoRA might be undertrained

#### 0.3–0.5: Hint
- Style elements start appearing
- Color palette shifts noticeably
- Base model still dominant in composition and structure
- Useful for: blending with other LoRAs, light touch

#### 0.5–0.7: Sweet Spot (for most style LoRAs)
- Style clearly visible
- Composition and lighting influenced
- Faces and details still clean
- This is where most style LoRAs perform best

#### 0.7–0.9: Strong
- Style dominates
- May affect face proportions
- Composition follows training data patterns
- Useful for: character LoRAs, or when you want maximum style

#### 0.9–1.0: Maximum
- Full LoRA effect
- High risk of:
  - Face/body distortion
  - Color oversaturation
  - Copying training composition
  - Loss of prompt responsiveness
- Rarely optimal for production use

### Finding Your Sweet Spot

1. **Generate the grid**: Run `eval-grid.sh` at weights 0.3, 0.5, 0.7, 0.9, 1.0
2. **Look at 0.5 first**: This is the most likely sweet spot for style LoRAs
3. **Check faces**: Are they still clean? If distorted, the sweet spot is below this weight
4. **Check style**: Is it visible? If not, the sweet spot is above this weight
5. **Narrow it down**: If 0.5 is too subtle and 0.7 distorts faces, try 0.6

### Combining Multiple LoRAs

When using multiple LoRAs together, total combined weight matters:

| Combined Weight | Guidance |
|----------------|----------|
| Total < 1.0 | Generally safe |
| Total 1.0–1.5 | Usually fine, watch for conflicts |
| Total > 1.5 | Quality degrades, reduce individual weights |

**Example**: Style LoRA at 0.6 + Character LoRA at 0.8 = 1.4 total. This should work but test it.

### Model-Specific Notes

| Base Model | Strength Behavior |
|------------|------------------|
| SDXL / Pony V6 | Standard behavior as described above |
| Flux Dev | Often needs lower weights (0.3–0.6) — Flux is more sensitive to LoRA influence |
| Flux Schnell | Similar to Dev but faster; test at 0.3 first |
| SD 1.5 | Can handle higher weights (0.7–1.0) without as much degradation |

### Troubleshooting by Strength

| Problem | At High Weight | At Low Weight |
|---------|---------------|--------------|
| Blurry output | Overtrained — use lower weight or earlier checkpoint | Not a weight issue — check base model |
| Wrong colors | LoRA dominating — reduce weight | Style not applied — increase weight |
| Face distortion | Too strong — this is the first thing to break | Not a weight issue |
| Ignores prompt | LoRA too dominant — reduce weight significantly | Normal — LoRA respects prompt at low weight |
| Copies training | Severely overtrained — use 0.3 or earlier checkpoint | N/A |

## Why This Matters
The difference between a LoRA that looks "amazing" and one that looks "broken" is often just a 0.2 change in strength. Finding the sweet spot takes 5 minutes with the eval grid and makes every subsequent generation better.
