##########################################################################
# Picassio is a provisioning/deployment script which uses a single linear
# JSON file to determine what commands to execute.
#
# Copyright (c) 2015, Matthew Kelly (Badgerati)
# Company: Cadaeic Studios
# License: MIT (see LICENSE for details)
#########################################################################

# Add/removes a website on IIS
Import-Module $env:PicassioTools -DisableNameChecking
Import-Module WebAdministration
sleep 2

function Start-Module($colour) {
	Test-Module $colour

	$siteName = $colour.siteName.Trim()
	$appPoolName = $colour.appPoolName.Trim()
	$ensure = $colour.ensure.ToLower().Trim()
	$state = $colour.state
	$path = $colour.path
	$runtimeVersion = $colour.runtimeVersion
	$appPoolIdentity = $colour.appPoolIdentity
	$username = $colour.username
	$password = $colour.password
	$bindings = $colour.bindings
	$syncPaths = $colour.syncPaths

	$siteExists = (Test-Path "IIS:\Sites\$siteName")
	$poolExists = (Test-Path "IIS:\AppPools\$appPoolName")

	switch ($ensure) {
		'added'
			{
				Write-Message "Creating application pool: '$appPoolName'."

				if (!$poolExists) {
					$pool = New-WebAppPool -Name $appPoolName -Force
					if (!$?) {
						throw
					}

					if ([string]::IsNullOrWhiteSpace($runtimeVersion)) {
						$pool.managedRuntimeVersion = 'v4.0'
					}
					else {
						$pool.managedRuntimeVersion = $runtimeVersion
					}

					if ([string]::IsNullOrWhiteSpace($appPoolIdentity)) {
						if (![string]::IsNullOrWhiteSpace($username) -and ![string]::IsNullOrWhiteSpace($password)) {
							$appPoolIdentity = 'SpecificUser'
						}
						else {
							$appPoolIdentity = 'ApplicationPoolIdentity'
						}
					}

					$appPoolIdentity = $appPoolIdentity.ToLower().Trim()

					switch ($appPoolIdentity) {
						'applicationpoolidentity'
							{
								$pool.processmodel.identityType = 4
							}

						'localservice'
							{
								$pool.processmodel.identityType = 1
							}

						'localsystem'
							{
								$pool.processmodel.identityType = 0
							}

						'networkservice'
							{
								$pool.processmodel.identityType = 2
							}

						'specificuser'
							{
								$pool.processmodel.identityType = 3
								$pool.processmodel.username = $username
								$pool.processmodel.password = $password
							}
					}

					$pool | Set-Item
					if (!$?) {
						throw
					}
				}
				else {
					Write-Warnings 'Application pool already exists.'
				}

				Write-Message 'Application pool created successfully.'
				Write-Message "`nCreating website: '$siteName'."

				$path = $path.Trim()
				if (!(Test-Path $path)) {
					throw "Path passed to add website does not exist: '$path'."
				}

				if (!$siteExists) {
					New-Website -Name $siteName -PhysicalPath $path -ApplicationPool $appPoolName -Force | Out-Null
					if (!$?) {
						throw
					}

					Remove-WebBinding -Name $siteName -IPAddress * -Port 80 -Protocol 'http'
					if (!$?) {
						throw 'Failed to remove the default *:80 endpoint from the website.'
					}
				}
				else {
					Write-Warnings 'Website already exists, updating.'
					
					if (![string]::IsNullOrWhiteSpace($syncPaths) -and $syncPaths -eq $true) {
						$currentPath = (Get-Item "IIS:\Sites\$siteName" | Select-Object -ExpandProperty physicalPath)
						Write-Message "Current Path: '$currentPath'."

						$matchingSites = (Get-Website | Select-Object Name, physicalPath | Where-Object { $_.physicalPath -eq $currentPath } | Select-Object -ExpandProperty Name)
						Write-Message "Found $($matchingSites.Count) matching websites for current path."

						ForEach ($site in $matchingSites) {
							Write-Information "Updating website: '$site'."
							Set-ItemProperty -Path "IIS:\Sites\$site" -Name physicalPath -Value $path
						}
					}
					else {
						Set-ItemProperty -Path "IIS:\Sites\$siteName" -Name physicalPath -Value $path
					}
										
					Set-ItemProperty -Path "IIS:\Sites\$siteName" -Name applicationPool -Value $appPoolName
				}
				
				Write-Message 'Website created successfully.'
				Write-Message "`nSetting up website binding."
				
				$web = Get-Website -Name $siteName
				if (!$?) {
					throw
				}

				ForEach ($binding in $bindings) {
					$protocol = $binding.protocol.ToLower().Trim()
					$ip = $binding.ip.Trim()
					$port = $binding.port.Trim()

					$col = $web.Bindings.Collection | Where-Object { $_.protocol -eq $protocol }
					$endpoint = ("*$ip" + ":" + "$port*")

					Write-Message ("Setting up website $protocol binding for '$ip" + ":" + "$port'.")
					
					if ($col -eq $null -or $col.Length -eq 0 -or $col.bindingInformation -notlike $endpoint) {
						New-WebBinding -Name $siteName -IPAddress $ip -Port $port -Protocol $protocol
						if (!$?) {
							throw
						}

						if ($protocol -eq 'https') {
							$certificate = $binding.certificate.Trim()
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
						Write-Warnings ("Binding already exists: '$ip" + ":" + "$port'.")
					}
				}

				Write-Message 'Website binding setup successfully.'
				Write-Message "`nSetting up website folder user security permissions."
				
				$acl = Get-Acl -Path $path

				$iis_user = $acl.Access | ForEach-Object { $_.identityReference.value | Where-Object { $_ -imatch 'NT AUTHORITY\\IUSR' } } | Select-Object -First 1
				if ([string]::IsNullOrWhiteSpace($iis_user)) {
					Write-Message 'Adding IIS user.'
					$iis_ar = New-Object System.Security.AccessControl.FileSystemAccessRule("NT AUTHORITY\IUSR", "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow")
					$acl.SetAccessRule($iis_ar)
				}
				else {
					Write-Warnings 'IIS user already added.'
				}

				$app_user = $acl.Access | ForEach-Object { $_.identityReference.value | Where-Object { $_ -imatch "IIS APPPOOL\\$appPoolName" } } | Select-Object -First 1
				if ([string]::IsNullOrWhiteSpace($app_user)) {
					Write-Message 'Adding application pool user.'
					$app_ar = New-Object System.Security.AccessControl.FileSystemAccessRule("IIS APPPOOL\$appPoolName", "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow")
					$acl.SetAccessRule($app_ar)
				}
				else {
					Write-Warnings 'Application pool user already added.'
				}

				Set-Acl -Path $path -AclObject $acl

				Write-Message 'User security permissions setup successfully.'

				$state = $state.ToLower().Trim()

				Write-Message "`nEnsuring Application Pool and Website are $state."

				switch ($state) {
					'started'
						{
							Restart-WebAppPool -Name $appPoolName
							if (!$?) {
								throw
							}

							Start-Website -Name $siteName
							if (!$?) {
								throw
							}
						}

					'stopped'
						{
							Stop-WebAppPool -Name $appPoolName
							if (!$?) {
								throw
							}
							
							Stop-Website -Name $siteName
							if (!$?) {
								throw
							}
						}
				}
				
				Write-Message "Application Pool and Website have been $state."
			}

		'removed'
			{
				Write-Message "Removing website: '$siteName'."

				if ($siteExists) {
					Remove-Website -Name $siteName
					if (!$?) {
						throw
					}
				}
				else {
					Write-Warnings 'Website does not exist.'
				}
				
				Write-Message 'Website removed successfully.'
				Write-Message "`nRemoving application pool: '$appPoolName'."

				if ($poolExists) {
					Remove-WebAppPool -Name $appPoolName
					if (!$?) {
						throw
					}
				}
				else {
					Write-Warnings 'Application pool does not exist.'
				}
				
				Write-Message 'Application pool removed successfully.'
			}
	}
}

function Test-Module($colour) {
	if (!(Test-Win64)) {
		throw 'Shell needs to be running as a 64-bit host when setting up IIS websites.'
	}

	$siteName = $colour.siteName
	if ([string]::IsNullOrEmpty($siteName)) {
		throw 'No site name has been supplied for website.'
	}

	$siteName = $siteName.Trim()

	$appPoolName = $colour.appPoolName
	if ([string]::IsNullOrEmpty($appPoolName)) {
		throw 'No app pool name has been supplied for website.'
	}
	
	$appPoolName = $appPoolName.Trim()
	
	$siteExists = (Test-Path "IIS:\Sites\$siteName")
	$poolExists = (Test-Path "IIS:\AppPools\$appPoolName")

	$ensure = $colour.ensure
    if ([string]::IsNullOrWhiteSpace($ensure)) {
        throw 'No ensure parameter supplied for website.'
    }

    # check we have a valid ensure property
    $ensure = $ensure.ToLower().Trim()
    if ($ensure -ne 'added' -and $ensure -ne 'removed') {
        throw "Invalid ensure parameter supplied for website: '$ensure'."
    }

	$state = $colour.state
    if ([string]::IsNullOrWhiteSpace($state) -and $ensure -eq 'added') {
        throw 'No state parameter supplied for website.'
    }
	
    # check we have a valid state property
	if ($state -ne $null) {
		$state = $state.ToLower().Trim()
	}

    if ($state -ne 'started' -and $state -ne 'stopped' -and $ensure -eq 'added') {
        throw "Invalid state parameter supplied for website: '$state'."
    }

    $path = $colour.path
	if ($ensure -eq 'added') {
		if ([string]::IsNullOrWhiteSpace($path)) {
			throw 'No path passed to add website.'
		}
	}

	$syncPaths = $colour.syncPaths
	if (![string]::IsNullOrWhiteSpace($syncPaths) -and $syncPaths -ne $true -and $syncPaths -ne $false) {
		throw "Invalid value for syncPaths: '$syncPaths'. Should be either true or false."
	}

	$runtimeVersion = $colour.runtimeVersion
	if (![string]::IsNullOrWhiteSpace($runtimeVersion) -and $ensure -eq 'added') {
		if ($runtimeVersion -notmatch 'v(1.1|2.0|4.0)') {
			throw "Invalid runtime version value supplied. Can only be v1.1, v2.0 or v4.0. Got: $runtimeVersion"
		}
	}

	$appPoolIdentity = $colour.appPoolIdentity
	if (![string]::IsNullOrWhiteSpace($appPoolIdentity) -and $ensure -eq 'added') {
		$appPoolIdentity = $appPoolIdentity.ToLower().Trim()

		if ($appPoolIdentity -inotmatch '(ApplicationPoolIdentity|LocalService|LocalSystem|NetworkService|SpecificUser)') {
			throw "Invalid application pool identity: '$appPoolIdentity'. Should be either ApplicationPoolIdentity, LocalService, LocalSystem, NetworkService or SpecificUser."
		}

		if ($appPoolIdentity -ieq 'SpecificUser') {
			$username = $colour.username
			$password = $colour.password

			if ([string]::IsNullOrWhiteSpace($username) -or [string]::IsNullOrWhiteSpace($password)) {
				throw 'SpecificUser passed for application pool identity, but not username/password passed.'
			}
		}
	}

	$bindings = $colour.bindings
	if ($ensure -eq 'added' -and ($bindings -eq $null -or $bindings.Length -eq 0)) {
		throw 'No bindings specified to setup website.'
	}

	if ($ensure -eq 'added' -and $bindings.Length -gt 0) {
		ForEach ($binding in $bindings) {
			$ip = $binding.ip
			if([string]::IsNullOrWhiteSpace($ip)) {
				throw 'No IP address passed to add website binding.'
			}

			$port = $binding.port
			if([string]::IsNullOrWhiteSpace($port)) {
				throw 'No port number passed to add website binding.'
			}

			$protocol = $binding.protocol	
			if ([string]::IsNullOrWhiteSpace($protocol)) {
				throw 'No protocol passed for adding website binding.'
			}

			$protocol = $protocol.ToLower().Trim()
			if ($protocol -ne 'http' -and $protocol -ne 'https') {
				throw "Protocol for website binding is not valid. Expected http(s) but got: '$protocol'."
			}

			if ($protocol -eq 'https') {
				$certificate = $binding.certificate
				if ([string]::IsNullOrWhiteSpace($certificate)) {
					throw 'No certificate passed for setting up website binding https protocol.'
				}

				$certificate = $certificate.Trim()
				$certExists = (Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -match $certificate } | Select-Object -First 1)

				if ([string]::IsNullOrWhiteSpace($certExists)) {
					throw "Certificate passed cannot be found when setting up website binding: '$certificate'."
				}
			}

			$endpoint = ("*$ip" + ":" + "$port*")

			ForEach ($site in (Get-ChildItem IIS:\Sites)) {
				if ($site.Name -eq $siteName) {
					continue
				}

				$col = $site.Bindings.Collection | Where-Object { $_.protocol -eq $protocol }

				if ($col -eq $null -or $col.Length -eq 0) {
					continue
				}

				if ($col.bindingInformation -like $endpoint) {
					throw "Website already exists that uses $endpoint : '$($site.Name)'."
				}
			}
		}
	}
}