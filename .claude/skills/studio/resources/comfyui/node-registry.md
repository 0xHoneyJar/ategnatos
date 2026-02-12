# ComfyUI Node Registry

> Quick reference: which custom node packages provide which nodes.

## In Plain Language

Every block in a ComfyUI workflow has a `class_type` -- that's the node doing the work. Some nodes come pre-installed with ComfyUI (built-in), while others require separate packages you install into the `custom_nodes/` folder. This registry tells you which is which, so you don't have to guess why a workflow fails with "Node not found."

## What You Need to Know

- Built-in nodes ship with ComfyUI -- no installation needed
- Custom nodes live in ComfyUI's `custom_nodes/` directory
- The preflight check (`comfyui-preflight.sh`) uses this registry to detect missing nodes and suggest install commands
- The `/object_info` API endpoint lists all nodes available on a running ComfyUI instance -- use it to verify installs

## Node Map

### Built-in Nodes

These ship with every ComfyUI installation.

| Node Class | Category | Notes |
|-----------|----------|-------|
| KSampler | sampling | Core sampler -- the main generation step |
| KSamplerAdvanced | sampling | Adds start/end step control, noise control |
| SamplerCustom | sampling | Wire your own sampler + scheduler + sigmas |
| CheckpointLoaderSimple | loaders | Load checkpoint models (.safetensors, .ckpt) |
| UNETLoader | loaders | Load UNET-only models (used by some Flux setups) |
| DualCLIPLoader | loaders | Load two CLIP models (Flux T5 + CLIP-L) |
| LoraLoader | loaders | Load LoRA weights, applies to both model and CLIP |
| LoraLoaderModelOnly | loaders | Load LoRA weights, model only (no CLIP change) |
| VAELoader | loaders | Load a standalone VAE |
| ControlNetLoader | loaders | Load ControlNet models |
| UpscaleModelLoader | loaders | Load upscale models (ESRGAN, SwinIR, etc.) |
| CLIPTextEncode | conditioning | Encode text prompts into conditioning |
| ConditioningCombine | conditioning | Merge two conditioning inputs |
| ConditioningConcat | conditioning | Concatenate conditioning (for area prompting) |
| ConditioningSetArea | conditioning | Regional prompting -- apply conditioning to a specific area |
| ConditioningSetMask | conditioning | Mask-based regional conditioning |
| ConditioningZeroOut | conditioning | Zero out conditioning (useful for Flux negative) |
| CLIPSetLastLayer | clip | Set CLIP skip layer |
| CLIPVisionLoader | clip | Load CLIP vision model (for IP-Adapter, etc.) |
| CLIPVisionEncode | clip | Encode an image through CLIP vision |
| FluxGuidance | conditioning | Set guidance scale for Flux models (replaces CFG) |
| VAEDecode | latent | Decode latent to pixel image |
| VAEEncode | latent | Encode pixel image to latent |
| VAEDecodeTiled | latent | Tiled decode for large images (lower VRAM) |
| VAEEncodeTiled | latent | Tiled encode for large images (lower VRAM) |
| EmptyLatentImage | latent | Create empty latent at specified dimensions |
| LatentUpscale | latent | Resize latent (nearest/bilinear/area/bislerp) |
| LatentUpscaleBy | latent | Resize latent by scale factor |
| LatentComposite | latent | Composite one latent onto another |
| LatentBlend | latent | Blend two latents together |
| SaveImage | image | Save output image to disk |
| PreviewImage | image | Preview image (WebSocket only, not saved) |
| LoadImage | image | Load input image from disk |
| LoadImageMask | image | Load image as a mask |
| ImageScale | image | Resize image (nearest/bilinear/area/bicubic/lanczos) |
| ImageScaleBy | image | Resize image by scale factor |
| ImageUpscaleWithModel | image | Upscale using a loaded upscale model |
| ImageInvert | image | Invert image colors |
| ImageBatch | image | Combine images into a batch |
| ImagePadForOutpaint | image | Pad image edges for outpainting |
| MaskToImage | mask | Convert mask to image |
| ImageToMask | mask | Convert image channel to mask |
| ControlNetApplyAdvanced | conditioning | Apply ControlNet with start/end percent control |
| RepeatLatentBatch | latent | Repeat a latent N times for batch generation |
| RebatchLatentImages | latent | Re-batch latent images |

