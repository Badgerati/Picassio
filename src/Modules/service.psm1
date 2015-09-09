# Installs a service onto the system
Import-Module $env:PICASSO_TOOLS -DisableNameChecking

function Start-Module($colour) {
    $name = $colour.name
    if ([string]::IsNullOrWhiteSpace($name)) {
        throw 'No service name supplied.'
    }

    # attempt to retrieve the service
    $service = (Get-WmiObject -Class Win32_Service -Filter "Name='$name'")

    $ensure = $colour.ensure
    if ([string]::IsNullOrWhiteSpace($ensure)) {
        throw 'No ensure parameter supplied for service.'
    }

    # check we have a valid ensure property
    $ensure = $ensure.ToLower()
    if ($ensure -ne 'installed' -and $ensure -ne 'uninstalled') {
        throw "Invalid ensure parameter supplied for service: '$ensure'."
    }

    # check if service is alredy uninstalled
    if ($service -eq $null -and $ensure -eq 'uninstalled') {
        Write-Message "Service '$name' already $ensure."
        return
    }

    $state = $colour.state
    if ([string]::IsNullOrWhiteSpace($state)) {
        throw 'No state parameter supplied for service.'
    }

    # check we have a valid state property
    $state = $state.ToLower()
    if ($state -ne 'started' -and $state -ne 'stopped' -and $ensure -eq 'installed') {
        throw "Invalid state parameter supplied for service: '$state'."
    }

    $path = $colour.path
    if ([string]::IsNullOrWhiteSpace($path) -and $service -eq $null -and $ensure -eq 'installed') {
        throw 'No path passed to install service.'
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