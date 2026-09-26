import from core.api { Task, list_tasks, save_task, set_done, archive_task, day_plan, StudySession, StudyChange, list_sessions, log_study, revise_study, WeeklyCapacity, get_capacity, save_capacity, week_plan }
import from .Planner { Planner }
import ".global.css";

def:pub app -> JsxElement { <Planner /> }
