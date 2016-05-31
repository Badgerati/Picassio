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
#	"paint": [
#		{
#			"type": "windows-optional-feature",
#			"ensure": "installed",
#			"name": "Microsoft-Hyper-V",
#			"all": false
#		}
#	]
# }
#########################################################################

# Installs/uninstalled windows optional features
Import-Module $env:PicassioTools -DisableNameChecking

function Start-Module($colour, $variables) {
	Test-Module $colour $variables

	$name = (Replace-Variables $colour.name $variables).Trim()
	$ensure = (Replace-Variables $colour.ensure $variables).ToLower().Trim()
	$all = Replace-Variables $colour.all $variables

	Write-Message "`nEnsuring '$name' is $ensure."

	switch ($ensure) {
		'installed'
			{
				if ($all) {
					Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName $name -All
				}
				else {
					Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName $name
				}

				if (!$?) {
					throw 'Failed to install Windows optional feature.'
				}
			}

		'uninstalled'
			{
				Disable-WindowsOptionalFeature -Online -NoRestart -FeatureName $name

				if (!$?) {
					throw 'Failed to uninstall Windows optional feature.'
				}
			}
	}

	Write-Message "'$name' has been $ensure."
	Write-Information 'It is suggested that you restart your computer.'
}

function Test-Module($colour, $variables) {
	$name = Replace-Variables $colour.name $variables
	if ([string]::IsNullOrEmpty($name)) {
		throw 'No optional feature name has been supplied.'
	}

	# ensure the feature exists
	$name = $name.Trim()
	$featureExists = (Get-WindowsOptionalFeature -Online -FeatureName $name | Measure-Object).Count

	if ($featureExists -eq 0) {
		throw "Windows optional feature does not exist: '$name'."
	}

	$ensure = Replace-Variables $colour.ensure $variables
    if ([string]::IsNullOrWhiteSpace($ensure)) {
        throw 'No ensure parameter supplied.'
    }

    # check we have a valid ensure property
    $ensure = $ensure.ToLower().Trim()
    if ($ensure -ne 'installed' -and $ensure -ne 'uninstalled') {
        throw "Invalid ensure parameter supplied: '$ensure'."
    }

	$all = Replace-Variables $colour.all $variables
	if (![string]::IsNullOrWhiteSpace($all) -and $all -ne $true -and $all -ne $false) {
		throw "Invalid value for all: '$all'. Should be either true or false."
	}
}