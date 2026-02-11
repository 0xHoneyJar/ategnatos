# Preference Categories

How aesthetic preferences are organized. Each category captures a different dimension of visual taste.

## Color

What colors and color relationships you're drawn to (or repelled by).

**Examples of preferences**:
- "Warm palettes — earth tones, amber, terracotta"
- "Muted over saturated"
- "High contrast between light and dark"
- "Monochromatic with one accent color"

**Examples of anti-preferences**:
- "AVOID: neon/fluorescent colors"
- "NEVER: all-grey desaturated look"

## Texture

How surfaces and materials feel visually.

**Examples**:
- "Painterly, visible brushwork"
- "Grain or noise for warmth"
- "Clean, sharp edges"
- "Soft, diffused look"

**Anti-examples**:
- "AVOID: plastic/glossy 3D rendering"
- "NEVER: flat vector style"

## Composition

How elements are arranged in the frame.

**Examples**:
- "Generous negative space"
- "Asymmetric balance"
- "Strong diagonals"
- "Center-weighted with vignette"

## Style

Broader aesthetic movements or approaches.

**Examples**:
- "Art nouveau influences"
- "Ukiyo-e flat color with line art"
- "Impressionistic light handling"
- "Retro/vintage poster aesthetic"

## Subject

Subject matter preferences (what you tend to create).

**Examples**:
- "Characters over environments"
- "Organic forms over geometric"
- "Animals and creatures"
- "Urban landscapes"

## Anti-Preferences

Things you don't want in your work. Two levels:

### AVOID
Things you generally skip. The framework will exclude these from prompts by default but won't block them if you specifically ask.

**Examples**: "AVOID: photorealistic skin", "AVOID: lens flare effects"

### NEVER
Hard constraints. The framework will always exclude these and warn you if a request might produce them.

**Examples**: "NEVER: stock photo aesthetic", "NEVER: AI-typical hands"

## Model Combos

Specific model + settings combinations that consistently produce results matching your preferences. Tracked automatically when you approve outputs.

**Format**: `{model} + {settings} + {LoRA}@{weight} = {outcome} [{approval count}]`

**Example**: "Pony V6 + CFG 7 + mibera-lora@0.7 = consistent good results [3 approvals]"
