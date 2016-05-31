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
#			"type": "windows-feature",
#			"ensure": "installed",
#			"name": "Web-Server",
#			"includeSubFeatures": true,
#			"includeManagementTools": true
#		}
#	]
# }
#########################################################################

# Installs/uninstalled windows features
Import-Module $env:PicassioTools -DisableNameChecking
Import-Module ServerManager

function Start-Module($colour, $variables) {
	Test-Module $colour $variables

	$name = (Replace-Variables $colour.name $variables).Trim()
	$ensure = (Replace-Variables $colour.ensure $variables).ToLower().Trim()
	$includeSubFeatures = Replace-Variables $colour.includeSubFeatures $variables
	$includeManagementTools = Replace-Variables $colour.includeManagementTools $variables

	Write-Message "`nEnsuring '$name' is $ensure."

	switch ($ensure) {
		'installed'
			{
				if ($includeSubFeatures -eq $true -and $includeManagementTools -eq $true) {
					Add-WindowsFeature -Name $name -IncludeAllSubFeature -IncludeManagementTools
				}
				elseif ($includeSubFeatures -eq $true) {
					Add-WindowsFeature -Name $name -IncludeAllSubFeature
				}
				elseif ($includeManagementTools -eq $true) {
					Add-WindowsFeature -Name $name -IncludeManagementTools
				}
				else {
					Add-WindowsFeature -Name $name
				}

				if (!$?) {
					throw 'Failed to install Windows feature.'
				}
			}

		'uninstalled'
			{
				if ($includeManagementTools -eq $true) {
					Remove-WindowsFeature -Name $name -IncludeManagementTools
				}
				else {
					Remove-WindowsFeature -Name $name
				}

				if (!$?) {
					throw 'Failed to uninstall Windows feature.'
				}
			}
	}

	Write-Message "'$name' has been $ensure."
	Write-Information 'It is suggested that you restart your computer.'
}

function Test-Module($colour, $variables) {
	$name = Replace-Variables $colour.name $variables
	if ([string]::IsNullOrEmpty($name)) {
		throw 'No feature name has been supplied.'
	}

	# ensure the feature exists
	$name = $name.Trim()
	$featureExists = (Get-WindowsFeature -Name $name | Measure-Object).Count

	if ($featureExists -eq 0) {
		throw "Windows feature does not exist: '$name'."
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

	$includeSubFeatures = Replace-Variables $colour.includeSubFeatures $variables
	if (![string]::IsNullOrWhiteSpace($includeSubFeatures) -and $includeSubFeatures -ne $true -and $includeSubFeatures -ne $false) {
		throw "Invalid value for includeSubFeatures: '$includeSubFeatures'. Should be either true or false."
	}

	$includeManagemementTools = Replace-Variables $colour.includeManagementTools $variables
	if (![string]::IsNullOrWhiteSpace($includeManagemementTools) -and $includeManagemementTools -ne $true -and $includeManagemementTools -ne $false) {
		throw "Invalid value for includeManagementTools: '$includeManagemementTools'. Should be either true or false."
	}
}