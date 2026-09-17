"""Deterministic scheduling: no paid AI, external calendar, or hidden data."""
import from datetime { date }

def _valid_date(value: str) -> str {
    parsed = date.fromisoformat(value);
    if parsed.isoformat() != value {
        raise ValueError("Use a date in YYYY-MM-DD format.");
    }
    return value;
}

def _task_order(t: dict) -> tuple {
    return (t["due"], -t["priority"], t["title"], t["id"]);
}

def _make_plan(tasks: list[dict], day: str, budget: int) -> dict {
    _valid_date(day);
    if budget < 5 or budget > 720 {
        raise ValueError("Available time must be between 5 and 720 minutes.");
    }
    pending = [t for t in tasks if not t["done"]];
    pending.sort(key=_task_order);
    blocks: list[dict] = [];
    elapsed = 0;
    study = 0;
    allocated: dict = {};
    for task in pending {
        remaining = task["minutes"];
        while remaining > 0 {
            pause = 5 if len(blocks) > 0 else 0;
            available = budget - elapsed - pause;
            if available <= 0 { break; }
            length = min(25, remaining, available);
            elapsed += pause;
            blocks.append({"id": task["id"], "title": task["title"],
                "course": task["course"], "start": elapsed, "minutes": length,
                "due": task["due"], "overdue": task["due"] < day,
                "break_before": pause});
            remaining -= length;
            elapsed += length;
            study += length;
            allocated[task["id"]] = allocated.get(task["id"], 0) + length;
        }
        if elapsed >= budget { break; }
    }
    total = sum(t["minutes"] for t in pending);
    urgent = sum(t["minutes"] for t in pending if t["due"] <= day);
    urgent_scheduled = sum(b["minutes"] for b in blocks if b["due"] <= day);
    return {"day": day, "budget": budget, "blocks": blocks, "study": study,
        "breaks": elapsed - study, "elapsed": elapsed, "remaining": total - study,
        "urgent_unplanned": urgent - urgent_scheduled,
        "rule": "Earliest deadline first; ties use priority. Up to 25 minutes of focus, then a 5-minute break. This is a suggestion, not a saved calendar."};
}
