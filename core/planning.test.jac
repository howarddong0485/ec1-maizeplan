test "empty plan" {
    p = _make_plan([], "2026-10-05", 120);
    assert p["blocks"] == [];
    assert p["study"] == 0;
    assert p["breaks"] == 0;
}

test "deadline then priority ordering" {
    rows = [
        {"id": "a", "title": "Later", "course": "A", "due": "2026-10-06", "priority": 3, "minutes": 25, "done": False},
        {"id": "b", "title": "Low", "course": "A", "due": "2026-10-05", "priority": 1, "minutes": 25, "done": False},
        {"id": "c", "title": "High", "course": "A", "due": "2026-10-05", "priority": 3, "minutes": 25, "done": False}
    ];
    p = _make_plan(rows, "2026-10-05", 85);
    assert [b["id"] for b in p["blocks"]] == ["c", "b", "a"];
    assert p["elapsed"] == 85;
    assert p["breaks"] == 10;
    assert p["remaining"] == 0;
}

test "partial large task fits budget including breaks" {
    t = {"id": "a", "title": "Project", "course": "A", "due": "2026-10-05", "priority": 3, "minutes": 100, "done": False};
    p = _make_plan([t], "2026-10-05", 40);
    assert [b["minutes"] for b in p["blocks"]] == [25, 10];
    assert [b["start"] for b in p["blocks"]] == [0, 30];
    assert p["elapsed"] == 40;
    assert p["urgent_unplanned"] == 65;
    assert t["minutes"] == 100;
    assert not t["done"];
}

test "completed tasks excluded" {
    t = {"id": "a", "title": "Done", "course": "A", "due": "2026-10-01", "priority": 3, "minutes": 100, "done": True};
    p = _make_plan([t], "2026-10-05", 120);
    assert len(p["blocks"]) == 0;
    assert p["urgent_unplanned"] == 0;
}

test "invalid dates and budgets rejected" {
    with testraises(ValueError) { _make_plan([], "2026-02-30", 120); }
    with testraises(ValueError) { _make_plan([], "2026-10-05", 0); }
    with testraises(ValueError) { _make_plan([], "2026-10-05", 721); }
}

test "five minute budget and no trailing break" {
    t = {"id": "a", "title": "Read", "course": "A", "due": "2026-10-01", "priority": 1, "minutes": 25, "done": False};
    p = _make_plan([t], "2026-10-05", 5);
    assert p["study"] == 5;
    assert p["breaks"] == 0;
    assert p["blocks"][0]["overdue"];
    p = _make_plan([t], "2026-10-05", 30);
    assert p["study"] == 25;
    assert p["breaks"] == 0;
}

test "week splits work and resets breaks each day without mutation" {
    t = {"id": "a", "title": "Project", "course": "A", "due": "2026-10-06", "priority": 3, "minutes": 60, "done": False};
    p = _make_week([t], "2026-10-05", [40, 25]);
    assert p["study"] == 60;
    assert p["breaks"] == 5;
    assert p["remaining"] == 0;
    assert p["risks"] == [];
    assert p["days"][1]["blocks"][0]["start"] == 0;
    assert t["minutes"] == 60;
}

test "late capacity cannot hide a deadline shortfall" {
    t = {"id": "a", "title": "Project", "course": "A", "due": "2026-10-05", "priority": 3, "minutes": 60, "done": False};
    p = _make_week([t], "2026-10-05", [25, 120]);
    assert p["remaining"] == 0;
    assert p["deadline_shortfall"] == 35;
    assert p["days"][1]["blocks"][0]["overdue"];
}

test "days off overdue work and future deadlines are distinct" {
    rows = [
        {"id": "a", "title": "Late", "course": "A", "due": "2026-10-04", "priority": 3, "minutes": 10, "done": False},
        {"id": "b", "title": "Due", "course": "A", "due": "2026-10-06", "priority": 2, "minutes": 25, "done": False},
        {"id": "c", "title": "Future", "course": "A", "due": "2026-10-20", "priority": 1, "minutes": 60, "done": False}
    ];
    p = _make_week(rows, "2026-10-05", [0, 40]);
    assert p["days"][0]["blocks"] == [];
    assert p["days"][0]["budget"] == 0;
    assert p["overdue_minutes"] == 10;
    assert p["deadline_shortfall"] == 0;
    assert len(p["risks"]) == 1;
    assert p["remaining"] == 60;
}

test "week validates budgets and dates" {
    with testraises(ValueError) { _make_week([], "2026-10-05", []); }
    with testraises(ValueError) { _make_week([], "2026-10-05", [60 for i in range(15)]); }
    with testraises(ValueError) { _make_week([], "2026-10-05", [-1]); }
    with testraises(ValueError) { _make_week([], "2026-10-05", [4]); }
    with testraises(ValueError) { _make_week([], "2026-10-05", [721]); }
    with testraises(ValueError) { _make_week([], "2026-02-30", [60]); }
    p = _make_week([], "2026-12-31", [0, 0]);
    assert p["end"] == "2027-01-01";
    assert p["capacity"] == 0;
    assert p["risks"] == [];
}

test "weekly ordering and completion exclusion" {
    rows = [
        {"id": "a", "title": "Low", "course": "A", "due": "2026-10-05", "priority": 1, "minutes": 25, "done": False},
        {"id": "b", "title": "High", "course": "A", "due": "2026-10-05", "priority": 3, "minutes": 25, "done": False},
        {"id": "c", "title": "Finished", "course": "A", "due": "2026-10-01", "priority": 3, "minutes": 100, "done": True}
    ];
    p = _make_week(rows, "2026-10-05", [55]);
    assert [b["id"] for b in p["days"][0]["blocks"]] == ["b", "a"];
    assert p["remaining"] == 0;
    assert p["risks"] == [];
}
