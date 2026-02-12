# Ategnatos — Software Design Document

**Version**: 1.0
**Date**: 2026-02-11
**Author**: AI (Software Architect) + Human (Creative Director)
**Status**: Draft
**Source PRD**: grimoires/loa/prd.md v1.1

---

## 1. Executive Summary

Ategnatos is a Claude Code skill-based framework for AI art production. It has no server, no database, no runtime of its own. It is a collection of markdown skill files, shell scripts, and reference data that makes Claude Code dramatically better at orchestrating AI art workflows — ComfyUI generation, LoRA training, GPU infrastructure, and aesthetic memory.

The architecture follows the same patterns as Loa (skills + scripts + state). No namespace prefix needed — Ategnatos command names (`studio`, `art`, `train`, `eye`) have zero overlap with Loa's commands or Rune's constructs. All persistent state lives in `grimoire/` as human-readable markdown.

## 2. System Architecture

### 2.1 High-Level Overview

```
┌─────────────────────────────────────────────────────┐
│                    Claude Code                       │
│  ┌───────────────────────────────────────────────┐  │
│  │              Ategnatos Framework               │  │
│  │                                                │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐      │  │
│  │  │ /studio  │ │  /art    │ │ /train   │      │  │
│  │  │  Skill   │ │  Skill   │ │  Skill   │      │  │
│  │  └────┬─────┘ └────┬─────┘ └────┬─────┘      │  │
│  │       │             │             │            │  │
│  │  ┌────┴─────┐ ┌────┴─────┐ ┌────┴─────┐      │  │
│  │  │ /eye   │ │ Scripts  │ │Reference │      │  │
│  │  │  Skill   │ │  Layer   │ │  Data    │      │  │
│  │  └────┬─────┘ └────┬─────┘ └────┬─────┘      │  │
│  │       │             │             │            │  │
│  │  ┌────┴─────────────┴─────────────┴──────┐    │  │
│  │  │           grimoire/ (State)            │    │  │
│  │  │  studio.md │ eye.md │ library/ │ ... │    │  │
│  │  └───────────────────────────────────────┘    │  │
│  └───────────────────────────────────────────────┘  │
│                         │                            │
│                    External Tools                    │
│  ┌──────────┐ ┌──────────────┐ ┌──────────────────┐ │
│  │ ComfyUI  │ │ GPU Providers│ │ Training Backends │ │
│  │  (API)   │ │ Vast/RunPod/ │ │ kohya/SimpleTuner │ │
│  │          │ │ Lambda/Local │ │ /ai-toolkit       │ │
│  └──────────┘ └──────────────┘ └──────────────────┘ │
└─────────────────────────────────────────────────────┘
```

### 2.2 Zone Model

| Zone | Path | Permission | Purpose |
|------|------|-----------|---------|
| System | `.claude/skills/{studio,art,train,eye}/`, `.claude/commands/*.md`, `.claude/scripts/*/` | Read-only | Framework code — skills, commands, scripts, reference data |
| State | `grimoire/` | Read/Write | Persistent state — preferences, inventory, history, library |
| Workspace | `workspace/` | Read/Write | Active work — datasets, workflows, outputs in progress |
| Export | `exports/` | Write | Final approved assets ready for use |

### 2.3 Coexistence with Loa

No namespace prefix needed. Loa's skills use descriptive verb phrases (`implementing-tasks`, `designing-architecture`). Ategnatos uses short nouns (`studio`, `art`, `train`, `eye`). Zero overlap verified against Loa v1.33.0 and Rune v4.0.0.

| Concern | Solution |
|---------|----------|
| Skill namespace | Plain names: `studio`, `art`, `train`, `eye` — no collision with Loa's `implementing-tasks`, etc. |
| Command namespace | Plain names: `.claude/commands/studio.md`, etc. — no collision with Loa's `implement.md`, `plan.md`, etc. |
| Script namespace | Organized in skill-named dirs: `.claude/scripts/studio/`, `.claude/scripts/train/`, etc. |
| State separation | Ategnatos uses `grimoire/` (singular). Loa uses `grimoires/loa/`. No collision |
| CLAUDE.md | Ategnatos has its own CLAUDE.md at project root |

## 3. Component Design

### 3.1 Skill Architecture

Each command maps to one skill. Each skill follows this structure:

```
.claude/skills/{name}/
├── index.yaml          # Metadata (name, version, description, danger_level)
├── SKILL.md            # Main instruction file — the "brain" of the skill
└── resources/          # Reference data files
    ├── *.md            # Knowledge bases, guides, templates
    └── *.json          # Structured data (model DB, provider specs)
```

**Skill loading**: When a user invokes `/studio`, Claude Code loads `.claude/commands/studio.md` which routes to `.claude/skills/studio/SKILL.md`. The SKILL.md contains the full role definition, workflow steps, decision trees, and references to resource files.

### 3.2 `/studio` — Environment & Infrastructure Skill

**Skill ID**: `studio`
**Danger Level**: `moderate` (manages cloud resources, can incur costs)

#### Components

```
.claude/skills/studio/
├── index.yaml
├── SKILL.md                        # Studio Manager role + workflow
└── resources/
    ├── providers/
    │   ├── provider-guide.md       # Overview of all providers, pros/cons, pricing
    │   ├── vastai.md               # Vast.ai-specific: CLI commands, instance types, gotchas
    │   ├── runpod.md               # RunPod-specific: CLI, templates, serverless vs pods
    │   ├── lambda.md               # Lambda Labs specifics
    │   └── local.md                # Local GPU detection and setup
    ├── comfyui/
    │   ├── api-reference.md        # ComfyUI REST API documentation
    │   ├── workflow-anatomy.md     # How ComfyUI workflow JSONs are structured
    │   └── templates/              # Base workflow templates
    │       ├── txt2img-sdxl.json   # Standard text-to-image for SDXL models
    │       ├── txt2img-flux.json   # Standard text-to-image for Flux models
    │       ├── img2img.json        # Image-to-image
    │       ├── upscale.json        # Upscaling workflow
    │       └── lora-test.json      # LoRA evaluation workflow
    ├── models/
    │   └── model-database.md       # Known models: name, type, capabilities, download, settings
    └── cuda-compat.md              # CUDA ↔ PyTorch ↔ Driver compatibility matrix

.claude/scripts/studio/
├── detect-gpu.sh                   # Detect local GPU, CUDA, driver, VRAM
├── detect-comfyui.sh               # Find running ComfyUI instance, check API
├── comfyui-submit.sh               # Submit workflow JSON to ComfyUI API
├── comfyui-poll.sh                 # Poll for completion, download results
├── provider-spinup.sh              # Generic provider spin-up (delegates to provider-specific)
├── provider-teardown.sh            # Generic provider teardown
├── provider-validate.sh            # Pre-flight environment validation on remote instance
└── providers/
    ├── vastai-lifecycle.sh          # Vast.ai-specific instance management
    └── runpod-lifecycle.sh          # RunPod-specific instance management
```

