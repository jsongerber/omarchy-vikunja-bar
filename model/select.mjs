import { addLocalDays, startOfLocalDay } from "./dates.mjs"
import { normalizeShowDone, normalizeShowNoDate } from "./settings.mjs"

export const GROUP_OVERDUE = "overdue"
export const GROUP_TODAY = "today"
export const GROUP_TOMORROW = "tomorrow"
export const GROUP_LATER = "later"
export const GROUP_NO_DATE = "no-date"

// The next todo is the most urgent open task. parseTasks already sorts
// overdue first, then soonest due, then highest priority, then title.
export function nextTodo(tasks) {
  for (let i = 0; i < tasks.length; i++) {
    if (tasks[i].done !== true) return tasks[i]
  }
  return null
}

function openTasks(tasks, showDone) {
  if (showDone) return tasks
  const open = []
  for (let i = 0; i < tasks.length; i++) {
    if (tasks[i].done !== true) open.push(tasks[i])
  }
  return open
}

export function buildGroups(tasks, now, options) {
  const settings = options || {}
  const showDone = normalizeShowDone(settings.showDone)
  const showNoDate = normalizeShowNoDate(settings.showNoDate)

  const list = openTasks(tasks, showDone)
  const todayStart = startOfLocalDay(now)
  const tomorrowStart = addLocalDays(todayStart, 1)

  const buckets = {}
  for (let i = 0; i < list.length; i++) {
    const task = list[i]
    let key
    if (task.dueMs === null) {
      key = GROUP_NO_DATE
    } else {
      const dueDay = startOfLocalDay(new Date(task.dueMs))
      if (dueDay < todayStart) key = GROUP_OVERDUE
      else if (dueDay.getTime() === todayStart.getTime()) key = GROUP_TODAY
      else if (dueDay.getTime() === tomorrowStart.getTime()) key = GROUP_TOMORROW
      else key = GROUP_LATER
    }
    if (!buckets[key]) buckets[key] = []
    buckets[key].push(task)
  }

  const titles = {
    [GROUP_OVERDUE]: "OVERDUE",
    [GROUP_TODAY]: "TODAY",
    [GROUP_TOMORROW]: "TOMORROW",
    [GROUP_LATER]: "LATER",
    [GROUP_NO_DATE]: "NO DUE DATE"
  }
  const order = [GROUP_OVERDUE, GROUP_TODAY, GROUP_TOMORROW, GROUP_LATER, GROUP_NO_DATE]

  const groups = []
  for (let i = 0; i < order.length; i++) {
    const key = order[i]
    if (!buckets[key] || buckets[key].length === 0) continue
    if (key === GROUP_NO_DATE && !showNoDate) continue
    groups.push({ key: key, title: titles[key], items: buckets[key] })
  }
  return groups
}

// A list rather than a set of flags, so the panel's selected action is an
// index and an unavailable action is absent rather than present-but-invalid.
export function heroActions(task) {
  if (!task) return []
  return task.done ? ["open"] : ["open", "done"]
}
