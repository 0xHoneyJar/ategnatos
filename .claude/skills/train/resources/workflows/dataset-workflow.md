# Dataset Workflow — Phases 1-6 (Gate 1)

This workflow prepares a bulletproof dataset before any GPU time is spent.

## Phase 1: Training Intent Interview

1. **Ask what they want to train**:
   - "What are you trying to teach the model? A specific character, an art style, or a particular object/concept?"

2. **Explain the training type** using `resources/training/training-concepts.md`:
   - Character LoRA: teaches a specific face/body/outfit
   - Style LoRA: teaches brush technique, color palettes, composition patterns
   - Object/Concept LoRA: teaches a specific thing (e.g., a logo, an item)

3. **Set expectations** using `resources/dataset/dataset-sizes.md`:
   - Character: 15-40 images, consistent identity
   - Style: 20-100 images, diverse subjects but consistent technique
   - Object: 10-30 images, varied angles and contexts

4. **Surface the content-style problem** using `resources/dataset/content-style.md`:
   - "If all your training images are cats with painterly brushwork, the model can't tell if it's learning 'cats' or 'painterly.' We need to separate what's in the images from how they're drawn."

5. **Create intent file** at `grimoire/training/{name}/intent.md`:
   ```markdown
   # Training Intent: {name}
   - **Type**: style / character / object
   - **Base model**: {model from studio.md}
   - **Description**: {what they're training}
   - **Dataset target**: {recommended size}
   - **Trigger word**: {chosen trigger}
   - **Content-style notes**: {any separation concerns}
   ```

## Phase 2: Dataset Quality Audit

Run `.claude/scripts/train/dataset-audit.sh` on the image directory:

1. **Review results** — script checks resolution, format, corruption, aspect ratios, color space, and dataset format (flat vs Kohya)
2. **Present findings in plain language**:
   - "3 images are below 1024px — they'll need to be upscaled or removed"
   - "1 image appears corrupted and can't be opened"
   - "All images are RGB, which is correct"
3. **If flat format detected for Kohya backend**: suggest running `structure-dataset.sh` to create the `{repeats}_{name}/` folder structure
4. **If low-res images found**: suggest upscaling via `export-asset.sh --upscale 4x` or removing them
5. **Store results** in `grimoire/training/{name}/dataset-report.md`

## Phase 3: Duplicate Detection

Run `.claude/scripts/train/find-duplicates.sh` on the dataset:

1. **Review duplicate pairs**
2. **Explain why duplicates hurt**: "Training on duplicates makes the model memorize those specific images instead of learning your general style"
3. **Let the artist decide** which to keep from each pair

## Phase 4: Style-Aware Captioning

This is the core innovation. For each image:

1. **Analyze with Claude vision** to identify:
   - **Content**: what's depicted (subject, setting, action, objects)
   - **Style**: technique elements (brushwork, palette, lighting quality, composition, edge treatment, texture, color harmony)

2. **Format captions for the base model**:
   - Pony/SDXL → booru-style tags (see `resources/dataset/caption-formats.md`)
   - Flux → natural language descriptions
   - Kohya format: `.txt` file alongside each image

3. **Prepend trigger word** to every caption

4. **Human review**: Present 5 sample captions for approval before batch captioning:
   ```
   Image: forest_01.png
   Caption: "mystyle, oil painting of a dense forest path, dappled golden light filtering through canopy,
   visible brushwork with impasto technique, warm earth tones with cool shadow accents,
   atmospheric perspective creating depth, soft diffused edges on background foliage"

   Content elements: forest path, light through trees
   Style elements: oil painting technique, impasto brushwork, warm-cool contrast, atmospheric perspective

   Does this capture both what's in the image AND how it's painted? [approve / adjust / skip]
   ```

5. **Batch caption** remaining images using the approved style

## Phase 5: Dataset Curation

Using `resources/dataset/curation-guide.md`:

1. **Analyze diversity**: pose variety, angle variety, subject variety, lighting variety
2. **Recommend optimal subset** if portfolio is larger than needed
3. **Flag clusters** that are too similar
4. **Suggest regularization images** if needed (explain: "These are 'normal' images that help the model remember what it already knows while learning your style")

## Phase 6: Gate 1 — Dataset Report

Generate `grimoire/training/{name}/dataset-report.md`:

```markdown
# Dataset Report: {name}

## Summary
- Images: {count}
- Captioned: {count}/{total} ({percent}%)
- Average resolution: {WxH}
- Duplicates found: {count} (removed: {count})
- Quality issues: {count}

## Diversity Assessment
{qualitative analysis of variety in subjects, angles, lighting, etc.}

## Content-Style Balance
{assessment of whether content and style can be separated}

## Quality Issues
{list of specific problems found}

## Gate 1 Decision: GO / NO-GO
{reasoning}

### If NO-GO:
{specific, actionable fixes}

### If GO:
{what this dataset will train well, and known limitations}
```