#### State Files

```
grimoire/
├── studio.md                       # Environment inventory
└── workflows/                      # User's workflow library
    └── {name}.json
```

**`grimoire/studio.md` schema:**

```markdown
# Studio

## Environment
- **Primary**: [Local RTX 4090 / RunPod A100 / Vast.ai / etc.]
- **CUDA**: [version]
- **ComfyUI**: [location, API endpoint if running]

## Models
| Name | Type | Base | Good For | Location | Settings |
|------|------|------|----------|----------|----------|
| Pony V6 XL | Checkpoint | SDXL | Stylized, character | /models/checkpoints/ | CFG 7, clip_skip 2 |

## LoRAs
| Name | Trigger | Weight Range | Trained On | Location |
|------|---------|-------------|------------|----------|
| mibera-style-v2 | mibera | 0.6-0.8 | Character style | /models/loras/ |

## Active Instances
| Provider | GPU | Status | Cost/hr | Started |
|----------|-----|--------|---------|---------|
```

#### Key Design Decisions

1. **Provider abstraction via scripts**: Each provider gets its own lifecycle script implementing a standard interface: `spinup`, `validate`, `deploy`, `execute`, `teardown`. The generic scripts delegate to provider-specific ones based on `grimoire/studio.md` config.

2. **ComfyUI workflow building**: Claude reads `workflow-anatomy.md` to understand the JSON structure, then builds workflows by composing node definitions. Templates provide starting points that Claude modifies based on the user's request.

3. **Cost awareness**: Every operation that touches a billed resource shows estimated cost and requires confirmation. Scripts emit cost data that the skill surfaces to the user.

### 3.3 `/art` — Generation & Iteration Skill

**Skill ID**: `art`
**Danger Level**: `safe` (no infrastructure changes, no billing without /studio)

#### Components

```
.claude/skills/art/
├── index.yaml
├── SKILL.md                        # Art Director's Assistant role + workflow
└── resources/
    ├── prompting/
    │   ├── prompt-engineering.md    # General prompt crafting principles
    │   ├── sdxl-syntax.md          # SDXL/Pony prompt syntax, quality tags, weights
    │   ├── flux-syntax.md          # Flux prompt syntax (natural language, different approach)
    │   ├── negative-prompts.md     # Common negative prompts by model family
    │   └── weighting-guide.md      # How (word:1.3) works, differs by model, accessible explanation
    ├── formats/
    │   └── asset-specs.md          # Common asset dimensions/formats (OG image, favicon, hero, etc.)
    └── feedback-mapping.md         # Maps natural language feedback to prompt adjustments
                                    # "too dark" → increase brightness/lighting keywords
                                    # "more playful" → add specific style modifiers

.claude/scripts/art/
├── export-asset.sh                 # Resize, convert format, optimize
└── image-info.sh                   # Read image metadata (dimensions, format, color profile)
```

#### State Files

```
grimoire/
├── eye.md                        # Read by /art for preference context
├── library/                        # Proven prompts
│   └── {model-family}/
│       └── {name}.md               # Prompt text, parameters, result notes
└── projects/
    └── {name}/
        └── assets/
            └── {asset}/
                ├── spec.md         # What's needed (dimensions, format, purpose)
                ├── iterations.md   # History of prompts tried, feedback received
                └── approved.md     # Final prompt + parameters that worked
```

#### Key Design Decisions

1. **Model-specific prompt building**: The skill reads which model is active from `grimoire/studio.md`, then loads the corresponding syntax guide from `resources/prompting/`. Pony V6 expects booru-style quality tags (`masterpiece, best quality, score_9`). Flux expects natural language descriptions. The user doesn't need to know this — the skill adapts.

2. **Feedback-to-prompt mapping**: `feedback-mapping.md` is a structured reference that maps common natural language feedback ("too busy", "warmer", "less contrast") to specific prompt adjustments. This is the knowledge that makes iteration faster than manual prompting.

3. **Iteration history**: Every generation attempt is logged in `iterations.md` with the exact prompt, parameters, and user feedback. This enables "go back to version 3 but warmer" and feeds into the prompt library when something works.

4. **No direct image generation**: The skill uses `/studio`'s ComfyUI integration or presents prompts for manual use. It never runs inference itself.

### 3.4 `/train` — LoRA Training Skill

**Skill ID**: `train`
**Danger Level**: `high` (manages GPU resources, significant cost potential)

#### Components

```
.claude/skills/train/
├── index.yaml
├── SKILL.md                        # Training Specialist role + workflow
└── resources/
    ├── dataset/
    │   ├── curation-guide.md       # How to select training images, quality criteria
    │   ├── captioning-guide.md     # Style-aware captioning methodology
    │   ├── caption-formats.md      # Format reference: booru tags vs natural language vs mixed
    │   ├── content-style.md        # The content-style separation problem, explained simply
    │   └── dataset-sizes.md        # Recommended sizes by training type, with citations
    ├── training/
    │   ├── training-concepts.md    # Plain-language explainer: what LoRA training actually does
    │   ├── parameters-guide.md     # Every parameter explained accessibly with rationale
    │   ├── optimizers.md           # Prodigy vs AdamW vs Lion, plain language comparison
    │   ├── presets.md              # Quick/Standard/Thorough preset definitions
    │   └── failure-modes.md        # Common failures → diagnosis → fixes, accessible language
    ├── backends/
    │   ├── kohya-adapter.md        # kohya sd-scripts: config format, CLI, quirks
    │   ├── simpletuner-adapter.md  # SimpleTuner: config format, CLI, quirks
    │   └── ai-toolkit-adapter.md   # ai-toolkit: config format, CLI, quirks
    ├── environment/
    │   ├── cuda-pytorch-matrix.md  # CUDA version → PyTorch version → install command
    │   ├── vram-calculator.md      # Model size + batch size + resolution → VRAM estimate
    │   └── preflight-checklist.md  # Step-by-step validation procedure
    └── evaluation/
        ├── eval-methodology.md     # How to evaluate a LoRA: weight grid, test prompts, comparison
        └── strength-guide.md       # Understanding LoRA weight (0.0-1.0), sweet spot finding

.claude/scripts/train/
├── dataset-audit.sh                # Check image resolution, format, corruption
├── find-duplicates.sh              # Perceptual hash + similarity detection
├── generate-config.sh              # Build training config from parameters
├── validate-environment.sh         # CUDA/PyTorch/VRAM/disk pre-flight
├── calculate-vram.sh               # Estimate VRAM usage for given config
├── launch-training.sh              # Start training with OOM recovery wrapper
├── monitor-training.sh             # Track progress, loss, VRAM
└── eval-grid.sh                    # Generate test images at multiple weights
```

