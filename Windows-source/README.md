# Shimeji Nook for Windows

Read ../README.md and ../docs/VALIDATION.md. Build with the .NET 10 SDK on Windows using `./Windows-source/build.ps1` from the repository root. Add `-Run` to launch after publishing, or `-Runtime win-arm64` for an ARM64 build.

The release executable is ShimejiNook.exe, a self-contained single-file application. Keep its Assets directory beside it. No separate .NET installation is required to run the packaged application.

Settings and runtime logs are stored in %LOCALAPPDATA%/ShimejiNook. On first launch, existing model selection is copied from %LOCALAPPDATA%/ThungNgern if available. This old path is retained only for migration.

The renamed 0.6.0 executable was built on Mac and still needs runtime verification on Windows. The previous 0.5.1 implementation was tested on Windows.
