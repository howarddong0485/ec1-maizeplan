"""All planning state belongs to the authenticated caller's persistent root."""
import from .planning { _valid_date, _task_order, _make_plan }

node Task {
    has title: str, course: str, due: str, priority: int, minutes: int;
    has done: bool = False;
    def view -> dict {
        return {"id": jid(self), "title": self.title, "course": self.course,
            "due": self.due, "priority": self.priority, "minutes": self.minutes,
            "done": self.done};
    }
}

def _all -> list[dict] {
    tasks = [t.view() for t in [root -->][?:Task]];
    tasks.sort(key=_task_order);
    return tasks;
}

def:protect list_tasks() -> list[dict] { return _all(); }

def:protect save_task(title: str, course: str, due: str, priority: int,
                    minutes: int, task_id: str = "") -> dict {
    title = title.strip();
    course = course.strip();
    if not title or len(title) > 160 { raise ValueError("Title must be 1–160 characters."); }
    if len(course) > 40 { raise ValueError("Course must be at most 40 characters."); }
    _valid_date(due);
    if priority not in [1, 2, 3] { raise ValueError("Priority must be 1, 2, or 3."); }
    if minutes < 5 or minutes > 1440 { raise ValueError("Estimate must be 5–1440 minutes."); }
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

def:protect set_done(task_id: str, done: bool) -> dict {
    for t in [root -->][?:Task] {
        if jid(t) == task_id {
            t.done = done;
            return t.view();
        }
    }
    raise ValueError("Task not found in your account.");
}

def:protect day_plan(day: str, budget: int = 120) -> dict {
    return _make_plan(_all(), day, budget);
}
