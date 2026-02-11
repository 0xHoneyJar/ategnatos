# Model Database

Known AI image generation models with capabilities, settings, and download sources.

---

## Pony Diffusion V6 XL

### In Plain Language
A model built for stylized, character-focused art. Very popular with artists who want anime, cartoon, or illustrated styles. Responds well to quality tags that tell it to aim higher.

### What You Need to Know
- **Type**: Checkpoint (full model)
- **Base**: SDXL architecture
- **Best for**: Stylized characters, anime, illustration, cartoon styles
- **VRAM needed**: 8GB minimum, 12GB+ recommended
- **Resolution**: 1024x1024 (native), supports other SDXL resolutions

### Recommended Settings
| Setting | Value | Why |
|---------|-------|-----|
| CFG Scale | 6-8 | 7 is the sweet spot for most prompts |
| Clip Skip | 2 | Pony was trained with clip skip 2 |
| Sampler | Euler a, DPM++ 2M Karras | Both work well |
| Steps | 25-35 | 30 is a good default |
| Quality tags | `score_9, score_8_up, score_7_up` | These are Pony-specific quality boosters — always include them |

### Prompt Style
Booru-style tags work best: `score_9, score_8_up, 1girl, long hair, warm lighting, painterly style`

Natural language also works but tags are more reliable for this model.

### Why This Matters
If you use natural language prompts without the quality score tags, Pony's output quality drops significantly. Always include `score_9, score_8_up` at minimum.

