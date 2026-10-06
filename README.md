# Shimeji Nook

**Created by naph_ · Open Source · [MIT License](LICENSE)**

A Shimeji desktop companion for Windows and macOS, with selectable **ThungNgern** and **Artist** characters, transparent animations, independent dialogue and application-window climbing.

## Download and run

Use the version 0.6.0 archive for your platform and extract the complete ZIP before launching.

| Platform | Application | Version |
| --- | --- | --- |
| Windows 10/11 x64 | ShimejiNook.exe with Assets beside it | 0.6.0 |
| macOS 13+ Intel / Apple Silicon | Shimeji Nook.app | 0.6.0 |

Windows packages are self-contained: no separate .NET installation is required. Keep the executable and Assets together. On macOS, move the application to Applications. The Mac build is ad-hoc signed, without Developer ID or notarization. Allow Accessibility for Shimeji Nook when needed for window geometry.

## Controls

Right-click the character to open the compact menu:

- **Emotes:** Wave, Happy, Jump, Sleep/Wake Up, Sit and Run.
- **Change Model:** select a character; selection is remembered after restarting.
- **Say:** display dialogue specific to the selected character.
- **Pause / Wandering:** pause movement or enable/disable autonomous walking.
- **Move:** walk left/right, visit a window, climb its sides or return Home.
- **Quit:** close the application; shown in red at the bottom.

Drag the character with the mouse. Transparent areas allow clicks through to other applications. Opening menus does not resize the character. Artist is a temporary name for a male character with 96 frames across 12 states and 14 dialogue lines.

## Build

### Windows

Requires the .NET 10 SDK on Windows:

```powershell
.\Windows-source\build.ps1
# Build and launch
.\Windows-source\build.ps1 -Run
```

Output: Windows-app/ShimejiNook.exe and Assets. For ARM64, add `-Runtime win-arm64`.

### macOS

Requires Mac and Xcode:

```bash
bash macOS-source/build.command
```

Output: Mac-app/Shimeji Nook.app, Universal arm64 + x86_64.

### Package

Requires Python 3.11+ and a build for the selected platform:

```bash
python scripts/package.py --platform windows
python scripts/package.py --platform macos
# Source ZIP after git init
python scripts/package-source.py
```

Archives, checksums and package reports are written to dist/. The scripts verify asset hashes and archived files, and preserve macOS executable permissions.

## Repository layout

```text
Windows-source/                    C# / WPF + Win32
macOS-source/                     Swift / AppKit + Xcode
macOS-source/ShimejiNook/Assets/   Shared character assets
CharacterPreview/                 Artist animation preview (index.html)
scripts/                          Packaging and validation
docs/                             Validation and GitHub preparation
.github/workflows/                Windows and macOS build jobs
```

Keep both source folders side by side. Do not commit executables, runtimes, SDKs or build outputs. Attach application ZIPs to GitHub Releases instead. Suggested repository name: `shimeji-nook`.

## Validation status

Version 0.6.0 was rebuilt for both platforms on Mac. The renamed macOS application was launched and visually inspected. The previous Windows 0.5.1 build was tested on Windows; **the renamed Windows 0.6.0 executable still requires a Windows runtime check**. See [validation](docs/VALIDATION.md). GitHub workflows have not yet been executed for this repository.

## Credits and license

Created by **naph_**, distributed under the [MIT License](LICENSE). See [credits](CREDITS.md), [contributing](CONTRIBUTING.md), [third-party notices](THIRD_PARTY_NOTICES.md), [GitHub preparation](docs/GITHUB.md) and [changelog](CHANGELOG.md).

---

## ภาษาไทย

**Shimeji Nook** เป็นแอปเพื่อนตัวจิ๋วบนเดสก์ท็อปสำหรับ Windows และ macOS สร้างโดย **naph_** ใช้ MIT License ชื่อโปรเจกต์ใหม่ไม่เปลี่ยนชื่อโมเดล **ถุงเงิน** และ **Artist** ภาพและคำพูดยังคงเดิม

แตก ZIP ทั้งชุดก่อนเปิดแอป Windows ใช้ **ShimejiNook.exe** และต้องเก็บ Assets ไว้ข้างกัน ไม่ต้องติดตั้ง .NET เพิ่ม ส่วน Mac ใช้ **Shimeji Nook.app** รองรับ macOS 13+ ทั้ง Intel และ Apple Silicon และอาจต้องอนุญาต Accessibility ให้แอปชื่อใหม่

คลิกขวาเปิด Emotes, Change Model, Say, Pause, Wandering และ Move; Quit สีแดงอยู่ล่างสุด ลากตัวละครได้ พื้นที่โปร่งใสคลิกทะลุ และการเปิดเมนูไม่เปลี่ยนขนาดตัวละคร

รุ่น 0.6.0 build ใหม่ทั้งสองระบบบน Mac แล้ว ฝั่ง Mac ตรวจตัวละครและเมนูจริงแล้ว ฝั่ง Windows รุ่นเดิม 0.5.1 ผ่านการใช้งานจริง แต่ตัวรันชื่อใหม่ยังต้องเปิดตรวจซ้ำบน Windows

เปิด CharacterPreview/index.html เพื่อดูท่าของ Artist และอ่านเอกสารภาษาอังกฤษใน docs/ สำหรับการ build และเตรียมขึ้น GitHub งานนี้ยังไม่ได้ push หรือเผยแพร่ Release ให้ค่ะ
