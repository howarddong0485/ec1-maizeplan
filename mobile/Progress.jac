import from "@jac/mobui" { View, Text, TextInput, Pressable, StyleSheet }
import from core.client { rpc, today, day_offset, study_request_id, capacity_dates, capacity_pattern }
import from .StudyHistory { StudyHistory }
import from .Workload { Workload }

glob ui = StyleSheet.create({
    stack: {gap: 14}, text: {color: "#d7e1f0", fontSize: 16},
    heading: {color: "#ffcd36", fontSize: 22, fontWeight: "bold"},
    input: {backgroundColor: "#ffffff", color: "#142b49", padding: 14, borderRadius: 8},
    button: {backgroundColor: "#ffcd36", padding: 14, borderRadius: 8},
    card: {backgroundColor: "#d9e4f2", padding: 14, borderRadius: 8, gap: 8},
    dark: {color: "#142b49", fontSize: 16}, error: {color: "#ffbdb5", fontSize: 16}
});

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
    async def record {
        if busy { return; }
        busy = True; error = ""; notice = "";
        if not request_id { request_id = study_request_id(); }
        try {
            await rpc(base, token, "log_study", {"task_id": task_id, "minutes": int(minutes), "day": day, "request_id": request_id});
            request_id = ""; forecast = None;
            notice = "Study saved. Remaining work updated; zero remaining completes the task.";
            await onSaved();
        } except Exception as err { error = str(err); }
        finally { busy = False; }
    }
    async def schedule {
        if busy { return; }
        busy = True; error = ""; forecast = None;
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
    return <View style={ui.stack}>
        <Text style={ui.heading}>Record your study</Text>
        <Text style={ui.text}>Choose an open task. Actual focus minutes reduce remaining work, never below zero. Exclude breaks.</Text>
        {<Text style={ui.error} accessibilityRole="alert">{error}</Text> if error else <View/>}
        {<Text style={ui.text}>{notice}</Text> if notice else <View/>}
        {[<Pressable key={t["id"]} accessibilityRole="button" disabled={busy} style={ui.button if task_id == t["id"] else ui.card} onPress={lambda { task_id = t["id"]; request_id = ""; }}><Text style={ui.dark}>{t["title"]} · {str(t["minutes"])} min left {"(selected)" if task_id == t["id"] else ""}</Text></Pressable> for t in tasks if not t["done"] and not t["archived"]]}
        <Text style={ui.text}>Study date (YYYY-MM-DD)</Text><TextInput accessibilityLabel="Study date" editable={not busy} style={ui.input} value={day} onChangeText={lambda (v: str) { day = v; request_id = ""; }}/>
        <Text style={ui.text}>Studied minutes (1–1440)</Text><TextInput accessibilityLabel="Studied minutes" editable={not busy} style={ui.input} keyboardType="number-pad" value={minutes} onChangeText={lambda (v: str) { minutes = v; request_id = ""; }}/>
        <Pressable accessibilityRole="button" disabled={busy or not task_id} style={ui.button} onPress={record}><Text style={ui.dark}>{"Saving…" if busy else "Record study"}</Text></Pressable>
        <Pressable accessibilityRole="button" disabled={busy} style={ui.card} onPress={load_history}><Text style={ui.dark}>Refresh tasks &amp; study history</Text></Pressable>
        <StudyHistory base={base} token={token} history={history} onSaved={onSaved}/>
        <Text style={ui.heading}>Seven-day workload plan</Text>
        <Text style={ui.text}>Daily minutes include breaks. Use 0 for a day off, otherwise 5–720. This forecast does not change tasks; regenerate after changes.</Text>
        <Text style={ui.text}>Saved capacity repeats by weekday. Changing the start date loads that routine; unsaved edits apply only to this forecast.</Text>
        <Text style={ui.text}>{capacity_notice}</Text>
        <TextInput accessibilityLabel="Week starts" style={ui.input} editable={not busy and not capacity_busy} value={start} onChangeText={lambda (v: str) { change_start(v); }}/>
        {[<View key={str(i)} style={ui.stack}><Text style={ui.text}>{day_offset(start, i)}</Text><TextInput accessibilityLabel={"Budget " + day_offset(start, i)} style={ui.input} keyboardType="number-pad" editable={not busy and not capacity_busy} value={v} onChangeText={lambda (value: str) { capacity(i, value); }}/></View> for (i, v) in enumerate(budgets)]}
        <Pressable accessibilityRole="button" disabled={busy or capacity_busy} style={ui.button} onPress={schedule}><Text style={ui.dark}>Plan seven days</Text></Pressable>
        <Pressable accessibilityRole="button" disabled={busy or capacity_busy} style={ui.card} onPress={save_capacity}><Text style={ui.dark}>Save weekly capacity</Text></Pressable>
        <Pressable accessibilityRole="button" disabled={busy or capacity_busy} style={ui.card} onPress={load_capacity}><Text style={ui.dark}>Load saved capacity</Text></Pressable>
        {<View style={ui.stack}><Text style={ui.text}>{str(week["study"])} min focus + {str(week["breaks"])} min breaks / {str(week["capacity"])} available. {str(week["remaining"])} min unscheduled.</Text>
            <Workload week={week}/>
            <Text style={ui.text}>{week["rule"]}</Text>
            <Text style={ui.text}>Deadline shortfall: {str(week["deadline_shortfall"])} min · already overdue: {str(week["overdue_minutes"])} min</Text>
            {[<Text key={r["id"]} style={ui.error}>{r["title"]} · due {r["due"]}: {str(r["minutes"])} min {"already overdue" if r["overdue"] else "cannot fit by deadline"}</Text> for r in week["risks"]]}
            {[<View key={d["day"]} style={ui.card}><Text style={ui.dark}>{d["day"]}: {str(d["study"])} min focus / {str(d["breaks"])} breaks / {str(d["budget"])} budget</Text>
                {[<Text key={str(i)} style={ui.dark}>+{str(b["start"])} min · {b["title"]} · {str(b["minutes"])} min {"(late / catch-up)" if b["overdue"] else ""}</Text> for (i, b) in enumerate(d["blocks"])]}
                {<Text style={ui.dark}>{"Day off" if not d["budget"] else "No work scheduled"}</Text> if not len(d["blocks"]) else <View/>}
            </View> for d in week["days"]]}
        </View> if week else <Text style={ui.text}>Generate a plan from your current tasks. Refreshing or changing tasks clears the previous forecast and keeps your daily budgets.</Text>}
    </View>;
}
