$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$temp = 'C:\Temp\vs-build-tools'
$installPath = 'C:\BuildTools'
New-Item -ItemType Directory -Path $temp -Force | Out-Null

$installer = Join-Path $temp 'vs_buildtools.exe'
Write-Host 'Downloading and verifying signature for vs_buildtools.exe'
Invoke-WebRequest -Uri 'https://aka.ms/vs/17/release/vs_buildtools.exe' -OutFile $installer -UseBasicParsing
$signature = Get-AuthenticodeSignature -FilePath $installer
if ($signature.Status -ne 'Valid') {
    throw "Authenticode validation failed for vs_buildtools.exe: $($signature.Status)"
}

$arguments = @(
    '--quiet',
    '--wait',
    '--norestart',
    '--nocache',
    '--installPath',
    $installPath,
    '--add',
    'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
    '--add',
    'Microsoft.VisualStudio.Component.Vcpkg',
    '--add',
    'Microsoft.VisualStudio.Component.Windows11SDK.26100',
    '--add',
    'Microsoft.Net.Component.4.8.TargetingPack'
)

Write-Host 'Installing Visual Studio Build Tools; this step can take several minutes'
$process = Start-Process -FilePath $installer -ArgumentList $arguments -Wait -PassThru
if ($process.ExitCode -notin @(0, 3010)) {
    throw "Visual Studio Build Tools installation failed with exit code $($process.ExitCode)"
}

if (-not (Test-Path 'C:\BuildTools\VC\Auxiliary\Build\vcvars64.bat')) {
    throw 'The x64 MSVC toolchain was not installed'
}

$vcpkgSource = Join-Path $installPath 'VC\vcpkg'
if (-not (Test-Path (Join-Path $vcpkgSource 'vcpkg.exe'))) {
    throw "The vcpkg Visual Studio component was not installed under $vcpkgSource"
}

if (-not $env:VCPKG_ROOT) {
    throw 'VCPKG_ROOT must be set before installing the vcpkg component'
}

New-Item -ItemType Directory -Path $env:VCPKG_ROOT -Force | Out-Null
Get-ChildItem -LiteralPath $vcpkgSource -Force | Copy-Item -Destination $env:VCPKG_ROOT -Recurse -Force

if (-not (Test-Path (Join-Path $env:VCPKG_ROOT 'vcpkg.exe'))) {
    throw "The vcpkg component was not copied to $env:VCPKG_ROOT"
}

if (-not (Test-Path (Join-Path $env:VCPKG_ROOT 'scripts\buildsystems\vcpkg.cmake'))) {
    throw "The vcpkg toolchain was not copied to $env:VCPKG_ROOT"
}

Remove-Item $temp -Recurse -Force
