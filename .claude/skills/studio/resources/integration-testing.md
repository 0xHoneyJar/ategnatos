# Cross-Command Integration Testing

## In Plain Language
Ategnatos has four commands that share state through grimoire files. This document describes how to test that everything works together — from setting up your environment to generating art with a custom-trained LoRA.

## What You Need to Know

### Shared State Files

| File | Written By | Read By | What It Stores |
|------|-----------|---------|----------------|
| `grimoire/eye.md` | `/eye` | `/art`, `/train` | Aesthetic preferences |
| `grimoire/studio.md` | `/studio`, `/train` (LoRA registration) | `/art`, `/train`, `/studio` | Environment, models, LoRAs, instances |
| `grimoire/library/` | `/art` | `/art` | Successful prompt history |
| `grimoire/training/{name}/` | `/train` | `/train` | Training project state |
| `grimoire/projects/` | `/art` | `/art` | Project context and history |

### Write Ownership Rules

Each file has exactly one writer (except studio.md which has two controlled writers):

- Only `/eye` writes to `grimoire/eye.md`
- Only `/studio` writes to `grimoire/studio.md` (environment, models, instances)
- Only `/train` writes to `grimoire/studio.md` (LoRA registration via Phase 13)
- Only `/art` writes to `grimoire/library/` and `grimoire/projects/`
- Only `/train` writes to `grimoire/training/`

No command should ever write to another command's files outside these rules.

---

## Workflow 1: Generation Pipeline

**Path**: `/studio` → `/eye` → `/art` → iterate → export

### Step 1: Studio Setup

```
/studio
```

**Verify**:
- [ ] `grimoire/studio.md` → Environment section populated with GPU/ComfyUI info
- [ ] Models table has at least one entry
- [ ] Plain-language summary shown to user

### Step 2: Set Preferences

```
/eye
"I like warm earth tones, painterly textures, and dramatic lighting"
"I avoid flat vector styles"
"I never want photorealistic faces"
```

**Verify**:
- [ ] `grimoire/eye.md` → Color section has warm earth tones preference
- [ ] Texture section has painterly textures
- [ ] Anti-Preferences → Avoid has flat vector
- [ ] Anti-Preferences → Never has photorealistic faces
- [ ] Each preference has `[confirmed: 1 session]`

### Step 3: Generate Art

```
/art
"Create a mascot character for a coffee brand"
```

**Verify**:
- [ ] `/art` reads `grimoire/eye.md` — warm earth tones reflected in prompt
- [ ] `/art` reads `grimoire/studio.md` — correct model selected
- [ ] Negative prompt includes "flat vector" (from Avoid) and "photorealistic face" (from Never)
- [ ] If LoRA available in studio.md, trigger word included where relevant
- [ ] Prompt presented with plain-language explanation before generation
- [ ] Model-specific syntax used (booru tags for Pony/SDXL, natural language for Flux)

### Step 4: Iterate

```
"More contrast in the shadows"
"Try it with a different pose"
```

**Verify**:
- [ ] Previous prompt context preserved
- [ ] Modifications applied incrementally (not restarting from scratch)
- [ ] Eye preferences still applied

### Step 5: Export

```
"This one is great, save it"
```

**Verify**:
- [ ] Export to `exports/` directory
- [ ] Prompt saved to `grimoire/library/` for future reference
- [ ] Library entry includes: prompt, model, settings, and outcome description

---

## Workflow 2: Training Pipeline

**Path**: `/studio` → `/train` (dataset → config → validate → train → evaluate → register) → `/art` with new LoRA

### Step 1: Studio Setup

```
/studio
```

(Same as Workflow 1 — environment must be configured before training.)

### Step 2: Training Intent

```
/train
"I want to train a style LoRA based on my watercolor paintings"
```

**Verify**:
- [ ] `/train` reads `grimoire/eye.md` — preferences inform captioning style
- [ ] `/train` reads `grimoire/studio.md` — knows available GPU and VRAM
- [ ] Intent file created at `grimoire/training/{name}/intent.md`
- [ ] Training type, base model, trigger word, dataset size set

### Step 3: Dataset Preparation

**Verify**:
- [ ] `dataset-audit.sh` runs and produces plain-language report
- [ ] `find-duplicates.sh` detects duplicates with actionable output
- [ ] Style-aware captions describe both content AND technique
- [ ] Trigger word prepended to all captions
- [ ] 5 sample captions presented for approval before batch captioning
- [ ] Gate 1 report in `grimoire/training/{name}/dataset-report.md`
- [ ] GO/NO-GO recommendation is clear

