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
#   "paint": [
#       {
#           "type": "nuget",
#           "ensure": "install",
#           "packages": {
#              "NewtonSoft.Json": "latest",
#              "JQuery": "2.2.2"
#           },
#           "path": "C:\\to\\install\\packages"
#       },
#       {
#           "type": "nuget",
#           "ensure": "install",
#           "source": "C:\\path\\to\\soltuion.sln"
#       }
#   ]
# }
#########################################################################

# Uses NuGet to install, upgrade or restore the speicified packages
Import-Module $env:PicassioTools -DisableNameChecking -ErrorAction Stop

function Start-Module($colour, $variables, $credentials)
{
    Test-Module $colour $variables $credentials

    # Check to see if NuGet is installed, if not then install it
    if (!(Test-Software 'nuget.exe help' 'NuGet'))
    {
        Write-Warnings 'NuGet is not installed'
        Install-AdhocSoftware 'NuGet.CommandLine' 'NuGet'
    }

    $ensure = (Replace-Variables $colour.ensure $variables).ToLower().Trim()
    $packages = $colour.packages

    $path = Replace-Variables $colour.path $variables
    if ([string]::IsNullOrWhiteSpace($path))
    {
        $path = [string]::Empty
    }
    elseif (!(Test-Path $path))
    {
        throw "Path does not exist: '$path'."
    }

    $source = Replace-Variables $colour.source $variables
    if ([string]::IsNullOrWhiteSpace($source))
    {
        $source = [string]::Empty
    }
    elseif (!(Test-Path $source))
    {
        throw "Source path does not exist: '$source'."
    }

    if ($packages -eq $null)
    {
        Write-Message "Restoring NuGet packages."

        Run-Command 'nuget.exe' "restore $source"

        Write-Message "NuGet packages restored successfully."
        Reset-Path $false
    }
    else
    {
        # Set location as path pass to nuget installed
        if (![string]::IsNullOrWhiteSpace($path))
        {
            Push-Location $path
        }

        try
        {
            $keys = $packages.psobject.properties.name
            ForEach ($key in $keys)
            {
                # Grab the package we're dealing with currently
                $key = (Replace-Variables $key $variables).Trim()

                # What version of that package do we need?
                $version = Replace-Variables $packages.$key $variables
                if ([string]::IsNullOrWhiteSpace($version))
                {
                    $version = [string]::Empty
                }
                else
                {
                    $version = $version.Trim()
                }

                if ([string]::IsNullOrWhiteSpace($version))
                {
                    $versionTag = [string]::Empty
                    $version = [string]::Empty
                    $versionStr = 'latest'
                }
                else
                {
                    $versionTag = '-v'
                    $versionStr = $version
                }

                Write-Message "Starting $ensure of $key, version: $versionStr"

                Run-Command 'nuget.exe' "$ensure $key $versionTag $version"

                Write-Message "$ensure of $key ($versionStr) successful."
                Reset-Path $false
                Write-NewLine
            }
        }
        finally
        {
            if (![string]::IsNullOrWhiteSpace($path))
            {
                Pop-Location
            }
        }
    }
}

function Test-Module($colour, $variables, $credentials)
{
    # Get ensured operation for installing/uninstalling
    $ensure = Replace-Variables $colour.ensure $variables
    $ensures = @('install', 'restore')
    if ([string]::IsNullOrWhiteSpace($ensure) -or $ensures -inotcontains ($ensure.Trim()))
    {
        throw ("Invalid ensure found: '$ensure'. Can be only: {0}." -f ($ensures -join ', '))
    }

    switch ($ensure.ToLower())
    {
        'install'
            {
                # Check to see if any packages were supplied
                $packages = $colour.packages
                if ($packages -ne $null)
                {
                    # Grab the names of the packages, ensure we have valid values
                    $keys = $packages.psobject.properties.name
                    if ($keys -eq $null -or $keys.Length -eq 0)
                    {
                        throw 'No package names have been supplied.'
                    }

                    if (($keys | Where-Object { [string]::IsNullOrWhiteSpace((Replace-Variables $_ $variables)) } | Measure-Object).Count -gt 0)
                    {
                        throw 'Invalid or empty package names found.'
                    }
                }
            }
    }

}
