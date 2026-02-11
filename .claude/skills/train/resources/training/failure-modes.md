# Training Failure Modes

## In Plain Language
Sometimes a trained LoRA (the small add-on that teaches your model new styles or characters) doesn't come out right. This guide maps what you're seeing to what went wrong and how to fix it. Every failure has a specific cause and a specific fix — you don't need to start over from scratch.

## What You Need to Know

### Quick Reference

| What You See | Most Likely Cause | Fix |
|-------------|------------------|-----|
| Output looks blurry | Overtrained | Use earlier checkpoint, reduce epochs |
| Ignores trigger word | Undertrained | More epochs, check trigger in captions |
| Copies training images exactly | Severely overtrained | Fewer epochs, add dataset diversity |
| Style captured but wrong colors | Captions missing color descriptions | Recaption with explicit color/palette tags |
| Works at 1.0 but not lower | Too few training steps | More epochs or higher learning rate |
| Artifacts at any weight | Dataset quality issues | Re-run dataset audit, check for corrupted images |
| Good on some subjects, bad on others | Insufficient diversity | Add more varied subjects to dataset |
| Face/body distortion | Rank too high or overtrained | Lower rank, fewer epochs, or lower weight |

### Detailed Failure Analysis

---

### "Output looks blurry or soft"

**What's happening**: The model has been shown the same images too many times. Instead of learning the style, it's averaging everything together into a blur.

**Cause**: Overtrained — too many epochs for your dataset size.

**How to check**: Compare checkpoints. If epoch 10 is sharper than epoch 20, you overtrained.

**Fix (easiest to hardest)**:
1. **Use an earlier checkpoint** — check epoch 5, 10, 15 outputs
2. **Reduce epochs** — cut by 30-50% and retrain
3. **Reduce learning rate** — the model is learning too aggressively
4. **Add more images** — larger dataset needs more epochs to overtrain

---

### "Trigger word is ignored"

**What's happening**: The model hasn't learned to associate your trigger word with the style/concept.

**Cause**: Undertrained, or trigger word not consistently in captions.

**How to check**: Open your caption .txt files and verify the trigger word is at the start of every single caption.

**Fix**:
1. **Check every caption** — trigger word MUST be in 100% of captions
2. **Train longer** — add 50% more epochs
3. **Increase learning rate** (carefully) — if using AdamW, try 1.5x the current rate
4. **Simplify trigger** — use a unique nonsense word (e.g., "xyzstyle") not a real word

---

### "Copies training images exactly"

**What's happening**: The model has memorized your training images instead of learning the general pattern. This is called "overfitting."

**Cause**: Severely overtrained, often combined with too few images or too many duplicates.

**How to check**: Generate with the same prompt structure as your captions. If the output is pixel-similar to a training image, you've overfit.

**Fix**:
1. **Use a much earlier checkpoint** — try the earliest available
2. **Reduce epochs dramatically** — cut by 50-75%
3. **Add more diverse images** — especially different subjects
4. **Check for duplicates** — run `find-duplicates.sh` again
5. **Lower network rank** — reduces the model's memorization capacity

---

### "Style captured but wrong colors"

**What's happening**: The model learned the brushwork, composition, and texture but not the color palette. This happens when captions describe the subject but not the colors.

**Cause**: Captions don't explicitly describe the color characteristics.

**How to check**: Read your captions. Do they mention specific colors, warm/cool temperature, saturation level?

**Fix**:
1. **Recaption with color focus** — add explicit color descriptions:
   - "warm golden tones with cool blue shadows"
   - "desaturated earth palette"
   - "high contrast complementary colors"
2. **Retrain** — the model will pick up color information from updated captions

---

### "Works at 1.0 but not at lower weights"

**What's happening**: The LoRA's effect is too weak to show at subtle strengths. The model barely learned the concept.

**Cause**: Too few training steps, learning rate too low, or rank too low.

**How to check**: If there's barely any effect at 0.7 but clear effect at 1.0, the training signal is too weak.

**Fix**:
1. **More epochs** — add 50-100% more
2. **Higher learning rate** — if using AdamW, increase 2x
3. **Higher network rank** — from 16 to 32, or 32 to 64
4. **Switch to Prodigy optimizer** — it auto-adjusts learning rate

---

### "Artifacts at any weight"

**What's happening**: The LoRA introduces visual errors — noise, blotches, impossible geometry, color bleeding.

**Cause**: Usually dataset quality issues, sometimes config problems.

**How to check**:
1. Re-run `dataset-audit.sh` — look for corrupted or very low-resolution images
2. Check if artifacts appear even at weight 0.3 — if so, it's a fundamental issue

**Fix**:
1. **Audit dataset** — remove any corrupted, very low-res, or heavily JPEG-compressed images
2. **Check color space** — all images must be RGB (not CMYK, not grayscale)
3. **Lower noise offset** — try 0.0 instead of 0.1
4. **Reduce rank** — high rank with small dataset amplifies noise

---

### "Good on some subjects, bad on others"

**What's happening**: The LoRA only works well for subjects similar to the training data. It hasn't generalized.

**Cause**: Insufficient subject diversity in the training dataset.

**How to check**: Generate 5 different subjects (person, animal, landscape, object, abstract). If only 1-2 look right, the LoRA hasn't generalized.

**Fix**:
1. **Add diverse subjects** — the content-style separation problem:
   - If training a style, use 5+ different subjects
   - Cats AND people AND landscapes AND objects
2. **Improve captions** — be explicit about what is style vs content
3. **Use regularization images** — "normal" images that prevent catastrophic forgetting

---

### "Training crashed or produced NaN loss"

**What's happening**: The training process numerically exploded. Loss values became infinite.

**Cause**: Learning rate too high, or incompatible settings.

**How to check**: Check the training log for "NaN", "inf", or rapidly increasing loss values.

**Fix**:
1. **Reduce learning rate** — cut in half
2. **Switch to Prodigy** — it's more stable than manual learning rates
3. **Enable gradient clipping** — add `max_grad_norm = 1.0` to config
4. **Check mixed precision** — ensure bf16 is supported on your GPU

---

### "Training is impossibly slow"

**What's happening**: Training is progressing but each step takes much longer than expected.

**Cause**: Usually a configuration issue or hardware limitation.

**How to check**: Compare your step time to expected times:
- RTX 3090: ~2-4 sec/step for SDXL LoRA at batch 1
- RTX 4090: ~1-3 sec/step
- A100: ~0.5-2 sec/step
- Apple MPS: ~8-15 sec/step (3-5x slower is normal)

**Fix**:
1. **Enable xformers** — significant memory and speed improvement
2. **Check batch size** — don't exceed what your VRAM can handle
3. **Check resolution** — training at 1024 is 4x more work than 512
4. **Use bf16** — half-precision training is ~2x faster

## Why This Matters
Every failed training run wastes GPU time and money. But most failures have straightforward fixes. Understanding what went wrong means you can fix it in one iteration instead of blindly retraining and hoping for the best.
