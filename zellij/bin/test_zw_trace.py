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


def clean_env(**extra):
    """The environment without a trace of our own, so a test names its own."""
    env = {k: v for k, v in os.environ.items() if k not in ("ZW_TASK", "ZW_LOG", "TRACEPARENT")}
    return {**env, **extra}


def emitted(log, *args, **env):
    """What `zw emit ARGS` appends to `log`: the one event."""
    before = len(log.read_text(encoding="utf-8").splitlines()) if log.exists() else 0
    r = subprocess.run([ZW_PATH, "emit", *args], env=clean_env(ZW_LOG=str(log), ZW_TASK="t-1", **env),
                       capture_output=True, text=True)
    assert (r.returncode, r.stdout, r.stderr) == (0, "", ""), r
    lines = log.read_text(encoding="utf-8").splitlines()
    assert len(lines) == before + 1, lines
    return json.loads(lines[-1])


def event(ts, kind, task=None, **fields):
    return {"ts": ts, "kind": kind, "task": task, "session": None, "branch": "agent/x",
            "worktree": "/w", "pid": 1, **fields}


def span(start, name, duration, status="OK", task=None, span_id=None, parent=None,
         trace="ab" * 16, **tags):
    ids = {"trace_id": trace, "span_id": span_id or os.urandom(8).hex()}
    if parent:
        ids["parent_span_id"] = parent
    return event(start, "span", task, name=name, **ids, start=start, duration=duration,
                 status=status, attributes=tags)


def step(start, name, seconds):
    """A `step` line, which logs written before spans hold: no span."""
    return event(start, "step", None, group="build", name=name, start=start, seconds=seconds,
                 status="PASS", load=1.0)


