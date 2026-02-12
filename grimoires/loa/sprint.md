# Ategnatos Cycle 3 — Sprint Plan

**Version**: 3.0
**Date**: 2026-02-12
**Source PRD**: grimoires/loa/prd.md v3.0
**Source SDD**: grimoires/loa/sdd.md (Cycle 3 Addendum)
**Cycle**: 3 — Security, Resilience & Operational Maturity

---

## Overview

| Parameter | Value |
|-----------|-------|
| Team | 1 human (Creative Director) + AI (Claude Code) |
| Sprint count | 4 |
| Sprint duration | Flexible — milestone-based |
| Scope | Security hardening, state architecture, operational resilience, ComfyUI ops, specs |
| Total tasks | 24 |
| Source | Flatline Protocol adversarial review (GPT-5.2 + Claude Opus 4.6) |

### Sprint Dependency Chain

```
Sprint 1: Security Foundation (SEC-001, SEC-003)
         │
         ├── Sprint 2: Security Gates & State Architecture (SEC-002, STATE-001)
         │
         └── Sprint 3: Operational Resilience (OPS-001, OPS-003, COMFY-001)
                  │
                  └── Sprint 4: SSH, Recovery, Specs & E2E (OPS-002, OPS-004, COMFY-002, SPEC-001, SPEC-002)
```

Sprint 1 is the foundation — all security libraries must exist before they can be integrated.
Sprints 2 and 3 can run in parallel after Sprint 1.
Sprint 4 depends on Sprints 2 and 3.

---

## Sprint 1 (Global #11): Security Foundation

**Label**: Security Foundation
**Goal**: Establish the core security libraries and hardened scripting standard that all subsequent work depends on.

### Tasks

#### S1-T1: Create validate-lib.sh — Input Validation Library
**PRD Ref**: SEC-001
**SDD Ref**: C3.1 (Input Validation Library)
**File**: `.claude/scripts/lib/validate-lib.sh` (NEW)

**Description**: Create the input validation library with allowlist-based validators.

Functions to implement:
```bash
validate_path <path>                    # Rejects: .., symlink escapes, null bytes
validate_url <url>                      # Rejects: non-http(s), credentials in URL
validate_url_localhost <url>            # Requires: 127.0.0.1 or localhost
validate_provider_id <id>              # Allowlist: vast, runpod, lambda, local
validate_backend_id <id>               # Allowlist: kohya, simpletuner, ai-toolkit
validate_positive_int <value>          # Rejects: non-numeric, negative, zero
validate_json_file <path>              # Validates: exists, valid JSON, no eval-able content
```

**Acceptance Criteria**:
- All functions return 0 (valid) or 1 (invalid) with stderr message
- Path validation uses `realpath` to resolve symlinks, rejects paths outside project root
- Allowlists are hardcoded constants
- Script starts with `set -euo pipefail`

---

#### S1-T2: Create secrets-lib.sh — Secrets Management Library
**PRD Ref**: SEC-003
**SDD Ref**: C3.1 (Secrets Library)
**File**: `.claude/scripts/lib/secrets-lib.sh` (NEW)

**Description**: Create the secrets management library for credential loading and log redaction.

Functions to implement:
```bash
load_secret <name>                     # Load from env var → ~/.config/ategnatos/secrets → fail
redact_log <text>                      # Mask patterns: sk-*, ssh-*, API keys
safe_log <text>                        # echo "$(redact_log "$text")" >&2
```

Redaction patterns:
- `sk-[A-Za-z0-9]{10,}` → `sk-***<last4>`
- `ssh-[a-z]{3,}\s+\S+` → `ssh-***REDACTED`
- Long alphanumeric strings preceded by key/token/secret/password context

**Acceptance Criteria**:
- `load_secret VASTAI_API_KEY` loads from env var if set
- `load_secret VASTAI_API_KEY` falls back to `~/.config/ategnatos/secrets`
- `redact_log "my key is sk-abc123xyz789"` masks the key
- Secret file check enforces 0600 permissions
- Clear error message when secret not found

---