### Sources
- [CivitAI: Pony Diffusion V6 XL](https://civitai.com/models/257749/pony-diffusion-v6-xl)
- [Pony Prompting Guide](https://civitai.com/articles/4248)

---

## SDXL 1.0 (Stable Diffusion XL)

### In Plain Language
The general-purpose workhorse. Good at almost everything — photorealistic images, illustrations, concept art, landscapes. The most mature model with the largest ecosystem of LoRAs and extensions.

### What You Need to Know
- **Type**: Checkpoint (full model)
- **Base**: SDXL architecture
- **Best for**: General purpose — photos, illustrations, concept art, landscapes
- **VRAM needed**: 8GB minimum, 12GB+ recommended
- **Resolution**: 1024x1024 (native), supports various aspect ratios

### Recommended Settings
| Setting | Value | Why |
|---------|-------|-----|
| CFG Scale | 5-9 | 7 is a good default |
| Sampler | DPM++ 2M Karras, Euler a | Most reliable samplers |
| Steps | 25-40 | 30 is balanced |
| Quality tags | `masterpiece, best quality, high resolution` | General quality boosters |

### Prompt Style
Both natural language and tag-based prompts work. Natural language tends to give better results for complex scenes.

### Why This Matters
SDXL has the largest LoRA ecosystem. If you train a LoRA, SDXL compatibility means the most options for combining with other community LoRAs and models.

### Sources
- [Stability AI: SDXL](https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0)
- [SDXL Prompting Guide](https://stable-diffusion-art.com/sdxl-prompts/)

---

## Flux Dev

### In Plain Language
A newer model from Black Forest Labs (founded by the original Stable Diffusion creators). Excellent at following complex prompts and generating photorealistic images. Understands natural language instructions better than older models.

### What You Need to Know
- **Type**: Checkpoint (full model)
- **Base**: Flux architecture (different from SDXL)
- **Best for**: Photorealistic images, complex scenes, text rendering, prompt adherence
- **VRAM needed**: 12GB minimum, 24GB recommended (larger model)
- **Resolution**: Flexible (not fixed to 1024x1024)

### Recommended Settings
| Setting | Value | Why |
|---------|-------|-----|
| CFG Scale | 1-4 | Flux uses very low CFG — this is normal |
| Sampler | Euler | Primary sampler for Flux |
| Steps | 20-30 | 20 is usually enough |
| Guidance | 3-4 | Flux-specific guidance parameter |

### Prompt Style
**Natural language only.** Flux understands descriptive sentences much better than tags. Write prompts like you'd describe the image to a person.

Good: "A woman standing in a sunlit forest clearing, wearing a flowing blue dress, soft golden hour lighting filtering through the trees"

Bad: "1girl, forest, blue dress, sunlight, score_9" (tag style doesn't work well)

### Why This Matters
Flux is significantly larger than SDXL, so it needs more VRAM. If you're on a 12GB GPU, you may need to use quantized versions. On cloud GPUs, this isn't an issue.

### Sources
- [Black Forest Labs: Flux](https://blackforestlabs.ai/)
- [HuggingFace: Flux Dev](https://huggingface.co/black-forest-labs/FLUX.1-dev)

---

## Flux Schnell

### In Plain Language
The fast version of Flux. Generates images in 1-4 steps instead of 20-30. Quality is slightly lower than Flux Dev but generation is nearly instant. Great for rapid prototyping — try ideas fast, then switch to Dev for final quality.

### What You Need to Know
- **Type**: Checkpoint (full model)
- **Base**: Flux architecture (distilled for speed)
- **Best for**: Quick iterations, prototyping, testing concepts before committing to longer runs
- **VRAM needed**: 12GB minimum, 24GB recommended
- **Resolution**: Flexible

### Recommended Settings
| Setting | Value | Why |
|---------|-------|-----|
| CFG Scale | 1 | Schnell needs minimal guidance |
| Sampler | Euler | Primary sampler |
| Steps | 1-4 | That's the whole point — it's fast |

### Prompt Style
Same as Flux Dev — natural language descriptions.

### Why This Matters
When you're iterating on a concept and generating dozens of variations, Schnell saves significant time and compute. Use it to find the right direction, then switch to Dev for the final version.

### Sources
- [HuggingFace: Flux Schnell](https://huggingface.co/black-forest-labs/FLUX.1-schnell)

---

## Illustrious XL

### In Plain Language
A community-refined SDXL model focused on anime and illustration. Similar to Pony V6 but with different training data and tagging conventions. Known for vibrant colors and clean linework. A strong alternative when Pony's quality tags feel limiting.

### What You Need to Know
- **Type**: Checkpoint (full model)
- **Base**: SDXL architecture
- **Best for**: Anime, manga-style illustration, vivid character art
- **VRAM needed**: 8GB minimum, 12GB+ recommended
- **Resolution**: 1024x1024 (native), supports SDXL aspect ratios

### Recommended Settings
| Setting | Value | Why |
|---------|-------|-----|
| CFG Scale | 5-8 | 7 works well for most styles |
| Clip Skip | 2 | Trained with clip skip 2 (like Pony) |
| Sampler | Euler a, DPM++ 2M Karras | Standard SDXL samplers |
| Steps | 25-35 | 30 is a good default |
| Quality tags | `masterpiece, best quality` | Uses standard quality tags (not Pony's score system) |

### Prompt Style
Booru-style tags work best, similar to Pony but without the `score_X` system. Standard quality tags apply.

Good: `masterpiece, best quality, 1girl, long flowing hair, sunset, vivid colors, detailed eyes`

### LoRA Compatibility
Illustrious XL is SDXL-based, so most SDXL LoRAs work. However, LoRAs trained specifically on Pony may not transfer perfectly — test at lower weights (0.4-0.6) first.

### Why This Matters
If Pony's style feels too specific or you want a different aesthetic baseline, Illustrious XL gives you SDXL compatibility with a different artistic training set. Great for artists who want vibrant, clean anime without Pony's particular aesthetic.

### Sources
- [CivitAI: Illustrious XL](https://civitai.com/models/795765/illustrious-xl)

---

## Stable Diffusion 1.5

### In Plain Language
The original Stable Diffusion that started the AI art revolution. Older and lower resolution than SDXL, but much faster and has the largest ecosystem of LoRAs, embeddings, and tools. Still useful for quick iterations and when you need access to the massive 1.5 community resources.

### What You Need to Know
- **Type**: Checkpoint (full model)
- **Base**: SD 1.5 architecture (different from SDXL)
- **Best for**: Quick iterations, using legacy LoRAs, low VRAM setups
- **VRAM needed**: 4GB minimum, 6GB+ recommended
- **Resolution**: 512x512 (native) — lower than SDXL
- **File size**: ~4GB (vs ~6.5GB for SDXL)

### Recommended Settings
| Setting | Value | Why |
|---------|-------|-----|
| CFG Scale | 7-11 | Higher CFG than SDXL; 7.5 is default |
| Sampler | Euler a, DPM++ 2M Karras | Well-tested for 1.5 |
| Steps | 20-30 | 20 is often sufficient |
| Resolution | 512x512 | Native; upscale afterward for larger output |

### Prompt Style
Tags and natural language both work. Positive/negative prompt separation matters more here than with SDXL.

Good positive: `masterpiece, best quality, detailed, a woman in a garden, soft lighting, oil painting style`
Good negative: `worst quality, low quality, blurry, deformed hands, extra fingers`

### LoRA Compatibility
SD 1.5 has the LARGEST LoRA ecosystem — thousands available on CivitAI. SD 1.5 LoRAs are NOT compatible with SDXL or Flux models (different architecture).

### When to Use
- You have a GPU with <8GB VRAM
- You need a specific SD 1.5 LoRA that hasn't been retrained for SDXL
- Quick prototyping before committing to higher-resolution generation
- Learning/experimentation (faster feedback cycle)

### Why This Matters
Despite being older, SD 1.5 runs on almost any GPU and has the most community content. It's worth knowing about even if you primarily use SDXL or Flux, because some artistic styles only exist as 1.5 LoRAs.

### Sources
- [HuggingFace: Stable Diffusion 1.5](https://huggingface.co/runwayml/stable-diffusion-v1-5)
- [CivitAI Models (SD 1.5)](https://civitai.com/models?types=Checkpoint&baseModels=SD+1.5)

---

## Model Recommendations

### "Which model should I use?"

| Your Goal | Recommended Model | Why |
|-----------|------------------|-----|
| Stylized characters, anime | Pony V6 XL or Illustrious XL | Best at stylized art with tags |
| Photorealistic images | Flux Dev | Best prompt comprehension and realism |
| General purpose illustration | SDXL 1.0 | Most versatile, huge LoRA ecosystem |
| Quick prototyping | Flux Schnell | Near-instant generation |
| Low VRAM (<8GB) | SD 1.5 | Runs on almost any GPU |
| LoRA training (style) | Pony V6 XL or SDXL 1.0 | Best training support and documentation |
| LoRA training (character, Flux) | Flux Dev | Best at natural language prompts |

### Model Architecture Compatibility

LoRAs are NOT interchangeable between architectures:

| LoRA Trained On | Works With | Does NOT Work With |
|----------------|------------|-------------------|
| SD 1.5 | SD 1.5, SD 1.x variants | SDXL, Flux |
| SDXL / Pony / Illustrious | SDXL, Pony V6, Illustrious XL | SD 1.5, Flux |
| Flux | Flux Dev, Flux Schnell | SD 1.5, SDXL |

### Glossary

| Term | What It Means |
|------|--------------|
| **Checkpoint** | A full model file — the AI brain that generates images. Usually 2-7 GB. |
| **LoRA** | A small add-on (20-200 MB) that teaches a checkpoint new styles or characters. |
| **SDXL** | Stable Diffusion XL — a model architecture. Multiple models share this base (SDXL 1.0, Pony, Illustrious). |
| **Flux** | A newer model architecture by Black Forest Labs. Better at following instructions but needs more VRAM. |
| **CFG Scale** | How strongly the model follows your prompt vs its own instincts. Higher = more literal, lower = more creative. |
| **Sampler** | The algorithm that builds the image step by step. Different samplers produce slightly different results. |
| **Steps** | How many times the sampler refines the image. More steps = more detail but slower. |
| **Clip Skip** | Tells the model to use a less-processed understanding of your prompt. Some models need this set to 2. |
| **VRAM** | GPU memory. More VRAM = can run bigger models and generate larger images. |
| **Booru tags** | Short descriptive labels separated by commas (like hashtags). Some models understand these better than sentences. |
| **Inference** | Generating an image (as opposed to training). Uses less VRAM than training. |
| **Quantized** | A smaller version of a model that uses less VRAM with minor quality loss. |

## Quick Reference

| Model | Style | Prompt Type | VRAM | Speed | Quality |
|-------|-------|------------|------|-------|---------|
| Pony V6 XL | Stylized/anime | Booru tags | 8GB+ | Medium | High (for stylized) |
| SDXL 1.0 | General | Tags or natural | 8GB+ | Medium | High |
| Illustrious XL | Anime/illustration | Booru tags | 8GB+ | Medium | High |
| Flux Dev | Photorealistic | Natural language | 12GB+ | Slow | Very high |
| Flux Schnell | Prototyping | Natural language | 12GB+ | Very fast | Good |
| SD 1.5 | Legacy/low VRAM | Tags or natural | 4GB+ | Fast | Medium |
