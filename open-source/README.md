# Basel Desktop Hub — independent open-source MVP

An independently developed desktop controller for Android devices on Windows, inspired by the general concept of integrating Android and desktop workflows. **This is not Android DEX, is not affiliated with its author, and contains no original Android DEX application code.**

## Current functionality
- Detect USB- or Wi-Fi-connected authorized Android devices
- Select an attached device
- Connect to an already configured ADB-over-TCP endpoint
- List, filter, and launch third-party Android packages
- Mirror and control the selected device via scrcpy
- Capture PNG screenshots
- Push a local file into the Android Download folder

**Important:** The current "Open app window" button launches the selected app and opens a *whole-device mirror*, not a separately rendered virtual-display app window. True per-app multi-window, audio routing, gaming profiles, notification synchronization, and reconnect automation are planned but not implemented.

## Requirements
- Windows 10 or 11
- Python 3.10+ with Tkinter
- [Android SDK Platform Tools (ADB)](https://developer.android.com/tools/releases/platform-tools) installed and added to PATH
- [scrcpy](https://github.com/Genymobile/scrcpy) installed and added to PATH
- Android device with Developer options and USB debugging enabled

## Run
From the repository root:

~~~powershell
python .\open-source\desktop_hub.py
~~~

1. On the phone, enable **Developer options → USB debugging**.
2. Connect by USB and approve the authorization prompt.
3. Press **Refresh** and select the device.
4. Press **Load Apps**, select a package, then **Launch selected app** or **Open app window**.
5. Press **Mirror Screen** to interact with the device using mouse and keyboard.

### Wi-Fi
The Wi-Fi field connects to an **already enabled** ADB-over-TCP IP:port endpoint. Android 11+ wireless debugging pairing is **not implemented** in this MVP. You may use USB for the initial setup. Do not expose ADB ports to the public internet.

## Security
- All ADB commands use Python subprocess argument arrays, not shell string interpolation.
- Package identifiers and wireless connection addresses are validated.
- Commands are sent only to a selected authorized connected device.
- Do not enable USB debugging on untrusted PCs.
- Network traffic is not encrypted merely because ADB is used; follow Android's pairing and network guidance.

## Open-source boundaries
All original code in this folder is licensed under the MIT license in [LICENSE](LICENSE). This license **does not apply** to other files in the repository, including the existing proprietary Android DEX materials. The source history of this fork still contains those materials; for a clean independent distribution, move this folder into a fresh repository with its own history and branding.

External ADB and scrcpy binaries are **not bundled** here. Their original licenses remain in force.

## Roadmap
1. App icons and friendly app names; improved device diagnostics
2. Persisted profiles and window layouts
3. Android 11+ wireless debugging pairing, reconnection
4. Per-app virtual displays where Android supports them, without implying universal compatibility
5. Optional Android companion for notifications and media data, with explicit permission controls
