# ComfyUI REST API Reference

## In Plain Language
ComfyUI has a built-in web API. When ComfyUI is running, you can send it generation requests as JSON and get images back — no clicking required. This is how `/art` automates image generation.

## What You Need to Know

### Base URL
```
http://127.0.0.1:8188
```
Default port is 8188. Some setups use 8189, 8190, or 3000 (via reverse proxy).

### Key Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/prompt` | POST | Submit a workflow for generation |
| `/history/{prompt_id}` | GET | Check if a generation is done |
| `/queue` | GET | See what's running and pending |
| `/view` | GET | Download a generated image |
| `/system_stats` | GET | Check GPU memory, queue depth |
| `/object_info` | GET | List all available nodes |
| `/upload/image` | POST | Upload an image (for img2img, ControlNet) |

### Submitting a Workflow

Send a POST to `/prompt` with the workflow JSON:

```bash
curl -X POST http://127.0.0.1:8188/prompt \
  -H "Content-Type: application/json" \
  -d '{"prompt": { ...workflow nodes... }}'
```

Response:
```json
{
  "prompt_id": "abc123-def456-...",
  "number": 5
}
```

The `prompt_id` is your receipt — use it to track progress.

### Checking Progress

Poll `/history/{prompt_id}` until your prompt appears:

```bash
curl http://127.0.0.1:8188/history/abc123-def456
```

- **Empty response** = still generating
- **Has your prompt_id** = done (check `.status.status_str` for "success" or "error")

### Downloading Results

When done, the history entry has an `outputs` section with filenames:

```bash
curl -o result.png "http://127.0.0.1:8188/view?filename=ComfyUI_00001_.png&type=output"
```

### Checking the Queue

```bash
curl http://127.0.0.1:8188/queue
```

Returns:
```json
{
  "queue_running": [...],   // Currently generating
  "queue_pending": [...]    // Waiting in line
}
```

### System Stats

```bash
curl http://127.0.0.1:8188/system_stats
```

Shows GPU memory usage, loaded models, and system info. Useful for checking if you're close to running out of VRAM.

### Uploading Images

For img2img or ControlNet workflows, upload an image first:

```bash
curl -X POST http://127.0.0.1:8188/upload/image \
  -F "image=@my_image.png" \
  -F "type=input"
```

Response includes the filename to reference in your workflow.

## Common Issues

| Problem | Cause | Fix |
|---------|-------|-----|
| Connection refused | ComfyUI not running | Start ComfyUI |
| "Prompt not found" | Wrong prompt_id | Check the ID from submit response |
| Empty outputs | Node not connected to output | Check workflow JSON |
| OOM error | Image too large for VRAM | Lower resolution or batch size |
| "Node not found" | Missing custom node | Install required custom nodes |

## Why This Matters
The API lets us automate the entire generation process — submit, wait, download — without manual interaction. This is what makes the `/art` iteration loop possible.

## Sources
- [ComfyUI API Documentation](https://github.com/comfyanonymous/ComfyUI)
- [ComfyUI API Examples](https://github.com/comfyanonymous/ComfyUI/tree/master/script_examples)
