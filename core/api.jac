"""All planning state belongs to the authenticated caller's persistent root."""
import from .planning { _valid_date, _task_order, _make_plan, _make_week }
import from datetime { date }

node Task {
    has title: str, course: str, due: str, priority: int, minutes: int;
    has done: bool = False, archived: bool = False, manual_done: bool = False;
    has effort_revision: int = 0;
    def view -> dict[str, any] {
        return {"id": jid(self), "title": self.title, "course": self.course,
            "due": self.due, "priority": self.priority, "minutes": self.minutes,
            "done": self.done, "archived": self.archived};
    }
}

def _all(include_archived: bool = False) -> list[dict[str, any]] {
    tasks = [t.view() for t in [root -->][?:Task] if include_archived or not t.archived];
    tasks.sort(key=_task_order);
    return tasks;
}

def:protect list_tasks(include_archived: bool = False) -> list[dict[str, any]] {
    # The HTTP binder stringifies omitted defaults; "False" must not include archives.
    return _all(include_archived is True);
}

def:protect save_task(title: str, course: str, due: str, priority: int,
                    minutes: int, task_id: str = "") -> dict[str, any] {
    title = title.strip();
    course = course.strip();
    if not title or len(title) > 160 { raise ValueError("Title must be 1–160 characters."); }
    if len(course) > 40 { raise ValueError("Course must be at most 40 characters."); }
    _valid_date(due);
    if priority not in [1, 2, 3] { raise ValueError("Priority must be 1, 2, or 3."); }
    if minutes < 1 or minutes > 1440 { raise ValueError("Estimate must be 1–1440 minutes."); }
    if task_id {
        for t in [root -->][?:Task] {
            if jid(t) == task_id {
                if t.archived { raise ValueError("Restore this task before editing it."); }
                if t.minutes != minutes { t.effort_revision += 1; }
                t.title = title; t.course = course; t.due = due;
                t.priority = priority; t.minutes = minutes;
                return t.view();
            }
        }
        raise ValueError("Task not found in your account.");
    }
    task = root ++> Task(title=title, course=course, due=due,
        priority=priority, minutes=minutes);
    return task.view();
}

def:protect set_done(task_id: str, done: bool) -> dict[str, any] {
    for t in [root -->][?:Task] {
        if jid(t) == task_id {
            if t.archived { raise ValueError("Restore this task before changing its completion."); }
            if not done and t.minutes == 0 { raise ValueError("Edit the remaining estimate on the web before reopening this task."); }
            t.done = done;
            t.manual_done = done;
            return t.view();
        }
    }
    raise ValueError("Task not found in your account.");
}

def:protect day_plan(day: str, budget: int = 120) -> dict[str, any] {
    return _make_plan(_all(), day, budget);
}

def:protect archive_task(task_id: str, archived: bool = True) -> dict[str, any] {
    for t in [root -->][?:Task] {
        if jid(t) == task_id {
            t.archived = archived is True or str(archived) == "True";
            return t.view();
        }
    }
    raise ValueError("Task not found in your account.");
}


node StudySession {
    has task_id: str, title: str, course: str, day: str, minutes: int;
    has credited: int, request_id: str;
    has effort_revision: int = 0;
    def view -> dict[str, any] {
        return {"id": jid(self), "task_id": self.task_id, "title": self.title,
            "course": self.course, "day": self.day, "minutes": self.minutes,
            "credited": self.credited, "request_id": self.request_id,
            "voided": False, "version": 0, "changes": []};
    }
}

node StudyChange {
    has session_id: str, request_id: str, minutes: int, day: str, voided: bool;
    has expected_version: int, credited: int, remaining_delta: int, estimate_adjusted: bool;
    def view -> dict[str, any] {
        return {"version": self.expected_version + 1, "minutes": self.minutes,
            "day": self.day, "voided": self.voided, "credited": self.credited,
            "remaining_delta": self.remaining_delta, "estimate_adjusted": self.estimate_adjusted};
    }
}

def _session_view(s: StudySession) -> dict[str, any] {
    result = s.view();
    changes = [c.view() for c in [root -->][?:StudyChange] if c.session_id == jid(s)];
    changes.sort(key=lambda (c: dict[str, any]) { c["version"]; });
    result["original_minutes"] = s.minutes; result["original_day"] = s.day;
    if changes { result.update(changes[-1]); }
    result["changes"] = changes;
    return result;
}

def:protect list_sessions() -> list[dict[str, any]] {
    rows = [_session_view(s) for s in [root -->][?:StudySession]];
    rows.sort(key=lambda (s: dict[str, any]) { (s["day"], s["id"]); }, reverse=True);
    return rows;
}

