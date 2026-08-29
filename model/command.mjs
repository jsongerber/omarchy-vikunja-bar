import { MAX_OUTPUT_CHARS } from "./limits.mjs"

export const MAX_STDOUT_BYTES = MAX_OUTPUT_CHARS
export const MAX_STDERR_BYTES = 4096

// The Vikunja API token travels via the VIKUNJA_TOKEN environment variable
// (set on the Process), never argv, so it does not show up in `ps`.
export const TOKEN_ENV = "VIKUNJA_TOKEN"

// The keyring service attribute the token is stored under.
export const SECRET_SERVICE = "org.jasongerber.vikunja"

// Cap both pipes while preserving producer failures, same as the caldir widget.
export function boundedCommand(argv) {
  const script = "set -o pipefail; " +
    '{ exec "$@" 2>&1 1>&3 | head -c ' + MAX_STDERR_BYTES + " >&2; } 3>&1" +
    " | head -c " + MAX_STDOUT_BYTES
  return ["bash", "-c", script, "vikunja-widget"].concat(argv)
}

// Read the token from the OS keyring. The lookup only uses the fixed service
// attribute, so the secret itself never appears on a command line.
export function secretLookupCommand() {
  return ["secret-tool", "lookup", "service", SECRET_SERVICE]
}

// Store the token in the OS keyring. The secret is piped over stdin by the
// caller (never argv), so it does not show up in `ps`.
export function storeTokenCommand() {
  return ["secret-tool", "store", "--label=Vikunja API token", "service", SECRET_SERVICE]
}

// Fetch items across all pages and merge every page's items into one JSON
// array. Bounded to 20 pages so a misbehaving total can never loop forever.
function fetchItemsCommand(instance, path) {
  const script = [
    'instance="$1"',
    'path="$2"',
    "page=1",
    "total_pages=1",
    'out="[]"',
    'while [ "$page" -le "$total_pages" ] && [ "$page" -le 20 ]; do',
    '  resp="$(curl -sS --max-time 20 -H "Authorization: Bearer ${VIKUNJA_TOKEN}" "${instance}${path}?per_page=50&page=${page}")"',
    "  total_pages=\"$(printf '%s' \"$resp\" | jq -r '.total_pages // 1')\"",
    "  out=\"$(printf '%s\\n%s' \"$out\" \"$resp\" | jq -s '.[0] + .[1].items')\"",
    "  page=\"$((page + 1))\"",
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
