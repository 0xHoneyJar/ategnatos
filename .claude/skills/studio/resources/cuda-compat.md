# CUDA Compatibility Reference

## In Plain Language
Your GPU (the chip that generates images) needs three software layers to work together: the NVIDIA driver (talks to the hardware), CUDA (lets AI software use the GPU), and PyTorch (the framework AI models run on). If any of these are the wrong version, training won't start. This reference tells you exactly which versions are compatible and gives you the exact commands to install them. See `glossary.md` for full definitions.

## What You Need to Know

### Version Matrix

| CUDA | PyTorch 2.0.x | PyTorch 2.1.x | PyTorch 2.2.x | PyTorch 2.3.x | PyTorch 2.4.x | PyTorch 2.5.x |
|------|:---:|:---:|:---:|:---:|:---:|:---:|
| 11.7 | Yes | No | No | No | No | No |
| 11.8 | Yes | Yes | Yes | Yes | No | No |
| 12.1 | No | Yes | Yes | Yes | Yes | No |
| 12.4 | No | No | No | No | Yes | Yes |
| 12.6 | No | No | No | No | No | Yes |

### Install Commands

#### CUDA 11.8 (Legacy — widest compatibility)
```bash
# PyTorch 2.3.x (latest for CUDA 11.8)
pip install torch==2.3.1+cu118 torchvision==0.18.1+cu118 --index-url https://download.pytorch.org/whl/cu118

# PyTorch 2.1.x
pip install torch==2.1.2+cu118 torchvision==0.16.2+cu118 --index-url https://download.pytorch.org/whl/cu118
```

#### CUDA 12.1 (Recommended — good balance)
```bash
# PyTorch 2.4.x (latest for CUDA 12.1)
pip install torch==2.4.1+cu121 torchvision==0.19.1+cu121 --index-url https://download.pytorch.org/whl/cu121

# PyTorch 2.3.x
pip install torch==2.3.1+cu121 torchvision==0.18.1+cu121 --index-url https://download.pytorch.org/whl/cu121
```

#### CUDA 12.4 (Current)
```bash
# PyTorch 2.5.x
pip install torch==2.5.1+cu124 torchvision==0.20.1+cu124 --index-url https://download.pytorch.org/whl/cu124

# PyTorch 2.4.x
pip install torch==2.4.1+cu124 torchvision==0.19.1+cu124 --index-url https://download.pytorch.org/whl/cu124
```

#### CUDA 12.6 (Latest)
```bash
# PyTorch 2.5.x
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu126
```

### Driver Requirements

| CUDA Version | Minimum NVIDIA Driver | Recommended |
|-------------|----------------------|-------------|
| 11.7 | 515.43+ | 535.x+ |
| 11.8 | 520.61+ | 535.x+ |
| 12.1 | 530.30+ | 535.x+ |
| 12.4 | 550.54+ | 550.x+ |
| 12.6 | 560.28+ | 560.x+ |

### How to Check Your Setup

```bash
# Step 1: What GPU and driver do you have?
nvidia-smi
# Look for: Driver Version and CUDA Version (this is the max CUDA your driver supports)

# Step 2: What CUDA toolkit is installed?
nvcc --version
# Look for: release X.Y

# Step 3: What PyTorch and CUDA does it see?
python3 -c "import torch; print(f'PyTorch {torch.__version__}'); print(f'CUDA: {torch.version.cuda}'); print(f'GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"None\"}')"
```

### Known Issues and Workarounds

| Issue | CUDA Versions | Workaround |
|-------|--------------|------------|
| xformers build fails | 11.7, early 12.x | Use pre-built: `pip install xformers` (matches PyTorch version) |
| bf16 not supported | Older GPUs (pre-Ampere) | Use `fp16` instead of `bf16` in training config |
| Flash Attention fails | CUDA < 12.1 on some GPUs | Install `flash-attn` separately or disable |
| SDPA not available | PyTorch < 2.0 | Upgrade PyTorch to 2.0+ |
| "CUDA out of memory" on startup | Any | Not a version issue — reduce batch size |

### Cloud GPU CUDA Versions

| Provider | Typical CUDA | Notes |
|----------|-------------|-------|
| Vast.ai | Varies (11.8-12.4) | Check before renting; filter by `cuda_vers>=12.1` |
| RunPod | 12.1-12.4 (managed templates) | PyTorch templates are pre-configured |
| Lambda | Latest (12.4-12.6) | Always up to date |

### Apple Silicon (No CUDA)

Apple Silicon Macs use MPS instead of CUDA:
```bash
# Verify MPS works
python3 -c "import torch; print(torch.backends.mps.is_available())"
# Should print: True

# Install PyTorch for MPS (no CUDA suffix needed)
pip install torch torchvision
```

MPS does not need CUDA, drivers, or any NVIDIA software. It uses Apple's Metal framework directly.

## Why This Matters
A CUDA/PyTorch version mismatch is the #1 reason training fails to start. Getting the right combination installed takes 5 minutes with the right command. Getting it wrong means hours of debugging cryptic error messages. Always check this matrix first.

## Sources
- [PyTorch Install Guide](https://pytorch.org/get-started/locally/)
- [PyTorch Previous Versions](https://pytorch.org/get-started/previous-versions/)
- [NVIDIA CUDA Toolkit Archive](https://developer.nvidia.com/cuda-toolkit-archive)
- [NVIDIA Driver Downloads](https://www.nvidia.com/Download/index.aspx)
