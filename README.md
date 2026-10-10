# FocusLight

A small macOS menu bar app that highlights the active window, making it easier to see where your keyboard input will go. Built with SwiftUI and AppKit.

## Features

- Highlight the active window with a full border, an edge bar, or a pulsing corner dot.
- Customize color and opacity, width, padding, corner radius, and dot corner.
- Enable or disable highlighting from the menu bar.
- Save preferences automatically between launches.
- Use a transparent overlay that lets mouse clicks pass through.

FocusLight runs in the menu bar, with no Dock icon or regular main window.

## Requirements

- macOS 14 Sonoma or later.
- Xcode 15 or later to build, with its command line tools selected. Xcode is not needed to run the built app.
- Accessibility permission to read the active window's position and size.

There are no third-party dependencies.

## Build a standalone app

From the project directory, run:

```sh
./scripts/package-app.sh
```

The script builds an optimized Release version for Apple silicon and Intel, signs it ad hoc for local use, and verifies the signature. The result is **`dist/FocusLight.app`**. Intermediate build files go into `build/`; both directories are ignored by Git. No Apple Developer account is required for this local build.

If the command reports that Xcode is not selected, open **Xcode → Settings → Locations** and select your installed Xcode under **Command Line Tools**.

### Install and launch

1. Quit any running copy of FocusLight, including one started from Xcode.
2. In Finder, drag `dist/FocusLight.app` into **Applications** (or `~/Applications` for a per-user installation).
3. Double-click the installed app. From now on, launch it from Applications or Spotlight without opening Xcode.
4. In **System Settings → Privacy & Security → Accessibility**, enable the installed FocusLight app. If it is missing, use **+** to add it from Applications. See [Apple's Accessibility permission guide](https://support.apple.com/guide/mac-help/allow-accessibility-apps-to-access-your-mac-mh43185/mac).
5. Quit and reopen FocusLight after granting permission.

Look for the dashed rectangle icon in the menu bar. Its menu contains **Enable Highlighting**, **Settings**, and **Quit FocusLight**.

To start it automatically when you log in, add the installed app to **Open at Login** in **System Settings → General → Login Items** (called **Login Items & Extensions** on newer macOS versions). See [Apple's login items guide](https://support.apple.com/en-au/guide/mac-help/-mtusr003/mac).

### Updating your local copy

Run the packaging script again, quit FocusLight, replace the app in Applications, and reopen it. Preferences are stored in macOS UserDefaults under `com.focuslight.app`, outside the app bundle.

After moving or rebuilding the app, macOS may require Accessibility access again. If highlighting stops, remove the old FocusLight entry from Accessibility settings, add the installed copy, enable it, and relaunch.

### Sharing the app

This packaging script is intended for local use. For public distribution outside the Mac App Store, use Developer ID signing and notarization; the local build does not include those steps. See [Apple's macOS distribution guide](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac).

## Development

Open `FocusLight.xcodeproj` in Xcode, select the shared **FocusLight** scheme, and run it on **My Mac**. The project includes Debug and Release configurations.

| File | Purpose |
| --- | --- |
| `FocusLightApp.swift` | App entry point, menu bar, and Settings scene |
| `AppDelegate.swift` | Highlighter lifecycle and Accessibility prompt |
| `WindowHighlighter.swift` | Tracks the active app and window through Accessibility events |
| `OverlayWindow.swift` | Draws the highlight in a transparent floating window |
| `AppSettings.swift` | Preferences and persistence |
| `MenuBarView.swift` | Menu bar controls |
| `SettingsView.swift` | Appearance controls and permission status |

These Swift files are in `FocusLight/`. The shared Xcode scheme is committed; personal `xcuserdata`, editor settings, credentials, and generated build products are ignored.

## Troubleshooting

- **No highlight:** check Accessibility access, enable highlighting in the menu bar, then quit and reopen the app. The focused application must expose its window through the macOS Accessibility API.
- **No Dock icon:** this is expected; use the menu bar icon to open Settings or quit.
- **Two menu bar icons:** quit the Xcode-launched copy before running the installed app.

The project currently has no automated test target. To check a build manually, switch between apps and windows, move and resize a window, try each highlight style, and verify that disabling highlighting hides the overlay.
