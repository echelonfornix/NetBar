# Contributing

Thanks for taking a look at NetBar.

## Local Development

Build the app:

```sh
./scripts/build.sh
```

Run it:

```sh
open build/NetBar.app
```

Package a DMG:

```sh
./scripts/package_dmg.sh
```

## Code Style

- Keep the app native and lightweight.
- Prefer AppKit and standard macOS tools over large dependencies.
- Keep network collection local and transparent.
- Avoid aggressive network probing unless it is opt-in and clearly documented.
- Keep UI text short enough for small Menu Bar panels and cards.

## Testing Before a Pull Request

Run:

```sh
./scripts/build.sh
./scripts/package_dmg.sh
```

Then launch the app and check:

- Menu Bar item appears.
- Refresh works.
- Settings open.
- Network Map opens.
- DMG contains `NetBar.app` and an Applications shortcut.
