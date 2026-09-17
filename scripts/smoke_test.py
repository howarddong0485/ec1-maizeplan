"""Integration checks against a RUNNING Jac server, never a mocked backend.

Creates two uniquely named test accounts and tasks; it does not delete accounts.
Use a local development server. No real user credentials are read or printed.
Requires Python 3.10+ and jac on PATH (or --jac /path/to/jac).
"""
import argparse
import json
import os
import secrets
import subprocess
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError


def call(base, path, payload, token=""):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    request = Request(base.rstrip("/") + path,
                      data=json.dumps(payload).encode(), headers=headers)
    try:
        with urlopen(request, timeout=30) as response:
            return response.status, json.load(response)
    except HTTPError as error:
        return error.code, json.load(error)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--server", default="http://127.0.0.1:8001")
    parser.add_argument("--jac", default="jac")
    state = parser.add_mutually_exclusive_group()
    state.add_argument("--write-restart-state", type=Path,
                       help="Save disposable test token/task for a later restart check")
    state.add_argument("--verify-restart-state", type=Path,
                       help="Verify the saved task after restarting the same server")
    args = parser.parse_args()
    base = args.server
    if args.verify_restart_state:
        saved = json.loads(args.verify_restart_state.read_text())
        assert saved["server"] == base, "Use the same server URL as before restart"
        status, body = call(base, "/function/list_tasks", {}, saved["token"])
        assert status == 200 and body["ok"], "Authentication failed after restart"
        rows = body["data"]["result"]
        assert saved["task"] in rows, "Saved task fields/state did not survive restart"
        print("PASS: authentication and exact task state persist after server restart.")
        return
    suffix = secrets.token_hex(5)
    password = secrets.token_urlsafe(24)
    tokens = []
    for label in ("a", "b"):
        username = "maize_test_" + suffix + label
        credential = {"type": "password", "password": password}
        status, body = call(base, "/user/register", {
            "identities": [{"type": "username", "value": username}],
            "credential": credential})
        assert status < 300 and body["ok"], f"Registration failed: {status}"
        status, body = call(base, "/user/login", {
            "identity": {"type": "username", "value": username},
            "credential": credential})
        assert status < 300 and body["ok"], "Login failed"
        tokens.append(body["data"]["token"])

    def rpc(name, payload=None, token=tokens[0]):
        status, body = call(base, "/function/" + name, payload or {}, token)
        assert status < 300 and body["ok"], f"{name} failed: {status} {body.get('error')}"
        return body["data"]["result"]

    status, body = call(base, "/function/list_tasks", {})
    assert status == 401 or not body["ok"], "Anonymous access was accepted"
    task = rpc("save_task", {"title": "Integration test", "course": "TEST",
                            "due": "2026-10-05", "priority": 3, "minutes": 60})
    assert rpc("list_tasks")[0]["id"] == task["id"]
    assert rpc("list_tasks", token=tokens[1]) == [], "Account data leaked"
    status, body = call(base, "/function/set_done", {
        "task_id": task["id"], "done": True}, tokens[1])
    assert status >= 400 or not body["ok"], "Cross-account mutation succeeded"
    status, body = call(base, "/function/save_task", {
        "title": "Bad date", "course": "TEST", "due": "2026-02-30",
        "priority": 2, "minutes": 20}, tokens[0])
    assert status >= 400 or not body["ok"], "Invalid date accepted"
    plan = rpc("day_plan", {"day": "2026-10-05", "budget": 40})
    assert plan["study"] == 35 and plan["elapsed"] == 40

    env = {**os.environ, "MAIZEPLAN_TOKEN": tokens[0]}
    def cli(*command):
        result = subprocess.run([args.jac, "run", "cli", "--server", base,
                                 "--json", *command], env=env, text=True,
                                capture_output=True, timeout=60)
        assert result.returncode == 0, result.stderr
        return json.loads(result.stdout)
    rows = cli("list")
    assert rows[0]["id"] == task["id"], "CLI did not read server data"
    cli("done", task["id"])
    assert rpc("list_tasks")[0]["done"], "CLI completion not reflected by server"
    cli("reopen", task["id"])
    assert not rpc("list_tasks")[0]["done"]
    added = cli("add", "CLI capture", "--course", "TEST", "--due", "2026-10-06",
                "--minutes", "25")
    assert added in rpc("list_tasks"), "CLI capture missing from server"
    updated = rpc("save_task", {"task_id": task["id"], "title": "Edited integration test",
                               "course": "TEST", "due": "2026-10-05",
                               "priority": 1, "minutes": 75})
    assert updated in cli("list"), "Server edit missing from CLI"
    assert cli("plan", "--day", "2026-10-05", "--minutes", "40") == rpc(
        "day_plan", {"day": "2026-10-05", "budget": 40}), "Plans differ across clients"
    status, body = call(base, "/function/save_task", {
        **{k: v for k, v in updated.items() if k not in ("id", "done")},
        "task_id": task["id"]}, tokens[1])
    assert status >= 400 or not body["ok"], "Cross-account edit succeeded"
    cli("done", task["id"])
    if args.write_restart_state:
        args.write_restart_state.parent.mkdir(parents=True, exist_ok=True)
        fd = os.open(args.write_restart_state, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        os.chmod(args.write_restart_state, 0o600)
        with os.fdopen(fd, "w") as stream:
            json.dump({"server": base, "token": tokens[0],
                       "task": {**updated, "done": True}}, stream)
        print("Saved restart-check state; keep it out of version control.")
    print("PASS: register/login, auth, account isolation, validation, task edits, CLI capture/synchronization, matching plans.")
    print("Two test accounts remain on this development server; no real user data changed.")
    print("Still verify browser/native interactions and persistence across a server restart.")


if __name__ == "__main__":
    main()
