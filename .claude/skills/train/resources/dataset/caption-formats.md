# Caption Formats

## In Plain Language
Different base models expect captions in different formats. Pony and SDXL were trained on tag-style captions (comma-separated keywords). Flux was trained on natural language descriptions. Using the right format for your base model makes a real difference in training quality.

## What You Need to Know

### Format by Base Model

| Base Model | Format | Example |
|-----------|--------|---------|
| Pony V6 XL | Booru tags (comma-separated) | `mystyle, 1girl, sitting, cafe, oil painting, warm tones, visible brushwork` |
| SDXL | Tags or short phrases | `mystyle, woman in cafe, oil painting style, warm golden lighting, textured brushwork` |
| Flux | Natural language (sentences) | `mystyle, a woman sitting in a cafe rendered as an oil painting with visible brushwork in warm golden tones` |

### Booru Tag Format (Pony/SDXL)

Booru tags are the format used on anime image boards. They're concise, specific, and comma-separated.

**Structure:**
```
{trigger}, {subject tags}, {action tags}, {setting tags}, {style tags}, {technique tags}
```

**Example:**
```
mystyle, 1girl, long hair, sitting, looking out window, cafe interior,
coffee cup, oil painting, visible brushwork, impasto technique,
warm earth tones, golden hour lighting, atmospheric perspective,
soft edges on background
```

**Tag rules:**
- One concept per tag
- Most specific to least specific
- Use established booru vocabulary when possible
- Style/technique tags go after content tags
- Trigger word always first

### Natural Language Format (Flux)

Flux expects flowing descriptions — how you'd describe the image to another person.

**Structure:**
```
{trigger}, {subject and scene description}. {style and technique description}.
```

**Example:**
```
mystyle, a young woman with long dark hair sits at a small cafe table
looking out a rain-streaked window, a coffee cup in her hands. The scene
is rendered as an oil painting with clearly visible impasto brushwork,
warm earth tones dominating the palette with touches of cool blue in the
shadows. Golden hour lighting enters from the window, creating soft
atmospheric perspective toward the background.
```

**Writing rules:**
- Full sentences, natural flow
- Describe what you see, then how it's rendered
- Be specific about technique and materials
- Avoid list-style formatting
- Trigger word still goes first

### Mixed Format (Advanced)

Some trainers use a hybrid approach: tags for content, natural language for style.

**Example:**
```
mystyle, 1girl, cafe, coffee cup, window.
Painted in oil with heavy impasto technique, warm earth-tone palette,
golden hour lighting creating atmospheric depth, soft lost edges in the
background contrasting with defined foreground detail.
```

This can work well when the content is straightforward but the style description needs nuance. Use with SDXL — Pony strongly prefers pure tags, Flux strongly prefers pure natural language.

### File Format

Captions are saved as `.txt` files with the same name as the image:

```
dataset/
├── image_001.png
├── image_001.txt    ← caption for image_001
├── image_002.jpg
├── image_002.txt    ← caption for image_002
└── ...
```

This is the format Kohya sd-scripts and most training backends expect.

### Caption Length

| Base Model | Recommended Length | Max Tokens |
|-----------|-------------------|------------|
| Pony V6 XL | 20-40 tags | 77 tokens (CLIP limit) |
| SDXL | 20-50 tags/phrases | 77 tokens |
| Flux | 30-100 words | 256+ tokens (T5 encoder) |

**Important**: SDXL/Pony use CLIP which has a 77-token limit. Tags beyond this are silently ignored during training. Flux uses a T5 text encoder with a much higher limit — longer descriptions are fine.

### What NOT to Include in Captions

- Quality tags (`masterpiece`, `best quality`, `score_9`) — these are for generation, not training
- Negative descriptions ("no watermark", "not blurry") — captions describe what IS there
- Artist names (unless you're the artist) — ethical and legal concerns
- Vague descriptors ("nice", "beautiful", "good") — be specific

## Why This Matters
The caption format directly affects how well the model learns from your images. Using natural language captions with a Pony model is like speaking French to someone who only understands English — some meaning gets through, but most is lost.

## Sources
- [Kohya Caption Format Documentation](https://github.com/kohya-ss/sd-scripts)
- [Flux Training Guide](https://huggingface.co/blog/flux-training)
