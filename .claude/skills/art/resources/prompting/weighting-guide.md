# Prompt Weighting

## In Plain Language
Prompt weighting lets you tell the model "pay more attention to this part" or "pay less attention to that part." It's like underlining words in a sentence to show what matters most.

## What You Need to Know

### How It Works (SDXL/Pony)

Wrap a word or phrase in parentheses with a number:
```
(warm lighting:1.3)    — 30% more emphasis on warm lighting
(background:0.7)       — 30% less emphasis on the background
```

- **1.0** = normal (default, no change)
- **Above 1.0** = more emphasis (stronger influence on the output)
- **Below 1.0** = less emphasis (weaker influence)

### Safe Ranges

| Weight | Effect | When to Use |
|--------|--------|-------------|
| 0.5-0.8 | Subtle reduction | De-emphasize something without removing it |
| 0.8-1.0 | Slight reduction | Fine-tuning |
| 1.0 | Normal | Default |
| 1.0-1.3 | Slight boost | Make something a bit more prominent |
| 1.3-1.5 | Strong boost | Make something clearly dominant |
| 1.5+ | Extreme | Usually causes artifacts — avoid |

### Common Mistakes

1. **Going too high**: Weights above 1.5 often cause weird artifacts instead of stronger emphasis. If 1.3 isn't enough, try rephrasing the prompt instead of increasing the weight.

2. **Weighting everything**: If you weight every term, nothing is actually weighted. Only emphasize 1-2 elements that truly matter most.

3. **Wrong syntax by model**: SDXL uses `(word:1.3)`. Some older models use `{word}` or `[[word]]`. Check which model you're using.

### Weighting in Flux

Flux handles emphasis differently. It understands natural language emphasis:
- Instead of `(warm:1.3)`, write "with particularly warm, golden lighting"
- Instead of `(detailed:1.5)`, write "extremely detailed, with intricate fine details visible"
- Flux responds better to descriptive emphasis than numerical weights

### Weighting vs. Position

In most models, words earlier in the prompt have naturally more influence. So:
```
warm lighting, a woman in a forest
```
gives more weight to "warm lighting" than:
```
a woman in a forest, warm lighting
```

This means prompt ordering is a form of implicit weighting.

## Why This Matters
Weighting is one of the most powerful tools for fine-tuning output, but it's easy to overuse. Most of the time, reordering your prompt or being more descriptive works better than adding weight numbers. Use weighting as a precision tool, not a hammer.

## Details (For the Curious)
Technically, weighting adjusts the attention scores in the model's cross-attention layers. Higher weight = the model "attends" more to those tokens during generation. Extreme weights oversaturate the attention mechanism, which is why they cause artifacts.
