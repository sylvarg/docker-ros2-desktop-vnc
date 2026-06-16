param(
    [string]$EnvFile,
    [string]$WebotsHome = $(if ($env:WEBOTS_HOME) { $env:WEBOTS_HOME } else { "C:\Program Files\Webots" }),
    [string]$WebotsSharedHostDir = $(if ($env:WEBOTS_SHARED_HOST_DIR) { $env:WEBOTS_SHARED_HOST_DIR } else { "" }),
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ServerArguments
)

$ErrorActionPreference = "Stop"

$ServerScript = Join-Path $PSScriptRoot "local_simulation_server.py"
$PythonInstallManagerUrl = "https://www.python.org/downloads/latest/pymanager/"
$PythonInstallManagerWingetId = "9NQ7512CXL7T"
$PythonInstallManagerWingetSource = "msstore"

function Show-Usage {
    Write-Host @"
Usage:
  .\run_webots_host.cmd --env-file <path> [server-port]
  .\run_webots_host.ps1 -EnvFile <path> [server-port]

Optional PowerShell named arguments:
  -WebotsHome <path>
  -WebotsSharedHostDir <path>
"@
}

function Confirm-YesNo {
    param(
        [string]$Prompt
    )

    $answer = Read-Host "$Prompt [Y/n]"
    return [string]::IsNullOrWhiteSpace($answer) -or $answer -match '^(?i:y|yes)$'
}

function Import-EnvFileValues {
    param(
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-Error "Env file not found: $Path"
        exit 1
    }

    $values = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
            continue
        }

        $separatorIndex = $trimmed.IndexOf('=')
        if ($separatorIndex -lt 1) {
            continue
        }

        $key = $trimmed.Substring(0, $separatorIndex).Trim()
        $value = $trimmed.Substring($separatorIndex + 1).Trim()

        if (
            ($value.StartsWith('"') -and $value.EndsWith('"')) -or
            ($value.StartsWith("'") -and $value.EndsWith("'"))
        ) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        $values[$key] = $value
    }

    return $values
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

function Resolve-LauncherArguments {
    param(
        [string]$EnvFile,
        [bool]$EnvFileWasProvided,
        [string[]]$Arguments
    )

    $forwardedArguments = New-Object System.Collections.Generic.List[string]

    for ($index = 0; $index -lt $Arguments.Count; $index++) {
        $argument = $Arguments[$index]

        if ($argument -eq '--env-file') {
            if ($EnvFileWasProvided) {
                Write-Error "Env file was specified more than once. Use either -EnvFile or --env-file, not both."
                exit 1
            }

            if ($index + 1 -ge $Arguments.Count) {
                Show-Usage
                Write-Error "--env-file requires a path."
                exit 1
            }

            $EnvFile = $Arguments[$index + 1]
            $EnvFileWasProvided = $true
            $index++
            continue
        }

        if ($argument.StartsWith('--env-file=')) {
            if ($EnvFileWasProvided) {
                Write-Error "Env file was specified more than once. Use either -EnvFile or --env-file, not both."
                exit 1
            }

            $EnvFile = $argument.Substring('--env-file='.Length)
            if ([string]::IsNullOrWhiteSpace($EnvFile)) {
                Show-Usage
                Write-Error "--env-file requires a path."
                exit 1
            }

            $EnvFileWasProvided = $true
            continue
        }

        $forwardedArguments.Add($argument)
    }

    return [pscustomobject]@{
        EnvFile = $EnvFile
        ServerArguments = $forwardedArguments.ToArray()
    }
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

if (-not (Test-Path -LiteralPath $ServerScript -PathType Leaf)) {
    Write-Error "Repository-local Webots server script not found: $ServerScript"
    exit 1
}

$resolvedLauncherArguments = Resolve-LauncherArguments `
    -EnvFile $EnvFile `
    -EnvFileWasProvided $PSBoundParameters.ContainsKey('EnvFile') `
    -Arguments $ServerArguments

$EnvFile = $resolvedLauncherArguments.EnvFile
$ServerArguments = $resolvedLauncherArguments.ServerArguments

if ([string]::IsNullOrWhiteSpace($EnvFile)) {
    Show-Usage
    Write-Error "Env file path is required. Use -EnvFile <path> or --env-file <path>."
    exit 1
}

$envFileValues = Import-EnvFileValues -Path $EnvFile

if (-not $PSBoundParameters.ContainsKey('WebotsHome') -and $envFileValues.ContainsKey('WEBOTS_HOME') -and -not [string]::IsNullOrWhiteSpace($envFileValues['WEBOTS_HOME'])) {
    $WebotsHome = $envFileValues['WEBOTS_HOME']
}

if (-not $PSBoundParameters.ContainsKey('WebotsSharedHostDir') -and $envFileValues.ContainsKey('WEBOTS_SHARED_HOST_DIR') -and -not [string]::IsNullOrWhiteSpace($envFileValues['WEBOTS_SHARED_HOST_DIR'])) {
    $WebotsSharedHostDir = $envFileValues['WEBOTS_SHARED_HOST_DIR']
}

if ([string]::IsNullOrWhiteSpace($WebotsSharedHostDir)) {
    Write-Error "WEBOTS_SHARED_HOST_DIR is required in $EnvFile"
    exit 1
}

if (-not (Test-Path -LiteralPath $WebotsHome -PathType Container)) {
    Write-Error "Webots installation not found at: $WebotsHome`nSet WEBOTS_HOME in the env file or your shell environment."
    exit 1
}

$webotsExecutable = Get-WebotsExecutablePath -WebotsHome $WebotsHome
if (-not $webotsExecutable) {
    Write-Error @"
No supported Webots executable was found under: $WebotsHome
The Windows helper looked for:
  - $([System.IO.Path]::Combine($WebotsHome, 'msys64\mingw64\bin\webotsw.exe'))
  - $([System.IO.Path]::Combine($WebotsHome, 'msys64\mingw64\bin\webots.exe'))
  - $([System.IO.Path]::Combine($WebotsHome, 'webotsw.exe'))
  - $([System.IO.Path]::Combine($WebotsHome, 'webots.exe'))
If your installation lives elsewhere, re-run the script with -WebotsHome or update WEBOTS_HOME in the env file.
"@
    exit 1
}

New-Item -ItemType Directory -Force -Path $WebotsSharedHostDir | Out-Null

$env:WEBOTS_HOME = $WebotsHome
$env:WEBOTS_EXECUTABLE = $webotsExecutable
$env:WEBOTS_SHARED_HOST_DIR = $WebotsSharedHostDir

Write-Host "Launching repository-local Webots host server..."
Write-Host "  ENV_FILE=$EnvFile"

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
& $pythonCandidate.Executable @($pythonCandidate.Arguments + @($ServerScript) + $ServerArguments)
exit $LASTEXITCODE
