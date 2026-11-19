param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$BuildArguments
)

$ErrorActionPreference = "Stop"

$Tb3Dir = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../jazzy-webots-tb3")).Path
$Tb3Key = Join-Path $Tb3Dir "ssh/id_ed25519_tb3_tp"
$Tb3Arguments = @()
$BuildTb3 = Test-Path -LiteralPath $Tb3Key -PathType Leaf

if ($BuildTb3) {
    $PublicKey = & ssh-keygen -y -f $Tb3Key
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
    $KeyInfo = $PublicKey | & ssh-keygen -lf -
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
    $Fingerprint = ($KeyInfo -split '\s+')[1]
    $Tb3Arguments = @('--secret', "id=tb3_ssh_key,src=$Tb3Key",
        '--build-arg', "TB3_SSH_KEY_FINGERPRINT=$Fingerprint")
} else {
    $Tb3Image = & docker image ls --quiet ros2-desktop-vnc:jazzy-webots-tb3
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
    $BuildTb3 = -not $Tb3Image
}

if ($BuildTb3) {
    & (Join-Path $Tb3Dir "build.ps1") @Tb3Arguments
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

& docker build `
    -t ros2-desktop-vnc:jazzy-webots-tb3-ned2 `
    @BuildArguments `
    $PSScriptRoot
exit $LASTEXITCODE
