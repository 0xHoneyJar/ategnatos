#!/usr/bin/env bash
# state-lib.sh — Structured JSON state management for grimoire files
# Usage: source this file, then call state_* functions
#
# Provides a JSON backing store for grimoire markdown files.
# JSON is the source of truth; markdown is regenerated from it.
# Requires: jq

# Guard against double-sourcing
[[ -n "${_STATE_LIB_LOADED:-}" ]] && return 0
_STATE_LIB_LOADED=1

STATE_DIR="${STATE_DIR:-grimoire/.state}"

# ──────────────────────────────────────────────
# state_init <scope>
# Create the JSON backing store for a scope
# ──────────────────────────────────────────────
state_init() {
  local scope="$1"
  if [[ -z "$scope" ]]; then
    echo "Error: state_init requires a scope name." >&2
    return 1
  fi

  mkdir -p "$STATE_DIR"

  local json_file="$STATE_DIR/${scope}.json"
  if [[ -f "$json_file" ]]; then
    echo "State file already exists: $json_file" >&2
    return 0
  fi

  case "$scope" in
    studio)
      cat > "$json_file" <<'JSON'
{
  "environment": {
    "gpu": null,
    "cuda_version": null,
    "driver_version": null,
    "vram_gb": null,
    "comfyui": null
  },
  "models": [],
  "loras": [],
  "active_instances": []
}
JSON
      ;;
    *)
      echo '{}' > "$json_file"
      ;;
  esac

  echo "$json_file"
}

# ──────────────────────────────────────────────
# state_get <scope> <jq_path>
# Read a value from state
# ──────────────────────────────────────────────
state_get() {
  local scope="$1"
  local jq_path="$2"

  if [[ -z "$scope" || -z "$jq_path" ]]; then
    echo "Error: state_get requires scope and jq_path." >&2
    return 1
  fi

  local json_file="$STATE_DIR/${scope}.json"
  if [[ ! -f "$json_file" ]]; then
    echo "Error: State file not found: $json_file" >&2
    return 1
  fi

  jq -r "$jq_path" "$json_file"
}

# ──────────────────────────────────────────────
# state_set <scope> <jq_path> <value>
# Set a value in state
# ──────────────────────────────────────────────
state_set() {
  local scope="$1"
  local jq_path="$2"
  local value="$3"

  if [[ -z "$scope" || -z "$jq_path" ]]; then
    echo "Error: state_set requires scope, jq_path, and value." >&2
    return 1
  fi

  local json_file="$STATE_DIR/${scope}.json"
  if [[ ! -f "$json_file" ]]; then
    echo "Error: State file not found: $json_file. Run state_init first." >&2
    return 1
  fi

  local tmp_file="${json_file}.tmp"

  # Detect if value is valid JSON (object, array, number, boolean, null)
  if echo "$value" | jq empty 2>/dev/null; then
    jq "$jq_path = $value" "$json_file" > "$tmp_file"
  else
    # Treat as string
    jq --arg val "$value" "$jq_path = \$val" "$json_file" > "$tmp_file"
  fi

  mv "$tmp_file" "$json_file"
}

# ──────────────────────────────────────────────
# state_append <scope> <jq_path> <json_object>
# Append an object to an array in state
# ──────────────────────────────────────────────
state_append() {
  local scope="$1"
  local jq_path="$2"
  local object="$3"

  if [[ -z "$scope" || -z "$jq_path" || -z "$object" ]]; then
    echo "Error: state_append requires scope, jq_path, and object." >&2
    return 1
  fi

  local json_file="$STATE_DIR/${scope}.json"
  if [[ ! -f "$json_file" ]]; then
    echo "Error: State file not found: $json_file" >&2
    return 1
  fi

  local tmp_file="${json_file}.tmp"
  jq --argjson obj "$object" "$jq_path += [\$obj]" "$json_file" > "$tmp_file"
  mv "$tmp_file" "$json_file"
}

