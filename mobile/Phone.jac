import from "@jac/mobui" { View, Text, TextInput, Pressable, ScrollView, StyleSheet, KeyboardAvoidingView, Platform }
import from core.client { authenticate, rpc, today }
import from .Progress { Progress }

glob styles = StyleSheet.create({
    screen: {flex: 1, backgroundColor: "#10284a"},
    body: {padding: 24, paddingTop: 60, paddingBottom: 60, gap: 16},
    brand: {color: "#ffcd36", fontSize: 18, fontWeight: "bold"},
    heading: {color: "#ffffff", fontSize: 30, fontWeight: "bold"},
    text: {color: "#d7e1f0", fontSize: 16, lineHeight: 24},
    input: {backgroundColor: "#ffffff", color: "#142b49", padding: 14, borderRadius: 8, fontSize: 16},
    button: {backgroundColor: "#ffcd36", borderRadius: 8, padding: 14, alignItems: "center"},
    secondary: {backgroundColor: "#d9e4f2", borderRadius: 8, padding: 14, alignItems: "center"},
    buttonText: {color: "#142b49", fontSize: 16, fontWeight: "bold"},
    row: {flexDirection: "row", gap: 12, flexWrap: "wrap"},
    card: {backgroundColor: "#ffffff", padding: 18, borderRadius: 12, gap: 10},
    title: {color: "#142b49", fontSize: 18, fontWeight: "bold"},
    meta: {color: "#53677e", fontSize: 14},
    error: {color: "#ffbdb5", fontSize: 14},
    badge: {color: "#ffcd36", fontSize: 14}
});

