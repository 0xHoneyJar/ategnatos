# Feedback Mapping

## In Plain Language
When an artist says "too dark" or "more dreamy," this reference translates their feedback into specific prompt changes. It's the bridge between how artists talk and how models listen.

## What You Need to Know

### How to Use This File

1. Artist gives feedback in natural language
2. Match their feedback to a category below
3. Apply the suggested prompt adjustments
4. Show the artist what you changed and why

### Lighting Feedback

| Artist Says | What to Adjust | SDXL/Pony | Flux |
|-------------|---------------|-----------|------|
| "too dark" | Increase lighting keywords | Add `bright lighting, well-lit` or increase weight on existing lighting | Add "brightly lit" or "illuminated by strong light" |
| "too bright" | Reduce lighting, add shadow | Add `dim lighting, moody` or reduce lighting weight | Add "softly lit" or "subtle shadows" |
| "too flat" | Add depth via lighting contrast | Add `dramatic lighting, chiaroscuro, depth` | Add "with strong directional light creating depth and shadow" |
| "harsh lighting" | Soften light sources | Replace with `soft lighting, diffused light, gentle illumination` | Add "soft, diffused lighting without harsh shadows" |
| "needs warmth" | Shift color temperature | Add `warm lighting, golden hour, warm tones` | Add "bathed in warm golden light" |
| "too warm" / "too yellow" | Cool the color temperature | Add `cool lighting, blue hour` or reduce warm keywords | Add "in cool, neutral light" |
| "backlit" / "needs rim light" | Add backlighting | Add `rim lighting, backlit, silhouette lighting` | Add "backlit with a glowing rim of light around the subject" |

### Color Feedback

| Artist Says | What to Adjust | SDXL/Pony | Flux |
|-------------|---------------|-----------|------|
| "too saturated" | Reduce color intensity | Add `muted colors, desaturated, subtle palette` | Add "with muted, understated colors" |
| "needs more color" | Increase vibrancy | Add `vibrant colors, vivid, colorful` | Add "rich, vibrant colors" |
| "wrong palette" | Shift color scheme | Replace color terms; specify desired palette | Describe the exact colors you want |
| "too monochrome" | Add color variety | Remove monochrome tags, add `colorful, varied palette` | Add "with a diverse range of colors" |
| "warmer colors" | Shift toward reds/oranges | Add `warm palette, amber, golden, sunset tones` | Add "in warm amber and golden tones" |
| "cooler colors" | Shift toward blues/purples | Add `cool palette, azure, twilight tones` | Add "in cool blue and violet tones" |

### Composition Feedback

| Artist Says | What to Adjust | SDXL/Pony | Flux |
|-------------|---------------|-----------|------|
| "too centered" | Adjust framing | Add `rule of thirds, off-center composition` | Add "composed using the rule of thirds, subject offset to one side" |
| "too busy" | Reduce visual clutter | Add negative: `cluttered, busy background, crowded`; simplify prompt | Add "clean composition with minimal background elements" |
| "too empty" | Add environmental detail | Add setting details, props, background elements | Describe specific background elements |
| "wrong angle" | Change camera perspective | Add `from above`, `from below`, `eye level`, `three quarter view` | Add "viewed from [angle]" |
| "more space" | Adjust framing/negative space | Add `wide shot, negative space, breathing room` | Add "with generous negative space around the subject" |
| "closer" | Tighten framing | Add `close-up, portrait, tight crop` | Add "close-up view" or "tightly framed" |
| "further back" | Widen framing | Add `wide shot, full body, establishing shot` | Add "seen from a distance" or "wide establishing shot" |

### Style Feedback

