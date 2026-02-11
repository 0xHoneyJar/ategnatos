# LoRA Evaluation Methodology

## In Plain Language
After training a LoRA (your custom style or character add-on), you need to test it before using it in real projects. Evaluation means generating test images at different strength settings to see how well the training worked. This guide tells you exactly what to look for and how to decide if your LoRA is ready.

## What You Need to Know

### The Evaluation Process

1. **Generate a weight grid** — same prompt at different LoRA strengths (0.3, 0.5, 0.7, 0.9, 1.0)
2. **Compare to originals** — does the output actually look like your training data?
3. **Test with different prompts** — does the LoRA work with various subjects, not just the training images?
4. **Compare checkpoints** — earlier checkpoints might be better than the final one
5. **Find the sweet spot** — the weight where style is clear but quality stays high

### What To Look For

#### Style Fidelity
Does the generated image capture the key elements of your training data?

| Element | What To Check |
|---------|--------------|
| Color palette | Are the characteristic colors present? |
| Brushwork/texture | Does the surface quality match? |
| Composition style | Are framing patterns similar? |
| Lighting quality | Is the light mood captured? |
| Edge treatment | Are edges crisp/soft in the same way? |

#### Quality Preservation
Does the image still look good, or has the LoRA damaged it?

| Issue | What It Looks Like |
|-------|-------------------|
| Face distortion | Eyes, nose, mouth look warped or melted |
| Color banding | Smooth gradients become stepped/blocky |
| Artifacts | Random noise, blotches, or impossible geometry |
| Loss of detail | Fine details become mushy or blurred |
| Pose collapse | Body proportions look wrong |

#### Generalization
Does the LoRA work on things it wasn't trained on?

| Test | Why It Matters |
|------|---------------|
| Different subjects | Style LoRA should apply to ANY subject, not just cats |
| Different compositions | Should work in portraits, landscapes, close-ups |
| Different lighting | Should adapt to bright, dark, dramatic, flat |
| With other LoRAs | Should combine cleanly with character or concept LoRAs |

### Standardized Test Prompts

Use these to exercise the LoRA consistently:

**For style LoRAs:**
1. "a portrait of a woman looking at the viewer" — tests face quality
2. "a wide landscape with mountains and a river" — tests composition and color
3. "a still life with fruit on a table" — tests texture and lighting
4. "a cat sitting in a window" — tests natural subjects
5. "an abstract composition with geometric shapes" — tests pure style

**For character LoRAs:**
1. "character_name standing, full body" — tests identity preservation
2. "character_name portrait, close up face" — tests facial detail
3. "character_name sitting at a desk" — tests pose variety
4. "character_name in a forest" — tests environment integration
5. "character_name, action pose" — tests dynamic poses

**For object LoRAs:**
1. "object_name on a white background" — tests isolation
2. "object_name on a table in a room" — tests context
3. "object_name held by a person" — tests interaction
4. "object_name, close up detail" — tests detail
5. "multiple object_name" — tests repetition

### Checkpoint Comparison

Training produces checkpoints at regular intervals. The final checkpoint isn't always the best.

| Checkpoint | What To Expect |
|------------|---------------|
| Early (25% through) | Subtle effect, may not be enough |
| Mid (50% through) | Often the sweet spot for style |
| Late (75% through) | Strong effect, risk of overfit |
| Final (100%) | Strongest effect, highest overfit risk |

**Rule of thumb**: Compare the final checkpoint to one from the middle of training. If the mid checkpoint produces cleaner images with recognizable style, use that one.

### Decision Framework

After evaluation, the LoRA fits one of these categories:

| Outcome | Indicators | Action |
|---------|-----------|--------|
| **Ready** | Style visible at 0.5-0.8, no quality loss, generalizes | Register and use |
| **Needs tuning** | Works but sweet spot is too narrow or too strong | Adjust epochs or rank, retrain |
| **Overtrained** | Copies training images, faces distorted | Use earlier checkpoint or retrain with fewer epochs |
| **Undertrained** | Style barely visible even at 1.0 | Retrain with more epochs or higher learning rate |
| **Dataset issue** | Wrong colors, missing elements, inconsistent | Go back to dataset phase |

## Why This Matters
Evaluation prevents wasting time with a LoRA that doesn't actually work. It takes 5 minutes to evaluate properly but saves hours of frustration if you discover the LoRA needs adjustment.

## Sources
- LoRA training community best practices (Civitai, Hugging Face forums)
- AUTOMATIC1111 and ComfyUI LoRA testing workflows
