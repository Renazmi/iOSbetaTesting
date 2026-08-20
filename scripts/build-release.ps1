# Builds TrackIT mobile release APK to releases/TrackIT.apk
$ErrorActionPreference = "Stop"
$mobileRoot = Split-Path -Parent $PSScriptRoot
$projectRoot = Split-Path -Parent $mobileRoot
$releasesApk = Join-Path $projectRoot "releases\TrackIT.apk"
Set-Location $mobileRoot

Write-Host "Fetching dependencies..."
flutter pub get

$registrantPath = Join-Path $mobileRoot "android\app\src\main\java\io\flutter\plugins\GeneratedPluginRegistrant.java"
if (Test-Path $registrantPath) {
    $content = Get-Content $registrantPath -Raw
    $content = $content -replace '(?ms)\s*try \{\s*flutterEngine\.getPlugins\(\)\.add\(new dev\.flutter\.plugins\.integration_test\.IntegrationTestPlugin\(\)\);\s*\} catch \(Exception e\) \{\s*Log\.e\(TAG, "Error registering plugin integration_test[^"]*", e\);\s*\}', ''
    Set-Content -Path $registrantPath -Value $content -NoNewline
}

Write-Host "Building release APK..."
Set-Location (Join-Path $mobileRoot "android")
& ./gradlew.bat :app:exportTrackITApk
if ($LASTEXITCODE -ne 0) {
    throw "Gradle release build failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path $releasesApk)) {
    throw "Release APK was not produced at $releasesApk"
}

$item = Get-Item $releasesApk
Write-Host ""
Write-Host "Done: $($item.FullName) ($([math]::Round($item.Length / 1MB, 2)) MB)"
