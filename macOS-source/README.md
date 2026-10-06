# Shimeji Nook for macOS

Version 0.6.0 requires macOS 13 or later and supports Apple Silicon and Intel.

Read ../README.md and ../docs/VALIDATION.md. Build using Xcode and the ShimejiNook scheme, or run `bash macOS-source/build.command` from the repository root. The script creates Mac-app/Shimeji Nook.app and verifies both architectures and its ad-hoc signature.

The bundle identifier is local.naph.ShimejiNook. Allow Accessibility for the renamed application when needed for window geometry. Model selection is migrated from the previous application if available.

Character assets are under ShimejiNook/Assets; additional models are under Assets/Models. Keep the shared assets directory in place for the Windows project.

The project is created by naph_ and distributed under the MIT License at the repository root.
