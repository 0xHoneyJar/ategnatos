# Ategnatos Cycle 3 — Security, Resilience & Operational Maturity

**Version**: 3.0
**Date**: 2026-02-12
**Cycle**: 3
**Previous**: Cycle 2 — "Hardening & Functional Completeness" (archived 2026-02-12)
**Status**: Draft

> Source: Flatline Protocol adversarial review (GPT-5.2 + Claude Opus 4.6, 2026-02-12).
> All requirements trace to specific Flatline findings with consensus scores.

---

## 1. Context

Cycle 2 delivered functional completeness: img2img/ControlNet support, batch generation, workflow management, dataset structuring, dry-run validation, state management library, and a test framework (22 tasks, 31 files, +4,682 lines). The framework is now functionally capable but operationally immature.

Adversarial cross-model review (Flatline Protocol) identified 8 high-consensus improvements and 7 blockers. The top 3 blockers are all security-related (severity 880-930). The remaining blockers concern state architecture brittleness, provider abstraction gaps, cost enforcement, and training resilience.

This cycle addresses these findings in priority order: **security first**, then **architectural resolution**, then **operational resilience**.

## 2. Goals

| Goal | Metric | Source |
|------|--------|--------|
| Zero critical security gaps in scripts | All scripts pass shellcheck + input validation audit | SEC-001 (930) |
| ComfyUI endpoints secured by default | Localhost-only, SSH tunnel documented, security gate script | SEC-002 (900) |
| Secrets never in logs or state files | Audit passes for all provider/ComfyUI scripts | SEC-003 (880) |
| Single source of truth for state | JSON canonical, MD generated read-only, no two-way sync | STATE-001 (780) |
| Enforceable cost protection | Hard budget limits, auto-teardown timer, billing watchdog | COST-001 (740) |
| Training survives interruptions | Resume from checkpoint, disk monitoring, artifact validation | TRAIN-001 (710) |
| ComfyUI custom node validation | Preflight detects missing nodes before workflow submission | IMP-004 (850) |
| Resource contention prevented | Lock mechanism prevents concurrent /art + /train on same GPU | IMP-002 (815) |

## 3. Requirements

### 3.1 Security Hardening (P0)

#### SEC-001: Hardened Scripting Standard
**Flatline**: severity 930, both models flagged
**Current**: Scripts use `set -euo pipefail` inconsistently. No input validation. No safe quoting enforcement. `eval` may exist in some paths. jq filters accept untrusted input.
**Need**:
- All scripts MUST use `set -euo pipefail`
- Input validation library: `validate_path()`, `validate_url()`, `validate_provider_id()` with allowlists
- No `eval` anywhere. No unquoted variable expansions in command positions
- shellcheck passes on all scripts (zero warnings at default level)
- bats test suite for security-sensitive functions
- Document the standard in `resources/scripting-standard.md`

**Acceptance Criteria**:
- `shellcheck .claude/scripts/**/*.sh` exits 0
- `grep -r 'eval ' .claude/scripts/` returns zero results
- Input validation library exists with tests
- All provider/ComfyUI scripts use validation functions for external input

#### SEC-002: ComfyUI Endpoint Security
**Flatline**: severity 900, both models flagged
**Current**: `COMFYUI_URL` stored in `studio.md` as plain text. No auth. No transport security. Remote endpoints exposed on cloud GPUs are unauthenticated.
**Need**:
- Default to `http://127.0.0.1:8188` (localhost only)
- `comfyui-security-check.sh` — validates endpoint is localhost OR reachable via SSH tunnel
- Warn if endpoint is a public IP without tunnel
- Document ComfyUI hardening: bind to 127.0.0.1, firewall rules, SSH tunnel setup
- `comfyui-submit.sh` refuses non-localhost endpoints unless `--allow-remote` is explicitly passed
- Add to provider spinup workflow: "Set up SSH tunnel to ComfyUI"

**Acceptance Criteria**:
- `comfyui-security-check.sh --url http://127.0.0.1:8188` exits 0
- `comfyui-security-check.sh --url http://203.0.113.5:8188` exits 1 with warning
- `comfyui-submit.sh` with remote URL exits 1 unless `--allow-remote`
- Hardening guide exists in `resources/comfyui/security.md`

