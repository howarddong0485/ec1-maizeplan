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
