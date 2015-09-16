# Updates the hosts file
Import-Module $env:PicassioTools -DisableNameChecking

function Start-Module($colour) {
	Validate-Module $colour

    $hostFile = "$env:windir\System32\drivers\etc\hosts"
    $ensure = $colour.ensure.ToLower().Trim()

    # check IP
    $ip = $colour.ip
    if ([String]::IsNullOrWhiteSpace($ip)) {
        $ip = [String]::Empty
    }
	else {
		$ip = $ip.Trim()
	}

    # check hostname
    $hostname = $colour.hostname
    if ([String]::IsNullOrWhiteSpace($hostname)) {
        $hostname = [String]::Empty
    }
	else {
		$hostname = $hostname.Trim()
	}

    Write-Message "Ensuring '$ip - $hostname' are $ensure."
    $regex = ".*?$ip.*?$hostname.*?"
    $lines = Get-Content $hostFile

    switch ($ensure) {
        'added'
            {
				$current = ($lines | Where-Object { $_ -match $regex } | Select-Object -First 1)
				
				if ([string]::IsNullOrWhiteSpace($current)) { 
					("$ip`t`t$hostname") | Out-File -FilePath $hostFile -Encoding ASCII -Append
				}
				else {
					Write-Message 'Host entry already exists.'
				}
            }

        'removed'
            {
                $lines | Where-Object { $_ -notmatch $regex } | Out-File -FilePath $hostFile -Encoding ASCII
            }
    }

    if (!$?) {
        throw "Failed to $ensure '$ip - $hostname' to the hosts file."
    }

    Write-Message "'$ip - $hostname' has been $ensure successfully."
}

function Validate-Module($colour) {
    $hostFile = "$env:windir\System32\drivers\etc\hosts"
    if (!(Test-Path $hostFile)) {
        throw "Hosts file does not exist at: '$hostFile'."
    }

    $ensure = $colour.ensure
    if ([String]::IsNullOrWhiteSpace($ensure)) {
        throw 'No ensure parameter supplied for hosts update.'
    }

    # check we have a valid ensure property
    $ensure = $ensure.ToLower().Trim()
    if ($ensure -ne 'added' -and $ensure -ne 'removed') {
        throw "Invalid ensure parameter supplied for hosts: '$ensure'."
    }

    # check IP
    $ip = $colour.ip
    if ([String]::IsNullOrWhiteSpace($ip)) {
        $ip = [String]::Empty
    }

    # check hostname
    $hostname = $colour.hostname
    if ([String]::IsNullOrWhiteSpace($hostname)) {
        $hostname = [String]::Empty
    }

    if ($ensure -eq 'added' -and ([String]::IsNullOrWhiteSpace($ip) -or [String]::IsNullOrWhiteSpace($hostname))) {
        throw 'No IP or Hostname has been supplied for adding a host entry.'
    }
    elseif ($ensure -eq 'removed' -and [String]::IsNullOrWhiteSpace($ip) -and [String]::IsNullOrWhiteSpace($hostname)) {
        throw 'No IP and Hostname have been supplied for removing a host entry.'
    }
}