// shell.json is hand-editable, so the manifest's types and bounds constrain
// the settings UI but not the file. Everything is re-checked here.

export const INSTANCE = {
  key: "instance",
  defaultValue: ""
}

export const SHOW_DONE = {
  key: "showDone",
  defaultValue: false
}

export const SHOW_NO_DATE = {
  key: "showNoDate",
  defaultValue: true
}

export const SYNC_INTERVAL = {
  key: "syncInterval",
  defaultValue: 300,
  min: 30,
  max: 86400
}

// The instance URL is kept as a trimmed base URL without a trailing slash,
// so callers can append "/api/v2/..." directly. An empty string means the
// widget has not been configured yet.
export function normalizeInstance(value) {
  if (value === undefined || value === null) return INSTANCE.defaultValue
  return String(value).trim().replace(/\/+$/, "")
}

function normalizeBoolean(value, spec) {
  if (value === undefined || value === null) return spec.defaultValue
  if (typeof value === "boolean") return value
  if (typeof value === "string") {
    const text = value.trim().toLowerCase()
    if (text === "true" || text === "1" || text === "yes" || text === "on") return true
    if (text === "false" || text === "0" || text === "no" || text === "off") return false
  }
  return spec.defaultValue
}

export function normalizeShowDone(value) {
  return normalizeBoolean(value, SHOW_DONE)
}

export function normalizeShowNoDate(value) {
  return normalizeBoolean(value, SHOW_NO_DATE)
}

// Seconds between automatic refreshes. shell.json is hand-editable so the
// value can arrive as a string or anything else; clamp to the declared bounds
// and fall back to the default on anything unparseable.
export function normalizeSyncInterval(value) {
  if (value === undefined || value === null) return SYNC_INTERVAL.defaultValue
  const n = parseInt(String(value).trim(), 10)
  if (!isFinite(n)) return SYNC_INTERVAL.defaultValue
  if (n < SYNC_INTERVAL.min) return SYNC_INTERVAL.min
  if (n > SYNC_INTERVAL.max) return SYNC_INTERVAL.max
  return n
}
