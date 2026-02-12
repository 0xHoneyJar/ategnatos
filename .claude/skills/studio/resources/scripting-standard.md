# Hardened Scripting Standard

## In Plain Language
Every shell script in Ategnatos follows eight strict rules that prevent silent failures, security holes, and the kind of bugs that waste GPU hours. If a script doesn't follow these rules, it doesn't ship.

## What You Need to Know

All scripts in this project must pass these eight checks before they are considered complete. No exceptions, no "I'll fix it later."

### Rule 1: Strict Mode on Line 2

Every script starts with `set -euo pipefail` immediately after the shebang.

- `-e` stops the script the moment any command fails
- `-u` treats unset variables as errors instead of silent empty strings
- `-o pipefail` catches failures inside piped commands

```bash
# GOOD
#!/usr/bin/env bash
set -euo pipefail

# BAD — missing strict mode, failures are silent
#!/usr/bin/env bash
echo "starting..."
```

### Rule 2: Always Quote Variables

Every variable expansion must be double-quoted. No exceptions. Unquoted variables cause word splitting and glob expansion, which leads to broken paths and security bugs.

```bash
# GOOD
echo "${filename}"
cp "${source_dir}/${file}" "${dest_dir}/"
if [[ -f "${config_path}" ]]; then

# BAD — unquoted variables break on spaces and special characters
echo $filename
cp $source_dir/$file $dest_dir/
if [ -f $config_path ]; then
```

### Rule 3: No eval, No Untrusted Source

`eval` is banned. Never use it. Never `source` a file you did not write or whose integrity you cannot verify.

```bash
# GOOD — direct execution
"${command}" "${args[@]}"

# GOOD — source only known, controlled files
source "$(dirname "$0")/validate-lib.sh"

# BAD — eval can execute arbitrary code
eval "$user_input"
eval "$(curl -s https://example.com/script.sh)"

# BAD — sourcing untrusted content
source "${USER_PROVIDED_PATH}/config.sh"
```

### Rule 4: Validate All External Input

Any value that comes from outside the script (user arguments, environment variables, file contents, API responses) must be validated through `validate-lib.sh` before use.

```bash
# GOOD — validate before use
source "$(dirname "$0")/validate-lib.sh"

validate_path "${dataset_dir}" "dataset directory"
validate_positive_integer "${batch_size}" "batch size"
validate_enum "${backend}" "backend" "kohya" "simpletuner" "ai-toolkit"

# BAD — trusting external input directly
dataset_dir="$1"
cd "${dataset_dir}"  # Could be /etc, /dev/null, or "$(rm -rf /)"
```

### Rule 5: Proper Array Expansion

Arrays must be expanded with `"${array[@]}"` (quoted, with `@`). Using `*` or forgetting quotes collapses array elements.

```bash
# GOOD — each element stays separate
files=("file one.png" "file two.png" "file three.png")
for f in "${files[@]}"; do
    process "${f}"
done

# GOOD — passing arrays to commands
cmd_args=("--epochs" "15" "--batch-size" "4")
python train.py "${cmd_args[@]}"

# BAD — elements merge into one string
for f in ${files[*]}; do
for f in "${files[*]}"; do
for f in ${files[@]}; do
```

### Rule 6: Temp Files with Trap Cleanup

Temp files must be created with `mktemp` and cleaned up with a trap. Never use hardcoded temp paths (they collide between parallel runs and create security issues).

```bash
# GOOD — mktemp + trap ensures cleanup even on failure
tmpfile="$(mktemp)"
trap 'rm -f "${tmpfile}"' EXIT

curl -s "${url}" > "${tmpfile}"
process "${tmpfile}"

# GOOD — multiple temp files
tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

# BAD — hardcoded path, no cleanup
curl -s "${url}" > /tmp/download.json
process /tmp/download.json
# If script fails here, /tmp/download.json stays forever
```

### Rule 7: Zero shellcheck Warnings

Every script must pass `shellcheck` at its default warning level with zero warnings. Run it before considering a script complete.

```bash
# Check a single script
shellcheck script.sh

# Check all scripts in the project
shellcheck .claude/scripts/*.sh
```

### Rule 8: Disable Directives Require Justification

If you absolutely must suppress a shellcheck warning, the `disable` directive must include an inline comment explaining why the suppression is safe.

```bash
# GOOD — explains why the disable is safe
# shellcheck disable=SC2086 # word splitting is intentional here for flag expansion
docker run ${DOCKER_FLAGS} image:tag

# BAD — no explanation, reviewer cannot verify safety
# shellcheck disable=SC2086
docker run ${DOCKER_FLAGS} image:tag

# BAD — blanket disables hide real bugs
# shellcheck disable=SC2086,SC2034,SC2155
```

## Why This Matters

A single unquoted variable can break a training run 6 hours in. A missing `set -e` can let a failed CUDA check pass silently, leading to a cryptic crash after your dataset has already been loaded onto an expensive GPU. An `eval` on user input is a remote code execution vulnerability.

Every rule here exists because someone, somewhere, lost real time or real money to the exact bug that rule prevents. GPU hours cost between $1 and $8 per hour. A preventable script failure that wastes a 10-hour training run at $4/hr is $40 in the trash.

## Details (For the Curious)

### Why `set -euo pipefail` Instead of Just `set -e`

`set -e` alone misses two common failure modes:

1. **Unset variables** (`-u`): Without this, `${TYPO_VAR}` silently expands to an empty string. With it, the script stops and tells you the variable name. This catches typos immediately.

2. **Pipe failures** (`-o pipefail`): Without this, `failing_command | grep pattern` succeeds if `grep` succeeds, even if `failing_command` crashed. With it, the pipe's exit code is the exit code of the last failing command.

### Why Arrays Need `@` Not `*`

`"${array[*]}"` joins all elements with the first character of IFS (usually a space) into a single string. `"${array[@]}"` expands each element as a separate word. This distinction matters when elements contain spaces:

```bash
args=("--output" "my file.png")

# "${args[@]}" expands to: "--output" "my file.png"  (2 arguments)
# "${args[*]}" expands to: "--output my file.png"     (1 argument)
```

### Why No eval

`eval` re-parses its argument as a shell command. This means any string that reaches `eval` is executed with the full privileges of the script. If that string comes from user input, file contents, or API responses, you have a code injection vulnerability. There is no safe way to use `eval` with untrusted data. Every use case for `eval` has a safer alternative (arrays for dynamic arguments, `printf` for formatting, indirect expansion for variable indirection).

### Shellcheck Rule Reference

Common shellcheck codes you will encounter:

| Code | What It Catches |
|------|----------------|
| SC2086 | Unquoted variable (word splitting risk) |
| SC2046 | Unquoted command substitution |
| SC2155 | Declare and assign on same line (masks exit code) |
| SC2034 | Unused variable |
| SC2068 | Unquoted array expansion |
| SC2164 | `cd` without `||` exit (directory change can fail silently) |
| SC2129 | Multiple redirects to same file (use a block instead) |
