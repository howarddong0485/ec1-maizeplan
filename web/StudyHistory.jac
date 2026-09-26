import from core.client { rpc, today, study_request_id }

def:pub StudyHistory(base: str, token: str, history: list[dict[str, any]], onSaved: any) -> JsxElement {
    has editing: any = None, minutes: str = "", day: str = "", request_id: str = "";
    has busy: bool = False, error: str = "", notice: str = "";
    def edit(s: dict[str, any]) {
        editing = s; minutes = str(s["minutes"]); day = s["day"];
        request_id = ""; error = ""; notice = "";
    }
    async def change(s: dict[str, any], undo: bool, amount: str, date_value: str, identity: str) {
        busy = True; error = ""; notice = "";
        try {
            result = await rpc(base, token, "revise_study", {"session_id": s["id"],
                "minutes": int(amount), "day": date_value, "voided": undo,
                "expected_version": s["version"], "request_id": identity});
            editing = None;
            notice = "Study record updated. " + ("Remaining effort adjusted." if result["estimate_adjusted"] else "Your newer manual estimate was kept; only history changed.");
            await onSaved();
        } except Exception as err { error = str(err); }
        finally { busy = False; }
    }
    async def save(e: FormEvent) {
        e.preventDefault();
        if busy or editing is None { return; }
        if not request_id { request_id = study_request_id(); }
        await change(editing, False, minutes, day, request_id);
    }
    async def undo(s: dict[str, any]) {
        if busy { return; }
        await change(s, True, str(s["minutes"]), s["day"], "undo-" + s["id"] + "-" + str(s["version"]));
    }
    return <section className="study-history" aria-label="Study history">
        <p><strong>{str(sum(s["minutes"] for s in history if not s["voided"]))}</strong> total focus minutes recorded.</p>
        <p className="small">Corrections keep an audit trail. Undo restores credited effort unless you have since manually re-estimated the task.</p>
        {<p className="error" role="alert">{error}</p> if error else <span/>}
        <p className="notice" role="status">{notice}</p>
        {<form className="history-editor" onSubmit={save}><h3>{"Restore study record" if editing["voided"] else "Correct study record"}: {editing["title"]}</h3>
            <div className="plan-form"><label>Corrected date<input type="date" required={True} max={today()} disabled={busy} value={day} onChange={lambda (e: ChangeEvent) { day = e.target.value; request_id = ""; }}/></label>
                <label>Corrected minutes<input type="number" min="1" max="1440" required={True} disabled={busy} value={minutes} onChange={lambda (e: ChangeEvent) { minutes = e.target.value; request_id = ""; }}/></label>
                <button className="primary" disabled={busy}>Save correction</button></div>
            <button type="button" className="secondary" disabled={busy} onClick={lambda { editing = None; }}>Cancel correction</button>
        </form> if editing is not None else <span/>}
        <ul className="history-list">{[<li key={s["id"]} className={"history-record voided" if s["voided"] else "history-record"}>
            <strong>{s["title"]}</strong><p>{s["day"]} · {str(s["minutes"])} min studied · {str(s["credited"])} min deducted {"· Undone (excluded from totals)" if s["voided"] else ""}</p>
            <div className="action-row"><button className="secondary" disabled={busy} onClick={lambda { edit(s); }}>{"Restore record" if s["voided"] else "Correct record"}</button>
                {<button className="text-button" disabled={busy} onClick={lambda { undo(s); }}>Undo record</button> if not s["voided"] else <span/>}</div>
            {<details><summary>{str(s["version"])} change(s) · view audit trail</summary><p>Original: {s["original_day"]} · {str(s["original_minutes"])} min</p>
                <ul>{[<li key={str(c["version"])}>Revision {str(c["version"])}: {c["day"]} · {str(c["minutes"])} min · {"undone" if c["voided"] else "active"} · remaining adjustment {str(c["remaining_delta"])} min {"(history only; manual estimate preserved)" if not c["estimate_adjusted"] else ""}</li> for c in s["changes"]]}</ul></details> if s["version"] else <span/>}
        </li> for s in history]}</ul>
        {<p className="small">No study records yet.</p> if not len(history) else <span/>}
    </section>;
}
