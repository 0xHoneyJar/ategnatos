# Execution Workflow — Phases 7-10 (Gates 2-4 + Training)

This workflow configures training, validates the environment, runs a dry run, and executes training with safety nets.

## Phase 7: Training Configuration — Gate 2

1. **Determine training parameters** using `resources/training/parameters-guide.md`:
   - Learning rate, epochs, batch size, resolution, rank, alpha
   - Present each parameter with its plain-language explanation
   - Never use ML jargon without immediately explaining it

2. **Recommend an optimizer** using `resources/training/optimizers.md`:
   - Prodigy: "Set it and forget it — finds its own learning rate"
   - AdamW: "Industry standard — reliable but needs manual tuning"
   - Lion: "Memory-efficient — good when VRAM is tight"

3. **Start from a preset** using `resources/training/presets.md`:
   - Quick (5 epochs): "Fast test to see if your dataset works"
   - Standard (15 epochs): "Good balance of quality and speed"
   - Thorough (25 epochs): "Best results, takes longest"
   - Let the artist choose, then customize from there

4. **Estimate VRAM** using `.claude/scripts/train/calculate-vram.sh`:
   - Run: `calculate-vram.sh --model <base> --resolution <res> --batch <size> --rank <rank>`
   - Compare against available VRAM from `grimoire/studio.md`
   - Auto-reduce batch size if VRAM is tight (always keep 20% safety margin)

5. **Select backend** using adapter files in `resources/backends/`:
   - `kohya-adapter.md` — Most popular, best SDXL/Pony support
   - `simpletuner-adapter.md` — Best multi-aspect-ratio, good for Flux
   - `ai-toolkit-adapter.md` — Simplest config, lightweight

6. **Generate config** using `.claude/scripts/train/generate-config.sh`:
   - Run: `generate-config.sh --backend kohya --preset standard --model <base> ...`
   - Script outputs the backend-specific config file (TOML, .env, or YAML)
   - Present the generated config with explanations for user confirmation

7. **Save config** to `grimoire/training/{name}/config.md`:
   ```markdown
   # Training Config: {name}
   - **Backend**: kohya / simpletuner / ai-toolkit
   - **Base model**: {model}
   - **Preset**: Quick / Standard / Thorough
   - **Key parameters**: lr={lr}, epochs={epochs}, batch={batch}, rank={rank}
   - **Estimated VRAM**: {estimate} GB (available: {available} GB)
   - **Estimated time**: {time} on {gpu}
   - **Config file**: {path to generated config}
   ```

**Gate 2 Decision**: Config is valid if VRAM estimate fits available GPU with 20% margin and all parameters are within safe ranges.

## Phase 8: Environment Validation — Gate 3

1. **Run environment check** using `.claude/scripts/train/validate-environment.sh`:
   - Detects GPU, CUDA, PyTorch, training backend, VRAM, disk space
   - Run: `validate-environment.sh --backend kohya --model-size 6.5 --dataset-size 30 --json`
   - Idempotent — safe to re-run after SSH drops

2. **Review results in plain language**:
   - "Your RTX 4090 has 24 GB VRAM — plenty for this training"
   - "CUDA 12.1 and PyTorch 2.1 are compatible"
   - "You have 120 GB free disk — need about 45 GB for model + dataset + checkpoints"
   - Or: "Problem: PyTorch 2.1 needs CUDA 12.1 but you have CUDA 11.8. Fix: pip install torch==2.1.0+cu118"

3. **Reference files** when troubleshooting:
   - `resources/environment/cuda-pytorch-matrix.md` — version compatibility
   - `resources/environment/vram-calculator.md` — estimation methodology
   - `resources/environment/preflight-checklist.md` — step-by-step procedure

4. **Save environment snapshot** to `grimoire/training/{name}/environment.md`

**Gate 3 Decision**: Environment passes if GPU is detected, CUDA/PyTorch are compatible, VRAM is sufficient, disk space is adequate, and training backend is installed.

