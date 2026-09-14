# ==============================================================================
# AiBL Author CLI - Automated Standalone Installer for Windows (PowerShell)
# ==============================================================================
# Usage:
#   Invoke-WebRequest -Uri "https://raw.githubusercontent.com/opmediainc/aibl-author-installs/master/cli/install.ps1" -OutFile "install-aibl.ps1"; powershell -ExecutionPolicy ByPass -c '.\install-aibl.ps1'; Remove-Item install-aibl.ps1
# ==============================================================================

$ErrorActionPreference = 'Stop'

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

function Print-Banner {
    $banner = @'

    ___      _   ____   __         ___             __     __                
   /   |    (_) / __ ) / /        /   |  __  __   / /_   / /_   ____   _____
  / /| |   / / / __  |/ /        / /| | / / / /  / __/  / __ \ / __ \ / ___/
 / ___ |  / / / /_/ // /___     / ___ |/ /_/ /  / /_   / / / // /_/ // /    
/_/  |_| /_/ /_____//_____/    /_/  |_|\__,_/   \__/  /_/ /_/ \____//_/     
                                                                             
'@
    Write-Host $banner -ForegroundColor Cyan
    Write-Host "AiBL Author CLI & MCP Automated Installer" -ForegroundColor White
    Write-Host "https://demo.aiblx.ai`n" -ForegroundColor DarkGray
}

function Write-Info {
    param([string]$message)
    Write-Host "[*] $message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$message)
    Write-Host "[+] $message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$message)
    Write-Host "[!] $message" -ForegroundColor Yellow
}

function Write-Err {
    param([string]$message)
    Write-Host "[x] $message" -ForegroundColor Red
}

$AiblHome = Join-Path $HOME ".aibl"
$RuntimeDir = Join-Path $AiblHome "runtime"
$NodeDir = Join-Path $RuntimeDir "node"
$BinDir = Join-Path $AiblHome "bin"
$NodeVersion = "v22.14.0"
$PackageName = "@op-media-inc/aibl-author-cli"

function Detect-Architecture {
    $arch = "win-x64"
    try {
        $osArch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
        if ($osArch -eq "Arm64") {
            $arch = "win-arm64"
        } elseif ($osArch -eq "X86") {
            $arch = "win-x86"
        }
    } catch {
        if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") {
            $arch = "win-arm64"
        } elseif (-not [System.Environment]::Is64BitOperatingSystem) {
            $arch = "win-x86"
        }
    }
    Write-Info "Detected Windows architecture: $arch"
    return $arch
}

function Setup-NodeRuntime {
    param([string]$arch)

    New-Item -ItemType Directory -Force -Path $AiblHome | Out-Null
    New-Item -ItemType Directory -Force -Path $RuntimeDir | Out-Null
    New-Item -ItemType Directory -Force -Path $BinDir | Out-Null

    $nodeExe = Join-Path $NodeDir "node.exe"
    $needDownload = $true

    if (Test-Path $nodeExe) {
        try {
            $installedVer = (& $nodeExe -v 2>$null).Trim()
            if ($installedVer -eq $NodeVersion) {
                Write-Info "Standalone Node.js LTS ($NodeVersion) runtime already provisioned."
                return "existing"
            }
        } catch {
            $needDownload = $true
        }
    }

    if ($needDownload) {
        Write-Info "Provisioning isolated Node.js runtime ($NodeVersion) into $NodeDir..."
        $zipName = "node-$NodeVersion-$arch.zip"
        $downloadUrl = "https://nodejs.org/dist/$NodeVersion/$zipName"
        $tempZip = Join-Path $env:TEMP $zipName
        $tempExtract = Join-Path $env:TEMP "node_extract_$([guid]::NewGuid().ToString('N'))"

        Write-Info "Downloading Node.js archive from nodejs.org..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip -UseBasicParsing

        if (Test-Path $NodeDir) {
            Remove-Item -Recurse -Force $NodeDir
        }

        Write-Info "Extracting runtime binaries..."
        Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force
        
        # Node zip contains a root folder e.g. node-v22.14.0-win-x64
        $extractedFolder = Get-ChildItem -Path $tempExtract -Directory | Select-Object -First 1
        Move-Item -Path $extractedFolder.FullName -Destination $NodeDir -Force

        # Cleanup temporary files
        Remove-Item -Force $tempZip -ErrorAction SilentlyContinue
        Remove-Item -Recurse -Force $tempExtract -ErrorAction SilentlyContinue

        Write-Success "Node.js runtime provisioned successfully."
    }

    return "isolated"
}

