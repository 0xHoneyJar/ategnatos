# Ategnatos Cycle 2 — Sprint Plan

**Version**: 2.0
**Date**: 2026-02-11
**Source PRD**: grimoires/loa/prd.md v2.0
**Source SDD**: grimoires/loa/sdd.md (Cycle 2 Addendum)
**Cycle**: 2 — Hardening & Functional Completeness

---

## Overview

| Parameter | Value |
|-----------|-------|
| Team | 1 human (Creative Director) + AI (Claude Code) |
| Sprint count | 4 |
| Sprint duration | Flexible — milestone-based |
| Scope | Bug fixes, architectural completions, doc cleanup, infrastructure |
| Total tasks | 22 |

### Sprint Dependency Chain

```
Sprint 1: Bug Fixes & Quick Wins
         │
         ├── Sprint 2: Training Pipeline Completeness
         │
         ├── Sprint 3: Generation Pipeline Expansion
         │
         └── Sprint 4: Infrastructure & Testing (depends on 1-3)
```

Sprints 2 and 3 can run in parallel after Sprint 1. Sprint 4 depends on all prior sprints.

---

## Sprint 1 (Global #7): Bug Fixes & Quick Wins

**Label**: Bug Fixes & Quick Wins
**Goal**: Fix all known bugs and clean up documentation inconsistencies. Zero known defects after this sprint.

### Tasks

#### S1-T1: Fix eval-grid.sh ComfyUI script calls
**PRD Ref**: BUG-001
**File**: `.claude/scripts/train/eval-grid.sh` (lines 251-255)

**Current (broken)**:
```bash
PROMPT_ID=$("$STUDIO_SCRIPTS/comfyui-submit.sh" --workflow "$WORKFLOW_FILE" --url "$COMFYUI_URL" --json ...)
"$STUDIO_SCRIPTS/comfyui-poll.sh" --id "$PROMPT_ID" --url "$COMFYUI_URL" --output "$out_dir" --timeout 120
```

**Fix**: Parse `COMFYUI_URL` into host/port. Use positional args:
```bash
# Extract host:port from URL
COMFYUI_HOST=$(echo "$COMFYUI_URL" | sed 's|http://||' | cut -d: -f1)
COMFYUI_PORT=$(echo "$COMFYUI_URL" | sed 's|http://||' | cut -d: -f2)

PROMPT_ID=$("$STUDIO_SCRIPTS/comfyui-submit.sh" "$WORKFLOW_FILE" --host "$COMFYUI_HOST" --port "$COMFYUI_PORT" --json ...)
"$STUDIO_SCRIPTS/comfyui-poll.sh" "$PROMPT_ID" --host "$COMFYUI_HOST" --port "$COMFYUI_PORT" --output "$out_dir" --timeout 120
```

**Acceptance Criteria**: eval-grid.sh calls match comfyui-submit.sh and comfyui-poll.sh documented interfaces exactly.

---

#### S1-T2: Fix vastai-lifecycle.sh grep -oP portability
**PRD Ref**: BUG-002
**File**: `.claude/scripts/studio/providers/vastai-lifecycle.sh` (lines 250-251)

**Current (macOS-incompatible)**:
```bash
port=$(echo "$ssh_url" | grep -oP '(?<=-p )\d+')
ip=$(echo "$ssh_url" | grep -oP '[^@\s]+$')
```

**Fix**: Use sed (POSIX-compatible):
```bash
port=$(echo "$ssh_url" | sed -n 's/.*-p \([0-9]*\).*/\1/p')
ip=$(echo "$ssh_url" | sed -n 's/.*@\([^ ]*\)$/\1/p')
```

**Acceptance Criteria**: `do_pull()` function works on macOS BSD grep. No `grep -P` anywhere in codebase.

---

#### S1-T3: Remove sprint labels from train SKILL.md
**PRD Ref**: BUG-003
**File**: `.claude/skills/train/SKILL.md`

**Current**:
```
## Workflow — Dataset Phase (Sprint 3)
## Workflow — Execution Phase (Sprint 4)
## Workflow — Evaluation Phase (Sprint 5)
```

**Fix**:
```
## Workflow — Dataset Phase
## Workflow — Execution Phase
## Workflow — Evaluation Phase
```

**Acceptance Criteria**: Zero "(Sprint N)" text in any user-facing file.

---

#### S1-T4: Consolidate CUDA compatibility files
**PRD Ref**: DOC-001
**Files**: `.claude/skills/studio/resources/cuda-compat.md`, `.claude/skills/train/resources/environment/cuda-pytorch-matrix.md`

**Fix**: Replace `cuda-compat.md` content with a redirect:
```markdown
# CUDA Compatibility

For the full CUDA/PyTorch/Driver compatibility matrix, see the canonical reference:

→ Read `.claude/skills/train/resources/environment/cuda-pytorch-matrix.md`

That file is the single source of truth for all CUDA compatibility information,
used by both `/studio` and `/train`.
```