## Phase 9: Dry Run — Gate 4

1. **Execute a short test** using `.claude/scripts/train/dry-run.sh`:
   - Run: `dry-run.sh --config <path> --backend <backend> --steps 5`
   - Runs 2-5 actual training steps to verify the full pipeline
   - Catches initialization errors before real training starts

2. **Check for issues**:
   - Model loading failures → usually wrong model path or corrupted download
   - Caption parsing errors → usually encoding issues or missing files
   - OOM on first step → batch size too high, reduce and retry
   - CUDA errors → version mismatch (Gate 3 should have caught this)

3. **Report results**:
   - "Dry run passed — model loaded, 5 steps completed, no errors"
   - Or: "Dry run failed — {specific error with diagnosis and fix}"

**Gate 4 Decision**: Dry run passes if the model loads, dataset is accessible, and at least 2 training steps complete without error. This is the final GO before real training.

## Phase 10: Training Execution

1. **Final confirmation** before GPU time:
   - Summarize: dataset size, model, backend, estimated time, estimated cost
   - "Ready to train. This will take approximately 45 minutes on your RTX 4090."
   - For cloud: "This will cost approximately $0.35 at current rates."

2. **Launch training** using `.claude/scripts/train/launch-training.sh`:
   - Run: `launch-training.sh --config <path> --backend <backend> --output <dir>`
   - Script handles OOM detection and automatic batch size reduction
   - Up to 3 retry attempts with halved batch size on OOM
   - Each adjustment reported: "Hit memory limit — reducing batch size from 4 to 2 and retrying"

3. **Monitor progress** using `.claude/scripts/train/monitor-training.sh`:
   - Run: `monitor-training.sh --log <training.log> --epochs <total>`
   - Tracks: epoch progress, loss values, VRAM usage, estimated time remaining
   - Detects anomalies:
     - Loss plateau: "Loss hasn't changed in 5 epochs — model may have stopped learning"
     - Loss divergence: "Loss is increasing — something may be wrong"
     - Loss explosion: "Loss jumped to NaN — training has failed"

4. **Checkpoint management**:
   - Save checkpoints at configurable intervals (default: every 5 epochs)
   - Store in `grimoire/training/{name}/checkpoints/`
   - Keep last 3 checkpoints to save disk space

5. **Track progress** in `grimoire/training/{name}/progress.md`:
   ```markdown
   # Training Progress: {name}
   - **Status**: RUNNING / COMPLETE / FAILED
   - **Current epoch**: 12/25
   - **Loss**: 0.0234 (started: 0.0891)
   - **VRAM usage**: 18.2 / 24.0 GB
   - **Elapsed**: 23 min
   - **Estimated remaining**: 25 min
   - **Checkpoints**: epoch-5, epoch-10
   - **OOM recoveries**: 0
   ```

## Cloud GPU Workflow

When training on a cloud instance (via `/studio`):

1. **Spin up** using `.claude/scripts/studio/provider-spinup.sh`:
   - Choose provider (Vast.ai, RunPod) and GPU based on provider guides
   - Cost estimation before any spend
   - Instance recorded in `grimoire/studio.md`

2. **Validate** using `.claude/scripts/studio/provider-validate.sh`:
   - SSH connectivity, GPU, CUDA, PyTorch, disk space
   - Same checks as Gate 3, but on the remote instance

3. **Deploy and train**:
   - Transfer dataset to instance
   - Install training backend if needed
   - Run Gate 4 (dry run) on remote
   - Launch training

4. **Pull results**:
   - Download trained LoRA and checkpoints
   - Download training logs for analysis

5. **TEAR DOWN IMMEDIATELY** using `.claude/scripts/studio/provider-teardown.sh`:
   - Every minute costs money
   - Instance marked as TERMINATED in `grimoire/studio.md`
   - Always confirm teardown after training completes
