# Local GPU Guide

## In Plain Language
If you have an NVIDIA GPU in your computer, you can train LoRAs without paying for cloud services. This guide covers what's possible on consumer hardware and Apple Silicon.

## What You Need to Know

### NVIDIA Consumer GPUs

| GPU | VRAM | SDXL LoRA | Flux LoRA | Notes |
|-----|------|-----------|-----------|-------|
| RTX 3060 | 12 GB | Tight (rank 16, batch 1) | Not recommended | Budget option |
| RTX 3070 Ti | 8 GB | Not recommended | No | Insufficient VRAM |
| RTX 3080 | 10 GB | Tight (rank 16, batch 1) | No | Minimum viable |
| RTX 3090 | 24 GB | Comfortable | Tight (batch 1) | Best consumer option |
| RTX 4070 Ti | 12 GB | Possible (rank 16-32) | Not recommended | |
| RTX 4080 | 16 GB | Comfortable | Tight | |
| RTX 4090 | 24 GB | Comfortable | Possible | Best current consumer |

### Apple Silicon (MPS)

| Chip | Unified Memory | Training Feasibility |
|------|---------------|---------------------|
| M1 | 8-16 GB | Very limited (8 GB: no, 16 GB: maybe SDXL) |
| M2 | 8-24 GB | Limited (24 GB: SDXL possible, slow) |
| M3 | 8-36 GB | Possible (36 GB: SDXL comfortable, Flux tight) |
| M4 | 16-64 GB | Good (32+ GB: most training feasible, but slow) |
| M1/M2/M3/M4 Pro/Max/Ultra | 16-192 GB | VRAM not the issue — speed is |

**Key limitation**: MPS training is 3-5x slower than NVIDIA CUDA. A 30-minute CUDA training takes 1.5-2.5 hours on MPS. For serious training, cloud GPU is recommended.

### Local Setup Checklist

1. **NVIDIA GPU**:
   - Install latest NVIDIA drivers
   - Install CUDA toolkit (matching your driver)
   - Install PyTorch with correct CUDA version
   - Install training backend (kohya/SimpleTuner/ai-toolkit)

2. **Apple Silicon**:
   - Install PyTorch with MPS support (`pip install torch torchvision`)
   - Verify MPS: `python3 -c "import torch; print(torch.backends.mps.is_available())"`
   - Note: Not all training operations support MPS yet

### Advantages of Local Training

- **Free**: No per-hour costs
- **Fast iteration**: No upload/download of datasets
- **Always available**: No waiting for GPU availability
- **Privacy**: Your data stays on your machine

### Disadvantages

- **VRAM limited**: Consumer GPUs max at 24 GB
- **Slower**: Consumer GPUs train slower than datacenter GPUs
- **Power**: Training uses significant electricity
- **Heat/noise**: GPU runs at full load during training

### Common Gotchas

1. **CUDA version mismatch**: Your NVIDIA driver determines the maximum CUDA version. Check with `nvidia-smi` — the CUDA version shown is the max your driver supports.
2. **MPS not supported by all backends**: Some training tools don't fully support Apple's MPS. Check backend compatibility before starting.
3. **Fan noise**: GPU training runs at full load. Your computer will sound like a jet engine. Consider headphones or training overnight.
4. **Power draw**: A training RTX 3090 pulls 350W. On a small power supply, this can cause instability. Check your PSU rating.
5. **Thermal throttling**: If your GPU overheats, it slows down automatically. Ensure good airflow and monitor temps with `nvidia-smi`.
6. **System becomes sluggish**: Training uses all GPU resources. Don't expect to run games or heavy apps during training.

## Why This Matters
Local training is the fastest path from "I want to try LoRA training" to actually training. No account creation, no cost, no waiting. It's limited by hardware, but for SDXL LoRAs, most modern NVIDIA GPUs work fine.
