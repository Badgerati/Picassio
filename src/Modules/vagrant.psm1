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
#            "type": "vagrant",
#            "path": "C:\\path\\to\\project",
#            "command": "up"
#        }
#    ]
# }
#########################################################################

# Calls vagrant from a specified path where a Vagrantfile can be found
Import-Module $env:PicassioTools -DisableNameChecking -ErrorAction Stop

function Start-Module($colour, $variables, $credentials)
{
    Test-Module $colour $variables $credentials

    if (!(Test-Software 'vagrant version' 'vagrant'))
    {
        Write-Warnings 'Vagrant is not installed'
        Install-AdhocSoftware 'vagrant' 'Vagrant'
    }

    $path = (Replace-Variables $colour.path $variables).Trim()
    $command = (Replace-Variables $colour.command $variables).Trim()

    if (!(Test-Path $path))
    {
        throw "Path specified to Vagrantfile doesn't exist: '$path'."
    }

    Write-Message "Running vagrant $command."
    Push-Location $path

    try
    {
        vagrant.exe $command
        if (!$?)
        {
            throw 'Failed to call vagrant.'
        }
    }
    finally
    {
        Pop-Location
    }

    Write-Message "vagrant $command, successful."
}

function Test-Module($colour, $variables, $credentials)
{
    $path = Replace-Variables $colour.path $variables
    if ([string]::IsNullOrWhiteSpace($path))
    {
        throw 'No path specified to parent directory where the Vagrantfile is located.'
    }

    $command = Replace-Variables $colour.command $variables
    if ([string]::IsNullOrWhiteSpace($command))
    {
        throw 'No command specified for which to call vagrant.'
    }
}