#### S1-T3: Create scripting-standard.md — Documentation
**PRD Ref**: SEC-001
**SDD Ref**: C3.1 (Hardened Scripting Standard)
**File**: `.claude/skills/studio/resources/scripting-standard.md` (NEW)

**Description**: Document the hardened scripting standard for all Ategnatos scripts.

Must cover:
1. `set -euo pipefail` requirement
2. Variable quoting rules
3. No `eval` policy
4. Input validation requirements
5. Array expansion rules
6. Temp file handling with `mktemp` + trap cleanup
7. shellcheck compliance
8. `# shellcheck disable` justification requirement

**Acceptance Criteria**:
- Document exists with all 8 rules
- Follows the standard resource file format (In Plain Language → What You Need to Know → Details)

---

#### S1-T4: Create secrets policy document
**PRD Ref**: SEC-003
**SDD Ref**: C3.1 (Secrets Library)
**File**: `.claude/skills/studio/resources/secrets-policy.md` (NEW)

**Description**: Document the secrets management policy.

Must cover:
- Where to store secrets (env vars or `~/.config/ategnatos/secrets`)
- Never store secrets in grimoire files or JSON state
- SSH key handling guidance
- Log redaction expectations

**Acceptance Criteria**:
- Document exists with clear guidance
- References `secrets-lib.sh` for implementation

---

#### S1-T5: Audit and fix existing scripts for shellcheck compliance
**PRD Ref**: SEC-001
**SDD Ref**: C3.1 (Hardened Scripting Standard)
**Files**: All scripts in `.claude/scripts/studio/`, `.claude/scripts/train/`, `.claude/scripts/lib/state-lib.sh`

**Description**: Run shellcheck on all existing Ategnatos scripts and fix warnings.

Steps:
1. Run `shellcheck` on each script
2. Fix all warnings (unquoted variables, missing `set -euo pipefail`, etc.)
3. Add `# shellcheck disable=SCXXXX` with justification where truly intentional
4. Verify `grep -r 'eval ' .claude/scripts/` returns zero results (Ategnatos scripts only)

**Acceptance Criteria**:
- All Ategnatos scripts pass shellcheck at default warning level
- No `eval` in any Ategnatos script
- All scripts have `set -euo pipefail`

---

#### S1-T6: Create test-validate-lib.sh and test-secrets-lib.sh
**PRD Ref**: SEC-001, SEC-003
**Files**: `tests/test-validate-lib.sh` (NEW), `tests/test-secrets-lib.sh` (NEW)

**Description**: Test suites for the new security libraries.

`test-validate-lib.sh` must test:
- Valid and invalid paths (including `..` traversal, null bytes)
- Valid and invalid URLs (http/https, credentials in URL)
- Localhost URL validation
- Provider ID allowlist (valid + invalid)
- Backend ID allowlist
- Positive integer validation
- JSON file validation

`test-secrets-lib.sh` must test:
- Loading secrets from env vars
- Loading secrets from file (with correct permissions)
- Rejection of secrets file with wrong permissions
- Redaction of `sk-` prefixed keys
- Redaction of `ssh-` keys
- Clear error on missing secret

**Acceptance Criteria**:
- Both test files execute successfully via `tests/run-all.sh`
- Cover happy path and error cases for each function

---

## Sprint 2 (Global #12): Security Gates & State Architecture

**Label**: Security Gates & State Architecture
**Goal**: Secure ComfyUI endpoints by default and establish JSON as the single canonical source of truth for state.

### Tasks

#### S2-T1: Create comfyui-security-check.sh
**PRD Ref**: SEC-002
**SDD Ref**: C3.1 (ComfyUI Security Gate)
**File**: `.claude/scripts/studio/comfyui-security-check.sh` (NEW)

**Description**: Create the ComfyUI endpoint security validation script.

Interface: `comfyui-security-check.sh --url <endpoint> [--allow-remote] [--json]`

Logic:
1. Parse URL → extract host
2. `127.0.0.1`, `localhost`, `::1` → PASS
3. Private IP (10.x, 172.16-31.x, 192.168.x) → WARN
4. Public IP → FAIL unless `--allow-remote`
5. If `--allow-remote`, verify SSH tunnel process exists

Must source `validate-lib.sh` for URL validation.

