# ai-toolkit Adapter

## In Plain Language
ai-toolkit (by Ostris) is a lightweight tool for training LoRAs (style and character add-ons for AI models). It uses a clean, readable config file format and requires minimal setup. Good for users who want a simpler alternative to Kohya.

## What You Need to Know

### Installation
```bash
git clone https://github.com/ostris/ai-toolkit
cd ai-toolkit
pip install -r requirements.txt
```

### Config Format

ai-toolkit uses YAML configs:

```yaml
job: train
config:
  name: "my_lora"
  process:
    - type: sd_trainer
      training_folder: "/path/to/output"
      device: cuda:0
      network:
        type: lora
        linear: 32          # network_dim/rank
        linear_alpha: 16    # network_alpha
      save:
        dtype: float16
        save_every: 500     # steps
      datasets:
        - folder_path: "/path/to/dataset"
          caption_ext: txt
          resolution: 1024
          batch_size: 1
      train:
        batch_size: 1
        steps: 3000
        lr: 1e-4
        optimizer: adamw
        noise_scheduler: ddpm
        noise_offset: 0.1
        dtype: bf16
      model:
        name_or_path: "/path/to/model.safetensors"
        is_xl: true
```

### Training Command

```bash
python run.py config.yaml
```

### Parameter Mapping

| Our Parameter | ai-toolkit Equivalent |
|--------------|---------------------|
| epochs | Calculated from train.steps |
| learning_rate | train.lr |
| batch_size | train.batch_size |
| network_rank | network.linear |
| network_alpha | network.linear_alpha |
| resolution | datasets[].resolution |
| optimizer | train.optimizer |
| noise_offset | train.noise_offset |
| save_interval | save.save_every |

### ai-toolkit Advantages

1. **Simple YAML config**: Easy to read and modify
2. **Single command**: Just `python run.py config.yaml`
3. **Good defaults**: Less configuration needed
4. **Active development**: Regular updates

### Dataset Folder Structure

Same as SimpleTuner — flat directory:

```
dataset/
├── image_001.png
├── image_001.txt
├── image_002.jpg
├── image_002.txt
└── ...
```

### Steps vs Epochs

Like SimpleTuner, ai-toolkit uses total steps. Same conversion:
```
total_steps = (num_images * epochs) / batch_size
```

### Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| "CUDA out of memory" | Resolution or batch too high | Reduce values |
| "is_xl must be true" | SDXL model not flagged | Set `is_xl: true` in model config |
| Training very slow | No mixed precision | Set `dtype: bf16` |
| "Module not found" | Missing dependency | `pip install -r requirements.txt` again |

## Sources
- [ai-toolkit Repository](https://github.com/ostris/ai-toolkit)
