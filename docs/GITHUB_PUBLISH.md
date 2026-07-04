# GitHub Publishing

This project is ready to publish as a GitHub repository.

## Recommended Repository Settings

- Repository name: `NetBar`
- Visibility: public
- Default branch: `main`
- Licence: MIT
- Description: `A small macOS Menu Bar app that shows local network devices from the ARP table.`

## Push From This Mac

If GitHub CLI is installed and authenticated:

```sh
gh repo create NetBar --public --source=. --remote=origin --push
```

If you create the empty GitHub repository manually first, push with:

```sh
git remote add origin https://github.com/YOUR-USERNAME/NetBar.git
git push -u origin main
```

## Create a Release

Build and package:

```sh
./scripts/build.sh
./scripts/package_dmg.sh
```

Then create a GitHub release and attach:

```text
dist/NetBar.dmg
```

Suggested first release title:

```text
NetBar 0.2.0
```

Suggested release notes:

```markdown
Initial public release of NetBar.

- macOS Menu Bar network device list.
- Friendly names for devices.
- Optional MAC address display.
- Launch at login setting.
- Network Map view.
- Local-first ARP-based discovery.
```

## GitHub Actions

The repository includes `.github/workflows/build.yml`.

On push or pull request, GitHub Actions will:

- Build `NetBar.app` on macOS.
- Package `dist/NetBar.dmg`.
- Upload the DMG as a workflow artifact.
