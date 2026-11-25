[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Position = 0)]
    [ValidateSet('external', 'embedded')]
    [string]$WebotsVariant = 'external',
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$BuildArguments
)

$ErrorActionPreference = "Stop"

$Backend = 'external'
$PlatformArguments = @()
if ($WebotsVariant -eq 'embedded') {
    $Backend = 'bundled'
    $PlatformArguments = @('--platform', 'linux/amd64')
}

& docker build `
    @BuildArguments `
    @PlatformArguments `
    --build-arg "WEBOTS_BACKEND=$Backend" `
    -t "ros2-desktop-vnc:jazzy-webots-$WebotsVariant" `
    $PSScriptRoot
exit $LASTEXITCODE
