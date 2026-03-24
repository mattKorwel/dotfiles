# Gemini CLI Skill: CI Monitor & Auto-Fix (`gmonitor` & `gcheck`)

A specialized skill for Gemini CLI that provides high-performance, fail-fast monitoring of GitHub Actions workflows and automated local verification of CI failures.

## Objective
- **Efficiency:** Monitor all concurrent workflows (CI, E2E, Links) triggered by a push in real-time with an aggregated status line.
- **Fail-Fast:** Stop immediately when the first job fails to save developer time.
- **Actionability:** Extract exact failing test names from deep logs and generate ready-to-run `npm test` or `npm run lint` commands.
- **Noise Reduction:** Automatically filter out Git sync logs, NPM deprecation warnings, and redundant stack traces for a clean, machine-readable report.

## Setup
Ensure these scripts are in your dotfiles and sourced in your shell profile.

### 1. `ci-monitor.mjs`
The core engine that interfaces with the GitHub CLI (`gh`) and the GitHub REST API.
Location: `~/dev/dotfiles/.gemini-scripts/ci-monitor.mjs`

### 2. `gemini-functions.zsh`
Shell wrappers that bridge the monitor output to local execution.
Location: `~/dev/dotfiles/.gemini-scripts/gemini-functions.zsh`

```zsh
# Add to your .zshrc
source ~/dev/dotfiles/.gemini-scripts/gemini-functions.zsh
```

## Commands

### `gmonitor [branch] [run_id]`
Monitors CI runs for the specified branch (defaults to current).
- **Behavior:** Updates every 15 seconds. Shows a single line status: `⏳ Monitoring 3 runs... 15/20 jobs (14 passed, 1 failed, 5 running)`.
- **On Failure:** Prints a structured report grouped by File/Category and exits immediately.

### `gcheck [branch] [run_id]`
The "bridge" command for automated triage.
- **Behavior:** Runs `gmonitor`. If failures are detected, it extracts the suggested `npm` commands and **immediately executes them locally**.
- **Use Case:** Best used when you want to "hand off" a CI failure to the Gemini CLI agent. The agent can run `gcheck`, see the local failure output, and immediately apply a fix.

## Failure Categories
- **Test Failures:** Extracted as `packages/<pkg>/src/.../name.test.ts`.
- **Lint Errors:** Identified and suggested as `npm run lint:all`.
- **Build Errors:** Captured when TypeScript compilation or bundling fails.
- **Job Errors:** Captured when a job fails during setup or due to infrastructure issues (e.g., CodeQL, E2E timeouts).

## Noise Filtering Logic
The skill aggressively filters:
- Git branch update logs.
- NPM `deprecated` warnings.
- Internal Node.js stack trace noise.
- Excessive output truncation (limits to 10 lines per failure category).