### Custom Node Packages

These require separate installation. Each row includes the install command -- run it from your ComfyUI root directory.

#### comfyui_controlnet_aux -- ControlNet Preprocessors

Repository: [Fannovel16/comfyui_controlnet_aux](https://github.com/Fannovel16/comfyui_controlnet_aux)

```bash
cd custom_nodes && git clone https://github.com/Fannovel16/comfyui_controlnet_aux
cd comfyui_controlnet_aux && pip install -r requirements.txt
```

| Node Class | What It Does |
|-----------|-------------|
| AIO_Preprocessor | Auto-detect and run the right preprocessor |
| CannyEdgePreprocessor | Canny edge detection |
| DepthAnythingPreprocessor | Depth estimation |
| DWPreprocessor | DWPose -- human pose estimation |
| LineArtPreprocessor | Line art extraction |
| MiDaS-DepthMapPreprocessor | MiDaS depth map |
| OpenposePreprocessor | OpenPose skeleton detection |
| ScribblePreprocessor | Scribble/sketch preprocessing |
| TilePreprocessor | Tile preprocessor for detail enhancement |
| InpaintPreprocessor | Prepare inpaint masks |

#### ComfyUI_IPAdapter_plus -- IP-Adapter (Image Prompting)

Repository: [cubiq/ComfyUI_IPAdapter_plus](https://github.com/cubiq/ComfyUI_IPAdapter_plus)

```bash
cd custom_nodes && git clone https://github.com/cubiq/ComfyUI_IPAdapter_plus
```

| Node Class | What It Does |
|-----------|-------------|
| IPAdapterApply | Apply IP-Adapter to a model |
| IPAdapterModelLoader | Load IP-Adapter model weights |
| IPAdapterAdvanced | IP-Adapter with weight type and masking |
| IPAdapterFaceID | Face-specific IP-Adapter |
| IPAdapterEncoder | Encode image for IP-Adapter |
| IPAdapterCombineEmbeds | Combine multiple IP-Adapter embeddings |

#### ComfyUI-Impact-Pack -- Face Detailing, Wildcards, and More

Repository: [ltdrdata/ComfyUI-Impact-Pack](https://github.com/ltdrdata/ComfyUI-Impact-Pack)

```bash
cd custom_nodes && git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack
cd ComfyUI-Impact-Pack && python install.py
```

| Node Class | What It Does |
|-----------|-------------|
| FaceDetailer | Detect and re-generate faces at higher detail |
| SAMDetectorCombined | Segment Anything Model detection |
| BboxDetectorSEGS | Bounding box detection for face/hand segments |
| WildcardEncode | Expand wildcard syntax in prompts |
| ImpactSimpleDetectorSEGS | Simplified segment detection |

#### ComfyUI_UltimateSDUpscale -- Tiled Upscaling

Repository: [ssitu/ComfyUI_UltimateSDUpscale](https://github.com/ssitu/ComfyUI_UltimateSDUpscale)

```bash
cd custom_nodes && git clone https://github.com/ssitu/ComfyUI_UltimateSDUpscale
```

| Node Class | What It Does |
|-----------|-------------|
| UltimateSDUpscale | Tiled upscale with controlable tile size, overlap, and seam fix |
| UltimateSDUpscaleNoUpscale | Same but expects pre-upscaled input |

#### ComfyUI-Manager -- Node Management UI

Repository: [ltdrdata/ComfyUI-Manager](https://github.com/ltdrdata/ComfyUI-Manager)

```bash
cd custom_nodes && git clone https://github.com/ltdrdata/ComfyUI-Manager
```

| Node Class | What It Does |
|-----------|-------------|
| (no workflow nodes) | Provides a UI for installing/updating other custom nodes |

Note: ComfyUI-Manager doesn't add workflow nodes, but it's the easiest way to install other custom node packages through the ComfyUI web interface.

#### ComfyUI-KJNodes -- Utility Nodes

Repository: [kijai/ComfyUI-KJNodes](https://github.com/kijai/ComfyUI-KJNodes)

```bash
cd custom_nodes && git clone https://github.com/kijai/ComfyUI-KJNodes
```

| Node Class | What It Does |
|-----------|-------------|
| GetImageSize | Return width/height of an image |
| ConditioningSetMaskAndCombine | Set mask and combine conditioning in one step |
| ImageBatchRepeatInterleaving | Repeat images in a batch with interleaving |

#### ComfyUI-Essentials -- Common Utilities

Repository: [cubiq/ComfyUI_essentials](https://github.com/cubiq/ComfyUI_essentials)

```bash
cd custom_nodes && git clone https://github.com/cubiq/ComfyUI_essentials
cd ComfyUI_essentials && pip install -r requirements.txt
```

| Node Class | What It Does |
|-----------|-------------|
| ImageResize+ | Resize with more options than built-in |
| MaskBlur+ | Blur masks with adjustable radius |
| ImageCrop+ | Crop images with precise control |
| BatchCount+ | Set batch count for generation |

#### was-node-suite-comfyui -- Extended Image Processing

Repository: [WASasquatch/was-node-suite-comfyui](https://github.com/WASasquatch/was-node-suite-comfyui)

```bash
cd custom_nodes && git clone https://github.com/WASasquatch/was-node-suite-comfyui
cd was-node-suite-comfyui && pip install -r requirements.txt
```

| Node Class | What It Does |
|-----------|-------------|
| WAS_Image_Resize | Resize images |
| WAS_Image_Save | Save with more format options |
| WAS_Mask_Combine | Combine multiple masks |
| WAS_Text_Concatenate | Join text strings |

#### ComfyUI-AnimateDiff-Evolved -- Animation/Video

Repository: [Kosinkadink/ComfyUI-AnimateDiff-Evolved](https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved)

```bash
cd custom_nodes && git clone https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved
```

| Node Class | What It Does |
|-----------|-------------|
| ADE_AnimateDiffLoaderWithContext | Load AnimateDiff model with context options |
| ADE_AnimateDiffUniformContextOptions | Set uniform context for animation |
| ADE_UseEvolvedSampling | Use evolved sampling for animation |

## Template Coverage

Nodes used in the Ategnatos workflow templates and where they come from:

| Template | Nodes Used | All Built-in? |
|----------|-----------|---------------|
| txt2img-sdxl | CheckpointLoaderSimple, CLIPTextEncode, EmptyLatentImage, KSampler, VAEDecode, SaveImage | Yes |
| txt2img-flux | CheckpointLoaderSimple, CLIPTextEncode, FluxGuidance, EmptyLatentImage, KSampler, VAEDecode, SaveImage | Yes |
| lora-test | CheckpointLoaderSimple, LoraLoader, CLIPTextEncode, EmptyLatentImage, KSampler, VAEDecode, SaveImage | Yes |
| img2img-sdxl | CheckpointLoaderSimple, LoadImage, VAEEncode, CLIPTextEncode, KSampler, VAEDecode, SaveImage | Yes |
| img2img-flux | CheckpointLoaderSimple, LoadImage, VAEEncode, CLIPTextEncode, FluxGuidance, KSampler, VAEDecode, SaveImage | Yes |
| controlnet-sdxl | CheckpointLoaderSimple, ControlNetLoader, LoadImage, CLIPTextEncode, ControlNetApplyAdvanced, EmptyLatentImage, KSampler, VAEDecode, SaveImage | Yes |
| upscale-esrgan | LoadImage, UpscaleModelLoader, ImageUpscaleWithModel, SaveImage | Yes |

All current templates use only built-in nodes. Custom node packages become necessary when you add IP-Adapter, face detailing, ControlNet preprocessors, tiled upscaling, or animation to your workflows.

## Adding New Nodes

When you install a new custom node package:

1. Add entries to the appropriate section above (or create a new section)
2. Run `comfyui-preflight.sh` to verify installation
3. Check the ComfyUI `/object_info` endpoint to confirm the nodes are loaded:
   ```bash
   curl -s http://127.0.0.1:8188/object_info | python3 -c "import sys,json; d=json.load(sys.stdin); print('NodeName' in d)"
   ```

## Sources

- [ComfyUI Built-in Nodes](https://github.com/comfyanonymous/ComfyUI/tree/master/nodes)
- [ComfyUI Examples](https://comfyanonymous.github.io/ComfyUI_examples/)
- [ComfyUI-Manager Node Database](https://github.com/ltdrdata/ComfyUI-Manager)
