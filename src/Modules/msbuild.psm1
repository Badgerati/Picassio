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
#            "toolpath": "C:\\path\\to\\msbuild.exe",
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

    $toolpath = Replace-Variables $colour.toolpath $variables
    if ([string]::IsNullOrWhiteSpace($toolpath))
    {
        Write-Message 'No MSBuild tool path supplied, using default.'
        $toolpath = 'C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe'
    }
    else
    {
        $toolpath = $toolpath.Trim()
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
                Build-Project $toolpath "/p:Configuration=Debug /t:Clean $project"
                Build-Project $toolpath "/p:Configuration=Release /t:Clean $project"
            }

            Write-Host 'Building...'
            Build-Project $toolpath "$_args $project"

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
    $toolpath = Replace-Variables $colour.toolpath $variables
    if ([string]::IsNullOrWhiteSpace($toolpath))
    {
        $toolpath = 'C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe'
    }

    if (!(Test-Path ($toolpath.Trim())))
    {
        throw "Invalid tool path to MSBuild.exe supplied: '$toolpath'."
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
