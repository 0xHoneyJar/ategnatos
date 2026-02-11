# Style-Aware Captioning Guide

## In Plain Language
Most captioning tools describe what's IN an image (a cat, a tree). Style-aware captioning also describes HOW it's rendered (thick brushwork, warm palette, atmospheric perspective). This dual description is what separates good LoRA training from mediocre results.

## What You Need to Know

### The Two Layers

Every training caption should describe two things:

1. **Content** — What's depicted
   - Subject: who or what is in the image
   - Setting: where the scene takes place
   - Action: what's happening
   - Objects: notable items in the scene

2. **Style** — How it's rendered
   - Medium: oil paint, watercolor, digital, ink
   - Brushwork: visible strokes, smooth blending, impasto, stipple
   - Palette: warm, cool, muted, vibrant, complementary, analogous
   - Lighting: direction, quality, color temperature
   - Composition: symmetry, rule of thirds, leading lines, negative space
   - Edge treatment: sharp, soft, lost and found edges
   - Texture: rough, smooth, grainy, glossy
   - Atmosphere: hazy, crisp, moody, airy

### Caption Structure

**Template:**
```
{trigger_word}, {content description}, {style description}
```

**Example (booru/tag format for Pony/SDXL):**
```
mystyle, 1girl, sitting, cafe interior, coffee cup, looking out window,
oil painting, visible brushwork, warm palette, golden hour lighting,
soft edges, atmospheric perspective, muted earth tones
```

**Example (natural language for Flux):**
```
mystyle, a young woman sits in a cafe looking out the window with a coffee cup
on the table. Rendered as an oil painting with clearly visible brushwork in
warm earth tones, the golden hour light creates a soft glow. The background
uses atmospheric perspective with soft, lost edges while the subject has
slightly more defined features.
```

### Style Elements to Identify

When looking at an image, ask these questions:

| Question | Style Element | Example Tags/Phrases |
|----------|--------------|---------------------|
| What medium does it look like? | Medium | oil painting, watercolor, digital painting, charcoal |
| Can you see brush/pen strokes? | Brushwork | visible brushstrokes, smooth blending, impasto, hatching |
| What's the overall color feeling? | Palette | warm tones, cool blues, muted pastels, vivid saturated |
| Where does the light come from? | Lighting | side lighting, rim light, diffused ambient, dramatic contrast |
| How is the image arranged? | Composition | centered, rule of thirds, diagonal, asymmetric |
| How do edges look between areas? | Edge quality | sharp crisp edges, soft blending, lost and found |
| How does the surface feel? | Texture | smooth gradient, rough canvas, paper grain |
| What's the spatial feeling? | Depth/atmosphere | atmospheric haze, sharp depth of field, flat |

### Captioning Workflow

1. **Set the trigger word** — chosen during intent interview
2. **Start with content** — describe what you see, naturally
3. **Add style observations** — describe how it's rendered
4. **Match the base model's format** (tags for Pony, sentences for Flux)
5. **Review 5 samples** with the artist before batch captioning
6. **Adjust** based on feedback, then caption the rest

### Quality Checks for Captions

- Does every caption include the trigger word?
- Does every caption describe both content AND style?
- Are style descriptions consistent across the dataset? (Same technique described the same way each time)
- Are content descriptions specific enough to differentiate images?
- Is the format correct for the target base model?

### What NOT to Caption

- **Don't describe quality**: "high quality, masterpiece, beautiful" — these are generation prompts, not training captions
- **Don't use vague style words**: "nice style, good colors" — be specific about what the technique actually is
- **Don't copy-paste identical captions**: Each image is unique; captions should reflect what's different
- **Don't over-caption**: A 200-word caption isn't better than a 50-word caption. Be specific, not verbose.

### Trigger Word Placement

The trigger word always goes first:
```
mystyle, [rest of caption]
```

This consistent placement trains the model to associate the trigger with the learned concept.

## Why This Matters
Standard captioning tools produce "a cat sitting on a chair" — useful for content but invisible on style. Style-aware captioning produces "a cat sitting on a chair, oil painting with visible impasto, warm sienna palette" — teaching the model both what it sees and how it's rendered. This dual teaching is what makes style LoRAs actually work.

## Sources
- [Kohya Training: The Importance of Captions](https://github.com/kohya-ss/sd-scripts/wiki)
- [CivitAI Caption Guide](https://education.civitai.com/)