def span_report(log, *args):
    """`zw report --spans ARGS --json` on the events in `log`, days read in UTC."""
    r = subprocess.run([ZW_PATH, "report", "--spans", *args, "--json"],
                       env=clean_env(ZW_LOG=str(log), TZ="UTC"), capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    return json.loads(r.stdout)


def write_log(folder, events):
    log = pathlib.Path(folder) / "events.jsonl"
    log.write_text("\n".join(json.dumps(e) for e in events) + "\n", encoding="utf-8")
    return log


def init_repo(root):
    subprocess.run(["git", "init", "-q", "-b", "main", root], check=True)
    subprocess.run(["git", "-C", root, "config", "user.email", "test@example.com"], check=True)
    subprocess.run(["git", "-C", root, "config", "user.name", "Test"], check=True)
    subprocess.run(["git", "-C", root, "commit", "--allow-empty", "-m", "init", "-q"], check=True)


class ZwTraceTests(unittest.TestCase):
    def test_concurrent_appends_20_processes(self):
        with tempfile.TemporaryDirectory() as d:
            init_repo(d)
            env = clean_env()
            procs = [
                subprocess.Popen(
                    [ZW_PATH, "emit", "span", f"name=p{i}", "duration=0.5", "load=1.25"],
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
                self.assertEqual(ev["kind"], "span")
                self.assertEqual(ev["duration"], 0.5)
                self.assertEqual(ev["attributes"], {"load": 1.25})
                self.assertTrue(ev["ts"].endswith("Z"))
                names.add(ev["name"])
            self.assertEqual(names, {f"p{i}" for i in range(20)})

    def test_emit_outside_git_and_unwritable_log(self):
        with tempfile.TemporaryDirectory() as d:
            env = clean_env()
            r1 = subprocess.run([ZW_PATH, "emit", "span", "name=x"], cwd=d, env=env,
                                capture_output=True, text=True)
            self.assertEqual(r1.returncode, 0)
            self.assertEqual(r1.stdout, "")
            self.assertEqual(r1.stderr, "")

            blocker = pathlib.Path(d) / "not-a-dir"
            blocker.write_text("file", encoding="utf-8")
            env_bad = {**env, "ZW_LOG": str(blocker / "events.jsonl"), "ZW_TASK": "t-1"}
            r2 = subprocess.run([ZW_PATH, "emit", "span", "name=y"], cwd=d, env=env_bad,
                                capture_output=True, text=True)
            self.assertEqual(r2.returncode, 0)
            self.assertEqual(r2.stdout, "")
            self.assertEqual(r2.stderr, "")

    def test_a_span_s_own_fields_are_named_and_every_other_is_a_tag(self):
        with tempfile.TemporaryDirectory() as d:
            log = pathlib.Path(d) / "events.jsonl"
            ev = emitted(log, "span", "name=1e5", "start=2026-11-16T10:00:00.000Z", "duration=2.5",
                         "status=ERROR", "trace_id=" + "1" * 32, "span_id=1234567890123e10",
                         "parent_span_id=" + "3" * 16, "group=build", "tries=3", "load=1.5",
                         "reason=game died", "--json",
                         json.dumps({"crates": ["a", "b"], "game_ms": {"shown": 315.0}}))
            # The envelope, then the span's fields in OpenTelemetry's names, then its tags.
            self.assertEqual(list(ev), ["ts", "kind", "task", "session", "branch", "worktree", "pid",
                                        "name", "trace_id", "span_id", "parent_span_id", "start",
                                        "duration", "status", "attributes"])
            self.assertEqual((ev["kind"], ev["task"]), ("span", "t-1"))
            # A name and an ID stay text though they read as numbers; a tag that reads as one is one.
            self.assertEqual({k: ev[k] for k in ("name", "trace_id", "span_id", "parent_span_id",
                                                 "start", "duration", "status")},
                             {"name": "1e5", "trace_id": "1" * 32, "span_id": "1234567890123e10",
                              "parent_span_id": "3" * 16, "start": "2026-11-16T10:00:00.000Z",
                              "duration": 2.5, "status": "ERROR"})
            self.assertEqual(ev["attributes"], {"group": "build", "tries": 3, "load": 1.5,
                                                "reason": "game died", "crates": ["a", "b"],
                                                "game_ms": {"shown": 315.0}})

    def test_a_tag_named_as_one_of_a_span_s_own_fields_stays_a_tag(self):
        with tempfile.TemporaryDirectory() as d:
            log = pathlib.Path(d) / "events.jsonl"
            # Tags go under --json's `attributes`, where any name is a tag's; the span's own
            # fields are what `key=value` gave, whatever --json says beside them.
            tags = {"name": "a tag", "status": "PASS", "start": "never", "duration": "long",
                    "seconds": 3, "span_id": "f" * 16, "trace_id": "f" * 32,
                    "parent_span_id": "f" * 16, "attributes": {"nested": 1}}
            ev = emitted(log, "span", "name=build", "start=2026-11-16T10:00:00.000Z", "duration=2.5",
                         "status=OK", "trace_id=" + "1" * 32, "span_id=" + "2" * 16, "seconds=9",
                         "--json", json.dumps({"attributes": tags, "name": "not this",
                                               "status": "ERROR", "duration": 99}))
            self.assertEqual({k: ev.get(k) for k in ("name", "trace_id", "span_id", "parent_span_id",
                                                     "start", "duration", "status")},
                             {"name": "build", "trace_id": "1" * 32, "span_id": "2" * 16,
                              "parent_span_id": None, "start": "2026-11-16T10:00:00.000Z",
                              "duration": 2.5, "status": "OK"})
            # `seconds` is no field of a span's: given beside the tags, it is one more.
            self.assertEqual(ev["attributes"], {**tags, "seconds": 9})
            # And they read back as tags, the span's own fields still its own: a report
            # groups by its name, and reaches a tag of that name as `attributes.name`.
            self.assertEqual(span_report(log, "--where", "seconds=9")["total"]["count"], 1)
            self.assertEqual(span_report(log, "--by", "name")["rows"][0]["key"], {"name": "build"})
            self.assertEqual(span_report(log, "--where", "status=OK", "--where", "attributes.status=PASS",
                                         "--by", "attributes.name,attributes.attributes.nested"
                                         )["rows"][0]["key"],
                             {"attributes.name": "a tag", "attributes.attributes.nested": "1"})

    def test_a_span_without_ids_gets_its_own_under_the_one_traceparent_names(self):
        with tempfile.TemporaryDirectory() as d:
            log = pathlib.Path(d) / "events.jsonl"
            alone = emitted(log, "span", "name=a", "duration=1")
            self.assertRegex(alone["trace_id"], r"^[0-9a-f]{32}$")
            self.assertRegex(alone["span_id"], r"^[0-9a-f]{16}$")
            self.assertNotIn("parent_span_id", alone)
            self.assertEqual((alone["status"], alone["duration"]), ("UNSET", 1.0))
            # A start it didn't give is its duration before it was written.
            written = zw_time(alone["ts"])
            self.assertAlmostEqual((written - zw_time(alone["start"])).total_seconds(), 1.0, places=1)

            parent = "00-" + "ab" * 16 + "-" + "cd" * 8 + "-01"
            child = emitted(log, "span", "name=b", "duration=1", TRACEPARENT=parent)
            self.assertEqual((child["trace_id"], child["parent_span_id"]), ("ab" * 16, "cd" * 8))
            self.assertNotIn(child["span_id"], ("cd" * 8, alone["span_id"]))

            # An emitter that names its own trace is not put under the environment's span.
            own = emitted(log, "span", "name=c", "duration=1", "trace_id=" + "9" * 32,
                          "span_id=" + "8" * 16, TRACEPARENT=parent)
            self.assertEqual((own["trace_id"], own["span_id"]), ("9" * 32, "8" * 16))
            self.assertNotIn("parent_span_id", own)

    def test_only_a_span_is_a_span(self):
        with tempfile.TemporaryDirectory() as d:
            log = pathlib.Path(d) / "events.jsonl"
            # Another kind is written as given: no IDs, no tags.
            ev = emitted(log, "step", "group=check", "name=clippy", "seconds=12.5", "status=PASS")
            self.assertEqual({k: v for k, v in ev.items() if k not in ("ts", "pid", "session", "branch",
                                                                       "worktree")},
                             {"kind": "step", "task": "t-1", "group": "check", "name": "clippy",
                              "seconds": 12.5, "status": "PASS"})
            # A status is one of OpenTelemetry's three, as written, or the span's is unset.
            self.assertEqual([emitted(log, "span", "name=x", f"status={word}")["status"]
                              for word in ("OK", "ERROR", "UNSET", "PASS", "ok")],
                             ["OK", "ERROR", "UNSET", "UNSET", "UNSET"])
            # Neither report reads the `step` line: six events, five spans.
            self.assertEqual(span_report(log)["total"]["count"], 5)
            per_task = subprocess.run([ZW_PATH, "report", "t-1", "--json"], env=clean_env(ZW_LOG=str(log)),
                                      capture_output=True, text=True, check=True)
            self.assertEqual(json.loads(per_task.stdout)[0]["spans"],
                             {"other": {"count": 5, "sum_seconds": 0.0, "union_seconds": 0.0}})

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
                # Overlapping spans in group 'check': [10..20] (10s) and [14..24] (10s)
                # -> sum 20s, union 14s
                {"ts": "2026-11-16T10:00:20.000Z", "kind": "span", "task": "foo-20261116T100000Z",
                 "session": None, "branch": "agent/foo", "worktree": d, "pid": 3,
                 "name": "clippy", "trace_id": "ab" * 16, "span_id": "12" * 8,
                 "start": "2026-11-16T10:00:10.000Z", "duration": 10.0, "status": "OK",
                 "attributes": {"group": "check", "load": 1.0}},
                {"ts": "2026-11-16T10:00:24.000Z", "kind": "span", "task": "foo-20261116T100000Z",
                 "session": None, "branch": "agent/foo", "worktree": d, "pid": 4,
                 "name": "test", "trace_id": "ab" * 16, "span_id": "cd" * 8,
                 "start": "2026-11-16T10:00:14.000Z", "duration": 10.0, "status": "OK",
                 "attributes": {"group": "check", "load": 1.0}},
                # A span with no group is counted under 'other'.
                {"ts": "2026-11-16T10:00:26.000Z", "kind": "span", "task": "foo-20261116T100000Z",
                 "session": None, "branch": "agent/foo", "worktree": d, "pid": 4,
                 "name": "gpu studio", "trace_id": "ab" * 16, "span_id": "ef" * 8,
                 "start": "2026-11-16T10:00:21.000Z", "duration": 5.0, "status": "OK",
                 "attributes": {}},
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
            self.assertEqual(rep["spans"], {
                "check": {"count": 2, "sum_seconds": 20.0, "union_seconds": 14.0},
                "other": {"count": 1, "sum_seconds": 5.0, "union_seconds": 5.0}})
            self.assertEqual(rep["msgs"], 1)
            self.assertEqual(rep["tokens"], "n/a (phase 2)")

    def test_span_report_shows_one_name_s_trend_across_tasks_and_none(self):
        with tempfile.TemporaryDirectory() as d:
            # One name over three days, in two tasks and in none; a `step` line is no span.
            log = write_log(d, [
                span("2026-11-14T10:00:00.000Z", "_build studio", 10.0, task="a-1", load=2.0),
                span("2026-11-14T11:00:00.000Z", "_build studio", 20.0, "ERROR", task="a-1", load=4.0),
                span("2026-11-15T10:00:00.000Z", "_build studio", 30.0, load=6.0),
                span("2026-11-15T11:00:00.000Z", "_build studio", 0.0, "UNSET", load=50.0),
                step("2026-11-15T12:00:00.000Z", "_build studio", 999.0),
                span("2026-11-16T10:00:00.000Z", "_build studio", 40.0, group="build", load=8.0),
                span("2026-11-16T11:00:00.000Z", "_build studio", 50.0, task="b-1", group="build",
                     load=10.0),
                span("2026-11-16T12:00:00.000Z", "launch studio", 3.0, group="other"),
                event("2026-11-16T12:00:00.000Z", "agent.state", "b-1", state="working"),
            ])
            # Several names: a row each, beside each other, and all of them.
            names = span_report(log)
            self.assertEqual(names["by"], ["name"])
            self.assertEqual([(r["key"]["name"], r["count"]) for r in names["rows"]],
                             [("_build studio", 6), ("launch studio", 1)])
            self.assertEqual(names["total"]["count"], 7)

            # One name: its trend, a row per day. A span that never ran (UNSET) is counted,
            # but neither its duration nor the load it didn't run under.
            trend = span_report(log, "_build")
            self.assertEqual(trend["by"], ["day"])
            self.assertEqual(trend["rows"], [
                {"key": {"day": "2026-11-14"}, "count": 2, "ok": 1, "error": 1,
                 "median": 15.0, "p90": 20.0, "latest": 20.0, "load": 3.0},
                {"key": {"day": "2026-11-15"}, "count": 2, "ok": 1, "error": 0,
                 "median": 30.0, "p90": 30.0, "latest": 30.0, "load": 6.0},
                {"key": {"day": "2026-11-16"}, "count": 2, "ok": 2, "error": 0,
                 "median": 45.0, "p90": 50.0, "latest": 50.0, "load": 9.0},
            ])
            self.assertEqual(trend["total"], {"count": 6, "ok": 4, "error": 1, "median": 30.0,
                                              "p90": 50.0, "latest": 50.0, "load": 6.0})

            # In no task (the person's own runs), and by task.
            mine = span_report(log, "_build studio", "--where", "task=")
            self.assertEqual([(r["key"]["day"], r["count"]) for r in mine["rows"]],
                             [("2026-11-15", 2), ("2026-11-16", 1)])
            by_task = span_report(log, "_build studio", "--by", "task")
            self.assertEqual([(r["key"]["task"], r["count"], r["median"]) for r in by_task["rows"]],
                             [("-", 3, 35.0), ("a-1", 2, 15.0), ("b-1", 1, 50.0)])

    def test_span_report_filters_and_groups_by_any_tag_and_a_window(self):
        with tempfile.TemporaryDirectory() as d:
            log = write_log(d, [
                span("2026-11-14T10:00:00.000Z", "_build studio", 100.0, recipe="studio",
                     crates=["purge_frontend", "purge-game"]),
                span("2026-11-15T10:00:00.000Z", "_build studio", 2.0, group="build", recipe="studio",
                     crates=["purge_model_studio", "purge-game"]),
                span("2026-11-16T10:00:00.000Z", "_build gpu studio", 4.0, group="build",
                     recipe="gpu studio", crates=[]),
                span("2026-11-16T10:00:05.000Z", "launch gpu studio game-shown", 6.0, group="other",
                     recipe="gpu studio", game_ms={"shown": 2166.0}),
                span("2026-11-16T10:01:00.000Z", "studio-hot patch", 1.0, "ERROR", group="build",
                     recipe="studio-hot", reason="game died"),
            ])

            def names(*args):
                report = span_report(log, *args, "--by", "name")
                return [r["key"]["name"] for r in report["rows"]]

            # A tag an emitter made up filters without `zw` knowing it; several narrow together.
            self.assertEqual(names("--where", "reason=game died"), ["studio-hot patch"])
            self.assertEqual(names("--where", "group=build", "--where", "recipe=gpu studio"),
                             ["_build gpu studio"])
            # A list holds the value; a tag inside another is dotted; a span's own field is a key.
            self.assertEqual(names("--where", "crates=purge_frontend"), ["_build studio"])
            self.assertEqual(names("--where", "game_ms.shown=2166.0"), ["launch gpu studio game-shown"])
            self.assertEqual(names("--where", "status=ERROR"), ["studio-hot patch"])
            # `KEY=` is the spans without the tag or with nothing in it: a build of no crate.
            self.assertEqual(names("--where", "crates="),
                             ["_build gpu studio", "launch gpu studio game-shown", "studio-hot patch"])
            self.assertEqual(names("--where", "crates=", "--where", "group=build", "--where", "reason="),
                             ["_build gpu studio"])
            # A window: ISO times, or days ago; a date it ends on is taken in whole.
            self.assertEqual(names("--since", "2026-11-15T00:00:00Z", "--until", "2026-11-16T10:00:01Z"),
                             ["_build gpu studio", "_build studio"])
            self.assertEqual(names("--since", "2026-11-15", "--until", "2026-11-15"), ["_build studio"])
            self.assertEqual(len(names("--until", "2026-11-16")), 4)
            self.assertEqual(names("--since", "0.001"), [])
            self.assertEqual(len(names("--since", "36500")), 4)

            by_recipe = span_report(log, "--by", "recipe,status")
            self.assertEqual([(r["key"], r["count"]) for r in by_recipe["rows"]], [
                ({"recipe": "gpu studio", "status": "OK"}, 2),
                ({"recipe": "studio", "status": "OK"}, 2),
                ({"recipe": "studio-hot", "status": "ERROR"}, 1)])

    def test_span_report_draws_a_run_as_a_tree(self):
        with tempfile.TemporaryDirectory() as d:
            log = write_log(d, [
                # Children are written before the parent that outlasts them.
                span("2026-11-16T10:00:06.000Z", "launch gpu studio game-shown", 6.0, span_id="c" * 16,
                     parent="a" * 16, group="other"),
                span("2026-11-16T10:00:01.000Z", "_build gpu studio", 4.0, span_id="b" * 16,
                     parent="a" * 16, group="build"),
                span("2026-11-16T10:00:00.000Z", "gpu studio", 13.0, span_id="a" * 16, recipe="gpu studio"),
                span("2026-11-16T11:00:00.000Z", "gpu studio", 9.0, "ERROR", span_id="d" * 16),
                span("2026-11-16T12:00:00.000Z", "check", 9.0, span_id="e" * 16),
                span("2026-11-16T09:00:00.000Z", "gpu studio", 1.0),
                # Another trace's span with an ID seen above: an ID is its trace's alone.
                span("2026-11-16T09:00:00.000Z", "gpu studio", 2.0, span_id="a" * 16, trace="cd" * 16),
                span("2026-11-16T09:00:01.000Z", "_build gpu studio", 0.5, parent="a" * 16,
                     trace="cd" * 16),
            ])

            def shape(nodes):
                return [(n["name"], n["duration"], shape(n["children"])) for n in nodes]

            self.assertEqual(shape(span_report(log, "gpu studio", "--tree")), [
                ("gpu studio", 1.0, []),
                ("gpu studio", 2.0, [("_build gpu studio", 0.5, [])]),
                ("gpu studio", 13.0, [("_build gpu studio", 4.0, []),
                                      ("launch gpu studio game-shown", 6.0, [])]),
                ("gpu studio", 9.0, []),
            ])
            # A matching span under a matching one is drawn once, under it.
            self.assertEqual(shape(span_report(log, "--where", "trace_id=" + "ab" * 16, "--since",
                                               "2026-11-16T09:30:00Z", "--until", "2026-11-16T10:30:00Z",
                                               "--tree")),
                             [("gpu studio", 13.0, [("_build gpu studio", 4.0, []),
                                                    ("launch gpu studio game-shown", 6.0, [])])])
            text = subprocess.run([ZW_PATH, "report", "--spans", "gpu studio", "--tree", "--since",
                                   "2026-11-16T09:30:00Z", "--until", "2026-11-16T10:30:00Z"],
                                  env=clean_env(ZW_LOG=str(log), TZ="UTC"), capture_output=True, text=True)
            self.assertEqual(text.stdout.splitlines(), [
                "2026-11-16 10:00:00  gpu studio  13.0s OK  recipe=gpu studio",
                "                       _build gpu studio  4.00s OK  group=build",
                "                       launch gpu studio game-shown  6.00s OK  group=other",
            ])

    def test_span_report_table_and_what_it_refuses(self):
        with tempfile.TemporaryDirectory() as d:
            log = write_log(d, [
                span("2026-11-15T10:00:00.000Z", "_build studio", 2.0, load=6.0),
                span("2026-11-16T10:00:00.000Z", "_build studio", 113.2, group="build", load=8.0),
            ])
            env = clean_env(ZW_LOG=str(log), TZ="UTC")
            table = subprocess.run([ZW_PATH, "report", "--spans", "_build"], env=env,
                                   capture_output=True, text=True)
            self.assertEqual(table.stdout.splitlines(), [
                "span: _build studio",
                "day         count  ok  error  median    p90  latest  load",
                "2026-11-15      1   1      0   2.00s  2.00s   2.00s   6.0",
                "2026-11-16      1   1      0    113s   113s    113s   8.0",
                "all             2   2      0   57.6s   113s    113s   7.0",
            ])
            none = subprocess.run([ZW_PATH, "report", "--spans", "nothing"], env=env,
                                  capture_output=True, text=True)
            self.assertEqual((none.returncode, none.stdout), (0, "No spans match.\n"))
            refused = subprocess.run([ZW_PATH, "report", "--by", "name"], env=env,
                                     capture_output=True, text=True)
            self.assertNotEqual(refused.returncode, 0)
            self.assertIn("zw report --spans", refused.stderr)
            # What can't be read is refused in a line, not a traceback.
            for args, names in ((["--by", "name,name"], "--by name,name"), (["--by", "name,"], "--by"),
                                (["--since", "inf"], "inf"), (["--since", "1e9"], "1e9"),
                                (["--until", "nan"], "nan"), (["--since", "yesterday"], "yesterday"),
                                (["--where", "group"], "--where group")):
                refused = subprocess.run([ZW_PATH, "report", "--spans", *args], env=env,
                                         capture_output=True, text=True)
                self.assertEqual((refused.returncode, refused.stdout), (1, ""), args)
                self.assertEqual(len(refused.stderr.splitlines()), 1, refused.stderr)
                self.assertIn(names, refused.stderr)

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


def zw_time(text):
    import datetime
    return datetime.datetime.fromisoformat(text.replace("Z", "+00:00"))


if __name__ == "__main__":
    unittest.main()
