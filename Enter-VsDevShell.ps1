$ErrorActionPreference = 'Stop'

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$instanceId = & $vswhere -latest -products '*' -property instanceId
if (-not $instanceId) {
    throw 'Visual Studio Build Tools instance was not found'
}

$devShellModule = 'C:\BuildTools\Common7\Tools\Microsoft.VisualStudio.DevShell.dll'
if (-not (Test-Path $devShellModule)) {
    throw "Visual Studio Developer Shell module was not found: $devShellModule"
}

Import-Module $devShellModule
Enter-VsDevShell -VsInstanceId $instanceId -SkipAutomaticLocation `
    -DevCmdArguments '-arch=amd64 -host_arch=amd64'
