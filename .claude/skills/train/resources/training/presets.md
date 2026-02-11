# Training Presets

## In Plain Language
Presets are pre-configured training recipes. Instead of setting 15 technical parameters individually, pick a preset that matches your goal: Quick to test if your concept works (5 minutes), Standard for a production-quality result (30 minutes), or Thorough for maximum quality (1-2 hours). Each preset sets the learning rate (how fast the model learns), epochs (how many times it sees your images), and other settings to proven values.

## What You Need to Know

### Quick Preset — "Does This Even Work?"

**Goal**: Fast iteration. Test if your dataset and concept are viable before investing serious GPU time.

| Parameter | Value | Why |
|-----------|-------|-----|
| Epochs | 5 | Just enough to see if the concept is captured |
| Learning rate | Prodigy 1.0 | No tuning needed |
| Network rank | 16 | Sufficient for testing |
| Network alpha | 16 | Equal to rank |
| Batch size | 1 | VRAM-safe |
| Resolution | 1024x1024 | Standard |
| Noise offset | 0.05 | Minor improvement, low cost |
| Save every | 2 epochs | Quick checkpoints |

**Expected time**: 5-15 minutes (depending on dataset size and GPU)
**Expected quality**: Rough — enough to tell if the training direction is right
**When to use**: First training with a new dataset, testing if captions are good enough

### Standard Preset — "Production Quality"

**Goal**: Good-quality LoRA for regular use. The default recommendation.

| Parameter | Value | Why |
|-----------|-------|-----|
| Epochs | 15 | Balanced learning without overfit |
| Learning rate | Prodigy 1.0 or AdamW 1e-4 | Stable convergence |
| Network rank | 32 | Captures moderate detail |
| Network alpha | 16 | Half of rank for stability |
| Batch size | Auto (VRAM-based) | Maximized within safety margin |
| Resolution | 1024x1024 | Standard |
| Noise offset | 0.1 | Better contrast range |
| Save every | 3 epochs | Regular checkpoints |

**Expected time**: 15-60 minutes (depending on dataset size and GPU)
**Expected quality**: Good — suitable for regular generation use
**When to use**: After Quick preset validates the concept; most production LoRAs

### Thorough Preset — "Maximum Quality"

**Goal**: Highest quality. For production LoRAs where quality matters more than time.

| Parameter | Value | Why |
|-----------|-------|-----|
| Epochs | 25 | Extended learning for nuance |
| Learning rate | AdamW 5e-5 | Gentle, precise convergence |
| Network rank | 64 | Maximum detail capacity |
| Network alpha | 32 | Half of rank for stability |
| Batch size | Auto (VRAM-based) | Maximized within safety margin |
| Resolution | 1024x1024 | Standard |
| Noise offset | 0.1 | Better contrast range |
| Warmup steps | 15% of total | Gradual start for stability |
| Save every | 5 epochs | More checkpoints to evaluate |

**Expected time**: 30-120 minutes (depending on dataset size and GPU)
**Expected quality**: Best possible — subtle style details captured
**When to use**: Final production LoRA after Standard preset proves the concept

### Preset Selection Flow

```
First training?
  → Quick (5 min, test the concept)

Quick result looks promising?
  → Standard (30 min, production quality)

Standard result needs more nuance?
  → Thorough (60+ min, maximum quality)

Standard result looks wrong?
  → Fix dataset first, then Quick again
```

### VRAM Estimates by Preset

| Preset | 10 GB GPU | 16 GB GPU | 24 GB GPU |
|--------|-----------|-----------|-----------|
| Quick | OK (batch 1) | OK (batch 1-2) | OK (batch 2-4) |
| Standard | OK (batch 1) | OK (batch 1-2) | OK (batch 2-4) |
| Thorough | Tight (batch 1 only) | OK (batch 1) | OK (batch 2) |

**Note**: Higher network rank (Thorough: 64) uses more VRAM than lower (Quick: 16). If VRAM is tight, the auto-calculator will adjust batch size down and flag if the preset isn't feasible.

### Customizing Presets

After selecting a preset, you can adjust individual parameters:

```
"Start with Standard but use 20 epochs instead of 15"
"Use Thorough but with Prodigy instead of AdamW"
```

The preset is a starting point, not a constraint.

## Backend-Specific Configs

Each preset below gives you the exact config for your training tool. Copy, paste, adjust paths.

