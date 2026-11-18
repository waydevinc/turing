# turing

`turing` works out how much of each git commit was written by an AI agent and how much by a person. It records the answer in a `WD:` trailer on the commit message, which Waydev reads.

The name comes from the Turing test: for every line in a commit, it decides whether a person or a machine wrote it.

It is a single Node.js file with no dependencies, and it replaces the Entire CLI that the older `install-wd.sh` relies on. It works with these agents:

| Agent | Edits | Shell commands | Tokens | Hooks in |
|---|---|---|---|---|
| Claude Code | ✓ | ✓ | ✓ | `~/.claude/settings.json` |
| OpenCode | ✓ | ✓ | ✓ | `~/.config/opencode/plugins/turing.js` |
| Codex CLI | ✓ | ✓ | ✓ | `~/.codex/hooks.json` |
| Gemini CLI | ✓ | ✓ | best effort | `~/.gemini/settings.json` |
| Factory Droid | ✓ | ✓ | best effort | `~/.factory/hooks.json`, or `settings.json` if your hooks already live there |
| Copilot CLI | ✓ | ✓ | — | `~/.copilot/hooks/turing.json` |
| Cursor (agent) | ✓ | — | best effort | `~/.cursor/hooks.json` |

What the columns mean:
- **Tokens: best effort.** The token count is read from the agent's session transcript, whose format isn't documented, so it may be missing.
- **Tokens: —.** The agent doesn't expose usage, so the tokens field stays empty.
- **Cursor shell commands** aren't tracked. Cursor's shell hook is a permission hook, and a hook there could block or auto-approve commands.
- **Tab autocomplete** (Copilot, Cursor Tab) can't be tracked by any hook-based tool, because completions go straight into the editor.

The installer also sets up **OTel telemetry** for Claude Code and OpenCode, which reports usage, tokens and cost per developer to Waydev. One installer covers both attribution and telemetry.

## Requirements

- `git`
- `node` 18 or later

## Install

The installer looks for git repositories in the folder you give it (default: the current folder) and up to 6 levels below it, and skips `node_modules`, `vendor`, `dist`, `build`, `target`, `Pods` and hidden folders.

With npm (any OS):

```bash
npx @waydev/turing install ~/code                       # one-off, nothing left installed globally
npm install -g @waydev/turing && turing install ~/code  # or keep the turing command
turing install ~/code --agents claude,cursor --no-otel  # same options as the scripts below
turing install ~/code -y                                # no prompts: keep Entire, defaults, tokens from the environment
```

`turing install` asks the same questions as the scripts below. To update, run `npm update -g @waydev/turing` (or `npx @waydev/turing@latest …`): the next `turing` command replaces the copy the hooks run, `~/.waydev/turing.js`, with the newer version. An older version never replaces a newer one. `turing --version` prints the version.

From the zip, macOS, Linux, or Git Bash on Windows:

```bash
./install.sh                        # every agent found, repos under the current folder
./install.sh ~/code                 # repos under ~/code
./install.sh --agents claude,cursor # only these agents
./install.sh --no-otel              # attribution only, no telemetry
```

Windows (PowerShell):

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
powershell -ExecutionPolicy Bypass -File install.ps1 -Path C:\code -Agents claude,cursor
powershell -ExecutionPolicy Bypass -File install.ps1 -NoOtel
```

**WSL:** run `install.sh` inside WSL, with `node` 18+ installed there (Ubuntu's packaged node is often older; use nvm). The agent, git and the repositories must all be on the same side. VS Code or Cursor opened in WSL mode count as inside WSL. Windows git committing in a WSL repo, or WSL git committing in a repo under `/mnt/c`, calls a `node` path from the other side and the commit gets no trailer. If you work on both sides, install on each side for its own repositories.

Agent names for `--agents` / `-Agents`: `claude`, `opencode`, `cursor`, `gemini`, `copilot`, `droid`, `codex`. Without the option, the installer picks every agent it finds: its config folder exists, or its command is on `PATH`.

### What the installer asks

If any repository uses Entire, the installer lists those repositories and asks whether to remove Entire from them (default: no). See [Switching a repo from Entire to turing](#comparing-with-entire). If you keep Entire, those repositories are put in compare mode, so the two tools don't both write `WD:`.

For OTel (only when Claude Code or OpenCode is selected), the installer asks for:
- **The ingest URL.** The default is `https://api-ai.waydev.co`.
- **An ingest token for each agent.** Typing is hidden.
- **The email to tag sessions with.** Press Enter to use each repository's git `user.email`, or type one email to use for every repository. It's required when there's no global `git config user.email`.

