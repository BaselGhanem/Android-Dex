# Basel Companion

Basel Companion is a personal Android companion for Basel Desktop Hub. Start
the local bridge in the app, enable notification access if wanted, and copy
the access code into the My Galaxy panel on the desktop. The desktop uses
ADB port forwarding; the phone server listens on its loopback address only.
The code is stored privately on the phone and is not stored by the desktop.
The service can be stopped from the app and is not restarted automatically.

The status snapshot contains the battery percentage, network type, and up to
50 current notifications if notification access is enabled. Treat the access
code as private because it grants access to that notification data. Media
buttons in the desktop app use Android media key events via ADB.

Build an installable debug APK with Android SDK 35, Java 17 and Gradle 8.9:
`gradle assembleDebug`. GitHub Actions also builds a debug APK as an
artifact. A debug APK is for testing; it is not a signed release.

The project is covered by the MIT license in the parent open-source folder.
