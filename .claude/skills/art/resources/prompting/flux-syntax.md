# Flux Prompt Syntax

## In Plain Language
Flux models understand natural language — write prompts like you'd describe an image to a person. Full sentences work much better than comma-separated tags. This is the opposite of SDXL/Pony.

## What You Need to Know

### Basic Format
Write a descriptive paragraph. Be specific about what you see in your mind's eye.

**Good prompt**:
```
A woman with long auburn hair stands in a sunlit forest clearing, wearing a flowing emerald green dress. Soft golden light filters through the canopy above, casting dappled shadows on the mossy ground. She looks directly at the viewer with a calm expression. The scene has a painterly quality with warm, earthy tones.
```

**Bad prompt** (tag style — don't do this with Flux):
```
1girl, auburn hair, forest, green dress, sunlight, painterly, warm tones
```

### Key Differences from SDXL

| Aspect | SDXL/Pony | Flux |
|--------|-----------|------|
| Prompt style | Tags (comma-separated) | Natural language (sentences) |
| Quality tags | Required (`score_9`, `masterpiece`) | Not needed — just describe quality |
| CFG Scale | 5-9 (usually 7) | 1-4 (very low — this is normal) |
| Negative prompts | Important | Less important (model is better at ignoring unwanted elements) |
| Steps | 25-40 | 20-30 (often 20 is enough) |

### Tips for Good Flux Prompts

1. **Describe the scene in order**: subject → setting → lighting → style → mood
2. **Be specific about style**: Instead of "painterly", say "painted in the style of golden age illustration with visible brushwork and rich oil-paint texture"
3. **Describe lighting concretely**: "warm golden sunlight from the upper left" beats "good lighting"
4. **Mention camera angle if relevant**: "shot from slightly below, looking up" or "aerial view looking down"
5. **Text rendering**: Flux can render text in images. Include text in quotes: `a sign that reads "WELCOME"`

### CFG Scale
Flux uses very low CFG (1-4). If your output looks oversaturated or artifacted, lower the CFG. This is the single most common mistake people make with Flux.

### Guidance Scale
Flux has a separate "guidance" parameter (distinct from CFG in some interfaces). Typical values: 3-4. This controls how closely the model follows your prompt.

## Why This Matters
Using tag-style prompts with Flux wastes the model's best capability — understanding complex descriptions. Flux was trained on natural language captions, so natural language prompts communicate your intent far more precisely.

## Sources
- [Black Forest Labs: Flux](https://blackforestlabs.ai/)
- [Flux Prompting Community Guide](https://huggingface.co/black-forest-labs/FLUX.1-dev)
