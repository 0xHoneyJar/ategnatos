# Ategnatos — AI Art Production Framework

> A standalone Claude Code framework for AI art production workflows.
> Orchestrates the full pipeline: prompt crafting, ComfyUI workflow management,
> LoRA training, GPU infrastructure, and aesthetic memory.

## Design Principles

1. **The human drives creative decisions.** The framework remembers, enforces consistency, and removes grunt work.
2. **Accessible language always.** Users may not know ML terminology. Explain everything in plain language.
3. **Prevent wasted GPU time.** Validate everything before training starts. Dataset quality, environment compatibility, VRAM headroom — check it all upfront.

## Core Commands

| Command | What It Does |
|---------|-------------|
| `/studio` | Set up and manage your generation environment — local ComfyUI, remote GPU instances, model inventory |
| `/art` | Generate visual assets — prompt crafting, iteration, export |
| `/train` | LoRA training — dataset prep, captioning, config, execution, evaluation |
| `/eye` | Manage accumulated aesthetic preferences |

## State Files

| File | Purpose | Updated By |
|------|---------|------------|
| `grimoire/eye.md` | Aesthetic preferences | `/eye` |
| `grimoire/studio.md` | Environment profile | `/studio` |
| `grimoire/library/` | Saved prompts | `/art` |
| `grimoire/training/` | Training projects | `/train` |

## Known Pain Points (from experience)

These are real problems encountered during LoRA training that this framework MUST prevent:

- CUDA version mismatches on cloud GPU instances — always validate before installing PyTorch
- PyTorch/torchvision version incompatibilities — pin exact versions matched to detected CUDA
- OOM crashes with no recovery — pre-calculate VRAM needs, auto-reduce batch size
- SSH/tmux sessions breaking mid-training — make every step idempotent and resumable
- Hours wasted on wrong training data — validate dataset thoroughly before any GPU time
