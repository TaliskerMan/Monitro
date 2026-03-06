Write-Host "Incrementing build number..."
$env:VERSION = .\scripts\increment_build.ps1
Write-Host "Building version: $env:VERSION"

Write-Host "Building Flutter UI for Windows..."
flutter build windows --release

Write-Host "Building backend..."
Push-Location backend
dart pub get
dart compile exe bin/monitro_collector.dart -o monitro_collector.exe
Pop-Location

Write-Host "Packaging with Inno Setup..."
# GitHub Actions runner usually has Inno Setup in this path or it's accessible via iscc
$ISCC = "iscc"
if (Get-Command $ISCC -ErrorAction SilentlyContinue) {
    & $ISCC .\scripts\monitro.iss
} else {
    $ISCC_PATH = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
    if (Test-Path $ISCC_PATH) {
        & $ISCC_PATH .\scripts\monitro.iss
    } else {
        Write-Host "Inno Setup Compiler not found."
        exit 1
    }
}
Write-Host "Created Windows Installer."