**Acceptance Criteria**: One canonical CUDA file. Studio references it. No duplicated data.

---

#### S1-T5: Resolve Lambda Cloud provider status
**PRD Ref**: DOC-002
**Files**: `.claude/scripts/studio/provider-spinup.sh`, `.claude/skills/studio/resources/providers/provider-guide.md`, `.claude/skills/studio/resources/providers/lambda.md`

**Fixes**:
1. `provider-spinup.sh` line 128-131: Change error message from implying Lambda is broken to explaining it's manual-only
2. `provider-guide.md`: Mark Lambda as "Manual Only — no CLI automation"
3. `lambda.md`: Document the manual workflow (web dashboard → SSH → use provider-validate.sh)

**Acceptance Criteria**: Lambda clearly documented as manual-only. No suggestion it's "unsupported" — it's supported, just not automated.

---

### Sprint 1 Success Criteria
- All 3 bugs verified fixed
- CUDA files consolidated
- Lambda status clear
- `grep -oP` gone from entire codebase

---

## Sprint 2 (Global #8): Training Pipeline Completeness

**Label**: Training Pipeline Completeness
**Goal**: Complete the training toolchain — Gate 4 script, dataset structuring, SKILL.md restructure, model database docs.

### Tasks

#### S2-T1: Create dry-run.sh for Gate 4
**PRD Ref**: ARCH-001
**New file**: `.claude/scripts/train/dry-run.sh`

**Interface**:
```bash
dry-run.sh --config <path> --backend <kohya|simpletuner|ai-toolkit> [--steps 5] [--json]
```

**Behavior**:
1. Read config to get model path, dataset path, LoRA parameters
2. Per backend:
   - kohya: `accelerate launch train_network.py ... --max_train_steps=5`
   - simpletuner: Modify config `max_train_steps`, run
   - ai-toolkit: Modify YAML `steps`, run
3. Capture stdout/stderr
4. On success (exit 0): report VRAM peak, time taken
5. On failure (exit 1): categorize error (OOM, CUDA, missing file, config) and suggest fix

**Acceptance Criteria**: Script accepts all 3 backends. Reports pass/fail with actionable diagnosis. Exits cleanly on all error paths.

---

#### S2-T2: Create structure-dataset.sh for Kohya folders
**PRD Ref**: ARCH-005
**New file**: `.claude/scripts/train/structure-dataset.sh`

**Interface**:
```bash
structure-dataset.sh --input <flat_dir> --output <kohya_dir> --name <concept> [--repeats <N|auto>] [--epochs 15] [--target-steps 1500] [--json]
```

**Behavior**:
1. Validate input dir has images + matching .txt caption files
2. Create `<output>/<repeats>_<name>/` directory
3. Copy images + captions into structured directory
4. Auto-calculate repeats when `--repeats auto`:
   - `repeats = ceil(target_steps / (image_count * epochs))`
   - Example: 25 images, 15 epochs, 1500 target steps → `repeats = ceil(1500 / (25 * 15)) = 4`
5. Report: "Created 4_mystyle/ with 25 images (4 repeats × 25 images × 15 epochs = 1,500 steps)"

**Acceptance Criteria**: Creates valid Kohya folder structure. Auto-calc matches formula. Preserves caption file pairing.

---

#### S2-T3: Update dataset-audit.sh with Kohya format detection
**PRD Ref**: ARCH-005
**File**: `.claude/scripts/train/dataset-audit.sh`

**Addition**: After existing checks, detect dataset format:
- Flat: all images in one directory
- Kohya: `{N}_{name}/` subdirectory pattern detected
- Mixed: some structure but incomplete

When flat format detected and kohya backend configured, suggest:
```
Dataset format: flat (all images in one directory)
For Kohya training, run: structure-dataset.sh --input <dir> --output <dir> --name <concept> --repeats auto
```

**Acceptance Criteria**: Format detection works for flat, kohya, and mixed. Suggestion only appears when relevant.

---

#### S2-T4: Split train SKILL.md into sub-documents
**PRD Ref**: DOC-003

**Restructure**:
1. Create `.claude/skills/train/resources/workflows/dataset-workflow.md` — extract Phases 1-6
2. Create `.claude/skills/train/resources/workflows/execution-workflow.md` — extract Phases 7-10
3. Create `.claude/skills/train/resources/workflows/evaluation-workflow.md` — extract Phases 11-13
4. Reduce `SKILL.md` to: role definition, state files, four gates table, rules, reference table, and read instructions pointing to sub-documents

**Acceptance Criteria**: SKILL.md under 200 lines. Sub-documents contain full workflow detail. No content lost in split.

---

