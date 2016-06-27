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
#			"ensure": "add",
#			"ip": "127.0.0.3",
#			"hostname": "test.local.com"
#		}
#	]
# }
#########################################################################

# Updates the hosts file
Import-Module $env:PicassioTools -DisableNameChecking -ErrorAction Stop

function Start-Module($colour, $variables, $credentials)
{
    Test-Module $colour $variables $credentials

    $hostFile = "$env:windir\System32\drivers\etc\hosts"
    $ensure = (Replace-Variables $colour.ensure $variables).ToLower().Trim()

    # check IP
    $ip = Replace-Variables $colour.ip $variables
    if ([String]::IsNullOrWhiteSpace($ip))
    {
        $ip = [String]::Empty
    }
    else
    {
        $ip = $ip.Trim()
    }

    # check hostname
    $hostname = Replace-Variables $colour.hostname $variables
    if ([String]::IsNullOrWhiteSpace($hostname))
    {
        $hostname = [String]::Empty
    }
    else
    {
        $hostname = $hostname.Trim()
    }

    Write-Message "Attempting to $ensure '$ip - $hostname'."
    $regex = ".*?$ip.*?$hostname.*?"
    $lines = Get-Content $hostFile

    switch ($ensure)
    {
        'add'
            {
                $current = ($lines | Where-Object { $_ -match $regex } | Measure-Object).Count

                if ($current -eq 0)
                {
                    ("`n$ip`t`t$hostname") | Out-File -FilePath $hostFile -Encoding ASCII -Append
                }
                else
                {
                    Write-Message 'Host entry already exists.'
                }
            }

        'remove'
            {
                $lines | Where-Object { $_ -notmatch $regex } | Out-File -FilePath $hostFile -Encoding ASCII
            }
    }

    if (!$?)
    {
        throw "Failed to $ensure '$ip - $hostname' to the hosts file."
    }

    Write-Message "$ensure of '$ip - $hostname' successful."
}

function Test-Module($colour, $variables, $credentials)
{
    $hostFile = "$env:windir\System32\drivers\etc\hosts"
    if (!(Test-Path $hostFile))
    {
        throw "Hosts file does not exist at: '$hostFile'."
    }

    $ensure = Replace-Variables $colour.ensure $variables
    $ensures = @('add', 'remove')
    if ([string]::IsNullOrWhiteSpace($ensure) -or $ensures -inotcontains ($ensure.Trim()))
    {
        throw ("Invalid ensure found: '$ensure'. Can be only: {0}." -f ($ensures -join ', '))
    }

    # check IP
    $ip = Replace-Variables $colour.ip $variables
    if ([String]::IsNullOrWhiteSpace($ip))
    {
        $ip = [String]::Empty
    }

    # check hostname
    $hostname = Replace-Variables $colour.hostname $variables
    if ([String]::IsNullOrWhiteSpace($hostname))
    {
        $hostname = [String]::Empty
    }

    if ($ensure -eq 'add' -and ([String]::IsNullOrWhiteSpace($ip) -or [String]::IsNullOrWhiteSpace($hostname)))
    {
        throw 'No IP or Hostname has been supplied for adding a host entry.'
    }
    elseif ($ensure -eq 'remove' -and [String]::IsNullOrWhiteSpace($ip) -and [String]::IsNullOrWhiteSpace($hostname))
    {
        throw 'No IP and Hostname have been supplied for removing a host entry.'
    }
}
