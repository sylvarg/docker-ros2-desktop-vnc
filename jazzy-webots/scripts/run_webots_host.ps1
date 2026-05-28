param(
    [string]$WebotsServerScript = $(if ($env:WEBOTS_SERVER_SCRIPT) { $env:WEBOTS_SERVER_SCRIPT } else { (Join-Path ([System.IO.Path]::GetTempPath()) "webots-server\local_simulation_server.py") }),
    [string]$WebotsHome = $(if ($env:WEBOTS_HOME) { $env:WEBOTS_HOME } else { "C:\Program Files\Webots" }),
    [string]$WebotsSharedHostDir = $(if ($env:WEBOTS_SHARED_HOST_DIR) { $env:WEBOTS_SHARED_HOST_DIR } else { (Join-Path ([System.IO.Path]::GetTempPath()) "ros2-desktop-vnc-webots-shared") })
)

$ErrorActionPreference = "Stop"

# This helper mirrors run_webots_host.sh for a native Windows host running the
# upstream Webots local simulation server.
#
# Note: when a system-wide PowerShell execution policy blocks direct .ps1
# execution, use the sibling run_webots_host.cmd launcher. It starts this
# script with `powershell.exe -ExecutionPolicy Bypass` for the current process
# only, which makes the workflow work out of the box from PowerShell, cmd, or a
# terminal embedded in an IDE.

$WebotsServerUrl = "https://raw.githubusercontent.com/cyberbotics/webots-server/main/local_simulation_server.py"
$PythonInstallManagerUrl = "https://www.python.org/downloads/latest/pymanager/"
$PythonInstallManagerWingetId = "9NQ7512CXL7T"
$PythonInstallManagerWingetSource = "msstore"

function Confirm-YesNo {
    param(
        [string]$Prompt
    )

    $answer = Read-Host "$Prompt [Y/n]"
    return [string]::IsNullOrWhiteSpace($answer) -or $answer -match '^(?i:y|yes)$'
}

function Ensure-WebotsServerScript {
    param(
        [string]$ScriptPath
    )

    if (Test-Path -LiteralPath $ScriptPath -PathType Leaf) {
        return $ScriptPath
    }

    $scriptDir = Split-Path -Parent $ScriptPath
    if (-not [string]::IsNullOrWhiteSpace($scriptDir)) {
        New-Item -ItemType Directory -Force -Path $scriptDir | Out-Null
    }

    Write-Host "Webots host server script not found locally. Downloading it now..."
    Write-Host "  URL=$WebotsServerUrl"
    Write-Host "  TARGET=$ScriptPath"

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    } catch {
        # Best effort only; modern PowerShell versions do not need this.
    }

    Invoke-WebRequest -Uri $WebotsServerUrl -OutFile $ScriptPath
    return $ScriptPath
}

