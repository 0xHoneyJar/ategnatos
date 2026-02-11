# Optimizers — Choosing Your Training Engine

## In Plain Language
An optimizer is the algorithm that decides how to adjust the model after each training step. Think of it like different driving styles — one driver is careful and steady, another is adaptive and self-correcting, another is fast but less predictable. Each has trade-offs.

## What You Need to Know

### The Three Main Options

#### Prodigy (Recommended for Beginners)
**What it is**: An adaptive optimizer that automatically adjusts the learning rate during training. You don't need to tune the learning rate — it figures it out.

| Aspect | Details |
|--------|---------|
| Learning rate | Set to 1.0 (Prodigy handles the rest) |
| VRAM usage | Moderate (slightly more than AdamW) |
| Speed | Moderate |
| Best for | Beginners, first-time training, when you don't want to tune |
| Risk | Can sometimes converge to suboptimal results |

**When to use**: You're not sure what learning rate to use, or this is your first LoRA.

**When to avoid**: You need precise control over training dynamics, or you have very limited VRAM.

#### AdamW (Recommended for Control)
**What it is**: The standard optimizer. Reliable, well-understood, widely documented. Requires manual learning rate tuning.

| Aspect | Details |
|--------|---------|
| Learning rate | 1e-4 (standard), tune from there |
| VRAM usage | Low |
| Speed | Fast |
| Best for | Experienced users, precise control, well-documented recipes |
| Risk | Wrong learning rate wastes training time |

**When to use**: You have a proven learning rate (from a recipe or previous successful training).

**When to avoid**: You're guessing at the learning rate and don't want to waste GPU time experimenting.

#### Lion (Advanced)
**What it is**: A newer optimizer that uses less memory and can train faster. Less forgiving of poor parameters.

| Aspect | Details |
|--------|---------|
| Learning rate | 1e-5 to 3e-5 (much lower than AdamW) |
| VRAM usage | Low (less than AdamW) |
| Speed | Fast |
| Best for | VRAM-constrained environments, advanced users |
| Risk | More sensitive to hyperparameters; easier to overtrain |

**When to use**: You're experienced and need to save VRAM, or you have a proven Lion recipe.

**When to avoid**: First time training. Lion requires more careful parameter tuning.

### Comparison Table

| Factor | Prodigy | AdamW | Lion |
|--------|---------|-------|------|
| Ease of use | Easy | Moderate | Hard |
| Learning rate tuning | None needed | Required | Required (and more sensitive) |
| VRAM usage | Moderate | Low | Lowest |
| Training speed | Moderate | Fast | Fast |
| Result quality | Good | Excellent (when tuned) | Excellent (when tuned) |
| Community documentation | Growing | Extensive | Limited |
| Recommended for | Beginners | Intermediate | Advanced |

### Our Default Recommendation

```
First attempt → Prodigy (set learning rate to 1.0, let it adapt)
Refinement → AdamW at 1e-4 (if Prodigy result was close but needs tuning)
VRAM pressure → Lion at 1e-5 (if you need to save every MB)
```

### Backend Compatibility

| Optimizer | Kohya | SimpleTuner | ai-toolkit |
|-----------|-------|-------------|------------|
| Prodigy | Yes (install prodigyopt) | Yes (built-in) | Yes |
| AdamW | Yes (built-in) | Yes (built-in) | Yes |
| Lion | Yes (install lion-pytorch) | Yes | Limited |

## Why This Matters
The optimizer choice affects training time, VRAM usage, and result quality. Picking the wrong optimizer (or wrong learning rate for that optimizer) is a common reason training fails or produces mediocre results. When in doubt, start with Prodigy.

## Sources
- [Prodigy: An Expeditiously Adaptive Parameter-Free Learner](https://arxiv.org/abs/2306.06101)
- [AdamW: Decoupled Weight Decay Regularization](https://arxiv.org/abs/1711.05101)
- [Lion: Evolved Sign Momentum](https://arxiv.org/abs/2302.06675)
- [CivitAI Optimizer Comparison](https://civitai.com/articles/3105)
