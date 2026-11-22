# escape=`
FROM mcr.microsoft.com/dotnet/framework/runtime:4.8.1-windowsservercore-ltsc2025

SHELL ["powershell", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "$ErrorActionPreference = 'Stop';"]

ENV CARGO_HOME=C:\Cargo `
    RUSTUP_HOME=C:\Rustup `
    DOTNET_ROOT="C:\Program Files\dotnet" `
    JAVA_HOME="C:\Program Files\Eclipse Adoptium\jdk-25.0.5.8-hotspot" `
    PATH="C:\Program Files\PowerShell\7;C:\Program Files\Git\cmd;C:\Program Files\nodejs;C:\Python314;C:\Python314\Scripts;C:\Program Files\Eclipse Adoptium\jdk-25.0.5.8-hotspot\bin;C:\Program Files\CMake\bin;C:\Program Files\dotnet;C:\Cargo\bin;C:\ProgramData\Docker;C:\ProgramData\NuGet;C:\Users\ContainerUser\vcpkg;C:\Windows\system32;C:\Windows;C:\Windows\System32\Wbem;C:\Windows\System32\WindowsPowerShell\v1.0;C:\Windows\System32\OpenSSH"

WORKDIR C:\workspace

COPY Install-Tools.ps1 C:\Install-Tools.ps1
COPY Install-VsBuildTools.ps1 C:\Install-VsBuildTools.ps1
COPY Enter-VsDevShell.ps1 C:\Enter-VsDevShell.ps1

RUN C:\Install-Tools.ps1
RUN Remove-Item C:\Install-Tools.ps1 -Force

USER ContainerUser

USER ContainerAdministrator
RUN C:\Install-VsBuildTools.ps1
RUN Remove-Item C:\Install-VsBuildTools.ps1 -Force

ENTRYPOINT ["powershell.exe", "-NoLogo", "-NoExit", "-ExecutionPolicy", "Bypass", "-File", "C:\\Enter-VsDevShell.ps1"]