#### SEC-003: Secrets Management
**Flatline**: severity 880, both models flagged
**Current**: No explicit policy for credential handling. Provider scripts may log API keys. SSH key paths stored in plaintext. No log redaction.
**Need**:
- Secrets policy document: env vars or `~/.config/ategnatos/secrets` (0600 perms)
- `secrets-lib.sh` — `load_secret()`, `redact_log()` functions
- All provider scripts use `secrets-lib.sh` for credential loading
- Log redaction: any output containing key patterns (`sk-`, `ssh-`, API URLs with tokens) is masked
- SSH key handling guidance in provider docs
- Never store secrets in grimoire files or JSON state

**Acceptance Criteria**:
- `grep -r 'API_KEY\|SECRET\|PASSWORD' grimoire/` returns zero results
- All provider scripts source `secrets-lib.sh`
- `redact_log "sk-abc123xyz"` outputs `sk-***xyz`
- Secrets policy document exists

### 3.2 State Architecture Resolution (P0)

#### STATE-001: JSON Canonical, Markdown Generated
**Flatline**: severity 780 (blocker) + avg 755 (high consensus improvement)
**Current**: Cycle 2 introduced `state-lib.sh` with `state_sync` (JSON→MD) and `state_migrate` (MD→JSON). This creates a two-way sync risk — manual edits to MD diverge from JSON.
**Need**:
- Declare JSON as the single canonical source of truth
- Markdown files generated from JSON are marked `<!-- GENERATED — DO NOT EDIT. Use /studio to modify. -->`
- Remove `state_migrate` from the normal workflow (keep as one-time migration utility only)
- All skill commands that modify state MUST go through `state_set`/`state_append`/`state_remove`
- `state_sync` adds a header comment and a hash of the JSON source for drift detection
- `state_check` function: compare hash in MD header vs current JSON hash, warn on drift
- Schema version field in JSON: `"_schema_version": "1.0"`
- Atomic writes: write to `.tmp`, then `mv` (already implemented)
- Backup before sync: copy previous MD to `.bak`

**Acceptance Criteria**:
- `grimoire/studio.md` contains `<!-- GENERATED -->` header
- Editing `grimoire/studio.md` manually triggers drift warning on next `/studio` invocation
- `state_check "studio"` detects tampering
- JSON has `_schema_version` field
- Round-trip test: `state_sync → state_check` passes

### 3.3 Operational Resilience (P1)

#### OPS-001: Resource Contention Lock
**Flatline**: avg 815 (high consensus)
**Current**: Nothing prevents `/art` and `/train` from using the same ComfyUI endpoint or GPU simultaneously. Concurrent use causes OOM, corrupted outputs, or billing surprises.
**Need**:
- `resource-lock.sh` — advisory lock mechanism using lockfiles
- `lock_acquire <resource> [--timeout N]` — creates `/tmp/ategnatos-lock-<resource>.lock` with PID
- `lock_release <resource>` — removes lockfile
- `lock_check <resource>` — returns holder info or "available"
- Resources: `comfyui:<host>:<port>`, `gpu:<provider>:<instance_id>`
- Skills check lock before any GPU/ComfyUI operation
- Stale lock detection: if PID in lockfile is dead, auto-release
- Lock info displayed: "ComfyUI is currently in use by /train (PID 12345, started 10m ago). Wait or cancel?"

**Acceptance Criteria**:
- `lock_acquire comfyui:localhost:8188` creates lockfile
- Second `lock_acquire` on same resource fails with holder info
- `lock_release` cleans up
- Dead PID auto-releases

#### OPS-002: SSH Resilience for Remote GPU
**Flatline**: avg 770 (high consensus)
**Current**: Provider scripts assume persistent SSH connections. SSH drops during training or generation corrupt perceived state.
**Need**:
- Provider spinup scripts configure tmux session on remote instance
- All remote commands wrapped in `ssh_exec()` that retries with exponential backoff (3 attempts)
- Idempotent phase markers: each step writes a `.phase-complete` marker file on remote
- `reconnect_check()` — on SSH reconnect, reads phase markers to determine where to resume
- Training launch uses `nohup` or tmux so process survives SSH drop
- Document: "If your SSH drops, reconnect and run `/studio status` to check"

