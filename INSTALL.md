# Installing foreman

Steps for a coding agent (or a person) installing foreman into Claude Code. Ask your agent: *"Install foreman by following https://raw.githubusercontent.com/ilkemerol/foreman/main/INSTALL.md"*.

foreman installs one of two ways:

- **Plugin (recommended)** - from this repo's own plugin marketplace. Hooks load with the plugin.
- **Repo clone** - `git clone` into `~/.claude/skills/foreman`. Claude Code loads the clone as a plugin too, so its hooks load with it.

Either way the command is `/foreman`. As a plugin its full name is `/foreman:foreman`; use that when another skill named `foreman` takes `/foreman`.

Never both on one machine: both load as plugins, and every foreman hook runs twice.

Paths below say `~/.claude`. When `CLAUDE_CONFIG_DIR` is set, Claude Code and foreman use that folder instead, and so do the commands below (`c` in them).

## Rules for the agent

- Run the steps in order. Every step is safe to run again.
- On any error, stop and report it to the user with the command's output. Do not work around it.
- Back up `settings.json` before changing it (the steps below do), and never write a file `jq` could not parse. Write it in place (`cat "$s.tmp" > "$s"`, not `mv`), so a symlinked `settings.json` stays a symlink.
- Ask the user before installing a plugin, before removing a foreman install, and before replacing a status line they already have.
- Run every command in bash. On Windows that is Git Bash, the shell Claude Code runs hooks in.
- Do not start foreman yourself. The user turns it on.

## 1. Check the tools

```sh
for c in claude bash jq; do command -v "$c" >/dev/null || echo "missing: $c"; done
bash --version | head -n1   # needs 3.2 or newer
jq --version                # needs 1.6 or newer
```