#### State Files

```
grimoire/
└── training/
    └── {lora-name}/
        ├── intent.md               # What we're training and why
        ├── dataset-report.md        # Full audit results from dataset prep
        ├── config.md                # Training configuration used (with explanations)
        ├── environment.md           # Validated environment snapshot
        ├── progress.md              # Training progress log
        └── eval.md                  # Evaluation results and conclusions
```

#### Key Design Decisions

1. **Gate architecture**: Training has four sequential gates. Each must pass before the next begins:

```
GATE 1: Dataset         → dataset-report.md    (GO/NO-GO)
GATE 2: Configuration   → config.md            (user confirms)
GATE 3: Environment     → environment.md       (all checks green)
GATE 4: Dry Run         → model loads, no errors
────────────────────────────────────────────────────────
TRAINING STARTS (only after all 4 gates pass)
```

No GPU time is spent until Gate 4 passes. This is the core architectural principle.

2. **Backend adapter pattern**: Each training backend (kohya, SimpleTuner, ai-toolkit) gets an adapter resource file that maps from Ategnatos's standard config format to the backend's specific format. The SKILL.md reads the adapter file for whichever backend is configured.

   Standard config (what the skill works with):
   ```yaml
   base_model: ponyDiffusionV6XL
   training_type: character
   dataset_path: workspace/datasets/mibera/
   trigger_word: mibera
   network_rank: 32
   network_alpha: 16
   optimizer: prodigy
   epochs: 15
   batch_size: 2       # auto-calculated from VRAM
   resolution: 1024
   ```

   The adapter translates this to kohya CLI flags, SimpleTuner YAML, or ai-toolkit config.

3. **Style-aware captioning via Claude vision**: Claude can see images. During dataset prep, the skill shows Claude each training image and asks it to generate a caption that describes BOTH the content ("a woman in a forest") AND the stylistic technique ("warm palette, visible brushwork, dramatic side-lighting"). This is where Ategnatos provides unique value no other tool offers.

4. **Idempotent setup scripts**: Every script in `train/` is designed to be re-run safely. If SSH drops mid-setup, re-running the script picks up where it left off. This is implemented via state markers — each step checks if its output already exists before executing.

5. **OOM recovery in `launch-training.sh`**: Wraps the training command in a retry loop. On OOM (detected via exit code or stderr), halves batch size and retries. Maximum 3 retries. Reports each adjustment to the user in plain language.

### 3.5 `/eye` — Preference Memory Skill

**Skill ID**: `eye`
**Danger Level**: `safe`

#### Components

```
.claude/skills/eye/
├── index.yaml
├── SKILL.md                        # Creative Memory role + workflow
└── resources/
    └── categories.md               # Preference categories with examples
                                    # color, texture, composition, style, subject, anti-prefs
```

#### State Files

```
grimoire/
└── eye.md                        # Your eye — preferences, human-readable, append-friendly
```

**`grimoire/eye.md` schema:**

```markdown
# Taste Profile

## Color
- Warm palettes preferred (earth tones, amber, terracotta) [confirmed: 5 sessions]
- Muted > saturated [confirmed: 3 sessions]

## Texture
- Painterly, visible brushwork [confirmed: 4 sessions]
- AVOID: flat vector, glossy 3D [confirmed: 2 sessions]

## Composition
- Generous negative space [confirmed: 1 session]

## Style
- (preferences accumulate here)

## Anti-Preferences
- NEVER: photorealistic skin rendering
- NEVER: stock photo aesthetic

## Model Combos
- Pony V6 + CFG 7 + mibera-lora@0.7 = consistent good results [3 approvals]
```

#### Key Design Decisions

1. **Confirmation counts**: Each preference tracks how many times it's been confirmed. Higher counts = higher confidence. This is displayed to the user and influences how strongly the preference is applied.

2. **AVOID vs NEVER**: Two levels of negative preference. AVOID means "generally skip this." NEVER means "hard constraint, always exclude." Maps to negative prompts with different weights.

3. **Cross-skill reading**: `/art` and `/train` both read `eye.md` but only `/eye` writes to it. This prevents race conditions and keeps the eye file clean. During `/art` sessions, the art skill suggests preference updates but delegates the actual write to the eye system.

## 4. Reference Data Architecture

Reference data is the core intellectual property of Ategnatos. It's what makes the framework valuable — curated, accessible knowledge about models, providers, training, and prompting.

### 4.1 Reference Data Types

| Type | Location | Purpose | Update Frequency |
|------|----------|---------|------------------|
| Provider guides | `resources/providers/*.md` | GPU provider documentation, pricing, gotchas | Per release |
| Model database | `resources/models/model-database.md` | Known models with capabilities and settings | Per release |
| CUDA compat matrix | `resources/cuda-compat.md` | CUDA ↔ PyTorch version mapping | Per PyTorch release |
| Prompt syntax | `resources/prompting/*.md` | Model-specific prompt engineering | Per model family |
| Training parameters | `resources/training/*.md` | Parameter explanations and presets | Per training tool release |
| Failure modes | `resources/training/failure-modes.md` | Diagnosis → fix mapping | Continuously improved |
| ComfyUI templates | `resources/comfyui/templates/*.json` | Base workflow JSONs | Per ComfyUI release |

### 4.2 Accessibility Layer

Every reference file follows a strict format:

```markdown
# [Topic]

## In Plain Language
[1-2 sentence explanation anyone can understand]

## What You Need to Know
[Practical guidance, no jargon]

## Why This Matters
[Consequence of getting it wrong — in terms of wasted time/money, not technical terms]

## Details (For the Curious)
[Technical details for users who want to go deeper]

## Sources
[Links to community guides, documentation, research]
```

This ensures the accessibility requirement (XCT-010 through XCT-013) is baked into the data architecture, not just the skill instructions.

