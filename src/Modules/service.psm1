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
#			"type": "service",
#			"name": "Example Service",
#			"path": "C:\\absolute\\path\\to\\service.exe",
#			"ensure": "installed",
#			"state": "started"
#		}
#	]
# }
#########################################################################

# Installs a service onto the system
Import-Module $env:PicassioTools -DisableNameChecking -ErrorAction Stop

function Start-Module($colour, $variables, $credentials)
{
    Test-Module $colour $variables $credentials

    # attempt to retrieve the service
    $name = (Replace-Variables $colour.name $variables).Trim()
    $service = (Get-WmiObject -Class Win32_Service -Filter "Name='$name'")

    # check if service is already uninstalled
    $ensure = (Replace-Variables $colour.ensure $variables).ToLower().Trim()
    if ($service -eq $null -and $ensure -eq 'uninstalled')
    {
        Write-Message "Service '$name' already $ensure."
        return
    }

    $state = Replace-Variables $colour.state $variables
    if ($state -ne $null)
    {
        $state = $state.ToLower().Trim()
    }

    $path = Replace-Variables $colour.path $variables
    if ($path -ne $null)
    {
        $path = $path.Trim()
    }

    # Deal with exists logic
    if ($ensure -eq 'exists')
    {
        if ($service -eq $null)
        {
            Write-Message 'Service does not exist, skipping exists state logic.'
            return
        }

        Write-Message "Ensuring service '$name' is $state."
        Toggle-Service $name $state
        Write-Message "Service $state."
        return
    }

    if ($service -ne $null -and $ensure -eq 'installed')
    {
        Write-Message "Ensuring service '$name' is $state."
        Toggle-Service $name $state
        Write-Message "Service $state."
    }
    elseif ($service -ne $null -and $ensure -eq 'uninstalled')
    {
        Write-Message "Ensuring service '$name' is $ensure."

        $tasks = (tasklist /FI "IMAGENAME eq mmc.exe")
        $t = ($tasks | Where-Object { $_ -match "mmc.exe" })
        if ($t.Count -gt 0)
        {
            taskkill /F /IM mmc.exe | Out-Null
        }

        Stop-Service $name | Out-Null
        if (!$?)
        {
            throw 'Failed to stop service before deletion.'
        }

        $service.delete() | Out-Null
        if (!$?)
        {
            throw 'Failed to delete service.'
        }

        Write-Message "Service $ensure."
    }
    else
    {
        if (!(Test-Path $path))
        {
            throw "Path passed to install service does not exist: '$path'"
        }

        Write-Message "Ensuring service '$name' is $ensure."

        New-Service -Name $name -BinaryPathName $path -StartupType Automatic
        if (!$?)
        {
            throw 'Failed to create the service.'
        }

        Write-Message "Service $ensure."

        Write-Message "Ensuring service '$name' is $state."
        Toggle-Service $name $state $false
        Write-Message "Service $state."
    }
}

function Test-Module($colour, $variables, $credentials)
{
    $name = Replace-Variables $colour.name $variables
    if ([string]::IsNullOrWhiteSpace($name))
    {
        throw 'No service name supplied.'
    }

    $name = $name.Trim()

    # attempt to retrieve the service
    $service = (Get-WmiObject -Class Win32_Service -Filter "Name='$name'")

    $ensure = Replace-Variables $colour.ensure $variables
    if ([string]::IsNullOrWhiteSpace($ensure))
    {
        throw 'No ensure parameter supplied for service.'
    }

    # check we have a valid ensure property
    $ensure = $ensure.ToLower().Trim()
    if ($ensure -ne 'installed' -and $ensure -ne 'uninstalled' -and $ensure -ne 'exists')
    {
        throw "Invalid ensure parameter supplied for service: '$ensure'."
    }

    $state = Replace-Variables $colour.state $variables
    if ([string]::IsNullOrWhiteSpace($state) -and ($ensure -eq 'installed' -or $ensure -eq 'exists'))
    {
        throw 'No state parameter supplied for service.'
    }

    # check we have a valid state property
    if ($state -ne $null)
    {
        $state = $state.ToLower().Trim()
    }

    if ($state -ne 'started' -and $state -ne 'stopped' -and ($ensure -eq 'installed' -or $ensure -eq 'exists'))
    {
        throw "Invalid state parameter supplied for service: '$state'."
    }

    $path = Replace-Variables $colour.path $variables
    if ([string]::IsNullOrWhiteSpace($path) -and $service -eq $null -and $ensure -eq 'installed')
    {
        throw 'No path passed to install service.'
    }
}


function Toggle-Service($name, $state, $restart = $true)
{
    if ($state -eq 'started')
    {
        if ($restart)
        {
            Restart-Service $name -Force
        }
        else
        {
            Start-Service $name
        }
    }
    else
    {
        Stop-Service $name -Force
    }

    if (!$?)
    {
        throw "Failed to update service state."
    }
}
