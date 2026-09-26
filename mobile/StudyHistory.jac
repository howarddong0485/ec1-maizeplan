import from "@jac/mobui" { View, Text, TextInput, Pressable }
import from core.client { rpc, study_request_id }

def:pub StudyHistory(base: str, token: str, history: list[dict[str, any]], onSaved: any) -> JsxElement {
    has editing: any = None, minutes: str = "", day: str = "", request_id: str = "";
    has busy: bool = False, error: str = "", notice: str = "", audit: str = "";
    card = {backgroundColor: "#d9e4f2", padding: 14, borderRadius: 8, gap: 10};
    text = {color: "#142b49", fontSize: 16};
    button = {backgroundColor: "#ffcd36", padding: 12, borderRadius: 8};
    input = {backgroundColor: "#ffffff", color: "#142b49", padding: 12, borderRadius: 8};
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
    async def save {
        if busy or editing is None { return; }
        if not request_id { request_id = study_request_id(); }
        await change(editing, False, minutes, day, request_id);
    }
    async def undo(s: dict[str, any]) {
        if busy { return; }
        await change(s, True, str(s["minutes"]), s["day"], "undo-" + s["id"] + "-" + str(s["version"]));
    }
    return <View style={{gap: 14}}>
        <Text style={{color: "#d7e1f0", fontSize: 16}}>{str(sum(s["minutes"] for s in history if not s["voided"]))} total focus minutes recorded. Undo restores credited effort unless you later manually re-estimated the task.</Text>
        {<Text accessibilityRole="alert" style={{color: "#ffbdb5"}}>{error}</Text> if error else <View/>}
        {<Text style={{color: "#d7e1f0"}}>{notice}</Text> if notice else <View/>}
        {<View style={card}><Text style={text}>{"Restore" if editing["voided"] else "Correct"}: {editing["title"]}</Text>
            <Text style={text}>Corrected date</Text><TextInput accessibilityLabel="Corrected date" style={input} editable={not busy} value={day} onChangeText={lambda (v: str) { day = v; request_id = ""; }}/>
            <Text style={text}>Corrected minutes</Text><TextInput accessibilityLabel="Corrected minutes" keyboardType="number-pad" style={input} editable={not busy} value={minutes} onChangeText={lambda (v: str) { minutes = v; request_id = ""; }}/>
            <Pressable accessibilityRole="button" style={button} disabled={busy} onPress={save}><Text style={text}>Save correction</Text></Pressable>
            <Pressable accessibilityRole="button" disabled={busy} onPress={lambda { editing = None; }}><Text style={text}>Cancel correction</Text></Pressable>
        </View> if editing is not None else <View/>}
        {[<View key={s["id"]} style={card}><Text style={text}>{s["title"]} · {s["day"]}</Text><Text style={text}>{str(s["minutes"])} min studied · {str(s["credited"])} min deducted {"· Undone (excluded from totals)" if s["voided"] else ""}</Text>
            <Pressable accessibilityRole="button" style={button} disabled={busy} onPress={lambda { edit(s); }}><Text style={text}>{"Restore record" if s["voided"] else "Correct record"}</Text></Pressable>
            {<Pressable accessibilityRole="button" disabled={busy} onPress={lambda { undo(s); }}><Text style={text}>Undo record</Text></Pressable> if not s["voided"] else <View/>}
            {<Pressable accessibilityRole="button" onPress={lambda { audit = "" if audit == s["id"] else s["id"]; }}><Text style={text}>{str(s["version"])} change(s) · view audit trail</Text></Pressable> if s["version"] else <View/>}
            {<View style={{gap: 8}}><Text style={text}>Original: {s["original_day"]} · {str(s["original_minutes"])} min</Text>{[<Text key={str(c["version"])} style={text}>Revision {str(c["version"])}: {c["day"]} · {str(c["minutes"])} min · {"undone" if c["voided"] else "active"} · remaining adjustment {str(c["remaining_delta"])} min {"(manual estimate preserved)" if not c["estimate_adjusted"] else ""}</Text> for c in s["changes"]]}</View> if audit == s["id"] else <View/>}
        </View> for s in history]}
    </View>;
}
