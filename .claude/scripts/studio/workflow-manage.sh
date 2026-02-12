#!/usr/bin/env bash
# workflow-manage.sh — Manage ComfyUI workflow templates
# Usage: workflow-manage.sh <command> [args]
#
# Commands:
#   list                         List all available workflows
#   get <name>                   Output workflow JSON to stdout
#   save <name> <workflow.json>  Save a workflow to user collection
#   delete <name>                Delete a user-saved workflow

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILTIN_DIR="${SCRIPT_DIR}/../skills/studio/resources/comfyui/templates"
USER_DIR="grimoire/workflows"

usage() {
  cat <<'USAGE'
Usage: workflow-manage.sh <command> [args]

Manage ComfyUI workflow templates.

Commands:
  list                         List all available workflows (built-in + saved)
  get <name>                   Output workflow JSON to stdout
  save <name> <workflow.json>  Save a workflow to your collection
  delete <name>                Delete a user-saved workflow

Built-in templates (read-only) come from the framework.
Saved workflows (read/write) are stored in grimoire/workflows/.

Examples:
  workflow-manage.sh list
  workflow-manage.sh get txt2img-sdxl
  workflow-manage.sh save my-portrait workflow.json
  workflow-manage.sh delete my-portrait
USAGE
}

COMMAND="${1:-}"
shift 2>/dev/null || true

case "$COMMAND" in
  list)
    echo "=== Available Workflows ==="
    echo ""

    # Built-in templates
    if [[ -d "$BUILTIN_DIR" ]]; then
      BUILTIN_COUNT=0
      for f in "$BUILTIN_DIR"/*.json; do
        [[ -f "$f" ]] || continue
        NAME=$(basename "$f" .json)
        echo "  [built-in]  $NAME"
        BUILTIN_COUNT=$((BUILTIN_COUNT + 1))
      done
      if (( BUILTIN_COUNT == 0 )); then
        echo "  (no built-in templates found)"
      fi
    else
      echo "  (built-in template directory not found)"
    fi

    echo ""

    # User-saved workflows
    if [[ -d "$USER_DIR" ]]; then
      USER_COUNT=0
      for f in "$USER_DIR"/*.json; do
        [[ -f "$f" ]] || continue
        NAME=$(basename "$f" .json)
        echo "  [saved]     $NAME"
        USER_COUNT=$((USER_COUNT + 1))
      done
      if (( USER_COUNT == 0 )); then
        echo "  (no saved workflows yet)"
      fi
    else
      echo "  (no saved workflows yet)"
    fi
    ;;

  get)
    NAME="${1:-}"
    if [[ -z "$NAME" ]]; then
      echo "Error: No workflow name specified." >&2
      echo "Usage: workflow-manage.sh get <name>" >&2
      exit 1
    fi

    # Check user-saved first (user overrides take priority)
    if [[ -f "$USER_DIR/${NAME}.json" ]]; then
      cat "$USER_DIR/${NAME}.json"
    elif [[ -f "$BUILTIN_DIR/${NAME}.json" ]]; then
      cat "$BUILTIN_DIR/${NAME}.json"
    else
      echo "Error: Workflow not found: $NAME" >&2
      echo "Run 'workflow-manage.sh list' to see available workflows." >&2
      exit 1
    fi
    ;;

  save)
    NAME="${1:-}"
    SOURCE="${2:-}"

    if [[ -z "$NAME" || -z "$SOURCE" ]]; then
      echo "Error: Both name and source file are required." >&2
      echo "Usage: workflow-manage.sh save <name> <workflow.json>" >&2
      exit 1
    fi

    if [[ ! -f "$SOURCE" ]]; then
      echo "Error: Source file not found: $SOURCE" >&2
      exit 1
    fi

    # Validate JSON
    if ! jq empty "$SOURCE" 2>/dev/null; then
      echo "Error: Invalid JSON in: $SOURCE" >&2
      exit 1
    fi

    mkdir -p "$USER_DIR"
    cp "$SOURCE" "$USER_DIR/${NAME}.json"
    echo "Saved workflow: $NAME"
    echo "  Location: $USER_DIR/${NAME}.json"
    ;;

  delete)
    NAME="${1:-}"
    if [[ -z "$NAME" ]]; then
      echo "Error: No workflow name specified." >&2
      echo "Usage: workflow-manage.sh delete <name>" >&2
      exit 1
    fi

    # Prevent deleting built-in templates
    if [[ -f "$BUILTIN_DIR/${NAME}.json" && ! -f "$USER_DIR/${NAME}.json" ]]; then
      echo "Error: Cannot delete built-in template: $NAME" >&2
      echo "Built-in templates are part of the framework and are read-only." >&2
      exit 1
    fi

    if [[ ! -f "$USER_DIR/${NAME}.json" ]]; then
      echo "Error: Saved workflow not found: $NAME" >&2
      exit 1
    fi

    rm "$USER_DIR/${NAME}.json"
    echo "Deleted workflow: $NAME"
    ;;

  --help|-h|help)
    usage
    ;;

  "")
    usage
    exit 1
    ;;

  *)
    echo "Error: Unknown command: $COMMAND" >&2
    echo "Run 'workflow-manage.sh --help' for usage." >&2
    exit 1
    ;;
esac