**Acceptance Criteria**:
- `ssh_exec "hostname" --retries 3` retries on connection failure
- Training processes survive SSH disconnection (tmux-based)
- Phase markers written after each major step

#### OPS-003: Enforceable Cost Protection
**Flatline**: severity 740 (blocker)
**Current**: Cost protection is conversational — the skill asks "shall I proceed?" but scripts themselves have no limits. Scripts invoked directly skip all prompts.
**Need**:
- `cost-config.json` in grimoire: `max_hourly_rate`, `max_total_cost`, `max_runtime_minutes`, `auto_teardown_minutes`
- `cost-guard.sh` — reads config, enforces limits
  - `cost_check --operation <type> --estimated <amount>` — fails if would exceed budget
  - `cost_start_timer --resource <id> --max-minutes <N>` — starts background watchdog
  - `cost_teardown_overdue` — checks all running timers, tears down overdue instances
- All billable scripts call `cost_check` before proceeding
- `--confirm` flag required on billable operations (no silent execution)
- Billing watchdog: `cost_watchdog.sh` — periodic check (can be run via cron or manual)

**Acceptance Criteria**:
- `cost_check --operation train --estimated 5.00` with `max_total_cost: 3.00` exits 1
- `cost_start_timer --resource vast-123 --max-minutes 120` creates timer
- Timer expiry triggers teardown warning
- Scripts without `--confirm` refuse billable operations

#### OPS-004: Training Mid-Run Recovery
**Flatline**: severity 710 (blocker)
**Current**: Gates 1-4 validate before training starts. No mechanism handles mid-run failures: spot preemption, disk fills, corrupted checkpoints, SSH drops.
**Need**:
- `monitor-training.sh` enhanced with:
  - Checkpoint integrity validation (file size, loadability)
  - Disk space monitoring (warn at 90%, abort at 95%)
  - Resume capability: detect last valid checkpoint, construct resume command per backend
- `training-state.json` — persisted metadata: run ID, backend, config path, last checkpoint, start time, status
- Resume workflow: `/train resume` reads `training-state.json`, validates checkpoint, restarts from last good point
- Each backend's resume command documented:
  - Kohya: `--resume <checkpoint_path>`
  - SimpleTuner: `--resume_from_checkpoint <path>`
  - AI-Toolkit: restart with same config (auto-resumes from last checkpoint)

**Acceptance Criteria**:
- `training-state.json` written on training start, updated on each checkpoint
- `monitor-training.sh` detects low disk space
- `/train resume` constructs correct resume command per backend
- Checkpoint validation catches truncated/corrupt files

### 3.4 ComfyUI Operational Improvements (P1)

#### COMFY-001: Custom Node Validation
**Flatline**: avg 850 (highest consensus improvement)
**Current**: Workflows reference custom nodes. If a node isn't installed, ComfyUI returns an opaque error. Users waste time debugging missing nodes.
**Need**:
- `comfyui-preflight.sh` — queries ComfyUI `/object_info` endpoint for installed nodes
- Parses workflow JSON for all node types used
- Compares against installed nodes, reports missing ones with install instructions
- Maintains `resources/comfyui/node-registry.md` — maps node types to custom node packages
- Run automatically before `comfyui-submit.sh` (can be skipped with `--skip-preflight`)

**Acceptance Criteria**:
- `comfyui-preflight.sh --workflow templates/controlnet-sdxl.json --url http://localhost:8188` lists missing nodes
- Known nodes mapped in registry
- `comfyui-submit.sh` runs preflight by default

#### COMFY-002: ComfyUI Version Pinning
**Flatline**: 100% PRD agreement
**Current**: No version requirements documented. Workflow templates may silently break on ComfyUI updates.
**Need**:
- `comfyui-version-check.sh` — queries ComfyUI API for version info
- Minimum supported version documented in `resources/comfyui/compatibility.md`
- Workflow templates tagged with minimum ComfyUI version in a comment header
- Version check runs during `/studio` setup and before workflow submission