## 5. Script Architecture

### 5.1 Script Design Principles

All scripts follow these rules:

1. **Idempotent**: Can be re-run safely. Check for existing state before acting.
2. **Single-line friendly**: No multi-line constructs that break over SSH/copy-paste.
3. **Exit codes**: 0 = success, 1 = expected failure (e.g., validation failed), 2 = unexpected error.
4. **JSON output**: Scripts that return data use `--json` flag for machine-readable output, human-readable by default.
5. **No silent failures**: Every error is surfaced with a plain-language explanation.

### 5.2 Script Categories

```
.claude/scripts/
├── studio/          # Infrastructure management
│   ├── detect-*.sh      # Read-only detection scripts
│   ├── comfyui-*.sh     # ComfyUI API interaction
│   ├── provider-*.sh    # Generic provider lifecycle
│   └── providers/       # Provider-specific implementations
├── train/           # Training pipeline
│   ├── dataset-*.sh     # Dataset preparation utilities
│   ├── validate-*.sh    # Pre-flight validation
│   ├── calculate-*.sh   # VRAM/cost estimators
│   ├── launch-*.sh      # Training execution with recovery
│   ├── monitor-*.sh     # Progress tracking
│   └── eval-*.sh        # Evaluation utilities
└── art/             # Generation utilities
    ├── export-*.sh      # Asset export and conversion
    └── image-*.sh       # Image metadata reading
```

## 6. Command Architecture

### 6.1 Command Definitions

```
.claude/commands/
├── studio.md        # Routes to studio skill
├── art.md           # Routes to art skill
├── train.md         # Routes to train skill
└── eye.md         # Routes to eye skill
```

Each command file follows Claude Code's command format:

```markdown
---
description: "Set up and manage your AI art generation environment"
agent: studio
---
# /studio

[Skill SKILL.md is loaded automatically]
```

### 6.2 Golden Path

Ategnatos doesn't have a multi-phase workflow like Loa. Instead, commands are independent and can be used in any order. However, there is a natural onboarding flow:

```
First time:   /studio  →  /eye  →  /art
Training:     /studio  →  /train  →  /art (with new LoRA)
Day-to-day:   /art (everything else already configured)
```

`/studio` is the entry point. `/eye` builds over time. `/art` is the most-used command. `/train` is used when you need a new LoRA.

## 7. Data Flow

### 7.1 Generation Flow (`/art`)

```
User: "I need a mascot"
         │
         ▼
    Read grimoire/eye.md ─── aesthetic preferences
    Read grimoire/studio.md ── available models/LoRAs
    Read grimoire/library/ ─── similar proven prompts
         │
         ▼
    Craft prompt (model-specific syntax)
    Present to user: "Here's what I'd send. [Approve/Adjust]"
         │
         ▼ (on approve)
    Check ComfyUI availability (grimoire/studio.md → API endpoint)
         │
    ┌────┴────┐
    │ API up  │ API down │
    │         │          │
    ▼         ▼          │
  Submit    Present      │
  workflow  prompt for   │
  via API   manual use   │
    │         │          │
    ▼         ▼          │
  Pull     User reports  │
  results  feedback      │
    │         │          │
    └────┬────┘
         ▼
    "How did it turn out?" [Approve / Adjust / Start over]
         │
    ┌────┴──────────┐
    │ Adjust        │ Approve
    │               │
    ▼               ▼
  Modify prompt   Export (resize, format, optimize)
  Re-generate     Log to grimoire/library/
    │              Update grimoire/eye.md (if pattern detected)
    └── (loop) ──┘
```

### 7.2 Training Flow (`/train`)

```
User: "I want to train a LoRA of my art style"
         │
         ▼
    GATE 1: Dataset Preparation
    ├── Collect images → workspace/datasets/{name}/
    ├── Run dataset-audit.sh (resolution, format, corruption)
    ├── Run find-duplicates.sh (perceptual hash + similarity)
    ├── Claude vision: caption each image (content + style)
    ├── User reviews sample captions
    ├── Generate dataset-report.md
    └── GO/NO-GO decision
         │ (GO)
         ▼
    GATE 2: Configuration
    ├── Read grimoire/studio.md for available GPU/VRAM
    ├── Select training backend (kohya/SimpleTuner/ai-toolkit)
    ├── Generate config via backend adapter
    ├── Run calculate-vram.sh for batch size
    ├── Present config with plain-language explanations
    └── User confirms
         │ (confirmed)
         ▼
    GATE 3: Environment Validation
    ├── Run validate-environment.sh on target machine
    │   ├── GPU detection
    │   ├── CUDA version check
    │   ├── PyTorch install (pinned to CUDA version)
    │   ├── Training backend install
    │   ├── VRAM headroom check
    │   └── Disk space check
    ├── Generate environment.md
    └── All checks green?
         │ (green)
         ▼
    GATE 4: Dry Run
    ├── Load model + dataset (no training)
    ├── Verify initialization succeeds
    └── No errors?
         │ (clean)
         ▼
    TRAINING
    ├── Launch via launch-training.sh (with OOM recovery)
    ├── Monitor via monitor-training.sh
    ├── Save checkpoints at intervals
    └── Training completes
         │
         ▼
    EVALUATION
    ├── Generate test images at weights 0.5, 0.7, 0.9, 1.0
    ├── Present to user with original art comparison
    ├── "Does this capture what you wanted?"
    └── Register in grimoire/studio.md if approved
```

## 8. File System Layout

### 8.1 Complete Project Structure

```
ategnatos/
├── .claude/
│   ├── commands/
│   │   ├── studio.md
│   │   ├── art.md
│   │   ├── train.md
│   │   └── eye.md
│   ├── skills/
│   │   ├── studio/
│   │   │   ├── index.yaml
│   │   │   ├── SKILL.md
│   │   │   └── resources/
│   │   │       ├── providers/
│   │   │       ├── comfyui/
│   │   │       ├── models/
│   │   │       └── cuda-compat.md
│   │   ├── art/
│   │   │   ├── index.yaml
│   │   │   ├── SKILL.md
│   │   │   └── resources/
│   │   │       ├── prompting/
│   │   │       ├── formats/
│   │   │       └── feedback-mapping.md
│   │   ├── train/
│   │   │   ├── index.yaml
│   │   │   ├── SKILL.md
│   │   │   └── resources/
│   │   │       ├── dataset/
│   │   │       ├── training/
│   │   │       ├── backends/
│   │   │       ├── environment/
│   │   │       └── evaluation/
│   │   └── eye/
│   │       ├── index.yaml
│   │       ├── SKILL.md
│   │       └── resources/
│   │           └── categories.md
│   ├── scripts/
│   │   ├── studio/
│   │   ├── train/
│   │   └── art/
│   └── rules/                      # Optional constraint files
│       └── cost-protection.md  # Never bill without confirmation
├── grimoire/
│   ├── studio.md
│   ├── eye.md
│   ├── library/
│   ├── training/
│   ├── workflows/
│   └── projects/
├── workspace/
│   ├── datasets/
│   ├── outputs/
│   └── configs/
├── exports/
├── gumi/                           # User's directory
├── CLAUDE.md
├── .gitignore
└── README.md                       # Project readme (generated when ready)
```

