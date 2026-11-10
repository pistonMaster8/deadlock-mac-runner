# Deadlock Mac Runner Distribution Design

## Intent

Package the working local Sikarugir/Wine configuration as a friend-friendly macOS disk image and publish a small GitHub project page. The friend should do as little as possible: drag one app to Applications, open it, sign in to Steam, install Deadlock, and play.

## Goals

- Ship a compressed DMG containing a self-contained `Deadlock Runner.app`.
- Start from the known-working Wine Sikarugir 10.0 revision 6 engine and wrapper settings.
- Install Steam from Valve's official installer on first launch, then launch Steam normally.
- Reapply the known Deadlock compatibility changes after Steam/game updates.
- Keep the user's Steam account, tokens, userdata, installed games, caches, and personal settings out of the artifact.
- Publish source, checksums, setup instructions, troubleshooting, and configuration notes through a public GitHub repository with Pages enabled.

## Non-goals

- Bundle Deadlock or any other Steam game.
- Bundle a logged-in or preconfigured personal Steam account.
- Sign or notarize with an Apple Developer ID that is not available locally.
- Promise compatibility with Intel Macs, macOS versions older than 14.6, or every controller/display.

## Distribution Architecture

The build script copies only the reusable wrapper, Wine engine, frameworks, and license files from the existing runner. It creates a clean Wine prefix, downloads Valve's current Steam installer, installs a first-run Windows bootstrap command, updates the wrapper identity, and produces a compressed DMG with an Applications shortcut and a short install guide.

The wrapper launches the bootstrap command. On first launch it silently starts the official Steam installer and then Steam; on later launches it starts the installed Steam client. A native startup script runs before Wine and idempotently applies Deadlock-specific changes whenever the game files or per-account configuration exist.

## Preserved Compatibility Configuration

- Engine: `wine sikarugir 10.0 (revision 6)`; do not use the locally backed-up 11.0 revision 1 engine.
- macOS floor: 14.6.
- Wrapper: D9VK enabled; DXVK and D3DMetal disabled; ESYNC and MSYNC enabled; GPU probing disabled.
- Wine Mac driver: Command maps to Control and Option maps to Alt on both sides.
- Deadlock renderer: `game/citadel/cfg/boot.vcfg` defaults to `-dx11`, replacing Vulkan.
- First-run video guidance: windowed/borderless, conservative graphics, Apple vendor ID 4203, device ID 0, and GPU memory level 3 if the account config exists.
- Controller fix: preserve the Xbox mapping revision bump to 113 and the added `TAB` binding alongside Ping; set `steam_inputhandler_glyph_lock_mode` to `2` when the per-user config exists.
- The fixes must be repeatable and create backups before changing game-owned or user-owned files.

## Privacy and Licensing Constraints

- The build must fail if staged output contains Steam login/config/userdata, app tickets, account IDs, Steam libraries, Deadlock binaries, or other installed games.
- Steam is obtained at build time from Valve's official download URL; the project does not commit or redistribute account data or game content.
- Preserve all third-party license files already present in the wrapper.
- Publish the generated DMG as a release asset rather than committing it to Git history.

## Verification

- Automated tests validate staging exclusions, app metadata, bootstrap behavior, idempotent configuration patching, privacy scanning, and DMG contents.
- The final artifact is mounted and inspected, checksummed, and Gatekeeper/codesign status is documented accurately.
- A clean-prefix smoke test must confirm that the runner reaches the Steam setup/login flow without relying on the original 53 GB prefix.

## Builder Calls

- Public GitHub repository and Pages site are the default because the artifact is intended for a friend without an agent.
- The project will use shell scripts and macOS system tools (`rsync`, `plutil`, `hdiutil`, `codesign`) to avoid requiring a development toolchain.
- Native execution in this session is selected because the user asked for the least-work path.
