# What LoRA Training Actually Does

## In Plain Language
A LoRA (Low-Rank Adaptation) teaches an existing AI model something new without rewriting the whole model. Think of the base model as a painter who already knows how to paint. A LoRA is like giving that painter a master class in your specific style — they keep all their existing skills but add your technique to their repertoire.

## What You Need to Know

### The Basic Idea

1. **Base model** = A large AI model that already knows how to make images (SDXL, Pony, Flux)
2. **LoRA** = A small "add-on" file that modifies how the base model behaves
3. **Training** = Showing the model your images with descriptions until it learns the pattern

### What Can a LoRA Learn?

| Training Type | What the Model Learns | Example |
|--------------|----------------------|---------|
| **Character** | A specific person's face, body, clothing | "What does this character look like from any angle?" |
| **Style** | An artistic technique — brushwork, palette, composition | "How does this artist paint, regardless of subject?" |
| **Object/Concept** | A specific item or visual concept | "What does this logo/weapon/creature look like?" |

### How Training Works (Simplified)

1. You show the model an image and its description (caption)
2. The model tries to recreate the image from the description
3. It compares its attempt to the real image
4. It adjusts its internal settings to get closer
5. Repeat hundreds of times until it "gets it"

The LoRA file stores only the adjustments — not a whole new model. That's why LoRA files are small (50-200 MB) compared to full models (2-7 GB).

### Trigger Words

A trigger word is a special word you include in every caption during training. Later, when you use the LoRA, including that trigger word tells the model "activate the thing you learned."

**Example**: If your trigger word is `mystyle`:
- During training: "mystyle, a landscape with warm golden light and visible brushwork"
- During generation: "mystyle, a portrait of a woman" → produces the portrait in your trained style

**Rules for trigger words:**
- Make it unique (not a real word the model already knows)
- Keep it short (1-2 words)
- Use it consistently in every caption
- Examples: `mystyle`, `johndoe_v1`, `craftlogo`, `artname_style`

### What Makes Training Succeed or Fail

| Factor | Success | Failure |
|--------|---------|---------|
| Dataset quality | Clean, diverse, well-captioned | Blurry, duplicate, uncaptioned |
| Dataset size | Right amount for the type | Too few (can't generalize) or too many (memorizes) |
| Content-style separation | Diverse subjects, consistent technique | All same subject (model confuses content for style) |
| Captions | Describe both content AND technique | Only describe content, or no captions at all |
| Training parameters | Matched to dataset and hardware | Default values without adjustment |
| Environment | Correct CUDA, PyTorch, enough VRAM | Version mismatches, OOM crashes |

### Overfitting

Overfitting is when the model memorizes your training images instead of learning the general pattern. Signs:
- Generated images look exactly like specific training images
- The model can't apply the learned concept to new subjects
- Results look "burned in" — too strong even at low LoRA weight

**Prevention**: Good dataset diversity, proper training duration, appropriate learning rate.

### Underfitting

Underfitting is the opposite — the model hasn't learned enough. Signs:
- The trigger word has little or no effect
- Generated images don't resemble the training data
- The style/character is barely visible

**Prevention**: More training steps, higher learning rate (carefully), better captions.

### VRAM and Training

Training requires more GPU memory (VRAM) than generating images:

| Training Type | Minimum VRAM | Comfortable VRAM |
|--------------|-------------|------------------|
| LoRA (SDXL) | 10 GB | 16-24 GB |
| LoRA (Flux) | 16 GB | 24 GB |

If you run out of VRAM during training, the process crashes (OOM — Out Of Memory). This is one of the most common pain points, and why we validate environment before starting.

## Why This Matters
Understanding what LoRA training does (and doesn't do) helps you make better decisions about your dataset, your expectations, and your budget. A 2-hour training run on a rented GPU costs real money — understanding the process means fewer wasted runs.

## Sources
- [LoRA: Low-Rank Adaptation of Large Language Models](https://arxiv.org/abs/2106.09685) — the original paper
- [Kohya ss Training Guide](https://github.com/kohya-ss/sd-scripts) — practical training documentation
- [CivitAI LoRA Training Wiki](https://education.civitai.com/) — community knowledge base
