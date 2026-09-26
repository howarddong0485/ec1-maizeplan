def:pub Workload(week: dict[str, any]) -> JsxElement {
    scale = max([d["budget"] for d in week["days"]] + [1]);
    return <section className="workload" aria-label="Weekly workload chart"><h3>Your week at a glance</h3>
        <p className="small">Focus · breaks · free capacity. Bars share one minutes scale. Deadline warnings below show work that cannot fit on time.</p>
        <div className="chart-legend"><span><i className="load-study"/>Focus</span><span><i className="load-break"/>Breaks</span><span><i className="load-free"/>Free</span></div>
        {[<div key={d["day"]} className="load-row"><div className="load-label"><strong>{d["day"]}</strong><span>{str(d["study"])} focus + {str(d["breaks"])} break / {str(d["budget"])} min</span></div>
            <div className="load-track" role="img" aria-label={d["day"] + ": " + str(d["study"]) + " focus, " + str(d["breaks"]) + " break, " + str(d["budget"] - d["elapsed"]) + " free minutes"}>
                <span className="load-study" style={{width: str(d["study"] * 100 / scale) + "%"}}/><span className="load-break" style={{width: str(d["breaks"] * 100 / scale) + "%"}}/><span className="load-free" style={{width: str((d["budget"] - d["elapsed"]) * 100 / scale) + "%"}}/>
            </div><p className="small">{"Day off" if not d["budget"] else str(d["budget"] - d["elapsed"]) + " min free"}{" · " + str(d["late"]) + " min late / catch-up" if d["late"] else ""}{" · " + str(d["urgent_unplanned"]) + " min due/overdue still remaining" if d["urgent_unplanned"] else ""}</p>
        </div> for d in week["days"]]}
    </section>;
}