# ──────────────────────────────────────────────
# state_remove <scope> <jq_path> <key> <value>
# Remove objects from an array where key matches value
# ──────────────────────────────────────────────
state_remove() {
  local scope="$1"
  local jq_path="$2"
  local key="$3"
  local value="$4"

  if [[ -z "$scope" || -z "$jq_path" || -z "$key" || -z "$value" ]]; then
    echo "Error: state_remove requires scope, jq_path, key, and value." >&2
    return 1
  fi

  local json_file="$STATE_DIR/${scope}.json"
  if [[ ! -f "$json_file" ]]; then
    echo "Error: State file not found: $json_file" >&2
    return 1
  fi

  local tmp_file="${json_file}.tmp"
  jq --arg k "$key" --arg v "$value" \
    "$jq_path |= map(select(.[\$k] != \$v))" "$json_file" > "$tmp_file"
  mv "$tmp_file" "$json_file"
}

# ──────────────────────────────────────────────
# state_sync <scope>
# Regenerate markdown from JSON state
# ──────────────────────────────────────────────
state_sync() {
  local scope="$1"

  if [[ -z "$scope" ]]; then
    echo "Error: state_sync requires a scope." >&2
    return 1
  fi

  local json_file="$STATE_DIR/${scope}.json"
  if [[ ! -f "$json_file" ]]; then
    echo "Error: State file not found: $json_file" >&2
    return 1
  fi

  case "$scope" in
    studio) _sync_studio "$json_file" ;;
    *) echo "Error: No sync template for scope: $scope" >&2; return 1 ;;
  esac
}

# Internal: generate grimoire/studio.md from JSON
_sync_studio() {
  local json_file="$1"
  local md_file="grimoire/studio.md"

  {
    echo "# Studio"
    echo ""
    echo "## Environment"
    echo ""

    local gpu cuda driver vram comfyui
    gpu=$(jq -r '.environment.gpu // "Not detected"' "$json_file")
    cuda=$(jq -r '.environment.cuda_version // "N/A"' "$json_file")
    driver=$(jq -r '.environment.driver_version // "N/A"' "$json_file")
    vram=$(jq -r '.environment.vram_gb // "N/A"' "$json_file")
    comfyui=$(jq -r '.environment.comfyui // "Not detected"' "$json_file")

    echo "- **GPU**: $gpu"
    echo "- **CUDA**: $cuda"
    echo "- **Driver**: $driver"
    echo "- **VRAM**: ${vram}GB"
    echo "- **ComfyUI**: $comfyui"
    echo ""

    echo "## Models"
    echo ""

    local model_count
    model_count=$(jq '.models | length' "$json_file")
    if (( model_count > 0 )); then
      echo "| Name | Type | Base | Good For | Location | Settings |"
      echo "|------|------|------|----------|----------|----------|"
      jq -r '.models[] | "| \(.name) | \(.type) | \(.base) | \(.good_for) | \(.location) | \(.settings) |"' "$json_file"
    else
      echo "No models registered yet."
    fi
    echo ""

    echo "## LoRAs"
    echo ""

    local lora_count
    lora_count=$(jq '.loras | length' "$json_file")
    if (( lora_count > 0 )); then
      echo "| Name | Trigger | Weight Range | Trained On | Location |"
      echo "|------|---------|-------------|------------|----------|"
      jq -r '.loras[] | "| \(.name) | \(.trigger) | \(.weight_range) | \(.trained_on) | \(.location) |"' "$json_file"
    else
      echo "No LoRAs registered yet."
    fi
    echo ""

    echo "## Active Instances"
    echo ""

    local instance_count
    instance_count=$(jq '.active_instances | length' "$json_file")
    if (( instance_count > 0 )); then
      echo "| Provider | GPU | Status | Cost/hr | Started |"
      echo "|----------|-----|--------|---------|---------|"
      jq -r '.active_instances[] | "| \(.provider) | \(.gpu) | \(.status) | \(.cost_hr) | \(.started) |"' "$json_file"
    else
      echo "No active instances."
    fi
  } > "$md_file"

  echo "$md_file"
}

# ──────────────────────────────────────────────
# state_migrate <scope>
# Parse existing markdown into JSON state
# ──────────────────────────────────────────────
state_migrate() {
  local scope="$1"

  if [[ -z "$scope" ]]; then
    echo "Error: state_migrate requires a scope." >&2
    return 1
  fi

  case "$scope" in
    studio) _migrate_studio ;;
    *) echo "Error: No migration template for scope: $scope" >&2; return 1 ;;
  esac
}

