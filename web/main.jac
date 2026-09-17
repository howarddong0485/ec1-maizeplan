import from core.api { Task, list_tasks, save_task, set_done, day_plan }
import from .Planner { Planner }
import ".global.css";

def:pub app -> JsxElement { <Planner /> }