### 8.2 .gitignore

```gitignore
# Large files — never commit
workspace/datasets/*/
workspace/outputs/
exports/
*.safetensors
*.ckpt
*.pt
*.bin

# Sensitive
.env
*.pem

# OS
.DS_Store
Thumbs.db

# Temporary
*.tmp
*.log
```

## 9. Security & Cost Protection

### 9.1 Cost Protection Rule

```
.claude/rules/cost-protection.md
```

A framework-level rule that applies to ALL skills:

- **NEVER** start a GPU instance without showing cost estimate and getting confirmation
- **NEVER** launch training without all 4 gates passing
- **ALWAYS** suggest teardown when GPU work completes
- **ALWAYS** warn about running instances that may be billing

### 9.2 No Credentials in State

- GPU provider API keys: user's environment variables, never stored in grimoire
- ComfyUI API: local/remote endpoint stored in studio.md, no auth tokens
- No secrets in any committed file

## 10. Development Workflow

### 10.1 Implementation Order

Recommended sprint sequence based on dependencies:

```
Sprint 1: Foundation
  - CLAUDE.md, grimoire structure, .gitignore
  - /eye skill (simplest, no external deps)
  - /studio skill (environment detection only, no provider lifecycle yet)

Sprint 2: Generation Pipeline
  - /art skill (prompt crafting, iteration, export)
  - ComfyUI integration scripts
  - /studio ComfyUI management
  - Prompt reference data for major model families

Sprint 3: Training Pipeline — Dataset
  - /train dataset preparation (audit, dedup, captioning)
  - Dataset validation scripts
  - Style-aware captioning via Claude vision

Sprint 4: Training Pipeline — Execution
  - /train configuration and environment validation
  - Training backend adapters (kohya first)
  - Launch, monitor, OOM recovery scripts
  - /studio GPU provider lifecycle

Sprint 5: Training Pipeline — Evaluation
  - /train evaluation workflow
  - LoRA registration into studio.md
  - Failure mode diagnosis
  - Connect trained LoRA to /art for immediate use

Sprint 6: Polish & Reference Data
  - Complete provider guides
  - Complete model database
  - CUDA compatibility matrix
  - Preset training profiles
  - Cross-command integration testing
```

### 10.2 Testing Strategy

Since this is a skill-based framework (markdown + shell scripts), testing is:

1. **Script testing**: Each shell script has basic input/output tests
2. **Workflow testing**: End-to-end test of each command's workflow with mock data
3. **Reference data validation**: Ensure all links work, compatibility matrices are current
4. **Integration testing**: Verify ComfyUI API interaction with a test instance

## 11. Technical Risks & Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| ComfyUI workflow JSON format changes | Templates break | Version-pin templates, test against ComfyUI releases |
| Training tool CLI changes | Backend adapters break | Each adapter is isolated; one breaking doesn't affect others |
| New model architectures (SD4, Flux 2, etc.) | Prompt syntax guides outdated | Model-agnostic design; new models = new resource file, not new code |
| CUDA/PyTorch version matrix grows | Environment validation stale | Maintain as structured data, update with releases |
| Claude vision captioning quality | Style descriptions may miss nuance | Human review gate ensures quality; improve over time |

## 12. Future Considerations

| Feature | Architecture Impact | When |
|---------|--------------------|------|
| Style Intelligence integration | New skill (`analyze`) that orchestrates the Gradio app | v2.0 |
| Batch generation queues | New script for queuing multiple ComfyUI jobs | v1.x |
| Team taste sharing | Export/import mechanism for eye.md | v1.x |
| ComfyUI workflow marketplace | Resource file expansion, possible download script | v2.0 |
| Video generation (SVD, etc.) | New workflow templates, new evaluation methodology | v3.0 |

---

## Cycle 2 Addendum — Hardening & Functional Completeness

**Date**: 2026-02-11
**Source PRD**: grimoires/loa/prd.md v2.0

### C2.1 New Scripts

#### `dry-run.sh` (Gate 4 completion)

```
.claude/scripts/train/dry-run.sh
```

Interface:
```bash
dry-run.sh --config <path> --backend <backend> [--steps 5] [--json]
```

Behavior:
1. Reads training config to determine backend, model path, dataset path
2. Invokes the backend's training command with `--max_train_steps=N` (2-5)
3. Captures stdout/stderr, watches for OOM, CUDA errors, missing file errors
4. Reports: pass (exit 0) with VRAM snapshot, or fail (exit 1) with diagnosis
5. On OOM: suggests reduced batch size. On missing file: reports which file. On CUDA error: references `cuda-pytorch-matrix.md`

Backend dispatch:
- kohya: `accelerate launch train_network.py ... --max_train_steps=5`
- simpletuner: Modify config `max_train_steps`, run normally
- ai-toolkit: Modify YAML `steps`, run normally

#### `structure-dataset.sh` (Kohya folder structuring)

```
.claude/scripts/train/structure-dataset.sh
```

Interface:
```bash
structure-dataset.sh --input <flat_dir> --output <kohya_dir> --name <concept> --repeats <N> [--json]
```

Behavior:
1. Validates input directory has images + matching .txt captions
2. Creates `{repeats}_{name}/` directory structure
3. Copies/moves images and captions into structured directory
4. Auto-calculates repeats if `--repeats auto`: `repeats = ceil(target_steps / (image_count * epochs))`
5. For multi-concept: `--concepts "3_style,5_reg"` creates multiple subdirectories

#### `workflow-manage.sh` (Workflow template management)

```
.claude/scripts/studio/workflow-manage.sh
```

