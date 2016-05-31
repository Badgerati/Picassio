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
#			"type": "cake",
#			"path": "C:\\path\\to\\project",
#			"name": "build.cake"
#		}
#	]
# }
#########################################################################

# Calls cake buid from the specified path where a cake script can be found
Import-Module $env:PicassioTools -DisableNameChecking

function Start-Module($colour, $variables) {
	Test-Module $colour $variables

    if (!(Test-Software 'cake.exe -version' 'cake')) {
        Write-Errors 'Cake is not installed'
        Install-AdhocSoftware 'cake.portable' 'Cake'
    }

    $path = (Replace-Variables $colour.path $variables).Trim()
    if (!(Test-Path $path)) {
        throw "Path specified to project doesn't exist: '$path'."
    }

    $name = (Replace-Variables $colour.name $variables).Trim()
	if ([string]::IsNullOrWhiteSpace($name)) {
		$name = 'build.cake'
	}

	if (!(Test-Path (Join-Path $path $name))) {
		throw "Cake build script does not exist at path: '$name'."
	}

	Write-Message "Running Cake."
    Push-Location $path

	try {
		cake.exe $name

		if (!$?) {
			throw 'Failed to call cake.'
		}
	}
	finally {
		Pop-Location
	}

    Write-Message "Cake build was successful."
}

function Test-Module($colour, $variables) {
    $path = Replace-Variables $colour.path $variables
    if ([string]::IsNullOrWhiteSpace($path)) {
        throw 'No path specified to a directory where the project is located.'
    }
}