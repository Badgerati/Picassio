# Use MSBuild to build a project or solution
Import-Module $env:PicassoTools -DisableNameChecking

function Start-Module($colour) {
    $path = $colour.path
    if (!(Test-Path $path)) {
        throw "Path to MSBuild.exe does not exist: '$path'"
    }

    $project = $colour.project
    if (!(Test-Path $project)) {
        throw "Path to project for building does not exist: '$project'"
    }

    Push-Location (Split-Path $project -Parent)
    $file = (Split-Path $project -Leaf)

    $args = $colour.arguments
    $command = "$path $args $project"

    Write-Message "Building project: '$file'."
    (cmd.exe /C $command) | Out-Null

    if (!$?) {
        Pop-Location
        throw "Failed to build project '$file'."
    }

    Pop-Location
    Write-Message "Project '$file' built successfully."
}