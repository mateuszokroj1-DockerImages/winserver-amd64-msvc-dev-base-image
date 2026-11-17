$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$temp = 'C:\Temp\devtools'
New-Item -ItemType Directory -Path $temp -Force | Out-Null

function Get-VerifiedDownload {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$ExpectedHash,
        [ValidateSet('SHA256', 'SHA512')][string]$Algorithm = 'SHA256'
    )

    $path = Join-Path $temp $Name
    Write-Host "Downloading and verifying $Name"
    Invoke-WebRequest -Uri $Uri -OutFile $path -UseBasicParsing
    $actual = (Get-FileHash -Path $path -Algorithm $Algorithm).Hash.ToLowerInvariant()
    if ($actual -ne $ExpectedHash.ToLowerInvariant()) {
        throw "$Algorithm mismatch for $Name (got $actual)"
    }

    return $path
}

function Get-AuthenticodeVerifiedDownload {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][string]$Name
    )

    $path = Join-Path $temp $Name
    Write-Host "Downloading and verifying signature for $Name"
    Invoke-WebRequest -Uri $Uri -OutFile $path -UseBasicParsing
    $signature = Get-AuthenticodeSignature -FilePath $path
    if ($signature.Status -ne 'Valid') {
        throw "Authenticode validation failed for ${Name}: $($signature.Status)"
    }

    return $path
}

function Install-Msi {
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$Arguments = ''
    )

    Write-Host "Installing MSI: $Path"
    $process = Start-Process -FilePath 'msiexec.exe' `
        -ArgumentList "/i `"$Path`" /qn /norestart $Arguments" `
        -Wait -PassThru
    if ($process.ExitCode -notin @(0, 3010)) {
        throw "MSI installation failed for $Path with exit code $($process.ExitCode)"
    }
}

$git = Get-VerifiedDownload `
    'https://github.com/git-for-windows/git/releases/download/v2.56.1.windows.1/Git-2.56.1-64-bit.exe' `
    'Git-2.56.1-64-bit.exe' `
    'c330c72e10b408cc39994bfefdb63542b0d93d21699325c3e0bd874af8a5a559'
$signature = Get-AuthenticodeSignature -FilePath $git
if ($signature.Status -ne 'Valid') {
    throw "Git installer signature is not valid: $($signature.Status)"
}
Write-Host 'Installing Git for Windows'
$process = Start-Process -FilePath $git `
    -ArgumentList '/VERYSILENT /NORESTART /SUPPRESSMSGBOXES "/DIR=C:\Program Files\Git"' `
    -Wait -PassThru
if ($process.ExitCode -ne 0) {
    throw "Git installation failed with exit code $($process.ExitCode)"
}
Remove-Item $git -Force

$gitLfsArchive = Get-VerifiedDownload `
    'https://github.com/git-lfs/git-lfs/releases/download/v3.8.1/git-lfs-windows-amd64-v3.8.1.zip' `
    'git-lfs-windows-amd64-v3.8.1.zip' `
    '5bb771c12b3dacc535e912d0270a010c209d4da2e63819c5918e3547c2defed9'
Write-Host 'Installing Git LFS'
$gitLfsExtract = Join-Path $temp 'git-lfs'
Expand-Archive -Path $gitLfsArchive -DestinationPath $gitLfsExtract -Force
$gitLfsBinary = Get-ChildItem -Path $gitLfsExtract -Filter git-lfs.exe -Recurse | Select-Object -First 1
if (-not $gitLfsBinary) {
    throw 'git-lfs.exe was not present in the verified Git LFS archive'
}
Copy-Item $gitLfsBinary.FullName 'C:\Program Files\Git\cmd\git-lfs.exe' -Force
Remove-Item $gitLfsArchive -Force
Remove-Item $gitLfsExtract -Recurse -Force
@'
[filter "lfs"]
    clean = git-lfs clean -- %f
    smudge = git-lfs smudge -- %f
    process = git-lfs filter-process
    required = true
'@ | Add-Content -Path 'C:\Program Files\Git\etc\gitconfig' -Encoding ASCII
if (-not (Test-Path 'C:\Program Files\Git\cmd\git-lfs.exe')) {
    throw 'Git LFS installation failed'
}

$powerShell = Get-VerifiedDownload `
    'https://github.com/PowerShell/PowerShell/releases/download/v7.7.0/PowerShell-7.7.0-win-x64.zip' `
    'PowerShell-7.7.0-win-x64.zip' `
    '7c74e03b20a75b59715847439d046a6214b1863ee79b187872980f139bb4a05f'
$powerShellPath = 'C:\Program Files\PowerShell\7'
Write-Host 'Installing PowerShell 7'
New-Item -ItemType Directory -Path $powerShellPath -Force | Out-Null
Expand-Archive -Path $powerShell -DestinationPath $powerShellPath -Force
Remove-Item $powerShell -Force

$python = Get-AuthenticodeVerifiedDownload `
    'https://www.python.org/ftp/python/3.14.9/python-3.14.9-amd64.exe' `
    'python-3.14.9-amd64.exe'
Write-Host 'Installing Python'
$pythonProcess = Start-Process -FilePath $python `
    -ArgumentList '/quiet InstallAllUsers=1 Include_test=0 Include_launcher=0 PrependPath=0 TargetDir=C:\Python314' `
    -Wait -PassThru
if ($pythonProcess.ExitCode -ne 0) {
    throw "Python installation failed with exit code $($pythonProcess.ExitCode)"
}
Remove-Item $python -Force

$node = Get-VerifiedDownload `
    'https://nodejs.org/dist/v24.22.3/node-v24.22.3-x64.msi' `
    'node-v24.22.3-x64.msi' `
    '4a1ab5bdec5434bae58efae6c3e5077a011f6f1e76d2b47b7b10af043f7db545'
