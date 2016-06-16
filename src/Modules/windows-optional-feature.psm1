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
#            "type": "windows-optional-feature",
#            "ensure": "installed",
#            "all": false,
#            "names": [
#               "Microsoft-Hyper-V"
#            ]
#        }
#    ]
# }
#########################################################################

# Installs/uninstalled windows optional features
Import-Module $env:PicassioTools -DisableNameChecking -ErrorAction Stop

function Start-Module($colour, $variables, $credentials)
{
    Test-Module $colour $variables $credentials

    $names = $colour.names
    $ensure = (Replace-Variables $colour.ensure $variables).ToLower().Trim()
    $all = Replace-Variables $colour.all $variables

    ForEach ($name in $names)
    {
        $name = (Replace-Variables $name $variables).Trim()
        Write-Message "`nEnsuring '$name' is $ensure."

        switch ($ensure)
        {
            'installed'
                {
                    if ((Get-WindowsOptionalFeature -Online -FeatureName $name).State -ieq 'enabled')
                    {
                        Write-Information "$name has already been $ensure."
                        continue
                    }

                    if ($all)
                    {
                        Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName $name -All
                    }
                    else
                    {
                        Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName $name
                    }

                    if (!$?)
                    {
                        throw 'Failed to install Windows optional feature.'
                    }
                }

            'uninstalled'
                {
                    if ((Get-WindowsOptionalFeature -Online -FeatureName $name).State -ieq 'disabled')
                    {
                        Write-Information "$name has already been $ensure."
                        continue
                    }

                    Disable-WindowsOptionalFeature -Online -NoRestart -FeatureName $name

                    if (!$?)
                    {
                        throw 'Failed to uninstall Windows optional feature.'
                    }
                }
        }

        Write-Message "'$name' has been $ensure."
    }

    Write-Information 'It is suggested that you restart your computer.'
}

function Test-Module($colour, $variables, $credentials)
{
    # Check feature names are all valid
    $names = $colour.names
    if ($names -eq $null -or $names.Length -eq 0)
    {
        throw 'No Windows optional feature names have been supplied.'
    }

    ForEach ($name in $names)
    {
        $name = Replace-Variables $name $variables

        if ([string]::IsNullOrEmpty($name) -or (Get-WindowsOptionalFeature -Online -FeatureName $name | Measure-Object).Count -eq 0)
        {
            throw "Invalid Windows optional feature: '$name'."
        }
    }

    # Check ensures value
    $ensure = Replace-Variables $colour.ensure $variables
    $ensures = @('installed', 'uninstalled')
    if ([string]::IsNullOrWhiteSpace($ensure) -or $ensures -inotcontains ($ensure.Trim()))
    {
        throw ("Invalid ensure found: '$ensure'. Can be only: {0}." -f ($ensures -join ', '))
    }

    # Check we want to install all features
    $all = Replace-Variables $colour.all $variables
    if (![string]::IsNullOrWhiteSpace($all) -and $all -ne $true -and $all -ne $false)
    {
        throw "Invalid value for all: '$all'. Should be either true or false."
    }
}
