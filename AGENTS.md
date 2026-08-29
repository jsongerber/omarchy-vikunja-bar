## Architecture

The widget is split the same way as the other shell panels: `BarWidget.qml`
owns all data and actions (keyring lookup, `curl` fetches, toggling todos) and
the panel stays presentational. `Panel.qml` reads everything through
`hostWidget` and delegates actions back to it, so the host is the single owner
of the token, the task list, and the sync state machine.

`model/*.mjs` is pure, dependency-free ES and is re-exported by `Model.mjs` for
both QML and the Node test suite (`npm test`). Values are normalized at the
boundary (in `model/settings.mjs`) because `shell.json` is hand-editable and the
manifest schema is only a hint; a test keeps the settings declarations in step
with `manifest.json`.

## Settings page

A gear `PanelActionButton` in the panel header toggles `showSettings`, which
swaps the todo list for a settings view. The fields are:

- **Server** — `instance`, normalized on commit (`normalizeInstance`).
- **API token** — stored to the keyring (`secret-tool store … service
  org.jsongerber.vikunja instance <url>`), never `shell.json`. The token
  travels via the `VIKUNJA_TOKEN` environment variable (fed to `secret-tool`
  over a here-string), never argv. A link below the field opens
  `{instance}/user/settings/api-tokens`.
- **Sync interval** — `syncInterval` (seconds, clamped 30–86400), drives the
  refresh `Timer` in `BarWidget.qml`.
- **Show no due date / Show title** — `showNoDate`
  / `showTitle` toggles. `showTitle` collapses the bar to a compact icon when
  off.
- **Test connection** — a button that runs a lightweight authenticated request
  (`/api/v2/user`) via `BarWidget.testConnection()`. It commits the server
  field first, tests the token in the field (or looks it up from the keyring if
  the field is empty), and — on success — stores the typed token to the keyring
  scoped to the instance. Status flows back as `testStatus`/`testMessage`
  ("idle"/"running"/"ok"/"error").

## Error and empty states

The todo view (when not in settings) shows one of:

- `setupItem` — no config (`!hasConfig`): "No instance set" vs "No API token",
  driven by `BarWidget.configIssue`, with an "Open settings" button.
- `errorItem` — a load error (`hasConfig && loadError !== ""`): a card with the
  error text plus "Retry" and "Settings" buttons.
- `heroItem` / `groupsItem` / `emptyItem` — the normal next-todo hero, the
  grouped list, and the "all caught up" state.

`fetchItemsCommand` now appends `%{http_code}` to the `curl` output and fails on
any non-200 response with a friendly message on stderr (401/403/404 get
specific text), so auth and connectivity problems surface as an error instead
of an empty list.

## Persistence

Settings are written to the widget's entry in `~/.config/omarchy/shell.json`
via `BarWidget.persistSettings()`, which applies values locally first (so the
bar reacts on the click itself) and then calls
`root.bar.shell.updateEntryInline(moduleName, entry)`. The shell hot-reloads
`shell.json` on save, re-injects `settings` (`onModuleSettingsChanged →
injectProps`), and `BarWidget.qml`'s `onSettingsChanged` triggers a refresh —
so manual edits to `shell.json` are picked up live.

## Auth

The API token is stored in the keyring scoped to the instance URL
(`secret-tool store … service org.jsongerber.vikunja instance <url>`) and
looked up per instance with `secret-tool lookup service org.jsongerber.vikunja
instance <url>`. It is passed to `curl` via the `VIKUNJA_TOKEN` environment
variable, never argv. Because the token is scoped per instance, changing the
instance URL drops the cached token (`BarWidget.onInstanceChanged`) and the
widget re-reads the keyring for the new URL. Storing a new token from the
settings page (via the **Test connection** button) also clears the cached token
and re-runs the lookup + fetch.
