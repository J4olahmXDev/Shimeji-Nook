# Historical macOS 0.5 — Change Model

- Added the male chibi Artist model with a temporary display name.
- Added Change Model with persistent selection between ThungNgern and Artist.
- Added 12 Artist states / 96 transparent PNG frames, including talk for Say.
- Kept dialogue separate: 14 male Artist lines and the original 8 ThungNgern lines.
- Paused walking temporarily during Say and sized the speech bubble to its text.
- Added a compact 200 × 207 point main menu: Emotes, Change Model, Say, Pause, Wandering, Move and Quit.
- Grouped directional walking, window climbing, window visits and Home under Move.
- Grouped Wave, Happy, Jump, Sleep/Wake Up, Sit and Run under Emotes.
- Placed red Quit last and removed debug commands from the user menu.
- Fixed submenu switching and sized child menus for full labels.
- Respected loop=false for Jump and an explicit Wave playback order.
- Preserved physics, window perching, click-through and the character panel size.

## Add a bundled model

Place a model pack at ShimejiNook/Assets/Models/<model-id>/ with model.json and an Assets folder containing manifest.json and PNG frames. Use the Artist pack as an example. Metadata supplies the display name, dialogue, native facing, fps, pivot and frame order.

Every model must load an idle animation. Missing states fall back to idle. At least one dialogue line is required.

Change Model lists packs bundled in the application; it is not a ZIP import interface.
