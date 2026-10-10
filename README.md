# FocusLight

A small macOS menu bar app that highlights the active window, making it easier to see where your keyboard input will go. Built with SwiftUI and AppKit.

This project is developed primarily for personal use.

## License

All rights reserved. FocusLight's original source code and documentation are not offered under an open-source license; see [LICENSE](LICENSE).

## Features

- Highlight the active window with a full border, an edge bar, or a pulsing corner dot.
- Customize color and opacity, width, padding, corner radius, and dot corner.
- Enable or disable highlighting from the menu bar.
- Save settings automatically to a TOML config file between launches.
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

Run the packaging script again, quit FocusLight, replace the app in Applications, and reopen it. Settings are stored in `~/.config/FocusLight/config.toml`, outside the app bundle.

After moving or rebuilding the app, macOS may require Accessibility access again. If highlighting stops, remove the old FocusLight entry from Accessibility settings, add the installed copy, enable it, and relaunch.

### Sharing the app

This packaging script is intended for local use. For public distribution outside the Mac App Store, use Developer ID signing and notarization; the local build does not include those steps. See [Apple's macOS distribution guide](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac).

## Configuration

FocusLight reads **`~/.config/FocusLight/config.toml`** on startup. It creates the directory and file if missing, carrying over your existing preferences from UserDefaults. Every setting change in the Settings window or menu bar immediately saves the current configuration with an atomic write.

To configure the app by hand, quit FocusLight, edit the file, and reopen the app. For example:

```toml
is_enabled = true
highlight_style = "border"
border_width = 4.0
padding = 0.0
corner_radius = 8.0
dot_corner = "topRight"
border_color = "#007AFFFF"
```

| Key | Allowed values |
| --- | --- |
| `is_enabled` | `true` or `false` |
| `highlight_style` | `"border"`, `"top"`, `"bottom"`, `"left"`, `"right"`, `"dot"` |
| `border_width` | 1–20 points; also controls dot size |
| `padding` | 0–24 points |
| `corner_radius` | 0–40 points |
| `dot_corner` | `"topLeft"`, `"topRight"`, `"bottomLeft"`, `"bottomRight"` |
| `border_color` | Quoted `#RRGGBB` or `#RRGGBBAA` hex color; `AA` controls opacity |

Missing keys use the defaults shown above. The supported TOML format is a flat list of these top-level keys, with booleans, decimal numbers, and unescaped single- or double-quoted strings. Blank lines and `#` comments are supported; tables and other keys are rejected. Changing settings in the app rewrites the file, replacing custom comments and formatting.

If the file has an invalid setting or cannot be read, FocusLight uses defaults and shows the error in Settings. It preserves the file and suspends saving until you fix it and restart the app. Save failures also appear in Settings and are retried on the next setting change.

## Development

Open `FocusLight.xcodeproj` in Xcode, select the shared **FocusLight** scheme, and run it on **My Mac**. The project includes Debug and Release configurations.

| File | Purpose |
| --- | --- |
| `FocusLightApp.swift` | App entry point, menu bar, and Settings scene |
| `AppDelegate.swift` | Highlighter lifecycle and Accessibility prompt |
| `WindowHighlighter.swift` | Tracks the active app and window through Accessibility events |
| `OverlayWindow.swift` | Draws the highlight in a transparent floating window |
| `AppSettings.swift` | Preferences and persistence |
| `SettingsConfiguration.swift` | TOML schema, serialization, and validation |
| `MenuBarView.swift` | Menu bar controls |
| `SettingsView.swift` | Appearance controls and permission status |

These Swift files are in `FocusLight/`. The shared Xcode scheme is committed; personal `xcuserdata`, editor settings, credentials, and generated build products are ignored.

## Troubleshooting

- **No highlight:** check Accessibility access, enable highlighting in the menu bar, then quit and reopen the app. The focused application must expose its window through the macOS Accessibility API.
- **No Dock icon:** this is expected; use the menu bar icon to open Settings or quit.
- **Two menu bar icons:** quit the Xcode-launched copy before running the installed app.

Run `bash scripts/test-settings.sh` to check config parsing, validation, migration, persistence, and error recovery. The checks use temporary files and isolated in-memory preferences, leaving your own configuration untouched.

To check the UI manually, switch between apps and windows, move and resize a window, try each highlight style, and verify that disabling highlighting hides the overlay.
