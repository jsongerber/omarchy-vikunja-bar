# Vikunja Todos widget for Omarchy

Quick access to your open Vikunja todos in the Omarchy bar. Shows your most
urgent todo in the bar and the full list, grouped by due date, on click.

## Features

- Lists open todos grouped by **Overdue / Today / Tomorrow / Later / No due date**.
- Bar shows the most urgent open todo (overdue first, then soonest due).
- Left-click a todo opens it in the Vikunja web UI; right-click marks it done.
- Prioritised tasks show a colored priority marker (1–4).
- API token is read from the OS keyring and passed to `curl` via the
  environment — it never appears in `ps` or on disk.
- Syncs automatically every five minutes (or press <kbd>s</kbd> / click the
  sync button).

## Setup

1. Add the widget to `~/.config/omarchy/shell.json` and set your instance:

   ```json
   {
     "id": "org.jasongerber.vikunja",
     "instance": "https://vikunja.example.com"
   }
   ```

2. Create an API token in Vikunja (Settings → API Tokens) and store it in your
   keyring:

   ```sh
   secret-tool store --label='Vikunja API token' service org.jasongerber.vikunja
   ```

   The token is looked up with `secret-tool lookup service org.jasongerber.vikunja`,
   so it must be available to the omarchy shell's session (an unlocked keyring).

3. Press <kbd>s</kbd> in the panel (or click the sync button) to load.

Requires `curl`, `jq`, and `secret-tool` (libsecret).

## Settings

| Setting | Default | Purpose |
| --- | --- | --- |
| `instance` | `""` | Base URL of your Vikunja instance (no trailing slash). |
| `showDone` | `false` | Also show completed todos, dimmed. |
| `showNoDate` | `true` | Include todos that have no due date. |

## IPC

```sh
omarchy shell org.jasongerber.vikunja toggle
omarchy shell org.jasongerber.vikunja open
omarchy shell org.jasongerber.vikunja close
omarchy shell org.jasongerber.vikunja refresh
```

## Development

```sh
npm test                # model unit tests
omarchy plugin validate .
```

The model is pure, dependency-free ES modules (`model/*.mjs`) re-exported by
`Model.mjs`, tested with `node --test` against `Europe/London` time.