**Acceptance Criteria**:
- `comfyui-security-check.sh --url http://127.0.0.1:8188` exits 0
- `comfyui-security-check.sh --url http://203.0.113.5:8188` exits 1 with warning
- `--allow-remote` flag allows public IPs
- Uses `validate_url` from validate-lib.sh

---

#### S2-T2: Integrate security check into comfyui-submit.sh
**PRD Ref**: SEC-002
**SDD Ref**: C3.1
**File**: `.claude/scripts/studio/comfyui-submit.sh` (MODIFY)

**Description**: Add security gate to comfyui-submit.sh. Before submitting any workflow, call `comfyui-security-check.sh` to validate the endpoint.

**Changes**:
- Source `validate-lib.sh` and `secrets-lib.sh`
- Call `comfyui-security-check.sh` before submission
- Add `--allow-remote` passthrough flag
- Add `--skip-security` escape hatch for advanced users
- Wrap logging with `safe_log`

**Acceptance Criteria**:
- `comfyui-submit.sh` with remote URL exits 1 unless `--allow-remote`
- `--skip-security` bypasses the check
- No credentials appear in script output

---

#### S2-T3: Create ComfyUI security hardening guide
**PRD Ref**: SEC-002
**SDD Ref**: C3.1
**File**: `.claude/skills/studio/resources/comfyui/security.md` (NEW)

**Description**: Documentation for securing ComfyUI endpoints.

Must cover:
- Binding ComfyUI to 127.0.0.1 (not 0.0.0.0)
- Firewall rules for cloud GPU instances
- SSH tunnel setup (`ssh -L 8188:localhost:8188 user@gpu-instance`)
- Why unauthenticated ComfyUI on a public IP is dangerous
- Integration with `/studio` setup workflow

**Acceptance Criteria**:
- Document exists with concrete commands
- SSH tunnel example is copy-pasteable
- Follows standard resource file format

---

#### S2-T4: Enhance state-lib.sh — JSON canonical model
**PRD Ref**: STATE-001
**SDD Ref**: C3.2 (State Architecture Revised)
**File**: `.claude/scripts/lib/state-lib.sh` (MODIFY)

**Description**: Add drift detection, backup, and schema versioning to state-lib.sh.

New/modified functions:
```bash
state_sync "studio"                    # Now adds <!-- GENERATED --> header + source hash
state_check "studio"                   # Compares MD hash vs JSON hash, returns drift status
state_backup "studio"                  # Copies JSON + MD to .bak with timestamp
state_schema_version "studio"          # Returns _schema_version from JSON
```

Changes to `state_sync`:
- Output starts with: `<!-- GENERATED — DO NOT EDIT. Source: grimoire/.state/studio.json (hash: <sha256>) -->`
- Backup previous MD to `.bak` before overwriting

Changes to `state_init`:
- Add `"_schema_version": "1.0"` and `"_generated_at"` to new JSON files

Deprecation:
- `state_migrate` — add warning: "DEPRECATED: one-time migration utility only"

**Acceptance Criteria**:
- `state_sync` output starts with GENERATED comment containing hash
- `state_check "studio"` detects when MD was manually edited (hash mismatch)
- `state_backup "studio"` creates timestamped `.bak` files
- New JSON files include `_schema_version: "1.0"`
- Round-trip test: `state_sync → state_check` passes (exit 0)

---

#### S2-T5: Integrate security libs into provider scripts
**PRD Ref**: SEC-001, SEC-003
**Files**: `.claude/scripts/studio/provider-spinup.sh`, `.claude/scripts/studio/provider-teardown.sh`, `.claude/scripts/studio/provider-validate.sh`, `.claude/scripts/studio/providers/vastai-lifecycle.sh` (MODIFY)

**Description**: All provider scripts must source `validate-lib.sh` and `secrets-lib.sh`. Validate inputs. Use `safe_log` for any output that might contain credentials.

**Acceptance Criteria**:
- All provider scripts source both security libraries
- Provider IDs validated via `validate_provider_id`
- API key loading via `load_secret`
- Log output uses `safe_log`

---

