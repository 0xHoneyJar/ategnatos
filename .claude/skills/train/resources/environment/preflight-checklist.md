# Pre-Flight Checklist

## In Plain Language
This is the step-by-step procedure that runs before any GPU time is spent. Every check must pass. If any check fails, you get a specific error message with exact fix instructions. No guessing, no debugging in the dark.

## What You Need to Know

### The Checklist

#### 1. GPU Detection
- [ ] GPU is detected and identified
- [ ] GPU model name and VRAM are known
- [ ] For NVIDIA: driver version is sufficient
- [ ] For Apple Silicon: MPS backend is available

**If this fails**: "No GPU detected. Training requires a GPU. Options: install NVIDIA drivers, or use a cloud GPU provider (see /studio)."

#### 2. CUDA Compatibility
- [ ] CUDA runtime version detected
- [ ] CUDA version is compatible with installed PyTorch
- [ ] No version conflicts between system CUDA and PyTorch CUDA

**If this fails**: "CUDA [X.Y] detected but PyTorch was built for CUDA [A.B]. Fix: `pip install torch==2.X.X+cuXYZ -f https://download.pytorch.org/whl/cuXYZ`"

#### 3. PyTorch Verification
- [ ] PyTorch is installed
- [ ] PyTorch can access the GPU (`torch.cuda.is_available()` or `torch.backends.mps.is_available()`)
- [ ] PyTorch version is compatible with training backend

**If this fails**: "PyTorch cannot access the GPU. This usually means a CUDA version mismatch. [Specific install command based on detected CUDA]"

#### 4. Training Backend
- [ ] Selected backend (kohya/SimpleTuner/ai-toolkit) is installed
- [ ] Required dependencies are present (accelerate for kohya, etc.)
- [ ] Backend can import successfully

**If this fails**: "[Backend] not found. Install: `git clone [repo URL] && pip install -r requirements.txt`"

#### 5. VRAM Headroom
- [ ] Available VRAM >= estimated requirement (from calculate-vram.sh)
- [ ] 20% safety margin maintained
- [ ] If close to limit: suggest VRAM-saving options

**If this fails**: "Need [X] GB VRAM but GPU has [Y] GB. Options: reduce batch size to [N], reduce rank to [N], or use a larger GPU."

#### 6. Disk Space
- [ ] At least 10 GB free for checkpoints and intermediate files
- [ ] 20+ GB recommended for comfortable operation
- [ ] Space for: model copy + latent cache + checkpoints + final LoRA

**If this fails**: "Only [X] GB disk space available. Need at least 10 GB. Free up space or use a larger volume."

#### 7. Dataset Access
- [ ] Dataset directory exists and is readable
- [ ] Images are accessible (no permission issues)
- [ ] Caption files exist alongside images

**If this fails**: "Cannot read dataset at [path]. Check permissions or path."

### Running the Checklist

```bash
.claude/scripts/train/validate-environment.sh --backend kohya --vram-need 12
```

### Re-Running After Fixes

The checklist is idempotent — safe to run again after fixing issues. It doesn't modify anything; it only reads and reports.

### After SSH Drops

If your SSH connection drops during environment setup:
1. Reconnect
2. Re-run the checklist — it will pick up where things stand
3. No state is lost; no cleanup needed

## Why This Matters
Every failed check has a specific fix with exact commands. No "something went wrong, try again" — you always know exactly what's broken and how to fix it.
