# SimpleTuner Adapter

## In Plain Language
SimpleTuner is a training tool focused on making LoRA training (teaching AI models new styles) simpler. It handles images of different sizes automatically and has good defaults, so you need less configuration. It's newer than Kohya but gaining popularity, especially for Flux models.

## What You Need to Know

### Installation
```bash
git clone https://github.com/bghira/SimpleTuner
cd SimpleTuner
pip install -r requirements.txt
```

### Config Format

SimpleTuner uses a combination of environment variables and JSON/YAML configs:

```bash
# config/config.env
export MODEL_NAME="/path/to/model.safetensors"
export OUTPUT_DIR="/path/to/output"
export INSTANCE_DIR="/path/to/dataset"
export RESOLUTION=1024
export TRAIN_BATCH_SIZE=1
export MAX_NUM_STEPS=3000
export LEARNING_RATE=1e-4
export OPTIMIZER="prodigy"
export LORA_RANK=32
export LORA_ALPHA=16
export MIXED_PRECISION="bf16"
export CHECKPOINTING_STEPS=500
export NOISE_OFFSET=0.1
```

### Training Command

```bash
bash train.sh
# or
python train.py --config_path config/config.env
```

### Parameter Mapping

| Our Parameter | SimpleTuner Equivalent |
|--------------|----------------------|
| epochs | Calculated from MAX_NUM_STEPS |
| learning_rate | LEARNING_RATE |
| batch_size | TRAIN_BATCH_SIZE |
| network_rank | LORA_RANK |
| network_alpha | LORA_ALPHA |
| resolution | RESOLUTION |
| optimizer | OPTIMIZER |
| noise_offset | NOISE_OFFSET |
| save_interval | CHECKPOINTING_STEPS |

### SimpleTuner Advantages

1. **Multi-aspect-ratio training**: Automatically handles images of different sizes
2. **Prodigy built-in**: No extra install needed
3. **Flux support**: Better native Flux LoRA training than Kohya
4. **Simpler dataset format**: Just put images + captions in a folder

### Dataset Folder Structure

SimpleTuner is simpler than Kohya:

```
dataset/
├── image_001.png
├── image_001.txt
├── image_002.jpg
├── image_002.txt
└── ...
```

No special folder naming. Just images and matching .txt caption files.

### Steps vs Epochs

SimpleTuner uses total steps instead of epochs. To convert:
```
total_steps = (num_images * repeats * epochs) / batch_size
```

Example: 30 images, 1 repeat, 15 epochs, batch 1 = 450 steps.

### Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| "CUDA out of memory" | Batch size or resolution too high | Reduce batch_size or resolution |
| "Cannot find model" | Wrong path in config | Use absolute path to model |
| Training doesn't start | Environment not set | Source the config.env before running |
| Poor quality output | Too few steps | Increase MAX_NUM_STEPS |

## Sources
- [SimpleTuner Repository](https://github.com/bghira/SimpleTuner)
- [SimpleTuner Documentation](https://github.com/bghira/SimpleTuner/wiki)