To run it without prompts, for example from a script, set:

| Variable | Meaning |
|---|---|
| `TURING_CLAUDE_TOKEN` | Claude Code ingest token |
| `TURING_OPENCODE_TOKEN` | OpenCode ingest token |
| `TURING_OTEL_URL` | ingest URL |
| `TURING_EMAIL` | one email for every repo, instead of each repo's git `user.email` |

The installer lists the repositories it found and asks before changing anything. It then:

1. Copies `turing.js` to `~/.waydev/turing.js`.
2. Adds turing's hooks to each selected agent's config file (see the table above).
   - For **Claude Code**, the hooks run after Edit, MultiEdit and Write, and before and after Bash.
   - Existing settings and hooks are kept.
   - When turing edits a file you already had, it saves a backup next to it as `<file>.turing-bak`.
   - **Codex** runs new hooks only after you approve them once: open `codex` and run `/hooks`.
3. Adds the `prepare-commit-msg`, `commit-msg` and `post-commit` git hooks to every repository it found. If you chose to remove Entire, that happens first.
4. Sets up OTel unless you pass `--no-otel`:
   - **Claude Code:** adds the telemetry settings to the `env` block of `~/.claude/settings.json`, tagged with the email you entered, else your global git `user.email`.
   - **OpenCode:** writes them to each repository's `.opencode/settings.json`, tagged with the email you entered, else that repository's `user.email`. This file holds the token, so it's added to `.git/info/exclude`. If it's already tracked by git, the installer warns you instead.

   Your existing settings are merged, not replaced.

The agent hooks are global, so it doesn't matter which folder an agent is started from. That includes a VS Code multi-root workspace ("Add Folder to Workspace"), where the agent starts in the first folder but edits the others. Edits are recorded in whichever repository holds the edited file, as long as turing is enabled there.

An agent can work in a repository that isn't enabled, for example a clone made after the install. turing notes that repository, and `diagnose` lists it with the command that enables it. To enable such repositories automatically, set `TURING_AUTO_ENABLE=1` in the agent's environment, for example in the `env` block of `~/.claude/settings.json`. A repository is then enabled the first time an agent edits a file in it, or runs a command from inside it. It isn't enabled when a command only names a path in it. Auto-enable installs the git hooks the same way `enable` does, so committed hook files (`.githooks/`, `.husky/`) show up as modified. It also re-enables a repository you disabled the next time an agent works in it.

### Git hooks

Our lines go at the top of each hook file, between `# >>> turing >>>` and `# <<< turing <<<`. Everything else in the file is left as it is. Where the hooks go:

| Repository setup | Hook files edited |
|---|---|
| Default | `.git/hooks/` |
| `core.hooksPath` set (for example `.githooks/`) | that folder |
| Husky v9 (`core.hooksPath=.husky/_`) | `.husky/<hook>`, because Husky regenerates `.husky/_` |

- **New hook files** created inside the working tree are added to `.git/info/exclude`, so they never show up as untracked files.
- **Hook files that are already committed** get modified, and the installer lists them. Don't commit these changes: our lines contain your machine's paths to node and `turing.js`. To hide them from `git status` on your machine only:
  ```sh
  git update-index --skip-worktree <files>      # hide
  git ls-files -v | grep '^S'                   # list hidden files
  git update-index --no-skip-worktree <files>   # unhide
  ```
  If a teammate changes one of these files, `git pull` refuses. Unhide it, `git checkout -- <file>`, pull, then run `turing enable` again and hide it again.
- **Hooks that aren't shell scripts** (for example a Python `post-commit`) are left untouched, because our shell line would break them. The installer prints the command to call from that hook instead.
- **A hooks folder shared by several repos** (a global `core.hooksPath`) keeps our lines when you disable one repo, since the others still use them. In a repo that isn't enabled they do nothing.
- **Hooks removed by another tool are put back.** Some tools rewrite whole hook files; Entire 0.10.4 does this when it upgrades its hooks, which removes our lines. The first time an agent session edits a repository, turing checks its hook files and re-adds any missing turing lines, leaving the rest of each file alone.