### Quick Preset — Backend Configs

#### Kohya sd-scripts (TOML)

```toml
[model]
pretrained_model_name_or_path = "/path/to/model.safetensors"

[train]
output_dir = "/path/to/output"
output_name = "my_lora_quick"
train_data_dir = "/path/to/dataset"
resolution = "1024,1024"
train_batch_size = 1
max_train_epochs = 5
learning_rate = 1.0
optimizer_type = "Prodigy"
network_module = "networks.lora"
network_dim = 16
network_alpha = 16
mixed_precision = "bf16"
save_every_n_epochs = 2
noise_offset = 0.05
clip_skip = 2
```

**Run**: `accelerate launch sdxl_train_network.py --config_file quick_config.toml`

#### SimpleTuner (config.env)

```bash
export MODEL_NAME="/path/to/model.safetensors"
export OUTPUT_DIR="/path/to/output"
export INSTANCE_DIR="/path/to/dataset"
export RESOLUTION=1024
export TRAIN_BATCH_SIZE=1
export MAX_NUM_STEPS=150
export LEARNING_RATE=1.0
export OPTIMIZER="prodigy"
export LORA_RANK=16
export LORA_ALPHA=16
export MIXED_PRECISION="bf16"
export CHECKPOINTING_STEPS=60
export NOISE_OFFSET=0.05
```

**Steps**: 30 images × 5 epochs / batch 1 = 150 steps. Adjust `MAX_NUM_STEPS` for your dataset size.

**Run**: `bash train.sh`

#### ai-toolkit (YAML)

```yaml
job: train
config:
  name: "my_lora_quick"
  process:
    - type: sd_trainer
      training_folder: "/path/to/output"
      device: cuda:0
      network:
        type: lora
        linear: 16
        linear_alpha: 16
      save:
        dtype: float16
        save_every: 60
      datasets:
        - folder_path: "/path/to/dataset"
          caption_ext: txt
          resolution: 1024
          batch_size: 1
      train:
        batch_size: 1
        steps: 150
        lr: 1.0
        optimizer: prodigy
        noise_offset: 0.05
        dtype: bf16
      model:
        name_or_path: "/path/to/model.safetensors"
        is_xl: true
```

**Run**: `python run.py quick_config.yaml`

---

### Standard Preset — Backend Configs

#### Kohya sd-scripts (TOML)

```toml
[model]
pretrained_model_name_or_path = "/path/to/model.safetensors"

[train]
output_dir = "/path/to/output"
output_name = "my_lora_standard"
train_data_dir = "/path/to/dataset"
resolution = "1024,1024"
train_batch_size = 1
max_train_epochs = 15
learning_rate = 1.0
optimizer_type = "Prodigy"
network_module = "networks.lora"
network_dim = 32
network_alpha = 16
mixed_precision = "bf16"
save_every_n_epochs = 3
noise_offset = 0.1
clip_skip = 2
```

**Run**: `accelerate launch sdxl_train_network.py --config_file standard_config.toml`

#### SimpleTuner (config.env)

```bash
export MODEL_NAME="/path/to/model.safetensors"
export OUTPUT_DIR="/path/to/output"
export INSTANCE_DIR="/path/to/dataset"
export RESOLUTION=1024
export TRAIN_BATCH_SIZE=1
export MAX_NUM_STEPS=450
export LEARNING_RATE=1.0
export OPTIMIZER="prodigy"
export LORA_RANK=32
export LORA_ALPHA=16
export MIXED_PRECISION="bf16"
export CHECKPOINTING_STEPS=90
export NOISE_OFFSET=0.1
```

**Steps**: 30 images × 15 epochs / batch 1 = 450 steps. Adjust for your dataset.

**Run**: `bash train.sh`

#### ai-toolkit (YAML)

```yaml
job: train
config:
  name: "my_lora_standard"
  process:
    - type: sd_trainer
      training_folder: "/path/to/output"
      device: cuda:0
      network:
        type: lora
        linear: 32
        linear_alpha: 16
      save:
        dtype: float16
        save_every: 90
      datasets:
        - folder_path: "/path/to/dataset"
          caption_ext: txt
          resolution: 1024
          batch_size: 1
      train:
        batch_size: 1
        steps: 450
        lr: 1.0
        optimizer: prodigy
        noise_offset: 0.1
        dtype: bf16
      model:
        name_or_path: "/path/to/model.safetensors"
        is_xl: true
```

