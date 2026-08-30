# Vikunja Todos widget for Omarchy

Quick access to your open Vikunja todos in the Omarchy bar. Shows your most
urgent todo in the bar and the list, grouped by due date, on click.

## Install

```sh
omarchy plugin add https://github.com/jsongerber/omarchy-vikunja-bar.git --enable
```

## Remove

```sh
omarchy plugin remove org.jsongerber.vikunja
```

## Features

- Lists open todos grouped by **Overdue / Today / Tomorrow / Later / No due date**.
- Bar shows the most urgent open todo (overdue first, then soonest due), or a
  compact icon when `showTitle` is off.
- Hovering the bar shows a summary of the open list (e.g. `5 open · 2 overdue`).
- Left-click a todo opens it in the Vikunja web UI; right-click marks it done.
- Prioritised tasks show a colored priority marker (1–4).
- Repeating tasks show a ↻ icon.
- API token is read from the OS keyring and passed to `curl` via the
  environment — it never appears in `ps` or on disk.
- Syncs automatically on a configurable interval (default 300 seconds).
- A **settings page** (gear icon in the panel) configures the server URL,
  API token, sync interval, and visibility of no-due-date todos, and
  includes a **Test connection** button that verifies the URL and token.
- Clear **error and setup screens**: an auth/connection failure shows an error
  card with Retry and Settings buttons, and a missing URL or token shows a
  dedicated "No instance set" / "No API token" screen.

## Configure

1. Add the widget to `~/.config/omarchy/shell.json` (or skip this and configure
   everything from the panel's settings page):

   ```json
   {
     "id": "org.jsongerber.vikunja",
     "instance": "https://vikunja.example.com"
   }
   ```

   You can set `instance` here, or leave it empty and configure everything from
   the panel's settings page.

2. Create an API token in Vikunja (Settings → API Tokens) and store it in your
   keyring. Easiest from the panel: open the settings page (gear icon), paste
   the token into the **API TOKEN** field, and press **Test connection** (or
   Enter) — on success the token is stored and the list loads. The settings
   page also links straight to `{instance}/user/settings/api-tokens`.

   Alternatively, store it on the command line (note the `instance` attribute,
   which ties the token to a specific instance URL):

   ```sh
   secret-tool store --label='Vikunja API token' \
     service org.jsongerber.vikunja instance https://vikunja.example.com
   ```

   The token is looked up with
   `secret-tool lookup service org.jsongerber.vikunja instance <url>`, so it
   must be available to the omarchy shell's session (an unlocked keyring).

3. Press <kbd>s</kbd> in the panel (or click the sync button) to load.

Requires `curl`, `jq`, and `secret-tool` (libsecret).

## Settings

All settings live in the widget's entry in `~/.config/omarchy/shell.json` and
can be edited there or from the panel's settings page (the gear icon). The bar
picks up manual `shell.json` edits automatically.

| Setting | Default | Purpose |
| --- | --- | --- |
| `instance` | `""` | Base URL of your Vikunja instance (no trailing slash). |
| `syncInterval` | `300` | Seconds between automatic refreshes (clamped 30–86400). |
| `showNoDate` | `true` | Include todos that have no due date. |
| `showTitle` | `true` | Show the next task's title in the bar (off: compact icon only). |

The API token is **not** stored in `shell.json` — it lives in the OS keyring
(`service org.jsongerber.vikunja`, scoped per `instance`) and is written from
the settings page.

## IPC

```sh
omarchy shell org.jsongerber.vikunja toggle
omarchy shell org.jsongerber.vikunja open
omarchy shell org.jsongerber.vikunja close
omarchy shell org.jsongerber.vikunja refresh
```

## Development

```sh
npm test                # model unit tests
omarchy plugin validate .
```

The model is pure, dependency-free ES modules (`model/*.mjs`) re-exported by
`Model.mjs`, tested with `node --test` against `Europe/London` time.
