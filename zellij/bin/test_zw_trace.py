#!/usr/bin/env python3
"""Tests for devtrace in zw."""
import importlib.machinery
import importlib.util
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ZW_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "zw")


def load_zw():
    loader = importlib.machinery.SourceFileLoader("zw_mod", ZW_PATH)
    spec = importlib.util.spec_from_loader("zw_mod", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


def init_repo(root):
    subprocess.run(["git", "init", "-q", "-b", "main", root], check=True)
    subprocess.run(["git", "-C", root, "config", "user.email", "test@example.com"], check=True)
    subprocess.run(["git", "-C", root, "config", "user.name", "Test"], check=True)
    subprocess.run(["git", "-C", root, "commit", "--allow-empty", "-m", "init", "-q"], check=True)


class ZwTraceTests(unittest.TestCase):
    def test_concurrent_appends_20_processes(self):
        with tempfile.TemporaryDirectory() as d:
            init_repo(d)
            env = {k: v for k, v in os.environ.items() if k not in ("ZW_TASK", "ZW_LOG")}
            procs = [
                subprocess.Popen(
                    [ZW_PATH, "emit", "step", f"name=p{i}", "seconds=0.5", "load=1.25"],
                    cwd=d, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                )
                for i in range(20)
            ]
            for p in procs:
                out, err = p.communicate(timeout=10)
                self.assertEqual(p.returncode, 0)
                self.assertEqual(out, b"")
                self.assertEqual(err, b"")

            log = pathlib.Path(d) / ".git" / "zw" / "events.jsonl"
            lines = log.read_text(encoding="utf-8").splitlines()
            self.assertEqual(len(lines), 20)
            names = set()
            for line in lines:
                ev = json.loads(line)
                self.assertEqual(ev["kind"], "step")
                self.assertEqual(ev["seconds"], 0.5)
                self.assertEqual(ev["load"], 1.25)
                self.assertTrue(ev["ts"].endswith("Z"))
                names.add(ev["name"])
            self.assertEqual(names, {f"p{i}" for i in range(20)})

    def test_emit_outside_git_and_unwritable_log(self):
        with tempfile.TemporaryDirectory() as d:
            env = {k: v for k, v in os.environ.items() if k not in ("ZW_TASK", "ZW_LOG")}
            r1 = subprocess.run([ZW_PATH, "emit", "step", "name=x"], cwd=d, env=env,
                                capture_output=True, text=True)
            self.assertEqual(r1.returncode, 0)
            self.assertEqual(r1.stdout, "")
            self.assertEqual(r1.stderr, "")

            blocker = pathlib.Path(d) / "not-a-dir"
            blocker.write_text("file", encoding="utf-8")
            env_bad = {**env, "ZW_LOG": str(blocker / "events.jsonl"), "ZW_TASK": "t-1"}
            r2 = subprocess.run([ZW_PATH, "emit", "step", "name=y"], cwd=d, env=env_bad,
                                capture_output=True, text=True)
            self.assertEqual(r2.returncode, 0)
            self.assertEqual(r2.stdout, "")
            self.assertEqual(r2.stderr, "")

    def test_task_resolution_order(self):
        with tempfile.TemporaryDirectory() as d:
            init_repo(d)
            base_env = {k: v for k, v in os.environ.items() if k not in ("ZW_TASK", "ZW_LOG")}

            # 3. No env, no branch config -> null (empty stdout for `zw task`, null in event)
            r = subprocess.run([ZW_PATH, "task"], cwd=d, env=base_env, capture_output=True, text=True)
            self.assertEqual(r.returncode, 0)
            self.assertEqual(r.stdout.strip(), "")

            # 2. Branch config
            subprocess.run(["git", "-C", d, "config", "branch.main.zwTask", "branch-task-1"], check=True)
            r = subprocess.run([ZW_PATH, "task"], cwd=d, env=base_env, capture_output=True, text=True)
            self.assertEqual(r.returncode, 0)
            self.assertEqual(r.stdout.strip(), "branch-task-1")

            # 1. ZW_TASK env overrides branch config
            r = subprocess.run([ZW_PATH, "task"], cwd=d, env={**base_env, "ZW_TASK": "env-task-2"},
                               capture_output=True, text=True)
            self.assertEqual(r.returncode, 0)
            self.assertEqual(r.stdout.strip(), "env-task-2")

    def test_report_state_intervals_and_step_unions(self):
        with tempfile.TemporaryDirectory() as d:
            log = pathlib.Path(d) / "events.jsonl"
            events = [
                {"ts": "2026-11-16T10:00:00.000Z", "kind": "task.start", "task": "foo-20261116T100000Z",
                 "session": None, "branch": "agent/foo", "worktree": d, "pid": 1,
                 "name": "foo", "base": "abc", "provider": "codex", "model": None, "effort": None,
                 "host": "zellij", "versions": {}},
                {"ts": "2026-11-16T10:00:05.000Z", "kind": "agent.state", "task": "foo-20261116T100000Z",
                 "session": None, "branch": "agent/foo", "worktree": d, "pid": 2, "state": "working"},
                {"ts": "2026-11-16T10:00:15.000Z", "kind": "agent.state", "task": "foo-20261116T100000Z",
                 "session": None, "branch": "agent/foo", "worktree": d, "pid": 2, "state": "input"},
                {"ts": "2026-11-16T10:00:20.000Z", "kind": "agent.state", "task": "foo-20261116T100000Z",
                 "session": None, "branch": "agent/foo", "worktree": d, "pid": 2, "state": "working"},
                {"ts": "2026-11-16T10:00:30.000Z", "kind": "agent.state", "task": "foo-20261116T100000Z",
                 "session": None, "branch": "agent/foo", "worktree": d, "pid": 2, "state": "done"},
                # Overlapping steps in group 'check': [10..20] (10s) and [14..24] (10s) -> sum 20s, union 14s
                {"ts": "2026-11-16T10:00:20.000Z", "kind": "step", "task": "foo-20261116T100000Z",
                 "session": None, "branch": "agent/foo", "worktree": d, "pid": 3,
                 "group": "check", "name": "clippy", "start": "2026-11-16T10:00:10.000Z",
                 "seconds": 10.0, "status": "PASS", "load": 1.0},
                {"ts": "2026-11-16T10:00:24.000Z", "kind": "step", "task": "foo-20261116T100000Z",
                 "session": None, "branch": "agent/foo", "worktree": d, "pid": 4,
                 "group": "check", "name": "test", "start": "2026-11-16T10:00:14.000Z",
                 "seconds": 10.0, "status": "PASS", "load": 1.0},
                # Message from outside task to foo
                {"ts": "2026-11-16T10:00:25.000Z", "kind": "msg", "task": None,
                 "session": None, "branch": "main", "worktree": d, "pid": 5,
                 "to": "foo", "to_task": "foo-20261116T100000Z", "chars": 12},
                {"ts": "2026-11-16T10:01:00.000Z", "kind": "task.end", "task": "foo-20261116T100000Z",
                 "session": None, "branch": "agent/foo", "worktree": d, "pid": 6,
                 "outcome": "landed", "tip": "def"},
            ]
            log.write_text("\n".join(json.dumps(e) for e in events) + "\n", encoding="utf-8")

            env = {**os.environ, "ZW_LOG": str(log)}
            r = subprocess.run([ZW_PATH, "report", "foo", "--json"], env=env,
                               capture_output=True, text=True, check=True)
            data = json.loads(r.stdout)
            self.assertEqual(len(data), 1)
            rep = data[0]
            self.assertEqual(rep["task"], "foo-20261116T100000Z")
            self.assertEqual(rep["wall_seconds"], 60.0)
            self.assertEqual(rep["states"], {"working": 20.0, "input": 5.0, "done": 30.0})
            self.assertEqual(rep["steps"]["check"], {"count": 2, "sum_seconds": 20.0, "union_seconds": 14.0})
            self.assertEqual(rep["msgs"], 1)
            self.assertEqual(rep["tokens"], "n/a (phase 2)")

    def test_claude_dedup_and_subagents(self):
        with tempfile.TemporaryDirectory() as d:
            p = pathlib.Path(d)
            primary = p / "sess1.jsonl"
            sub_dir = p / "sess1" / "subagents"
            sub_dir.mkdir(parents=True)
            sub = sub_dir / "agent-a1.jsonl"

            # Primary has message m1 streamed twice (different output_tokens) + m2
            primary_rows = [
                {"type": "assistant", "timestamp": "2026-11-16T10:00:00Z",
                 "message": {"id": "m1", "usage": {"input_tokens": 10, "cache_creation_input_tokens": 20,
                                                   "cache_read_input_tokens": 30, "output_tokens": 5},
                             "content": [{"type": "thinking"}]}},
                {"type": "assistant", "timestamp": "2026-11-16T10:00:01Z",
                 "message": {"id": "m1", "usage": {"input_tokens": 10, "cache_creation_input_tokens": 20,
                                                   "cache_read_input_tokens": 30, "output_tokens": 40},
                             "content": [{"type": "text"}]}},
                {"type": "assistant", "timestamp": "2026-11-16T10:00:02Z",
                 "message": {"id": "m2", "usage": {"input_tokens": 1, "cache_creation_input_tokens": 2,
                                                   "cache_read_input_tokens": 3, "output_tokens": 4},
                             "content": [{"type": "text"}]}},
            ]
            # Subagent copies m1 from parent (must not double-count) and adds m3
            sub_rows = [
                {"type": "assistant", "timestamp": "2026-11-16T10:00:01Z",
                 "message": {"id": "m1", "usage": {"input_tokens": 10, "cache_creation_input_tokens": 20,
                                                   "cache_read_input_tokens": 30, "output_tokens": 40},
                             "content": [{"type": "text"}]}},
                {"type": "assistant", "timestamp": "2026-11-16T10:00:03Z",
                 "message": {"id": "m3", "usage": {"input_tokens": 5, "cache_creation_input_tokens": 6,
                                                   "cache_read_input_tokens": 7, "output_tokens": 8},
                             "content": [{"type": "text"}]}},
            ]
            primary.write_text("\n".join(json.dumps(r) for r in primary_rows) + "\n", encoding="utf-8")
            sub.write_text("\n".join(json.dumps(r) for r in sub_rows) + "\n", encoding="utf-8")

            log = p / "events.jsonl"
            env = {**os.environ, "ZW_LOG": str(log), "ZW_TASK": "bar-20261116T100000Z"}
            subprocess.run([ZW_PATH, "hook", "session-start"],
                           input=json.dumps({"session_id": "sess1", "transcript_path": str(primary),
                                             "cwd": d, "source": "startup"}),
                           text=True, env=env, check=True)
            r = subprocess.run([ZW_PATH, "report", "--json"], env=env, capture_output=True, text=True, check=True)
            data = json.loads(r.stdout)
            self.assertEqual(data[0]["tokens"], {
                "uncached_input": 16,
                "cache_write": 28,
                "cache_read": 40,
                "output": 52,
            })

    def test_hook_session_start_providers(self):
        with tempfile.TemporaryDirectory() as d:
            init_repo(d)
            subprocess.run(["git", "-C", d, "config", "branch.main.zwTask", "t-hook"], check=True)
            env = {k: v for k, v in os.environ.items() if k not in ("ZW_TASK", "ZW_LOG", "ZW_SESSION")}

            payloads = [
                {"session_id": "c1", "transcript_path": "/Users/x/.claude/projects/p/c1.jsonl",
                 "cwd": d, "hook_event_name": "SessionStart", "source": "startup"},
                {"session_id": "x1", "transcript_path": "/Users/x/.codex/sessions/2026/11/16/rollout-x1.jsonl",
                 "cwd": d, "hook_event_name": "SessionStart"},
                {"conversationId": "a1", "transcriptPath": "/Users/x/.gemini/antigravity-cli/brain/a1/.system_generated/logs/transcript_full.jsonl",
                 "cwd": d, "hookEventName": "SessionStart"},
            ]
            for payload in payloads:
                r = subprocess.run([ZW_PATH, "hook", "session-start"], input=json.dumps(payload),
                                   cwd="/tmp", env=env, capture_output=True, text=True)
                self.assertEqual(r.returncode, 0)
                self.assertEqual(r.stdout, "")

            log = pathlib.Path(d) / ".git" / "zw" / "events.jsonl"
            evs = [json.loads(line) for line in log.read_text(encoding="utf-8").splitlines()]
            self.assertEqual([(e["provider"], e["session_id"], e["task"]) for e in evs], [
                ("claude", "c1", "t-hook"),
                ("codex", "x1", "t-hook"),
                ("agy", "a1", "t-hook"),
            ])

    def test_stubbed_zw_lifecycle(self):
        zw = load_zw()
        with tempfile.TemporaryDirectory() as d:
            main_dir = os.path.realpath(os.path.join(d, "repo"))
            os.makedirs(main_dir)
            init_repo(main_dir)
            orig_cwd = os.getcwd()
            os.chdir(main_dir)
            try:
                zellij_calls = []

                def fake_zellij(*args, capture=False, name=None):
                    zellij_calls.append(args)
                    if args[:2] == ("list-clients", "--json") or args[:1] == ("list-clients",):
                        return "CLIENT_ID ZELLIJ_PANE_ID RUNNING_COMMAND\n1 terminal_1 zsh\n"
                    if args[:1] == ("list-tabs",):
                        return "[]"
                    if args[:1] == ("list-panes",):
                        return "[]"
                    return ""

                with mock.patch.object(zw, "session", return_value="repo"), \
                     mock.patch.object(zw, "sessions", return_value=["repo"]), \
                     mock.patch.object(zw, "orca_unreachable", return_value="no orca"), \
                     mock.patch.object(zw, "zellij", side_effect=fake_zellij), \
                     mock.patch.object(zw, "provider_versions", return_value={"claude": "2.1", "codex": None, "agy": None}), \
                     mock.patch.dict(os.environ, {k: v for k, v in os.environ.items() if k not in ("ZW_TASK", "ZW_LOG")}, clear=True):
                    zw.new("alpha", ["hello"])
                    wt_path = zw.target("alpha")[0]
                    self.assertTrue(os.path.isdir(wt_path))
                    # Verify ZW_TASK was passed into zellij layout via env
                    new_tab_call = next(c for c in zellij_calls if c[0] == "new-tab")
                    self.assertIn("ZW_TASK=alpha-", new_tab_call[2])

                    # Verify zwTask stored in git config
                    task_id = zw.task_for_branch("agent/alpha", cwd=main_dir)
                    self.assertTrue(task_id.startswith("alpha-"))

                    # Resume emits task.resume
                    with mock.patch.object(zw, "session_of", return_value="sess-alpha"):
                        zw.resume("alpha")

                    # Status emits agent.state
                    os.chdir(wt_path)
                    zw.status("working")
                    os.chdir(main_dir)

                    # Msg emits msg
                    running = zw.Running("zellij", "claude", "working", "terminal_9", {"session": "repo", "tab_id": 1})
                    with mock.patch.object(zw, "where", return_value=running), \
                         mock.patch.object(zw, "type_into", return_value=True):
                        zw.msg("alpha", "ping")

                    # Done emits task.end (landed because 0 commits ahead of main)
                    zw.done("alpha")

                    log = pathlib.Path(main_dir) / ".git" / "zw" / "events.jsonl"
                    evs = [json.loads(line) for line in log.read_text(encoding="utf-8").splitlines()]
                    self.assertEqual([e["kind"] for e in evs], [
                        "task.start", "task.resume", "agent.state", "msg", "task.end"
                    ])
                    self.assertEqual(evs[0]["versions"], {"claude": "2.1", "codex": None, "agy": None})
                    self.assertEqual(evs[2]["state"], "working")
                    self.assertEqual(evs[2]["task"], task_id)
                    self.assertEqual(evs[3]["to"], "alpha")
                    self.assertEqual(evs[3]["to_task"], task_id)
                    self.assertEqual(evs[3]["chars"], 4)
                    self.assertEqual(evs[4]["outcome"], "landed")
                    self.assertEqual(evs[4]["task"], task_id)
            finally:
                os.chdir(orig_cwd)


if __name__ == "__main__":
    unittest.main()
