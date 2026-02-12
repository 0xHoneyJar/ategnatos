# Evaluation Workflow — Phases 11-13

This workflow evaluates the trained LoRA, diagnoses problems, and registers successful models.

## Phase 11: LoRA Evaluation

1. **Generate evaluation grid** using `.claude/scripts/train/eval-grid.sh`:
   - Run: `eval-grid.sh --lora <path> --model <base> --prompt "<test>" --trigger <word>`
   - Generates images at weights 0.3, 0.5, 0.7, 0.9, 1.0
   - Uses fixed seed for fair comparison across weights
   - Falls back to saving workflow JSONs if ComfyUI isn't running

2. **Use standardized test prompts** from `resources/evaluation/eval-methodology.md`:
   - Style LoRAs: portrait, landscape, still life, animal, abstract
   - Character LoRAs: full body, close-up, sitting, outdoors, action
   - Object LoRAs: isolated, in context, held, close-up, multiple

3. **Compare checkpoints** if multiple are available:
   - Generate the same grid for 2-3 checkpoints (early, mid, final)
   - The mid-training checkpoint is often better than the final one

4. **Find the sweet spot** using `resources/evaluation/strength-guide.md`:
   - Look at 0.5 first (most likely sweet spot for style LoRAs)
   - Check faces — are they still clean?
   - Check style — is it visible?
   - Narrow down: if 0.5 is too subtle and 0.7 distorts, try 0.6

5. **Present structured comparison**:
   ```
   Weight 0.3: Style barely visible — good for subtle blending
   Weight 0.5: Style clearly present, faces clean — SWEET SPOT
   Weight 0.7: Strong style, minor face softening — usable
   Weight 0.9: Very strong, some distortion — use cautiously
   Weight 1.0: Maximum effect, quality degradation — not recommended
   ```

6. **Store results** in `grimoire/training/{name}/eval.md`:
   ```markdown
   # Evaluation: {name}
   - **Sweet spot**: 0.5-0.7
   - **Recommended weight**: 0.6
   - **Quality at sweet spot**: Clean faces, strong style, good detail
   - **Issues at high weight**: Minor face softening above 0.8
   - **Checkpoint used**: epoch-15 (final)
   - **Test prompts**: 5 standard prompts + 2 custom
   ```

## Phase 12: Failure Diagnosis

If evaluation reveals problems, use `resources/training/failure-modes.md`:

1. **Identify the symptom** — what does the output look like?
2. **Map to cause** — the guide maps every common symptom to its root cause
3. **Apply the fix** — specific, actionable instructions for each failure
4. **Explain in plain language** — "Your LoRA is copying your training images instead of learning the general style. This means it saw the same images too many times. Use the checkpoint from halfway through training, or retrain with fewer epochs."

Common diagnoses:
- Blurry → overtrained → use earlier checkpoint
- Ignores trigger → undertrained → more epochs
- Copies training images → overfit → reduce epochs + add diversity
- Wrong colors → captions missing color info → recaption
- Only works at 1.0 → weak training signal → more epochs or higher rank

## Phase 13: LoRA Registration

On approval, register the LoRA so `/art` can use it:

1. **Add to `grimoire/studio.md`** in the LoRAs section:
   ```markdown
   ### LoRA: {name}
   - **File**: {path to .safetensors}
   - **Type**: style / character / object
   - **Trigger word**: {trigger}
   - **Recommended weight**: {sweet spot}
   - **Base model**: {model it was trained on}
   - **Good for**: {what it does well}
   - **Training date**: {date}
   - **Training params**: {preset}, {epochs} epochs, rank {rank}
   ```

2. **Verify `/art` integration**:
   - `/art` reads `grimoire/studio.md` for available LoRAs
   - When the user mentions the style/character/concept, `/art` includes the LoRA
   - Trigger word is automatically added to prompts
   - Weight is set to the recommended value from evaluation

3. **Close the training project**:
   - Update `grimoire/training/{name}/status.md` to COMPLETE
   - Archive evaluation images to `grimoire/training/{name}/eval/`