**Run**: `python run.py standard_config.yaml`

---

### Thorough Preset — Backend Configs

#### Kohya sd-scripts (TOML)

```toml
[model]
pretrained_model_name_or_path = "/path/to/model.safetensors"

[train]
output_dir = "/path/to/output"
output_name = "my_lora_thorough"
train_data_dir = "/path/to/dataset"
resolution = "1024,1024"
train_batch_size = 1
max_train_epochs = 25
learning_rate = 5e-5
optimizer_type = "AdamW"
network_module = "networks.lora"
network_dim = 64
network_alpha = 32
mixed_precision = "bf16"
save_every_n_epochs = 5
noise_offset = 0.1
clip_skip = 2
lr_scheduler = "cosine_with_restarts"
lr_warmup_steps = 112
```

**Warmup**: 15% of total steps. For 30 images × 25 epochs = 750 steps → ~112 warmup steps.

**Run**: `accelerate launch sdxl_train_network.py --config_file thorough_config.toml`

#### SimpleTuner (config.env)

```bash
export MODEL_NAME="/path/to/model.safetensors"
export OUTPUT_DIR="/path/to/output"
export INSTANCE_DIR="/path/to/dataset"
export RESOLUTION=1024
export TRAIN_BATCH_SIZE=1
export MAX_NUM_STEPS=750
export LEARNING_RATE=5e-5
export OPTIMIZER="adamw"
export LORA_RANK=64
export LORA_ALPHA=32
export MIXED_PRECISION="bf16"
export CHECKPOINTING_STEPS=150
export NOISE_OFFSET=0.1
export LR_SCHEDULER="cosine_with_restarts"
export LR_WARMUP_STEPS=112
```

**Run**: `bash train.sh`

#### ai-toolkit (YAML)

```yaml
job: train
config:
  name: "my_lora_thorough"
  process:
    - type: sd_trainer
      training_folder: "/path/to/output"
      device: cuda:0
      network:
        type: lora
        linear: 64
        linear_alpha: 32
      save:
        dtype: float16
        save_every: 150
      datasets:
        - folder_path: "/path/to/dataset"
          caption_ext: txt
          resolution: 1024
          batch_size: 1
      train:
        batch_size: 1
        steps: 750
        lr: 5e-5
        optimizer: adamw
        noise_offset: 0.1
        dtype: bf16
        warmup_steps: 112
      model:
        name_or_path: "/path/to/model.safetensors"
        is_xl: true
```

**Run**: `python run.py thorough_config.yaml`

---

### VRAM Estimates by GPU

These estimates assume SDXL LoRA training with xformers enabled. Flux requires approximately 50% more VRAM.

| Preset | RTX 3090 (24 GB) | RTX 4090 (24 GB) | A100 40 GB | A100 80 GB |
|--------|:-:|:-:|:-:|:-:|
| **Quick** (rank 16) | batch 2-4 | batch 2-4 | batch 4-8 | batch 8-16 |
| **Standard** (rank 32) | batch 1-2 | batch 1-2 | batch 2-4 | batch 4-8 |
| **Thorough** (rank 64) | batch 1 | batch 1 | batch 1-2 | batch 2-4 |

**What the batch size means**: Higher batch size = faster training but more VRAM. Batch 1 always works but is slowest. The auto-calculator picks the highest safe batch for your GPU.

| Preset + Flux | RTX 3090 (24 GB) | RTX 4090 (24 GB) | A100 40 GB | A100 80 GB |
|---------------|:-:|:-:|:-:|:-:|
| **Quick** (rank 16) | batch 1 | batch 1 | batch 2-4 | batch 4-8 |
| **Standard** (rank 32) | batch 1 (tight) | batch 1 (tight) | batch 1-2 | batch 2-4 |
| **Thorough** (rank 64) | May not fit | May not fit | batch 1 | batch 1-2 |

**Note**: For Flux Thorough on 24 GB GPUs, reduce rank to 32 or use quantized model loading.

## Why This Matters
Most failed LoRAs fail because of bad parameters. Presets encode proven configurations, so you start with something that works and adjust from there instead of guessing. The backend-specific configs mean you can copy-paste directly — no translation required.

## Sources
- Derived from [Kohya Community Configs](https://civitai.com/articles/3105)
- Validated against [Derrian's Training Guide](https://civitai.com/articles/2056)
