$ErrorActionPreference = 'Stop'
$counterRoot = Split-Path -Parent $PSScriptRoot
$counterJavaTemp = Join-Path $counterRoot 'build/java_tmp'
New-Item -ItemType Directory -Force -Path $counterJavaTemp | Out-Null
$counterOldJava = $env:JAVA_OPTS
$counterOldUnbuffered = $env:PYTHONUNBUFFERED
try {
    $env:JAVA_OPTS = '-Djdk.net.unixdomain.tmpdir=' + ($counterJavaTemp -replace '\\','/') + ' -Djava.net.preferIPv4Stack=true'
    $env:PYTHONUNBUFFERED = '1'
    & 'C:/AMDDesignTools/2025.2/Vitis/bin/vitis.bat' -s (Join-Path $PSScriptRoot 'build_counter_bsp.py')
    if ($LASTEXITCODE -ne 0) { throw 'Vitis application build failed; inspect its output.' }
} finally {
    $env:JAVA_OPTS = $counterOldJava
    $env:PYTHONUNBUFFERED = $counterOldUnbuffered
}
