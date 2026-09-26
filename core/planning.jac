"""Deterministic scheduling: no paid AI, external calendar, or hidden data."""
import from datetime { date }

def _valid_date(value: str) -> str {
    parsed = date.fromisoformat(value);
    if parsed.isoformat() != value {
        raise ValueError("Use a date in YYYY-MM-DD format.");
    }
    return value;
}

def _task_order(t: dict[str, any]) -> tuple[str, int, str, str] {
    return (t["due"], -t["priority"], t["title"], t["id"]);
}

def _make_plan(tasks: list[dict[str, any]], day: str, budget: int) -> dict[str, any] {
    _valid_date(day);
    if budget < 5 or budget > 720 {
        raise ValueError("Available time must be between 5 and 720 minutes.");
    }
    pending = [t for t in tasks if not t["done"] and not t.get("archived", False)];
    pending.sort(key=_task_order);
    blocks: list[dict[str, any]] = [];
    elapsed = 0;
    study = 0;
    allocated: dict[str, any] = {};
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

# Each capacity includes breaks. Deadline warnings use only allocations on/before
# the deadline, even when later days have ample room to catch up.
def _make_week(tasks: list[dict[str, any]], start: str, budgets: list[int]) -> dict[str, any] {
    _valid_date(start);
    if len(budgets) < 1 or len(budgets) > 14 {
        raise ValueError("Provide 1–14 daily budgets.");
    }
    for budget in budgets {
        if budget != 0 and (budget < 5 or budget > 720) {
            raise ValueError("Each daily budget must be 0 (day off) or 5–720 minutes.");
        }
    }
    original = [dict(t) for t in tasks if not t["done"] and not t.get("archived", False)];
    remaining = [dict(t) for t in original];
    days: list[dict[str, any]] = [];
    on_time: dict[str, any] = {};
    for (i, budget) in enumerate(budgets) {
        day = date.fromordinal(date.fromisoformat(start).toordinal() + i).isoformat();
        p = _make_plan(remaining, day, budget) if budget else _make_plan([], day, 5);
        p["budget"] = budget;
        for block in p["blocks"] {
            for t in remaining {
                if t["id"] == block["id"] { t["minutes"] -= block["minutes"]; }
            }
            if day <= block["due"] {
                on_time[block["id"]] = on_time.get(block["id"], 0) + block["minutes"];
            }
        }
        p["remaining"] = sum(t["minutes"] for t in remaining);
        p["urgent_unplanned"] = sum(t["minutes"] for t in remaining if t["due"] <= day);
        p["late"] = sum(b["minutes"] for b in p["blocks"] if b["overdue"]);
        days.append(p);
    }
    end = days[-1]["day"];
    risks: list[dict[str, any]] = [];
    for t in original {
        missing = t["minutes"] - on_time.get(t["id"], 0);
        if t["due"] <= end and missing > 0 {
            risks.append({"id": t["id"], "title": t["title"], "due": t["due"],
                "minutes": missing, "overdue": t["due"] < start});
        }
    }
    risks.sort(key=lambda (r: dict[str, any]) { (r["due"], r["title"]); });
    return {"start": start, "end": end, "days": days, "risks": risks,
        "study": sum(p["study"] for p in days),
        "breaks": sum(p["breaks"] for p in days), "capacity": sum(budgets),
        "remaining": sum(t["minutes"] for t in remaining),
        "deadline_shortfall": sum(r["minutes"] for r in risks if not r["overdue"]),
        "overdue_minutes": sum(r["minutes"] for r in risks if r["overdue"]),
        "rule": "Earliest deadline, then priority; 25-minute focus / 5-minute breaks within each day. Later work is catch-up, not on-time completion. Plans do not change tasks."};
}
