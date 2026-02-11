# Prompt Engineering Principles

## In Plain Language
A prompt is the text instruction you give an AI image model. Better prompts = better images. Think of it like giving directions — the more specific and clear you are, the closer you get to where you want to go.

## What You Need to Know

### Structure Matters
Most prompts work best in this order:
1. **Subject** — what's in the image (a woman, a dragon, a landscape)
2. **Action/pose** — what they're doing (standing, flying, serene)
3. **Setting** — where they are (forest, city, abstract background)
4. **Style** — how it should look (painterly, photorealistic, anime)
5. **Quality/technical** — model-specific boosters (varies by model)
6. **Lighting/mood** — atmosphere (golden hour, dramatic, soft)

### Specificity Wins
- Vague: "a nice landscape" → unpredictable results
- Specific: "a misty mountain valley at dawn, soft pink light on snow-capped peaks, pine trees in foreground" → much closer to intent

### The Negative Prompt
Tells the model what to avoid. Less intuitive than positive prompts but critical for quality:
- Common negatives prevent known failure modes (bad hands, blurry, watermarks)
- Style negatives prevent unwanted aesthetics (photorealistic when you want illustrated)

### Different Models, Different Rules
- **SDXL/Pony models**: Respond to tag-style prompts (comma-separated keywords)
- **Flux models**: Respond to natural language (full sentences)
- Using the wrong style for the model reduces quality significantly

## Why This Matters
The difference between a mediocre and excellent AI image is usually the prompt, not the model. A well-crafted prompt on a basic model beats a poor prompt on the best model.

## Sources
- [Stable Diffusion Prompt Guide](https://stable-diffusion-art.com/prompt-guide/)
- [CivitAI Prompting Wiki](https://education.civitai.com/civitais-prompt-craft-essentials)
