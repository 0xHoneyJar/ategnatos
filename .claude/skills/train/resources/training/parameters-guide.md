# Training Parameters Guide

## In Plain Language
Training parameters are the knobs and dials that control how your model learns. Setting them wrong wastes GPU time. Setting them right produces great results. This guide explains every parameter you'll encounter.

## What You Need to Know

### The Critical Parameters

#### Learning Rate
**What it does**: How big of a step the model takes each time it adjusts. Too big = overshoots and produces garbage. Too small = learns nothing or takes forever.

| Scenario | Recommended | Notes |
|----------|-------------|-------|
| Standard LoRA (SDXL/Pony) | 1e-4 (0.0001) | Safe starting point |
| With Prodigy optimizer | 1.0 | Prodigy auto-adjusts; 1.0 is correct |
| With AdamW optimizer | 1e-4 to 5e-5 | Lower for larger datasets |
| Fine-tuning only text encoder | 5e-5 | Text encoder needs gentler treatment |

#### Epochs
**What it does**: How many times the model sees every image in your dataset. More epochs = more learning, but too many = memorization (overfitting).

| Training Type | Quick | Standard | Thorough |
|--------------|-------|----------|----------|
| Character | 5 | 10-15 | 20-30 |
| Style | 3-5 | 8-15 | 15-25 |
| Object | 5 | 10-15 | 20 |

**Rule of thumb**: With 30 images, 10 epochs = 300 training steps. The model sees each image 10 times.

#### Batch Size
**What it does**: How many images the model processes simultaneously. Larger batch = faster training but needs more VRAM.

| VRAM | Recommended Batch Size | Resolution |
|------|----------------------|------------|
| 10 GB | 1 | 1024x1024 |
| 16 GB | 1-2 | 1024x1024 |
| 24 GB | 2-4 | 1024x1024 |
| 48 GB (A100) | 4-8 | 1024x1024 |

**Safety**: We always calculate with a 20% VRAM safety margin. If your GPU has 24 GB, we plan for 19.2 GB available.

#### Network Rank (dim)
**What it does**: How much detail the LoRA can store. Higher rank = more capacity but larger file size and slower training.

| Use Case | Recommended Rank | File Size (approx) |
|----------|-----------------|-------------------|
| Simple character | 8-16 | 20-50 MB |
| Complex character | 16-32 | 50-100 MB |
| Style LoRA | 16-32 | 50-100 MB |
| Detailed style | 32-64 | 100-200 MB |

**Default**: 16 is a good starting point for most training.

#### Network Alpha
**What it does**: Scales the LoRA's influence during training. Typically set to half the rank or equal to rank.

| Common Settings | Behavior |
|----------------|----------|
| alpha = rank | Full strength (standard) |
| alpha = rank / 2 | Gentler training (safer) |
| alpha = 1 | Very conservative (rarely needed) |

**Default**: Equal to rank. Safer to use rank/2 for first training attempt.

### Generation Parameters (for reference during training)

| Parameter | Training Impact | Notes |
|-----------|---------------|-------|
| Resolution | Must match training resolution | Train at 1024x1024 → generate at 1024x1024 |
| CFG | Not used during training | Used during evaluation |
| Steps | Not used during training | Used during evaluation |
| Seed | Not used during training | Use fixed seeds during evaluation for comparison |

### Advanced Parameters

| Parameter | What It Does | Default | When to Change |
|-----------|-------------|---------|----------------|
| Warmup steps | Gradually increases learning rate at start | 10% of total steps | Rarely needs changing |
| Gradient accumulation | Simulates larger batch size | 1 | Increase if batch size is 1 and training is unstable |
| Mixed precision | Uses less VRAM per step | fp16 or bf16 | Use bf16 if GPU supports it (Ampere+) |
| Clip skip | Layers to skip in text encoding | 2 for Pony, 1 for SDXL | Must match generation setting |
| Noise offset | Improves dark/light image generation | 0.05-0.1 | Enable for better contrast range |

## Why This Matters
These parameters interact with each other. A high learning rate with many epochs produces a fried LoRA. A low learning rate with few epochs produces nothing. Getting the balance right is what the presets and Gate 2 validation handle for you.

## Sources
- [Kohya Training Parameters](https://github.com/kohya-ss/sd-scripts/wiki/Training-parameters)
- [LoRA Training Best Practices (CivitAI)](https://civitai.com/articles/3105)
- [Derrian's Guide to SD Training](https://civitai.com/articles/2056)
