# Kemas project untuk CD/USB — hanya file yang diperlukan (tanpa build cache).
# Jalankan dari folder root project:
#   powershell -ExecutionPolicy Bypass -File scripts\package_for_cd.ps1
#
# Opsi:
#   -Mode source   → kode sumber Flutter + Arduino (~5–15 MB)
#   -Mode apk      → salin APK yang sudah di-build (jika ada)
#   -Mode both     → keduanya (default)

param(
    [ValidateSet('source', 'apk', 'both')]
    [string]$Mode = 'both',
    [string]$OutputDir = ''
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not $OutputDir) {
    $stamp = Get-Date -Format 'yyyyMMdd_HHmm'
    $OutputDir = Join-Path $root "cd_package_$stamp"
}

$excludeDirs = @(
    'build', '.dart_tool', '.git', '.idea', 'node_modules',
    'android\.gradle', 'android\app\build', 'android\build',
    'ios\Pods', 'ios\.symlinks', 'windows\flutter\ephemeral',
    'linux\flutter\ephemeral', 'macos\Flutter\ephemeral'
)

function Should-SkipPath([string]$relativePath) {
    foreach ($ex in $excludeDirs) {
        if ($relativePath -eq $ex -or $relativePath -like "$ex\*" -or $relativePath -like "*\$ex\*") {
            return $true
        }
    }
    return $false
}

function Copy-ProjectSource {
    param([string]$Dest)
    $srcRoot = Join-Path $Dest 'monitoring_plts_source'
    New-Item -ItemType Directory -Force -Path $srcRoot | Out-Null

    Get-ChildItem -Path $root -Recurse -Force -File | ForEach-Object {
        $rel = $_.FullName.Substring($root.Length + 1)
        if (Should-SkipPath $rel) { return }
        if ($rel -like 'cd_package_*') { return }
        if ($rel -like 'scripts\package_for_cd.ps1') { return }

        $target = Join-Path $srcRoot $rel
        $targetDir = Split-Path $target -Parent
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
        }
        Copy-Item $_.FullName $target -Force
    }

    $readme = @"
MONITORING PLTS — Paket Sumber
==============================

Ukuran kecil karena folder build/ dan .dart_tool/ TIDAK disertakan.
Itu hanya cache komputer pengembang, bukan bagian aplikasi.

Cara menjalankan ulang di PC lain:
1. Install Flutter SDK + Android Studio
2. Buka folder monitoring_plts_source
3. Jalankan: flutter pub get
4. Build APK: flutter build apk --release

Firebase: pastikan google-services.json dan firebase_options.dart ada.
"@
    Set-Content -Path (Join-Path $srcRoot 'BACA_INI_CD.txt') -Value $readme -Encoding UTF8
    return $srcRoot
}

function Copy-ApkIfExists {
    param([string]$Dest)
    $apkPaths = @(
        (Join-Path $root 'build\app\outputs\flutter-apk\app-release.apk'),
        (Join-Path $root 'build\app\outputs\apk\release\app-release.apk'),
        (Join-Path $root 'build\app\outputs\flutter-apk\app-debug.apk'),
        (Join-Path $root 'build\app\outputs\apk\debug\app-debug.apk')
    )
    $found = $apkPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $found) {
        Write-Warning 'APK tidak ditemukan. Build dulu: flutter build apk --release'
        return $null
    }
    $apkDir = Join-Path $Dest 'install_apk'
    New-Item -ItemType Directory -Force -Path $apkDir | Out-Null
    Copy-Item $found (Join-Path $apkDir 'monitoring_plts.apk') -Force

    $readme = @"
MONITORING PLTS — Instal APK
============================

1. Salin monitoring_plts.apk ke HP Android
2. Aktifkan "Instal dari sumber tidak dikenal" di pengaturan
3. Buka file APK dan instal

Catatan: APK debug lebih besar (~75 MB). Untuk CD lebih kecil,
build release: flutter build apk --release (~20–40 MB)
"@
    Set-Content -Path (Join-Path $apkDir 'CARA_INSTAL.txt') -Value $readme -Encoding UTF8
    return (Join-Path $apkDir 'monitoring_plts.apk')
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
Write-Host "Output: $OutputDir"

if ($Mode -eq 'source' -or $Mode -eq 'both') {
    $src = Copy-ProjectSource -Dest $OutputDir
    $srcSize = (Get-ChildItem $src -Recurse -File | Measure-Object Length -Sum).Sum / 1MB
    Write-Host ("Sumber: {0:N2} MB -> {1}" -f $srcSize, $src)
}

if ($Mode -eq 'apk' -or $Mode -eq 'both') {
    $apk = Copy-ApkIfExists -Dest $OutputDir
    if ($apk) {
        $apkSize = (Get-Item $apk).Length / 1MB
        Write-Host ("APK: {0:N2} MB -> {1}" -f $apkSize, $apk)
    }
}

$total = (Get-ChildItem $OutputDir -Recurse -File | Measure-Object Length -Sum).Sum / 1MB
Write-Host ("Total paket: {0:N2} MB (muat CD 700 MB)" -f $total)
Write-Host 'Salin isi folder output ke CD/USB, atau zip dulu.'
