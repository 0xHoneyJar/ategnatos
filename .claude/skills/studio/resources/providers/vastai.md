# Vast.ai Provider Guide

## In Plain Language
Vast.ai is a marketplace where people rent out their GPUs. It's usually the cheapest option because you're renting from individuals, not datacenters. The trade-off: availability varies and some machines are more reliable than others.

## What You Need to Know

### Instance Types

| Type | What It Means | Best For |
|------|--------------|----------|
| **On-demand** | Dedicated reservation, won't be interrupted | Production training, long sessions |
| **Interruptible** (spot) | Cheaper but host can reclaim anytime | Quick experiments, testing |
| **Bid** | You set your max price, may not get filled | When you can wait for a deal |

For LoRA training, **on-demand** is recommended. Training sessions are short enough that the small cost difference isn't worth the risk of interruption.

### Pricing Tiers

| GPU | VRAM | Typical $/hr | Good For |
|-----|------|-------------|----------|
| RTX 3090 | 24 GB | $0.15-0.30 | SDXL LoRA (best value) |
| RTX 4090 | 24 GB | $0.30-0.50 | SDXL + Flux LoRA |
| A5000 | 24 GB | $0.25-0.45 | Reliable SDXL training |
| A6000 | 48 GB | $0.50-0.80 | Flux LoRA (comfortable VRAM) |
| A100 40GB | 40 GB | $0.80-1.50 | Flux LoRA + large batch |
| A100 80GB | 80 GB | $1.20-2.00 | Everything (overkill for most LoRAs) |

*Prices fluctuate based on supply and demand.*

### Setup

1. **Create account** at vast.ai
2. **Install CLI**: `pip install vastai`
3. **Set API key**: `vastai set api-key YOUR_KEY`
4. **Add SSH key** in Account → SSH Keys (required for connection)

### Template Selection

Templates are pre-built environments with CUDA, PyTorch, and tools already installed.

| Template | CUDA | PyTorch | Notes |
|----------|------|---------|-------|
| `pytorch/pytorch:2.4.1-cuda12.1-cudnn9-devel` | 12.1 | 2.4 | Recommended default |
| `pytorch/pytorch:2.5.1-cuda12.4-cudnn9-devel` | 12.4 | 2.5 | Newest stack |
| Custom | Varies | Varies | Upload your own Docker image |

**Recommendation**: Use the PyTorch template matching your target CUDA version. This avoids spending 15 minutes installing PyTorch after SSH-ing in.

### Recommended Instance Search

```bash
# Find reliable RTX 3090 for SDXL LoRA training
vastai search offers 'gpu_name=RTX_3090 num_gpus=1 cuda_vers>=12.1 reliability>0.95 dph<=0.50 disk_space>=50.0' -o 'dph'

# Find A100 for Flux LoRA training
vastai search offers 'gpu_name=A100 num_gpus=1 cuda_vers>=12.1 dph<=2.00 disk_space>=80.0' -o 'dph'

# Find any 24GB+ GPU under $0.40/hr
vastai search offers 'gpu_ram>=24 num_gpus=1 cuda_vers>=12.1 reliability>0.95 dph<=0.40 disk_space>=50.0' -o 'dph'
```

### Key Selection Criteria

| Criterion | What to Look For | Why |
|-----------|-----------------|-----|
| Reliability | > 95% | Lower means the machine crashes or disappears more often |
| CUDA version | >= 12.1 | Older CUDA won't work with modern PyTorch |
| Disk space | >= 50 GB | Model (~7 GB) + dataset + checkpoints + cache need room |
| Internet speed | >= 100 Mbps | Faster upload of your dataset and download of results |
| Docker template | PyTorch 2.x with CUDA | Pre-configured environment saves setup time |

### SSH Access

```bash
# Get SSH connection info
vastai ssh-url INSTANCE_ID
# Typically: ssh -p PORT root@IP_ADDRESS

# Connect with key
ssh -p PORT -i ~/.ssh/your_key root@IP_ADDRESS
```

### SSH Tunneling for ComfyUI

If you want to run ComfyUI on the remote GPU and access its UI locally:

```bash
# Forward remote port 8188 (ComfyUI) to local port 8188
ssh -p PORT -L 8188:localhost:8188 root@IP_ADDRESS

# Then open in your browser:
# http://localhost:8188
```

This lets you use ComfyUI's web interface as if it were running on your own machine, while all the GPU work happens on the rented instance.

### File Transfer

```bash
# Upload dataset
scp -P PORT -r ./dataset/ root@IP:/workspace/dataset/

# Download trained LoRA
scp -P PORT root@IP:/workspace/output/my_lora.safetensors ./

# For large transfers, rsync is faster (resumes on failure)
rsync -avz -e "ssh -p PORT" ./dataset/ root@IP:/workspace/dataset/
```

### Common Gotchas

1. **Instance disappears**: Host can terminate interruptible instances. Use on-demand for training, or save checkpoints every few epochs.
2. **Slow internet**: Some hosts have slow upload. Check bandwidth in the search results before renting.
3. **Old CUDA**: Some machines run outdated CUDA. Always filter `cuda_vers>=12.1` in your search.
4. **Disk full**: `/tmp` and HuggingFace cache fill up fast. Monitor with `df -h` and clear cache: `rm -rf ~/.cache/huggingface/hub/*`.
5. **SSH drops**: Always run training inside `tmux` or `screen` so it continues if your connection drops.
6. **Wrong template**: If the template lacks CUDA or PyTorch, you'll waste time installing. Double-check the template before renting.
7. **Forgot to teardown**: Your meter is running. Set a timer on your phone. We'll remind you too.

## Why This Matters
Vast.ai gives you access to powerful GPUs at the lowest cost, but the marketplace model means quality varies. Following this guide — filtering for reliability, using the right template, and monitoring your instance — keeps you from wasting money on bad machines.

## Sources
- [Vast.ai Documentation](https://vast.ai/docs/)
- [Vast.ai CLI Reference](https://vast.ai/docs/cli/commands)