Interface:
```bash
workflow-manage.sh save <name> <workflow.json>     # Save to grimoire/workflows/
workflow-manage.sh list                             # List built-in + user workflows
workflow-manage.sh get <name>                       # Output workflow JSON
workflow-manage.sh delete <name>                    # Remove user workflow
```

Sources: built-in templates from `resources/comfyui/templates/` + user workflows from `grimoire/workflows/`

#### `state-lib.sh` (Structured state library)

```
.claude/scripts/lib/state-lib.sh
```

Functions:
```bash
source .claude/scripts/lib/state-lib.sh

state_init "studio"                    # Initialize grimoire/.state/studio.json if not exists
state_get "studio" ".environment.cuda" # Read a value (jq path)
state_set "studio" ".environment.cuda" '"12.4"'  # Set a value
state_append "studio" ".models" '{...}'           # Append to array
state_remove "studio" ".active_instances" "id" "12345"  # Remove from array by key
state_sync "studio"                    # Regenerate grimoire/studio.md from JSON
state_migrate "studio"                 # Parse existing studio.md into JSON (one-time)
```

JSON schema for `grimoire/.state/studio.json`:
```json
{
  "environment": {
    "primary": "string",
    "cuda": "string",
    "comfyui": { "host": "string", "port": "number", "status": "string" }
  },
  "models": [
    { "name": "string", "type": "string", "base": "string", "good_for": "string", "location": "string", "settings": "string" }
  ],
  "loras": [
    { "name": "string", "trigger": "string", "weight_range": "string", "trained_on": "string", "location": "string" }
  ],
  "active_instances": [
    { "id": "string", "provider": "string", "gpu": "string", "cost_hr": "string", "started": "string", "status": "string" }
  ]
}
```

### C2.2 New Workflow Templates

```
.claude/skills/studio/resources/comfyui/templates/
├── txt2img-sdxl.json        # (existing)
├── txt2img-flux.json         # (existing)
├── lora-test.json            # (existing)
├── img2img-sdxl.json         # NEW — source image + prompt
├── img2img-flux.json         # NEW — source image + prompt (Flux)
├── controlnet-sdxl.json      # NEW — control image + prompt
├── upscale-esrgan.json       # NEW — ESRGAN 4x upscale
└── batch-variations.json     # NEW — batch_size parameter for N variations
```

### C2.3 Updated Script Interfaces

**`comfyui-submit.sh`** — Add `--upload` flag for img2img/ControlNet:
```bash
comfyui-submit.sh <workflow.json> [--host HOST] [--port PORT] [--upload <image>] [--json]
```
When `--upload` is provided, the script POSTs the image to ComfyUI's `/upload/image` endpoint first, then substitutes the returned filename into the workflow JSON before submitting.

**`export-asset.sh`** — Add upscale support:
```bash
export-asset.sh <input> <output> [--width W] [--height H] [--format png|webp|jpg] [--upscale 2x|4x] [--json]
```
Upscale logic: if ComfyUI running → submit upscale workflow. If not → fallback to ImageMagick `convert -resize`.

**`dataset-audit.sh`** — Add Kohya format detection:
```bash
dataset-audit.sh <directory> [--json]
# Now reports: "Dataset format: flat" or "Dataset format: kohya ({repeats}_{name})"
# Adds recommendation: "Run structure-dataset.sh to restructure for Kohya"
```

### C2.4 Train SKILL.md Split

New structure:
```
.claude/skills/train/
├── index.yaml
├── SKILL.md                            # Reduced: role, rules, state files, reference table
└── resources/
    ├── workflows/
    │   ├── dataset-workflow.md          # Phases 1-6
    │   ├── execution-workflow.md        # Phases 7-10
    │   └── evaluation-workflow.md       # Phases 11-13
    ├── dataset/                         # (existing)
    ├── training/                        # (existing)
    ├── backends/                        # (existing)
    ├── environment/                     # (existing)
    └── evaluation/                      # (existing)
```

### C2.5 CUDA Compatibility Consolidation

Canonical file: `.claude/skills/train/resources/environment/cuda-pytorch-matrix.md`

Replacement file at `.claude/skills/studio/resources/cuda-compat.md`:
```markdown
# CUDA Compatibility

For the full CUDA ↔ PyTorch ↔ Driver compatibility matrix, see:
`../../../train/resources/environment/cuda-pytorch-matrix.md`

This file is the single source of truth for all CUDA compatibility information.
```

### C2.6 Test Framework

```
tests/
├── run-all.sh                  # Runner: executes all test files, reports summary
├── test-scripts-help.sh        # Verify all scripts accept --help without error
├── test-comfyui-mock.sh        # Mock ComfyUI server + test submit/poll
├── test-dataset-pipeline.sh    # Sample images → audit → dedup → structure
├── test-state-lib.sh           # State init/get/set/append/remove/sync
├── test-eval-grid-args.sh      # Verify eval-grid.sh calls scripts correctly
├── fixtures/
│   ├── sample-images/          # 5 small test images
│   ├── sample-workflow.json    # Valid ComfyUI workflow
│   └── sample-config.toml      # Valid training config
└── lib/
    └── test-helpers.sh         # assert_eq, assert_file_exists, mock helpers
```

### C2.7 Updated File System Layout

Additions to the Cycle 1 layout:

```
ategnatos/
├── grimoire/
│   ├── .state/                 # NEW — structured state backing
│   │   └── studio.json
│   └── workflows/              # NOW POPULATED — user-saved workflows
├── tests/                      # NEW — integration test framework
│   ├── run-all.sh
│   ├── test-*.sh
│   ├── fixtures/
│   └── lib/
├── .claude/
│   ├── scripts/
│   │   ├── lib/
│   │   │   └── state-lib.sh   # NEW — state management library
│   │   ├── studio/
│   │   │   └── workflow-manage.sh  # NEW
│   │   └── train/
│   │       ├── dry-run.sh      # NEW
│   │       └── structure-dataset.sh  # NEW
│   └── skills/
│       └── train/
│           └── resources/
│               └── workflows/  # NEW — extracted from SKILL.md
│                   ├── dataset-workflow.md
│                   ├── execution-workflow.md
│                   └── evaluation-workflow.md
```

---

## Cycle 3 Addendum — Security, Resilience & Operational Maturity

**Date**: 2026-02-12
**Source PRD**: grimoires/loa/prd.md v3.0
**Source**: Flatline Protocol adversarial review (GPT-5.2 + Claude Opus 4.6)

### C3.1 Security Architecture

#### Input Validation Library (`validate-lib.sh`)

```
.claude/scripts/lib/validate-lib.sh
```

