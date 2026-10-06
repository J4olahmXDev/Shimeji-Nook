# Validation — Shimeji Nook 0.6.0

## Windows

The source preserves the latest Windows 0.5.1 implementation that the developer previously confirmed working on Windows. Version 0.6.0 changes the namespace, assembly/executable name, window titles, product/version metadata, data directory and singleton names, with migration of the previous settings.

Rebuilt on macOS ARM64 using .NET SDK 10.0.401 as Release win-x64 self-contained single-file. WPF is not trimmed. Assets remain beside ShimejiNook.exe. **The renamed executable has not been run on Windows in this preparation.** Repeat runtime checks for menus, settings migration, singleton replacement, dragging, click-through and window attachment on Windows.

## macOS

Rebuilt Swift/AppKit on Mac with Xcode as Release Universal arm64 + x86_64, version 0.6.0. Application: Shimeji Nook.app. Executable: ShimejiNook. Bundle identifier: local.naph.ShimejiNook.

Verified the ad-hoc signature, universal executable and bundle metadata. Launched the renamed application and visually inspected the character and menu. Character assets and dialogue are unchanged.

The new bundle identifier may require Accessibility permission for Shimeji Nook. Physical multiple-monitor testing and a new Accessibility grant were not performed as part of this rename.

## Packaging

The packaging tool checks PE/Mach-O signatures, architectures, manifest frame counts, positive frame rates, playback orders, source-to-bundle asset hashes, ZIP CRC, every archived entry and macOS executable permissions. New archives include SHA256SUMS.txt, the MIT License and author credits. Windows packages retain matching runtime licenses and notices.

Unrelated CoreSimulator/system diagnostics and skipped AppIntents metadata are not application compile errors.
