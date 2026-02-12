# ComfyUI Compatibility

## In Plain Language
ComfyUI updates frequently, and different versions can behave differently. Some updates add new node types, change how the API works, or rename things. This file tracks which versions Ategnatos supports and what to watch out for when updating.

## Minimum Supported Version

**ComfyUI 0.2.0** is the minimum version Ategnatos supports.

Why this version:
- The `/system_stats` endpoint (used by version checking) was stabilized
- The `/object_info` API (used by preflight checks) returns consistent JSON
- Workflow API format is stable with `class_type` and `inputs` structure
- LoRA loading nodes use the standardized `LoraLoader` class

Older versions may work for basic generation but are not tested and may produce unexpected behavior with Ategnatos workflows.

## Known Breaking Changes

### 0.3.x (Late 2024)
- **FluxGuidance node**: Added for Flux model support. Workflows using Flux models need this node; it does not exist in older versions.
- **Scheduler changes**: `sgm_uniform` scheduler added. Older versions will reject workflows referencing it.
- **UNETLoader**: Alternative to `CheckpointLoaderSimple` for loading Flux UNET-only files. Not available in pre-0.3.x.

### 0.2.x (Mid 2024)
- **API format stabilization**: The `/queue` and `/system_stats` endpoints settled into their current JSON structure.
- **class_type consistency**: Node class names became case-sensitive. Workflows exported from pre-0.2.x may have inconsistent casing.
- **Output format**: `SaveImage` node output path handling changed. Workflows relying on specific output paths may need adjustment.

### Pre-0.2.0 (Early 2024 and before)
- **Not supported by Ategnatos.** Too many inconsistencies in the API surface.
- `/object_info` structure differs significantly
- Workflow JSON format may use legacy fields not recognized by current tooling

## Template Version Tagging

Ategnatos workflow templates are tagged with the ComfyUI version range they support. Templates live in `grimoire/library/` and the resources directory.

| Tag | Meaning | Example |
|-----|---------|---------|
| `comfyui: ">=0.2.0"` | Works with 0.2.0 and above | Basic txt2img, img2img |
| `comfyui: ">=0.3.0"` | Needs 0.3.0+ features | Flux workflows, FluxGuidance node |
| `comfyui: ">=0.2.0 <0.3.0"` | Only works in the 0.2.x range | Legacy SDXL-only templates |
| No tag | Assumed `>=0.2.0` | Older templates before tagging was introduced |

When `/art` selects a template, it checks the running ComfyUI version (via `comfyui-version-check.sh`) against the template's version tag. If the version is outside the supported range, the template is skipped with a warning.

### How Templates Declare Compatibility

In the template YAML front matter:

```yaml
---
name: flux-txt2img-basic
description: Basic Flux text-to-image generation
comfyui: ">=0.3.0"
model_type: flux
---
```

## How to Update ComfyUI Safely

Updating ComfyUI can break running workflows and custom nodes. Follow this process:

### 1. Check What You Have

Run the version check before doing anything:

```bash
.claude/scripts/studio/comfyui-version-check.sh --url http://127.0.0.1:8188
```

Note the current version and commit hash so you can roll back if needed.

### 2. Back Up Custom Nodes

Custom nodes are the most common source of breakage after an update. Before updating:

```bash
# In your ComfyUI directory
cp -r custom_nodes custom_nodes_backup_$(date +%Y%m%d)
```

### 3. Update ComfyUI

```bash
cd /path/to/ComfyUI
git pull
pip install -r requirements.txt
```

### 4. Update Custom Nodes

Most custom nodes need to be updated separately:

```bash
# For each custom node directory
cd custom_nodes/ComfyUI-Manager
git pull
pip install -r requirements.txt  # if it has one
```

Or use ComfyUI-Manager's built-in update feature if installed.

### 5. Verify After Update

Run the version check again and then the preflight check on your workflows:

```bash
# Check version
.claude/scripts/studio/comfyui-version-check.sh --url http://127.0.0.1:8188

# Check that your workflows still have all required nodes
.claude/scripts/studio/comfyui-preflight.sh \
  --workflow grimoire/library/my-workflow.json \
  --url http://127.0.0.1:8188
```

### 6. Roll Back if Needed

If something breaks:

```bash
cd /path/to/ComfyUI
git checkout <previous-commit-hash>
pip install -r requirements.txt

# Restore custom nodes if needed
rm -rf custom_nodes
mv custom_nodes_backup_YYYYMMDD custom_nodes
```

## Integration with comfyui-version-check.sh

The `comfyui-version-check.sh` script (located at `.claude/scripts/studio/comfyui-version-check.sh`) is the automated way to verify compatibility.

### How It Works

1. Queries the ComfyUI `/system_stats` endpoint
2. Extracts the `comfyui_version` and commit hash from the response
3. Compares the version against the minimum (`0.2.0`)
4. Reports PASS or FAIL

### Usage

```bash
# Plain text output
comfyui-version-check.sh --url http://127.0.0.1:8188

# JSON output (for programmatic use by other scripts)
comfyui-version-check.sh --url http://127.0.0.1:8188 --json
```

### JSON Output Format

```json
{
  "status": "PASS",
  "comfyui_version": "0.3.1",
  "commit": "abc1234",
  "min_required": "0.2.0",
  "message": "ComfyUI 0.3.1 meets minimum requirement (0.2.0)"
}
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Version meets or exceeds the minimum requirement |
| 1 | Version is too old, could not be determined, or ComfyUI is unreachable |

### Where It Is Called

- **`/studio` setup**: Automatically checks version when configuring a ComfyUI endpoint
- **`/art` generation**: Checks version before submitting workflows to catch incompatibilities early
- **`/train` evaluation**: Verifies the ComfyUI instance can run evaluation workflows after training

## Sources
- [ComfyUI Releases](https://github.com/comfyanonymous/ComfyUI/releases)
- [ComfyUI API Documentation](https://github.com/comfyanonymous/ComfyUI)
