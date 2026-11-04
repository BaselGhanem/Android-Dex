# Basel Desktop Hub — open-source project

This directory contains **original, independently written source code** for managing Android devices from a Windows desktop. It is not a redistribution, copy, or modification of proprietary Android DEX software.

## Recommended: Flutter desktop client v0.4

See **[flutter_hub/README.md](flutter_hub/README.md)** for Windows prerequisites, build commands, and the detailed feature list.

### Your personalized workspaces
- **Sales Desk:** Data-to-decision workspace
- **X Academy:** Learn. Analyse. Lead.
- **Build Lab:** Developer workspace

The Flutter client offers virtual Android app windows, an in-app taskbar, an App Drawer with local favorites, multiple monitor detection, window placement and persistence, and one-click layout restore.

Its existing dark/teal interface is retained. App window rendering is performed by scrcpy, while ADB handles Android commands. Actual compatibility on a Galaxy A56, especially multiple virtual displays and Windows multi-monitor positioning, requires hardware testing.

## Legacy Python prototype

`desktop_hub.py` is the older experimental Python/Tkinter application. **New development should use `flutter_hub`**, not the Python prototype.

## Licensing

Original files in this directory and its Flutter subdirectory are MIT licensed. The parent GitHub repository is still a fork carrying proprietary Android DEX materials under a different license. The entire fork cannot be relicensed as MIT. Publish the original open-source folder to a separate fresh repository when preparing a clean public distribution.

## Verification

Flutter Windows analysis, unit tests and compilation are configured in the repository workflow. A successful CI result and real-device test have not yet been verified in this chat.
