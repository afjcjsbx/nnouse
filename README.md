# nnouse

`nnouse` is a lightweight macOS menu bar app that lets you control mouse targeting from the keyboard.

It overlays a labeled grid on every screen, lets you jump to a region by typing a short key sequence, and then performs a click either at the center of the selected cell or at a more precise sub-cell location.

## Features

- Global activation shortcut to show or hide the grid overlay
- Two-step keyboard targeting for fast mouse clicks
- Precision sub-grid for fine-grained targeting after selecting a main cell
- Continuous cursor movement with `Command` + arrow keys
- Menu bar UI with a built-in settings window
- Configurable grid size, opacity, shortcut, cursor movement speed, and label ordering
- Multi-monitor support

## How It Works

1. Launch the app.
2. Press the activation shortcut to display the grid. By default, this is `Option` + `Space`.
3. Type two characters to select a main grid cell.
4. After the main cell is selected, press `Space` to click the center of that cell, or type one more character to select a position inside the precision sub-grid and click there.
5. Press `Esc` to dismiss the overlay without clicking.

While the app is running, you can also hold `Command` + arrow keys to move the cursor continuously.

## Settings

The menu bar icon opens a settings window where you can adjust:

- Number of columns
- Number of rows
- Grid opacity
- Highlight opacity
- Cursor movement FPS
- Activation shortcut
- Cell label ordering mode

The app stores these settings with `UserDefaults`.

## Permissions

`nnouse` needs macOS Accessibility permission to listen for global keyboard input and to move/click the mouse.

If permission is missing, add the built app to:

`System Settings > Privacy & Security > Accessibility`

## Build and Run

1. Open `nnouse.xcodeproj`.
2. Select the `nnouse` target.
3. Build and run the app from Xcode.
4. Grant Accessibility permission when prompted or add it manually in System Settings.

The project has no external dependencies.

## Project Structure

- `nnouse/main.swift`: app entry point
- `nnouse/Core`: app lifecycle, configuration, and persisted settings
- `nnouse/Grid`: overlay windows, grid rendering, and hit geometry
- `nnouse/Mouse`: cursor movement and synthetic click handling
- `nnouse/UI`: status bar and settings window UI

## Notes

This project is currently source-first: open it in Xcode and run it locally to use it.