# Internal: parse grimoire/studio.md into JSON
_migrate_studio() {
  local md_file="grimoire/studio.md"
  local json_file="$STATE_DIR/studio.json"

  if [[ ! -f "$md_file" ]]; then
    echo "Error: $md_file not found." >&2
    return 1
  fi

  mkdir -p "$STATE_DIR"

  local json='{"environment":{},"models":[],"loras":[],"active_instances":[]}'

  # Parse environment section
  local gpu cuda driver vram comfyui
  gpu=$(sed -n 's/.*\*\*GPU\*\*:\s*//p' "$md_file" | head -1)
  cuda=$(sed -n 's/.*\*\*CUDA\*\*:\s*//p' "$md_file" | head -1)
  driver=$(sed -n 's/.*\*\*Driver\*\*:\s*//p' "$md_file" | head -1)
  vram=$(sed -n 's/.*\*\*VRAM\*\*:\s*\([0-9.]*\).*/\1/p' "$md_file" | head -1)
  comfyui=$(sed -n 's/.*\*\*ComfyUI\*\*:\s*//p' "$md_file" | head -1)

  json=$(echo "$json" | jq \
    --arg gpu "${gpu:-}" \
    --arg cuda "${cuda:-}" \
    --arg driver "${driver:-}" \
    --arg vram "${vram:-}" \
    --arg comfyui "${comfyui:-}" \
    '.environment = {gpu: $gpu, cuda_version: $cuda, driver_version: $driver, vram_gb: $vram, comfyui: $comfyui}')

  local in_models=false
  local in_loras=false
  local in_instances=false

  while IFS= read -r line; do
    if echo "$line" | grep -q "| Name | Type | Base |"; then
      in_models=true; in_loras=false; in_instances=false; continue
    elif echo "$line" | grep -q "| Name | Trigger |"; then
      in_loras=true; in_models=false; in_instances=false; continue
    elif echo "$line" | grep -q "| Provider | GPU |"; then
      in_instances=true; in_models=false; in_loras=false; continue
    fi

    echo "$line" | grep -q '^|[-|]*|$' && continue

    if $in_models && echo "$line" | grep -q '^|'; then
      local name type base good_for location settings
      name=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$2); print $2}')
      type=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$3); print $3}')
      base=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$4); print $4}')
      good_for=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$5); print $5}')
      location=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$6); print $6}')
      settings=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$7); print $7}')
      [[ -z "$name" ]] && continue
      json=$(echo "$json" | jq --arg n "$name" --arg t "$type" --arg b "$base" \
        --arg g "$good_for" --arg l "$location" --arg s "$settings" \
        '.models += [{"name":$n,"type":$t,"base":$b,"good_for":$g,"location":$l,"settings":$s}]')
    fi

    if $in_loras && echo "$line" | grep -q '^|'; then
      local name trigger weight_range trained_on location
      name=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$2); print $2}')
      trigger=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$3); print $3}')
      weight_range=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$4); print $4}')
      trained_on=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$5); print $5}')
      location=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$6); print $6}')
      [[ -z "$name" ]] && continue
      json=$(echo "$json" | jq --arg n "$name" --arg t "$trigger" --arg w "$weight_range" \
        --arg tr "$trained_on" --arg l "$location" \
        '.loras += [{"name":$n,"trigger":$t,"weight_range":$w,"trained_on":$tr,"location":$l}]')
    fi

    if $in_instances && echo "$line" | grep -q '^|'; then
      local provider gpu status cost_hr started
      provider=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$2); print $2}')
      gpu=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$3); print $3}')
      status=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$4); print $4}')
      cost_hr=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$5); print $5}')
      started=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$6); print $6}')
      [[ -z "$provider" ]] && continue
      json=$(echo "$json" | jq --arg p "$provider" --arg g "$gpu" --arg s "$status" \
        --arg c "$cost_hr" --arg st "$started" \
        '.active_instances += [{"provider":$p,"gpu":$g,"status":$s,"cost_hr":$c,"started":$st}]')
    fi
  done < "$md_file"

  echo "$json" | jq '.' > "$json_file"
  echo "$json_file"
}
