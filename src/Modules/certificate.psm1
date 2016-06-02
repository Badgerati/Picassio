##########################################################################
# Picassio is a provisioning/deployment script which uses a single linear
# JSON file to determine what commands to execute.
#
# Copyright (c) 2015, Matthew Kelly (Badgerati)
# Company: Cadaeic Studios
# License: MIT (see LICENSE for details)
#
# {
#	"paint": [
#		{
#			"type": "certificate",
#			"esnure": "imported",
#			"certStoreType: "LocalMachine",
#			"certStoreName": "Root",
#			"certPath": "C:\\path\\to\\cert.cer"
#		}
#	]
# }
#########################################################################

# Imports/Exports a certificate on MMC
Import-Module $env:PicassioTools -DisableNameChecking -ErrorAction Stop

function Start-Module($colour, $variables, $credentials) {
	Test-Module $colour $variables $credentials

	$certStoreType = (Replace-Variables $colour.certStoreType $variables).Trim()
	$certStoreName = (Replace-Variables $colour.certStoreName $variables).Trim()
	if (!(Test-Path "Cert:\$certStoreType\$certStoreName")) {
		throw "Cetificate store does not exist 'Cert:\$certStoreType\$certStoreName'."
	}

	$ensure = (Replace-Variables $colour.ensure $variables).ToLower().Trim()
	$certPass = (Replace-Variables $colour.certPass $variables)
	$certPath = (Replace-Variables $colour.certPath $variables).Trim()

	switch ($ensure) {
		'exported'
			{
				$certificate = (Replace-Variables $colour.certificate $variables).Trim()
				Write-Message "Exporting certificate '$certificate' to '$certPath'."

				$certs = (Get-ChildItem "Cert:\$certStoreType\$certStoreName" | Where-Object { $_.Subject -match $certificate } | Select-Object -First 1)

				if ([string]::IsNullOrWhiteSpace($certs)) {
					throw "Certificate pattern passed cannot be found for exporting certificate: '$certificate'."
				}

				$certType = (Replace-Variables $colour.certType $variables).ToLower().Trim()

				ForEach ($cert in $certs) {
					switch ($certType) {
						'cert'
							{
								$bytes = $cert.Export('CERT')
							}

						'pfx'
							{
								$bytes = $cert.Export('PFX', $certPass)
							}
					}

					[System.IO.File]::WriteAllBytes($certPath, $bytes)
				}

				if (!$?) {
					throw
				}

				Write-Message 'Certificate exported successfully.'
			}

		'imported'
			{
				Write-Message "Importing certificate '$certPath' to '$certStoreType\$certStoreName'."

				if (!(Test-Path $certPath)) {
					throw "Certificate path does not exist: '$certPath'."
				}

				$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2

				if ([string]::IsNullOrEmpty($certPass)) {
					$cert.Import($certPath)
				}
				else {
					$cert.Import($certPath, $certPass, 'Exportable, PersistKeySet')
				}

				if (!$?) {
					throw
				}

				$store = New-Object System.Security.Cryptography.X509Certificates.X509Store($certStoreName, $certStoreType)
				$store.Open("MaxAllowed")
				$store.Add($cert)

				if (!$?) {
					throw
				}

				$store.Close()

				if (!$?) {
					throw
				}

				Write-Message 'Certificate imported successfully.'
			}
	}
}

function Test-Module($colour, $variables, $credentials) {
	# check we have a valid cert store type
	$certStoreType = (Replace-Variables $colour.certStoreType $variables)
	if ([string]::IsNullOrEmpty($certStoreType)) {
		throw 'No certificate store type has been supplied.'
	}

	$certStoreType = $certStoreType.Trim()

	# check we have a valid cert store name
	$certStoreName = (Replace-Variables $colour.certStoreName $variables)
	if ([string]::IsNullOrEmpty($certStoreName)) {
		throw 'No certificate store name has been supplied.'
	}

	$certStoreName = $certStoreName.Trim()

	# check we have a valid cert path to export to
	$certPath = (Replace-Variables $colour.certPath $variables)
	if ([string]::IsNullOrEmpty($certPath)) {
		throw 'No certificate path has been supplied.'
	}

    # check we have a valid ensure property
	$ensure = (Replace-Variables $colour.ensure $variables)
    if ([string]::IsNullOrWhiteSpace($ensure)) {
        throw 'No ensure parameter supplied for certificate.'
    }

    $ensure = $ensure.ToLower().Trim()
    if ($ensure -ne 'imported' -and $ensure -ne 'exported') {
        throw "Invalid ensure supplied for certificate: '$ensure'."
    }

	if ($ensure -eq 'exported') {
		$certificate = (Replace-Variables $colour.certificate $variables)
		if ([string]::IsNullOrWhiteSpace($certificate)) {
			throw 'No certificate pattern passed for exporting certificate.'
		}

		$certType = (Replace-Variables $colour.certType $variables)
		if ([string]::IsNullOrWhiteSpace($certificate)) {
			throw 'No certificate type passed for exporting certificate.'
		}

		$certType = $certType.ToLower().Trim()
		if ($certType -ne 'cert' -and $certType -ne 'pfx') {
			throw "Invalid certificate type supplied for exporting: '$certType'."
		}
	}
}