#### S2-T6: Create test-comfyui-security.sh and test-state-enhanced.sh
**PRD Ref**: SEC-002, STATE-001
**Files**: `tests/test-comfyui-security.sh` (NEW), `tests/test-state-enhanced.sh` (NEW)

**Description**: Test suites for ComfyUI security and enhanced state management.

`test-comfyui-security.sh`:
- Localhost URL passes
- Public IP fails
- Private IP warns
- `--allow-remote` overrides

`test-state-enhanced.sh`:
- `state_sync` generates header with hash
- `state_check` passes after clean sync
- `state_check` fails after manual MD edit
- `state_backup` creates .bak files
- `state_schema_version` returns correct version

**Acceptance Criteria**:
- Both test files pass via `tests/run-all.sh`
- Cover all acceptance criteria from S2-T1 and S2-T4

---

## Sprint 3 (Global #13): Operational Resilience

**Label**: Operational Resilience
**Goal**: Prevent resource contention, enforce cost limits, and validate ComfyUI nodes before workflow submission.

### Tasks

#### S3-T1: Create resource-lock.sh — Advisory Lock Library
**PRD Ref**: OPS-001
**SDD Ref**: C3.3 (Resource Contention)
**File**: `.claude/scripts/lib/resource-lock.sh` (NEW)

**Description**: Create the advisory lock mechanism using lockfiles.

Functions:
```bash
lock_acquire <resource> [--timeout 30] [--holder "art"]
lock_release <resource>
lock_check <resource>                  # Returns JSON: holder, PID, time
lock_force_release <resource>          # Admin override
```

Lock file: `/tmp/ategnatos-lock-<resource_hash>.lock` containing JSON with resource, holder, pid, acquired_at.

Resource naming: `comfyui:<host>:<port>`, `gpu:<provider>:<instance_id>`, `training:<run_id>`

Stale detection: if PID not running (`kill -0 $pid`), auto-release with warning.

**Acceptance Criteria**:
- `lock_acquire comfyui:localhost:8188` creates lockfile
- Second `lock_acquire` on same resource fails with holder info
- `lock_release` cleans up lockfile
- Dead PID triggers auto-release

---

#### S3-T2: Create cost-guard.sh — Budget Enforcement Library
**PRD Ref**: OPS-003
**SDD Ref**: C3.4 (Cost Enforcement)
**Files**: `.claude/scripts/lib/cost-guard.sh` (NEW), `grimoire/cost-config.json` (NEW)

**Description**: Create cost enforcement library and default config.

Config file `grimoire/cost-config.json`:
```json
{
  "max_hourly_rate": 3.00,
  "max_total_cost": 50.00,
  "max_runtime_minutes": 480,
  "auto_teardown_minutes": 60,
  "require_confirm": true
}
```

Functions:
```bash
cost_check --operation <type> --estimated <amount>
cost_start_timer --resource <id> --max-minutes <N>
cost_stop_timer --resource <id>
cost_teardown_overdue
cost_report
```

Timer storage: `/tmp/ategnatos-cost-timer-<resource_hash>.json`

**Acceptance Criteria**:
- `cost_check --operation train --estimated 5.00` with `max_total_cost: 3.00` exits 1
- `cost_start_timer` creates timer file
- `cost_teardown_overdue` detects expired timers
- Default config created with sensible limits

---

#### S3-T3: Create comfyui-preflight.sh — Node Validation
**PRD Ref**: COMFY-001
**SDD Ref**: C3.7 (ComfyUI Preflight)
**File**: `.claude/scripts/studio/comfyui-preflight.sh` (NEW)

**Description**: Pre-flight check that validates all workflow nodes are installed.

Interface: `comfyui-preflight.sh --workflow <path.json> --url <endpoint> [--json]`

Steps:
1. Query ComfyUI `/object_info` → installed node types
2. Parse workflow JSON → extract all `class_type` values
3. Compare → report missing nodes
4. Look up missing in node-registry.md → provide install instructions
5. Exit 0 if all present, exit 1 if missing

Must source `validate-lib.sh` for input validation.

**Acceptance Criteria**:
- Correctly identifies installed vs missing nodes
- Reports install instructions from node registry
- `--json` outputs structured report
- Uses `validate_url` and `validate_json_file`