def:pub Phone -> JsxElement {
    has base: str = "http://localhost:8001", token: str = "", username: str = "", password: str = "";
    has signup: bool = False, busy: bool = False, error: str = "", tab: str = "tasks";
    has tasks: list[dict[str, any]] = [], title: str = "", course: str = "", due: str = today(), minutes: str = "30", priority: str = "2";
    has history: list[dict[str, any]] = [];
    has show_archived: bool = False;
    has plan: any = None, budget: str = "120", day: str = today();

    async def load {
        result: any = None;
        sessions: any = None;
        result = await rpc(base, token, "list_tasks", {"include_archived": True});
        sessions = await rpc(base, token, "list_sessions", {});
        tasks = result; history = sessions; plan = None;
    }
    async def login {
        if busy { return; }
        busy = True; error = "";
        next_token: str = "";
        result: any = None;
        sessions: any = None;
        try {
            next_token = await authenticate(base, username.strip(), password, signup);
            result = await rpc(base, next_token, "list_tasks", {"include_archived": True});
            sessions = await rpc(base, next_token, "list_sessions", {});
            token = next_token; tasks = result; history = sessions; password = "";
        } except Exception as err { error = str(err); }
        finally { busy = False; }
    }
    async def refresh {
        if busy { return; }
        busy = True; error = "";
        try { await load(); plan = None; }
        except Exception as err { error = str(err); }
        finally { busy = False; }
    }
    async def save {
        if busy { return; }
        busy = True; error = "";
        try {
            await rpc(base, token, "save_task", {"title": title, "course": course, "due": due,
                "priority": int(priority), "minutes": int(minutes), "task_id": ""});
            title = ""; plan = None; await load(); tab = "tasks";
        } except Exception as err { error = str(err); }
        finally { busy = False; }
    }
    async def complete(t: dict[str, any]) {
        if busy { return; }
        busy = True; error = "";
        try {
            await rpc(base, token, "set_done", {"task_id": t["id"], "done": not t["done"]});
            await load(); plan = None;
        } except Exception as err { error = str(err); }
        finally { busy = False; }
    }
    async def archive(t: dict[str, any]) {
        if busy { return; }
        busy = True; error = "";
        try {
            await rpc(base, token, "archive_task", {"task_id": t["id"], "archived": not t["archived"]});
            await load();
        } except Exception as err { error = str(err); }
        finally { busy = False; }
    }
    async def schedule {
        if busy { return; }
        busy = True; error = "";
        try { plan = await rpc(base, token, "day_plan", {"day": day, "budget": int(budget)}); }
        except Exception as err { error = str(err); }
        finally { busy = False; }
    }
    return <KeyboardAvoidingView style={styles.screen} behavior={"padding" if Platform.OS == "ios" else "height"}>
        <ScrollView contentContainerStyle={styles.body} keyboardShouldPersistTaps="handled">
            <Text style={styles.brand}>M / MAIZEPLAN</Text>
            <Text style={styles.heading}>{"Your next good move." if token else "Your plan, to go."}</Text>
            {<Text style={styles.error} accessibilityRole="alert">{error}</Text> if error else <View/>}
            {<Text style={styles.badge}>Connecting…</Text> if busy else <View/>}
            {<View style={{gap: 14}}>
                <Text style={styles.text}>Connect to the same server as your web app. On a physical phone, localhost means the phone—not your laptop. Use your laptop’s LAN address for trusted local testing, or HTTPS.</Text>
                <Text style={styles.text}>Server URL</Text><TextInput accessibilityLabel="Server URL" autoCapitalize="none" autoCorrect={False} value={base} style={styles.input} onChangeText={lambda (v: str) { base = v; }}/>
                <Text style={styles.text}>Username</Text><TextInput accessibilityLabel="Username" autoCapitalize="none" autoCorrect={False} value={username} style={styles.input} onChangeText={lambda (v: str) { username = v; }}/>
                <Text style={styles.text}>Password</Text><TextInput accessibilityLabel="Password" secureTextEntry={True} value={password} style={styles.input} onChangeText={lambda (v: str) { password = v; }}/>
                <Pressable disabled={busy} style={styles.button} onPress={login}><Text style={styles.buttonText}>{"Create account" if signup else "Sign in"}</Text></Pressable>
                <Pressable disabled={busy} style={styles.secondary} onPress={lambda { signup = not signup; }}><Text style={styles.buttonText}>{"Use existing account" if signup else "New? Create account"}</Text></Pressable>
                <Text style={styles.text}>Password: at least 8 characters. Session tokens stay in memory; tasks stay on the server.</Text>
            </View> if not token else <View style={{gap: 16}}>
                <View style={styles.row}>{[<Pressable key={v} style={styles.button if tab == v else styles.secondary} onPress={lambda { tab = v; }}><Text style={styles.buttonText}>{v.capitalize()}</Text></Pressable> for v in ["tasks", "add", "focus", "progress"]]}</View>
                {<View style={{gap: 14}}><Pressable disabled={busy} style={styles.secondary} onPress={refresh}><Text style={styles.buttonText}>Refresh from server</Text></Pressable>
                    <Pressable accessibilityRole="button" style={styles.secondary} onPress={lambda { show_archived = not show_archived; }}><Text style={styles.buttonText}>{"Show active tasks" if show_archived else "Show archived tasks"}</Text></Pressable>
                    {<Text style={styles.text}>{"No archived tasks." if show_archived else "No active tasks. Add a task or restore one from the archive."}</Text> if not len([t for t in tasks if t["archived"] == show_archived]) else <View/>}
                    {[<View key={t["id"]} style={styles.card}><Text style={styles.meta}>{t["course"] or "PERSONAL"}</Text><Text style={styles.title}>{t["title"]}</Text><Text style={styles.meta}>{"Completed" if t["done"] else ("Overdue" if t["due"] < today() else "Open")} · {t["due"]} · {str(t["minutes"])} min · P{str(t["priority"])}</Text>
                        {<Pressable disabled={busy} style={styles.secondary} onPress={lambda { complete(t); }}><Text style={styles.buttonText}>{"Reopen task" if t["done"] else "Mark complete"}</Text></Pressable> if not t["archived"] else <Text style={styles.meta}>Archived · excluded from plans</Text>}
                        <Pressable accessibilityRole="button" disabled={busy} style={styles.secondary} onPress={lambda { archive(t); }}><Text style={styles.buttonText}>{"Restore task" if t["archived"] else "Archive task"}</Text></Pressable></View> for t in tasks if t["archived"] == show_archived]}
                </View> if tab == "tasks" else <View/>}
                {<View style={{gap: 14}}><Text style={styles.text}>Task title</Text><TextInput accessibilityLabel="Task title" style={styles.input} value={title} maxLength={160} onChangeText={lambda (v: str) { title = v; }}/>
                    <Text style={styles.text}>Course or area</Text><TextInput accessibilityLabel="Course" style={styles.input} value={course} maxLength={40} onChangeText={lambda (v: str) { course = v; }}/>
                    <Text style={styles.text}>Deadline (YYYY-MM-DD)</Text><TextInput accessibilityLabel="Deadline" style={styles.input} value={due} onChangeText={lambda (v: str) { due = v; }}/>
                    <Text style={styles.text}>Estimated minutes (1–1440)</Text><TextInput accessibilityLabel="Minutes" style={styles.input} value={minutes} keyboardType="number-pad" onChangeText={lambda (v: str) { minutes = v; }}/>
                    <Text style={styles.text}>Priority: 1 low · 2 medium · 3 high</Text><View style={styles.row}>{[<Pressable key={p} style={styles.button if priority == p else styles.secondary} onPress={lambda { priority = p; }}><Text style={styles.buttonText}>{p}</Text></Pressable> for p in ["1", "2", "3"]]}</View>
                    <Pressable disabled={busy} style={styles.button} onPress={save}><Text style={styles.buttonText}>Add task</Text></Pressable>
                </View> if tab == "add" else <View/>}
                {<View style={{gap: 14}}><Text style={styles.text}>Planning day (YYYY-MM-DD)</Text><TextInput accessibilityLabel="Planning day" style={styles.input} value={day} onChangeText={lambda (v: str) { day = v; plan = None; }}/>
                    <Text style={styles.text}>Available minutes, including breaks</Text><TextInput accessibilityLabel="Available minutes" style={styles.input} value={budget} keyboardType="number-pad" onChangeText={lambda (v: str) { budget = v; plan = None; }}/>
                    <Pressable disabled={busy} style={styles.button} onPress={schedule}><Text style={styles.buttonText}>Make my plan</Text></Pressable>
                    {<View style={{gap: 14}}><Text style={styles.text}>{str(plan["study"])} min focus · {str(plan["breaks"])} min breaks · {str(plan["remaining"])} min left outside plan</Text><Text style={styles.text}>{plan["rule"]}</Text>
                        {<Text style={styles.error}>{str(plan["urgent_unplanned"])} minutes of due/overdue work do not fit.</Text> if plan["urgent_unplanned"] > 0 else <View/>}
                        {[<View key={str(i)} style={styles.card}><Text style={styles.meta}>Start +{str(b["start"])} min · {str(b["minutes"])} min focus</Text><Text style={styles.title}>{b["title"]}</Text></View> for (i, b) in enumerate(plan["blocks"])]}
                    </View> if plan else <View/>}
                </View> if tab == "focus" else <View/>}
                {<Progress base={base} token={token} tasks={tasks} history={history} onSaved={load}/> if tab == "progress" else <View/>}
                <Pressable disabled={busy} style={styles.secondary} onPress={lambda { token = ""; tasks = []; history = []; plan = None; error = ""; title = ""; course = ""; }}><Text style={styles.buttonText}>Sign out</Text></Pressable>
            </View>}
        </ScrollView>
    </KeyboardAvoidingView>;
}
