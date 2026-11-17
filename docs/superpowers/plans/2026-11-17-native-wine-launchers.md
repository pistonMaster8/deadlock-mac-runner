# Native Wine Launchers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build novice-friendly native macOS Steam, Deadlock, and Megabonk launchers around one shared Wine session supervisor with deterministic cleanup.

**Architecture:** A Swift AppKit supervisor owns one shared Wine prefix session. Three thin `.app` bundles pass `steam`, `deadlock`, or `megabonk` mode to the supervisor. A lock file prevents duplicate sessions; a watchdog and corrected wineserver path clean orphaned processes.

**Tech Stack:** Swift 5.9/AppKit, Foundation `Process`, POSIX `flock`, shell packaging, existing Sikarugir Wine runtime.

**Spec:** `docs/superpowers/specs/2026-11-17-native-wine-launchers-design.md`

## Global Constraints

- Apple Silicon macOS only.
- Use the existing bundled Wine/Sikarugir runtime; add no third-party runtime dependency.
- Scope cleanup to the shared prefix; never kill global native Steam or unrelated Wine prefixes.
- Preserve current Steam userdata, Deadlock, and Megabonk installations.
- Build local ad-hoc signed app bundles only.
- Keep current `scripts/test.sh` passing.

---

### Task 1: Add lifecycle tests and Swift package skeleton

**Files:**
- Create: `tools/native-launcher/Package.swift`
- Create: `tools/native-launcher/Tests/WineSupervisorTests/SessionConfigurationTests.swift`
- Create: `tools/native-launcher/Tests/WineSupervisorTests/SessionLockTests.swift`
- Create: `tools/native-launcher/Tests/WineSupervisorTests/ProcessTreeTests.swift`

**Interfaces:**
- Tests define the required public interfaces for `RuntimeLayout`, `LaunchMode`, `SessionLock`, and `CleanupPlan` before implementation.

- [ ] Write failing tests for bundle-relative runtime resolution, AppID mapping, stale lock recovery, and scoped cleanup command construction.
- [ ] Run `swift test` and confirm the tests fail because the source types are absent.

### Task 2: Implement runtime layout and safe process planning

**Files:**
- Create: `tools/native-launcher/Sources/WineSupervisor/SessionConfiguration.swift`
- Create: `tools/native-launcher/Sources/WineSupervisor/ProcessTree.swift`

**Interfaces:**
- `enum LaunchMode: String { case steam, deadlock, megabonk }`
- `struct RuntimeLayout { init(bundleURL: URL) throws; let prefixURL: URL; let wineURL: URL; let frameworksURL: URL; let steamWindowsPath: String; func appID(for mode: LaunchMode) -> String? }`
- `struct CleanupPlan { let prefixURL: URL; let wineserverURL: URL; let environment: [String:String]; let trackedPIDs: [Int32] }`
- `func buildCleanupPlan(layout: RuntimeLayout, trackedPIDs: [Int32]) -> CleanupPlan`

- [ ] Implement relative layout resolution for a launcher bundle beside `Wine Runtime.app` or `Megabonk Runner.app`.
- [ ] Reject missing Wine, prefix, or Steam executable paths with typed errors.
- [ ] Generate cleanup commands with the correct `WINEPREFIX`, `DYLD_LIBRARY_PATH`, and bundled wineserver only.
- [ ] Run focused Swift tests to confirm path and command invariants.

### Task 3: Implement single-instance lock and watchdog

**Files:**
- Create: `tools/native-launcher/Sources/WineSupervisor/SessionLock.swift`
- Modify: `tools/native-launcher/Tests/WineSupervisorTests/SessionLockTests.swift`

**Interfaces:**
- `final class SessionLock { init(url: URL); func acquire() throws; func release(); var isOwner: Bool { get } }`
- `struct SessionRecord: Codable { let pid: Int32; let mode: LaunchMode; let startedAt: Date }`

- [ ] Implement exclusive lock acquisition with a lock file under the shared runtime directory.
- [ ] Store owner PID and mode in a sidecar JSON record.
- [ ] Treat a record as stale only when its PID is absent or dead.
- [ ] Add a parent-death watchdog that invokes scoped cleanup when the supervisor loses its parent.
- [ ] Run focused lock tests, including a second-process refusal and stale record recovery.

