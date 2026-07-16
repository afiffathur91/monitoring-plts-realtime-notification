$buildGradlePath = 'C:\Users\PT FALCON\AppData\Local\Pub\Cache\hosted\pub.dev\usb_serial-0.4.0\android\build.gradle'
if (Test-Path $buildGradlePath) {
    $text = Get-Content $buildGradlePath -Raw
    if ($text -notmatch "namespace\s+'dev.bessems.usbserial'") {
        $text = $text -replace 'android\s*{', "android {\n    namespace 'dev.bessems.usbserial'"
        Set-Content -Path $buildGradlePath -Value $text
        Write-Output "Updated build.gradle: namespace inserted."
    } else {
        Write-Output "build.gradle already has namespace."
    }
} else {
    Write-Output "build.gradle not found at $buildGradlePath"
}

$manifestPath = 'C:\Users\PT FALCON\AppData\Local\Pub\Cache\hosted\pub.dev\usb_serial-0.4.0\android\src\main\AndroidManifest.xml'
if (Test-Path $manifestPath) {
    $mtext = Get-Content $manifestPath -Raw
    if ($mtext -notmatch 'package="dev.bessems.usbserial"') {
        $mtext = $mtext -replace '<manifest\s+xmlns:android="http://schemas.android.com/apk/res/android"', '<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="dev.bessems.usbserial"'
        Set-Content -Path $manifestPath -Value $mtext
        Write-Output "Updated AndroidManifest.xml: package added."
    } else {
        Write-Output "AndroidManifest.xml already has package."
    }
} else {
    Write-Output "AndroidManifest.xml not found at $manifestPath"
}