function Get-WebotsExecutablePath {
    param(
        [string]$WebotsHome
    )

    $candidates = @(
        (Join-Path $WebotsHome "msys64\mingw64\bin\webotsw.exe"),
        (Join-Path $WebotsHome "msys64\mingw64\bin\webots.exe"),
        (Join-Path $WebotsHome "webotsw.exe"),
        (Join-Path $WebotsHome "webots.exe")
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    return $null
}

function Prepare-WebotsServerScriptForWindows {
    param(
        [string]$ScriptPath
    )

    $scriptText = Get-Content -LiteralPath $ScriptPath -Raw
    $patchedScriptPath = Join-Path (Split-Path -Parent $ScriptPath) (([System.IO.Path]::GetFileNameWithoutExtension($ScriptPath)) + ".windows.py")

    if ($scriptText.Contains("'WEBOTS_EXECUTABLE' in os.environ")) {
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($patchedScriptPath, $scriptText, $utf8NoBom)
        return $patchedScriptPath
    }

    $originalBlock = @"
    if os.path.isabs(command[0]):
        pass
    elif 'WEBOTS_HOME' in os.environ:
        path_suffix = 'Contents/MacOS/webots' if sys.platform == 'darwin' else 'webots'
        command[0] = os.path.join(os.environ['WEBOTS_HOME'], path_suffix)
    else:
        message = 'FAIL: WEBOTS_HOME environment variable is not defined. Please define a valid Webots installation folder.'
        close_connection(connection, message)
        continue
"@

    $replacementBlock = @"
    if os.path.isabs(command[0]):
        pass
    elif 'WEBOTS_EXECUTABLE' in os.environ:
        command[0] = os.environ['WEBOTS_EXECUTABLE']
    elif 'WEBOTS_HOME' in os.environ:
        if sys.platform == 'darwin':
            path_suffix = 'Contents/MacOS/webots'
        elif sys.platform == 'win32':
            path_suffix = os.path.join('msys64', 'mingw64', 'bin', 'webotsw.exe')
        else:
            path_suffix = 'webots'
        command[0] = os.path.join(os.environ['WEBOTS_HOME'], path_suffix)
    else:
        message = 'FAIL: WEBOTS_HOME environment variable is not defined. Please define a valid Webots installation folder.'
        close_connection(connection, message)
        continue
"@

    if (-not $scriptText.Contains($originalBlock)) {
        Write-Error "Unsupported local_simulation_server.py format: the Webots executable block could not be located in $ScriptPath."
        exit 1
    }

    $patchedScriptText = $scriptText.Replace($originalBlock, $replacementBlock)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($patchedScriptPath, $patchedScriptText, $utf8NoBom)
    return $patchedScriptPath
}

function Get-PythonLauncherCandidate {
    $candidates = New-Object System.Collections.Generic.List[object]
    $windowsAppsDir = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"

    $pyCommand = Get-Command py -ErrorAction SilentlyContinue
    if ($pyCommand) {
        $candidates.Add([pscustomobject]@{
            Executable = $pyCommand.Source
            Arguments = @("-3")
            Label = "py -3"
            RequiresVerification = $false
        })
    }

    $pyAliasPath = Join-Path $windowsAppsDir "py.exe"
    if (Test-Path -LiteralPath $pyAliasPath -PathType Leaf) {
        $candidates.Add([pscustomobject]@{
            Executable = $pyAliasPath
            Arguments = @("-3")
            Label = "py -3"
            RequiresVerification = $false
        })
    }

    Get-ChildItem -Path $windowsAppsDir -Directory -Filter "PythonSoftwareFoundation.PythonManager_*" -ErrorAction SilentlyContinue | ForEach-Object {
        $pyPath = Join-Path $_.FullName "py.exe"
        if (Test-Path -LiteralPath $pyPath -PathType Leaf) {
            $candidates.Add([pscustomobject]@{
                Executable = $pyPath
                Arguments = @("-3")
                Label = "py -3"
                RequiresVerification = $false
            })
        }
    }

    $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
    if ($pythonCommand) {
        $candidates.Add([pscustomobject]@{
            Executable = $pythonCommand.Source
            Arguments = @()
            Label = "python"
            RequiresVerification = $true
        })
    }

    foreach ($candidate in $candidates) {
        if (-not $candidate.RequiresVerification) {
            return $candidate
        }

        try {
            $testArgs = @($candidate.Arguments + @("-c", "import sys"))
            & $candidate.Executable @testArgs *> $null
            if ($LASTEXITCODE -eq 0) {
                return $candidate
            }
        } catch {
            continue
        }
    }

    return $null
}

function Install-PythonInstallManager {
    if (-not (Confirm-YesNo -Prompt "Python 3 was not detected. Install the official Python Install Manager now?")) {
        return $false
    }

    $wingetCommand = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetCommand) {
        Write-Host "Installing the official Python Install Manager with winget..."
        & $wingetCommand.Source install `
            $PythonInstallManagerWingetId `
            -e `
            --source $PythonInstallManagerWingetSource `
            --accept-source-agreements `
            --accept-package-agreements `
            --disable-interactivity
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "The Python Install Manager installation did not complete successfully (winget exit code: $LASTEXITCODE)."
            Write-Host "You can inspect winget logs under:"
            Write-Host "  $env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir"
            return $false
        }
        return $true
    }

    Write-Warning "winget was not found on this system."
    Write-Host "Opening the official Python Install Manager download page:"
    Write-Host "  $PythonInstallManagerUrl"
    Start-Process $PythonInstallManagerUrl
    Read-Host "Install the Python Install Manager, then press Enter here to continue"
    return $true
}