def:protect log_study(task_id: str, minutes: int, day: str, request_id: str) -> dict[str, any] {
    _valid_date(day);
    if day > date.today().isoformat() { raise ValueError("A study record cannot be in the future."); }
    if minutes < 1 or minutes > 1440 { raise ValueError("Study time must be 1–1440 minutes."); }
    if not request_id or len(request_id) > 100 { raise ValueError("A request ID of 1–100 characters is required."); }
    for s in [root -->][?:StudySession] {
        if s.request_id == request_id {
            if s.task_id != task_id or s.minutes != minutes or s.day != day {
                raise ValueError("This request ID already belongs to a different study record.");
            }
            return _session_view(s);
        }
    }
    for t in [root -->][?:Task] {
        if jid(t) == task_id {
            if t.archived { raise ValueError("Restore this task before recording study time."); }
            if t.done { raise ValueError("Reopen this task before recording more study time."); }
            credited = min(minutes, t.minutes);
            session = root ++> StudySession(task_id=task_id, title=t.title,
                course=t.course, day=day, minutes=minutes, credited=credited, request_id=request_id,
                effort_revision=t.effort_revision);
            t.minutes -= credited;
            if t.minutes == 0 { t.done = True; t.manual_done = False; }
            return _session_view(session);
        }
    }
    raise ValueError("Task not found in your account.");
}

def:protect revise_study(session_id: str, minutes: int, day: str, voided: bool,
                        expected_version: int, request_id: str) -> dict[str, any] {
    _valid_date(day);
    if day > date.today().isoformat() { raise ValueError("A study record cannot be in the future."); }
    if minutes < 1 or minutes > 1440 { raise ValueError("Study time must be 1–1440 minutes."); }
    if not request_id or len(request_id) > 100 { raise ValueError("A request ID of 1–100 characters is required."); }
    for s in [root -->][?:StudySession] {
        if jid(s) != session_id { continue; }
        current = _session_view(s);
        for c in [root -->][?:StudyChange] {
            if c.request_id == request_id {
                if c.session_id != session_id or c.minutes != minutes or c.day != day or c.voided != voided or c.expected_version != expected_version {
                    raise ValueError("This request ID already belongs to a different correction.");
                }
                return current;
            }
        }
        if current["version"] != expected_version {
            raise ValueError("This record changed on another device. Refresh history before correcting it.");
        }
        for t in [root -->][?:Task] {
            if jid(t) != s.task_id { continue; }
            adjusted = s.effort_revision == t.effort_revision;
            credited = 0;
            delta = 0;
            if adjusted {
                available = t.minutes + current["credited"];
                credited = 0 if voided else min(minutes, available);
                remaining = available - credited;
                delta = remaining - t.minutes;
                if t.minutes == 0 and remaining > 0 and not t.manual_done { t.done = False; }
                t.minutes = remaining;
                if remaining == 0 { t.done = True; }
            }
            root ++> StudyChange(session_id=session_id, request_id=request_id,
                minutes=minutes, day=day, voided=voided, expected_version=expected_version,
                credited=credited, remaining_delta=delta, estimate_adjusted=adjusted);
            return _session_view(s);
        }
        raise ValueError("Task not found in your account.");
    }
    raise ValueError("Study record not found in your account.");
}

node WeeklyCapacity { has budgets: list[int]; }

def:protect get_capacity() -> dict[str, any] {
    for settings in [root -->][?:WeeklyCapacity] {
        return {"budgets": settings.budgets, "saved": True};
    }
    return {"budgets": [60, 60, 60, 60, 60, 0, 0], "saved": False};
}

def:protect save_capacity(budgets: list[int]) -> dict[str, any] {
    if len(budgets) != 7 { raise ValueError("Provide seven capacities, Monday through Sunday."); }
    _make_week([], "2026-09-28", budgets);
    for settings in [root -->][?:WeeklyCapacity] {
        settings.budgets = list(budgets);
        return get_capacity();
    }
    root ++> WeeklyCapacity(budgets=list(budgets));
    return get_capacity();
}

def:protect week_plan(start: str, budgets: list[int] | None = None) -> dict[str, any] {
    _valid_date(start);
    # Jac 0.37.21's HTTP binder supplies an omitted None default as "None".
    if budgets is None or str(budgets) == "None" {
        pattern = get_capacity()["budgets"];
        weekday = date.fromisoformat(start).weekday();
        budgets = [pattern[(weekday + i) % 7] for i in range(7)];
    }
    return _make_week(_all(), start, budgets);
}
