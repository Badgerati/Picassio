##########################################################################
# Picassio is a provisioning/deployment script which uses a single linear
# JSON file to determine what commands to execute.
#
# Copyright (c) 2015, Matthew Kelly (Badgerati)
# Company: Cadaeic Studios
# License: MIT (see LICENSE for details)
#
# Example:
#
# {
#    "paint": [
#        {
#            "type": "msbuild",
#            "path": "C:\\path\\to\\msbuild.exe",
#            "projects": [
#                "C:\\path\\to\\project.csproj",
#                "C:\\path\\to\\solution.sln"
#            ],
#            "arguments": "/p:Configuration=Debug",
#            "clean": true
#        }
#    ]
# }
#########################################################################

# Use MSBuild to build a project or solution
Import-Module $env:PicassioTools -DisableNameChecking -ErrorAction Stop

function Start-Module($colour, $variables, $credentials)
{
    Test-Module $colour $variables $credentials

    $path = Replace-Variables $colour.path $variables
    if ([string]::IsNullOrWhiteSpace($path))
    {
        Write-Message 'No path supplied, using default.'
        $path = 'C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe'
    }
    else
    {
        $path = $path.Trim()
    }

    $projects = $colour.projects
    $clean = Replace-Variables $colour.clean $variables

    $_args = Replace-Variables $colour.arguments $variables
    if ([string]::IsNullOrWhiteSpace($_args))
    {
        $_args = [string]::Empty
    }

    ForEach ($project in $projects)
    {
        $project = (Replace-Variables $project $variables).Trim()
        if (!(Test-Path $project))
        {
            throw "Path to project for building does not exist: '$project'."
        }

        Push-Location (Split-Path $project -Parent)

        try
        {
            $file = (Split-Path $project -Leaf)

            Write-SubHeader "$file"
            Write-Information "Arguments: '$_args'."

            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            if (![string]::IsNullOrWhiteSpace($clean) -and $clean -eq $true)
            {
                Write-Host 'Cleaning...'
                Build-Project $path "/p:Configuration=Debug /t:Clean $project"
                Build-Project $path "/p:Configuration=Release /t:Clean $project"
            }

            Write-Host 'Building...'
            Build-Project $path "$_args $project"

            Write-Stamp ('Time taken: {0}' -f $stopwatch.Elapsed)
            Write-Message "Project built successfully."
            Write-NewLine
        }
        finally
        {
            Pop-Location
        }
    }
}

function Test-Module($colour, $variables, $credentials)
{
    $path = Replace-Variables $colour.path $variables
    if ([string]::IsNullOrWhiteSpace($path))
    {
        $path = 'C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe'
    }

    if (!(Test-Path ($path.Trim())))
    {
        throw "Invalid path to MSBuild.exe supplied: '$path'."
    }

    $clean = Replace-Variables $colour.clean $variables
    if (![string]::IsNullOrWhiteSpace($clean) -and $clean -ne $true -and $clean -ne $false)
    {
        throw "Invalid value for clean: '$clean'. Should be either true or false."
    }

    $projects = $colour.projects
    if ($projects -eq $null -or $projects.Length -eq 0)
    {
        throw 'No projects have been supplied for MSBuild.'
    }

    ForEach ($project in $projects)
    {
        if ([string]::IsNullOrWhiteSpace($project))
        {
            throw 'No path specified to build project.'
        }
    }
}


function Build-Project($command, $_args)
{
    Run-Command $command $_args
}
