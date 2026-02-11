# GPU Provider Guide

## In Plain Language
When your local GPU (the chip that generates AI images) isn't powerful enough (or you don't have one), you can rent a cloud GPU by the hour. It's like renting computing power from someone else's machine. Each provider has different pricing, interfaces, and quirks. This guide helps you pick the right one.

## What You Need to Know

### Provider Comparison

| Provider | Best For | GPU Options | Pricing | Ease of Use |
|----------|---------|-------------|---------|-------------|
| **Vast.ai** | Budget training | Wide variety (consumer + datacenter) | $0.10-2.50/hr | Moderate |
| **RunPod** | Reliable training | Curated selection | $0.20-3.00/hr | Easy |
| **Lambda** | High-end research | A100, H100 | $0.80-3.00/hr | Easy |
| **Local** | No cloud needed | Whatever you have | Free (electricity) | Easiest |

### When to Use Cloud vs Local

**Use local GPU when:**
- You have an NVIDIA GPU with 10+ GB VRAM
- Training SDXL LoRAs (10-24 GB VRAM sufficient)
- You want zero cost and maximum control

**Use cloud GPU when:**
- No local GPU or insufficient VRAM
- Training Flux LoRAs (needs 16-24+ GB)
- Need faster training (A100/H100)
- Apple Silicon Mac (MPS training is slow)

### Cost Estimation

For a typical LoRA training session:

| Training Type | Quick (5 min) | Standard (30 min) | Thorough (2 hr) |
|--------------|--------------|-------------------|-----------------|
| Vast.ai RTX 3090 | $0.02 | $0.10 | $0.40 |
| RunPod RTX 4090 | $0.03 | $0.15 | $0.60 |
| Lambda A100 | $0.07 | $0.40 | $1.60 |

*Approximate. Actual costs depend on GPU availability and market pricing.*

### The Lifecycle

Every cloud GPU session follows the same pattern:

```
1. Choose provider and GPU
2. Spin up instance
3. Validate environment (Gate 3)
4. Deploy training tools
5. Transfer dataset
6. Train
7. Pull results
8. TEAR DOWN IMMEDIATELY
```

**Step 8 is critical.** Every minute the instance runs costs money. Always tear down when done.

## Why This Matters
Cloud GPUs make training accessible to everyone, but they cost real money. Picking the right provider and tearing down promptly saves money. We track active instances and always remind you to tear down.

## Sources
- [Vast.ai](https://vast.ai/)
- [RunPod](https://www.runpod.io/)
- [Lambda Cloud](https://lambdalabs.com/service/gpu-cloud)
