##########################################################################
# Picassio is a provisioning/deployment script which uses a single linear
# JSON file to determine what commands to execute.
#
# Copyright (c) 2015, Matthew Kelly (Badgerati)
# Company: Cadaeic Studios
# License: MIT (see LICENSE for details)
#########################################################################

# Calls vagrant from a specified path where a Vagrantfile can be found
Import-Module $env:PicassioTools -DisableNameChecking

function Start-Module($colour, $variables) {
	Test-Module $colour $variables

    if (!(Test-Software vagrant.exe 'vagrant')) {
        Write-Errors 'Vagrant is not installed'
        Install-AdhocSoftware 'vagrant' 'Vagrant'
    }

    $path = (Replace-Variables $colour.path $variables).Trim()
    $command = (Replace-Variables $colour.command $variables).Trim()
	
    if (!(Test-Path $path)) {
        throw "Path specified to Vagrantfile doesn't exist: '$path'."
    }

	Write-Message "Running vagrant $command."
    Push-Location $path
    vagrant.exe $command
    
    if (!$?) {
        Pop-Location
        throw 'Failed to call vagrant.'
    }

    Pop-Location
    Write-Message "vagrant $command, successful."
}

function Test-Module($colour, $variables) {
    $path = Replace-Variables $colour.path $variables
    if ([string]::IsNullOrWhiteSpace($path)) {
        throw 'No path specified to parent directory where the Vagrantfile is located.'
    }

    $command = Replace-Variables $colour.command $variables
    if ([string]::IsNullOrWhiteSpace($command)) {
        throw 'No command specified for which to call vagrant.'
    }
}