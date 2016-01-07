##########################################################################
# Picassio is a provisioning/deployment script which uses a single linear
# JSON file to determine what commands to execute.
#
# Copyright (c) 2015, Matthew Kelly (Badgerati)
# Company: Cadaeic Studios
# License: MIT (see LICENSE for details)
#########################################################################

# Installs a service onto the system
Import-Module $env:PicassioTools -DisableNameChecking

function Start-Module($colour, $variables) {
	Test-Module $colour $variables

    # attempt to retrieve the service
    $name = (Replace-Variables $colour.name $variables).Trim()
    $service = (Get-WmiObject -Class Win32_Service -Filter "Name='$name'")

    # check if service is already uninstalled
    $ensure = (Replace-Variables $colour.ensure $variables).ToLower().Trim()
    if ($service -eq $null -and $ensure -eq 'uninstalled') {
        Write-Message "Service '$name' already $ensure."
        return
    }

    $state = Replace-Variables $colour.state $variables
	if ($state -ne $null) {
		$state = $state.ToLower().Trim()
	}

    $path = Replace-Variables $colour.path $variables

	if ($path -ne $null) {
		$path = $path.Trim()
	}
    
    if ($service -ne $null -and $ensure -eq 'installed') {
        Write-Message "Ensuring service '$name' is $state."

        if ($state -eq 'started') {
            Restart-Service $name
        }
        else {
            Stop-Service $name
        }

        Write-Message "Service $state."
    }
    elseif ($service -ne $null -and $ensure -eq 'uninstalled') {
        Write-Message "Ensuring service '$name' is $ensure."

		$tasks = (tasklist /FI "IMAGENAME eq mmc.exe")
		$t = ($tasks | Where-Object { $_ -match "mmc.exe" })
		if ($tasks.Count -gt 0) {
			taskkill /F /IM mmc.exe | Out-Null
		}

		Stop-Service $name
        $service.delete()
        Write-Message "Service $ensure."
    }
    else {
		if (!(Test-Path $path)) {
			throw "Path passed to install service does not exist: '$path'"
		}

        Write-Message "Ensuring service '$name' is $ensure."
        New-Service -Name $name -BinaryPathName $path -StartupType Automatic
        Write-Message "Service $ensure."

        Write-Message "Ensuring service '$name' is $state."

        if ($state -eq 'started') {
            Start-Service $name
        }
        else {
            Stop-Service $name
        }

        Write-Message "Service $state."
    }
}

function Test-Module($colour, $variables) {
    $name = Replace-Variables $colour.name $variables
    if ([string]::IsNullOrWhiteSpace($name)) {
        throw 'No service name supplied.'
    }

	$name = $name.Trim()

    # attempt to retrieve the service
    $service = (Get-WmiObject -Class Win32_Service -Filter "Name='$name'")

    $ensure = Replace-Variables $colour.ensure $variables
    if ([string]::IsNullOrWhiteSpace($ensure)) {
        throw 'No ensure parameter supplied for service.'
    }

    # check we have a valid ensure property
    $ensure = $ensure.ToLower().Trim()
    if ($ensure -ne 'installed' -and $ensure -ne 'uninstalled') {
        throw "Invalid ensure parameter supplied for service: '$ensure'."
    }

    $state = Replace-Variables $colour.state $variables
    if ([string]::IsNullOrWhiteSpace($state) -and $ensure -eq 'installed') {
        throw 'No state parameter supplied for service.'
    }

    # check we have a valid state property
    if ($state -ne $null) {
		$state = $state.ToLower().Trim()
	}

    if ($state -ne 'started' -and $state -ne 'stopped' -and $ensure -eq 'installed') {
        throw "Invalid state parameter supplied for service: '$state'."
    }

    $path = Replace-Variables $colour.path $variables
    if ([string]::IsNullOrWhiteSpace($path) -and $service -eq $null -and $ensure -eq 'installed') {
        throw 'No path passed to install service.'
    }
}