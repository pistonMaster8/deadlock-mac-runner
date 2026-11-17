# Native Wine Launchers Design

## Goal

Provide novice-friendly macOS applications for Steam, Deadlock, and Megabonk that launch the existing Wine runtime without duplicate Dock instances or orphaned Wine/Steam processes.

## Problem

The current Sikarugir bundle launches `steam.exe` through a detached `start` command, so the macOS wrapper does not own the process tree. Its installed `QuitScript` also exports `WINEPREFIX` to `Contents/Resources` instead of the active `Contents/SharedSupport/prefix`. Closing the wrapper therefore leaves `wineserver`, `steam.exe`, `steamservice.exe`, and helper processes alive. Reopening the runner creates another visible Steam instance and another process group.

## Architecture

Build one shared native Swift supervisor and three thin macOS application bundles:

- `Steam.app` launches or activates Wine Steam.
- `Deadlock.app` launches or activates Steam, then starts AppID `1422450`.
- `Megabonk.app` launches or activates Steam, then starts AppID `3405340`.

The apps share one runtime directory containing the existing Wine engine, Frameworks, and prefix. The supervisor owns a single session lock, launches all Wine processes with the correct prefix and dynamic-library path, tracks the session PID, and performs scoped cleanup. The apps use `LSMultipleInstancesProhibited` and the session lock to prevent duplicate launches.

## Process lifecycle

1. Resolve the shared runtime relative to the launcher bundle.
2. Acquire an exclusive session lock in the runtime directory.
3. If a matching session exists, activate the existing app/session instead of launching another Wine instance.
4. Start Wine Steam once.
5. For game launchers, request Steam AppID `1422450` or `3405340` through the existing Wine Steam process.
6. On normal quit, request game/Steam exit, wait for graceful termination, then run the runtime-scoped `wineserver -k` with the correct `WINEPREFIX`.
7. On crash or force termination, a watchdog detects the dead parent and performs the same scoped cleanup.

Cleanup MUST NOT kill native macOS Steam or unrelated Wine prefixes. It MUST remove stale lock state only after confirming the recorded PID is no longer alive.

## User experience

Each app has a normal Dock icon and supports:

- double-click launch from Finder/Dock;
- normal `Command-Q` quit;
- Dock Quit;
- reopening the same app without creating a second Steam/Wine session.

Steam.app is the session owner. Quitting Steam.app closes the shared Wine session and all games in that prefix. Quitting Deadlock.app or Megabonk.app closes only the selected game when possible; if the game is already gone, the app exits cleanly without touching unrelated native processes.

## Direct current-install fix

Before building the new bundles, patch the existing installed runner’s quit path to target:

```text
Contents/SharedSupport/prefix
```

The patch must preserve an original backup and use the same scoped cleanup routine as the new supervisor. This immediately removes the current duplicate Dock/orphan behavior.

## Files and interfaces

The source runner will gain a native launcher tool under `tools/native-launcher/`:

- `Package.swift` — macOS executable package.
- `Sources/WineSupervisor/SessionConfiguration.swift` — runtime paths, AppIDs, and bundle-relative resolution.
- `Sources/WineSupervisor/ProcessTree.swift` — process launch, PID tracking, graceful wait, and scoped cleanup.
- `Sources/WineSupervisor/SessionLock.swift` — single-instance lock and stale-lock recovery.
- `Sources/WineSupervisor/LauncherApp.swift` — NSApplication lifecycle, Dock behavior, activation, and termination handling.
- `Sources/WineSupervisor/main.swift` — command-line mode selection for Steam, Deadlock, or Megabonk.
- `scripts/build-native-launchers.sh` — builds three `.app` bundles and stages shared runtime links/resources.

The existing shell patcher remains responsible for repeatable Deadlock configuration edits; the native supervisor invokes it before Steam starts.

## Error handling

- Missing runtime: show a native alert with the exact missing path and the reinstall action.
- Existing session: activate it and do not spawn another Wine server.
- Steam launch failure: show the Wine command and exit status in a user-readable alert; release the lock.
- Game launch failure: keep Steam available, report the AppID and command, and leave cleanup to the session owner.
- Termination timeout: escalate from graceful close to scoped `wineserver -k`; never use global `killall Steam` or global `pkill wine`.

## Verification

Automated tests will cover:

- runtime path resolution from each app bundle;
- single-instance lock behavior and stale lock recovery;
- process-tree ownership and scoped cleanup command construction;
- correct AppID selection;
- current runner quit script using `SharedSupport/prefix`;
- generated Info.plist values and bundle names.

Smoke verification will launch Steam.app, confirm one Wine/Steam process group, launch one game app, close it, and confirm no prefix-owned processes remain. A second launch of the same app must activate the first session rather than create another Dock icon.

## Constraints

- Apple Silicon macOS only, matching the existing runner requirement.
- No third-party runtime dependency beyond the existing bundled Wine/Sikarugir runtime.
- No global process termination commands.
- Existing Steam userdata and Deadlock/Megabonk installations remain in the shared prefix.
- Native bundles are ad-hoc signed for local use and are not notarized.
