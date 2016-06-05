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
#            "type": "software",
#            "ensure": "install",
#            "software": {
#               "git.install": "latest",
#               "atom": "1.0.7"
#            }
#        }
#    ]
# }
#########################################################################

# Uses Chocolatey to install, upgrade or uninstall the speicified softwares
Import-Module $env:PicassioTools -DisableNameChecking -ErrorAction Stop

function Start-Module($colour, $variables, $credentials)
{
    Test-Module $colour $variables $credentials

    # Check to see if Chocolatey is installed, if not then install it
    if (!(Test-Software choco.exe))
    {
        Install-Chocolatey
    }

    $ensure = (Replace-Variables $colour.ensure $variables).ToLower().Trim()
    $software = $colour.software
    $keys = $software.psobject.properties.name

    ForEach ($key in $keys)
    {
        # Grab the software we're dealing with currently
        $key = (Replace-Variables $key $variables).Trim()

        # What version of that software do we need?
        $version = Replace-Variables $software.$key $variables
        if ([string]::IsNullOrWhiteSpace($version))
        {
            $version = 'latest'
        }

        $version = $version.Trim()

        # Store the current ensure value, as this might be changed to upgrade later
        $current_ensure = $ensure

        # Deal with the ensure value
        $nothing_to_do = $false
        switch ($current_ensure)
        {
            'install'
                {
                    if ($version -ine 'latest')
                    {
                        $result = (choco.exe list -lo | Where-Object { $_ -ilike "*$key*$version*" } | Select-Object -First 1)

                        if (![string]::IsNullOrWhiteSpace($result))
                        {
                            Write-Information "$key $version is already installed."
                            $nothing_to_do = $true
                        }
                    }

                    if (!$nothing_to_do)
                    {
                        $result = (choco.exe list -lo | Where-Object { $_ -ilike "*$key*" } | Select-Object -First 1)

                        if (![string]::IsNullOrWhiteSpace($result))
                        {
                            $current_ensure = 'upgrade'
                        }
                    }
                }

            'uninstall'
                {
                    $result = (choco.exe list -lo | Where-Object { $_ -ilike "*$key*" } | Select-Object -First 1)

                    if ([string]::IsNullOrWhiteSpace($result))
                    {
                        Write-Information "$key is already uninstalled"
                        $nothing_to_do = $true
                    }
                }
        }

        # If software already (un)installed, skip to next
        if ($nothing_to_do)
        {
            continue
        }

        if ($version -ieq 'latest' -or $current_ensure -ieq 'uninstall')
        {
            $versionTag = [string]::Empty
            $version = [string]::Empty
            $versionStr = 'latest'
        }
        else
        {
            $versionTag = '--version'
            $versionStr = $version
        }

        Write-Message "Staring $current_ensure of $key, version: $versionStr"

        Run-Command 'choco.exe' "$current_ensure $key $versionTag $version -y"

        Write-Message "$current_ensure of $key ($versionStr) successful."
        Reset-Path $false
        Write-NewLine
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

    # Check to see if any software was supplied
    $software = $colour.software
    if ($software -eq $null)
    {
        throw 'No software has been supplied.'
    }

    # Grab the names of the software, ensure we have valid values
    $keys = $software.psobject.properties.name
    if ($keys -eq $null -or $keys.Length -eq 0)
    {
        throw 'No software names have been supplied.'
    }

    if (($keys | Where-Object { [string]::IsNullOrWhiteSpace((Replace-Variables $_ $variables)) } | Measure-Object).Count -gt 0)
    {
        throw 'Invalid or empty software names found.'
    }
}
