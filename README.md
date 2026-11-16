# Windows Server Dev Base Image

Windows development image based on the Windows Server LTSC 2025 Server Core
container image. It includes Git and Git LFS, PowerShell 7, Python, Node.js,
OpenJDK, Cargo, the Docker CLI, CMake, MSVC Build Tools, .NET SDK 10,
.NET Framework 4.8 targeting tools, NuGet, and vcpkg.

## Build

Build on a Windows Server 2025 host with Windows containers enabled. Windows
containers require a compatible Windows host; a Linux Docker daemon cannot
build this image.

```powershell
docker build --pull -t mateuszokroj1/winserver-dev-base-image:latest .
```

The base image is pinned to a reviewed manifest digest. Update the digest
deliberately after checking the new `mcr.microsoft.com/windows/server:ltsc2025`
manifest and its security advisories.

## Installed tools

| Tool | Version / source |
|---|---|
| Windows Server | LTSC 2025, pinned to a manifest digest |
| Git for Windows | 2.56.1 |
| Git LFS | 3.8.1 |
| PowerShell | 7.7.0, official archive verified with SHA-256 |
| Python | 3.14.9 |
| Node.js | 24.22.3 LTS, official MSI verified with SHA-256 |
| OpenJDK | Eclipse Temurin 25.0.5+8, MSI verified with SHA-256 |
| Cargo / Rust | Stable x64 MSVC toolchain installed by the checksum-verified rustup installer |
| Docker | Docker CLI 29.9.3, official archive verified with SHA-256; no Docker daemon |
| CMake | 4.5.0, official MSI verified with SHA-256 |
| MSVC | Visual Studio Build Tools 2022, x64 C++ tools |
| .NET SDK | 10.0.404, installer verified with SHA-512 |
| .NET Framework | 4.8 targeting pack; framework runtime is provided by Windows |
| NuGet | Current official `nuget.exe` |
| vcpkg | Repository revision `9eec002df1cd109f8f104cd966a763daf9751489` |

Installer/archive digests are checked during image build where the upstream
publishes a stable release artifact. Signed Windows installers and binaries
are also required to pass Authenticode validation before execution. The
Visual Studio bootstrapper and NuGet command-line tool follow their official
vendor download channels.

## Startup shell

The container starts in `C:\workspace` as the unprivileged `ContainerUser`.
Its default entrypoint initializes the x64 Visual Studio Developer Shell in
Windows PowerShell. Use `docker run -it --rm
mateuszokroj1/winserver-dev-base-image:latest` to start it interactively.

Vcpkg is checked out and bootstrapped at
`C:\Users\ContainerUser\vcpkg`; `VCPKG_ROOT` points to that repository.

The image includes Docker client tools only. To use Docker commands, provide
access to a compatible host Docker daemon; do not expose a host Docker endpoint
to untrusted containers.

## CI/CD

GitHub Actions has separate workflows for pull requests and deployment. The
pull-request workflow builds and smoke-tests the image for pull requests
targeting `main`. The deployment workflow runs only on pushes to `main`; it
builds and smoke-tests the image, then uses Docker Scout to block publication
if high or critical vulnerabilities are found. Only after a successful scan
is the image tagged `latest` and published to Docker Hub.

Configure the repository secrets `DOCKER_LOGIN` and `DOCKER_PASS` for the
deployment workflow. No changes or image were pushed while preparing this
repository content.
