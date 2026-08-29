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
  org.jasongerber.vikunja`), never `shell.json`. The token is piped over stdin
  via `Process.stdinEnabled` + `write()`, never argv. A link below the field
  opens `{instance}/user/settings/api-tokens`.
- **Sync interval** — `syncInterval` (seconds, clamped 30–86400), drives the
  refresh `Timer` in `BarWidget.qml`.
- **Show completed / Show no due date** — `showDone` / `showNoDate` toggles.

## Persistence

Settings are written to the widget's entry in `~/.config/omarchy/shell.json`
via `BarWidget.persistSettings()`, which applies values locally first (so the
bar reacts on the click itself) and then calls
`root.bar.shell.updateEntryInline(moduleName, entry)`. The shell hot-reloads
`shell.json` on save, re-injects `settings` (`onModuleSettingsChanged →
injectProps`), and `BarWidget.qml`'s `onSettingsChanged` triggers a refresh —
so manual edits to `shell.json` are picked up live.

## Auth

The API token is looked up once per session with
`secret-tool lookup service org.jasongerber.vikunja` and passed to `curl` via
the `VIKUNJA_TOKEN` environment variable, never argv. Storing a new token from
the settings page clears the cached token and re-runs the lookup + fetch.
