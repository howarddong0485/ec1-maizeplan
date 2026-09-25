"""All planning state belongs to the authenticated caller's persistent root."""
import from .planning { _valid_date, _task_order, _make_plan, _make_week }
import from datetime { date }

node Task {
    has title: str, course: str, due: str, priority: int, minutes: int;
    has done: bool = False;
    def view -> dict[str, any] {
        return {"id": jid(self), "title": self.title, "course": self.course,
            "due": self.due, "priority": self.priority, "minutes": self.minutes,
            "done": self.done};
    }
}

def _all -> list[dict[str, any]] {
    tasks = [t.view() for t in [root -->][?:Task]];
    tasks.sort(key=_task_order);
    return tasks;
}

def:protect list_tasks() -> list[dict[str, any]] { return _all(); }

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
            if not done and t.minutes == 0 { raise ValueError("Edit the remaining estimate on the web before reopening this task."); }
            t.done = done;
            return t.view();
        }
    }
    raise ValueError("Task not found in your account.");
}

def:protect day_plan(day: str, budget: int = 120) -> dict[str, any] {
    return _make_plan(_all(), day, budget);
}


node StudySession {
    has task_id: str, title: str, course: str, day: str, minutes: int;
    has credited: int, request_id: str;
    def view -> dict[str, any] {
        return {"id": jid(self), "task_id": self.task_id, "title": self.title,
            "course": self.course, "day": self.day, "minutes": self.minutes,
            "credited": self.credited, "request_id": self.request_id};
    }
}

def:protect list_sessions() -> list[dict[str, any]] {
    rows = [s.view() for s in [root -->][?:StudySession]];
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
            return s.view();
        }
    }
    for t in [root -->][?:Task] {
        if jid(t) == task_id {
            if t.done { raise ValueError("Reopen this task before recording more study time."); }
            credited = min(minutes, t.minutes);
            session = root ++> StudySession(task_id=task_id, title=t.title,
                course=t.course, day=day, minutes=minutes, credited=credited, request_id=request_id);
            t.minutes -= credited;
            if t.minutes == 0 { t.done = True; }
            return session.view();
        }
    }
    raise ValueError("Task not found in your account.");
}

def:protect week_plan(start: str, budgets: list[int]) -> dict[str, any] {
    return _make_week(_all(), start, budgets);
}
