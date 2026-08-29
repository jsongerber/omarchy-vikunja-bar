import { dayDistance } from "./dates.mjs"

const WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const MAX_BAR_LABEL_LENGTH = 28

// Neutralize rich-text triggers in strings passed to host AutoText items.
export function plainLine(value) {
  const string = value === undefined || value === null ? "" : String(value)
  return string
    .replace(/[\u0000-\u001F\u007F\u2028\u2029]+/g, " ")
    .replace(/<|&lt;/g, "‹")
}

export function truncate(value, limit) {
  const string = value === undefined || value === null ? "" : String(value)
  const max = Math.max(1, Number(limit) || 24)
  if (string.length <= max) return string
  return string.substring(0, max - 1).replace(/\s+$/, "") + "…"
}

// Short relative due label: "", "today", "tmrw", "in 3d", "overdue 2d".
export function relativeDue(task, now) {
  const due = task && task.dueMs
  if (due === null || due === undefined || isNaN(due)) return ""
  const distance = dayDistance(due, now)
  if (distance < 0) {
    const days = -distance
    return days === 1 ? "overdue 1d" : "overdue " + days + "d"
  }
  if (distance === 0) return "today"
  if (distance === 1) return "tmrw"
  return "in " + distance + "d"
}

// Bar label: title plus the relative due time, capped to fit.
export function formatLabel(task, now) {
  let title = plainLine(task.title)
  let suffix = relativeDue(task, now)
  if (suffix !== "") suffix = " · " + suffix

  const titleLimit = Math.max(3, MAX_BAR_LABEL_LENGTH - suffix.length)
  if (title.length > titleLimit) title = title.slice(0, Math.max(1, titleLimit - 1)) + "…"
  return title + suffix
}

function fullDayLabel(date) {
  return WEEKDAYS[date.getDay()] + " " + date.getDate() + " " + MONTHS[date.getMonth()]
}

// Full due label for the hero card: "Today", "Tomorrow", "Wed 3 Sep",
// "Overdue · Mon 25 Aug", or "No due date".
export function dueDateLabel(task, now) {
  const due = task && task.dueMs
  if (due === null || due === undefined || isNaN(due)) return "No due date"
  const distance = dayDistance(due, now)
  const date = new Date(due)
  if (distance === 0) return "Today"
  if (distance === 1) return "Tomorrow"
  if (distance < 0) return "Overdue · " + fullDayLabel(date)
  return fullDayLabel(date)
}

// Priority glyph used by the panel; 0 is unset and renders nothing.
export function priorityGlyph(priority) {
  switch (priority) {
    case 1: return "▁"
    case 2: return "▂"
    case 3: return "▄"
    case 4: return "▇"
    default: return ""
  }
}

export function priorityName(priority) {
  switch (priority) {
    case 1: return "Low"
    case 2: return "Medium"
    case 3: return "High"
    case 4: return "Urgent"
    default: return ""
  }
}