Install-Msi $node
Remove-Item $node -Force

$java = Get-VerifiedDownload `
    'https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.5%2B8/OpenJDK25U-jdk_x64_windows_hotspot_25.0.5_8.msi' `
    'OpenJDK25U-jdk_x64_windows_hotspot_25.0.5_8.msi' `
    'e1d3c94032579dc16af9abb311f4552ba271466b74c8767e8ce39585a4c64d40'
Install-Msi $java
Remove-Item $java -Force
$javaHome = Get-ChildItem 'C:\Program Files\Eclipse Adoptium' -Directory |
    Where-Object Name -Like 'jdk-25*' |
    Sort-Object Name -Descending |
    Select-Object -First 1 -ExpandProperty FullName
if (-not $javaHome) {
    throw 'Temurin JDK installation directory was not found'
}
[Environment]::SetEnvironmentVariable('JAVA_HOME', $javaHome, 'Machine')

$cmake = Get-VerifiedDownload `
    'https://github.com/Kitware/CMake/releases/download/v4.5.0/cmake-4.5.0-windows-x86_64.msi' `
    'cmake-4.5.0-windows-x86_64.msi' `
    '8e450caad4ce6bfb0f30206cac64bc611deee0d6848f4bf0ef30f51ff3606e25'
Install-Msi $cmake 'ADD_CMAKE_TO_PATH=System'
Remove-Item $cmake -Force

$dockerArchive = Get-VerifiedDownload `
    'https://download.docker.com/win/static/stable/x86_64/docker-29.9.3.zip' `
    'docker-29.9.3.zip' `
    '7c4ff7bbb31579046cd34dd8b91f7cbd3ab3482a1a85330170be726ef792d751'
Write-Host 'Installing Docker CLI'
$dockerExtract = Join-Path $temp 'docker'
Expand-Archive -Path $dockerArchive -DestinationPath $dockerExtract -Force
$dockerBinary = Get-ChildItem -Path $dockerExtract -Filter docker.exe -Recurse |
    Select-Object -First 1
if (-not $dockerBinary) {
    throw 'docker.exe was not present in the Docker CLI archive'
}
New-Item -ItemType Directory -Path 'C:\ProgramData\Docker' -Force | Out-Null
Copy-Item $dockerBinary.FullName 'C:\ProgramData\Docker\docker.exe' -Force
Remove-Item $dockerArchive -Force
Remove-Item $dockerExtract -Recurse -Force

$rustup = Get-VerifiedDownload `
    'https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe' `
    'rustup-init.exe' `
    '38027d51d69a5d05493627a0634dbea52d6cd793c8f072d2373d3f4163eec7db'
Write-Host 'Installing Rust toolchain'
$rustupProcess = Start-Process -FilePath $rustup `
    -ArgumentList '-y --no-modify-path --default-toolchain stable --profile minimal' `
    -Wait -PassThru
if ($rustupProcess.ExitCode -ne 0) {
    throw "Rust toolchain installation failed with exit code $($rustupProcess.ExitCode)"
}
Remove-Item $rustup -Force

$dotnet = Get-VerifiedDownload `
    'https://builds.dotnet.microsoft.com/dotnet/Sdk/10.0.404/dotnet-sdk-10.0.404-win-x64.exe' `
    'dotnet-sdk-10.0.404-win-x64.exe' `
    'c86b0aeb8c5ce0cd6dd290fb2b10bb112302d849d05cbcbcbc0ed4e5a15f66d1376e05bc77910bf66580d6a779390ec863e2bd6e51e7e21880d587b8b30c7b08' `
    -Algorithm SHA512
Write-Host 'Installing .NET SDK'
$dotnetProcess = Start-Process -FilePath $dotnet `
    -ArgumentList '/install /quiet /norestart' `
    -Wait -PassThru
if ($dotnetProcess.ExitCode -ne 0) {
    throw ".NET SDK installation failed with exit code $($dotnetProcess.ExitCode)"
}
Remove-Item $dotnet -Force

$nuget = Get-AuthenticodeVerifiedDownload `
    'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' `
    'nuget.exe'
New-Item -ItemType Directory -Path 'C:\ProgramData\NuGet' -Force | Out-Null
Move-Item $nuget 'C:\ProgramData\NuGet\nuget.exe' -Force

$sdks = & 'C:\Program Files\dotnet\dotnet.exe' --list-sdks
if (-not ($sdks | Where-Object { $_ -match '^10\.' })) {
    throw '.NET 10 SDK was not installed'
}

Remove-Item $temp -Recurse -Force
