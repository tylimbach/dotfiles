# Agent workflow: orchestrator, task agents, reviewers

I work in shared repos (mostly `~/dev/rad`) and others under `~/dev`. Each story
(a feature, a cleanup: anything merged on its own) gets its own branch and its
own orchestrator session. Repo rules (`CLAUDE.md`, `.claude/`) are the standard
all work is held to.

## Stories

- The main checkout stays on the default branch, pulled. Each story is
  `zw new STORY "<what it is>"` from there: `../<repo>-STORY` on `agent/STORY`,
  in its own zellij tab, with its own orchestrator. Stories run in parallel.
- A story's tasks branch from the story and land back into it, never into
  another story or the default branch.
- A story ships as its own PR, when I ask:
  `git push -u origin agent/STORY:<my branch name>`.

## Roles

Work out which one you are from where you run:

- **Orchestrator**: a story's checkout (its worktree, or the main checkout on a
  feature branch), talking to me.
- **Task agent**: a task's worktree (`../<repo>-NAME` on `agent/NAME`, or
  `.claude/worktrees/NAME` on `worktree-NAME`), or the `implementer` subagent.
  Do the brief, commit on your branch, report. Don't spawn agents or land.
- **Reviewer**: the `reviewer` subagent. Read-only.

## Orchestrator loop

1. **Agree the change with me first**: scope, and acceptance criteria I can check.
   Split it into tasks that touch separate files where possible.
2. **Brief each task**: its base (the story's branch), the goal, its acceptance
   criteria, files in and out of scope, the repo checks to run (from the repo's
   CLAUDE.md), and the expected commits.
3. **Run it**, one of two ways:
   - Default: the `implementer` agent. It gets its own worktree from the story's
     HEAD (`worktree.baseRef: "head"`), under the main checkout's
     `.claude/worktrees/`. Run independent tasks in parallel. I can open one
     with `zw new NAME -c`.
   - Long or hands-on work I want to watch or steer: `zw new NAME "<brief>"`
     from the story's checkout opens it in its own zellij tab, branched from
     the story. Its tab shows `●` working, `?` needs me, `✓` done. Check `zw ls` and its branch's commits when it's done.
4. **Review** each finished task with the `reviewer` agent: give it the worktree
   path, the branch, the base, and the brief. Run a fresh one per round.
5. **Iterate**: send the findings back to the same implementer (SendMessage) or
   the tab, then review again. Stop when the reviewer finds no blocking issues
   and the acceptance criteria are met. After 3 rounds, bring it to me instead.
6. **Land**, from the task's worktree: `zw land [CHECK...]` (rebases onto the
   branch's upstream, the story; runs CHECK; fast-forwards the story). Then
   `zw done NAME`. Check `zw ls` first: a task whose base isn't the story
   needs `git branch --set-upstream-to=<story>` before landing.
7. **Report**: what landed, what the checks showed, and anything left open.
   Don't push, open PRs or touch shared remotes unless I ask.

## Worktrees

- A new worktree has no submodules. If the repo has `.gitmodules`, run
  `git submodule update --init --recursive` in the worktree before building.
- `zw land` refuses uncommitted changes, and `zw done` refuses unlanded commits.
  Don't force either.
- `zw` commands: `new NAME [-c] [ARGS]`, `add NAME`, `go NAME`, `ls`,
  `land [CHECK...]`, `done NAME`. Tab actions need a live zellij session; outside
  one, use `zw add`/`ls`/`land`/`done` and the subagent path.
