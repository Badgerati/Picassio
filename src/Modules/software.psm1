# Uses Chocolatey to install, upgrade or uninstall the speicified softwares
Import-Module $env:PicassoTools -DisableNameChecking

function Start-Module($colour) {
	if (!(Test-Software choco.exe)) {
        Install-Chocolatey
    }

    # Get list of software names
    $names = $colour.names
    if ($names -eq $null -or $names.Length -eq 0) {
        throw 'No names supplied for software colour.'
    }
    
    # Get ensured operation for installing/uninstalling
    $operation = $colour.ensure
    if ([string]::IsNullOrWhiteSpace($operation)) {
        throw 'No ensure operation supplied for software colour.'
    }

    $operation = $operation.ToLower().Trim()

    if ($operation.EndsWith('ed')) {
        $operation = $operation.Substring(0, $colour.ensure.Length - 2)
    }

    # Get list of versions (or single version for all names)
    $versions = $colour.versions
    if ($versions -ne $null -and $versions.Length -gt 1 -and $versions.Length -ne $names.Length) {
        throw 'Incorrect number of versions specified. Expected an equal amount to the amount of names speicified.'
    }
    
    for ($i = 0; $i -lt $names.Length; $i++) {
        $name = $names[$i].Trim()
        $this_operation = $operation

        # Work out what version we're trying to install
        if ($versions -eq $null -or $versions.Length -eq 0) {
            $version = 'latest'
        }
        elseif ($versions.Length -eq 1) {
            $version = $versions[0].Trim()
        }
        else {
            $version = $versions[$i].Trim()
        }

        if ($this_operation -eq 'install') {
            if ($version.ToLower() -ne 'latest') {
				$result = (choco.exe list -lo | Where-Object { $_ -ilike "*$name*$version*" } | Select-Object -First 1)

				if (![string]::IsNullOrWhiteSpace($result)) {
					Write-Information "$name $version is already installed."
					continue
				}
			}
			
			$result = (choco.exe list -lo | Where-Object { $_ -ilike "*$name*" } | Select-Object -First 1)

            if (![string]::IsNullOrWhiteSpace($result)) {
                $this_operation = 'upgrade'
            }
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

        Reset-Path

        if ($i -ne ($names.Length - 1)) {
            Write-Host ([string]::Empty)
        }
    }
}