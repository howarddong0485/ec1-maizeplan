import from core.client { rpc, today, day_offset, study_request_id }

def:pub Progress(base: str, token: str, tasks: list[dict[str, any]], onSaved: any) -> JsxElement {
    has task_id: str = "", minutes: str = "25", day: str = today(), request_id: str = "";
    has history: any = None, error: str = "", notice: str = "", busy: bool = False;
    has start: str = today(), budgets: list[str] = ["60", "60", "60", "60", "60", "0", "0"], week: any = None;
    async def load_history {
        busy = True; error = "";
        try { history = await rpc(base, token, "list_sessions", {}); }
        except Exception as err { error = str(err); }
        finally { busy = False; }
    }
    async def record(e: FormEvent) {
        e.preventDefault();
        if busy { return; }
        busy = True; error = ""; notice = "";
        if not request_id { request_id = study_request_id(); }
        try {
            await rpc(base, token, "log_study", {"task_id": task_id, "minutes": int(minutes), "day": day, "request_id": request_id});
            request_id = ""; week = None;
            notice = "Study saved. Remaining work updated; zero remaining marks the task complete.";
            await onSaved();
            history = await rpc(base, token, "list_sessions", {});
        } except Exception as err { error = str(err); }
        finally { busy = False; }
    }
    async def schedule(e: FormEvent) {
        e.preventDefault(); busy = True; error = ""; week = None;
        try { week = await rpc(base, token, "week_plan", {"start": start, "budgets": [int(v) for v in budgets]}); }
        except Exception as err { error = str(err); }
        finally { busy = False; }
    }
    def capacity(index: int, value: str) {
        budgets = [value if i == index else v for (i, v) in enumerate(budgets)]; week = None;
    }
    return <section className="progress-tools">
        <section className="focus"><p className="eyebrow">PLAN · STUDY · ADJUST</p><h2>Record your study</h2>
            <p className="small">Record actual focus minutes, excluding breaks. Remaining work never goes below zero. Repeating a failed request with unchanged fields will not count it twice.</p>
            {<p role="alert" className="error">{error}</p> if error else <span/>}
            <p role="status" className="notice">{notice}</p>
            <form onSubmit={record}>
                <label>Study task<select required={True} disabled={busy} value={task_id} onChange={lambda (e: ChangeEvent) { task_id = e.target.value; request_id = ""; }}>
                    <option value="">Choose an open task</option>{[<option key={t["id"]} value={t["id"]}>{t["title"]} · {str(t["minutes"])} min left</option> for t in tasks if not t["done"]]}</select></label>
                <div className="plan-form"><label>Study date<input type="date" required={True} disabled={busy} max={today()} value={day} onChange={lambda (e: ChangeEvent) { day = e.target.value; request_id = ""; }}/></label>
                    <label>Studied minutes<input type="number" required={True} disabled={busy} min="1" max="1440" value={minutes} onChange={lambda (e: ChangeEvent) { minutes = e.target.value; request_id = ""; }}/></label>
                    <button className="primary" disabled={busy}>Record study</button></div>
            </form>
            <button className="secondary" disabled={busy} onClick={load_history}>Refresh study history</button>
            {<div><p>{str(sum(s["minutes"] for s in history))} total focus minutes recorded.</p>
                <ul className="history-list">{[<li key={s["id"]}>{s["day"]} · {s["title"]} · {str(s["minutes"])} min studied ({str(s["credited"])} min deducted)</li> for s in history]}</ul>
                {<p>No study records yet.</p> if not len(history) else <span/>}</div> if history is not None else <p className="small">Refresh history to view saved records from all your devices.</p>}
        </section>
        <section className="focus"><p className="eyebrow">SEE THE WEEK AHEAD</p><h2>Seven-day workload plan</h2>
            <p className="small">Daily budgets include breaks. Use 0 for a day off, otherwise 5–720 minutes. Generate again after tasks change; this forecast is not a saved calendar.</p>
            <form onSubmit={schedule}><label>Week starts<input type="date" required={True} value={start} onChange={lambda (e: ChangeEvent) { start = e.target.value; week = None; }}/></label>
                <div className="capacity-grid">{[<label key={str(i)}>{day_offset(start, i)}<input aria-label={"Budget " + day_offset(start, i)} type="number" min="0" max="720" required={True} value={v} onChange={lambda (e: ChangeEvent) { capacity(i, e.target.value); }}/></label> for (i, v) in enumerate(budgets)]}</div>
                <button className="primary" disabled={busy}>Plan seven days</button></form>
            {<div><p>{str(week["study"])} min focus + {str(week["breaks"])} min breaks / {str(week["capacity"])} min available. {str(week["remaining"])} min unscheduled.</p>
                <p className="small">{week["rule"]}</p>
                {<p className="warning" role="status">Deadline shortfall: {str(week["deadline_shortfall"])} focus minutes. Already overdue: {str(week["overdue_minutes"])} minutes.</p> if len(week["risks"]) else <p className="notice">All work due within this horizon fits by its deadline.</p>}
                <ul>{[<li key={r["id"]}>{r["title"]} · due {r["due"]} · {str(r["minutes"])} min {"already overdue" if r["overdue"] else "cannot fit by deadline"}</li> for r in week["risks"]]}</ul>
                <div className="week-days">{[<article key={d["day"]} className="week-day"><h3>{d["day"]}</h3><p>{str(d["study"])} min focus · {str(d["breaks"])} min breaks · budget {str(d["budget"])} min</p>
                    {<p className="small">{"Day off" if not d["budget"] else "No work scheduled"}</p> if not len(d["blocks"]) else <span/>}
                    <ol>{[<li key={str(i)}>+{str(b["start"])} min: {b["title"]} · {str(b["minutes"])} min {"(late / catch-up)" if b["overdue"] else ""}</li> for (i, b) in enumerate(d["blocks"])]}</ol>
                </article> for d in week["days"]]}</div>
            </div> if week else <span/>}
        </section>
    </section>;
}
