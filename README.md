# Blackout

Blackout is a lightweight, performant utility addon for Windower 4 (Final Fantasy XI) designed to prevent screen burn-in (especially on OLED monitors) and manage your game client when you step away from the keyboard.

## Features

- **Screen Saver Overlay** (Default: 5 minutes idle): Displays a solid black full-screen overlay to act as a screensaver.
  - *Note for Multiboxers*: After 10 minutes of inactivity, the client will automatically minimize. **Note that the `switchfocus` addon (and other focus-switching utilities) cannot target or switch focus to clients that are minimized.** Multiboxers can turn off auto-minimization on their accounts/clients via `//blackout minimize off` to prevent this.
- **FPS Display Toggle**: Automatically hides the FFXI FPS display when active and restores it on wake up, ensuring a completely black screen.
- **Auto-Minimize** (Default: 10 minutes idle): Automatically minimizes the FFXI client window to the Windows taskbar using Windower's built-in minimization command.
- **Configurable Background Alpha**: Customize the screensaver overlay opacity from 0 (fully transparent) to 255 (completely black).
- **Smart Inactivity Detection**:
  - Resets idle timers upon any keyboard input or mouse movement.
  - Monitors character coordinates ($X$, $Y$, $Z$) and camera-facing direction. Auto-running, getting moved, or panning the camera will keep you marked as active (perfect for gamepad users).
  - Automatically halts idle timers if you are in combat or dead, preventing the screensaver from activating during critical moments.
  - Designed for near-zero performance overhead (dynamic polling intervals that check state only when inactive or on prerender frames when overlay is active for instant wakeup).

## Commands

Use `//blackout` or `//bo` in the game chat log.

| Command | Description | Default |
| --- | --- | --- |
| `//blackout` or `//blackout toggle` | Manually activate/deactivate the screensaver overlay. | - |
| `//blackout on` | Manually activate the screensaver. | - |
| `//blackout off` | Manually deactivate the screensaver. | - |
| `//blackout auto [on\|off]` | Enable or disable the automatic idle screensaver. | `on` |
| `//blackout timeout [seconds]` | Set/view the inactivity timeout before screensaver starts. | `300` (5 mins) |
| `//blackout minimize [on\|off]` | Enable or disable automatic client minimization on idle timeout. | `on` |
| `//blackout minimizetimeout [seconds]` | Set/view the inactivity timeout before client minimizes. | `600` (10 mins) |
| `//blackout alpha [0-255]` | Set screensaver background opacity/transparency. | `255` |
| `//blackout combat [on\|off]` | Enable/disable screensaver and minimization when engaged in combat. | `on` (disabled in combat) |
| `//blackout dead [on\|off]` | Enable/disable screensaver and minimization when dead. | `on` (disabled when dead) |
| `//blackout fps [on\|off]` | Enable/disable automatic FPS display toggle when screensaving. | `on` |
| `//blackout status` | Display current settings and state in the chat window. | - |
| `//blackout help` | Show the command help menu. | - |

## Installation

1. Download or clone this repository.
2. Move the folder to your Windower `addons` directory (usually located at `C:\Program Files (x86)\Windower4\addons\`).
3. Ensure the folder is named exactly **`blackout`** (rename it from `Blackout-FFXI-ScreenSaver` or similar).
4. Load the addon in-game by typing `//lua load blackout` or add `lua load blackout` to your `init.txt` file (located in `Windower4/scripts/`) to load it automatically.
