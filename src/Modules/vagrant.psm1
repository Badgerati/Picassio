# Calls vagrant from a specified path where a Vagrantfile can be found
Import-Module $env:PicassioTools -DisableNameChecking

function Start-Module($colour) {
	Validate-Module $colour

    if (!(Test-Software vagrant.exe 'vagrant')) {
        Write-Error 'Vagrant is not installed'
        Install-AdhocSoftware 'vagrant' 'Vagrant'
    }

    $path = $colour.path.Trim()
    $command = $colour.command.Trim()

	Write-Message "Running vagrant $command."
    Push-Location $path
    vagrant.exe $command
    
    if (!$?) {
        Pop-Location
        throw 'Failed to call vagrant.'
    }

    Pop-Location
    Write-Message "vagrant $command, successful."
}

function Validate-Module($colour) {
    $path = $colour.path
    if ([string]::IsNullOrWhiteSpace($path)) {
        throw 'No path specified to parent directory where the Vagrantfile is located.'
    }
    
	$path = $path.Trim()

    if (!(Test-Path $path)) {
        throw "Path specified to Vagrantfile doesn't exist: '$path'."
    }

    $command = $colour.command
    if ([string]::IsNullOrWhiteSpace($command)) {
        throw 'No command specified for which to call vagrant.'
    }
}