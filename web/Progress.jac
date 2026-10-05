import from core.client { rpc, today, day_offset, study_request_id, capacity_dates, capacity_pattern }
import from .StudyHistory { StudyHistory }
import from .Workload { Workload }

def:pub Progress(base: str, token: str, tasks: list[dict[str, any]], history: list[dict[str, any]], onSaved: any) -> JsxElement {
    has task_id: str = "", minutes: str = "25", day: str = today(), request_id: str = "";
    has error: str = "", notice: str = "", busy: bool = False;
    has start: str = today(), budgets: list[str] = capacity_dates([60, 60, 60, 60, 60, 0, 0], today()), forecast: any = None, forecast_tasks: any = None;
    has pattern: list[int] = [60, 60, 60, 60, 60, 0, 0], capacity_notice: str = "", capacity_busy: bool = True;
    async def load_capacity {
        capacity_busy = True; error = "";
        try {
            saved = await rpc(base, token, "get_capacity", {});
            pattern = saved["budgets"]; budgets = capacity_dates(pattern, start); forecast = None;
            capacity_notice = "Loaded your saved weekly capacity." if saved["saved"] else "Default capacity. Save your own Monday–Sunday routine below.";
        } except Exception as err { error = str(err); }
        finally { capacity_busy = False; }
    }
    async can with entry { await load_capacity(); }
    async def save_capacity {
        capacity_busy = True; error = "";
        try {
            saved = await rpc(base, token, "save_capacity", {"budgets": capacity_pattern(budgets, start)});
            pattern = saved["budgets"]; capacity_notice = "Weekly capacity saved to your account for web, mobile and CLI.";
        } except Exception as err { error = str(err); }
        finally { capacity_busy = False; }
    }
    def change_start(value: str) {
        start = value; forecast = None;
        if len(value) == 10 { budgets = capacity_dates(pattern, value); }
    }
    async def load_history {
        busy = True; error = ""; notice = "";
        try { await onSaved(); notice = "Tasks and study history refreshed. Generate plans again to use the latest data."; }
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
            request_id = ""; forecast = None;
            notice = "Study saved. Remaining work updated; zero remaining marks the task complete.";
            await onSaved();
        } except Exception as err { error = str(err); }
        finally { busy = False; }
    }
    async def schedule(e: FormEvent) {
        e.preventDefault(); busy = True; error = ""; forecast = None;
        planned_tasks = tasks;
        try {
            forecast = await rpc(base, token, "week_plan", {"start": start, "budgets": [int(v) for v in budgets]});
            forecast_tasks = planned_tasks;
        }
        except Exception as err { error = str(err); }
        finally { busy = False; }
    }
    def capacity(index: int, value: str) {
        budgets = [value if i == index else v for (i, v) in enumerate(budgets)]; forecast = None;
    }
    week = forecast if forecast_tasks is tasks else None;
    return <section className="progress-tools">
        <section className="focus" id="study-progress"><p className="eyebrow">PLAN · STUDY · ADJUST</p><h2>Record your study</h2>
            <p className="small">Record actual focus minutes, excluding breaks. Remaining work never goes below zero. Repeating a failed request with unchanged fields will not count it twice.</p>
            {<p role="alert" className="error">{error}</p> if error else <span/>}
            <p role="status" className="notice">{notice}</p>
            <form onSubmit={record}>
                <label>Study task<select required={True} disabled={busy} value={task_id} onChange={lambda (e: ChangeEvent) { task_id = e.target.value; request_id = ""; }}>
                    <option value="">Choose an open task</option>{[<option key={t["id"]} value={t["id"]}>{t["title"]} · {str(t["minutes"])} min left</option> for t in tasks if not t["done"] and not t["archived"]]}</select></label>
                <div className="plan-form"><label>Study date<input type="date" required={True} disabled={busy} max={today()} value={day} onChange={lambda (e: ChangeEvent) { day = e.target.value; request_id = ""; }}/></label>
                    <label>Studied minutes<input type="number" required={True} disabled={busy} min="1" max="1440" value={minutes} onChange={lambda (e: ChangeEvent) { minutes = e.target.value; request_id = ""; }}/></label>
                    <button className="primary" disabled={busy}>Record study</button></div>
            </form>
            <button className="secondary" disabled={busy} onClick={load_history}>Refresh tasks &amp; study history</button>
            <StudyHistory base={base} token={token} history={history} onSaved={onSaved}/>
        </section>
        <section className="focus" id="weekly-plan"><p className="eyebrow">SEE THE WEEK AHEAD</p><h2>Seven-day workload plan</h2>
            <p className="small">Daily budgets include breaks. Use 0 for a day off, otherwise 5–720 minutes. Generate again after tasks change; this forecast is not a saved calendar.</p>
            <p className="small">Saved capacity repeats by weekday. Changing the start date loads that routine; unsaved edits apply only to this forecast.</p>
            <p className="notice" role="status">{capacity_notice}</p>
            <form onSubmit={schedule}><label>Week starts<input type="date" required={True} disabled={busy or capacity_busy} value={start} onChange={lambda (e: ChangeEvent) { change_start(e.target.value); }}/></label>
                <div className="capacity-grid">{[<label key={str(i)}>{day_offset(start, i)}<input aria-label={"Budget " + day_offset(start, i)} type="number" min="0" max="720" required={True} disabled={busy or capacity_busy} value={v} onChange={lambda (e: ChangeEvent) { capacity(i, e.target.value); }}/></label> for (i, v) in enumerate(budgets)]}</div>
                <div className="action-row"><button className="primary" disabled={busy or capacity_busy}>Plan seven days</button><button type="button" className="secondary" disabled={busy or capacity_busy} onClick={save_capacity}>Save weekly capacity</button><button type="button" className="text-button" disabled={busy or capacity_busy} onClick={load_capacity}>Load saved capacity</button></div></form>
            {<div><p>{str(week["study"])} min focus + {str(week["breaks"])} min breaks / {str(week["capacity"])} min available. {str(week["remaining"])} min unscheduled.</p>
                <Workload week={week}/>
                <p className="small">{week["rule"]}</p>
                {<p className="warning" role="status">Deadline shortfall: {str(week["deadline_shortfall"])} focus minutes. Already overdue: {str(week["overdue_minutes"])} minutes.</p> if len(week["risks"]) else <p className="notice">All work due within this horizon fits by its deadline.</p>}
                <ul>{[<li key={r["id"]}>{r["title"]} · due {r["due"]} · {str(r["minutes"])} min {"already overdue" if r["overdue"] else "cannot fit by deadline"}</li> for r in week["risks"]]}</ul>
                <div className="week-days">{[<article key={d["day"]} className="week-day"><h3>{d["day"]}</h3><p>{str(d["study"])} min focus · {str(d["breaks"])} min breaks · budget {str(d["budget"])} min</p>
                    {<p className="small">{"Day off" if not d["budget"] else "No work scheduled"}</p> if not len(d["blocks"]) else <span/>}
                    <ol>{[<li key={str(i)}>+{str(b["start"])} min: {b["title"]} · {str(b["minutes"])} min {"(late / catch-up)" if b["overdue"] else ""}</li> for (i, b) in enumerate(d["blocks"])]}</ol>
                </article> for d in week["days"]]}</div>
            </div> if week else <p className="small">Generate a plan from your current tasks. Refreshing or changing tasks clears the previous forecast and keeps your daily budgets.</p>}
        </section>
    </section>;
}
