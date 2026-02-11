# CUDA / PyTorch Compatibility Matrix

## In Plain Language
CUDA is NVIDIA's GPU programming toolkit. PyTorch is the ML framework that uses CUDA to run on GPUs. They must be compatible — wrong versions together means training won't start. This matrix tells you which versions work together.

## What You Need to Know

### Quick Lookup

| CUDA Version | PyTorch Versions | Install Command |
|-------------|-----------------|-----------------|
| CUDA 11.8 | 2.0.x - 2.3.x | `pip install torch==2.3.1+cu118 -f https://download.pytorch.org/whl/cu118` |
| CUDA 12.1 | 2.1.x - 2.4.x | `pip install torch==2.4.1+cu121 -f https://download.pytorch.org/whl/cu121` |
| CUDA 12.4 | 2.4.x+ | `pip install torch==2.4.1+cu124 -f https://download.pytorch.org/whl/cu124` |
| CUDA 12.6 | 2.5.x+ | `pip install torch -f https://download.pytorch.org/whl/cu126` |

### Driver Requirements

| CUDA Version | Minimum Driver | Recommended Driver |
|-------------|---------------|-------------------|
| CUDA 11.8 | 520.61+ | 535.x+ |
| CUDA 12.1 | 530.30+ | 535.x+ |
| CUDA 12.4 | 550.54+ | 550.x+ |
| CUDA 12.6 | 560.28+ | 560.x+ |

### How to Check Your Versions

```bash
# CUDA runtime version
nvcc --version

# NVIDIA driver version
nvidia-smi

# PyTorch version and CUDA it was built with
python3 -c "import torch; print(f'PyTorch {torch.__version__}, CUDA {torch.version.cuda}')"

# Verify GPU is accessible
python3 -c "import torch; print(f'GPU available: {torch.cuda.is_available()}')"
```

### Common Mismatches

| Symptom | Cause | Fix |
|---------|-------|-----|
| "CUDA not available" in PyTorch | PyTorch installed without CUDA | Reinstall with correct CUDA version |
| "CUDA error: no kernel image" | CUDA version mismatch | Match PyTorch CUDA to system CUDA |
| "Driver too old" | NVIDIA driver outdated | Update NVIDIA drivers |
| GPU works for inference but not training | Insufficient VRAM | Use smaller batch size or lower resolution |

### Apple Silicon (MPS)

Apple Silicon Macs don't use CUDA. They use MPS (Metal Performance Shaders):

```bash
# Check MPS availability
python3 -c "import torch; print(f'MPS available: {torch.backends.mps.is_available()}')"
```

**Limitations**: MPS training is slower than CUDA and some operations aren't supported. For serious training, a cloud GPU is recommended.

### Cloud GPU Pre-configured Environments

Most cloud providers offer pre-configured environments:
- **Vast.ai**: PyTorch templates with CUDA pre-installed
- **RunPod**: Managed PyTorch environments
- **Lambda**: Pre-configured with latest CUDA/PyTorch

When using cloud GPUs, prefer their managed environments to avoid version conflicts.

## Why This Matters
A CUDA/PyTorch mismatch is the most common "it won't start" error in ML training. This matrix prevents you from wasting time debugging version conflicts.

## Sources
- [PyTorch Previous Versions](https://pytorch.org/get-started/previous-versions/)
- [NVIDIA CUDA Toolkit Archive](https://developer.nvidia.com/cuda-toolkit-archive)
