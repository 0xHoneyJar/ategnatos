# VRAM Estimation Methodology

## In Plain Language
Before training starts, we estimate how much GPU memory (VRAM) you'll need. This prevents the most frustrating training failure: running out of memory 20 minutes into a 2-hour session. We always add a 20% safety margin.

## What You Need to Know

### What Uses VRAM During Training

| Component | Approximate VRAM | Notes |
|-----------|-----------------|-------|
| Base model (loaded) | 6-10 GB | SDXL ~6.5 GB, Flux ~10 GB |
| LoRA weights | 0.1-0.5 GB | Depends on rank |
| Optimizer state | 0.3-1.0 GB | Prodigy > AdamW > Lion |
| Gradients | 0.5-2.0 GB | Scales with model and batch |
| Batch of latents | 1-2 GB per image | At 1024x1024 resolution |
| Activations cache | 0.5-1.5 GB | Reduced by gradient checkpointing |
| xformers/flash attention | -1.5 GB (savings) | Enable if available |

### Estimation Formula

```
VRAM = base_model + lora_overhead + optimizer + (batch_size * latent_cost) + activations - xformers_savings
```

With 20% safety margin:
```
Required VRAM = VRAM * 1.2
```

### Quick Reference Tables

#### SDXL / Pony LoRA Training

| Rank | Batch 1 | Batch 2 | Batch 4 |
|------|---------|---------|---------|
| 16 | ~9 GB | ~11 GB | ~14 GB |
| 32 | ~10 GB | ~12 GB | ~15 GB |
| 64 | ~11 GB | ~13 GB | ~16 GB |

#### Flux LoRA Training

| Rank | Batch 1 | Batch 2 |
|------|---------|---------|
| 16 | ~14 GB | ~16 GB |
| 32 | ~15 GB | ~17 GB |
| 64 | ~16 GB | ~19 GB |

*Values include 20% safety margin. With xformers enabled.*

### GPU Recommendations by Training Type

| GPU | VRAM | SDXL LoRA | Flux LoRA | Cost (cloud) |
|-----|------|-----------|-----------|-------------|
| RTX 3080 | 10 GB | Tight (rank 16, batch 1) | Not recommended | $0.10-0.20/hr |
| RTX 3090 | 24 GB | Comfortable | Possible (batch 1) | $0.20-0.40/hr |
| RTX 4090 | 24 GB | Comfortable | Possible (batch 1) | $0.30-0.50/hr |
| A5000 | 24 GB | Comfortable | Possible | $0.25-0.40/hr |
| A6000 | 48 GB | Any config | Comfortable | $0.50-0.80/hr |
| A100 40GB | 40 GB | Any config | Comfortable | $0.80-1.50/hr |
| A100 80GB | 80 GB | Any config | Any config | $1.50-2.50/hr |

### When VRAM is Tight

If you're close to the limit, these save VRAM:
1. **Enable xformers** (saves ~1.5 GB)
2. **Reduce batch size** to 1
3. **Reduce network rank** (16 instead of 32)
4. **Enable gradient checkpointing** (saves ~1 GB, slightly slower)
5. **Use Lion optimizer** (less state than Prodigy/AdamW)
6. **Reduce resolution** to 768x768 (last resort — hurts quality)

## Why This Matters
Running out of VRAM mid-training crashes the process and wastes the time spent so far. Estimating upfront lets us pick the right GPU or adjust parameters before spending money.

## Sources
- Empirical measurements from community training benchmarks
- [VRAM Requirements for SD Training](https://github.com/kohya-ss/sd-scripts/wiki/VRAM-requirements)