function Wait-ForPythonLauncherCandidate {
    param(
        [int]$TimeoutSeconds = 30
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    do {
        $candidate = Get-PythonLauncherCandidate
        if ($candidate) {
            return $candidate
        }

        Start-Sleep -Seconds 2
    } while ($stopwatch.Elapsed.TotalSeconds -lt $TimeoutSeconds)

    return $null
}

if (-not (Test-Path -LiteralPath $WebotsHome -PathType Container)) {
    Write-Error "Webots installation not found at: $WebotsHome`nSet WEBOTS_HOME to your native Windows Webots installation."
    exit 1
}

if ([string]::IsNullOrWhiteSpace($WebotsServerScript)) {
    Write-Error @"
Missing WEBOTS_SERVER_SCRIPT.
Example:
  .\scripts\run_webots_host.cmd

or, with an explicit path:
  .\scripts\run_webots_host.cmd -WebotsServerScript C:\path\to\local_simulation_server.py
"@
    exit 1
}

$WebotsServerScript = Ensure-WebotsServerScript -ScriptPath $WebotsServerScript
$webotsExecutable = Get-WebotsExecutablePath -WebotsHome $WebotsHome
if (-not $webotsExecutable) {
    Write-Error @"
No supported Webots executable was found under: $WebotsHome
The Windows helper looked for:
  - $([System.IO.Path]::Combine($WebotsHome, 'msys64\mingw64\bin\webotsw.exe'))
  - $([System.IO.Path]::Combine($WebotsHome, 'msys64\mingw64\bin\webots.exe'))
  - $([System.IO.Path]::Combine($WebotsHome, 'webotsw.exe'))
  - $([System.IO.Path]::Combine($WebotsHome, 'webots.exe'))
If your installation lives elsewhere, re-run the script with -WebotsHome or set WEBOTS_HOME first.
"@
    exit 1
}

$WebotsServerScript = Prepare-WebotsServerScriptForWindows -ScriptPath $WebotsServerScript

New-Item -ItemType Directory -Force -Path $WebotsSharedHostDir | Out-Null

$env:WEBOTS_HOME = $WebotsHome
$env:WEBOTS_EXECUTABLE = $webotsExecutable
$env:WEBOTS_SERVER_SCRIPT = $WebotsServerScript
$env:WEBOTS_SHARED_HOST_DIR = $WebotsSharedHostDir

Write-Host "Starting native Webots host server"
Write-Host "  WEBOTS_HOME=$WebotsHome"
Write-Host "  WEBOTS_EXECUTABLE=$webotsExecutable"
Write-Host "  WEBOTS_SERVER_SCRIPT=$WebotsServerScript"
Write-Host "  WEBOTS_SHARED_HOST_DIR=$WebotsSharedHostDir"

$pythonCandidate = Get-PythonLauncherCandidate
if (-not $pythonCandidate) {
    if (-not (Install-PythonInstallManager)) {
        Write-Error "Python installation was declined or did not complete. Aborting."
        exit 1
    }

    Write-Host "Waiting for the Python Install Manager to become available..."
    $pythonCandidate = Wait-ForPythonLauncherCandidate
    if (-not $pythonCandidate) {
        Write-Error "Python is still not available after the installation step. Re-run this script after the official Python Install Manager has finished installing."
        exit 1
    }
}

Write-Host "Using Python launcher: $($pythonCandidate.Label)"
& $pythonCandidate.Executable @($pythonCandidate.Arguments + @($WebotsServerScript))
exit $LASTEXITCODE
