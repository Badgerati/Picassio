# Adds/removes a binding on a website via IIS
Import-Module $env:PicassioTools -DisableNameChecking
Import-Module WebAdministration

function Start-Module($colour) {
	Validate-Module $colour

	$siteName = $colour.siteName.Trim()
	$ensure = $colour.ensure.ToLower().Trim()
	$protocol = $colour.protocol.ToLower().Trim()
	$certificate = $colour.certificate
	$ip = $colour.ip.Trim()
	$port = $colour.port.Trim()
	$binding = ("*$ip" + ":" + "$port*")

	$siteExists = (Test-Path "IIS:\Sites\$siteName")

	if (!$siteExists) {
		throw "Website does not exist in IIS: '$siteName'."
	}

	$web = Get-Website -Name $siteName
	$col = $web.Bindings.Collection | Where-Object { $_.protocol -eq $protocol }

	switch ($ensure) {
		'added'
			{
				Write-Message ("Setting up website $protocol binding for '$ip" + ":" + "$port'.")
				
				if ($col -eq $null -or $col.Length -eq 0 -or $col.bindingInformation -notlike $binding) {
					New-WebBinding -Name $siteName -IPAddress $ip -Port $port -Protocol $protocol
					if (!$?) {
						throw
					}

					if ($protocol -eq 'https') {
						$certificate = $certificate.Trim()
						$certs = (Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -match $certificate } | Select-Object -First 1)
						$thumb = $certs.Thumbprint.ToString()

						Push-Location IIS:\SslBindings

						Get-Item Cert:\LocalMachine\My\$thumb | New-Item $ip!$port -Force
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
				Write-Message ("Removing website $protocol binding for '$ip" + ":" + "$port'.")

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

function Validate-Module($colour) {
	if (!(Test-Win64)) {
		throw 'Shell needs to be running as a 64-bit host when setting up IIS website bindings.'
	}

	$siteName = $colour.siteName
	if ([string]::IsNullOrEmpty($siteName)) {
		throw 'No site name has been supplied for website.'
	}

	$ensure = $colour.ensure
    if ([string]::IsNullOrWhiteSpace($ensure)) {
        throw 'No ensure parameter supplied for website binding.'
    }

    # check we have a valid ensure property
    $ensure = $ensure.ToLower().Trim()
    if ($ensure -ne 'added' -and $ensure -ne 'removed') {
        throw "Invalid ensure parameter supplied for website binding: '$ensure'."
    }

	$ip = $colour.ip
	if([string]::IsNullOrWhiteSpace($ip)) {
		throw 'No IP address passed to add website binding.'
	}

	$port = $colour.port
	if([string]::IsNullOrWhiteSpace($port)) {
		throw 'No port number passed to add website binding.'
	}

	$protocol = $colour.protocol
		
	if ([string]::IsNullOrWhiteSpace($protocol)) {
		throw 'No protocol passed for adding website binding.'
	}
		
	$protocol = $protocol.ToLower().Trim()
	if ($protocol -ne 'http' -and $protocol -ne 'https') {
		throw "Protocol for website binding is not valid. Expected http(s) but got: '$protocol'."
	}
	
	if ($ensure -eq 'added') {
		if ($protocol -eq 'https') {
			$certificate = $colour.certificate
			if ([string]::IsNullOrWhiteSpace($certificate)) {
				throw 'No certificate passed for setting up website binding https protocol.'
			}

			$certificate = $certificate.Trim()
			$certExists = (Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -match $certificate } | Select-Object -First 1)

			if ([string]::IsNullOrWhiteSpace($certExists)) {
				throw "Certificate passed cannot be found when setting up website binding: '$certificate'."
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