## Uninstall

```bash
turing uninstall [dir]                 # npm install
npm uninstall -g @waydev/turing
./install.sh --uninstall [dir]         # zip install
```

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall [-Path <dir>]
```

This removes the hook blocks and the per-repository state from every repository under the folder, removes turing's hooks from every agent's config, and deletes `~/.waydev/turing*`. It removes only the OTel settings turing wrote, so settings written earlier by `install-wd.sh` stay. An `.opencode/settings.json` that turing created is deleted if nothing else is left in it.

## How it works

1. **The agent edits a file.** turing records which lines the agent added or removed. Lines are stored as hashes, never as text, in `.git/turing/events.jsonl`. How the edit is seen depends on the agent:
   - **Claude Code, OpenCode and Cursor** report each edit, and turing compares the file before and after.
   - **Codex, Gemini, Droid and Copilot**, and every agent's **shell commands**, are covered by snapshots instead. Before the tool runs, turing saves a snapshot of the repo's uncommitted files; afterwards, it diffs every file that changed in between. Files are compared by content, not by timestamp, so writes from inside a Docker/Sail container (whose clock can lag) and `mv` / `cp -p` are still caught. Each distinct version of a file is saved once, in turing's own folder, and cleared after a day; nothing is written to git's object database. This works whatever shape the tool's input has.

   The repos checked for a snapshot are:
   - the one the command runs in
   - for a workspace folder that isn't a repo itself, the enabled repos up to 3 levels below it
   - any repo named by a `cd` target or an absolute path in the command or tool input
   - every repo the session has already edited, so a script run from one folder that writes into another repo is caught even when the command doesn't name it (the usual case in a multi-root workspace)

   If HEAD moved during the command (a checkout, pull or commit), its changes aren't the agent's writing and are skipped. Files git ignores are never recorded, since they can't be committed. Lines another tool call recorded in the meantime (for example an edit the agent made in parallel) aren't counted twice. To skip commands that run longer than a set time (test runs, dev servers), set `TURING_SHELL_MAX_SEC`; there's no limit by default, because the clock starts before Claude Code asks for permission, so a slow approval would otherwise drop a quick command's edits.
2. **You commit.** The `commit-msg` hook compares the staged changes with those recorded lines:
   - **AI lines:** added lines the agent wrote.
   - **Human modified:** lines that replace an agent line which no longer exists (you edited what the agent wrote).
   - **Human added:** any other added lines.
   - **Human removed:** removed lines the agent did not remove.
   - **Tokens:** what the session has used since its previous commit, read from the agent's session transcript (Claude Code, Codex, Gemini, Droid, Cursor) or from OpenCode's message events. A session's first commit counts from the prompt that led to its first recorded edit, not from the start of the session.
     - **Split by AI lines.** A session can edit several repositories, or leave some of its lines for a later commit. Each commit then takes only its share of the uncounted tokens: its own AI lines from the session, out of those lines plus the session's AI lines not yet committed in any repository. The last commit takes whatever is left. Example: a session writes 3 lines in `data` and 1 in `web` and uses 2000 tokens. Committing `data` first gives it 1500 tokens, and the `web` commit gets the remaining 500. Uncommitted lines that disappear from the working tree are dropped from the count, and so are lines in files nobody has touched for 7 days (abandoned work, such as an untracked scratch file); set `TURING_STALE_DAYS` to change that.
     - **Input and output only.** Cache reads and cache writes aren't counted.
3. **After the commit.** The `post-commit` hook marks the matched lines as used, so they aren't counted again, and drops stale entries. It does this even when the commit got no trailer (for example `git commit --no-verify` with the editor, or the trailer deleted in the editor), so those agent lines aren't credited to a later commit.

Package-manager lockfiles (`package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `composer.lock`, `Cargo.lock`, `go.sum`, `poetry.lock` and similar) are left out entirely. They don't count as AI or human lines, or toward the files total.

If no agent session touched any of the committed files, the commit gets no trailer. For `git commit -m` the trailer is added in `prepare-commit-msg`, so it still works with `--no-verify`.

