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
#           "type": "bower",
#           "ensure": "install",
#           "args": "--save",
#           "packages": {
#              "jquery": "1.8.2",
#              "normalize.css": ""
#           },
#           "path": "C:\\to\\install\\packages"
#       }
#   ]
# }
#########################################################################

# Uses bower to install, upgrade or uninstall the speicified packages
Import-Module $env:PicassioTools -DisableNameChecking -ErrorAction Stop

function Start-Module($colour, $variables, $credentials)
{
    Test-Module $colour $variables $credentials

    # Check to see if git is installed, if not then install it
    if (!(Test-Software 'git --version' 'git'))
    {
        Write-Errors 'Git is not installed'
        Install-AdhocSoftware 'git.install' 'Git'
    }

    # Check to see if bower is installed, if not then install it
    if (!(Test-Software 'bower help'))
    {
        Write-Errors 'bower is not installed'
        Install-AdhocSoftware 'bower' 'bower' 'npm'
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

    $_args = Replace-Variables $colour.args $variables
    if ($_args -eq $null)
    {
        $_args = [string]::Empty
    }

    # Set location as path pass to bower installed
    if (![string]::IsNullOrWhiteSpace($path))
    {
        Push-Location $path
    }

    try
    {
        if ($packages -eq $null)
        {
            Write-Message "Starting bower $ensure."

            Run-Command 'bower' "$ensure $_args"

            Write-Message "bower $ensure successful."
            Reset-Path $false
        }
        else
        {
            $keys = $packages.psobject.properties.name
            ForEach ($key in $keys)
            {
                # Grab the package we're dealing with currently
                $key = (Replace-Variables $key $variables).Trim()
                $normKey = $key -replace '\.', '-'

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
                                $result = (bower list | Where-Object { $_ -ilike "*$normKey#$version*" } | Measure-Object).Count
                                if ($result -ne 0)
                                {
                                    Write-Information "$key#$version is already installed."
                                    $nothing_to_do = $true
                                }
                            }

                            if (!$nothing_to_do)
                            {
                                $result = (bower list | Where-Object { $_ -ilike "*$normKey*" } | Measure-Object).Count
                                if ($result -ne 0)
                                {
                                    $current_ensure = 'update'
                                }
                            }
                        }

                    'uninstall'
                        {
                            $result = (bower list | Where-Object { $_ -ilike "*$normKey*" } | Measure-Object).Count
                            if ($result -eq 0)
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

                if ([string]::IsNullOrWhiteSpace($version) -or $current_ensure -ieq 'uninstall')
                {
                    $version = [string]::Empty
                    $versionStr = 'latest'
                }
                else
                {
                    $versionStr = $version
                    $version = "#$version"
                }

                Write-Message "Starting $current_ensure of $key, version: $versionStr"

                Run-Command 'bower' "$current_ensure $key$version $_args" $false $true

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
