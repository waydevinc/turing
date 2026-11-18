# Turing: AI Attribution & Telemetry Installer

## Overview

Turing measures how much of each Git commit was written by an AI coding agent and how much by a person. It runs locally on the developer's machine. It records the result in two trailer lines on the commit message, `Turing-Checkpoint:` and `WD:`, which Waydev reads when the commit is pushed.

The same installer can also set up **AI telemetry (OpenTelemetry)** for Claude Code and OpenCode, which reports usage, tokens and cost per developer to Waydev.

Turing replaces the Entire CLI used by the [Waydev Git-Hooks & AI Telemetry Installer](https://docs.waydev.co/docs/waydev-git-hooks-ai-telemetry-installer). It writes the same `WD:` trailer, and a `Turing-Checkpoint:` in the same format as Entire's `Entire-Checkpoint:`, so Waydev's reports work the same, with nothing to change on your side.

> 📘 Open source
>
> **Turing is a single Node.js file (`turing.js`) with no dependencies, plus two small installer scripts.** The source can be reviewed in full before installation; any modifications are made at your own risk. The archive also includes the complete technical documentation: <Anchor target="_blank" href="https://drive.google.com/drive/folders/1YL-P713TuaiBjOP-l_y6cwjVrVAOaqMO?usp=drive_link">**Download Turing**</Anchor>.

## Why Turing?

The name comes from the Turing test: for every line in a commit, Turing decides whether a person or a machine wrote it.

Waydev built Turing to replace the setup it used before: the Entire CLI, plus a Waydev hook that turned Entire's data into the `WD:` trailer.

- **One small tool you can read.** Turing is a single Node.js file with no dependencies and nothing to download at run time. Entire is a separate third-party binary, and its releases have changed how it installs its Git hooks. For example, an upgrade rewrites hook files whole, which removed other tools' lines from them.
- **Less data on the machine.** Turing keeps only hashes of the lines an agent wrote, inside `.git/turing/`, and clears them as you commit. Entire keeps full session logs and prompts, in an `.entire/` folder and in shadow branches in your repository.
- **Writes the trailer directly.** There's no second hook converting another tool's data, so there's one less thing to keep in sync and to break.
- **Accurate token counts.** Each AI message is counted once, from its input and output tokens only. When one session edits several repositories, its tokens are split between them by each one's share of the AI lines, so they aren't counted twice.
- **More agents covered.** Turing tracks Claude Code, OpenCode, Codex CLI, Gemini CLI, Factory Droid, GitHub Copilot CLI and Cursor, including edits made through shell commands (`sed`, scripts, code generators).
- **Works with your existing hooks.** Turing adds its lines alongside your own hooks, a custom `core.hooksPath` or Husky, and puts them back if another tool rewrites the hook files.
- **Works across repositories.** An agent working in a multi-repository workspace (for example a VS Code multi-root workspace) has each edit recorded in the repository that holds the file.
- **One installer** for both AI attribution and telemetry, on macOS, Linux and Windows, with a built-in health check (`diagnose`).
- **Easy to switch.** It writes the same `WD:` trailer format and a checkpoint in Entire's format, so Waydev's reports keep working without any change. A compare mode lets you run it next to Entire before switching.

## 1. Supported agents

- **Claude Code, OpenCode, Codex CLI:** edits, shell commands and tokens.
- **Gemini CLI, Factory Droid:** edits and shell commands; tokens best effort.
- **GitHub Copilot CLI:** edits and shell commands; no tokens.
- **Cursor (agent):** edits; tokens best effort; shell commands aren't tracked.

Notes:
- **Tokens best effort:** the token count comes from the agent's session transcript, whose format isn't documented, so it may be missing.
- **No tokens:** the agent doesn't expose token usage, so that field is left empty.
- **Tab autocomplete** (Copilot, Cursor Tab) can't be tracked, because completions go straight into the editor without any hook.

## 2. Installation

### 2.1 Prerequisites

- `git`
- Node.js 18 or later

Installer for each system:
- **macOS, Linux:** `install.sh`
- **Windows:** `install.ps1` (PowerShell) or `install.sh` (Git Bash)
- **WSL:** `install.sh`, run inside WSL

### 2.2 Run the installer

Unzip the archive you received from Waydev and run the installer from the folder that contains your repositories. It finds every Git repository in that folder and up to 6 levels below it, and skips dependency and build folders (`node_modules`, `vendor`, `dist`, `build`, …).

macOS, Linux, Git Bash, WSL:

```bash
cd turing
./install.sh ~/code                    # repositories under ~/code
./install.sh --agents claude,cursor    # only these agents
./install.sh --no-otel                 # attribution only, no telemetry
```

Windows (PowerShell):

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -Path C:\code
powershell -ExecutionPolicy Bypass -File install.ps1 -Path C:\code -Agents claude,cursor
powershell -ExecutionPolicy Bypass -File install.ps1 -NoOtel
```

Without `--agents`, the installer picks every agent it finds on the machine. Agent names: `claude`, `opencode`, `cursor`, `gemini`, `copilot`, `droid`, `codex`.

### 2.3 What the installer asks

The installer lists the repositories it found and asks before changing anything.

1. **Entire.** If any repository still uses Entire, the installer lists those repositories and asks whether to remove Entire from them (default: no). See [section 5](#5-moving-from-entire-to-turing).
2. **Telemetry** (only when Claude Code or OpenCode is selected):
   - **Ingest URL.** The default is `https://api-ai.waydev.co`.
   - **Ingest token** for each agent, from the Waydev integration page. Typing is hidden.
   - **Email.** Press Enter to tag sessions with each repository's `git config user.email`, or type one email to use for every repository.
3. **Confirmation.** Nothing is changed before you confirm.

To install without prompts, for example from a provisioning script, set these environment variables:

- `TURING_CLAUDE_TOKEN`: Claude Code ingest token
- `TURING_OPENCODE_TOKEN`: OpenCode ingest token
- `TURING_OTEL_URL`: ingest URL
- `TURING_EMAIL`: one email for every repository

### 2.4 What it changes

- Copies `turing.js` to `~/.waydev/turing.js`.
- Adds Turing's hooks to each selected agent's global config file (for example `~/.claude/settings.json`). Your existing settings and hooks are kept, and a backup of each edited file is saved as `<file>.turing-bak`.
- Adds the `prepare-commit-msg`, `commit-msg` and `post-commit` Git hooks to every repository it found. Existing hooks, a custom `core.hooksPath` and Husky are supported: Turing's lines go at the top of the hook file, between `# >>> turing >>>` and `# <<< turing <<<`, and the rest of the file is left alone.
- Sets up telemetry, unless you pass `--no-otel`:
  - **Claude Code:** in the `env` block of `~/.claude/settings.json`.
  - **OpenCode:** in each repository's `.opencode/settings.json`. That file holds the token, so it's added to `.git/info/exclude` and never committed.

> 🚧 Restart running agent sessions
>
> Agents load their hooks when a session starts. Edits made in a session that was already running during the install aren't recorded, and count as human. Start a new session (or restart the agent) after installing.

> 📘 Codex CLI
>
> Codex runs new hooks only after you approve them once: open `codex` and run `/hooks`.

> 🚧 Hook files committed to the repository
>
> If a repository keeps its Git hooks in a committed folder (for example `.githooks/`), Turing edits those files and they show up in `git status`. **Don't commit them**: they contain paths from your machine. Hide them locally with:
>
> ```bash
> git update-index --skip-worktree <files>
> ```
>
> The installer prints the exact command for each repository.

### 2.5 Check the current status

```bash
node ~/.waydev/turing.js diagnose ~/code
```

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -Diagnose -Path C:\code
```

The health check makes no changes. For each check it prints ✓ (fine), ⚠ (warning) or ✗ (problem), with a `fix:` line under each warning or problem. It checks:
- the agent hooks
- the Git hooks in every repository
- the telemetry settings, with one live request to the ingest endpoint to confirm the URL and token
- recent agent activity
- how many of your recent commits carry a `WD:` trailer

To see what the next commit would get in one repository:

```bash
node ~/.waydev/turing.js status [repo]
```

## 3. Data privacy and how Waydev reads AI attribution

### 3.1 What stays on the developer's machine

Everything Turing records stays local, in `.git/turing/` inside each repository and in `~/.waydev/turing/`. It is never committed or pushed.

- **Lines are stored as hashes, never as text.** Turing keeps a hash of each line an agent added or removed, so it can recognise those lines at commit time.
- **No prompts, responses or session transcripts are copied or sent anywhere.** Turing reads the agent's local transcript only to add up token counts.
- **Snapshots** taken while an agent runs a shell command are kept in `.git/turing/` and deleted after one day.

### 3.2 How Waydev gets the attribution data

When you commit, Turing's Git hooks compare the staged changes with the lines the agent wrote. They then add two trailer lines to the commit message:

```
Turing-Checkpoint: <12 hex characters>
WD: <base64 of agent|tokens|files|ai_lines|human_added|human_modified|human_removed|ai_percentage>
```

`Turing-Checkpoint:` is a random id in the same format as Entire's `Entire-Checkpoint:` (12 hex characters, a new one for each commit), which Waydev uses to count AI commits. An amended commit keeps its id. `WD:` carries the numbers.

For example, `claude-code|165|1|2|1|1|0|66.67` decodes to:

- **agent:** `claude-code`
- **tokens:** 165
- **files changed:** 1
- **AI lines:** 2
- **human added:** 1
- **human modified:** 1
- **human removed:** 0
- **AI percentage:** 66.67

What the fields mean:
- **AI lines:** lines the agent added.
- **Human added:** any other added lines.
- **Human modified:** agent lines that a person changed before committing.
- **Human removed:** removed lines the agent didn't remove.
- **AI percentage:** `ai_lines / (ai_lines + human_added)`.
- **Tokens:** the session's input and output tokens since its previous commit. When a session edits several repositories, its tokens are split between them by each one's share of the AI lines.

A commit that no agent session touched gets no trailer. Merges, rebases, cherry-picks and reverts are skipped. Amended commits get an updated trailer.

### 3.3 How the data reaches Waydev

The trailer is part of the commit message, so it travels with a normal `git push`. Waydev reads it when it syncs commits from your Git provider. Only the random checkpoint id and the eight numbers in the trailer leave the machine this way.

Telemetry, if enabled, is sent separately by Claude Code and OpenCode to the ingest URL. It contains usage, token and cost metrics tagged with the developer's email.

## 4. Uninstall

```bash
./install.sh --uninstall ~/code
```

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall -Path C:\code
```

This removes:
- Turing's lines from the Git hooks of every repository under the folder, and its local data in `.git/turing/`
- Turing's hooks from every agent's config
- the telemetry settings Turing wrote (settings written earlier by `install-wd.sh` are kept)
- `~/.waydev/turing.js` and `~/.waydev/turing/`

## 5. Moving from Entire to Turing

If Entire stays installed in a repository, both tools write a `WD:` trailer. Use one of them per repository:

- **Remove Entire.** Answer **yes** when the installer asks, or run:

  ```bash
  node ~/.waydev/turing.js entire-repos ~/code    # repositories that use Entire
  node ~/.waydev/turing.js remove-entire ~/code   # remove it from them
  ```

  This runs Entire's own uninstall (`entire disable --uninstall --force`) in each repository. That removes `.entire/`, Entire's Git and agent hooks, its local session data and shadow branches. It also removes the `wd_commit_hook` added by `install-wd.sh`. Turing then writes the `WD:` trailer.

- **Keep Entire for now.** Answer **no**. Turing is then put in *compare mode* in those repositories: it writes a `WD-Turing:` trailer, which Waydev ignores, and Entire keeps writing `WD:`. To see both side by side:

  ```bash
  node ~/.waydev/turing.js compare <repo> -n 30
  ```

  When you're ready to switch, remove Entire as above.

> 📘 Entire files committed to the repository
>
> If a repository commits `.entire/` or agent settings that Entire edited (for example `.claude/settings.json`), removing Entire shows up in `git status`. Commit that change if the whole team is moving to Turing, or hide it locally with `git update-index --skip-worktree <files>`.

## 6. Troubleshooting

- **Commits get no `WD:` trailer.** Run `diagnose`. Check that the repository is enabled and that the agent's hooks are present. A commit that no agent session touched gets no trailer.
- **AI-written code counts as human.** The agent session was probably started before the install, so its hooks weren't loaded: start a new session. Edits made outside the agent (IDE refactors, formatters, scripts you run yourself) count as human by design.
- **A repository was cloned after the install.** Run `node ~/.waydev/turing.js enable /path/to/repo`.
- **Node was upgraded or switched (nvm).** Run the installer again, so the hooks use the new Node path.
- **Telemetry endpoint unreachable.** Check the ingest URL, VPN and proxy, then run the installer again.
- **Telemetry token rejected (401).** Copy the token again from the Waydev integration page and run the installer again.
- **Commits get `WD-Turing:` and no `Turing-Checkpoint:`.** The repository is in compare mode. Remove Entire (section 5), or run `node ~/.waydev/turing.js enable --no-compare <repo>`.

## 7. Limitations

- If a person types a line identical to one an agent added and hasn't committed yet, it counts as AI.
- "Human modified" is an estimate.
- Edits made outside the agent (IDE refactors, format-on-save, formatters in pre-commit hooks) count as human, even when they only reformat lines the agent wrote.
- A file that a person edits while an agent's shell command is running counts as AI.
- Cursor's shell commands aren't tracked.
- Agents other than Claude Code and OpenCode have been tested only with simulated hook payloads built from each tool's documentation.