Functions:
```bash
source .claude/scripts/lib/validate-lib.sh

validate_path <path>                    # Rejects: .., symlink escapes, null bytes
validate_url <url>                      # Rejects: non-http(s), credentials in URL
validate_url_localhost <url>            # Requires: 127.0.0.1 or localhost
validate_provider_id <id>              # Allowlist: vast, runpod, lambda, local
validate_backend_id <id>               # Allowlist: kohya, simpletuner, ai-toolkit
validate_positive_int <value>          # Rejects: non-numeric, negative, zero
validate_json_file <path>              # Validates: exists, valid JSON, no eval-able content
```

Design:
- All functions return 0 (valid) or 1 (invalid) with stderr message
- Allowlists are hardcoded constants, not configurable (prevents injection via config)
- Path validation uses `realpath` to resolve symlinks, rejects paths outside project root
- URL validation uses bash pattern matching, no external commands

#### Secrets Library (`secrets-lib.sh`)

```
.claude/scripts/lib/secrets-lib.sh
```

Functions:
```bash
source .claude/scripts/lib/secrets-lib.sh

load_secret <name>                     # Load from env var, then ~/.config/ategnatos/secrets
redact_log <text>                      # Mask patterns: sk-*, ssh-*, API keys, tokens
safe_log <text>                        # Alias: echo "$(redact_log "$text")" >&2
```

Secret resolution order:
1. Environment variable (e.g., `VASTAI_API_KEY`)
2. `~/.config/ategnatos/secrets` file (format: `KEY=value`, perms 0600)
3. Fail with clear message: "Secret 'VASTAI_API_KEY' not found. Set it as an env var or add to ~/.config/ategnatos/secrets"

Redaction patterns:
```
sk-[A-Za-z0-9]{10,}     → sk-***<last4>
ssh-[a-z]{3,}\s+\S+     → ssh-***REDACTED
[A-Za-z0-9]{32,}        → (only if preceded by key/token/secret/password context)
```

#### ComfyUI Security Gate (`comfyui-security-check.sh`)

```
.claude/scripts/studio/comfyui-security-check.sh
```

Interface:
```bash
comfyui-security-check.sh --url <endpoint> [--allow-remote] [--json]
```

Checks:
1. Parse URL → extract host
2. If host is `127.0.0.1`, `localhost`, or `::1` → PASS
3. If host is private IP (10.x, 172.16-31.x, 192.168.x) → WARN (likely OK but not guaranteed)
4. If host is public IP → FAIL unless `--allow-remote`
5. If `--allow-remote`, verify SSH tunnel is active (check for `ssh -L` process targeting that port)

Integration: `comfyui-submit.sh` calls this before every submission. `--skip-security` flag available for advanced users.

#### Hardened Scripting Standard

Document: `.claude/skills/studio/resources/scripting-standard.md`

Rules enforced:
1. `set -euo pipefail` on line 2 of every script
2. All variables double-quoted: `"$var"` not `$var`
3. No `eval`, no `source` of untrusted files
4. External input validated via `validate-lib.sh` before use
5. Array expansion: `"${array[@]}"` not `${array[*]}`
6. Temporary files via `mktemp` with trap cleanup
7. shellcheck clean at default warning level
8. `# shellcheck disable=SCXXXX` requires inline justification comment

### C3.2 State Architecture (Revised)

#### Authority Model

```
JSON (canonical) → Markdown (generated view, read-only)
```

The Cycle 2 `state_migrate` function is deprecated for normal use. It remains as a one-time migration tool with a prominent warning.

#### Enhanced `state-lib.sh`

New/modified functions:
```bash
state_sync "studio"                    # Now adds <!-- GENERATED --> header + source hash
state_check "studio"                   # Compares MD hash vs JSON hash, returns drift status
state_backup "studio"                  # Copies JSON + MD to .bak with timestamp
state_schema_version "studio"          # Returns _schema_version from JSON
```

`state_sync` output format:
```markdown
<!-- GENERATED — DO NOT EDIT. Source: grimoire/.state/studio.json (hash: a1b2c3d4) -->
<!-- Use /studio to modify. Manual edits will be overwritten. -->

# Studio

## Environment
...
```

`state_check` behavior:
1. Read hash from MD header comment
2. Compute current hash of JSON file (`shasum -a 256`)
3. If match → return 0 ("in sync")
4. If mismatch → return 1 ("drift detected") with details
5. Skills call `state_check` at start and warn user if drift detected

#### Schema Versioning

```json
{
  "_schema_version": "1.0",
  "_generated_at": "2026-02-12T12:00:00Z",
  "environment": { ... },
  "models": [ ... ],
  "loras": [ ... ],
  "active_instances": [ ... ]
}
```

Migration path: if `_schema_version` is missing or < current, run migration function before proceeding.

### C3.3 Resource Contention

#### Lock Library (`resource-lock.sh`)

```
.claude/scripts/lib/resource-lock.sh
```

Functions:
```bash
source .claude/scripts/lib/resource-lock.sh

lock_acquire <resource> [--timeout 30] [--holder "art"]  # Create advisory lock
lock_release <resource>                                    # Release lock
lock_check <resource>                                      # Check status (JSON)
lock_force_release <resource>                              # Force release (admin)
```

Lock file format: `/tmp/ategnatos-lock-<resource_hash>.lock`
```json
{
  "resource": "comfyui:localhost:8188",
  "holder": "art",
  "pid": 12345,
  "acquired_at": "2026-02-12T12:00:00Z"
}
```

Stale detection: if PID in lockfile is not running (`kill -0 $pid`), auto-release and log warning.

Resource naming convention:
- `comfyui:<host>:<port>` — ComfyUI endpoint
- `gpu:<provider>:<instance_id>` — GPU instance
- `training:<run_id>` — Training run

### C3.4 Cost Enforcement

#### Cost Guard (`cost-guard.sh`)

```
.claude/scripts/lib/cost-guard.sh
```

Configuration file: `grimoire/cost-config.json`
```json
{
  "max_hourly_rate": 3.00,
  "max_total_cost": 50.00,
  "max_runtime_minutes": 480,
  "auto_teardown_minutes": 60,
  "require_confirm": true
}
```

Functions:
```bash
source .claude/scripts/lib/cost-guard.sh

cost_check --operation train --estimated 5.00     # Check against budget
cost_start_timer --resource vast-123 --max-minutes 120  # Start watchdog timer
cost_stop_timer --resource vast-123               # Stop timer
cost_teardown_overdue                             # Check all timers, warn/teardown
cost_report                                        # Show current spend summary
```

