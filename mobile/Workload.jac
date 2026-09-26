import from "@jac/mobui" { View, Text }

def:pub Workload(week: dict[str, any]) -> JsxElement {
    scale = max([d["budget"] for d in week["days"]] + [1]);
    return <View style={{gap: 14}}><Text style={{fontSize: 22, color: "#ffcd36", fontWeight: "bold"}}>Your week at a glance</Text>
        <Text style={{color: "#d7e1f0"}}>Blue: focus · gold: breaks · gray: free. Bars share one minutes scale; deadline warnings show work that cannot fit on time.</Text>
        {[<View key={d["day"]} style={{gap: 6}}><Text style={{color: "#ffffff"}}>{d["day"]} · {str(d["study"])} focus + {str(d["breaks"])} break / {str(d["budget"])} min</Text>
            <View accessibilityLabel={d["day"] + ": " + str(d["study"]) + " focus, " + str(d["breaks"]) + " break, " + str(d["budget"] - d["elapsed"]) + " free minutes"} style={{height: 18, flexDirection: "row", backgroundColor: "#234064", borderRadius: 4, overflow: "hidden"}}>
                <View style={{backgroundColor: "#72bcff", width: str(d["study"] * 100 / scale) + "%"}}/><View style={{backgroundColor: "#ffcd36", width: str(d["breaks"] * 100 / scale) + "%"}}/><View style={{backgroundColor: "#b3c0d0", width: str((d["budget"] - d["elapsed"]) * 100 / scale) + "%"}}/>
            </View><Text style={{color: "#d7e1f0"}}>{"Day off" if not d["budget"] else str(d["budget"] - d["elapsed"]) + " min free"}{" · " + str(d["late"]) + " min late / catch-up" if d["late"] else ""}{" · " + str(d["urgent_unplanned"]) + " min due/overdue remain" if d["urgent_unplanned"] else ""}</Text>
        </View> for d in week["days"]]}
    </View>;
}
