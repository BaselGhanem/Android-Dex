# Basel Desktop Hub — Flutter Windows app

An **independent, MIT-licensed Flutter project** for managing your Android phone from Windows. This is **not** Android DEX, and does not contain its closed-source application code.

## Features in v0.4 source

- Dark premium interface using teal #099999
- Discover and select authorized USB/ADB devices
- Read Android battery level
- List, filter and launch installed third-party Android apps
- Open whole-phone screen mirrors via scrcpy
- Open apps in separate Android virtual displays via scrcpy --new-display and --start-app
- Track windows and close sessions individually; show immediate launch errors
- Capture screenshots to Pictures/BaselDesktopHub
- Push local files to Android Downloads
- Home, Back, Recents, Power button commands
- Connect to already configured ADB over Wi-Fi TCP endpoints

## Your personal desktop (v0.4)

The existing dark/teal design is unchanged. Open **My Desktop** from the sidebar (or its taskbar icon). Copy is tailored to three independent work modes:

- **Sales Desk:** "From raw numbers to decisions that matter."
- **X Academy:** "Learn. Analyse. Lead." — training studio
- **Build Lab:** development and systems

Each workspace has its own:
- Pinned apps in the **App Drawer**
- Saved Android app window positions, including a second monitor
- A Restore Layout command
- A Save Positions command (reads the current Windows window rectangles)

At the bottom of the main hub, a **taskbar** lists active virtual-display windows and lets you focus them. The workspace lets you close windows, arrange them left/right/full/center on a selected screen, and automatically distribute running windows across all detected Windows monitors.

Your preferences are stored only on your own PC in:

    %APPDATA%\BaselDesktopHub\workspaces.json

They are **not** synced to the cloud and do not store your Android app content.

### Two-screen workflow

1. Connect your Samsung phone using USB debugging.
2. Open **My Desktop** and click **Load apps** in the App Drawer.
3. Pin the apps you actually use in Sales Desk, X Academy or Build Lab.
4. Launch them in virtual-display windows.
5. Use **Auto arrange across screens**, or pick a target monitor and Left/Right/Fill/Center for each running window.
6. Move any scrcpy window manually if needed and click **Save positions**.
7. Later choose the same workspace and select **Restore layout**.

Monitor locations are discovered from Windows, including negative coordinates for screens placed to the left of the main display. If a monitor is disconnected, saved positions that are off-screen fall back to a centered window on a connected screen.

Windows move/focus/read operations use local PowerShell and Win32 APIs; no external services and no additional Flutter plugins. Windows desktop scaling and device compatibility must be tested on your actual dual-monitor setup. Windows is the only supported OS for native window management in v0.4.

### Status and limitations

This project **launches** native scrcpy windows; it does not embed their rendering inside Flutter or replace the Windows shell. The taskbar is an in-app control bar, not a replacement for the system taskbar. App Drawer displays package-derived labels and symbolic icons, not extracted official Android application icons. Multiple sessions of the same package do not guarantee Android will create independent instances.

scrcpy versions supporting \`--flex-display\` and \`--no-vd-destroy-content\` will use those options automatically. Where available, the latter avoids destroying Android activity content just because the virtual display closes, but individual apps may still restart due to Android lifecycle handling.

## Not yet implemented

App-specific audio routing, game controls, Android notifications, automatic wireless pairing, automatic reconnection, extraction of real APK launcher icons, and installer packaging. Virtual display compatibility depends on Android firmware and each app.

## Windows installation

1. Install Flutter SDK and Visual Studio with the Desktop development with C++ workload.
2. Install Android SDK Platform Tools (ADB): https://developer.android.com/tools/releases/platform-tools
3. Install scrcpy: https://github.com/Genymobile/scrcpy
4. Add adb and scrcpy to the Windows PATH. Independent windows require scrcpy 3.0+ with --new-display and --start-app support.
5. Clone this repository and checkout the basel-open-source-mvp branch.
6. Open PowerShell in open-source/flutter_hub.
7. Execute these commands:

    flutter create --platforms=windows --project-name basel_desktop_hub .
    flutter pub get
    flutter test
    flutter run -d windows

To generate a Windows release build:

    flutter build windows --release

The generated Windows runner is provided by Flutter during the flutter create step; it is not committed in this folder.

## Independent windows test on Galaxy A56

1. Connect the Galaxy A56 over USB and approve USB debugging.
2. In Applications, select an app, then click Open independent app window.
3. Repeat with another app. App Windows lists each separately and provides a Close action.
4. If a session fails, check its diagnostic message. To isolate device restrictions, test scrcpy directly in PowerShell:

    scrcpy -s DEVICE_SERIAL --new-display=1280x800 --start-app=com.android.settings

Replace DEVICE_SERIAL with the serial shown by adb devices.

Each window is a separate scrcpy Windows process with its own Android virtual display, not an embedded Flutter widget. Some apps or OEM firmware may reject secondary-display launches. Closing a virtual display ordinarily destroys its Android content. Device-side rendering may affect performance.

## Android phone setup

Enable Developer Options and USB Debugging on the phone. Connect a USB cable and approve the computer's authorization prompt. Start the Flutter app and click Refresh. Wi-Fi connection requires a previously enabled ADB TCP endpoint; Android 11+ wireless pairing is not implemented.

## Code architecture

- lib/main.dart: responsive desktop dashboard, app list and device controls
- lib/android_bridge.dart: Android Debug Bridge and screen mirroring integration
- lib/virtual_window_manager.dart: virtual display sessions, window placement and lifecycle
- lib/desktop_layout.dart: Windows monitor geometry, native move/focus/read operations
- lib/workspace_store.dart: local per-workspace favorites and saved layouts
- lib/my_desktop.dart: personalized workspaces, in-app taskbar, App Drawer and dual-screen controls
- test/desktop_layout_test.dart: unit tests for placement arithmetic and negative screen coordinates
- pubspec.yaml: Flutter project configuration

## Security and licensing

No proprietary Android DEX application code is included in this Flutter folder. The MIT license in the sibling open-source folder covers original work only. This GitHub repository is still a fork with pre-existing proprietary material; it cannot be described as entirely open-source. For a completely MIT-licensed public project, publish the Flutter files in a separate clean-history repository.

ADB authorizes powerful control over a device. Do not enable debugging for unknown computers, and do not expose ADB TCP endpoints to public networks.

## Verification

The code has been committed to GitHub, but has **not been compiled, launched or device-tested** in a Windows Flutter environment during this session. Treat this as a development build until tested locally.
