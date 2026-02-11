# Glossary

## In Plain Language
AI art has a lot of technical jargon. This glossary defines every term you might encounter while using Ategnatos. When other reference files use a technical term, it's defined here.

## What You Need to Know

### Hardware & Infrastructure

| Term | What It Means |
|------|--------------|
| **GPU** | Graphics Processing Unit — the hardware chip that generates AI images. Think of it as the engine in your car. More powerful GPU = faster image generation. |
| **VRAM** | Video RAM — your GPU's dedicated memory. The bigger your VRAM, the larger models and images you can work with. Measured in gigabytes (GB). |
| **CUDA** | NVIDIA's software layer that lets programs use the GPU for computation. Only NVIDIA GPUs have CUDA. Think of it as the translator between your software and the GPU hardware. |
| **MPS** | Metal Performance Shaders — Apple Silicon's equivalent of CUDA. Used on Mac M-series chips instead of CUDA. |
| **SSH** | Secure Shell — a way to remotely connect to another computer over the internet. Like remote desktop, but text-based. Used to access cloud GPUs. |
| **NVIDIA Driver** | Software that lets your operating system talk to your NVIDIA GPU. Must be installed and updated for CUDA to work. |
| **PyTorch** | The software framework that AI models run on. It's like the operating system for AI — models are built for PyTorch, and PyTorch uses CUDA to talk to the GPU. |
| **OOM** | Out Of Memory — when a task needs more VRAM than your GPU has. The solution is usually to reduce batch size or image resolution. |

### Models & Architecture

| Term | What It Means |
|------|--------------|
| **Checkpoint** | A full AI model file — the "brain" that generates images. Usually 2-7 GB in size. |
| **LoRA** | Low-Rank Adaptation — a small add-on file (20-200 MB) that teaches an existing model new styles, characters, or concepts without replacing the whole model. |
| **SDXL** | Stable Diffusion XL — a model architecture (think: engine design). Multiple models share this base: SDXL 1.0, Pony V6, Illustrious XL. |
| **SD 1.5** | Stable Diffusion 1.5 — an older, smaller model architecture. Lower quality but runs on almost any GPU. |
| **Flux** | A newer model architecture by Black Forest Labs. Better at understanding complex instructions but needs more VRAM. |
| **VAE** | Variational Auto-Encoder — a component that converts between the model's internal representation and actual pixels. Usually included in the model file. |
| **CLIP** | Contrastive Language-Image Pre-training — the part of the model that understands your text prompt. Converts words into numbers the model can use. |
| **Quantized** | A smaller version of a model that uses less VRAM with minor quality loss. Like compressing a photo — smaller file, slightly less detail. |

### Generation Settings

| Term | What It Means |
|------|--------------|
| **CFG Scale** | Classifier-Free Guidance — how strictly the model follows your prompt. Higher = more literal, lower = more creative. Think of it as a dial between "do exactly what I said" and "improvise." |
| **Sampler** | The algorithm that builds the image step by step from noise. Different samplers produce slightly different results. Like different paintbrush techniques producing different textures. |
| **Steps** | How many times the sampler refines the image. More steps = more detail but slower generation. 20-30 is typical. |
| **Seed** | A number that controls the random starting point. Same seed + same prompt = same image. Useful for making small changes without starting over. |
| **Clip Skip** | Tells the model to use a less-processed understanding of your prompt. Some models (like Pony) need this set to 2 to work properly. |
| **Negative Prompt** | Things you DON'T want in the image. "blurry, low quality, extra fingers" tells the model to avoid these. |
| **Booru Tags** | Short descriptive labels separated by commas, like hashtags. Example: `1girl, long hair, warm lighting`. Some models understand these better than full sentences. |

### Training Terms

| Term | What It Means |
|------|--------------|
| **Epoch** | One complete pass through your entire training dataset. If you have 30 images and train for 15 epochs, the model sees each image 15 times. |
| **Batch Size** | How many images the model looks at simultaneously during training. Bigger batch = faster training but more VRAM needed. |
| **Learning Rate** | How much the model adjusts itself after seeing each image. Too high = chaotic learning. Too low = barely learns anything. |
| **Optimizer** | The strategy for how the model adjusts. Think of it as the study technique: Prodigy figures out its own pace, AdamW follows a fixed schedule. |
| **Network Rank** | How much detail capacity the LoRA has. Higher rank = more nuance captured but larger file and more VRAM. Rank 16 for testing, 32 for production, 64 for maximum detail. |
| **Network Alpha** | A stability parameter that controls how strongly the LoRA modifies the base model. Usually set to half of network rank. |
| **Noise Offset** | A technique that improves the model's ability to generate very dark and very bright areas. A small value (0.05-0.1) helps without side effects. |
| **Checkpoint** (training) | A snapshot saved during training. If you train for 15 epochs and save every 3, you get checkpoints at epochs 3, 6, 9, 12, and 15. Lets you pick the best result. |
| **Trigger Word** | A unique word you assign to your LoRA. Including it in a prompt activates the LoRA's effect. Example: "mystyle" triggers your trained style. |
| **Overtrained** | The model memorized your training images instead of learning the general concept. Outputs look exactly like training data or become blurry/distorted. |
| **Undertrained** | The model hasn't learned enough yet. The trigger word has little or no effect. Need more training steps. |
| **Content-Style Separation** | The challenge of teaching the model WHAT your style looks like without accidentally teaching it WHAT subjects to draw. If all training images are cats, the model might learn "cats" instead of "your art style." |
| **Fine-tune** | Training a model to learn something new. LoRA training is a type of fine-tuning that's efficient and focused. |
| **Inference** | Generating an image (as opposed to training). Uses less VRAM than training. |
| **Latent** | The model's internal representation of an image before it becomes actual pixels. Think of it as the model's mental sketch. |

### Training Backends

| Term | What It Means |
|------|--------------|
| **Kohya sd-scripts** | The most popular LoRA training tool. Powerful with many options. Uses TOML config files. |
| **SimpleTuner** | A newer training tool focused on simplicity. Good Flux support. Uses environment variable configs. |
| **ai-toolkit** | A lightweight training tool with clean YAML configs. Simple and fast to set up. |
| **xformers** | A library that makes training use less VRAM (saves ~2 GB). Optional but recommended. |
| **accelerate** | A tool by HuggingFace that manages GPU training. Required by Kohya. |
| **TOML** | A config file format (like JSON or YAML but more human-readable). Kohya uses this. |
| **YAML** | Another config file format. ai-toolkit uses this. |

### Tools & Platforms

| Term | What It Means |
|------|--------------|
| **ComfyUI** | A node-based interface for generating AI images. You connect processing blocks visually to build workflows. Has a REST API that Ategnatos can talk to. |
| **Vast.ai** | A marketplace where people rent out their GPUs. Cheapest option, but quality varies. |
| **RunPod** | A managed GPU cloud service. More reliable than Vast.ai, slightly more expensive. |
| **Lambda Cloud** | High-end GPU cloud with datacenter reliability. Most expensive but most reliable. |

## Why This Matters
Every artist deserves to understand their tools. This glossary exists so that no technical term is a mystery. When you see a term you don't recognize, check here first. If a term is missing, let us know — we'll add it.
