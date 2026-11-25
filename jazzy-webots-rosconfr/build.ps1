[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Position = 0)]
    [ValidateSet('external', 'embedded')]
    [string]$WebotsVariant = 'external',
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$BuildArguments
)

$ErrorActionPreference = "Stop"

# Match the parent platform; other build options apply to ROSCon only.
$ParentArguments = @()
$NextIsPlatform = $false
foreach ($Argument in $BuildArguments) {
    if ($NextIsPlatform) {
        $ParentArguments += @('--platform', $Argument)
        $NextIsPlatform = $false
    } elseif ($Argument -eq '--platform') {
        $NextIsPlatform = $true
    } elseif ($Argument.StartsWith('--platform=')) {
        $ParentArguments += $Argument
    }
}
if ($NextIsPlatform) {
    throw '--platform requires a value.'
}

& (Join-Path $PSScriptRoot '../jazzy-webots/build.ps1') `
    -WebotsVariant $WebotsVariant @ParentArguments
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$PlatformArguments = @()
if ($WebotsVariant -eq 'embedded') {
    $PlatformArguments = @('--platform', 'linux/amd64')
}

& docker build `
    @BuildArguments `
    @PlatformArguments `
    --build-arg BASE_IMAGE_REPOSITORY=ros2-desktop-vnc `
    --build-arg "WEBOTS_BACKEND=$WebotsVariant" `
    -t ros2-desktop-vnc:jazzy-webots-rosconfr `
    $PSScriptRoot
exit $LASTEXITCODE
