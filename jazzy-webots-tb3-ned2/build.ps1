param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$BuildArguments
)

$ErrorActionPreference = "Stop"

$Tb3Dir = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../jazzy-webots-tb3")).Path
$Tb3Key = Join-Path $Tb3Dir "ssh/id_ed25519_tb3_tp"
$BuildTb3 = Test-Path -LiteralPath $Tb3Key -PathType Leaf

if (-not $BuildTb3) {
    $Tb3Image = & docker image ls --quiet ros2-desktop-vnc:jazzy-webots-tb3
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
    $BuildTb3 = -not $Tb3Image
}

if ($BuildTb3) {
    # TB3 handles key detection, the BuildKit secret and fingerprint caching.
    & (Join-Path $Tb3Dir "build.ps1")
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

& docker build `
    -t ros2-desktop-vnc:jazzy-webots-tb3-ned2 `
    @BuildArguments `
    $PSScriptRoot
exit $LASTEXITCODE