#### S2-T5: Document custom model database extension
**PRD Ref**: DOC-004

**Updates**:
1. Studio SKILL.md: add "Adding a Model" workflow section
2. Clarify: `model-database.md` = built-in reference (framework-maintained)
3. Clarify: `grimoire/studio.md` Models table = user's registry (user-maintained)
4. Studio skill reads BOTH sources when recommending models

**Acceptance Criteria**: Clear documentation of which file to edit. Studio skill describes the "add model" workflow.

---

### Sprint 2 Success Criteria
- Gate 4 has a dedicated script (`dry-run.sh`)
- Kohya folder structuring automated
- Train SKILL.md manageable at <200 lines
- Model database extensibility documented

---

## Sprint 3 (Global #9): Generation Pipeline Expansion

**Label**: Generation Pipeline Expansion
**Goal**: Expand `/art` beyond txt2img — add img2img, ControlNet, batch generation, workflow management, upscaling.

### Tasks

#### S3-T1: Create img2img and ControlNet workflow templates
**PRD Ref**: ARCH-003

**New files**:
- `.claude/skills/studio/resources/comfyui/templates/img2img-sdxl.json`
- `.claude/skills/studio/resources/comfyui/templates/img2img-flux.json`
- `.claude/skills/studio/resources/comfyui/templates/controlnet-sdxl.json`

Each template: valid ComfyUI API JSON with LoadImage node for source/control image, documented input points for customization.

**Acceptance Criteria**: Templates are valid JSON. Input nodes clearly identified. LoadImage nodes reference uploadable filenames.

---

#### S3-T2: Add image upload to comfyui-submit.sh
**PRD Ref**: ARCH-003
**File**: `.claude/scripts/studio/comfyui-submit.sh`

**Addition**: `--upload <image>` flag:
1. POST image to `${BASE_URL}/upload/image`
2. Get returned filename from response
3. Substitute filename into workflow JSON (replace placeholder `INPUT_IMAGE`)
4. Then submit workflow as normal

**Acceptance Criteria**: Image upload works. Workflow JSON updated with server-side filename. Error handling for upload failures.

---

#### S3-T3: Update art SKILL.md for img2img and ControlNet
**PRD Ref**: ARCH-003
**File**: `.claude/skills/art/SKILL.md`

**Additions**:
1. Generation mode detection: "modify this image" → img2img, "use this for pose" → ControlNet, default → txt2img
2. For img2img: request source image, set denoise strength (explain in plain language)
3. For ControlNet: request control image, explain what ControlNet does ("uses the structure from one image to guide generation of another")
4. Workflow selection: reads correct template based on mode + model

**Acceptance Criteria**: Art skill recognizes all 3 generation modes. Each mode has clear workflow. Plain-language explanations for img2img strength and ControlNet.

---

#### S3-T4: Add batch generation support
**PRD Ref**: ARCH-004

**Changes**:
1. Art SKILL.md: "generate N variations" sets `batch_size` in workflow JSON
2. Art SKILL.md: "try these prompts" iterates over prompt list, submits each
3. Queue pattern: submit all workflows, collect prompt_ids, poll all, present results together
4. Results presented as numbered grid for comparison

**Acceptance Criteria**: "Generate 4 variations" produces 4 images. Multiple prompts each generate separately. Results presented together for comparison.

---

#### S3-T5: Create workflow-manage.sh
**PRD Ref**: ARCH-002
**New file**: `.claude/scripts/studio/workflow-manage.sh`

**Interface**:
```bash
workflow-manage.sh save <name> <workflow.json>     # Copy to grimoire/workflows/<name>.json
workflow-manage.sh list                             # List templates/ + grimoire/workflows/
workflow-manage.sh get <name>                       # Output workflow JSON to stdout
workflow-manage.sh delete <name>                    # Remove from grimoire/workflows/
```

**Sources**: built-in from `resources/comfyui/templates/` (read-only) + user-saved from `grimoire/workflows/` (read/write)

**Acceptance Criteria**: All 4 subcommands work. List shows both sources with [built-in] / [saved] labels. Can't delete built-in templates.

---

#### S3-T6: Integrate upscaling into export pipeline
**PRD Ref**: INFRA-003

**Changes**:
1. New template: `.claude/skills/studio/resources/comfyui/templates/upscale-esrgan.json`
2. Update `export-asset.sh`: add `--upscale 2x|4x` flag
   - If ComfyUI running: submit upscale workflow, poll, download
   - If not: fallback to ImageMagick `convert -resize`
3. Art SKILL.md: mention upscaling as export option
4. Train SKILL.md (dataset workflow): mention upscaling for low-res dataset images

**Acceptance Criteria**: `export-asset.sh --upscale 4x` works with both ComfyUI and ImageMagick fallback. Upscale template is valid JSON.

