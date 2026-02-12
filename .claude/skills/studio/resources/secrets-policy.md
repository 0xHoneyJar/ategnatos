# Secrets Management Policy

## In Plain Language
Secrets are things like passwords, API keys, and SSH keys. This policy defines where to put them, where to never put them, and how to keep them out of logs and committed files.

## What You Need to Know

### What Counts as a Secret

All of the following are secrets and must be handled according to this policy:

- API keys (Civitai, HuggingFace, cloud provider APIs)
- SSH private keys
- Authentication tokens (OAuth, bearer tokens, session tokens)
- Passwords
- Cloud provider credentials (AWS keys, GCP service account JSON, Vast.ai API key, RunPod API key)
- Webhook URLs that contain embedded tokens

When in doubt, treat it as a secret.

### Where to Store Secrets

There are exactly two acceptable locations, in order of preference:

**Option 1: Environment Variables (Preferred)**

Set secrets as environment variables in your shell profile (`~/.bashrc`, `~/.zshrc`, or `~/.zprofile`). Scripts read them at runtime without ever writing them to disk in the project.

```bash
# In your shell profile (~/.bashrc or ~/.zshrc)
export CIVITAI_API_KEY="your-key-here"
export RUNPOD_API_KEY="your-key-here"
export HUGGINGFACE_TOKEN="your-token-here"
export VASTAI_API_KEY="your-key-here"
```

Scripts load them via `secrets-lib.sh`:

```bash
source "$(dirname "$0")/secrets-lib.sh"

# load_secret checks the environment, falls back to secrets file, fails loudly if missing
civitai_key="$(load_secret "CIVITAI_API_KEY")"
```

**Option 2: Local Secrets File (Fallback)**

If environment variables are not practical (for example, multiple isolated environments), store secrets in:

```
~/.config/ategnatos/secrets
```

This file must have `0600` permissions (owner read/write only). No other user on the system can read it.

```bash
# Create the secrets file with correct permissions
mkdir -p ~/.config/ategnatos
touch ~/.config/ategnatos/secrets
chmod 0600 ~/.config/ategnatos/secrets
```

Format is one `KEY=value` per line, no shell syntax, no `export`:

```
CIVITAI_API_KEY=your-key-here
RUNPOD_API_KEY=your-key-here
HUGGINGFACE_TOKEN=your-token-here
VASTAI_API_KEY=your-key-here
```

`load_secret` from `secrets-lib.sh` checks the environment first, then falls back to this file.

### Where Secrets Must Never Be

Secrets must never appear in any of the following locations. This is not a suggestion.

| Forbidden Location | Why |
|-------------------|-----|
| `grimoire/` files (any `.md` file) | These are designed to be read, shared, and persisted. Secrets in grimoire files will eventually leak. |
| JSON state files | State files may be logged, committed, or transmitted. |
| Any committed file | Git history is permanent. A secret committed once is compromised forever, even if you delete it in the next commit. |
| Script source code | Hardcoded credentials in scripts are the most common source of leaked secrets in open-source projects. |
| Log output | Logs are stored, displayed, and sometimes uploaded. See the Log Redaction section below. |

### SSH Key Handling

SSH keys are used to connect to cloud GPU instances. Private keys require special care.

**Do**: Use `ssh-agent` to manage SSH keys in memory.

```bash
# Start ssh-agent (if not already running)
eval "$(ssh-agent -s)"

# Add your key to the agent (you'll be prompted for passphrase once)
ssh-add ~/.ssh/id_ed25519

# Connect to remote — agent provides the key automatically
ssh user@gpu-instance.example.com
```

**Do**: Generate per-provider keys stored in `~/.ssh/` with restrictive permissions.

```bash
ssh-keygen -t ed25519 -f ~/.ssh/runpod_key -C "ategnatos-runpod"
chmod 0600 ~/.ssh/runpod_key
```

**Never**: Copy private keys into grimoire files, training project directories, or any path inside the repository.

**Never**: Log or display the contents of a private key file.

**Never**: Use a private key without a passphrase on shared or cloud machines.

### Log Redaction

All script output that might contain secrets must be piped through `redact_log()` from `secrets-lib.sh`. This function replaces known secret patterns with `[REDACTED]`.

```bash
source "$(dirname "$0")/secrets-lib.sh"

# GOOD — output is redacted before display
curl -H "Authorization: Bearer ${token}" "${api_url}" 2>&1 | redact_log

# GOOD — safe_log wraps echo with automatic redaction
safe_log "Connecting to ${provider} with key ${api_key}"
# Output: "Connecting to runpod with key [REDACTED]"

# BAD — raw output may contain secrets in error messages
curl -H "Authorization: Bearer ${token}" "${api_url}"

# BAD — echo can print secrets to terminal and log files
echo "Using API key: ${api_key}"
```

### secrets-lib.sh Function Reference

| Function | What It Does |
|----------|-------------|
| `load_secret NAME` | Returns the value of secret `NAME`. Checks environment variables first, then `~/.config/ategnatos/secrets`. Exits with error if not found. |
| `redact_log` | Pipe filter. Replaces any known secret values in stdin with `[REDACTED]`. Use as `command \| redact_log`. |
| `safe_log MESSAGE` | Prints a message to stderr with automatic redaction of any embedded secret values. Replacement for `echo` in scripts that handle secrets. |

## Why This Matters

A leaked API key can drain a cloud account in hours. Vast.ai and RunPod keys have direct access to spin up GPU instances at several dollars per hour. A Civitai key or HuggingFace token can be used to upload content under your identity. An exposed SSH key grants shell access to your running GPU instances.

The damage is not hypothetical. Automated bots scan GitHub for committed credentials within minutes of a push. Once a secret is in a public commit, it must be considered compromised and rotated immediately, even if you force-push to remove the commit. Git history preserval means the secret is still recoverable.

Following this policy costs nothing. Violating it can cost everything from a surprise cloud bill to unauthorized access to your infrastructure.

## Details (For the Curious)

### How load_secret Works

```
1. Check if environment variable $NAME is set and non-empty
   -> If yes, return its value
2. Check if ~/.config/ategnatos/secrets exists
   -> If yes, parse it for a line starting with NAME=
   -> If found, return the value after the =
3. Neither source has the secret
   -> Print error to stderr: "Secret NAME not found"
   -> Exit 1
```

The two-tier approach means environment variables always take precedence. This lets you override the secrets file for testing or CI without modifying it.

### How redact_log Works

When `secrets-lib.sh` is sourced, it builds a list of all currently loaded secret values (from both environment variables and the secrets file). `redact_log` performs a `sed` replacement for each known value, substituting it with `[REDACTED]`.

This means `redact_log` only catches secrets it knows about. If a command leaks a secret that was not loaded through `load_secret`, it will not be caught. This is why the rule is: always use `load_secret` to access secrets, and always pipe external command output through `redact_log`.

### Why 0600 Permissions

Unix file permissions `0600` mean:
- Owner: read + write
- Group: nothing
- Others: nothing

This prevents other users on the same machine (including other accounts on a shared cloud GPU instance) from reading your secrets file. The `6` gives the owner read (4) + write (2). The two `0`s give group and others no access at all.

### Rotating a Compromised Secret

If a secret has been exposed (committed to git, printed in logs, or displayed on screen during a shared session):

1. Revoke the compromised credential immediately on the provider's website
2. Generate a new credential
3. Update your environment variable or `~/.config/ategnatos/secrets`
4. If the secret was committed to git, treat the entire repository history as potentially compromised. Do not rely on `git rebase` or `BFG Repo-Cleaner` alone as proof of removal.