function Install-CLI {
    param([string]$runtimeType = "isolated")

    Write-Info "Installing $PackageName in $runtimeType runtime..."
    $npmCmd = Join-Path $NodeDir "npm.cmd"

    $process = Start-Process -FilePath $npmCmd -ArgumentList "install", "-g", "--prefix", "`"$RuntimeDir`"", "$PackageName@latest", "--no-audit", "--no-fund" -NoNewWindow -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        Write-Err "npm install exited with code $($process.ExitCode). Retrying with verbose logging..."
        & $npmCmd install -g --prefix "$RuntimeDir" "$PackageName@latest"
    }

    Write-Success "AiBL Author CLI installed."
}

function Setup-Executables {
    $wrapperCmd = Join-Path $BinDir "aibl.cmd"
    $cmdContent = @'
@ECHO OFF
SETLOCAL
SET "AIBL_DIR=%USERPROFILE%\.aibl"
SET "NODE_EXE=%AIBL_DIR%\runtime\node\node.exe"
SET "CLI_ENTRY=%AIBL_DIR%\runtime\node_modules\@op-media-inc\aibl-author-cli\dist\index.js"

SET "PATH=%AIBL_DIR%\runtime\node;%AIBL_DIR%\bin;%PATH%"

IF EXIST "%CLI_ENTRY%" (
  "%NODE_EXE%" "%CLI_ENTRY%" %*
) ELSE IF EXIST "%AIBL_DIR%\runtime\aibl.cmd" (
  "%AIBL_DIR%\runtime\aibl.cmd" %*
) ELSE (
  ECHO Error: AiBL Author CLI executable not found in %AIBL_DIR%\runtime. >&2
  EXIT /B 1
)
'@
    Set-Content -Path $wrapperCmd -Value $cmdContent -Encoding ASCII

    $wrapperPs1 = Join-Path $BinDir "aibl.ps1"
    $ps1Content = @'
$AiblDir = Join-Path $HOME ".aibl"
$NodeExe = Join-Path $AiblDir "runtime\node\node.exe"
$CliEntry = Join-Path $AiblDir "runtime\node_modules\@op-media-inc\aibl-author-cli\dist\index.js"

$env:PATH = "$(Join-Path $AiblDir 'runtime\node');$(Join-Path $AiblDir 'bin');$env:PATH"

if (Test-Path $CliEntry) {
    & $NodeExe $CliEntry @args
} elseif (Test-Path (Join-Path $AiblDir "runtime\aibl.cmd")) {
    & (Join-Path $AiblDir "runtime\aibl.cmd") @args
} else {
    Write-Error "AiBL Author CLI executable not found in $AiblDir\runtime."
    exit 1
}
'@
    Set-Content -Path $wrapperPs1 -Value $ps1Content -Encoding UTF8

    Write-Success "Executable wrappers configured in $BinDir"
}

function Configure-EnvironmentPath {
    try {
        $userPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
        $pathList = if ([string]::IsNullOrWhiteSpace($userPath)) { @() } else { $userPath -split ';' }
        
        if (-not ($pathList -contains $BinDir)) {
            $newPath = if ([string]::IsNullOrWhiteSpace($userPath)) { $BinDir } else { "$BinDir;$userPath" }
            [Environment]::SetEnvironmentVariable("Path", $newPath, [EnvironmentVariableTarget]::User)
            Write-Info "Permanently added $BinDir to User PATH."
        }

        # Update current session PATH
        if (-not ($env:PATH -split ';' -contains $BinDir)) {
            $env:PATH = "$BinDir;$env:PATH"
        }
    } catch {
        Write-Warn "Could not automatically update User PATH: $($_.Exception.Message)"
    }
}

function Configure-ClaudeDesktop {
    $claudeConfigDir = Join-Path $env:APPDATA "Claude"
    if (Test-Path $claudeConfigDir) {
        Write-Info "Detected Claude Desktop installation. Configuring AiBL MCP bridge..."
        $aiblCmd = Join-Path $BinDir "aibl.cmd"
        try {
            & $aiblCmd mcp setup claude-desktop --force 2>$null | Out-Null
            Write-Success "Claude Desktop MCP bridge configured."
        } catch {
            Write-Warn "Could not automatically configure Claude Desktop: $($_.Exception.Message)"
        }
    }
}

function Configure-ChatGPT {
    $codexDir = Join-Path $HOME ".codex"
    $codexConfig = Join-Path $codexDir "config.toml"
    if ((Test-Path $codexDir) -or (Test-Path $codexConfig)) {
        Write-Info "Detected ChatGPT (Codex) installation. Configuring AiBL MCP bridge..."
        $aiblCmd = Join-Path $BinDir "aibl.cmd"
        try {
            & $aiblCmd mcp setup chatgpt --force 2>$null | Out-Null
            Write-Success "ChatGPT (Codex) MCP bridge configured."
        } catch {
            Write-Warn "Could not automatically configure ChatGPT (Codex): $($_.Exception.Message)"
        }
    }
}

function Main {
    Print-Banner
    $arch = Detect-Architecture
    $runtimeType = Setup-NodeRuntime $arch
    Install-CLI -runtimeType $runtimeType
    Setup-Executables
    Configure-EnvironmentPath
    Configure-ClaudeDesktop
    Configure-ChatGPT

    Write-Host "`n======================================================" -ForegroundColor Green
    Write-Host "       AiBL Author CLI Setup Complete!" -ForegroundColor Green
    Write-Host "======================================================`n" -ForegroundColor Green

    $version = "1.0.3"
    try {
        $aiblCmd = Join-Path $BinDir "aibl.cmd"
        $vOutput = (& $aiblCmd --version 2>$null)
        if (-not [string]::IsNullOrWhiteSpace($vOutput)) {
            $version = $vOutput.Trim()
        }
    } catch {}

    Write-Host "  - Installed Version : v$version" -ForegroundColor White
    Write-Host "  - Default Context   : cloud (https://demo.aiblx.ai)" -ForegroundColor Cyan
    Write-Host "  - Executable Path   : $(Join-Path $BinDir 'aibl.cmd')`n" -ForegroundColor DarkGray

    Write-Host "Next Steps:" -ForegroundColor White
    Write-Host "  1. Authenticate with your AiBL account:"
    Write-Host "     aibl auth`n" -ForegroundColor Cyan
    Write-Host "  2. (Optional) If Claude Desktop or ChatGPT / Codex was open, quit completely and reopen it.`n"
    Write-Host "  3. If 'aibl' command is not recognized in existing terminals, open a new PowerShell window.`n"
}

Main