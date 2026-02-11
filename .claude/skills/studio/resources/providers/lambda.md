# Lambda Cloud Provider Guide

## In Plain Language
Lambda Cloud offers high-end GPUs (A100, H100) with a simple interface. It's pricier than Vast.ai or RunPod but offers datacenter-grade reliability and the cleanest setup experience. Best for when you need guaranteed performance or want zero setup hassle.

## What You Need to Know

### Pricing

| GPU | VRAM | $/hr | Best For |
|-----|------|------|----------|
| A10 | 24 GB | ~$0.60 | SDXL LoRA training (budget datacenter) |
| A100 (40 GB) | 40 GB | ~$1.10 | Flux LoRA training |
| A100 (80 GB) | 80 GB | ~$1.50 | Large models, big batch sizes |
| H100 (80 GB) | 80 GB | ~$2.50 | Maximum speed (overkill for most LoRAs) |

*All instances are on-demand. No spot/interruptible pricing.*

### Setup

1. **Create account** at lambdalabs.com
2. **Add SSH key** in Cloud → SSH Keys
3. **Launch instance** from Cloud → Instances → Launch
4. **SSH in**: `ssh ubuntu@INSTANCE_IP`

That's it. Lambda instances come ready to use.

### Pre-Configured Environment

Lambda instances include:
- Ubuntu + latest NVIDIA drivers
- CUDA toolkit (latest stable, usually 12.4+)
- PyTorch (latest stable)
- Common ML libraries (numpy, scipy, etc.)
- Jupyter Notebook accessible via browser

**No setup needed.** SSH in and start installing your training backend (kohya/SimpleTuner/ai-toolkit). The CUDA/PyTorch/driver stack is already working.

### When to Use Lambda

| Scenario | Lambda? | Why |
|----------|---------|-----|
| Flux LoRA (needs 24+ GB reliably) | **Yes** | Guaranteed A100 with pre-configured env |
| Long training (2+ hours) | **Yes** | No risk of preemption |
| Budget SDXL LoRA training | No | Vast.ai is much cheaper for this |
| Quick 5-minute test | No | Minimum billing makes short runs expensive |
| Vast.ai/RunPod unavailable | **Yes** | Lambda usually has stock |

### SSH Access and Tunneling

```bash
# Connect
ssh ubuntu@INSTANCE_IP

# SSH tunnel for ComfyUI
ssh -L 8188:localhost:8188 ubuntu@INSTANCE_IP
# Then open http://localhost:8188 in your browser
```

**Note**: Lambda uses `ubuntu` as the default user (not `root` like Vast.ai).

### File Transfer

```bash
# Upload dataset
scp -r ./dataset/ ubuntu@INSTANCE_IP:~/dataset/

# Download trained LoRA
scp ubuntu@INSTANCE_IP:~/output/my_lora.safetensors ./

# rsync for large transfers
rsync -avz ./dataset/ ubuntu@INSTANCE_IP:~/dataset/
```

### Persistent Storage

Lambda provides persistent filesystem storage:
- Files in your home directory persist while the instance runs
- **Files are deleted when you terminate** the instance
- No network volumes like RunPod — download results before terminating

### Common Gotchas

1. **Availability**: Popular GPUs (A100) sell out during peak hours. Check availability before planning a session.
2. **Minimum billing**: You're billed from instance launch, not from first SSH connection. Don't launch until you're ready to work.
3. **No spot instances**: All on-demand means no cheap option for quick experiments.
4. **User is `ubuntu`**: Not `root`. Use `sudo` when needed.
5. **No persistent storage**: Everything is deleted on terminate. Always download your results first.
6. **API is simple but limited**: No search/filter like Vast.ai. What you see on the dashboard is what's available.

## Why This Matters
Lambda is the "hire a professional" option. You pay more, but everything works out of the box — no CUDA version mismatches, no flaky hosts, no template debugging. For artists who value their time over saving a few dollars per session, Lambda removes friction.

## Sources
- [Lambda Cloud](https://lambdalabs.com/service/gpu-cloud)
- [Lambda Cloud Documentation](https://docs.lambdalabs.com/)
