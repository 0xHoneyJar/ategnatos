# Dataset Size Recommendations

## In Plain Language
How many images you need depends on what you're training. Character LoRAs need fewer (but very consistent) images. Style LoRAs need more (but diverse) images. Using too few means the model can't learn enough; using too many of the same thing means it memorizes instead of generalizing.

## What You Need to Know

### By Training Type

#### Character LoRA
| Parameter | Recommendation | Why |
|-----------|---------------|-----|
| Image count | 15-40 | Enough for the model to learn facial features from multiple angles |
| Minimum | 10 | Below this, the model can't generalize poses/angles |
| Maximum | 60 | Beyond this, diminishing returns; risk of overfitting |
| Variety needed | Multiple angles, expressions, lighting conditions | One angle = one-note LoRA |

**What makes a good character dataset:**
- 5-10 close-up face shots (different angles: front, 3/4, profile)
- 5-10 upper body shots (different poses, outfits if relevant)
- 5-10 full body shots (different poses)
- Different lighting: indoor, outdoor, bright, dim
- Same person throughout (identity consistency is critical)

#### Style LoRA
| Parameter | Recommendation | Why |
|-----------|---------------|-----|
| Image count | 20-100 | More examples of the style = better generalization |
| Minimum | 15 | Below this, the model can't separate style from content |
| Sweet spot | 30-50 | Best quality-to-effort ratio |
| Maximum | 200 | After this, training time increases without quality gains |
| Variety needed | Different subjects, same technique | Teach the style, not the subject |

**What makes a good style dataset:**
- Same artist/technique throughout
- Different subjects (not all landscapes — mix in portraits, still life, etc.)
- Different color palettes within the style
- Different compositions
- The more diverse the subjects, the better the model isolates the style

#### Object/Concept LoRA
| Parameter | Recommendation | Why |
|-----------|---------------|-----|
| Image count | 10-30 | Objects are simpler than faces or styles |
| Minimum | 8 | Need enough angles to generalize |
| Maximum | 40 | Objects are simpler; too many leads to overfit |
| Variety needed | Multiple angles, backgrounds, scales | Different contexts teach flexibility |

**What makes a good object dataset:**
- Object from many angles (front, back, side, top, 3/4)
- Different backgrounds (white, natural, dark)
- Different scales (close-up, in context, far away)
- Consistent object appearance across all images

### Resolution Requirements

| Base Model | Minimum Resolution | Recommended | Notes |
|-----------|-------------------|-------------|-------|
| SDXL | 768x768 | 1024x1024 | Below 768 significantly hurts quality |
| Pony V6 XL | 768x768 | 1024x1024 | Same as SDXL |
| Flux | 768x768 | 1024x1024 | Flux is more forgiving of varied resolutions |

Images below the minimum should be upscaled (using a dedicated upscaler, not basic resize) or removed.

### How Many is Too Many?

More images isn't always better:
- **Diminishing returns**: Beyond the sweet spot, quality plateaus but training time increases
- **Overfit risk**: Too many similar images = memorization instead of learning
- **Cost**: More images = more steps = more GPU time = more money

### Common Mistakes

1. **All same pose**: 30 photos all facing forward → model can only generate forward-facing images
2. **All same subject**: Style LoRA with only cat paintings → model thinks "style" = "cats"
3. **Mixed quality**: 20 great images + 10 blurry ones → model learns the blur too
4. **Too few images**: Under 10 → model can't generalize at all

## Why This Matters
Getting the dataset size right is the difference between a LoRA that works and one that wastes hours of GPU time. Undershoot and you get a model that can't generalize. Overshoot and you waste time and risk overfitting.

## Sources
- [Kohya LoRA Training Guide](https://civitai.com/articles/3105) — community-validated sizing guidelines
- [LoRA Training Best Practices (CivitAI)](https://education.civitai.com/using-civitai-the-on-site-lora-trainer) — dataset quality recommendations
- [Derrian's SD Training Guide](https://civitai.com/articles/2056) — advanced dataset sizing with ablation results
