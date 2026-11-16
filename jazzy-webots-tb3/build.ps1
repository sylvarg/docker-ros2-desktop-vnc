param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$BuildArguments
)

$ErrorActionPreference = "Stop"

& docker build `
    --build-arg WEBOTS_BACKEND=external `
    -t ros2-desktop-vnc:jazzy-webots-tb3-base `
    (Join-Path $PSScriptRoot "../jazzy-webots")
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

# Forward optional BuildKit secrets and other TB3 image build arguments.
& docker build `
    -t ros2-desktop-vnc:jazzy-webots-tb3 `
    @BuildArguments `
    $PSScriptRoot
exit $LASTEXITCODE