| Artist Says | What to Adjust | SDXL/Pony | Flux |
|-------------|---------------|-----------|------|
| "more painterly" | Increase painted quality | Add `oil painting, visible brushwork, painterly, impasto` | Add "painted with visible brushwork and rich texture, oil painting quality" |
| "too smooth" / "too digital" | Add texture/imperfection | Add `textured, rough, organic, traditional media` | Add "with subtle texture and organic imperfections, hand-crafted feel" |
| "more realistic" | Push toward photorealism | Add `photorealistic, detailed skin texture, photography` | Add "photorealistic, like a professional photograph" |
| "less realistic" | Push toward illustration | Add `illustration, stylized, artistic` and negate `photorealistic` | Add "in an illustrated, stylized manner" |
| "more detailed" | Increase detail level | Add `highly detailed, intricate, fine details` | Add "extremely detailed with intricate fine details visible throughout" |
| "softer" | Reduce sharpness/detail | Add `soft focus, dreamy, gentle` | Add "with a soft, dreamlike quality" |
| "more dreamy" | Add ethereal quality | Add `dreamy, ethereal, atmospheric, soft glow, haze` | Add "ethereal and dreamlike, with a soft atmospheric glow" |

### Subject Feedback

| Artist Says | What to Adjust | SDXL/Pony | Flux |
|-------------|---------------|-----------|------|
| "expression is wrong" | Adjust facial expression | Replace expression tag: `smiling`, `serene`, `intense gaze`, `gentle expression` | Describe the exact expression you want |
| "wrong pose" | Change body positioning | Add specific pose: `standing, sitting, leaning, dynamic pose` | Describe the pose in detail |
| "wrong outfit" | Change clothing | Replace clothing descriptions | Describe the exact clothing |
| "hands look weird" | Fix hands (common AI issue) | Add negative: `(bad hands:1.3), extra fingers, deformed hands` | Add "with naturally posed, anatomically correct hands" |
| "eyes are off" | Fix eye issues | Add `detailed eyes, beautiful eyes` and negate `cross-eyed, uneven eyes` | Add "with clear, well-defined eyes looking [direction]" |

### Mood / Atmosphere Feedback

| Artist Says | What to Adjust | SDXL/Pony | Flux |
|-------------|---------------|-----------|------|
| "too happy" / "too cheerful" | Shift mood | Replace mood tags with `melancholy, pensive, somber` | Describe the mood you want |
| "too dark" (mood) | Lighten atmosphere | Replace with `hopeful, serene, peaceful` | Add "with a sense of calm and serenity" |
| "needs energy" | Add dynamism | Add `dynamic, energetic, motion blur, action` | Add "full of energy and movement" |
| "too static" | Add life/movement | Add `wind-blown, flowing, dynamic pose, movement` | Add "with a sense of natural movement" |
| "creepy" / "uncanny" | Fix uncanny valley | Adjust proportions, simplify details, check weight values | Simplify description, be more specific about natural features |

### Technical Feedback

| Artist Says | What to Adjust | Method |
|-------------|---------------|--------|
| "too blurry" | Increase sharpness | Increase steps, add `sharp focus, crisp` |
| "too noisy" / "grainy" | Reduce noise | Increase steps, try different sampler |
| "wrong resolution" | Change dimensions | Adjust width/height in workflow |
| "looks compressed" | Quality issue | Ensure no JPEG compression in pipeline; increase quality settings |
| "artifacts" | Generation artifacts | Lower CFG, check weight values (reduce if >1.5), try different seed |

## Adjustment Stacking

When combining multiple adjustments:
1. Make the biggest change first (usually composition or lighting)
2. Add secondary adjustments
3. Don't change more than 2-3 things per iteration — too many changes make it hard to isolate what worked
4. Always show the artist what changed between iterations

## When Feedback Doesn't Map

If the artist's feedback doesn't fit these categories:
1. Ask for clarification: "When you say 'more organic,' do you mean the texture, the shapes, or the overall feel?"
2. Look for reference images: "Can you show me an example of what you're going for?"
3. Try a small targeted change and check if it's in the right direction

## Why This Matters
Artists think in terms of feeling and appearance, not prompt tokens. This mapping bridges the gap so iterations are fast and accurate instead of trial-and-error.