**Amending** (`git commit --amend`) updates the trailer: the original commit's numbers plus what the amend changed, capped to what the final commit contains. If the original had no trailer, its lines count as human. A commit made before switching compare mode on or off is handled too: turing starts from its own trailer (`WD-Turing:`, else `WD:`) and replaces it; in compare mode Entire's `WD:` is left in place.
- With `--amend -m` or `-F`, the hooks can't tell an amend from a normal commit, so the `post-commit` hook fixes the trailer by amending once more.
- A message reused from a different commit (`-c` or `-C <commit>`) has that commit's trailer dropped and gets a fresh one.

These are skipped:
- merges and squashes
- rebases, cherry-picks and reverts

### The trailer

```
Turing-Checkpoint: <12 hex characters>
WD: <base64 of agent|tokens|files|ai_lines|human_added|human_modified|human_removed|ai_percentage>
```

`Turing-Checkpoint:` is a random id in the same format as Entire's `Entire-Checkpoint:` (12 hex characters, a new one for each commit), so Waydev counts AI commits the same way whichever tool wrote them (AI Checkpoints page, daily commit usage). An amend keeps the original commit's checkpoint. Compare mode doesn't write it, so Entire's checkpoint stays the only one.

For example, `claude-code|165|1|2|1|1|0|66.67` decodes to:

| Field | Value |
|---|---|
| agent | `claude-code` |
| tokens | 165 |
| files changed | 1 |
| AI lines | 2 |
| human added | 1 |
| human modified | 1 |
| human removed | 0 |
| AI percentage | 66.67 |

The AI percentage is `ai_lines / (ai_lines + human_added)`. The agent is one of `claude-code`, `opencode`, `cursor`, `gemini`, `copilot-cli`, `factoryai-droid` or `codex`; these are the names Entire used. The tokens field is empty when the token count isn't known. The format is the same one `install-wd.sh` produces, so `PullRequestCommit::parseCommitMessage` reads it unchanged.

## Comparing with Entire

To check turing's numbers against Entire on the same commits, put a repo in **compare mode**:

```bash
node ~/.waydev/turing.js enable --compare <repo>      # turing writes WD-Turing: and leaves WD: to Entire
node ~/.waydev/turing.js compare <dir> [-n 30]        # both trailers side by side for recent commits
node ~/.waydev/turing.js enable --no-compare <repo>   # back to writing WD:
```

How compare mode works:
- turing writes a `WD-Turing:` trailer with the same encoding as `WD:`.
- Entire's post-commit hook then adds its own `WD:`, as before.
- The backend ignores lines starting with `WD-`, so commits pushed during the comparison are counted from Entire's trailer only.

`compare` lists each commit with:
- the agent
- AI lines
- human added, modified and removed lines
- tokens

for both tools. It ends with totals:
- how many commits had both trailers
- how many had identical AI and human-added counts
- each tool's overall AI share and token total

