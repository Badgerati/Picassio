##########################################################################
# Picassio is a provisioning/deployment script which uses a single linear
# JSON file to determine what commands to execute.
#
# Copyright (c) 2015, Matthew Kelly (Badgerati)
# Company: Cadaeic Studios
# License: MIT (see LICENSE for details)
#########################################################################

# Add/removes an application pool on IIS
Import-Module $env:PicassioTools -DisableNameChecking
Import-Module WebAdministration
sleep 2

function Start-Module($colour, $variables) {
	Test-Module $colour $variables

	$appPoolName = (Replace-Variables $colour.appPoolName $variables).Trim()
	$ensure = (Replace-Variables $colour.ensure $variables).ToLower().Trim()
	$state = Replace-Variables $colour.state $variables

	$poolExists = (Test-Path "IIS:\AppPools\$appPoolName")

	switch ($ensure) {
		'added'
			{
				if (!$poolExists) {
					throw "Application pool in IIS for updating does not exist: '$appPoolName'."
				}

				$state = $state.ToLower().Trim()
				Write-Message "`nEnsuring Application Pool is $state."

				switch ($state) {
					'started'
						{
							Restart-WebAppPool -Name $appPoolName
							if (!$?) {
								throw
							}
						}

					'stopped'
						{
							Stop-WebAppPool -Name $appPoolName
							if (!$?) {
								throw
							}
						}
				}
				
				Write-Message "Application Pool has been $state."
			}

		'removed'
			{
				Write-Message "`nRemoving application pool: '$appPoolName'."

				if ($poolExists) {
					Remove-WebAppPool -Name $appPoolName
					if (!$?) {
						throw
					}
				}
				else {
					Write-Warnings 'Application pool does not exist.'
				}
				
				Write-Message 'Application pool removed successfully.'
			}
	}
}

function Test-Module($colour, $variables) {
	if (!(Test-Win64)) {
		throw 'Shell needs to be running as a 64-bit host when setting up IIS websites.'
	}

	$appPoolName = Replace-Variables $colour.appPoolName $variables
	if ([string]::IsNullOrEmpty($appPoolName)) {
		throw 'No app pool name has been supplied.'
	}
	
	$appPoolName = $appPoolName.Trim()
	$poolExists = (Test-Path "IIS:\AppPools\$appPoolName")

	$ensure = Replace-Variables $colour.ensure $variables
    if ([string]::IsNullOrWhiteSpace($ensure)) {
        throw 'No ensure parameter supplied for app pool.'
    }

    # check we have a valid ensure property
    $ensure = $ensure.ToLower().Trim()
    if ($ensure -ne 'added' -and $ensure -ne 'removed') {
        throw "Invalid ensure parameter supplied for app pool: '$ensure'."
    }

	$state = Replace-Variables $colour.state $variables
    if ([string]::IsNullOrWhiteSpace($state) -and $ensure -eq 'added') {
        throw 'No state parameter supplied for app pool.'
    }
	
    # check we have a valid state property
	if ($state -ne $null) {
		$state = $state.ToLower().Trim()
	}

    if ($state -ne 'started' -and $state -ne 'stopped' -and $ensure -eq 'added') {
        throw "Invalid state parameter supplied for app pool: '$state'."
    }
}