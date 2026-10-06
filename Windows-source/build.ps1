param([switch]$Run, [switch]$InspectUI, [ValidateSet('win-x64', 'win-arm64')][string]$Runtime = 'win-x64')
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$toolsRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../.tools'))
$localDotnet = Join-Path $toolsRoot 'dotnet/dotnet.exe'
$dotnetCommand = if (Test-Path -LiteralPath $localDotnet) { $localDotnet } else { 'dotnet' }
if ($dotnetCommand -eq $localDotnet) {
    $env:DOTNET_CLI_HOME = Join-Path $toolsRoot 'cli-home'
    $env:NUGET_PACKAGES = Join-Path $toolsRoot 'nuget'
}
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:DOTNET_GENERATE_ASPNET_CERTIFICATE = 'false'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Get-Process -Name 'ShimejiNook', 'ThungNgern.Windows' -ErrorAction SilentlyContinue | Where-Object {
    $_.Path -and $_.Path.StartsWith($projectRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
} | Stop-Process
$arch = $Runtime
$outputDir = Join-Path $projectRoot 'Windows-app'
if (Test-Path -LiteralPath $outputDir) {
    $backupDir = Join-Path $projectRoot ('.build/previous-Windows-app-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path (Split-Path -Parent $backupDir) -Force | Out-Null
    # Both paths are resolved under this repository; retain old output rather than deleting it.
    Move-Item -LiteralPath $outputDir -Destination $backupDir
}
& $dotnetCommand publish .\ShimejiNook.Windows.csproj -c Release -r $arch --self-contained true -o ..\Windows-app
if ($LASTEXITCODE -ne 0) { throw 'Build failed. See the errors above.' }
Write-Host "Ready: ..\Windows-app\ShimejiNook.exe"
if ($Run) {
    $launchOptions = @{ FilePath = Join-Path $projectRoot 'Windows-app/ShimejiNook.exe'; WindowStyle = 'Hidden' }
    if ($InspectUI) { $launchOptions.ArgumentList = '--inspect-ui' }
    Start-Process @launchOptions
}
