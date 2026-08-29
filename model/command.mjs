import { MAX_OUTPUT_CHARS } from "./limits.mjs"

export const MAX_STDOUT_BYTES = MAX_OUTPUT_CHARS
export const MAX_STDERR_BYTES = 4096

// The Vikunja API token travels via the VIKUNJA_TOKEN environment variable
// (set on the Process), never argv, so it does not show up in `ps`.
export const TOKEN_ENV = "VIKUNJA_TOKEN"

// The keyring service attribute the token is stored under.
export const SECRET_SERVICE = "org.jsongerber.vikunja"

// Cap both pipes while preserving producer failures, same as the caldir widget.
export function boundedCommand(argv) {
  const script = "set -o pipefail; " +
    '{ exec "$@" 2>&1 1>&3 | head -c ' + MAX_STDERR_BYTES + " >&2; } 3>&1" +
    " | head -c " + MAX_STDOUT_BYTES
  return ["bash", "-c", script, "vikunja-widget"].concat(argv)
}

// Read the token from the OS keyring. The lookup keys on both the fixed
// service attribute and the instance URL, so each instance keeps its own
// token and changing the instance URL never reuses a stale one. The secret
// itself never appears on a command line.
export function secretLookupCommand(instance) {
  return ["secret-tool", "lookup", "service", SECRET_SERVICE, "instance", instance]
}

// Store the token in the OS keyring, scoped to the instance URL it belongs
// to. The secret arrives via the VIKUNJA_TOKEN environment variable (never
// argv) and is fed to secret-tool over a here-string, so it does not show up
// in `ps`.
export function storeTokenCommand(instance) {
  const script = 'secret-tool store --label="Vikunja API token" service "$1" instance "$2" <<< "$VIKUNJA_TOKEN"'
  return ["bash", "-c", script, "vikunja-store", SECRET_SERVICE, instance]
}

// Fetch items across all pages and merge every page's items into one JSON
// array. Bounded to 20 pages so a misbehaving total can never loop forever.
// Non-200 responses (auth failures, wrong host, etc.) are reported on stderr
// and fail the fetch so the widget can surface an error instead of showing an
// empty list.
function fetchItemsCommand(instance, path) {
  const script = [
    'instance="$1"',
    'path="$2"',
    "page=1",
    "total_pages=1",
    'out="[]"',
    'while [ "$page" -le "$total_pages" ] && [ "$page" -le 20 ]; do',
    '  resp="$(curl -sS --max-time 20 -w "%{http_code}" -H "Authorization: Bearer ${VIKUNJA_TOKEN}" "${instance}${path}?per_page=50&page=${page}")"',
    '  code="${resp: -3}"',
    '  body="${resp%???}"',
    '  if [ "$code" != "200" ]; then',
    '    case "$code" in',
    '      401) printf "Unauthorized (HTTP 401) — check the API token" >&2 ;;',
    '      403) printf "Forbidden (HTTP 403) — the token lacks access" >&2 ;;',
    '      404)',
    '        v1="$(curl -sS --max-time 20 -o /dev/null -w "%{http_code}" "${instance}/api/v1/info")"',
    '        if [ "$v1" = "200" ]; then printf "Vikunja is running API v1 — update your instance (this widget requires API v2, Vikunja 2.4+)" >&2;',
    '        else printf "Not a Vikunja instance (HTTP 404)" >&2; fi ;;',
    '      *) printf "HTTP %s from %s" "$code" "$path" >&2 ;;',
    '    esac',
    '    exit 1',
    '  fi',
    '  total_pages="$(printf "%s" "$body" | jq -r ".total_pages // 1")"',
    '  out="$(printf "%s\\n%s" "$out" "$body" | jq -s ".[0] + .[1].items")"',
    '  page="$((page + 1))"',
    "done",
    "printf '%s' \"$out\""
  ].join("\n")
  return ["bash", "-c", script, "vikunja-fetch", instance, path]
}

export function tasksCommand(instance) {
  return fetchItemsCommand(instance, "/api/v2/tasks")
}

export function projectsCommand(instance) {
  return fetchItemsCommand(instance, "/api/v2/projects")
}

// Mark a task done. The panel only offers this on open tasks, so "done" is
// always the target state; reopening is out of scope for the widget.
export function toggleDoneCommand(instance, id) {
  const script = [
    'instance="$1"',
    'id="$2"',
    'curl -sS --max-time 20 -X PATCH -H "Authorization: Bearer ${VIKUNJA_TOKEN}" -H "Content-Type: application/json" -d \'{"done":true}\' "${instance}/api/v2/tasks/${id}"'
  ].join("\n")
  return ["bash", "-c", script, "vikunja-toggle", instance, String(id)]
}

// Verify the instance URL and API token by requesting one page of the tasks
// endpoint, which is the resource the widget actually loads. `/api/v2/user`
// is avoided because scoped API tokens (Vikunja 2.5+) can read tasks without
// the "user" permission, which would report a false 401. Prints a short
// human-readable result to stdout and exits non-zero unless Vikunja answers
// 200. A 404 on v2 is checked against /api/v1/info so an old instance gets a
// "please update" hint instead of a generic "not a Vikunja instance".
export function testCommand(instance) {
  const script = [
    'instance="$1"',
    'errfile="$(mktemp)"',
    'code="$(curl -sS --max-time 20 -o /dev/null -w "%{http_code}" -H "Authorization: Bearer ${VIKUNJA_TOKEN}" "${instance}/api/v2/tasks?per_page=1" 2>"$errfile")"',
    'err="$(cat "$errfile")"; rm -f "$errfile"',
    'if [ "$code" = "200" ]; then printf "Connection OK"; exit 0; fi',
    'if [ -n "$err" ]; then printf "%s" "$err"',
    'elif [ "$code" = "401" ]; then printf "Unauthorized: check the API token"',
    'elif [ "$code" = "403" ]; then printf "Forbidden: the token lacks access"',
    'elif [ "$code" = "404" ]; then',
    '  v1="$(curl -sS --max-time 20 -o /dev/null -w "%{http_code}" "${instance}/api/v1/info")"',
    '  if [ "$v1" = "200" ]; then printf "Vikunja is running API v1 — update your instance (this widget requires API v2, Vikunja 2.4+)"',
    '  else printf "Not a Vikunja instance (HTTP 404)"; fi',
    'else printf "HTTP %s" "$code"; fi',
    'exit 1'
  ].join("\n")
  return ["bash", "-c", script, "vikunja-test", instance]
}
