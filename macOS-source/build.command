#!/bin/bash
set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
build_dir="$repo_root/.build/macOS"
output_dir="$repo_root/Mac-app"
xcrun xcodebuild -project "$script_dir/ShimejiNook.xcodeproj" \
  -scheme ShimejiNook -configuration Release -derivedDataPath "$build_dir" \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO CODE_SIGN_IDENTITY="-" build
mkdir -p "$output_dir"
ditto "$build_dir/Build/Products/Release/Shimeji Nook.app" "$output_dir/Shimeji Nook.app"
codesign --verify --deep --strict "$output_dir/Shimeji Nook.app"
arch_list=$(lipo -archs "$output_dir/Shimeji Nook.app/Contents/MacOS/ShimejiNook")
for required_arch in arm64 x86_64; do
  case " $arch_list " in
    *" $required_arch "*) ;;
    *) echo "Missing architecture: $required_arch" >&2; exit 1 ;;
  esac
done
echo "Ready: $output_dir/Shimeji Nook.app"
