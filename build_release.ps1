# ==============================================================================
# Army (vn.army.txa) - Production Release Build Script
# Usage:
#   .\build_release.ps1 apk            -> Builds Release APK
#   .\build_release.ps1 aab            -> Builds Release AAB App Bundle
#   .\build_release.ps1 win / windows  -> Builds Windows Setup (.exe) via Inno Setup
#   .\build_release.ps1 all (or 1)     -> Builds APK, AAB & Windows Setup (.exe)
# ==============================================================================

param (
    [string]$Target = "all"
)

$ErrorActionPreference = "Stop"

# Ensure script runs from the project root directory
Set-Location -Path $PSScriptRoot

$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# Resolve Inno Setup Compiler (ISCC.exe)
$ISCC = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $ISCC)) {
    $ISCC = "C:\Program Files\Inno Setup 6\ISCC.exe"
}

# 0. Prepare single unified production output directory
$prodDir = Join-Path $PSScriptRoot "production"
if (-not (Test-Path $prodDir)) {
    New-Item -ItemType Directory -Path $prodDir -Force | Out-Null
}

Write-Host "🚀 Starting Army Production Release Build Process..." -ForegroundColor Yellow
Write-Host "Target: $Target" -ForegroundColor Cyan
Write-Host "Unified Production Directory: $prodDir" -ForegroundColor Cyan

# 1. Clean and fetch packages
Write-Host "`n📦 Running flutter pub get..." -ForegroundColor Gray
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to fetch packages!" -ForegroundColor Red
    exit 1
}

# 2. Analyze code cleanliness
Write-Host "`n🔍 Running flutter analyze..." -ForegroundColor Gray
flutter analyze
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Flutter analyze failed with errors!" -ForegroundColor Red
    exit 1
}

$buildApk = ($Target -eq "apk" -or $Target -eq "all" -or $Target -eq "1" -or $Target -eq "")
$buildAab = ($Target -eq "aab" -or $Target -eq "all" -or $Target -eq "1" -or $Target -eq "")
$buildWin = ($Target -eq "win" -or $Target -eq "windows" -or $Target -eq "all" -or $Target -eq "1")

# 3. Build APK
if ($buildApk) {
    Write-Host "`n📱 Building Release APK..." -ForegroundColor Green
    flutter build apk --release
    if ($LASTEXITCODE -eq 0) {
        $apkPath = "build\app\outputs\flutter-apk\app-release.apk"
        if (Test-Path $apkPath) {
            $apkDest = Join-Path $prodDir "Army Setup.apk"
            Copy-Item -Path $apkPath -Destination $apkDest -Force
            $apkSize = (Get-Item $apkDest).Length / 1MB
            Write-Host "✅ Release APK built & copied successfully!" -ForegroundColor Green
            Write-Host "   Output Path: $apkDest" -ForegroundColor White
            Write-Host "   Size: $([math]::Round($apkSize, 2)) MB" -ForegroundColor White
        }
    } else {
        Write-Host "❌ Failed to build Release APK!" -ForegroundColor Red
        exit 1
    }
}

# 4. Build AAB (App Bundle for Google Play)
if ($buildAab) {
    Write-Host "`n📦 Building Release AAB (Android App Bundle)..." -ForegroundColor Green
    flutter build appbundle --release
    if ($LASTEXITCODE -eq 0) {
        $aabPath = "build\app\outputs\bundle\release\app-release.aab"
        if (Test-Path $aabPath) {
            $aabDest = Join-Path $prodDir "Army Setup.aab"
            Copy-Item -Path $aabPath -Destination $aabDest -Force
            $aabSize = (Get-Item $aabDest).Length / 1MB
            Write-Host "✅ Release AAB built & copied successfully!" -ForegroundColor Green
            Write-Host "   Output Path: $aabDest" -ForegroundColor White
            Write-Host "   Size: $([math]::Round($aabSize, 2)) MB" -ForegroundColor White
        }
    } else {
        Write-Host "❌ Failed to build Release AAB!" -ForegroundColor Red
        exit 1
    }
}

# 5. Build Windows Desktop Setup via Inno Setup Compiler (ISCC)
if ($buildWin) {
    # Free up memory held by Java/Gradle Daemons if Android was built previously
    if (Test-Path "android\gradlew.bat") {
        Write-Host "`n🧹 Freeing Gradle memory before Windows build..." -ForegroundColor Gray
        & "android\gradlew.bat" --stop | Out-Null
    }

    Write-Host "`n💻 Building Release Windows App Binary..." -ForegroundColor Green
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to build Release Windows Binary!" -ForegroundColor Red
        exit 1
    }

    if (-not (Test-Path $ISCC)) {
        Write-Host "❌ Inno Setup Compiler (ISCC.exe) not found!" -ForegroundColor Red
        exit 1
    }

    Write-Host "`n🔨 Compiling Windows Setup Installer with Inno Setup (ISCC)..." -ForegroundColor Green
    $issScript = Join-Path $PSScriptRoot "Army.iss"
    & $ISCC "/DMyAppVersion=1.0.0" $issScript

    $setupExePath = Join-Path $prodDir "Army Setup.exe"
    if (Test-Path $setupExePath) {
        $exeSize = (Get-Item $setupExePath).Length / 1MB
        Write-Host "✅ Windows Installer (.exe) compiled successfully!" -ForegroundColor Green
        Write-Host "   Output Path: $setupExePath" -ForegroundColor White
        Write-Host "   Size: $([math]::Round($exeSize, 2)) MB" -ForegroundColor White
    } else {
        Write-Host "❌ Failed to generate Army Setup.exe installer!" -ForegroundColor Red
        exit 1
    }
}

$Stopwatch.Stop()
$elapsed = $Stopwatch.Elapsed
if ($elapsed.TotalSeconds -ge 60) {
    $timeStr = "$($elapsed.Minutes) phút $($elapsed.Seconds) giây"
} else {
    $timeStr = "$($elapsed.Seconds) giây"
}
Write-Host "`n⏱ Total Build Time: $timeStr" -ForegroundColor Cyan

Write-Host "`n📂 All Unified Production Artifacts in '$prodDir':" -ForegroundColor Yellow
Get-ChildItem -Path $prodDir | ForEach-Object {
    if ($_.PSIsContainer) {
        Write-Host "   📂 $($_.Name) (Directory)" -ForegroundColor White
    } else {
        $size = $_.Length / 1MB
        Write-Host "   📄 $($_.Name) ($([math]::Round($size, 2)) MB)" -ForegroundColor White
    }
}

Write-Host "`n🎉 Production Release Build Completed Successfully!" -ForegroundColor Yellow
