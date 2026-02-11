# Workflow JSON Anatomy

## In Plain Language
A ComfyUI workflow is a JSON file that describes a chain of operations: load a model → set the prompt → generate the image → save it. Each step is a "node" with an ID, and nodes connect to each other by referencing those IDs. Think of it like a recipe — each step uses ingredients from previous steps.

## What You Need to Know

### Structure Overview

A workflow is a JSON object where each key is a node ID (a string number), and each value describes what that node does:

```json
{
  "3": {
    "class_type": "KSampler",
    "inputs": {
      "seed": 42,
      "steps": 20,
      "cfg": 7,
      "sampler_name": "euler",
      "scheduler": "normal",
      "denoise": 1.0,
      "model": ["4", 0],
      "positive": ["6", 0],
      "negative": ["7", 0],
      "latent_image": ["5", 0]
    }
  }
}
```

### Node Format

Every node has:

| Field | What It Is |
|-------|-----------|
| `class_type` | The node type (e.g., "KSampler", "CLIPTextEncode") |
| `inputs` | Configuration values and connections to other nodes |

### How Nodes Connect

When an input references another node, it uses `["node_id", output_index]`:

```json
"model": ["4", 0]
```

This means: "Take the first output (index 0) from node 4."

### Essential Node Types

| Node Type | Purpose | Key Inputs |
|-----------|---------|------------|
| `CheckpointLoaderSimple` | Load a model (.safetensors) | `ckpt_name` |
| `CLIPTextEncode` | Convert text prompt to embeddings | `text`, `clip` |
| `EmptyLatentImage` | Create a blank canvas at a size | `width`, `height`, `batch_size` |
| `KSampler` | The core generation step | `seed`, `steps`, `cfg`, `sampler_name`, `model`, `positive`, `negative`, `latent_image` |
| `VAEDecode` | Convert latent result to a viewable image | `samples`, `vae` |
| `SaveImage` | Save the result to disk | `images`, `filename_prefix` |
| `LoraLoader` | Apply a LoRA to a model | `model`, `clip`, `lora_name`, `strength_model`, `strength_clip` |

### Minimal txt2img Flow

```
CheckpointLoader → CLIPTextEncode (positive) ─┐
                 → CLIPTextEncode (negative) ─── KSampler → VAEDecode → SaveImage
                                                    ↑
                 → EmptyLatentImage ───────────────┘
```

### Common Parameters

| Parameter | What It Controls | Typical Values |
|-----------|-----------------|----------------|
| `seed` | Reproducibility — same seed = same image | Any integer, or -1 for random |
| `steps` | How many refinement passes | SDXL: 25-40, Flux: 20-30 |
| `cfg` | How closely to follow the prompt | SDXL: 5-9, Flux: 1-4 |
| `sampler_name` | Algorithm for generation | `euler`, `euler_ancestral`, `dpmpp_2m`, `dpmpp_sde` |
| `scheduler` | Step scheduling | `normal`, `karras`, `sgm_uniform` |
| `denoise` | How much to change (1.0 = full generation) | txt2img: 1.0, img2img: 0.3-0.8 |
| `width` / `height` | Image dimensions | SDXL: 1024x1024, Pony: 832x1216 |

### Adding a LoRA

Insert a `LoraLoader` node between the checkpoint and the sampler:

```
CheckpointLoader → LoraLoader → CLIPTextEncode → KSampler → ...
```

The LoRA loader takes the model and clip from the checkpoint, applies the LoRA, and passes the modified model and clip to the next nodes.

Key LoRA inputs:
- `lora_name`: filename (e.g., "my_style_v1.safetensors")
- `strength_model`: how strongly the LoRA affects the image (0.5-1.0 typical)
- `strength_clip`: how strongly the LoRA affects text understanding (usually matches strength_model)

### SDXL vs Flux Differences

| Aspect | SDXL | Flux |
|--------|------|------|
| Checkpoint loader | `CheckpointLoaderSimple` | `CheckpointLoaderSimple` or `UNETLoader` |
| Text encoding | `CLIPTextEncode` | Often `CLIPTextEncode` + `FluxGuidance` |
| CFG | 5-9 | 1-4 |
| Sampler | `euler`, `dpmpp_2m` | `euler` |
| Scheduler | `karras` | `sgm_uniform` |
| Resolution | 1024x1024 | 1024x1024 |

## Why This Matters
Understanding workflow JSON lets `/art` build and modify generation pipelines programmatically. Instead of clicking in the ComfyUI UI, we construct the exact workflow we need and submit it via the API.

## Sources
- [ComfyUI Node Reference](https://github.com/comfyanonymous/ComfyUI)
- [ComfyUI Workflow Examples](https://comfyanonymous.github.io/ComfyUI_examples/)
