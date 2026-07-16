$buildGradlePath = 'C:\Users\PT FALCON\AppData\Local\Pub\Cache\hosted\pub.dev\usb_serial-0.4.0\android\build.gradle'
if (Test-Path $buildGradlePath) {
    $text = Get-Content $buildGradlePath -Raw
    if ($text -match "android \{\\n\s*namespace 'dev.bessems.usbserial'") {
        $text = $text -replace "\\n", [Environment]::NewLine
        Set-Content -Path $buildGradlePath -Value $text
        Write-Output "Replaced literal \"\\n\" with actual newlines in build.gradle."
    } else {
        Write-Output "No literal \"\\n\" tokens found (or already fixed)."
    }
} else {
    Write-Output "build.gradle not found at $buildGradlePath"
}