---

#### S3-T4: Create node-registry.md — ComfyUI Node Package Map
**PRD Ref**: COMFY-001
**SDD Ref**: C3.7 (Node Registry)
**File**: `.claude/skills/studio/resources/comfyui/node-registry.md` (NEW)

**Description**: Reference document mapping ComfyUI node class types to their packages.

Format:
```markdown
| Node Class | Package | Install Command | Notes |
|-----------|---------|----------------|-------|
| ControlNetApplyAdvanced | comfyui_controlnet_aux | cd custom_nodes && git clone ... | ControlNet |
| UpscaleModelLoader | built-in | N/A | Included with ComfyUI |
```

Cover nodes used in existing templates: txt2img-sdxl, txt2img-flux, lora-test, img2img, controlnet, upscale, batch.

**Acceptance Criteria**:
- All nodes from existing templates mapped
- Install commands are copy-pasteable
- Built-in vs custom clearly marked

---

#### S3-T5: Integrate preflight into comfyui-submit.sh
**PRD Ref**: COMFY-001
**SDD Ref**: C3.7
**File**: `.claude/scripts/studio/comfyui-submit.sh` (MODIFY)

**Description**: Run `comfyui-preflight.sh` before workflow submission.

**Changes**:
- Call `comfyui-preflight.sh` before submission (after security check)
- Add `--skip-preflight` flag to bypass
- On preflight failure: exit 1 with missing node list

**Acceptance Criteria**:
- Preflight runs by default before submission
- `--skip-preflight` bypasses the check
- Missing nodes reported clearly

---

#### S3-T6: Create test-resource-lock.sh, test-cost-guard.sh, test-comfyui-preflight.sh
**PRD Ref**: OPS-001, OPS-003, COMFY-001
**Files**: `tests/test-resource-lock.sh` (NEW), `tests/test-cost-guard.sh` (NEW), `tests/test-comfyui-preflight.sh` (NEW)

**Description**: Test suites for Sprint 3 deliverables.

`test-resource-lock.sh`:
- Acquire, check, release cycle
- Double-acquire fails
- Stale PID auto-release

`test-cost-guard.sh`:
- Budget check pass/fail
- Timer create/check/stop
- Overdue detection

`test-comfyui-preflight.sh`:
- Workflow parsing (extract class_type values)
- Missing node detection (mock /object_info response)

**Acceptance Criteria**:
- All three test files pass via `tests/run-all.sh`

---

## Sprint 4 (Global #14): SSH, Recovery, Specs & E2E

**Label**: SSH, Recovery, Specs & E2E
**Goal**: Complete SSH resilience, training recovery, remaining ComfyUI ops, specification documents, and validate all Cycle 3 goals end-to-end.

### Tasks

#### S4-T1: Create ssh-lib.sh — SSH Resilience Library
**PRD Ref**: OPS-002
**SDD Ref**: C3.5 (SSH Resilience)
**File**: `.claude/scripts/lib/ssh-lib.sh` (NEW)

**Description**: SSH execution library with retry, tmux, and phase markers.

Functions:
```bash
ssh_exec <host> <command> [--retries 3] [--backoff-base 5]
ssh_tmux_create <host> <session_name>
ssh_tmux_send <host> <session_name> <command>
ssh_tmux_attach <host> <session_name>
ssh_phase_mark <host> <phase_name>
ssh_phase_check <host> <phase_name>
ssh_reconnect_status <host>
```

Phase markers: `~/.ategnatos-phases/<phase_name>.done` on remote host.
Retry: exponential backoff (5s, 10s, 20s), connection timeout 10s per attempt.

Must source `validate-lib.sh` and `secrets-lib.sh`.

**Acceptance Criteria**:
- `ssh_exec` retries on connection failure
- Phase markers written and checked correctly
- tmux session creation is idempotent
- Uses `safe_log` for output containing host/key info

---

#### S4-T2: Enhance monitor-training.sh — Disk & Checkpoint Monitoring
**PRD Ref**: OPS-004
**SDD Ref**: C3.6 (Training Recovery)
**File**: `.claude/scripts/train/monitor-training.sh` (MODIFY)

