$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$temp = 'C:\Temp\vs-build-tools'
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
    'C:\BuildTools',
    '--add',
    'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
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

Remove-Item $temp -Recurse -Force
