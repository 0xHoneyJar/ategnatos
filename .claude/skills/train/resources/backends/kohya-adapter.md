# Kohya sd-scripts Adapter

## In Plain Language
Kohya sd-scripts is the most widely used tool for training LoRAs (small add-ons that teach AI models new styles or characters). It's a command-line program that reads a config file and your images, then runs the training process. It's powerful but has many options — this adapter translates our training settings into Kohya's format so you don't have to learn its syntax.

## What You Need to Know

### Installation
```bash
git clone https://github.com/kohya-ss/sd-scripts
cd sd-scripts
pip install -r requirements.txt
# For SDXL LoRA training:
pip install xformers  # optional but recommended for VRAM savings
```

### Config Format

Kohya uses command-line arguments or a TOML config file. We generate TOML configs:

```toml
[model]
pretrained_model_name_or_path = "/path/to/model.safetensors"

[train]
output_dir = "/path/to/output"
output_name = "my_lora"
train_data_dir = "/path/to/dataset"
resolution = "1024,1024"
train_batch_size = 1
max_train_epochs = 15
learning_rate = 1e-4
optimizer_type = "Prodigy"
network_module = "networks.lora"
network_dim = 32
network_alpha = 16
mixed_precision = "bf16"
save_every_n_epochs = 3
noise_offset = 0.1
clip_skip = 2  # For Pony
```

### Training Command

```bash
accelerate launch --num_cpu_threads_per_process 1 \
  sdxl_train_network.py \
  --config_file config.toml
```

### Parameter Mapping

| Our Parameter | Kohya Equivalent |
|--------------|-----------------|
| epochs | max_train_epochs |
| learning_rate | learning_rate |
| batch_size | train_batch_size |
| network_rank | network_dim |
| network_alpha | network_alpha |
| resolution | resolution |
| optimizer | optimizer_type |
| noise_offset | noise_offset |
| clip_skip | clip_skip |
| save_interval | save_every_n_epochs |

### Kohya Quirks

1. **Prodigy requires install**: `pip install prodigyopt`
2. **clip_skip**: Must match generation setting (2 for Pony, 1 for SDXL)
3. **Dataset structure**: Expects `{repeats}_{name}` folder naming (e.g., `10_mystyle`)
4. **Resolution**: Comma-separated, not "x" (use `1024,1024` not `1024x1024`)
5. **accelerate**: Must be installed and configured (`accelerate config` first run)
6. **xformers**: Optional but saves ~2GB VRAM on SDXL training

### Dataset Folder Structure

Kohya expects a specific folder layout:

```
train_data/
└── 10_mystyle/          # {repeats}_{concept}
    ├── image_001.png
    ├── image_001.txt     # caption
    ├── image_002.png
    ├── image_002.txt
    └── ...
```

The `10` prefix means each image is repeated 10 times per epoch. With 30 images and 10 repeats, that's 300 steps per epoch.

### Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| "CUDA out of memory" | Batch size too high | Reduce batch_size, enable xformers |
| "No module named 'lion_pytorch'" | Lion optimizer not installed | `pip install lion-pytorch` |
| "accelerate not found" | Missing dependency | `pip install accelerate && accelerate config` |
| Training produces black images | Learning rate too high | Reduce learning rate by 10x |
| LoRA has no effect | Too few training steps | Increase epochs or repeats |

## Sources
- [Kohya sd-scripts Repository](https://github.com/kohya-ss/sd-scripts)
- [Kohya Wiki](https://github.com/kohya-ss/sd-scripts/wiki)
