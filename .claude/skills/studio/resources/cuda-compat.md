# CUDA Compatibility

## Canonical Reference

For the full CUDA/PyTorch/Driver compatibility matrix, install commands, driver requirements, known issues, and cloud GPU CUDA versions, see the single source of truth:

**Read** `.claude/skills/train/resources/environment/cuda-pytorch-matrix.md`

That file is maintained as the canonical reference for all CUDA compatibility information, used by both `/studio` and `/train`.

## Quick Check

```bash
# What GPU and driver do you have?
nvidia-smi

# What CUDA toolkit is installed?
nvcc --version

# What does PyTorch see?
python3 -c "import torch; print(f'PyTorch {torch.__version__}, CUDA: {torch.version.cuda}, GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"None\"}')"
```

## Apple Silicon (No CUDA)

Apple Silicon Macs use MPS instead of CUDA — no NVIDIA software needed:
```bash
python3 -c "import torch; print(torch.backends.mps.is_available())"
pip install torch torchvision  # No CUDA suffix needed
```
