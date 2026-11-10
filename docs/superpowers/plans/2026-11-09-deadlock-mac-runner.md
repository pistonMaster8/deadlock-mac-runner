# Deadlock Mac Runner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and publish a sanitized, one-app Deadlock Wine runner DMG with Steam bootstrap and reproducible compatibility fixes.

**Architecture:** A tested shell build pipeline copies the reusable local wrapper, creates a clean prefix, installs a first-run bootstrap, applies idempotent Deadlock fixes at startup, scans for private/proprietary content, and creates a compressed DMG. Static GitHub Pages documentation explains the remaining Steam sign-in/install steps and the exact compatibility configuration.

**Tech Stack:** POSIX shell, zsh test harness, macOS `plutil`/`hdiutil`/`codesign`, Sikarugir Wine, GitHub CLI/Pages.

**Spec:** `docs/superpowers/specs/2026-11-09-deadlock-mac-runner-design.md`

## Global Constraints

- Source wrapper is `/Users/desmond.webb/Applications/Sikarugir/Megabonk Runner.app`.
- Preserve Wine Sikarugir 10.0 revision 6 and macOS 14.6 minimum.
- Never stage Steam accounts, tokens, userdata, installed Steam applications, or Deadlock game binaries.
- Download SteamSetup only from Valve's official HTTPS endpoint.
- The final app remains ad-hoc signed unless a Developer ID is explicitly provided.

## Review Focus

- A source path containing spaces must build correctly.
- Running configuration patching repeatedly must not duplicate bindings or corrupt VDF/VCFG files.
- Missing Steam or Deadlock files must be treated as normal first-run state.
- Privacy scanning must catch known Steam credential/account artifacts before DMG creation.
- The mounted DMG must contain exactly the app, Applications link, and install guide.

---

### Task 1: Test Harness and Configuration Patcher

**Files:**
- Create: `tests/test.sh`
- Create: `scripts/apply-deadlock-fixes.sh`
- Create: `fixtures/video-safe.txt`

**Interfaces:**
- Consumes: `WINEPREFIX` and an optional `DEADLOCK_ROOT`.
- Produces: idempotently patched boot renderer, controller mapping, and per-user config files with `.deadlock-runner.bak` backups.

- [ ] Write failing fixture tests for missing files, DX11 boot selection, single TAB binding, glyph mode 2, safe video defaults, and a second identical run.
- [ ] Run `zsh tests/test.sh` and confirm the patcher tests fail.
- [ ] Implement `scripts/apply-deadlock-fixes.sh` with path discovery and atomic edits.
- [ ] Run `zsh tests/test.sh` and confirm the patcher tests pass.

### Task 2: Reproducible App Builder and Privacy Gate

**Files:**
- Create: `scripts/build-app.sh`
- Create: `scripts/scan-private-data.sh`
- Create: `app/bootstrap.cmd`
- Modify: `tests/test.sh`

**Interfaces:**
- Consumes: source wrapper path and output directory.
- Produces: sanitized `Deadlock Runner.app`; exits nonzero if staged private/proprietary content is detected.

- [ ] Add failing tests for wrapper exclusions, renamed metadata, bootstrap branches, preserved engine version, and scanner detections.
- [ ] Implement a dry-run fixture mode and privacy scanner.
- [ ] Implement wrapper staging, clean-prefix creation, Valve SteamSetup download, metadata updates, startup patcher installation, and ad-hoc signing.
- [ ] Run `zsh tests/test.sh` and confirm all tests pass.

### Task 3: DMG, Documentation, and Release Metadata

**Files:**
- Create: `scripts/build-dmg.sh`
- Create: `README.md`
- Create: `docs/index.html`
- Create: `docs/styles.css`
- Create: `INSTALL.txt`
- Create: `LICENSE`
- Modify: `tests/test.sh`

**Interfaces:**
- Consumes: sanitized app bundle.
- Produces: compressed DMG, SHA-256 file, and static GitHub Pages content.

- [ ] Add failing tests for DMG staging contents, documentation requirements, and checksum format.
- [ ] Implement the DMG builder with Applications symlink and install guide.
- [ ] Write concise install, first launch, Deadlock setup, Gatekeeper, controller, update, and troubleshooting documentation.
- [ ] Run the full test suite.

### Task 4: Build and End-to-End Verification

**Files:**
- Create: `dist/Deadlock-Runner-macOS.dmg`
- Create: `dist/Deadlock-Runner-macOS.dmg.sha256`

**Interfaces:**
- Consumes: Tasks 1-3.
- Produces: inspected distributable artifact.

- [ ] Build the app from the live source wrapper without its current prefix or backup engine.
- [ ] Run the privacy scan and inspect staged size/content.
- [ ] Build, mount, inspect, and unmount the DMG.
- [ ] Run `codesign --verify --deep --strict` and record Gatekeeper status.
- [ ] Smoke-test the clean app through the Steam setup/login boundary.

### Task 5: GitHub Repository, Pages, and Release

**Files:**
- Modify: repository metadata only.

**Interfaces:**
- Consumes: verified source, site, DMG, and checksum.
- Produces: public repository, enabled Pages site, and release with downloadable DMG.

- [ ] Initialize Git, review tracked files for secrets/large binaries, and commit source/docs.
- [ ] Create the public GitHub repository and push the main branch.
- [ ] Enable Pages from `/docs` on `main`.
- [ ] Create a versioned release and upload the DMG and checksum.
- [ ] Verify the repository, Pages URL, release asset, and checksum download.