**Acceptance Criteria**:
- `comfyui-version-check.sh --url http://localhost:8188` returns version
- Compatibility doc specifies minimum version
- Templates have version comment

### 3.5 Specification Gaps (P2)

#### SPEC-001: Captioning Protocol Specification
**Flatline**: avg 845 (high consensus)
**Current**: Train skill describes style-aware captioning conceptually but lacks concrete specification — no prompts, output schema, batching strategy, or quality gates.
**Need**:
- `resources/workflows/captioning-protocol.md` — concrete specification:
  - VLM prompt templates for content captioning and style captioning
  - Output format: `{trigger_word}, {content_description}, {style_description}`
  - Token budget per caption (target: 50-150 tokens)
  - Batch processing strategy (N images per VLM call)
  - Quality gate: minimum caption length, required style terms, trigger word presence
- Integrate with `dataset-audit.sh` — check caption quality as part of Gate 1

**Acceptance Criteria**:
- Protocol document with concrete prompt templates
- `dataset-audit.sh --json` includes caption quality metrics
- Example captions demonstrate content + style separation

#### SPEC-002: Provider Contract Definition
**Flatline**: severity 760 (blocker)
**Current**: Provider abstraction assumes all providers have the same interface. Real providers differ in APIs, billing, instance states, and image handling.
**Need**:
- `resources/providers/provider-contract.md` — concrete interface specification:
  - Required functions: `spinup()`, `teardown()`, `status()`, `ssh_connect()`
  - State machine: `PENDING → RUNNING → STOPPING → TERMINATED`
  - Idempotency rules: `teardown()` on already-terminated instance returns success
  - Timeout policy per operation
  - Required outputs: instance_id, ssh_host, ssh_port, gpu_type, cost_per_hour
  - Billing detection: how to confirm billing stopped
- Each provider adapter validated against contract

**Acceptance Criteria**:
- Contract document with state machine diagram
- Vast.ai adapter implements all contract functions
- Contract test suite validates adapter compliance

## 4. Scope

### In Scope (Cycle 3)
- 3 security hardening requirements (P0)
- 1 state architecture resolution (P0)
- 4 operational resilience requirements (P1)
- 2 ComfyUI operational improvements (P1)
- 2 specification gaps (P2)

### Out of Scope
- Style Intelligence tool (separate product — see `context/style-intelligence-research.md`)
- New generation model support (SD3, etc.)
- Video/animation
- Team/collaboration features
- Provider abstraction rewrite (contract spec only — implementation deferred)

## 5. Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Security hardening breaks existing scripts | Functional regression | Run test suite before/after each change |
| State migration to JSON-canonical loses user data | Data loss | Backup-before-migrate, round-trip tests |
| Cost guard too restrictive | Blocks legitimate operations | Configurable limits, `--override` escape hatch |
| Resource lock creates deadlocks | Operations blocked indefinitely | Stale PID detection, timeout, manual `lock_release` |
| shellcheck may flag patterns that are intentional | False positive noise | Use `# shellcheck disable=SCXXXX` with justification comments |

## 6. Priority Order

1. **SEC-001** (scripting standard) — foundation for everything else
2. **SEC-003** (secrets management) — needed before SEC-002
3. **SEC-002** (ComfyUI endpoint security) — depends on SEC-003 for credential handling
4. **STATE-001** (JSON canonical) — resolves architectural blocker
5. **OPS-001** (resource lock) — quick win, high impact
6. **COMFY-001** (node validation) — quick win, highest consensus score
7. **OPS-003** (cost enforcement) — depends on state resolution
8. **OPS-002** (SSH resilience) — depends on provider scripts being secure
9. **OPS-004** (training recovery) — depends on state + monitoring
10. **COMFY-002** (version pinning) — low effort
11. **SPEC-001** (captioning protocol) — documentation, no code dependency
12. **SPEC-002** (provider contract) — documentation, deferred implementation

---

*PRD generated from Flatline Protocol adversarial review findings (GPT-5.2 + Claude Opus 4.6). All requirements trace to specific blocker IDs and consensus scores.*
