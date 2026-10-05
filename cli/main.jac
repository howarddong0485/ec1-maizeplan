"""Terminal client. All planning mutations travel to the running server."""
import argparse;
import json;
import os;
import sys;
import from pathlib { Path }
import from datetime { date }
import from getpass { getpass }
import from uuid { uuid4 }
import from urllib.request { Request, urlopen }
import from urllib.error { HTTPError }

def _request(server: str, path: str, token: str, payload: dict[str, any]) -> dict[str, any] {
    headers = {"Content-Type": "application/json"};
    if token { headers["Authorization"] = "Bearer " + token; }
    req = Request(server.rstrip("/") + path, data=json.dumps(payload).encode("utf-8"),
        headers=headers, method="POST");
    try {
        with urlopen(req, timeout=20) as response { body = json.load(response); }
    } except HTTPError as err {
        raise RuntimeError(f"HTTP {err.code}: {err.read().decode('utf-8')}");
    }
    if not body.get("ok") { raise RuntimeError(str(body.get("error", body))); }
    return body["data"];
}

def _parser -> argparse.ArgumentParser {
    p = argparse.ArgumentParser(description="MaizePlan — one account, one server, every interface.");
    p.add_argument("--server", `default="http://127.0.0.1:8001");
    p.add_argument("--json", action="store_true", help="Machine-readable output");
    sub = p.add_subparsers(dest="command", required=True);
    for name in ["register", "login"] {
        cmd = sub.add_parser(name); cmd.add_argument("username");
    }
    sub.add_parser("logout");
    sample = sub.add_parser("sample", help="Load the demo once into an empty account; never resets existing data");
    sample.add_argument("--day", `default=date.today().isoformat(), help="Sample deadline and first capacity date (default: today)");
    listing = sub.add_parser("list");
    listing.add_argument("--all", action="store_true", help="Include completed tasks");
    listing.add_argument("--today", action="store_true", help="Only due or overdue tasks");
    listing.add_argument("--archived", action="store_true", help="Show only archived tasks, including completed ones");
    add = sub.add_parser("add"); add.add_argument("title");
    add.add_argument("--course", `default="");
    add.add_argument("--due", required=True, help="YYYY-MM-DD");
    add.add_argument("--priority", `type=int, choices=[1, 2, 3], `default=2);
    add.add_argument("--minutes", `type=int, `default=30);
    for name in ["done", "reopen", "archive", "restore"] {
        cmd = sub.add_parser(name); cmd.add_argument("id", help="Full task ID from list --json");
    }
    plan = sub.add_parser("plan");
    plan.add_argument("--day", `default=date.today().isoformat());
    plan.add_argument("--minutes", `type=int, `default=120);
    study = sub.add_parser("study", help="Record actual study time and reduce remaining work");
    study.add_argument("id");
    study.add_argument("--minutes", `type=int, required=True);
    study.add_argument("--day", `default=date.today().isoformat());
    study.add_argument("--request-id", `default="", help="Reuse this ID when retrying an uncertain request");
    history = sub.add_parser("history", help="Show saved study records including undone records");
    history.add_argument("--audit", action="store_true", help="Show the immutable correction trail");
    for name in ["correct", "undo-study"] {
        correction = sub.add_parser(name, help="Correct/restore or undo a study record");
        correction.add_argument("id", help="Study record ID from history");
        correction.add_argument("--minutes", `type=int, required=name == "correct");
        correction.add_argument("--day", help="Corrected date; defaults to the current record date");
        correction.add_argument("--version", `type=int, help="Expected record version; reuse the printed version for a retry");
        correction.add_argument("--request-id", `default="");
    }
    capacity = sub.add_parser("capacity", help="View or save your Monday–Sunday capacity");
    capacity.add_argument("--budgets", help="Seven comma-separated capacities, Monday through Sunday");
    week = sub.add_parser("week", help="Plan 1–14 days with deadline warnings");
    week.add_argument("--start", `default=date.today().isoformat());
    week.add_argument("--budgets", help="Override saved capacity with 1–14 daily minutes, starting on --start");
    return p;
}

def main -> int {
    args = _parser().parse_args();
    session_path = Path(".jac/cli-session.json");
    server = args.server.rstrip("/");
    if args.command == "logout" {
        if session_path.exists() { session_path.unlink(); }
        print("Local session removed. Server tasks are unchanged."); return 0;
    }
    if args.command in ["login", "register"] {
        password = getpass("Password (not stored): ");
        credential = {"type": "password", "password": password};
        if args.command == "register" {
            _request(server, "/user/register", "", {"identities": [{"type": "username", "value": args.username}], "credential": credential});
        }
        account = _request(server, "/user/login", "", {"identity": {"type": "username", "value": args.username}, "credential": credential});
        session_path.parent.mkdir(parents=True, exist_ok=True);
        descriptor = os.open(str(session_path), os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 384);
        os.chmod(str(session_path), 384);
        with os.fdopen(descriptor, "w") as stream {
            json.dump({"server": server, "token": account["token"]}, stream);
        }
        print("Signed in. Session saved locally with owner-only permissions."); return 0;
    }
    token = os.environ.get("MAIZEPLAN_TOKEN", "");
    if not token and session_path.exists() {
        session = json.loads(session_path.read_text());
        if session["server"] == server { token = session["token"]; }
    }
    if not token { raise RuntimeError("Sign in first: jac run cli login YOUR_USERNAME"); }
    payload: dict[str, any] = {};
    endpoint = "";
    if args.command == "list" { endpoint = "list_tasks"; payload = {"include_archived": args.archived}; }
    elif args.command == "sample" { endpoint = "load_sample"; payload = {"day": args.day}; }
    elif args.command == "add" {
        endpoint = "save_task";
        payload = {"title": args.title, "course": args.course, "due": args.due,
            "minutes": args.minutes, "priority": args.priority, "task_id": ""};
    } elif args.command in ["done", "reopen"] {
        endpoint = "set_done";
        payload = {"task_id": args.id, "done": args.command == "done"};
    } elif args.command in ["archive", "restore"] {
        endpoint = "archive_task";
        payload = {"task_id": args.id, "archived": args.command == "archive"};
    } elif args.command == "plan" {
        endpoint = "day_plan"; payload = {"day": args.day, "budget": args.minutes};
    }
    elif args.command == "study" {
        endpoint = "log_study";
        request_id = args.request_id or str(uuid4());
        print("Study request ID (reuse for retries): " + request_id, file=sys.stderr);
        payload = {"task_id": args.id, "minutes": args.minutes, "day": args.day, "request_id": request_id};
    } elif args.command == "history" { endpoint = "list_sessions"; }
    elif args.command in ["correct", "undo-study"] {
        rows = _request(server, "/function/list_sessions", token, {})["result"];
        matches = [s for s in rows if s["id"] == args.id];
        if not matches { raise ValueError("Study record not found in your account."); }
        s = matches[0];
        version = s["version"] if args.version is None else args.version;
        request_id = args.request_id or str(uuid4());
        print(f"Correction request ID: {request_id}; version: {version}. Reuse both for retries.", file=sys.stderr);
        endpoint = "revise_study";
        payload = {"session_id": args.id, "minutes": s["minutes"] if args.minutes is None else args.minutes,
            "day": args.day or s["day"], "voided": args.command == "undo-study",
            "expected_version": version, "request_id": request_id};
    } elif args.command == "capacity" {
        endpoint = "get_capacity";
        if args.budgets {
            endpoint = "save_capacity"; payload = {"budgets": [int(v.strip()) for v in args.budgets.split(",")]};
        }
    }
    elif args.command == "week" {
        endpoint = "week_plan";
        payload = {"start": args.start};
        if args.budgets is not None { payload["budgets"] = [int(v.strip()) for v in args.budgets.split(",")]; }
    }
    result = _request(server, "/function/" + endpoint, token, payload)["result"];
    if args.command == "list" {
        result = [t for t in result if t["archived"] == args.archived and (args.archived or args.all or not t["done"]) and (not args.today or t["due"] <= date.today().isoformat())];
    }
    if args.json { print(json.dumps(result, indent=2, ensure_ascii=False)); return 0; }
    if args.command == "list" {
        if not result { print("No tasks match."); }
        for t in result {
            status = "archived" if t["archived"] else ("done" if t["done"] else "open");
            print(f"[{status}] {t['title']} | {t['course']} | due {t['due']} | {t['minutes']}m | P{t['priority']}");
            print("  ID: " + t["id"]);
        }
    } elif args.command == "plan" {
        print(result["rule"]);
        for b in result["blocks"] { print(f"+{b['start']}m  {b['title']} ({b['minutes']}m focus)"); }
        print(f"Focus {result['study']}m / breaks {result['breaks']}m / unplanned {result['remaining']}m");
        if result["urgent_unplanned"] { print(f"WARNING: {result['urgent_unplanned']}m of due/overdue work does not fit."); }
    } elif args.command == "study" {
        print(f"Recorded {result['minutes']}m for {result['title']}; remaining estimate reduced by {result['credited']}m.");
    } elif args.command == "history" {
        if not result { print("No study records yet."); }
        print(f"Active focus total: {sum(s['minutes'] for s in result if not s['voided'])}m");
        for s in result {
            print(f"{s['day']} | {s['title']} | studied {s['minutes']}m | reduced estimate {s['credited']}m | {'UNDONE' if s['voided'] else 'active'}");
            print(f"  ID: {s['id']} | version: {s['version']}");
            if args.audit {
                print(f"  Original: {s['original_day']} | {s['original_minutes']}m");
                for c in s["changes"] { print(f"  Revision {c['version']}: {c['day']} | {c['minutes']}m | {'undone' if c['voided'] else 'active'} | remaining adjustment {c['remaining_delta']}m | {'estimate adjusted' if c['estimate_adjusted'] else 'manual estimate preserved'}"); }
            }
        }
    } elif args.command in ["correct", "undo-study"] {
        print(f"Study record {'undone' if result['voided'] else 'corrected/restored'}; remaining adjustment {result['remaining_delta']}m.");
        if not result["estimate_adjusted"] { print("Your newer manual estimate was preserved; only history changed."); }
    } elif args.command == "capacity" {
        print("Saved weekly capacity (including breaks):" if result["saved"] else "Default weekly capacity (not yet saved):");
        for (i, name) in enumerate(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]) { print(f"{name}: {result['budgets'][i]}m"); }
    } elif args.command == "week" {
        print(result["rule"]);
        scale = max([d["budget"] for d in result["days"]] + [1]);
        print("Workload: # focus, + breaks, . free (shared minutes scale)");
        for d in result["days"] {
            bar = "#" * int(d["study"] * 30 / scale) + "+" * int(d["breaks"] * 30 / scale) + "." * int((d["budget"] - d["elapsed"]) * 30 / scale);
            print("[" + bar.ljust(30) + "] " + ("DAY OFF" if not d["budget"] else ""));
            print(f"{d['day']}: budget {d['budget']}m / focus {d['study']}m / breaks {d['breaks']}m");
            for b in d["blocks"] { print(f"  +{b['start']}m {b['title']} ({b['minutes']}m){' LATE' if b['overdue'] else ''}"); }
        }
        for r in result["risks"] { print(f"WARNING: {r['title']} due {r['due']}: {r['minutes']}m {'already overdue' if r['overdue'] else 'cannot fit by deadline'}"); }
        print(f"Unscheduled after this horizon: {result['remaining']}m");
    } elif args.command == "sample" {
        print(result["message"]);
        print("Sample date: " + result["day"] + " | Task ID: " + result["task_id"]);
        print("Next: jac run cli week --start " + result["day"]);
    } else { print(f"Saved: {result['title']} (ID: {result['id']})"); }
    return 0;
}

with entry {
    try { sys.`exit(main()); }
    except Exception as err { print("MaizePlan: " + str(err), file=sys.stderr); sys.`exit(1); }
}