**Description**: Add disk space monitoring, checkpoint integrity validation, and training-state.json management.

New capabilities:
1. Disk space: `df -h <training_dir>` — warn at 90%, abort at 95%
2. Checkpoint integrity: verify file size > 0, file not still being written
3. Process health: verify training PID is still running
4. VRAM usage logging

New file: `grimoire/training/training-state.json` — persisted metadata:
```json
{
  "run_id": "train-20260212-120000",
  "backend": "kohya",
  "config_path": "workspace/configs/mystyle.toml",
  "dataset_path": "workspace/datasets/mystyle/",
  "output_dir": "workspace/training/mystyle/",
  "status": "running",
  "started_at": "...",
  "last_checkpoint": "...",
  "last_checkpoint_at": "...",
  "total_steps": 1500,
  "completed_steps": 750,
  "provider": "vast",
  "instance_id": "12345"
}
```

Resume command per backend:
- Kohya: `--network_weights <checkpoint> --initial_epoch <epoch>`
- SimpleTuner: `--resume_from_checkpoint <checkpoint>`
- AI-Toolkit: restart with same config (auto-resumes)

**Acceptance Criteria**:
- Disk space check warns at 90%, aborts at 95%
- Checkpoint size > 0 validation
- training-state.json written and updated
- Resume command correct per backend

---

#### S4-T3: Create comfyui-version-check.sh + compatibility.md
**PRD Ref**: COMFY-002
**SDD Ref**: C3.7
**Files**: `.claude/scripts/studio/comfyui-version-check.sh` (NEW), `.claude/skills/studio/resources/comfyui/compatibility.md` (NEW)

**Description**: Version pinning for ComfyUI.

Script: `comfyui-version-check.sh --url <endpoint> [--json]`
- Queries ComfyUI API for version/commit info
- Compares against minimum supported version from compatibility.md
- Reports pass/fail

Document: minimum supported ComfyUI version, known breaking changes, template version tagging.

**Acceptance Criteria**:
- Script queries ComfyUI and returns version info
- Compatibility doc specifies minimum version
- `--json` outputs structured result

---

#### S4-T4: Create captioning-protocol.md
**PRD Ref**: SPEC-001
**File**: `.claude/skills/train/resources/workflows/captioning-protocol.md` (NEW)

**Description**: Concrete specification for the style-aware captioning protocol.

Must include:
- VLM prompt templates for content and style captioning
- Output format: `{trigger_word}, {content_description}, {style_description}`
- Token budget per caption (target: 50-150 tokens)
- Batch processing strategy
- Quality gate: minimum caption length, required style terms, trigger word presence
- Example captions demonstrating content + style separation

Integration: reference from `dataset-audit.sh` for caption quality metrics.

**Acceptance Criteria**:
- Concrete prompt templates (copy-pasteable)
- Example captions for at least 3 image types
- Quality gate thresholds defined
- Token budget documented

---

#### S4-T5: Create provider-contract.md
**PRD Ref**: SPEC-002
**File**: `.claude/skills/studio/resources/providers/provider-contract.md` (NEW)

**Description**: Formal interface specification for GPU provider adapters.

Must include:
- Required functions: `spinup()`, `teardown()`, `status()`, `ssh_connect()`
- State machine: `PENDING → RUNNING → STOPPING → TERMINATED`
- Idempotency rules
- Timeout policy per operation
- Required outputs: instance_id, ssh_host, ssh_port, gpu_type, cost_per_hour
- Billing detection
- Contract test checklist for adapter validation

**Acceptance Criteria**:
- State machine diagram (text-based)
- All required functions documented with signatures
- Idempotency rules explicit
- Contract test checklist usable for validation

---

#### S4-T6: End-to-End Goal Validation
**PRD Ref**: All
**SDD Ref**: All

**Description**: Validate that all Cycle 3 PRD goals are achieved.

