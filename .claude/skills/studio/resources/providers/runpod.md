# RunPod Provider Guide

## In Plain Language
RunPod is a managed GPU cloud. More polished than Vast.ai — consistent hardware, better UI, and managed environments. Slightly more expensive but more reliable. If you want "it just works" cloud training, RunPod is a strong choice.

## What You Need to Know

### Pricing

| Cloud Type | GPU Examples | Typical $/hr | What It Means |
|------------|-------------|-------------|---------------|
| **Community** | RTX 3090, 4090 | $0.20-0.80 | Shared hardware, cheaper, may be preempted |
| **Secure** | A100, H100 | $0.80-3.00 | Datacenter-grade, guaranteed availability |
| **Serverless** | Various | Per-second billing | For inference only, not training |

For LoRA training: **Community** is fine for most users. Use **Secure** for critical long-running sessions.

### Setup

1. **Create account** at runpod.io
2. **Add credits** (pay-as-you-go, minimum $10)
3. **Add SSH key** in Settings → SSH Keys
4. **Install CLI** (optional): `pip install runpodctl`

### Pod vs Serverless

| Feature | Pod | Serverless |
|---------|-----|-----------|
| Use case | Interactive training | Batch inference |
| Persistence | Disk persists while pod runs | Stateless |
| SSH access | Yes | No |
| File transfer | Yes (scp, rsync) | No |
| Best for training? | **Yes** | No |

**For LoRA training, always use Pods.**

### Creating a Pod

1. Go to Pods → Deploy
2. Choose GPU type (RTX 4090, A100, etc.)
3. Select a template (see below)
4. Set container disk (20+ GB) and volume disk (50+ GB for training)
5. Deploy

### Recommended Templates

| Template | CUDA | PyTorch | Best For |
|----------|------|---------|----------|
| **RunPod PyTorch 2.x** | 12.1+ | Latest | General training (recommended) |
| **Stable Diffusion WebUI** | 12.1 | Pre-installed | Already includes generation tools |
| **Custom Docker** | You choose | You choose | When you need specific versions |

**Recommendation**: Start with the PyTorch template. It has the right CUDA, PyTorch, and NVIDIA drivers pre-installed.

### Network Volumes (Persistent Storage)

Network volumes are RunPod's killer feature for repeat trainers:

| Feature | Container Disk | Network Volume |
|---------|---------------|----------------|
| Persistence | Deleted when pod stops | **Survives pod stop/restart** |
| Speed | Fast (local SSD) | Slightly slower (network) |
| Cost | Included in pod price | ~$0.07/GB/month |
| Use case | Temporary files, cache | Models, datasets, checkpoints |

**How to use**:
1. Create a network volume in the RunPod dashboard (50-100 GB)
2. Attach it when creating a pod
3. It mounts at `/workspace` by default
4. Store your base models and datasets here
5. Next time you create a pod, attach the same volume — no re-uploading

**This saves serious time.** Uploading a 7 GB model every session adds up. With a network volume, upload once, use forever.

### SSH Access and Tunneling

```bash
# Connect via CLI
runpodctl ssh --pod POD_ID

# Or use the SSH command from the pod's dashboard page
ssh root@IP -p PORT -i ~/.ssh/your_key

# SSH tunnel for ComfyUI (forward port 8188 to your machine)
ssh -L 8188:localhost:8188 root@IP -p PORT -i ~/.ssh/your_key
# Then open http://localhost:8188 in your browser
```

### File Transfer

```bash
# Upload dataset to pod
scp -P PORT -r ./dataset/ root@IP:/workspace/dataset/

# Download trained LoRA
scp -P PORT root@IP:/workspace/output/my_lora.safetensors ./

# RunPod also supports their own transfer tool
runpodctl send my_lora.safetensors  # generates a one-time code
runpodctl receive CODE              # download on another machine
```

### Common Gotchas

1. **Volume not mounted**: Always verify your network volume is attached before starting. Check with `ls /workspace/`.
2. **Template version**: Older templates may have outdated CUDA/PyTorch. Prefer templates updated in the last 3 months.
3. **Pod preemption**: Community cloud pods can be stopped if demand spikes. Save checkpoints frequently.
4. **Cost creep**: Pods keep running (and charging) until you stop them. **Always stop your pod when done.** We'll remind you.
5. **Container vs volume disk**: Training artifacts should go on the volume disk (persists). Temp files go on container disk (deleted on stop).
6. **SSH key missing**: If you can't SSH in, check that your public key is added in RunPod Settings → SSH Keys.

## Why This Matters
RunPod balances reliability and cost. The managed templates mean you spend less time debugging CUDA issues and more time training. Network volumes make it practical for artists who train regularly — set up once, reuse forever.

## Sources
- [RunPod Documentation](https://docs.runpod.io/)
- [RunPod CLI](https://github.com/runpod/runpodctl)
