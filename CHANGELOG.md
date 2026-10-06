# Changelog

## Shimeji Nook 0.6.0 — 2026-10-06

- Renamed the project, application, executable, package names and documentation from ThungNgern to Shimeji Nook.
- Unified the Windows and macOS release version at 0.6.0.
- Preserved the ThungNgern and Artist models, all artwork and dialogue.
- Added migration of the selected model from the previous application's settings.
- Replaced previous application instances when launching the renamed application.
- Updated build scripts, packaging tools and GitHub Actions artifact names.
- Changed the macOS bundle identifier to local.naph.ShimejiNook. Accessibility permission may need to be granted to the renamed application.
- Rebuilt both platforms on Mac; the renamed Windows executable has not yet been run on Windows.
- Converted Markdown documentation to English; README.md also includes Thai.

## Windows 0.5.1 — 2026-10-06

- Improved dragging, window attachment and state transitions in the Windows implementation.
- Added single-file self-contained publishing while retaining external character assets.
- Added UI inspection support and validated the character and menus on Windows.
- Prepared MIT-licensed repository documentation, credits, notices and release packaging scripts.

## macOS 0.5

- Added Change Model with persistent selection between ThungNgern and Artist.
- Added 96 transparent Artist frames across 12 animation states and 14 independent dialogue lines.
- Added compact menus, dynamic speech bubbles and per-animation playback metadata.
