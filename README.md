# Ategnatos

*Gaulish: ate- (re-) + gnatos (born). Reborn.*

Your art style, reborn through AI. Train models that understand how you see. Generate assets that feel like yours. Ategnatos is the bridge between your creative vision and the machines that can learn it.

## What This Is

Ategnatos is a [Claude Code](https://docs.anthropic.com/en/docs/claude-code) framework for AI art production. Four slash commands give you the full pipeline — environment setup, prompt crafting, LoRA training, and aesthetic memory — without leaving your terminal.

It is opinionated about one thing: **you should not need to understand CUDA driver versions to make art.** Everything else is up to you.

Ategnatos is standalone but was also designed to coexist with [Loa](https://github.com/0xHoneyJar/loa), an agent-driven development framework. The two use separate state directories and separate command spaces, so they slot together without conflicts. Loa handles the software engineering lifecycle; Ategnatos handles the art production lifecycle. You can use either or both.

### Who It's For

- Creatives who want to stop fighting infrastructure
- Developers who need visual assets and want guided defaults instead of trial-and-error
- Anyone who has lost a training run to a preventable environment error

### What It's Not

This is not a model. It's not a GUI. It doesn't generate images itself. It orchestrates the tools that do — ComfyUI, kohya sd-scripts, SimpleTuner, ai-toolkit — and makes sure they work before you spend money on GPU time.

## The Four Commands

### `/studio` — Environment Manager

Detects your GPU, finds ComfyUI, inventories your models and LoRAs. Manages cloud GPU providers (Vast.ai, RunPod, Lambda) with spin-up, validation, and teardown. Tracks everything in a single state file so the other commands know what you have.

### `/art` — Art Director's Assistant

Takes a vague idea ("I need a mascot") and walks you through prompt crafting, generation, feedback, iteration, and export. Reads your aesthetic preferences from `/eye` and your available tools from `/studio`. Saves successful prompts to a library for reuse.

### `/train` — Training Specialist

The reason this project exists. Guides you through LoRA training with a **four-gate safety pipeline**:

1. **Dataset Gate** — Audits images for quality, duplicates, resolution. Validates captions for content-style separation.
2. **Config Gate** — Generates training configs with VRAM estimation. Catches OOM before it happens.
3. **Environment Gate** — Validates CUDA, PyTorch, training backend compatibility. The gate that would have saved those seven sessions.
4. **Dry Run Gate** — Short test run (2-5 steps) to verify everything connects before committing GPU hours.

No training starts until all four gates pass. Supports kohya sd-scripts, SimpleTuner, and ai-toolkit backends with ready-made presets.

### `/eye` — Aesthetic Memory

Records what you like and what you don't, across sessions. Color palettes, textures, composition preferences, hard "never" constraints. `/art` and `/train` read from it automatically — you say it once and it sticks.

## Getting Started

### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and working
- Bash shell (macOS, Linux, WSL)
- For generation: ComfyUI running (locally or tunneled from cloud)
- For training: A GPU with 8GB+ VRAM (cloud or local)

### Setup

```bash
git clone https://github.com/0xHoneyJar/ategnatos.git
cd ategnatos
```

Then start a Claude Code session and run:

```
/studio
```

The studio manager will interview you about your setup — local GPU, cloud providers, ComfyUI location, installed models — and build your environment profile. From there:

```
/eye       # Tell it what you like (optional, but makes /art better)
/art       # Start making things
/train     # Train a LoRA when you need a custom model
```

## Project Structure

```
ategnatos/
├── .claude/
│   ├── commands/          # Slash command definitions
│   │   ├── studio.md      # /studio
│   │   ├── art.md         # /art
│   │   ├── train.md       # /train
│   │   └── eye.md         # /eye
│   ├── skills/            # Skill implementations + reference docs
│   │   ├── studio/        # GPU detection, ComfyUI, providers
│   │   ├── art/           # Prompting, formats, feedback
│   │   ├── train/         # Backends, datasets, evaluation
│   │   └── eye/           # Preference categories
│   └── scripts/           # 17 shell scripts
│       ├── studio/        # detect-gpu, detect-comfyui, provider-*, comfyui-*
│       ├── art/           # export-asset, image-info
│       └── train/         # dataset-audit, find-duplicates, validate-environment, ...
├── grimoire/              # Persistent state (your data)
│   ├── eye.md             # Your aesthetic preferences
│   ├── studio.md          # Your environment profile
│   ├── library/           # Saved prompts
│   ├── training/          # Training project data
│   ├── projects/          # Art project state
│   └── workflows/         # Saved ComfyUI workflows
├── workspace/             # Active work (datasets, outputs, configs)
└── exports/               # Final approved assets
```

The `grimoire/` directory is your persistent state. Template files (`eye.md`, `studio.md`) are tracked in git; your actual data (training projects, prompt library, etc.) is gitignored.

## License

MIT

---

*Ridden with [Loa](https://github.com/0xHoneyJar/loa)*