### Step 4: Configuration (Gate 2)

**Verify**:
- [ ] `generate-config.sh` produces valid config for selected backend
- [ ] `calculate-vram.sh` estimates VRAM correctly for GPU from studio.md
- [ ] Preset selection (Quick/Standard/Thorough) with plain-language explanation
- [ ] Config presented with every parameter explained
- [ ] Config saved to `grimoire/training/{name}/config.md`

### Step 5: Environment Validation (Gate 3)

**Verify**:
- [ ] `validate-environment.sh` checks GPU, CUDA, PyTorch, disk space, backend
- [ ] On failure: specific error with exact fix commands
- [ ] Snapshot saved to `grimoire/training/{name}/environment.md`
- [ ] References `cuda-compat.md` for version compatibility

### Step 6: Dry Run (Gate 4)

**Verify**:
- [ ] Short test run (2-5 steps) completes without error
- [ ] Model loads correctly with configured LoRA parameters
- [ ] Dataset accessible (all images and captions)
- [ ] Clear GO/NO-GO before real training

### Step 7: Training

**Verify**:
- [ ] `launch-training.sh` starts training with correct backend and config
- [ ] `monitor-training.sh` tracks progress (epoch, loss, VRAM, ETA)
- [ ] OOM recovery triggers automatically (halve batch, retry up to 3x)
- [ ] Checkpoints saved at configured intervals
- [ ] Progress in `grimoire/training/{name}/progress.md`

### Step 8: Evaluation

**Verify**:
- [ ] `eval-grid.sh` generates images at weights 0.3, 0.5, 0.7, 0.9, 1.0
- [ ] Fixed seed used for fair comparison
- [ ] Results in `grimoire/training/{name}/eval.md`
- [ ] Checkpoint comparison available
- [ ] Failure diagnosis available if results are unsatisfactory

### Step 9: LoRA Registration

```
"This LoRA looks great, approve it"
```

**Verify**:
- [ ] LoRA added to `grimoire/studio.md` → LoRAs table
- [ ] Record includes: trigger word, weight range, description, training params
- [ ] LoRA immediately available to `/art`

### Step 10: Use New LoRA in Art

```
/art
"Create a character portrait using my watercolor style"
```

**Verify**:
- [ ] `/art` reads `grimoire/studio.md` and sees the new LoRA
- [ ] Trigger word automatically included in prompt
- [ ] Recommended weight applied
- [ ] Output reflects the trained style

---

## State Integrity Checks

### Interleaved Command Usage

Commands may be used in any order. Verify no state corruption:

| Scenario | What to Check |
|----------|--------------|
| `/eye` during `/art` session | eye.md updates preserved, art session can continue |
| `/studio` during `/train` session | studio.md environment update doesn't corrupt training project state |
| `/art` after `/train` registers LoRA | New LoRA appears in next `/art` prompt crafting |
| Multiple `/train` projects | Each project's state is isolated in `grimoire/training/{name}/` |

### Session Persistence

| State | Where Stored | Survives Session? |
|-------|-------------|-------------------|
| Eye preferences | `grimoire/eye.md` | Yes |
| Studio environment | `grimoire/studio.md` | Yes |
| Model inventory | `grimoire/studio.md` | Yes |
| LoRA inventory | `grimoire/studio.md` | Yes |
| Prompt library | `grimoire/library/` | Yes |
| Training projects | `grimoire/training/` | Yes |
| Active instances | `grimoire/studio.md` | Yes (manual tracking) |

### Error Recovery

| Failure | Expected Behavior |
|---------|------------------|
| ComfyUI not running | `/art` falls back to prompt-only mode (no generation) |
| No GPU detected | `/studio` suggests cloud providers, `/train` blocks at Gate 3 |
| Missing eye.md | `/art` works without preferences (warns user to run `/eye`) |
| Missing studio.md | `/art` and `/train` prompt user to run `/studio` first |
| Training interrupted (SSH drop) | Resume from last checkpoint, state in grimoire preserved |
| Corrupt training config | Gate 2 catches and reports specific fix |

## Why This Matters
The four commands form a connected workflow. If state sharing breaks, an artist's preferences don't appear in their prompts, a trained LoRA doesn't show up for generation, or a training session can't find the GPU. Testing these connections end-to-end ensures the framework works as a cohesive tool, not four disconnected scripts.
