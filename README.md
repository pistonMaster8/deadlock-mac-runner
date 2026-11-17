# Deadlock Runner for Apple Silicon Macs

A community Wine wrapper that gets a friend from a DMG to the Windows Steam client with the compatibility settings that made Deadlock work on the original setup.

## Install

1. Download `Deadlock-Runner-macOS.dmg` and its `.sha256` file from the [latest release](https://github.com/pistonMaster8/deadlock-mac-runner/releases/latest).
2. Verify the download:

   ```sh
   shasum -a 256 -c Deadlock-Runner-macOS.dmg.sha256
   ```

3. Open the DMG and drag **Deadlock Runner.app** to **Applications**.
4. Control-click the installed app, choose **Open**, and approve the macOS warning.
5. Let the official Steam installer finish, sign in, and install Deadlock. Do not launch the game yet.
6. Quit Steam and the runner, then reopen Deadlock Runner so the game files and per-account settings receive their fixes.
7. Launch Deadlock from Steam.

Requirements: Apple Silicon, macOS 14.6 or newer, a Steam account with Deadlock access, and enough free storage for the game.

## What is preconfigured

- Wine Sikarugir 10.0 revision 6—the version verified on the original runner.
- ESYNC and MSYNC enabled; D3DMetal enabled for the DirectX 11 path; DXVK and D9VK disabled.
- Deadlock’s boot renderer changed from Vulkan to DirectX 11 after installation and updates.
- Conservative Mac video identifiers/defaults applied without replacing the display resolution.
- Xbox controller mapping revision 113 with the additional `TAB` binding alongside Ping.
- Controller glyph mode set to `2` when the per-account Deadlock configuration exists.
- Voice chat keeps the AirPods Max microphone, samples only while PTT is active, and moves voice processing out of the game process.

Every edit is repeatable and keeps a `.deadlock-runner.bak` copy of the original file.

## Privacy and content

The release contains no Steam account, login token, userdata, installed Steam library, Deadlock binary, or other game. First launch runs the official Valve Steam installer bundled during the release build. You provide your own Steam account and download Deadlock through Steam.

The build pipeline performs a privacy scan before creating the DMG. The DMG is published as a GitHub Release asset rather than stored in Git history.

## Troubleshooting

- **Black screen:** quit Steam and the runner, reopen the runner so it reapplies DirectX 11 and video settings, and start windowed before trying fullscreen.
- **Vulkan returns after an update:** quit and reopen the runner.
- **Controller labels or input are wrong:** reopen the runner, reconnect the controller, then launch Deadlock.
- **Steam setup stops:** close and reopen the app to retry.
- **macOS says the app is damaged:** verify the SHA-256 first, then follow the quarantine instructions in `INSTALL.txt`. The build is ad-hoc signed and is not Apple-notarized.

## Updating without losing Steam or Deadlock

Steam, Deadlock, and your local settings live inside `Deadlock Runner.app/Contents/SharedSupport/prefix`. Before replacing the app with a newer release, quit Steam and the runner, Control-click the old app, choose **Show Package Contents**, and copy that `prefix` folder somewhere safe. Install the new app, then replace its clean `prefix` folder with your backup before reopening Deadlock Runner. Keep the backup until Steam and Deadlock both launch successfully.

## Build locally

The build uses macOS system tools plus `rsync` and `curl`:

```sh
scripts/build-app.sh "/path/to/Sikarugir Runner.app" build
scripts/build-dmg.sh "build/Deadlock Runner.app" dist
zsh tests/test.sh
```

The source wrapper must already contain the Wine Sikarugir 10.0 revision 6 engine and its third-party license files. Generated apps and DMGs are ignored by Git.

## Legal

This project is not affiliated with Valve, Steam, Deadlock, Apple, Wine, or Sikarugir. Steam and Deadlock are trademarks of Valve Corporation. The project scripts and documentation are MIT licensed; bundled third-party components retain their own licenses.
