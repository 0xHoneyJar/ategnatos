# Dataset Curation Guide

## In Plain Language
Curation is choosing which images to include in your training dataset. Not every image you have is training-worthy. The goal is to pick a set that's diverse enough to teach the general pattern, consistent enough in quality to avoid teaching bad habits, and sized appropriately for your training type.

## What You Need to Know

### The Selection Process

1. **Start with everything** — gather all candidate images
2. **Remove clearly bad** — blurry, corrupted, too small, watermarked
3. **Remove duplicates** — near-identical images teach memorization
4. **Assess diversity** — do you have enough variety?
5. **Trim to target size** — remove the weakest remaining candidates
6. **Verify balance** — check content-style distribution

### Diversity Dimensions

For each dimension, aim for at least 3 distinct variations:

| Dimension | Why It Matters | Check |
|-----------|---------------|-------|
| **Subject** | Prevents content-style confusion | Different things depicted |
| **Pose/Angle** | Prevents single-viewpoint bias | Multiple viewpoints |
| **Lighting** | Teaches the style under different conditions | Natural, artificial, dark, bright |
| **Color palette** | Prevents "this style = this color" | Different dominant colors |
| **Composition** | Teaches flexible framing | Close-up, medium, wide |
| **Complexity** | Teaches both simple and complex scenes | Busy and sparse |

### Scoring Images

When choosing between similar images, prefer:

| Higher Score | Lower Score |
|-------------|-------------|
| Sharp, in focus | Slightly soft or blurry |
| Clean (no watermarks, text) | Has artifacts or overlays |
| Full resolution (1024x1024+) | Below training resolution |
| Good representation of the style | Atypical or experimental piece |
| Unique angle/subject in the set | Similar to other images you've already selected |

### Subset Selection (Large Portfolios)

When an artist has 200 images but you need 40:

1. **Group by subject** — separate landscapes, portraits, still life, etc.
2. **Select proportionally** — aim for roughly equal representation of each group
3. **Within each group, maximize variety** — different compositions, lighting, palettes
4. **Include the best quality examples** — sharp, clean, at-resolution
5. **Remove redundancy** — if you have 5 similar landscapes, keep the 2 most distinct

### Regularization Images

Regularization images are "normal" images (not by the artist) mixed into the training dataset. They act as a counterweight.

**When to use regularization:**
- Style LoRAs with limited subject diversity
- Character LoRAs where the character's features might bleed into unrelated outputs
- When training causes the model to "forget" how to generate normal images

**How they work:**
- You include a set of generic images in the same category as your training data
- These use a generic caption (no trigger word)
- The model learns to associate the trigger word only with the unique elements of your training images

**How many:**
- Typically 1:1 ratio (same number as training images, or slightly more)
- Can be generated from the base model itself
- Quality should match training image quality

**Example:**
- Training set: 30 cat paintings in your style → `mystyle, cat, oil painting, warm tones...`
- Regularization set: 30 cat images from various styles → `cat, sitting, indoor` (no trigger word)
- Model learns: trigger word = the style difference, not "cat"

### Size Recommendations by Type

| Type | Minimum | Sweet Spot | Maximum |
|------|---------|------------|---------|
| Character | 10 | 20-30 | 60 |
| Style | 15 | 30-50 | 200 |
| Object | 8 | 15-25 | 40 |

See `dataset-sizes.md` for detailed breakdown with rationale.

### Red Flags to Remove

| Red Flag | Action |
|----------|--------|
| Resolution below 768px | Remove or upscale with a dedicated tool |
| Heavy JPEG compression | Remove (visible blocks teach the model artifacts) |
| Watermarks or text overlays | Remove (model will learn to reproduce them) |
| Cropped or partial images | Remove unless intentional composition |
| Heavily edited/filtered photos used as "paintings" | Remove (inconsistent with actual painted technique) |
| Screenshots or photos of screens | Remove |

## Why This Matters
A curated dataset of 30 well-chosen images outperforms an uncurated dataset of 100. Curation isn't about having more — it's about having the right images. Every weak image in your dataset actively teaches the model something you don't want.

## Sources
- [Derrian's SD Training Guide — Dataset Quality](https://civitai.com/articles/2056)
- [Kohya Best Practices](https://github.com/kohya-ss/sd-scripts/wiki)
