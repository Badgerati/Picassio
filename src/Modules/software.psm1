##########################################################################
# Picassio is a provisioning/deployment script which uses a single linear
# JSON file to determine what commands to execute.
#
# Copyright (c) 2015, Matthew Kelly (Badgerati)
# Company: Cadaeic Studios
# License: MIT (see LICENSE for details)
#########################################################################

# Uses Chocolatey to install, upgrade or uninstall the speicified softwares
Import-Module $env:PicassioTools -DisableNameChecking

function Start-Module($colour, $variables) {
	Test-Module $colour $variables

	if (!(Test-Software choco.exe)) {
        Install-Chocolatey
    }

    # Get list of software names
    $names = $colour.names
    
    # Get ensured operation for installing/uninstalling
    $operation = (Replace-Variables $colour.ensure $variables).ToLower().Trim()
    $operation = $operation.Substring(0, $operation.Length - 2)

    # Get list of versions (or single version for all names)
    $versions = $colour.versions
    
	# Provision software
    for ($i = 0; $i -lt $names.Length; $i++) {
        $name = (Replace-Variables $names[$i] $variables).Trim()
        $this_operation = $operation

        # Work out what version we're trying to install
        if ($versions -eq $null -or $versions.Length -eq 0) {
            $version = 'latest'
        }
        elseif ($versions.Length -eq 1) {
            $version = (Replace-Variables $versions[0] $variables).Trim()
        }
        else {
            $version = (Replace-Variables $versions[$i] $variables).Trim()
        }

		$continue = $false
		switch ($this_operation) {
			'install'
				{
					if ($version.ToLower() -ne 'latest') {
						$result = (choco.exe list -lo | Where-Object { $_ -ilike "*$name*$version*" } | Select-Object -First 1)

						if (![string]::IsNullOrWhiteSpace($result)) {
							Write-Information "$name $version is already installed."
							$continue = $true
						}
					}

					if (!$continue) {
						$result = (choco.exe list -lo | Where-Object { $_ -ilike "*$name*" } | Select-Object -First 1)

						if (![string]::IsNullOrWhiteSpace($result)) {
							$this_operation = 'upgrade'
						}
					}
				}

			'uninstall'
				{
					$result = (choco.exe list -lo | Where-Object { $_ -ilike "*$name*" } | Select-Object -First 1)

					if ([string]::IsNullOrWhiteSpace($result)) {
						Write-Information "$name is already uninstalled"
						$continue = $true
					}
				}
		}

		if ($continue) {
			continue
		}

        if ([string]::IsNullOrWhiteSpace($version) -or $version.ToLower() -eq 'latest' -or $this_operation -eq 'uninstall') {
            $versionTag = [string]::Empty
            $version = [string]::Empty
            $versionStr = 'latest'
        }
        else {
            $versionTag = '--version'
            $versionStr = $version
        }

        Write-Message "$this_operation on $name application starting. Version: $versionStr"
        choco.exe $this_operation $name $versionTag $version -y

        if (!$?) {
            throw "Failed to $this_operation the $name software."
        }
    
        Write-Message "$this_operation on $name application successful."
        Reset-Path $false

        if ($i -ne ($names.Length - 1)) {
            Write-NewLine
        }
    }
}

function Test-Module($colour, $variables) {
    $names = $colour.names
    if ($names -eq $null -or $names.Length -eq 0) {
        throw 'No names supplied for software.'
    }
    
    # Get ensured operation for installing/uninstalling
    $operation = Replace-Variables $colour.ensure $variables
    if ([string]::IsNullOrWhiteSpace($operation)) {
        throw 'No ensure operation supplied for software.'
    }

    # check we have a valid ensure property
    $operation = $operation.ToLower().Trim()
    if ($operation -ne 'installed' -and $operation -ne 'uninstalled') {
        throw "Invalid ensure parameter supplied for software: '$ensure'."
    }
	
    # Get list of versions (or single version for all names)
    $versions = $colour.versions
    if ($versions -ne $null -and $versions.Length -gt 1 -and $versions.Length -ne $names.Length) {
        throw 'Incorrect number of versions specified. Expected an equal amount to the amount of names speicified.'
    }
}