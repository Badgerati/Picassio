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
#			"type": "directory",
#			"ensure": "exists",
#			"path": "C:\\path\\to\\some\\where\\to\\make"
#		}
#	]
# }
#########################################################################

# Creates or removes a directory
Import-Module $env:PicassioTools -DisableNameChecking

function Start-Module($colour, $variables) {
	Test-Module $colour $variables

    $path = (Replace-Variables $colour.path $variables).Trim()
    $ensure = (Replace-Variables $colour.ensure $variables).ToLower().Trim()

	Write-Message "`nEnsuring '$path' $ensure."

	switch ($ensure) {
		'exists'
			{
				if (!(Test-Path $path)) {
					New-Item -ItemType Directory -Path $path -Force | Out-Null
					if (!$?) {
						throw 'Failed to create directory path.'
					}
				}
			}

		'removed'
			{
				if (Test-Path $path) {
					Remove-Item -Path $path -Force -Recurse | Out-Null
					if (!$?) {
						throw 'Failed to remove directory path.'
					}
				}
			}
	}

	Write-Message "'$path' $ensure."
}

function Test-Module($colour, $variables) {
	$path = Replace-Variables $colour.path $variables
    if ([string]::IsNullOrWhiteSpace($path)) {
        throw 'No path passed.'
    }

	$ensure = Replace-Variables $colour.ensure $variables
    if ([string]::IsNullOrWhiteSpace($ensure)) {
        throw 'No ensure parameter supplied.'
    }

    # check we have a valid ensure property
    $ensure = $ensure.ToLower().Trim()
    if ($ensure -ne 'exists' -and $ensure -ne 'removed') {
        throw "Invalid ensure parameter supplied: '$ensure'."
    }
}