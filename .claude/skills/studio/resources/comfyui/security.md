# ComfyUI Security Hardening

## In Plain Language
ComfyUI has no login screen, no passwords, no user accounts. If someone can reach the port it's running on, they can do anything: generate images, read your files, or hijack your GPU for crypto mining. This guide shows you how to lock it down so only you can access it, whether you're running locally or on a cloud GPU instance.

## What You Need to Know

### 1. Always Bind to Localhost

When starting ComfyUI, make sure it only listens on your local machine:

```bash
python main.py --listen 127.0.0.1 --port 8188
```

- `127.0.0.1` means "only accept connections from this machine."
- The default behavior (no `--listen` flag) is safe — it already binds to localhost.
- **Never use `--listen 0.0.0.0`** unless you have a firewall and SSH tunnel in place. That flag makes ComfyUI accept connections from any IP address on the internet.

### 2. Firewall Rules for Cloud GPU Instances

When you rent a cloud GPU (Vast.ai, RunPod, Lambda, etc.), the instance is on the public internet. Lock it down immediately:

```bash
# Ubuntu/Debian — run these as root or with sudo
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw enable
```

This does three things:
- Blocks all incoming traffic by default
- Allows outgoing traffic (so you can download models, pip install, etc.)
- Allows SSH so you can still connect

**Do not add a rule for port 8188.** That port should never be open to the internet. Access ComfyUI through an SSH tunnel instead (see below).

To verify your firewall is active:

```bash
ufw status verbose
```

### 3. SSH Tunnel Setup

An SSH tunnel lets you access a remote ComfyUI as if it were running on your own machine. All traffic is encrypted and goes through your SSH connection.

**Basic command:**

```bash
ssh -L 8188:localhost:8188 user@gpu-instance
```

**With an SSH key (typical for cloud providers):**

```bash
ssh -i ~/.ssh/my_key -L 8188:localhost:8188 user@gpu-instance
```

What this does:
- `-L 8188:localhost:8188` forwards your local port 8188 to port 8188 on the remote machine.
- After running this command, open `http://localhost:8188` in your browser and you'll see the remote ComfyUI.
- Keep the SSH session open while you're generating. If the tunnel drops, just reconnect.

**With a custom SSH port (some providers use non-standard ports):**

```bash
ssh -i ~/.ssh/my_key -p 22222 -L 8188:localhost:8188 user@gpu-instance
```

### 4. Why Unauthenticated ComfyUI on a Public IP Is Dangerous

If you run `--listen 0.0.0.0` on a cloud instance without a firewall, anyone on the internet can:

| Risk | What Happens |
|------|-------------|
| **Workflow injection** | Anyone can submit workflows, generating whatever they want on your GPU |
| **File read/write** | ComfyUI nodes can read and write files on the server. Your models, training data, and system files are exposed |
| **GPU hijacking** | Crypto miners run automated scans for exposed GPU services. They will find open ComfyUI instances within minutes |
| **Data exfiltration** | Your LoRAs, checkpoints, and training images can be downloaded by anyone |
| **Resource exhaustion** | Someone can queue hundreds of generations, burning through your GPU rental budget |

This is not theoretical. Exposed GPU services on cloud instances are actively scanned and exploited. A $3/hr GPU rental can turn into a $200 surprise bill overnight.

### 5. Integration with Ategnatos

The framework has built-in protections:

- **`comfyui-security-check.sh`** runs automatically before every workflow submission. It verifies the endpoint is `localhost` or `127.0.0.1`.
- If you're connecting to a remote ComfyUI through an SSH tunnel, use the `--allow-remote` flag. This tells the framework you've intentionally set up a secure tunnel.
- If the framework detects a non-localhost endpoint without `--allow-remote`, it will block the submission and warn you:
  > "ComfyUI endpoint is not localhost. If you've set up an SSH tunnel, re-run with --allow-remote. If not, see the security guide."

### Quick Reference

| Scenario | What to Do |
|----------|-----------|
| Local machine | Default is fine. Or: `python main.py --listen 127.0.0.1 --port 8188` |
| Cloud GPU — setup | `ufw default deny incoming && ufw allow ssh && ufw enable` |
| Cloud GPU — access | `ssh -L 8188:localhost:8188 user@gpu-instance` |
| Ategnatos remote | Use `--allow-remote` after setting up SSH tunnel |
| Exposed instance found | Kill ComfyUI immediately, enable firewall, check for unauthorized files |

## Why This Matters
A single exposed ComfyUI instance can cost you hundreds of dollars in hijacked GPU time, leak your proprietary models and training data, and turn your rented server into a crypto mining rig. Every security step here takes under a minute to set up. The alternative is finding out the hard way.

## Details

### Verifying Your Setup

After configuring everything, confirm your security posture:

```bash
# Check ComfyUI is only listening on localhost
ss -tlnp | grep 8188
# Should show 127.0.0.1:8188, NOT 0.0.0.0:8188 or :::8188

# Check firewall status
ufw status

# Test from another machine (should fail/timeout)
curl http://your-gpu-ip:8188/system_stats
# Should timeout or be refused
```

### If You Suspect Compromise

1. Kill ComfyUI: `pkill -f "python main.py"`
2. Enable the firewall: `ufw enable`
3. Check for unauthorized processes: `ps aux | grep -E "mine|xmrig|crypto"`
4. Check for unfamiliar files in the ComfyUI output directory
5. Rotate any SSH keys that were on the instance
6. Consider terminating the instance and starting fresh

## Sources
- [ComfyUI CLI Arguments](https://github.com/comfyanonymous/ComfyUI/blob/master/comfy/cli_args.py)
- [UFW Documentation](https://help.ubuntu.com/community/UFW)
- [SSH Tunneling Guide](https://www.ssh.com/academy/ssh/tunneling)