| Goal | Validation Action | Expected Result |
|------|-------------------|-----------------|
| Zero critical security gaps | `shellcheck .claude/scripts/**/*.sh` + `grep -r 'eval '` | shellcheck clean, no eval |
| ComfyUI endpoints secured | `comfyui-security-check.sh --url http://127.0.0.1:8188` + test with public IP | Pass/fail as expected |
| Secrets never in logs | `grep -r 'API_KEY\|SECRET\|PASSWORD' grimoire/` | Zero results |
| Single source of truth | `state_sync → state_check` round-trip | Hash matches |
| Enforceable cost protection | `cost_check` with over-budget amount | Exits 1 |
| Training survives interruptions | `training-state.json` schema validation + resume command check | Valid state + correct commands |
| Custom node validation | `comfyui-preflight.sh` with mock data | Detects missing nodes |
| Resource contention prevented | `lock_acquire` → second acquire | Second fails |

Run full test suite: `tests/run-all.sh`

**Acceptance Criteria**:
- All 8 PRD goals validated
- All test suites pass
- No regressions in Cycle 1/2 functionality

---

## Summary

| Sprint | Global ID | Label | Tasks | PRD Requirements |
|--------|-----------|-------|-------|------------------|
| 1 | 11 | Security Foundation | 6 | SEC-001, SEC-003 |
| 2 | 12 | Security Gates & State Architecture | 6 | SEC-002, STATE-001 |
| 3 | 13 | Operational Resilience | 6 | OPS-001, OPS-003, COMFY-001 |
| 4 | 14 | SSH, Recovery, Specs & E2E | 6 | OPS-002, OPS-004, COMFY-002, SPEC-001, SPEC-002 |

## Appendix A: PRD Requirement Mapping

| PRD Requirement | Severity | Sprint | Tasks |
|----------------|----------|--------|-------|
| SEC-001 (Scripting Standard) | 930 | Sprint 1 | S1-T1, S1-T3, S1-T5, S1-T6 |
| SEC-003 (Secrets Management) | 880 | Sprint 1 | S1-T2, S1-T4, S1-T6 |
| SEC-002 (ComfyUI Endpoint Security) | 900 | Sprint 2 | S2-T1, S2-T2, S2-T3, S2-T6 |
| STATE-001 (JSON Canonical) | 780 | Sprint 2 | S2-T4, S2-T6 |
| OPS-001 (Resource Lock) | 815 | Sprint 3 | S3-T1, S3-T6 |
| OPS-003 (Cost Enforcement) | 740 | Sprint 3 | S3-T2, S3-T6 |
| COMFY-001 (Node Validation) | 850 | Sprint 3 | S3-T3, S3-T4, S3-T5, S3-T6 |
| OPS-002 (SSH Resilience) | 770 | Sprint 4 | S4-T1 |
| OPS-004 (Training Recovery) | 710 | Sprint 4 | S4-T2 |
| COMFY-002 (Version Pinning) | — | Sprint 4 | S4-T3 |
| SPEC-001 (Captioning Protocol) | 845 | Sprint 4 | S4-T4 |
| SPEC-002 (Provider Contract) | 760 | Sprint 4 | S4-T5 |

## Appendix B: SDD Component Mapping

| SDD Component | Sprint | Tasks |
|---------------|--------|-------|
| C3.1 validate-lib.sh | Sprint 1 | S1-T1 |
| C3.1 secrets-lib.sh | Sprint 1 | S1-T2 |
| C3.1 scripting-standard.md | Sprint 1 | S1-T3 |
| C3.1 comfyui-security-check.sh | Sprint 2 | S2-T1 |
| C3.2 state-lib.sh enhancements | Sprint 2 | S2-T4 |
| C3.3 resource-lock.sh | Sprint 3 | S3-T1 |
| C3.4 cost-guard.sh | Sprint 3 | S3-T2 |
| C3.5 ssh-lib.sh | Sprint 4 | S4-T1 |
| C3.6 monitor-training.sh | Sprint 4 | S4-T2 |
| C3.7 comfyui-preflight.sh | Sprint 3 | S3-T3 |
| C3.7 node-registry.md | Sprint 3 | S3-T4 |
| C3.8 File system additions | Sprints 1-4 | All |
| C3.9 Threat model | Sprint 4 | S4-T6 (validation) |

---

*Sprint plan generated from Cycle 3 PRD and SDD. All tasks trace to Flatline Protocol findings via PRD requirement IDs.*
