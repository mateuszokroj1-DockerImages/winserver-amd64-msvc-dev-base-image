# escape=`
FROM mcr.microsoft.com/windows/server:ltsc2025@sha256:b0a62a6e3590a063f3211efbec59d25c248e44e0890196ef9b7b8c06d60c4785

SHELL ["powershell", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "$ErrorActionPreference = 'Stop';"]

ENV CARGO_HOME=C:\Cargo `
    RUSTUP_HOME=C:\Rustup `
    VCPKG_ROOT=C:\Users\ContainerUser\vcpkg `
    DOTNET_ROOT="C:\Program Files\dotnet" `
    JAVA_HOME="C:\Program Files\Eclipse Adoptium\jdk-25.0.5.8-hotspot" `
    PATH="C:\Program Files\PowerShell\7;C:\Program Files\Git\cmd;C:\Program Files\nodejs;C:\Python314;C:\Python314\Scripts;C:\Program Files\Eclipse Adoptium\jdk-25.0.5.8-hotspot\bin;C:\Program Files\CMake\bin;C:\Program Files\dotnet;C:\Cargo\bin;C:\ProgramData\Docker;C:\ProgramData\NuGet;C:\Users\ContainerUser\vcpkg;C:\Windows\system32;C:\Windows;C:\Windows\System32\Wbem;C:\Windows\System32\WindowsPowerShell\v1.0;C:\Windows\System32\OpenSSH"

WORKDIR C:\workspace

COPY Install-Tools.ps1 C:\Install-Tools.ps1
COPY Enter-VsDevShell.ps1 C:\Enter-VsDevShell.ps1

RUN C:\Install-Tools.ps1
RUN Remove-Item C:\Install-Tools.ps1 -Force

USER ContainerUser

RUN git clone --quiet --depth 1 --branch 2026.10.16 https://github.com/microsoft/vcpkg.git $env:VCPKG_ROOT; `
    $revision = (git -C $env:VCPKG_ROOT rev-parse HEAD).Trim(); `
    if ($revision -ne '9eec002df1cd109f8f104cd966a763daf9751489') { throw "Unexpected vcpkg revision: $revision" }; `
    & "$env:VCPKG_ROOT\bootstrap-vcpkg.bat" -disableMetrics; `
    if ($LASTEXITCODE -ne 0) { throw 'vcpkg bootstrap failed' }

ENTRYPOINT ["powershell.exe", "-NoLogo", "-NoExit", "-ExecutionPolicy", "Bypass", "-File", "C:\\Enter-VsDevShell.ps1"]
