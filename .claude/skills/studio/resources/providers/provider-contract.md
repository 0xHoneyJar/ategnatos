# Provider Adapter Contract

## In Plain Language
Every cloud GPU provider (Vast.ai, RunPod, Lambda, etc.) works differently under the hood, but the framework needs them all to behave the same way. This contract defines exactly what every provider adapter script must do. If you're building a new adapter (e.g., `vastai-lifecycle.sh` or `runpod-lifecycle.sh`), it must implement every function listed here and follow these rules precisely.

## What You Need to Know

### Required Functions

Every provider adapter must implement all six of these functions:

| Function | Arguments | Returns | Description |
|----------|-----------|---------|-------------|
| `spinup` | `--gpu TYPE --disk GB --template NAME [--budget $/hr] [--yes] [--json]` | Instance ID, SSH connection details | Create and start a GPU instance |
| `teardown` | `--instance ID [--yes] [--json]` | Exit 0 on success | Destroy a specific instance |
| `teardown-all` | `[--yes]` | Exit 0 on success | Destroy ALL instances |
| `list` | `[--json]` | Instance list | List active instances |
| `pull` | `--instance ID --remote PATH --local PATH` | Exit 0 on success | Download files from instance |
| `ssh-info` | `--instance ID [--json]` | SSH host, port, key | Get SSH connection details |

### State Machine

Every instance follows this lifecycle. No shortcuts, no skipped states.

```
         spinup
IDLE ──────────→ PENDING
                    │
                    │ (provider confirms running)
                    ▼
                 RUNNING
                    │
              teardown │
                    ▼
                STOPPING
                    │
                    │ (provider confirms destroyed)
                    ▼
               TERMINATED
```

**Transitions:**
- `IDLE → PENDING`: `spinup` called, provider has accepted the request
- `PENDING → RUNNING`: GPU allocated and SSH accessible
- `RUNNING → STOPPING`: `teardown` called, destruction in progress
- `STOPPING → TERMINATED`: Instance fully destroyed, billing stopped
- `PENDING → TERMINATED`: Timeout or allocation failure (no GPU available, budget exceeded, etc.)

### Idempotency Rules

These are non-negotiable. Every adapter must handle repeated or out-of-order calls gracefully.

- `spinup` when already RUNNING: return existing instance info, do NOT create a second instance
- `teardown` when already TERMINATED: return success (exit 0), do nothing
- `teardown` when PENDING: cancel the pending allocation
- `list` when no instances: return empty array, not an error
- `pull` when TERMINATED: error with a clear message ("Instance 12345 is terminated. Nothing to download.")

### Timeout Policy

| Operation | Default Timeout | Escalation |
|-----------|----------------|------------|
| spinup | 5 minutes | Report "still pending" every 60s |
| teardown | 2 minutes | Force destroy if available |
| SSH connect | 10 seconds | Retry 3x with backoff |
| pull (scp) | 10 minutes | Depends on file size |

If `spinup` exceeds the timeout, the adapter must transition the instance to TERMINATED (cleaning up the allocation) and return a clear error explaining what happened.

### Required Outputs

Every `spinup` must return this structure (in JSON mode, via `--json`):

```json
{
  "instance_id": "12345",
  "provider": "vastai",
  "gpu": "RTX_3090",
  "ssh_host": "ssh4.vast.ai",
  "ssh_port": 12345,
  "cost_per_hour": 0.38,
  "status": "RUNNING",
  "started_at": "2026-02-12T10:00:00Z"
}
```

All fields are required. `cost_per_hour` must be a number (not a string). `started_at` must be ISO 8601 UTC.

### Billing Detection

- The adapter must report `cost_per_hour` in `spinup` output
- The adapter must detect when billing actually starts (some providers bill from allocation, others from ready)
- `teardown` must confirm billing has stopped before returning success
- If billing status cannot be confirmed, `teardown` must warn the user: "Could not confirm billing stopped. Check your provider dashboard."

### Contract Test Checklist

Use this checklist to validate any new adapter before it ships. Every box must be checked.

```markdown
- [ ] spinup creates instance and returns required JSON
- [ ] spinup with --json returns valid JSON
- [ ] spinup idempotent (second call returns same instance)
- [ ] list shows the running instance
- [ ] ssh-info returns valid SSH connection details
- [ ] SSH connection succeeds with returned details
- [ ] pull downloads test file successfully
- [ ] teardown destroys the instance
- [ ] teardown idempotent (second call succeeds)
- [ ] list shows no instances after teardown
- [ ] teardown-all destroys all instances
- [ ] Error messages are clear and actionable
```

## Why This Matters
A provider adapter that doesn't follow this contract will cause real problems: orphaned instances burning money, failed training runs that can't recover, or SSH connections that silently break. The idempotency rules and state machine exist because network calls fail, users retry commands, and training sessions must be resumable. Every rule here was written to prevent wasted GPU time and unexpected charges.

## Sources
- Provider-specific guides: `vastai.md`, `runpod.md`, `lambda.md`, `local.md`
- Cost protection rules: `.claude/rules/cost-protection.md`