Timer storage: `/tmp/ategnatos-cost-timer-<resource_hash>.json`

Integration: all billable scripts (`provider-spinup.sh`, `launch-training.sh`) call `cost_check` and `cost_start_timer`.

### C3.5 SSH Resilience

#### SSH Execution Library (`ssh-lib.sh`)

```
.claude/scripts/lib/ssh-lib.sh
```

Functions:
```bash
source .claude/scripts/lib/ssh-lib.sh

ssh_exec <host> <command> [--retries 3] [--backoff-base 5]  # Execute with retry
ssh_tmux_create <host> <session_name>                        # Create persistent tmux session
ssh_tmux_send <host> <session_name> <command>                # Send command to tmux
ssh_tmux_attach <host> <session_name>                        # Attach to tmux
ssh_phase_mark <host> <phase_name>                           # Write phase marker
ssh_phase_check <host> <phase_name>                          # Check if phase completed
ssh_reconnect_status <host>                                  # Read all phase markers
```

Phase markers: `~/.ategnatos-phases/<phase_name>.done` on remote host.

Retry behavior: exponential backoff (5s, 10s, 20s) with connection timeout of 10s per attempt.

### C3.6 Training Recovery

#### Enhanced `monitor-training.sh`

New checks added to monitoring loop:
1. **Disk space**: `df -h <training_dir>` — warn at 90%, abort at 95%
2. **Checkpoint integrity**: verify file size > 0, file not still being written (flock check)
3. **Process health**: verify training PID is still running
4. **VRAM usage**: log peak VRAM per checkpoint interval

#### Training State (`training-state.json`)

```json
{
  "run_id": "train-20260212-120000",
  "backend": "kohya",
  "config_path": "workspace/configs/mystyle.toml",
  "dataset_path": "workspace/datasets/mystyle/",
  "output_dir": "workspace/training/mystyle/",
  "status": "running",
  "started_at": "2026-02-12T12:00:00Z",
  "last_checkpoint": "workspace/training/mystyle/epoch-10.safetensors",
  "last_checkpoint_at": "2026-02-12T12:30:00Z",
  "total_steps": 1500,
  "completed_steps": 750,
  "provider": "vast",
  "instance_id": "12345"
}
```

Written by `launch-training.sh` at start, updated by `monitor-training.sh` at each checkpoint.

Resume command construction per backend:
- **Kohya**: `--network_weights <last_checkpoint> --initial_epoch <epoch>`
- **SimpleTuner**: `--resume_from_checkpoint <last_checkpoint>`
- **AI-Toolkit**: restart with same config (auto-detects latest checkpoint in output dir)

### C3.7 ComfyUI Preflight

#### Node Validation (`comfyui-preflight.sh`)

```
.claude/scripts/studio/comfyui-preflight.sh
```

Interface:
```bash
comfyui-preflight.sh --workflow <path.json> --url <endpoint> [--json]
```

Behavior:
1. Query ComfyUI `/object_info` → get list of installed node types
2. Parse workflow JSON → extract all `class_type` values
3. Compare: installed ∩ required → report missing
4. Look up missing nodes in `resources/comfyui/node-registry.md` → provide install instructions
5. Exit 0 if all nodes present, exit 1 if missing

#### Node Registry (`node-registry.md`)

```
.claude/skills/studio/resources/comfyui/node-registry.md
```

Format:
```markdown
| Node Class | Package | Install Command | Notes |
|-----------|---------|----------------|-------|
| ControlNetApplyAdvanced | comfyui_controlnet_aux | cd custom_nodes && git clone ... | Required for ControlNet workflows |
| UpscaleModelLoader | built-in | N/A | Included with ComfyUI |
```

### C3.8 New File System Additions

```
ategnatos/
├── .claude/
│   ├── scripts/
│   │   ├── lib/
│   │   │   ├── state-lib.sh           # (enhanced: state_check, state_backup, schema version)
│   │   │   ├── validate-lib.sh        # NEW — input validation
│   │   │   ├── secrets-lib.sh         # NEW — secret loading + log redaction
│   │   │   ├── resource-lock.sh       # NEW — advisory lock mechanism
│   │   │   ├── cost-guard.sh          # NEW — budget enforcement
│   │   │   └── ssh-lib.sh             # NEW — SSH resilience
│   │   └── studio/
│   │       ├── comfyui-security-check.sh  # NEW — endpoint security gate
│   │       └── comfyui-preflight.sh       # NEW — node validation
│   └── skills/
│       └── studio/
│           └── resources/
│               ├── comfyui/
│               │   ├── security.md         # NEW — hardening guide
│               │   ├── compatibility.md    # NEW — version requirements
│               │   └── node-registry.md    # NEW — node → package mapping
│               ├── providers/
│               │   └── provider-contract.md  # NEW — provider interface spec
│               └── scripting-standard.md    # NEW — hardened scripting rules
├── grimoire/
│   ├── cost-config.json               # NEW — budget limits
│   └── .state/
│       └── studio.json                # (enhanced: _schema_version, _generated_at)
└── tests/
    ├── test-validate-lib.sh           # NEW
    ├── test-secrets-lib.sh            # NEW
    ├── test-resource-lock.sh          # NEW
    ├── test-cost-guard.sh             # NEW
    └── test-comfyui-preflight.sh      # NEW
```

### C3.9 Security Threat Model

| Threat | Vector | Mitigation | Component |
|--------|--------|------------|-----------|
| Command injection via filenames | Malicious image filenames with shell metacharacters | `validate_path()` + strict quoting | validate-lib.sh |
| Credential leak in logs | API keys echoed during provider operations | `redact_log()` wraps all logging | secrets-lib.sh |
| Unauthenticated ComfyUI access | Public IP endpoint on cloud GPU | Localhost-only default + security check | comfyui-security-check.sh |
| Runaway GPU billing | Forgotten instances, crashed sessions | Auto-teardown timer + billing watchdog | cost-guard.sh |
| Corrupted training state | Partial writes, disk full, SSH drop | Atomic writes + checkpoint validation | state-lib.sh, monitor-training.sh |
| Resource contention | /art + /train hit same GPU | Advisory locks with stale detection | resource-lock.sh |

---

*SDD updated for Cycle 3. Addendum covers security hardening, state architecture resolution, resource contention, cost enforcement, SSH resilience, training recovery, and ComfyUI operational improvements.*