> **Switching a repo from Entire to turing.** Run turing in normal mode only. If Entire stays installed, both tools write a `WD:` trailer. The installer offers this; to do it yourself:
> ```bash
> node ~/.waydev/turing.js entire-repos <dir>    # repos under <dir> that use Entire
> node ~/.waydev/turing.js remove-entire <dir>   # remove it from them; turing in normal mode
> ```
> `remove-entire` runs `entire disable --uninstall --force` in each repo. That removes `.entire/`, Entire's git and agent hooks, its session state and shadow branches. It then removes any Entire hook files left behind and puts back the hooks Entire had moved aside (`<hook>.pre-entire`). It also removes `install-wd.sh`'s `wd_commit_hook`, then re-adds turing's lines in normal mode.
>
> If the repo commits `.entire/` or the agent settings Entire edited (for example `.claude/settings.json`), the uninstall shows up in `git status`. Hide those files on your machine with `git update-index --skip-worktree <files>`, the same way as [committed hook files](#git-hooks).

## Where it stores data

| Path | What |
|---|---|
| `~/.waydev/turing.js` | the tool |
| `~/.waydev/turing/reported.json` | per session: token total already counted and the repositories it edited (pruned after 30 days) |
| `~/.waydev/turing/opencode/<session>.jsonl` | OpenCode token usage per message (pruned after 30 days) |
| `~/.waydev/turing/skipped.json` | repos an agent worked in that aren't enabled, listed by `diagnose`; a repo is removed once it's enabled |
| `~/.waydev/turing/scan.json` | repos found below a workspace folder that isn't a repo, cached for 5 minutes |
| `<repo>/.git/turing/` | edits not yet committed (`events.jsonl`, `pool.json`) and snapshots taken during shell commands (`shell/`, with each file version in `shell/blobs/`, cleared after 1 day); never committed or pushed |
| `<repo>/.git/worktrees/<name>/turing/` | the same, for each linked git worktree, since each one has its own files; the repo's settings stay in `<repo>/.git/turing/` |

## Troubleshooting

Start with the health check:

```bash
./install.sh --diagnose [dir]
node ~/.waydev/turing.js diagnose [dir]        # same thing, once installed
```

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -Diagnose [-Path <dir>]
```

It makes no changes. For each check it prints ✓ (fine), ⚠ (warning) or ✗ (problem), with a `fix:` line under each warning or problem. The exit code is 1 when there are problems. It checks:

- **The install:** the installed script, `git` and `node`.
- **Claude Code:** the hooks are in `settings.json`, the Node path they use still runs, `disableAllHooks` isn't set, and the OTel settings are complete (endpoint, token, `user.email`).
- **OTel live check** (Claude Code and each repo's OpenCode settings): one request to the ingest endpoint with the configured token. It reports an unreachable server, a rejected token (401), a disabled integration (403), an inactive account, rate limiting (429) or a wrong URL. The request isn't JSON, so the server checks the token and then turns the request away before it logs or stores anything. Each endpoint and token pair is checked once per run, with a 10-second timeout.
  - It reads only the global `~/.claude/settings.json`. Overrides in a project's `.claude/settings.json`, in managed settings or in environment variables aren't seen.
- **OpenCode:** the plugin is present when `opencode` is installed, and its Node path still runs.
- **Other agents:** for each one found, turing's hooks are present and their Node path still runs. Agents that aren't installed are listed as skipped.
- **Each repo under dir:**
  - whether it's enabled
  - all three git hooks present and executable
  - Husky's `.husky/_` folder present
  - OpenCode's OTel settings complete, and the file holding the token not tracked by git
  - the Node path in the hooks still runs
  - Entire or `install-wd.sh` hooks present alongside
  - recent agent activity
  - how many of your recent commits have a `WD:` trailer
- **Repos an agent worked in that aren't enabled**, from the last 30 days, wherever they are on disk.

To look more closely at a single repository:

```bash
node ~/.waydev/turing.js status [repo]
```

This shows:
- whether the git hooks are in place
- the AI lines that haven't been committed yet, per file, and the sessions they came from
- the trailer the currently staged changes would get

To set up a single repository, or a new clone, by hand:

```bash
node ~/.waydev/turing.js enable /path/to/repo
```

Other commands: `setup [--claude] [--opencode] [--cursor] [--gemini] [--copilot] [--droid] [--codex]` (no option means every agent found), `agents` (lists the agents found), `teardown`, `disable [dir]`, `repos [dir]`, `entire-repos [dir]` and `remove-entire [dir]` (see [Comparing with Entire](#comparing-with-entire)).

The hooks look for `node` at the path recorded during install and fall back to whatever `node` is on `PATH`. If you upgrade or switch Node versions (with nvm, for example), run the installer again.

## Limitations

- **What counts as an agent line.** Lines are matched by their content with surrounding whitespace ignored. If a person types a line identical to one an agent added and hasn't committed yet, it counts as AI.
- **"Human modified" pairs removed agent lines with new human lines in the same file by count, not by position.** It's the number of agent lines that disappeared, capped at the number of human-added lines in the same file.
- **`git commit -C HEAD`** (reusing HEAD's message for a new commit) is treated as an amend, because git reports it to the hooks the same way.
- **Shell commands:**
  - A file that a person edits while an agent's command is running counts as AI: git can't tell who changed a file in that window. `TURING_SHELL_MAX_SEC` limits the window, at the cost of dropping edits from commands that waited long for approval.
  - A command that writes files through a variable path (`cd "$DIR"`) outside the folder it runs in is seen only if the session has already edited that repo.
  - Files over 2 MB and binary files are skipped.
  - Files a command generates count as AI, except package-manager lockfiles.
- **Agents other than Claude Code and OpenCode** haven't been tested in the real tools yet, only with simulated hook payloads built from each tool's documentation:
  - **Copilot CLI's** PowerShell hook (Windows) is unverified.
  - **Cursor** shell commands aren't tracked.
  - **Token counts** for Gemini, Droid and Cursor depend on transcript formats that aren't documented.
