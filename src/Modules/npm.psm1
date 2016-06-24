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
#       {
#           "type": "npm",
#           "ensure": "install",
#           "global": false,
#           "args": "--save",
#           "packages": {
#              "express": "@4.13.4",
#              "mongoose": ""
#           },
#           "path": "C:\\to\\install\\packages"
#       }
#   ]
# }
#########################################################################

# Uses npm to install, upgrade or uninstall the speicified packages
Import-Module $env:PicassioTools -DisableNameChecking -ErrorAction Stop

function Start-Module($colour, $variables, $credentials)
{
    Test-Module $colour $variables $credentials

    # Check to see if npm is installed, if not then install it
    if (!(Test-Software 'npm help' 'nodejs'))
    {
        Write-Warnings 'npm is not installed'
        Install-AdhocSoftware 'nodejs.install' 'node.js'
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

    $globalModules = Replace-Variables $colour.global $variables
    if ([string]::IsNullOrWhiteSpace($globalModules))
    {
        $globalModules = $false
    }

    $globalTag = [string]::Empty
    if ($globalModules -eq $true)
    {
        $globalTag = '-g'
    }

    $_args = Replace-Variables $colour.args $variables
    if ($_args -eq $null)
    {
        $_args = [string]::Empty
    }

    # Set location as path pass to npm installed
    if (![string]::IsNullOrWhiteSpace($path))
    {
        Push-Location $path
    }

    try
    {
        if ($packages -eq $null)
        {
            Write-Message "Starting npm $ensure."

            Run-Command 'npm' "$ensure $globalTag $_args"

            Write-Message "npm $ensure successful."
            Reset-Path $false
        }
        else
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

                $version = $version.Trim()

                # Store the current ensure value, as this might be changed to update later
                $current_ensure = $ensure

                # Deal with the ensure value
                $nothing_to_do = $false
                switch ($current_ensure)
                {
                    'install'
                        {
                            if (![string]::IsNullOrWhiteSpace($version))
                            {
                                npm list "$key$version" $globalTag | Out-Null
                                if ($?)
                                {
                                    Write-Information "$key$version is already installed."
                                    $nothing_to_do = $true
                                }
                            }

                            if (!$nothing_to_do)
                            {
                                npm list $key $globalTag | Out-Null
                                if ($?)
                                {
                                    $current_ensure = 'update'
                                }
                            }
                        }

                    'uninstall'
                        {
                            npm list $key $globalTag | Out-Null
                            if (!$?)
                            {
                                Write-Information "$key is already uninstalled."
                                $nothing_to_do = $true
                            }
                        }
                }

                # If package already (un)installed, skip to next
                if ($nothing_to_do)
                {
                    continue
                }

                if ([string]::IsNullOrWhiteSpace($version))
                {
                    $versionStr = 'latest'
                }
                else
                {
                    $versionStr = $version
                }

                Write-Message "Starting $current_ensure of $key, version: $versionStr"

                Run-Command 'npm' "$current_ensure $key$version $globalTag $_args" $false $true

                Write-Message "$current_ensure of $key ($versionStr) successful."
                Reset-Path $false
                Write-NewLine
            }
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

function Test-Module($colour, $variables, $credentials)
{
    # Get ensured operation for installing/uninstalling
    $ensure = Replace-Variables $colour.ensure $variables
    $ensures = @('install', 'uninstall')
    if ([string]::IsNullOrWhiteSpace($ensure) -or $ensures -inotcontains ($ensure.Trim()))
    {
        throw ("Invalid ensure found: '$ensure'. Can be only: {0}." -f ($ensures -join ', '))
    }

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