### Task 4: Implement AppKit supervisor lifecycle

**Files:**
- Create: `tools/native-launcher/Sources/WineSupervisor/LauncherApp.swift`
- Create: `tools/native-launcher/Sources/WineSupervisor/main.swift`
- Modify: `tools/native-launcher/Tests/WineSupervisorTests/ProcessTreeTests.swift`

**Interfaces:**
- `final class LauncherController: NSObject, NSApplicationDelegate { init(mode: LaunchMode, bundleURL: URL); func launch() throws; func terminate() }`
- `func launchSteam(layout: RuntimeLayout) throws -> Process`
- `func launchGame(mode: LaunchMode, layout: RuntimeLayout) throws -> Process`

- [ ] Implement `NSApplication` lifecycle with one visible native Dock app per bundle.
- [ ] Set `LSMultipleInstancesProhibited` in generated Info.plist files.
- [ ] Launch Wine Steam with the exact environment used by the existing runner.
- [ ] Launch Deadlock AppID `1422450` and Megabonk AppID `3405340` through Steam after the session is ready.
- [ ] Activate the existing owner when a second launcher opens instead of spawning another process tree.
- [ ] On normal termination, request graceful exit, wait with a bounded timeout, then run scoped wineserver cleanup.
- [ ] Run focused Swift tests and compile the executable.

### Task 5: Fix the existing runner shutdown path

**Files:**
- Modify: `app/StartupScript`
- Create: `app/QuitScript`
- Modify: `scripts/build-app.sh`
- Modify: `tests/test.sh`

**Interfaces:**
- `app/QuitScript` exports `WINEPREFIX=$CONTENTSFOLD/SharedSupport/prefix` and runs the bundled wineserver cleanup.

- [ ] Add a failing shell test that asserts generated/current QuitScript uses `SharedSupport/prefix`, not `Contents/Resources`.
- [ ] Implement the corrected QuitScript with a backup-safe scoped cleanup path.
- [ ] Stage QuitScript from `build-app.sh` and make it executable.
- [ ] Run the shell regression suite.

### Task 6: Build three native application bundles

**Files:**
- Create: `scripts/build-native-launchers.sh`
- Create: `tools/native-launcher/Resources/Steam/Info.plist`
- Create: `tools/native-launcher/Resources/Deadlock/Info.plist`
- Create: `tools/native-launcher/Resources/Megabonk/Info.plist`
- Modify: `README.md`

**Interfaces:**
- Script usage: `scripts/build-native-launchers.sh <runtime-app> <output-dir>`
- Output: `<output-dir>/Steam.app`, `<output-dir>/Deadlock.app`, `<output-dir>/Megabonk.app`

- [ ] Stage one compiled supervisor executable into each bundle.
- [ ] Set bundle names, identifiers, icons, `LSMultipleInstancesProhibited`, and mode arguments.
- [ ] Link or copy the shared runtime beside the apps without duplicating the prefix.
- [ ] Ad-hoc sign each app bundle.
- [ ] Document novice launch/quit behavior and the output directory.
- [ ] Add shell tests for generated bundle metadata and mode arguments.

### Task 7: Run full verification and package current apps

**Files:**
- Modify: `docs/index.html` only if user-facing setup instructions need synchronization.

- [ ] Run `swift test`.
- [ ] Run `zsh tests/test.sh`.
- [ ] Build the three native app bundles from the current runner runtime.
- [ ] Smoke launch Steam.app and confirm one Wine/Steam process group.
- [ ] Open Steam.app a second time and confirm no second wineserver/Steam process appears.
- [ ] Launch Deadlock.app and Megabonk.app, then close each and verify scoped process cleanup.
- [ ] Quit Steam.app and verify no prefix-owned `steam.exe`, `steamservice.exe`, `steamwebhelper.exe`, or wineserver remains.
- [ ] Report any runtime limitation instead of claiming in-game behavior that was not observed.
