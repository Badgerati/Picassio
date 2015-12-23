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

function Start-Module($colour) {
	Test-Module $colour

    # attempt to retrieve the service
    $name = $colour.name.Trim()
    $service = (Get-WmiObject -Class Win32_Service -Filter "Name='$name'")

    # check if service is already uninstalled
    $ensure = $colour.ensure.ToLower().Trim()
    if ($service -eq $null -and $ensure -eq 'uninstalled') {
        Write-Message "Service '$name' already $ensure."
        return
    }

    $state = $colour.state.ToLower().Trim()
    $path = $colour.path

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

function Test-Module($colour) {
    $name = $colour.name
    if ([string]::IsNullOrWhiteSpace($name)) {
        throw 'No service name supplied.'
    }

	$name = $name.Trim()

    # attempt to retrieve the service
    $service = (Get-WmiObject -Class Win32_Service -Filter "Name='$name'")

    $ensure = $colour.ensure
    if ([string]::IsNullOrWhiteSpace($ensure)) {
        throw 'No ensure parameter supplied for service.'
    }

    # check we have a valid ensure property
    $ensure = $ensure.ToLower().Trim()
    if ($ensure -ne 'installed' -and $ensure -ne 'uninstalled') {
        throw "Invalid ensure parameter supplied for service: '$ensure'."
    }

    $state = $colour.state
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

    $path = $colour.path
    if ([string]::IsNullOrWhiteSpace($path) -and $service -eq $null -and $ensure -eq 'installed') {
        throw 'No path passed to install service.'
    }
}