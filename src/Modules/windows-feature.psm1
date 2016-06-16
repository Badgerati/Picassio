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
#            "type": "windows-feature",
#            "ensure": "installed",
#            "includeSubFeatures": true,
#            "includeManagementTools": true,
#            "names": [
#               "Web-Server"
#            ]
#        }
#    ]
# }
#########################################################################

# Installs/uninstalled windows features
Import-Module $env:PicassioTools -DisableNameChecking -ErrorAction Stop
Import-Module ServerManager -ErrorAction Stop

function Start-Module($colour, $variables, $credentials)
{
    Test-Module $colour $variables $credentials

    $names = $colour.names
    $ensure = (Replace-Variables $colour.ensure $variables).ToLower().Trim()
    $includeSubFeatures = Replace-Variables $colour.includeSubFeatures $variables
    $includeManagementTools = Replace-Variables $colour.includeManagementTools $variables

    ForEach ($name in $names)
    {
        $name = (Replace-Variables $name $variables).Trim()
        Write-Message "`nEnsuring '$name' is $ensure."

        switch ($ensure)
        {
            'installed'
                {
                    if ((Get-WindowsFeature -Name $name).Installed -eq $true)
                    {
                        Write-Information "$name has already been $ensure."
                        continue
                    }

                    if ($includeSubFeatures -eq $true -and $includeManagementTools -eq $true)
                    {
                        Add-WindowsFeature -Name $name -IncludeAllSubFeature -IncludeManagementTools
                    }
                    elseif ($includeSubFeatures -eq $true)
                    {
                        Add-WindowsFeature -Name $name -IncludeAllSubFeature
                    }
                    elseif ($includeManagementTools -eq $true)
                    {
                        Add-WindowsFeature -Name $name -IncludeManagementTools
                    }
                    else
                    {
                        Add-WindowsFeature -Name $name
                    }

                    if (!$?)
                    {
                        throw 'Failed to install Windows feature.'
                    }
                }

            'uninstalled'
                {
                    if ((Get-WindowsFeature -Name $name).Installed -eq $false)
                    {
                        Write-Information "$name has already been $ensure."
                        continue
                    }

                    if ($includeManagementTools -eq $true)
                    {
                        Remove-WindowsFeature -Name $name -IncludeManagementTools
                    }
                    else
                    {
                        Remove-WindowsFeature -Name $name
                    }

                    if (!$?)
                    {
                        throw 'Failed to uninstall Windows feature.'
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
        throw 'No Windows feature names have been supplied.'
    }

    ForEach ($name in $names)
    {
        $name = Replace-Variables $name $variables

        if ([string]::IsNullOrEmpty($name) -or (Get-WindowsFeature -Name $name | Measure-Object).Count -eq 0)
        {
            throw "Invalid Windows feature: '$name'."
        }
    }

    # Check ensures value
    $ensure = Replace-Variables $colour.ensure $variables
    $ensures = @('installed', 'uninstalled')
    if ([string]::IsNullOrWhiteSpace($ensure) -or $ensures -inotcontains ($ensure.Trim()))
    {
        throw ("Invalid ensure found: '$ensure'. Can be only: {0}." -f ($ensures -join ', '))
    }

    # Check sub features and tools values
    $includeSubFeatures = Replace-Variables $colour.includeSubFeatures $variables
    if (![string]::IsNullOrWhiteSpace($includeSubFeatures) -and $includeSubFeatures -ne $true -and $includeSubFeatures -ne $false)
    {
        throw "Invalid value for includeSubFeatures: '$includeSubFeatures'. Should be either true or false."
    }

    $includeManagemementTools = Replace-Variables $colour.includeManagementTools $variables
    if (![string]::IsNullOrWhiteSpace($includeManagemementTools) -and $includeManagemementTools -ne $true -and $includeManagemementTools -ne $false)
    {
        throw "Invalid value for includeManagementTools: '$includeManagemementTools'. Should be either true or false."
    }
}