The repo-clone method also needs `git`. Missing `jq`: `winget install jqlang.jq` (Windows), `brew install jq` (macOS), `sudo apt-get install -y jq` (Debian/Ubuntu). Then open a new shell and check again. Missing `bash` or `git` on Windows: install [Git for Windows](https://git-scm.com/download/win). Missing `claude`: install [Claude Code](https://docs.anthropic.com/en/docs/claude-code) first.

## 2. Choose the method

Look for a foreman that is already installed:

```sh
c="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"; s="$c/settings.json"
claude plugin list --json | jq -e '.[] | select(.id == "foreman@foreman")' >/dev/null && echo "found: plugin foreman@foreman"
[ -e "$c/skills/foreman" ] && echo "found: repo clone $c/skills/foreman"
[ -f "$s" ] && jq -e '[.hooks // {} | .. | .command? // empty | strings | select(contains("/skills/foreman/hooks/"))] | length > 0' "$s" >/dev/null &&
  echo "found: old repo-clone hooks in $s"
```

Old repo-clone hooks are what an older foreman clone wired into `settings.json`; they count as a repo clone found.

Ask the user which method they want, plugin or repo clone; recommend the plugin. If foreman is already installed one way, suggest keeping that way. Then run step 3 for the plugin or step 4 for the repo clone. If the other method was found, step 5 removes it, after the user agrees.

## 3. Plugin: add the marketplace and install

This repo is its own plugin marketplace, named `foreman`, with one plugin, also named `foreman`:

```sh
m=$(claude plugin marketplace list --json)
if printf '%s' "$m" | jq -e '.[] | select(.name == "foreman" and .repo == "ilkemerol/foreman")' >/dev/null; then
  claude plugin marketplace update foreman
elif printf '%s' "$m" | jq -e '.[] | select(.name == "foreman")' >/dev/null; then
  echo "STOP: a marketplace named foreman exists with another source"
else
  claude plugin marketplace add ilkemerol/foreman
fi
```

On `STOP`, show the user `claude plugin marketplace list --json` and ask what to do. Do not remove their marketplace, and do not go on. Otherwise install the plugin, or update it if it is already there:

```sh
if claude plugin list --json | jq -e '.[] | select(.id == "foreman@foreman")' >/dev/null; then
  claude plugin update foreman@foreman
else
  claude plugin install foreman@foreman
fi
```

The hooks come with the plugin and load with it. Nothing goes into `settings.json` for them. Go to step 5.

## 4. Repo clone: clone and drop old hook wiring

foreman expects the clone at `~/.claude/skills/foreman`, so it goes there:

```sh
c="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"; d="$c/skills/foreman"
if [ -d "$d/.git" ]; then git -C "$d" pull --ff-only
elif [ -e "$d" ]; then echo "STOP: $d exists but is not a git clone"
else git clone https://github.com/ilkemerol/foreman.git "$d"
fi
```

On `STOP`, ask the user what to do with the existing folder. Do not delete it.

The clone holds `.claude-plugin/plugin.json`, so Claude Code loads it as the plugin `foreman@skills-dir`, with the hooks in [hooks/hooks.json](hooks/hooks.json). Nothing goes into `settings.json` for them. Older foreman versions merged their hooks into `settings.json`; left there, every hook runs twice. This removes them and leaves every other hook. A status line that ran the badge script inside the clone moves to the stable copy (step 6). With nothing to remove, it changes nothing:

```sh
c="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"; s="$c/settings.json"
if [ -f "$s" ] && jq -e '([.hooks // {} | .. | .command? // empty | strings | select(contains("/skills/foreman/hooks/"))] | length > 0)
    or ((.statusLine.command // "") | contains("/skills/foreman/bin/foreman-statusline.sh"))' "$s" >/dev/null; then
  cp "$s" "$s.bak-foreman-$(date +%Y%m%d%H%M%S)-$$"
  jq 'if .hooks then .hooks |= (with_entries(.value |= map(.hooks |= map(select((.command // "") | contains("/skills/foreman/hooks/") | not)) | select(.hooks | length > 0))) | with_entries(select(.value | length > 0))) else . end
    | if (.statusLine.command // "") | contains("/skills/foreman/bin/foreman-statusline.sh")
      then .statusLine.command |= sub("/skills/foreman/bin/foreman-statusline\\.sh"; "/foreman/foreman-statusline.sh") else . end' "$s" > "$s.tmp" &&
    jq empty "$s.tmp" && cat "$s.tmp" > "$s" && rm "$s.tmp"
fi
```

## 5. Remove the other method (ask first)

Only when step 2 found the method the user did not choose. Tell the user what was found and ask before removing it.

**Chose the plugin, a repo clone was found.** The clone may hold the user's own changes, so it is moved, not deleted. On yes, run step 4's second block, which removes the old hook wiring, then move the clone:

```sh
c="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
if [ -e "$c/skills/foreman" ]; then mv "$c/skills/foreman" "$c/foreman-old-skill-$(date +%Y%m%d%H%M%S)-$$"; fi
```

Tell the user where the clone went (`~/.claude/foreman-old-skill-<time>`); they can delete it once they have kept what they need.

**Chose the repo clone, the plugin was found.** On yes:

```sh
claude plugin uninstall foreman@foreman
```

The user may also remove the marketplace with `claude plugin marketplace remove foreman`; ask first.

The state folder `~/.claude/foreman/` is shared by both methods and stays.

## 6. Status line badge

foreman does not set the status line itself; a plugin cannot. At every session start foreman's hook copies its badge script to `~/.claude/foreman/foreman-statusline.sh`, a path that does not change on update. This is the same for both methods. The file appears after the first session start with foreman installed; until then the badge is empty.

If the user has no status line, set foreman's:

```sh
c="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"; s="$c/settings.json"
[ -f "$s" ] || echo '{}' > "$s"
if jq -e '.statusLine' "$s" >/dev/null; then echo "status line exists: ask the user"
else
  cp "$s" "$s.bak-foreman-$(date +%Y%m%d%H%M%S)-$$"
  jq '.statusLine = {type: "command", command: "bash \"${CLAUDE_CONFIG_DIR:-$HOME/.claude}/foreman/foreman-statusline.sh\"", refreshInterval: 15}' "$s" > "$s.tmp" &&
    jq empty "$s.tmp" && cat "$s.tmp" > "$s" && rm "$s.tmp"
fi
```

The command keeps `${CLAUDE_CONFIG_DIR:-$HOME/.claude}` as it is: bash expands it when the status line runs, the way foreman's scripts find the folder. If a status line exists and already runs `foreman/foreman-statusline.sh` in the config folder, leave it. Otherwise do not replace it. Offer the user two choices: replace it with foreman's (back up `settings.json` first, then run the `jq` line above), or add this line to their own script, which shows the badge in front of the rest:

```bash
# after reading Claude Code's JSON input into $input
printf '%s ' "$(printf '%s' "$input" | bash "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/foreman/foreman-statusline.sh")"
```

If their own script still calls `~/.claude/skills/foreman/bin/foreman-statusline.sh`, ask them to change that path to `~/.claude/foreman/foreman-statusline.sh`.

## 7. Optional plugins (ask first)

Neither plugin is required; foreman works without both. Ask the user about each one.

- **superpowers** (recommended): skills for planning, debugging and code review. foreman runs them with `/foreman <skill> <args>`, and its bug pieces follow `superpowers:systematic-debugging`.

  ```sh
  claude plugin install superpowers@claude-plugins-official
  ```

  If the marketplace is missing, run `claude plugin marketplace add anthropics/claude-plugins-official` first.

- **caveman** (optional): adds the `caveman:cavecrew-*` agent types that foreman prefers for locating code, small edits and reviews. Without it foreman uses `Explore` and `general-purpose` instead. It needs Node.js, and it turns its terse reply style on in every session by default. To keep that style off, write `{"defaultMode":"off"}` to `~/.config/caveman/config.json` (Windows: `%APPDATA%\caveman\config.json`).

  ```sh
  claude plugin marketplace add JuliusBrussee/caveman && claude plugin install caveman@caveman
  ```

## 8. Verify

foreman must be in the plugin list and enabled: `foreman@foreman` for the plugin, `foreman@skills-dir` for a repo clone.

```sh
claude plugin list --json | jq -r '.[] | select(.id == "foreman@foreman" or .id == "foreman@skills-dir") | "\(.id) enabled=\(.enabled)"'
```

Exactly one line must show, ending `enabled=true`.

- Disabled: run `claude plugin enable` with the id shown.
- Two lines: both methods are installed; go back to step 5.
- No line after a repo clone: this Claude Code does not load plugins from the skills folder, so the hooks would not run. Ask the user to update Claude Code (`claude update`), then check again.

Then run the checks from that folder:

```sh
p=$(claude plugin list --json | jq -r 'first(.[] | select(.id == "foreman@foreman" or .id == "foreman@skills-dir") | .installPath)' | tr -d '\r')
bash "$p/eval/check.sh"
```

The last line must read `foreman eval: <n> passed, 0 failed`. The checks run against a throwaway folder and change nothing real.

List the plugins that are enabled now:

```sh
claude plugin list --json | jq -r '.[] | select(.enabled) | .id'
```

## 9. Hand over

Tell the user:

- Restart Claude Code. For the plugin, `/reload-plugins` also loads it in a running session, but the status line copy is made when a session starts.
- Turn foreman on with `/foreman on`, run one task with `/foreman <task>`, check the board with `/foreman status`. If another skill named `foreman` takes `/foreman`, the plugin answers to `/foreman:foreman`. Claude never starts foreman on its own.
- Update later. Plugin: `claude plugin update foreman@foreman`, then `/reload-plugins` or a restart. Third-party marketplaces do not update on their own by default; the user can turn that on under `/plugin` > Marketplaces. Repo clone: `git -C ~/.claude/skills/foreman pull --ff-only`, then restart.
- Optional extras, both described in the README: [foreman-vision](README.md#foreman-vision), a live view (a clone install or its plugin, both are found), and [beads](README.md#tracking-with-beads) tracking. foreman offers to install `bd` when it needs it.

## Uninstall

Plugin:

```sh
claude plugin uninstall foreman@foreman
claude plugin marketplace remove foreman
```

Repo clone: ask the user first. The clone may hold their own changes, so it is moved, not deleted. On yes, run step 4's second block, which removes hooks an older foreman wired into `settings.json`, then:

```sh
c="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
if [ -e "$c/skills/foreman" ]; then mv "$c/skills/foreman" "$c/foreman-old-skill-$(date +%Y%m%d%H%M%S)-$$"; fi
```

Tell the user where the clone went; they can delete it once they have kept what they need.

Then, for both, remove foreman's status line and its state folder:

```sh
c="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"; s="$c/settings.json"
if [ -f "$s" ] && jq -e '(.statusLine.command // "") | test("/foreman/foreman-statusline\\.sh|/skills/foreman/")' "$s" >/dev/null; then
  cp "$s" "$s.bak-foreman-$(date +%Y%m%d%H%M%S)-$$"
  jq 'del(.statusLine)' "$s" > "$s.tmp" && jq empty "$s.tmp" && cat "$s.tmp" > "$s" && rm "$s.tmp"
fi
rm -rf "$c/foreman"
```

`~/.claude/foreman` holds the flags, the boards, foreman-vision's log and the status line copy. If the user added the badge line to their own status line script, remove it there. Ask before uninstalling superpowers or caveman: other skills may use them.
