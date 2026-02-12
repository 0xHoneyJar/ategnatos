# Captioning Protocol — VLM-Assisted Style-Aware Captioning

## In Plain Language

When you train a LoRA, the captions on your images are the instructions the model follows. Bad captions produce bad results. This protocol uses a Vision-Language Model (CogVLM, LLaVA, or similar) to generate captions that describe both what's in the image and how it looks — then structures them in a way the training process can actually use.

Think of it like labeling paint samples: you wouldn't just write "blue" — you'd write "matte cerulean with visible brush texture on linen." That level of specificity is what we're aiming for.

## What You Need to Know

This protocol runs two separate VLM passes per image, then combines the results with your trigger word. The separation ensures the model doesn't confuse content with style.

### VLM Prompt Templates

Two prompts are sent to the VLM for each image. They must be run separately — never combined into a single prompt.

**Pass 1 — Content Description**

```
Describe what is shown in this image. Focus on:
- Subject (person, object, scene)
- Actions and pose
- Background and setting
- Lighting and atmosphere
Be factual and specific. Do not interpret style or artistic choices.
```

**Pass 2 — Style Description**

```
Describe the artistic style of this image. Focus on:
- Medium (photograph, illustration, 3D render, painting)
- Color palette (warm/cool, saturated/muted, specific colors)
- Composition technique
- Texture and detail level
- Mood conveyed through visual style
Do not describe the subject or content.
```

### Output Format

Each caption follows this structure:

```
{trigger_word}, {content_description}, {style_description}
```

The trigger word always comes first, followed by content, then style. This consistent ordering helps the model learn what the trigger word maps to.

### Token Budget

| Parameter | Value | What Happens If Violated |
|-----------|-------|--------------------------|
| Target | 50-150 tokens | Aim for this range |
| Minimum | 30 tokens | Reject and re-caption — too vague to teach anything |
| Maximum | 200 tokens | Truncate — excess detail causes noise |
| Trigger word | 1 token | Already counted in the budget |

If a VLM caption comes back under 30 tokens, the image likely needs a better prompt or manual captioning. If it comes back over 200 tokens, truncate by removing the least specific descriptors (usually the last few clauses).

### Batch Processing Strategy

Captioning a full dataset can take time. Don't risk losing work.

1. **Process in batches of 10-20 images** — small enough to catch problems early, large enough to be efficient
2. **Save intermediate results after each batch** — write `.txt` files to disk immediately, don't hold them all in memory
3. **Track progress** — display `N/total processed` after each batch completes
4. **On crash or interrupt** — resume from the last completed batch, don't restart from scratch
5. **Log failures separately** — if a VLM call fails on an image, log it to `caption-errors.log` and continue with the next image

### Quality Gate

Every caption must pass all of the following checks before it is accepted. Captions that fail are flagged for manual review.

**Required checks:**

| Check | Rule | Why |
|-------|------|-----|
| Trigger word present | Must appear at the very start of the caption | Model needs consistent trigger placement to learn the association |
| Minimum length | Caption >= 30 tokens | Shorter captions don't carry enough information to train on |
| Style coverage | At least 2 terms from the style checklist (see below) | Ensures the style pass actually contributed meaningful detail |
| No hallucination markers | Must not contain: "I think", "it appears", "possibly", "might be", "seems to", "it looks like it could be" | VLMs hedge when uncertain — hedged captions teach the model nothing useful |

**Style checklist** (caption must include at least 2 of these categories):

- **Color** — palette, hue, saturation, tones (e.g., "warm golden tones", "muted pastels")
- **Texture** — surface quality, brushwork, grain (e.g., "smooth blending", "visible impasto")
- **Lighting** — direction, quality, temperature (e.g., "soft diffused light", "dramatic side lighting")
- **Composition** — framing, arrangement, perspective (e.g., "centered portrait", "diagonal composition")
- **Medium** — what it looks like it was made with (e.g., "digital illustration", "oil painting")
- **Mood** — emotional tone conveyed visually (e.g., "melancholic atmosphere", "energetic and vibrant")

### Example Captions

**1. Portrait photograph**

```
ohwx, a woman with dark curly hair looking directly at the camera with a neutral expression wearing a white blouse against a plain grey backdrop, studio photograph with soft even lighting shallow depth of field neutral color palette and smooth skin tones with subtle warm highlights
```

- Content: subject, expression, clothing, background
- Style: medium (photograph), lighting (soft even), depth of field, palette (neutral with warm highlights)
- Token count: ~52

**2. Landscape/scene**

```
ohwx, a mountain lake at dawn with pine trees along the shoreline and mist hanging over the water with snow-capped peaks in the distance, photograph with cool blue-grey tones soft diffused morning light atmospheric haze creating depth and a calm contemplative mood
```

- Content: setting, time of day, natural elements, spatial arrangement
- Style: palette (cool blue-grey), lighting (diffused morning), atmosphere (haze, depth), mood (calm)
- Token count: ~55

**3. Stylized illustration**

```
ohwx, a woman sitting at a cafe table drinking coffee in an outdoor setting with string lights and potted plants, digital illustration with warm golden tones soft lighting and painterly brushstrokes visible texture on surfaces flat color areas with detailed linework on the subject
```

- Content: subject, action, setting, details
- Style: medium (digital illustration), palette (warm golden), lighting (soft), texture (painterly brushstrokes, visible texture), technique (flat color + detailed linework)
- Token count: ~54

## Why This Matters

Standard auto-captioning tools (BLIP, WD14 tagger) describe content only — "a woman at a cafe" — and miss everything about the visual style. When you train on content-only captions, the model has no information about technique, so it either ignores style entirely or overfits to whatever accidental visual patterns show up most often. Running two separate VLM passes (content then style) and combining them gives the training process explicit style signal to learn from. This is the difference between a LoRA that sort of looks like your style and one that actually reproduces it.

## Integration

Caption quality metrics are checked by `dataset-audit.sh` (`.claude/scripts/train/dataset-audit.sh`). The audit script counts captioned vs uncaptioned images, flags missing `.txt` sidecar files, and is referenced during Gate 1 of the dataset workflow (`resources/workflows/dataset-workflow.md`, Phase 6). Captions produced by this protocol feed directly into the dataset report's "Captioned: N/total" metric.

For the full context on content-style separation and the captioning philosophy, see `resources/dataset/captioning-guide.md`.
