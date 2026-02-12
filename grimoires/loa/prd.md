# Ategnatos Cycle 2 — Hardening & Functional Completeness

**Version**: 2.0
**Date**: 2026-02-11
**Cycle**: 2
**Previous**: Cycle 1 — "Ategnatos v1.0 — AI Art Production Framework" (archived)
**Status**: Draft

---

## 1. Context

Cycle 1 delivered the complete framework architecture: all 4 skills (`/studio`, `/art`, `/train`, `/eye`), 18+ shell scripts, 36+ reference documentation files, grimoire schema, and command routing (~3,190 lines of scripts). However, the framework is not yet functional end-to-end — scripts have bugs, architectural gaps exist, and documentation needs cleanup.

This cycle focuses on **making what exists actually work** — fixing bugs, closing architectural gaps, cleaning up documentation, and adding the missing pieces that prevent real end-to-end workflows.

> Source: Post-Cycle 1 review feedback (15 items)

## 2. Goals

| Goal | Metric |
|------|--------|
| Zero known bugs in shipped scripts | All 3 identified bugs fixed, verified |
| Complete the script toolchain | All 4 training gates have dedicated scripts |
| Support non-txt2img workflows | img2img and ControlNet available in `/art` |
| Batch generation capability | `/art` can queue N variations in one pass |
| Automated dataset structuring | Kohya folder format created automatically |
| Single source of truth for CUDA/PyTorch compat | One file, cross-referenced |
| Clean user-facing documentation | Zero internal development labels visible |
| Structured state for reliability | JSON/YAML backing for fragile markdown state |
| Verifiable framework integrity | Integration test suite for pipeline validation |
| Image upscaling support | Available for dataset prep and post-export |

## 3. Requirements

### 3.1 Bug Fixes (P0)

#### BUG-001: eval-grid.sh argument mismatch with ComfyUI scripts
**Current**: `eval-grid.sh` calls `comfyui-submit.sh --workflow FILE --url URL --json` and `comfyui-poll.sh --id ID --url URL --output DIR --timeout N`
**Problem**: Both `comfyui-submit.sh` and `comfyui-poll.sh` expect positional arguments, not `--workflow`/`--id`/`--url` flags. `comfyui-submit.sh` takes `<workflow.json>` positional + `--host`/`--port` (not `--url`). `comfyui-poll.sh` takes `<prompt_id>` positional + `--host`/`--port`.
**Fix**: Update `eval-grid.sh` to parse `COMFYUI_URL` into host/port and call scripts with correct positional + flag pattern.

#### BUG-002: vastai-lifecycle.sh grep -oP on macOS
**Current**: Lines 250-251 use `grep -oP '(?<=-p )\d+'` and `grep -oP '[^@\s]+$'` (Perl regex)
**Problem**: macOS ships BSD grep which doesn't support `-P` flag. Framework claims macOS as primary platform.
**Fix**: Replace `grep -oP` with portable alternatives (`sed`, `awk`, or bash parameter expansion).

#### BUG-003: Sprint labels leaked into train SKILL.md
**Current**: Headers read "Workflow — Dataset Phase (Sprint 3)", "Workflow — Execution Phase (Sprint 4)", "Workflow — Evaluation Phase (Sprint 5)"
**Problem**: Internal development sprint labels visible to users. Confusing and unprofessional.
**Fix**: Remove "(Sprint N)" from all section headers. They should read "Workflow — Dataset Phase", "Workflow — Execution Phase", "Workflow — Evaluation Phase".

### 3.2 Architectural Completions (P0)

#### ARCH-001: Gate 4 dry-run script
**Current**: Gates 1-3 each have dedicated scripts (`dataset-audit.sh`, `generate-config.sh`/`calculate-vram.sh`, `validate-environment.sh`). Gate 4 has no script — the skill manually coordinates a short training run.
**Need**: `dry-run.sh` that runs 2-5 training steps with the configured backend, catches initialization errors, OOM, missing files, and reports pass/fail.
**Interface**: `dry-run.sh --config <path> --backend <backend> --steps 5 [--json]`

#### ARCH-002: Workflow template management
**Current**: 3 ComfyUI workflow templates exist in `resources/comfyui/templates/`. `grimoire/workflows/` exists but is empty with no save/load/modify tooling.
**Need**:
- Script to save current workflow to `grimoire/workflows/`
- Script to list available workflows (built-in templates + user-saved)
- Art skill can compose workflows from templates (add LoRA node, change sampler, add upscale step)
- Art skill documents how to save and reuse workflows

#### ARCH-003: img2img and ControlNet support
**Current**: Art skill is txt2img only. API reference mentions image upload capability.
**Need**:
- img2img workflow template (takes source image + prompt)
- ControlNet workflow template (takes control image + prompt)
- Art skill SKILL.md updated to support img2img and ControlNet generation modes
- `comfyui-submit.sh` updated to handle image upload when workflow references local images

#### ARCH-004: Batch generation
**Current**: Art skill generates one image at a time.
**Need**:
- Art skill supports "generate N variations" (batch_size parameter in workflow)
- Art skill supports "generate with these N prompts" (iterate over prompt list)
- Queue-style execution: submit all, poll all, present results together