---

### Sprint 3 Success Criteria
- `/art` supports txt2img, img2img, and ControlNet
- Batch generation works for N variations and multiple prompts
- Workflow management (save/list/get/delete) functional
- Upscaling available for both export and dataset prep

---

## Sprint 4 (Global #10): Infrastructure & Testing

**Label**: Infrastructure & Testing
**Goal**: Add structured state backing for reliability and integration tests for verification.

### Tasks

#### S4-T1: Create state-lib.sh
**PRD Ref**: INFRA-001
**New file**: `.claude/scripts/lib/state-lib.sh`

**Functions**:
```bash
state_init <scope>                        # Create grimoire/.state/<scope>.json
state_get <scope> <jq_path>              # Read value
state_set <scope> <jq_path> <value>      # Set value
state_append <scope> <jq_path> <object>  # Append to array
state_remove <scope> <jq_path> <key> <value>  # Remove from array by key match
state_sync <scope>                        # Regenerate markdown from JSON
state_migrate <scope>                     # Parse existing markdown into JSON
```

Requires: `jq`

**Acceptance Criteria**: All functions work. `state_sync` produces valid markdown. `state_migrate` parses existing `studio.md` format.

---

#### S4-T2: Implement studio.json state backing
**PRD Ref**: INFRA-001

**Changes**:
1. Create `grimoire/.state/` directory
2. `state_init "studio"` creates `grimoire/.state/studio.json` with schema from SDD C2.1
3. `state_migrate "studio"` parses existing `grimoire/studio.md` into JSON
4. Update `provider-teardown.sh`: replace `sed` operations with `state_remove` + `state_sync`
5. `state_sync "studio"` regenerates `grimoire/studio.md` from JSON

**Acceptance Criteria**: `studio.md` generated from JSON matches original format. `provider-teardown.sh` no longer uses `sed` for state updates.

---

#### S4-T3: Create test framework runner
**PRD Ref**: INFRA-002
**New files**: `tests/run-all.sh`, `tests/lib/test-helpers.sh`

**test-helpers.sh functions**:
```bash
assert_eq <expected> <actual> <message>
assert_contains <haystack> <needle> <message>
assert_file_exists <path> <message>
assert_exit_code <expected> <command...>
test_start <name>
test_pass
test_fail <reason>
report_summary
```

**run-all.sh**: Discovers and runs all `tests/test-*.sh` files. Reports pass/fail count. Exits non-zero on any failure.

**Acceptance Criteria**: Runner discovers tests. Helpers provide clear assertion output. Summary shows pass/fail/total.

---

#### S4-T4: Create script help tests
**PRD Ref**: INFRA-002
**New file**: `tests/test-scripts-help.sh`

Tests every script in `.claude/scripts/` with `--help`:
- Verifies exit code 0
- Verifies output contains usage information
- Catches syntax errors in scripts

**Acceptance Criteria**: Every script passes `--help` test. No bash syntax errors.

---

#### S4-T5: Create dataset pipeline tests
**PRD Ref**: INFRA-002
**New files**: `tests/test-dataset-pipeline.sh`, `tests/fixtures/sample-images/` (5 small test images)

Tests:
1. `dataset-audit.sh` against sample images (checks format detection)
2. `find-duplicates.sh` against samples (at least 2 similar)
3. `structure-dataset.sh` creates Kohya folder format

**Acceptance Criteria**: All 3 pipeline scripts tested. Fixture images committed. Tests pass on clean checkout.

---

#### S4-T6: Create state-lib tests
**PRD Ref**: INFRA-002
**New file**: `tests/test-state-lib.sh`

Tests:
1. `state_init` creates JSON file
2. `state_set` / `state_get` round-trip
3. `state_append` adds to array
4. `state_remove` removes by key
5. `state_sync` produces markdown
6. `state_migrate` parses markdown

Uses temp directory — no side effects.

**Acceptance Criteria**: All state-lib functions tested. Tests clean up after themselves.

---

### Sprint 4 Success Criteria
- State updates via JSON (no more sed on markdown)
- Test suite passes on clean checkout
- Every script has at least a help test
- Dataset pipeline testable without real GPU

---

## Summary

| Sprint | Global ID | Label | Tasks | Priority |
|--------|-----------|-------|-------|----------|
| 1 | 7 | Bug Fixes & Quick Wins | 5 | P0 |
| 2 | 8 | Training Pipeline Completeness | 5 | P0 |
| 3 | 9 | Generation Pipeline Expansion | 6 | P0/P1 |
| 4 | 10 | Infrastructure & Testing | 6 | P1 |
| **Total** | | | **22** | |

---

*Sprint plan generated from PRD v2.0 and SDD Cycle 2 Addendum. 4 sprints, 22 tasks. Bugs first, then architectural gaps, then infrastructure.*
