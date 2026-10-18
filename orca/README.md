# Orca with zw

[Orca](https://onorca.dev) can run a repo's agents itself: status, Needs
You, notifications on the phone, diff review with comments sent back to the
agent. `zw` stays the owner of everything else: worktrees (and their warm
pool), starting agents, moving them, landing, ending them. Each agent runs
once, on one host: an Orca terminal, or a zellij tab for working in a plain
terminal. One command moves every agent between the two.

## How it works
- **The host** is the repo's `git config zw.host`: `orca`, or `zellij` (the
  default). `zw move orca` or `zw move zellij` sets it.
- **`zw new NAME`** with Orca as the host makes the worktree, then has Orca
  start the agent (`orca agent launch`), as its own launcher does: with
  Orca's default arguments (Settings → Agents: Claude's
  `--dangerously-skip-permissions`, Codex's
  `--dangerously-bypass-approvals-and-sandbox`), the brief as its first
  prompt. Orca takes `--model` and `--effort` (only an effort the model
  supports) and the brief, nothing else.
- **Names:** a Claude session is named NAME (`--name`; through Orca,
  `/rename`, which applies once the brief's first turn ends). The name
  lives in the conversation, so it survives every resume and move; other
  sessions message it by that name.
- **`zw move HOST`** quits each idle agent on the other host and resumes
  its conversation on HOST, in a zellij tab named NAME or an Orca terminal
  run as Orca would start it. The session is the worktree's latest on its
  branch: Claude's from its transcripts, Codex's from each transcript's
  first line (`codex resume --last` can pick another worktree's). A
  resumed Codex gets a one-line note as its first prompt: its hooks report
  only once a turn runs. Model and effort carry over (`git config
  zw.NAME.*`); other arguments and Orca's defaults don't.
- **Idle** is what the hooks report: Orca's state; in zellij, Claude's own
  (`claude agents`) or the tab's mark. A working agent, one waiting on a
  question, or one not yet heard from stays put and is listed: rerun once
  it's idle.
- **`zw msg NAME TEXT`** types into an agent on either host, the way
  agents message a Codex. It refuses an agent waiting on a question or not
  yet heard from: its screen may hold a menu, where text and Enter pick an
  answer.
- **`zw resume NAME`** brings back an agent whose terminal or tab was
  closed by mistake. **`zw done NAME`** closes its terminals and tab.
- **zw's older zellij agents** each have an Orca terminal viewing their
  tab, and they report to Orca from it. `zw` finds zellij agents by their
  folder, never takes a view for an Orca agent, and closes the view when
  it moves one.

## Setup
An agent can do this; each step ends with its check. Where a step needs the
person (a password, a click in Orca), stop and ask.

1. **The zw workflow first:** the repo README's "Claude Code agent
   workflow" (`zw` on PATH, the `zw status` hooks, the Codex settings).
   Check: `zw ls` in a repo.
2. **Open files** (macOS, Linux): `zsh/.zshrc` raises the limit to 10240. A
   zellij server inherits its starter's limit, and at 256 (macOS's default
   for apps) a long session can run out, panic and kill every pane. Check:
   `ulimit -n` in a new terminal says 10240 or more.
3. **Install Orca** (onorca.dev; tested with 1.4.229 on macOS). Check: it
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
7. **Agents' arguments:** Settings → Agents. Its defaults skip every
   permission prompt and Codex's sandbox; change them there if policy
   needs, and `zw` follows (it reads them from Orca's settings file).
   Agents in Orca terminals don't open in Orca's chat view (Settings → Chat
   UI stays off): `zw` resumes conversations in terminals.
8. **Per repo:** add the main checkout as a project, with external
   worktrees shown; set its base ref to the branch work lands on
   (`orca repo set-base-ref --repo path:REPO --ref BRANCH`); in the
   sidebar filter, hide detached-HEAD workspaces (idle pool slots). Then
   `git config zw.host orca` in the main checkout.
9. **For the zellij host,** one session per repo, named for the main
   checkout and started from a plain terminal: `cd REPO && zellij attach
   -c REPO`. Every pane gets the server's environment, so a session
   started inside an agent or an Orca terminal hands that identity to
   every agent in it.

## Verify
In the repo, with Orca the host and the zellij session up:

1. `zw new orca-probe --model haiku "Reply with exactly: probe ok"`: Orca
   shows the agent in the probe's workspace, and once it has replied
   `claude agents --json` names it `orca-probe`.
2. `zw move zellij orca-probe`: a zellij tab `orca-probe` holds the same
   conversation. `zw move orca orca-probe` brings it back.
3. The same for `zw new orca-probe-codex --codex "Reply with exactly: probe ok"`.
4. `zw msg orca-probe "Reply with exactly: msg ok"` gets its answer.
5. `zw done orca-probe` and `zw done orca-probe-codex`: their terminals and
   tabs close. Then `git config zw.host` as you want it.

## Windows
Untested; verify each piece with the probe rather than assume:
- `zw` asks Orca for Git Bash terminals (`--shell git-bash`), since it
  quotes commands for a POSIX shell.
- It reads Orca's settings from `%APPDATA%\orca\profiles\local-default\`
  (Linux: `~/.config/orca/...`); if it says it couldn't, find the folder
  and fix `ORCA_SETTINGS` in `zw`.
- Orca's Windows hooks are `.cmd` and PowerShell scripts. If the probe's
  agent never shows in Orca, read how they test `ORCA_PANE_KEY` and the
  port, as `~/.orca/agent-hooks/*-hook.sh` do on macOS.
- The CLI's name and PATH entry (step 4). No `ulimit`; Windows' handle
  limits are high.

## Rules for agents
For a project's `AGENTS.md` or `CLAUDE.md`; one-off agent tabs unrelated to
a project don't need them.
- Start agents with `zw new` (or the repo's recipe over it); end them with
  `zw done`. Never `orca worktree create` or `rm`, Orca's New workspace,
  delete or archive on `zw` worktrees, or Orca's agent picker for project
  work: they skip the pool and the records a move needs.
- Message a Claude session by its name (SendMessage), a Codex with
  `zw msg NAME TEXT`.
- `orca terminal read` and `wait`, and `orca worktree set --comment` and
  `--workspace-status`, are fine.
- Orca's orchestration (`orca orchestration`) only when the person asks:
  its supervised workers can't move.
- Never two agent processes on one conversation: each keeps its own
  history and one side's turns are lost. `zw` refuses to resume an agent
  it finds running.

## Limits
- A move waits for idle: an agent mid-turn, or with background work (a
  Claude watch), stays where it is.
- A Claude session started through Orca takes its name only once its
  first turn ends; until then other sessions see `<folder>-<id>`.
- Orca starts an agent in a workspace its window hasn't shown unseen, and
  gives its terminal a new handle once the window adopts it; `zw` keys on
  the terminal's tab, which stays.
- An Orca update that restarts its terminal service ends every agent in
  it: `zw resume NAME` brings each back.