#### ARCH-005: Kohya dataset folder structuring
**Current**: `kohya-adapter.md` documents the `{repeats}_{name}` folder requirement. Neither `dataset-audit.sh` nor `generate-config.sh` handles folder restructuring.
**Need**:
- `dataset-audit.sh` detects if dataset is in flat format vs Kohya format
- New `structure-dataset.sh` script that restructures a flat image directory into Kohya's `{repeats}_{name}/` format
- Calculates repeats based on dataset size and target steps
- Supports multi-concept datasets with subfolders

### 3.3 Documentation & Maintenance (P1)

#### DOC-001: Consolidate CUDA compatibility files
**Current**: `cuda-compat.md` (studio) and `cuda-pytorch-matrix.md` (train) overlap substantially.
**Fix**: Make `cuda-pytorch-matrix.md` the single canonical source. Replace `cuda-compat.md` with a short file that references it. Both skills read from one location.

#### DOC-002: Resolve Lambda Cloud status
**Current**: `provider-spinup.sh` explicitly rejects Lambda ("does not have a CLI"). Lambda is still listed in `provider-guide.md` as a supported provider.
**Fix**: Update `provider-guide.md` to mark Lambda as "manual only — no CLI automation." Add a `lambda.md` provider doc explaining the manual workflow (web dashboard + SSH). Remove Lambda from `provider-spinup.sh`'s error message suggesting it's supported.

#### DOC-003: Split train SKILL.md into sub-documents
**Current**: `train/SKILL.md` is ~500 lines covering all 13 phases.
**Fix**: Extract workflow phases into separate documents:
- `SKILL.md` — Role definition, rules, reference table (reduced to ~150 lines)
- `resources/workflows/dataset-workflow.md` — Phases 1-6 (Gate 1)
- `resources/workflows/execution-workflow.md` — Phases 7-10 (Gates 2-4 + training)
- `resources/workflows/evaluation-workflow.md` — Phases 11-13 (eval + registration)
- SKILL.md references these with "Read resources/workflows/dataset-workflow.md for the dataset phase"

#### DOC-004: Custom model database extension
**Current**: `model-database.md` is a static file. No mechanism for users to add models without editing the database directly.
**Need**:
- `grimoire/studio.md` "Models" table serves as the user's custom model registry
- `model-database.md` serves as the built-in reference (read-only for users)
- `/studio` skill reads BOTH sources: built-in database + grimoire models table
- `/studio` has an "add model" workflow that adds to `grimoire/studio.md`
- Clear documentation of which file to edit

### 3.4 Infrastructure Improvements (P1)

#### INFRA-001: Structured state backing for grimoire
**Current**: `provider-teardown.sh` uses `sed` to update `studio.md` markdown tables. Fragile — breaks on formatting changes.
**Need**:
- `grimoire/.state/studio.json` — structured backing store for `studio.md`
- Scripts read/write JSON, then a sync script regenerates the markdown view
- `grimoire/studio.md` remains human-readable but is now generated from JSON
- State update library: `state-lib.sh` with functions like `state_get`, `state_set`, `state_append`
- Applied initially to `studio.md` (highest churn). `eye.md` and training state can follow later.

#### INFRA-002: Integration test framework
**Current**: No way to verify the full pipeline works end-to-end on a clean system.
**Need**:
- `tests/` directory at project root
- `tests/test-scripts.sh` — runs each script with `--help` to verify syntax, dependencies
- `tests/test-comfyui-mock.sh` — mocks ComfyUI API for testing submit/poll
- `tests/test-dataset-pipeline.sh` — tests dataset audit + dedup + structuring with sample data
- `tests/test-state-lib.sh` — tests state read/write/sync
- Can be run via `bash tests/run-all.sh`

#### INFRA-003: Image upscaling integration
**Current**: Referenced in multiple docs as a solution but never implemented. Needed for both dataset prep (upscale low-res training images) and post-generation export (upscale for print/web).
**Need**:
- ComfyUI upscale workflow template (`templates/upscale.json` exists but isn't integrated)
- Art skill can upscale approved images as an export step
- Train skill can recommend upscaling for low-res dataset images
- `export-asset.sh` updated to support upscale via ComfyUI API (when available) or fallback to ImageMagick

## 4. Scope

### In Scope (Cycle 2)
- All 3 bug fixes
- All 5 architectural completions
- All 4 documentation cleanups
- All 3 infrastructure improvements

### Out of Scope
- Video/animation support
- Style Intelligence integration
- Team eye profile sharing
- Brand brief system
- New model architecture support (SD3, etc.)

## 5. Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| ComfyUI API changes between versions | Workflow templates may need updates | Test against stable ComfyUI release |
| Structured state migration | Existing grimoire data could be lost | Migration script validates before overwriting |
| Train SKILL.md split may lose context | Claude may not load all sub-documents | Test skill loading with sub-document references |

---

*PRD generated from post-Cycle 1 review feedback (15 items). All requirements trace directly to identified bugs, gaps, or improvements.*
