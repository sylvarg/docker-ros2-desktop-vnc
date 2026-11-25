param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$BuildArguments = @()
)

$ErrorActionPreference = "Stop"

$Tb3Key = Join-Path $PSScriptRoot "ssh/id_ed25519_tb3_tp"
$ExplicitTb3Key = $false
$NextIsSecret = $false
foreach ($Argument in $BuildArguments) {
    $SecretSpec = ''
    if ($NextIsSecret) {
        $SecretSpec = $Argument
        $NextIsSecret = $false
    } elseif ($Argument -eq '--secret') {
        $NextIsSecret = $true
    } elseif ($Argument.StartsWith('--secret=')) {
        $SecretSpec = $Argument.Substring('--secret='.Length)
    }
    if (",$SecretSpec," -match ',id=tb3_ssh_key,') {
        $ExplicitTb3Key = $true
    }
}

if (-not $ExplicitTb3Key -and (Test-Path -LiteralPath $Tb3Key -PathType Leaf)) {
    $PublicKey = & ssh-keygen -y -f $Tb3Key
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
    $KeyInfo = $PublicKey | & ssh-keygen -lf -
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
    $Fingerprint = ($KeyInfo -split '\s+')[1]
    $BuildArguments = @('--secret', "id=tb3_ssh_key,src=$Tb3Key",
        '--build-arg', "TB3_SSH_KEY_FINGERPRINT=$Fingerprint") + @($BuildArguments)
    Write-Host "Using lab SSH key: $Tb3Key"
}

# Build the shared external parent from this checkout, using its standard tag.
& (Join-Path $PSScriptRoot "../jazzy-webots/build.ps1") -WebotsVariant external
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

# Forward optional BuildKit secrets and other TB3 image build arguments.
& docker build `
    -t ros2-desktop-vnc:jazzy-webots-tb3 `
    @BuildArguments `
    $PSScriptRoot
exit $LASTEXITCODE
