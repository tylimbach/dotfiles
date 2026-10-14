# Orca with zw

[Orca](https://onorca.dev) shows every agent `zw` starts, beside zellij:
status, Needs You, notifications, diff review with comments sent back to
the agent. `zw` stays the owner of everything else: worktrees (and their
warm pool), starting agents, landing, ending them. Each agent runs once, in
its zellij tab; Orca's tab is a second view of the same process.

## How it works
- With Orca running, `zw new NAME` asks Orca for a terminal in the
  worktree. That terminal runs `zw view`, which opens the zellij tab with
  the agent and attaches to the session.
- Orca hears of an agent only through its hooks (in `~/.claude/settings.json`
  and `~/.codex/`), and they report for the Orca pane named in the agent's
  environment. So `zw view` starts the agent with its terminal's identity
  (`ORCA_PANE_KEY` and the rest of `IDENTITY` in `zw`), through `zw run`.
  Never the hooks' token: they reread it from Orca's endpoint file.
- Codex runs with `--no-daemon`: its shared background server would run
  the hooks in its own environment, so neither Orca nor `zw status` would
  hear from it.
- `zw sync NAME` brings in an agent started without Orca: quit it, and it
  resumes (Claude: the latest session on the tab's branch; Codex: its
  latest in the worktree) in a tab Orca views.
- `zw done NAME` closes Orca's views and the tab.
- Without Orca nothing changes. With Orca installed but unreachable, `zw`
  says why and opens the tab alone.

## Setup
An agent can do this; each step ends with its check. Where a step needs the
person (a password, a click in Orca), stop and ask.

1. **The zw workflow first:** the repo README's "Claude Code agent
   workflow" (zellij, `zw` on PATH, the `zw status` hooks). Check: `zw ls`
   in a repo.
2. **Open files** (macOS, Linux): `zsh/.zshrc` raises the limit to 10240. A
   zellij server inherits its starter's limit, and at 256 (macOS's default
   for apps) a long session can run out, panic and kill every pane. Check:
   `ulimit -n` in a new terminal says 10240 or more.
3. **Install Orca** (onorca.dev; tested with 1.4.224 on macOS). Check: it
   opens.
4. **Its CLI on PATH:** Orca → Settings → General. Check from a plain
   terminal: `orca status --json` (Linux: `orca-ide`, since `orca` there is
   the GNOME screen reader) reports `"reachable": true`. On macOS the link
   it makes can be root-only (`Unable to determine Orca.app path from
   symlink`): `sudo chmod -h 755 /usr/local/bin/orca`.
5. **Privacy:** Settings → Privacy: telemetry off. Crash reports stay
   local. At work, also set `ORCA_TELEMETRY_DISABLED=1`,
   `ORCA_DIAGNOSTICS_DISABLED=1` and `DO_NOT_TRACK=1` in the environment
   Orca starts with (Windows: user environment variables), don't pair the
   mobile app, and decide whether its AI commit messages may send diffs
   through the agent CLI (Settings → Source Control). Check: the settings,
   and `orca status --json` still reachable.
6. **Its agent hooks:** Orca adds them to `~/.claude/settings.json` and
   `~/.codex/` on first run (Settings → Agents, or `orca agent hooks on`),
   beside the `zw status` ones. Check: both are there.
7. **Per repo:** add the main checkout as a project, with external
   worktrees shown; set its base ref to the branch work lands on
   (`orca repo set-base-ref --repo path:REPO --ref BRANCH`); in the
   sidebar filter, hide detached-HEAD workspaces (idle pool slots).
8. **Orca's own agent launcher** adds `--dangerously-skip-permissions`
   (Settings → Agents). Agents start through `zw`, not it; clear the
   default if policy needs.
9. **Start zellij from a plain terminal**, one session per repo, named for
   the main checkout: `cd REPO && zellij attach -c REPO`. Every pane gets
   the server's environment, so a session started inside an agent or an
   Orca terminal hands that identity to every agent in it.

## Verify
In the repo's session:

1. `zw new orca-probe --model haiku --effort low "Reply with exactly: probe ok"`
   prints `Created terminal ...`, and Orca shows a tab `orca-probe` whose
   agent (`orca terminal list --json`, `agentIdentity`) is `claude`; the
   zellij tab gets `✓`.
2. Quit it (`/exit`), `zw sync orca-probe`: the same conversation comes
   back, with a new Orca view.
3. `zw new orca-probe-codex --codex "Reply with exactly: probe ok"`: once
   it has replied, `agentIdentity` is `codex` and the tab gets `✓`.
4. `zw done orca-probe` and `zw done orca-probe-codex`: their Orca views
   and tabs close.

If a step shows no Orca view, `zw` printed why; fix that and retry.

## Windows
Untested; verify each piece with the probe rather than assume:
- zellij runs natively; `zw` asks Orca for a Git Bash terminal
  (`--shell git-bash`), since it quotes the command for a POSIX shell.
- Orca's Windows hooks are `.cmd` and PowerShell scripts. If the probe's
  agent never shows in Orca, read how they test `ORCA_PANE_KEY` and the
  port, as `~/.orca/agent-hooks/*-hook.sh` do on macOS.
- The CLI's name and PATH entry (step 4).
- No `ulimit`; Windows' handle limits are high.

## Rules for agents
For a project's `AGENTS.md` or `CLAUDE.md`; one-off agent tabs unrelated to
a project don't need them.
- Start agents with `zw new` (or the repo's recipe over it); end them with
  `zw done`. Never `orca worktree create` or `rm`, Orca's New workspace,
  delete or archive on `zw` worktrees, or Orca's agent picker for project
  work: they skip the pool and the tabs.
- `orca terminal read` and `wait`, and `orca worktree set --comment` and
  `--workspace-status`, are fine.
- Orca's orchestration (`orca orchestration`) only when the person asks.
- Never two agent processes on one conversation: each keeps its own
  history and one side's turns are lost. A view is never a second agent.

## Limits
- A new Orca view lands on a tab zellij picks, usually the agent's; switch
  it once if not. No zellij action steers one chosen client.
- Closing an Orca tab mid-task leaves the agent reporting to a gone pane:
  quit it and `zw sync`.
- A tab two views show takes the smaller one's size.
- A Codex started on the shared server can't move to `--no-daemon` until
  `codex app-server daemon restart` releases its conversation.
