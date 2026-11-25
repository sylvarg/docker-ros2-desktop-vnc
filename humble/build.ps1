param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$BuildArguments
)

$ErrorActionPreference = "Stop"

# Keep the historical Compose image name as an additional local tag.
& docker build `
    -t ros2-desktop-vnc:humble `
    -t sylar/ros2-desktop-vnc:humble `
    @BuildArguments `
    $PSScriptRoot
exit $LASTEXITCODE
