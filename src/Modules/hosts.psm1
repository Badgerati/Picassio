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
#			"type": "hosts",
#			"ensure": "added",
#			"ip": "127.0.0.3",
#			"hostname": "test.local.com"
#		}
#	]
# }
#########################################################################

# Updates the hosts file
Import-Module $env:PicassioTools -DisableNameChecking

function Start-Module($colour, $variables) {
	Test-Module $colour $variables

    $hostFile = "$env:windir\System32\drivers\etc\hosts"
    $ensure = (Replace-Variables $colour.ensure $variables).ToLower().Trim()

    # check IP
    $ip = Replace-Variables $colour.ip $variables
    if ([String]::IsNullOrWhiteSpace($ip)) {
        $ip = [String]::Empty
    }
	else {
		$ip = $ip.Trim()
	}

    # check hostname
    $hostname = Replace-Variables $colour.hostname $variables
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
					("`n$ip`t`t$hostname") | Out-File -FilePath $hostFile -Encoding ASCII -Append
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

function Test-Module($colour, $variables) {
    $hostFile = "$env:windir\System32\drivers\etc\hosts"
    if (!(Test-Path $hostFile)) {
        throw "Hosts file does not exist at: '$hostFile'."
    }

    $ensure = Replace-Variables $colour.ensure $variables
    if ([String]::IsNullOrWhiteSpace($ensure)) {
        throw 'No ensure parameter supplied for hosts update.'
    }

    # check we have a valid ensure property
    $ensure = $ensure.ToLower().Trim()
    if ($ensure -ne 'added' -and $ensure -ne 'removed') {
        throw "Invalid ensure parameter supplied for hosts: '$ensure'."
    }

    # check IP
    $ip = Replace-Variables $colour.ip $variables
    if ([String]::IsNullOrWhiteSpace($ip)) {
        $ip = [String]::Empty
    }

    # check hostname
    $hostname = Replace-Variables $colour.hostname $variables
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