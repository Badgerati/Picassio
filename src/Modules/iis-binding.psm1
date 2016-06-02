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
#			"type": "iis-binding",
#			"ensure": "added",
#			"siteName": "Example Site",
#			"ip": "127.0.0.3",
#			"port": 443,
#			"protocol": "https",
#			"certificate": "\*.local.com"
#		}
#	]
# }
#########################################################################

# Adds/removes a binding on a website via IIS
Import-Module $env:PicassioTools -DisableNameChecking -ErrorAction Stop
Import-Module WebAdministration -ErrorAction Stop
sleep 2

function Start-Module($colour, $variables, $credentials) {
	Test-Module $colour $variables $credentials

	$siteName = (Replace-Variables $colour.siteName $variables).Trim()
	$ensure = (Replace-Variables $colour.ensure $variables).ToLower().Trim()
	$protocol = (Replace-Variables $colour.protocol $variables).ToLower().Trim()

	$ip = (Replace-Variables $colour.ip $variables).Trim()
	$port = (Replace-Variables $colour.port $variables).Trim()
	$binding = ("*$ip" + ":" + "$port*")

	$siteExists = (Test-Path "IIS:\Sites\$siteName")

	if (!$siteExists) {
		throw "Website does not exist in IIS: '$siteName'."
	}

	$web = Get-Item "IIS:\Sites\$siteName"
	if (!$?) {
		throw
	}

	$col = $web.Bindings.Collection | Where-Object { $_.protocol -eq $protocol }

	switch ($ensure) {
		'added'
			{
				Write-Message "Setting up website $protocol binding for '$ip" + ":" + "$port'."

				if ($col -eq $null -or $col.Length -eq 0 -or $col.bindingInformation -notlike $binding) {
					New-WebBinding -Name $siteName -IPAddress $ip -Port $port -Protocol $protocol
					if (!$?) {
						throw
					}

					if ($protocol -eq 'https') {
						$certificate = (Replace-Variables $colour.certificate $variables).Trim()
						$certs = (Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -match $certificate } | Select-Object -First 1)

						if ([string]::IsNullOrWhiteSpace($certs)) {
							throw "Certificate passed cannot be found when setting up website binding: '$certificate'."
						}

						$thumb = $certs.Thumbprint.ToString()

						$sslBindingsPath = 'hklm:\SYSTEM\CurrentControlSet\services\HTTP\Parameters\SslBindingInfo\'
						$registryItems = Get-ChildItem -Path $sslBindingsPath | Where-Object -FilterScript { $_.Property -eq 'DefaultSslCtlStoreName' }

						If ($registryItems.Count -gt 0) {
							ForEach ($item in $registryItems) {
								$item | Remove-ItemProperty -Name DefaultSslCtlStoreName
								Write-Host "Deleted DefaultSslCtlStoreName in " $item.Name
							}
						}

						Push-Location IIS:\SslBindings

						Get-Item Cert:\LocalMachine\My\$thumb | New-Item $ip!$port -Force | Out-Null
						if (!$?) {
							Pop-Location
							throw
						}

						Pop-Location
					}
				}
				else {
					Write-Message 'Binding already exists.'
				}

				Write-Message 'Website binding setup successfully.'
			}

		'removed'
			{
				Write-Message "Removing website $protocol binding for '$ip" + ":" + "$port'."

				if ($col -ne $null -and $col.Length -gt 0 -and $colour.bindingInformation -like $binding) {
					Remove-WebBinding -Name $siteName -IPAddress $ip -Port $port -Protocol $protocol
					if (!$?) {
						throw
					}

					if ($protocol -eq 'https') {
						Push-Location IIS:\SslBindings

						Remove-Item $ip!$port -Force
						if (!$?) {
							Pop-Location
							throw
						}

						Pop-Location
					}
				}

				Write-Message 'Website binding removed successfully.'
			}
	}
}

function Test-Module($colour, $variables, $credentials) {
	if (!(Test-Win64)) {
		throw 'Shell needs to be running as a 64-bit host when setting up IIS website bindings.'
	}

	$siteName = Replace-Variables $colour.siteName $variables
	if ([string]::IsNullOrEmpty($siteName)) {
		throw 'No site name has been supplied for website.'
	}

	$ensure = Replace-Variables $colour.ensure $variables
    if ([string]::IsNullOrWhiteSpace($ensure)) {
        throw 'No ensure parameter supplied for website binding.'
    }

    # check we have a valid ensure property
    $ensure = $ensure.ToLower().Trim()
    if ($ensure -ne 'added' -and $ensure -ne 'removed') {
        throw "Invalid ensure supplied for website binding: '$ensure'."
    }

	$ip = Replace-Variables $colour.ip $variables
	if([string]::IsNullOrWhiteSpace($ip)) {
		throw 'No IP address passed to add website binding.'
	}

	$port = Replace-Variables $colour.port $variables
	if([string]::IsNullOrWhiteSpace($port)) {
		throw 'No port number passed to add website binding.'
	}

	$protocol = Replace-Variables $colour.protocol $variables
	if ([string]::IsNullOrWhiteSpace($protocol)) {
		throw 'No protocol passed for adding website binding.'
	}

	$protocol = $protocol.ToLower().Trim()
	if ($protocol -ne 'http' -and $protocol -ne 'https') {
		throw "Protocol for website binding is not valid. Expected http(s) but got: '$protocol'."
	}

	if ($ensure -eq 'added') {
		if ($protocol -eq 'https') {
			$certificate = Replace-Variables $colour.certificate $variables
			if ([string]::IsNullOrWhiteSpace($certificate)) {
				throw 'No certificate passed for setting up website binding https protocol.'
			}
		}

		$binding = ("*$ip" + ":" + "$port*")

		ForEach ($site in (Get-ChildItem IIS:\Sites)) {
			if ($site.Name -eq $siteName) {
				continue
			}

			$col = $site.Bindings.Collection | Where-Object { $_.protocol -eq $protocol }

			if ($col -eq $null -or $col.Length -eq 0) {
				continue
			}

			if ($col.bindingInformation -like $binding) {
				throw "Website already exists that uses $binding : '$($site.Name)'."
			}
		}
	}
}
