import from core.client { authenticate, rpc, today }
import from .Progress { Progress }

def:pub Planner -> JsxElement {
    has token: str = "", username: str = "", password: str = "", signup: bool = False;
    has tasks: list[dict[str, any]] = [], error: str = "", busy: bool = False;
    has history: list[dict[str, any]] = [];
    has title: str = "", course: str = "", due: str = today(), priority: str = "2", minutes: str = "60", editing: str = "";
    has day: str = today(), budget: str = "120", plan: any = None;
    has filter: str = "open", search: str = "", notice: str = "";
    has sample_version: int = 0;

    async def sample {
        if busy { return; }
        busy = True; error = ""; notice = "";
        try {
            result = await rpc(window.location.origin, token, "load_sample", {"day": today()});
            await reload(); sample_version += 1;
            filter = "open"; search = ""; notice = result["message"];
        } except Exception as err { error = str(err); }
        finally { busy = False; }
    }

    async def reload {
        fresh: any = None;
        sessions: any = None;
        fresh = await rpc(window.location.origin, token, "list_tasks", {"include_archived": True});
        sessions = await rpc(window.location.origin, token, "list_sessions", {});
        tasks = fresh; history = sessions; plan = None;
    }
    async def login(e: FormEvent) {
        e.preventDefault();
        busy = True; error = "";
        next_token: str = "";
        fresh: any = None;
        sessions: any = None;
        try {
            next_token = await authenticate(window.location.origin, username.strip(), password, signup);
            fresh = await rpc(window.location.origin, next_token, "list_tasks", {"include_archived": True});
            sessions = await rpc(window.location.origin, next_token, "list_sessions", {});
            token = next_token; tasks = fresh; history = sessions; password = "";
        } except Exception as err { error = str(err); }
        finally { busy = False; }
    }
    async def refresh {
        busy = True; error = ""; notice = "";
        try { await reload(); notice = "Tasks and study history are up to date. Generate plans again to use the latest data."; }
        except Exception as err { error = str(err); }
        finally { busy = False; }
    }
    async def save(e: FormEvent) {
        e.preventDefault(); busy = True; error = "";
        try {
            await rpc(window.location.origin, token, "save_task", {"title": title, "course": course,
                "due": due, "priority": int(priority), "minutes": int(minutes), "task_id": editing});
            title = ""; editing = ""; plan = None;
            notice = "Task saved. Refresh your phone or CLI to see it.";
            await reload();
        } except Exception as err { error = str(err); }
        finally { busy = False; }
    }
    async def complete(t: dict[str, any]) {
        busy = True; error = "";
        try {
            await rpc(window.location.origin, token, "set_done", {"task_id": t["id"], "done": not t["done"]});
            plan = None; await reload(); notice = "Task updated.";
        } except Exception as err { error = str(err); }
        finally { busy = False; }
    }
    async def archive(t: dict[str, any]) {
        busy = True; error = "";
        try {
            await rpc(window.location.origin, token, "archive_task", {"task_id": t["id"], "archived": not t["archived"]});
            if editing == t["id"] { editing = ""; title = ""; }
            await reload(); notice = "Task restored." if t["archived"] else "Task archived. Its study history is preserved; restore it from Archived.";
        } except Exception as err { error = str(err); }
        finally { busy = False; }
    }
    async def schedule(e: FormEvent) {
        e.preventDefault(); busy = True; error = "";
        try { plan = await rpc(window.location.origin, token, "day_plan", {"day": day, "budget": int(budget)}); }
        except Exception as err { error = str(err); }
        finally { busy = False; }
    }
    def edit(t: dict[str, any]) {
        editing = t["id"]; title = t["title"]; course = t["course"]; due = t["due"];
        priority = str(t["priority"]); minutes = str(t["minutes"]);
        field: any = document.getElementById("title");
        if field { field.focus(); }
    }
    def logout {
        token = ""; tasks = []; history = []; plan = None; error = ""; notice = "";
        title = ""; course = ""; editing = "";
    }
    visible = [t for t in tasks if (t["archived"] if filter == "archived" else (not t["archived"] and (filter == "all" or (filter == "done" and t["done"]) or (filter == "open" and not t["done"])))) and (search.lower() in (t["title"] + " " + t["course"]).lower())];
    pending = [t for t in tasks if not t["done"] and not t["archived"]];
    overdue = [t for t in pending if t["due"] < today()];
    completed = len([t for t in tasks if t["done"] and not t["archived"]]);

    if not token {
        return <main className="auth-shell">
            <section className="intro">
                <div className="brand"><span className="mark">M</span>MaizePlan</div>
                <p className="eyebrow">YOUR SEMESTER, IN FOCUS</p>
                <h1>Make room for<br/>what matters.</h1>
                <p className="lede">Turn coursework into a plan you can actually finish. One task list, from your desk to your phone to your terminal.</p>
                <div className="sample"><span className="eyebrow">A SMALLER NEXT STEP</span><h3>25 minutes. One task.</h3><p>Plan around the time you have—not an impossible to-do list.</p></div>
                <p className="privacy">Private account · Persistent plans · No AI subscription</p>
            </section>
            <section className="auth-card">
                <p className="eyebrow">LET’S GET ORGANIZED</p>
                <h2>{"Create your account" if signup else "Welcome back"}</h2>
                <p>Use the same account on all three interfaces.</p>
                <form onSubmit={login}>
                    <label htmlFor="username">Username</label><input id="username" autoComplete="username" required={True} value={username} onChange={lambda (e: ChangeEvent) { username = e.target.value; }}/>
                    <label htmlFor="password">Password</label><input id="password" type="password" autoComplete={"new-password" if signup else "current-password"} minLength={8} required={True} value={password} onChange={lambda (e: ChangeEvent) { password = e.target.value; }}/>
                    <button className="primary" disabled={busy}>{"Connecting…" if busy else ("Create account" if signup else "Sign in")}</button>
                </form>
                <button className="text-button" disabled={busy} onClick={lambda { signup = not signup; error = ""; }}>{"Already registered? Sign in" if signup else "New here? Create an account"}</button>
                {<p role="alert" className="error">{error}</p> if error else <span/>}
                <p className="small">Use a unique password. Sessions stay in memory; reloading signs you out but keeps your tasks.</p>
            </section>
        </main>;
    }
    return <div className="workspace">
        <aside className="rail"><div className="brand"><span className="mark">M</span>MaizePlan</div>
            <p className="eyebrow">PERSONAL WORKSPACE</p><div className="nav-current">Coursework &amp; focus</div>
            <div className="rail-note"><span className="eyebrow">YOUR NEXT GOOD MOVE</span><p>Start small.<br/>Finish something.</p></div>
            <div className="account"><span>{username}</span><button onClick={logout} disabled={busy}>Sign out</button></div>
        </aside>
        <main className="main">
            <header className="page-header"><div><p className="eyebrow">{today()} · YOUR PLANNING DESK</p><h1>A little more clarity.</h1></div><button className="secondary" onClick={refresh} disabled={busy}>Refresh all devices’ changes</button></header>
            <section className="stats" aria-label="Task summary"><article><span>Open tasks</span><strong>{str(len(pending))}</strong></article><article><span>Past deadline</span><strong className={"danger" if len(overdue) else ""}>{str(len(overdue))}</strong></article><article><span>Completed</span><strong>{str(completed)}</strong></article></section>
            {<p className="error" role="alert">{error}</p> if error else <span/>}
            <p className="notice" role="status">{notice}</p>
            <section className="demo-card" aria-label="Three-minute demo">
                <p className="eyebrow">TRY MAIZEPLAN IN THREE MINUTES</p>
                <h2>A deadline you can see coming</h2>
                <p>Use a new account to load one assignment and a saved weekly routine. Existing tasks, history and saved capacity are kept intact.</p>
                {<button className="primary" disabled={busy} onClick={sample}>Load sample week</button> if not len(tasks) and not len(history) else <p className="small">To start a fresh sample, sign out and create a new account.</p>}
                <details><summary>Follow the short demo</summary>
                    <ol>
                        <li><a href="#weekly-plan">Plan seven days</a>: the saved 25 / 120 / 0 / 0 / 0 / 0 / 0 capacities fit all 90 minutes, but 65 miss today's deadline.</li>
                        <li><a href="#study-progress">Record 25 minutes</a> for the sample task. Remaining work becomes 65; regenerate the weekly plan to see a 40-minute shortfall.</li>
                        <li>Correct the record to 10 minutes: 80 remain. Undo: 90 remain. Restore with 25: 65 remain. Expand the three-change audit trail.</li>
                        <li>Archive the task, then restore it from Archived. Its study history stays. Sign into mobile or CLI with this account and refresh to see the same result.</li>
                    </ol>
                    <p className="small">These numbers apply to the fresh sample. Dates use the day you load it; use that date when planning. The full cross-device walkthrough is in README.</p>
                </details>
            </section>
            <div className="columns"><section className="task-area">
                <div className="section-heading"><h2>Your coursework</h2><span className="small">Sorted by deadline, then priority</span></div>
                <div className="filters"><div className="tabs">{[<button key={v} aria-pressed={filter == v} className={"active" if filter == v else ""} onClick={lambda { filter = v; }}>{v.capitalize()}</button> for v in ["open", "done", "all", "archived"]]}</div><input aria-label="Search tasks and courses" placeholder="Find a task or course" value={search} onChange={lambda (e: ChangeEvent) { search = e.target.value; }}/></div>
                <div className="task-list">{[<article key={t["id"]} className={"task completed" if t["done"] else "task"}>
                    {<button className="check" aria-label={"Reopen " + t["title"] if t["done"] else "Complete " + t["title"]} aria-pressed={t["done"]} disabled={busy} onClick={lambda { complete(t); }}>{"✓" if t["done"] else "○"}</button> if not t["archived"] else <span className="pill">Archived</span>}
                    <div className="task-body"><span className="course">{t["course"] or "PERSONAL"}</span><h3>{t["title"]}</h3><div className="meta"><span className={"danger" if t["due"] < today() and not t["done"] else ""}>{"Overdue · " if t["due"] < today() and not t["done"] else "Due "}{t["due"]}</span><span>{str(t["minutes"])} min</span><span>{["", "Low", "Medium", "High"][t["priority"]]} priority</span></div></div>
                    <div className="task-actions">{<button className="text-button" disabled={busy} onClick={lambda { edit(t); }}>Edit</button> if not t["archived"] else <span/>}<button className="text-button" disabled={busy} onClick={lambda { archive(t); }}>{"Restore task" if t["archived"] else "Archive task"}</button></div>
                </article> for t in visible]}</div>
                {<div className="empty"><h3>{"Nothing matches this view." if len(tasks) else "A clear desk. A fresh start."}</h3><p>{"Try a different filter or search." if len(tasks) else "Add your first assignment on the right."}</p></div> if not len(visible) else <span/>}
                <section className="focus"><div className="section-heading"><div><p className="eyebrow">WORK WITH YOUR ENERGY</p><h2>Build a focus plan</h2></div><span className="pill">25 min focus / 5 min break</span></div>
                    <form className="plan-form" onSubmit={schedule}><label>Planning day<input type="date" required={True} value={day} onChange={lambda (e: ChangeEvent) { day = e.target.value; plan = None; }}/></label><label>Available minutes<input type="number" min="5" max="720" required={True} value={budget} onChange={lambda (e: ChangeEvent) { budget = e.target.value; plan = None; }}/></label><button className="primary" disabled={busy}>Make my plan</button></form>
                    {<div><p className="small">{plan["rule"]}</p><p><strong>{str(plan["study"])} min</strong> of focus + {str(plan["breaks"])} min of breaks. {str(plan["remaining"])} min remain outside this plan.</p>
                        {<p className="warning">{str(plan["urgent_unplanned"])} minutes of due/overdue work do not fit. Increase your time or reconsider deadlines.</p> if plan["urgent_unplanned"] > 0 else <span/>}
                        <ol className="timeline">{[<li key={str(i)}><span className="time">+{str(b["start"])} min</span><div><strong>{b["title"]}</strong><p>{b["course"] or "Personal"} · {str(b["minutes"])} min focus{" · after a 5-min break" if b["break_before"] else ""}</p></div></li> for (i, b) in enumerate(plan["blocks"])]}</ol>
                        {<p>No open tasks. Enjoy the space in your day.</p> if not len(plan["blocks"]) else <span/>}</div> if plan else <p className="small">Uses every open task, ordered by deadline. Includes breaks in your time budget. Nothing is marked complete automatically.</p>}
                </section>
                <Progress key={str(sample_version)} base={window.location.origin} token={token} tasks={tasks} history={history} onSaved={reload}/>
            </section><aside className="editor"><p className="eyebrow">GET IT OUT OF YOUR HEAD</p><h2>{"Edit task" if editing else "Add a task"}</h2>
                <form onSubmit={save}><label htmlFor="title">What needs doing?</label><input id="title" placeholder="Finish the bandits reading" required={True} maxLength={160} value={title} onChange={lambda (e: ChangeEvent) { title = e.target.value; }}/>
                    <label htmlFor="course">Course or area</label><input id="course" placeholder="EECS 449" maxLength={40} value={course} onChange={lambda (e: ChangeEvent) { course = e.target.value; }}/>
                    <label htmlFor="due">Deadline</label><input id="due" type="date" required={True} value={due} onChange={lambda (e: ChangeEvent) { due = e.target.value; }}/>
                    <div className="form-pair"><label>Priority<select value={priority} onChange={lambda (e: ChangeEvent) { priority = e.target.value; }}><option value="1">Low</option><option value="2">Medium</option><option value="3">High</option></select></label><label>Minutes<input type="number" min="1" max="1440" required={True} value={minutes} onChange={lambda (e: ChangeEvent) { minutes = e.target.value; }}/></label></div>
                    <button className="primary" disabled={busy}>{"Saving…" if busy else ("Save changes" if editing else "+ Add task")}</button>
                    {<button type="button" className="secondary" onClick={lambda { editing = ""; title = ""; }}>Cancel edit</button> if editing else <span/>}
                </form><p className="small">Estimate the work still remaining. Split a large assignment into smaller tasks when helpful.</p>
                <hr/><p className="eyebrow">TAKE YOUR PLAN WITH YOU</p><p className="small">The mobile app and CLI use this same account and server. Click Refresh after changing tasks elsewhere.</p>
            </aside></div>
        </main>
    </div>;
}
