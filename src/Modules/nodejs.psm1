# Opens a new Powershell host, and runs the node command on the passed file
Import-Module $env:PicassioTools -DisableNameChecking

function Start-Module($colour) {
	Validate-Module $colour

	if (!(Test-Software node.exe 'node.js')) {
        Write-Errors 'Node.js is not installed'
        Install-AdhocSoftware 'nodejs.install' 'node.js'
    }

    $file = $colour.file
	if (!(Test-Path $file)) {
		throw "Path to file to run for node does not exist: '$file'"
	}

	Push-Location (Split-Path -Parent $file)
	$_file = (Split-Path -Leaf $file)
	Start-Process powershell.exe -ArgumentList "node $_file"
	    
    if (!$?) {
		Pop-Location
        throw "Failed to run node for: '$file'."
    }
	
	Pop-Location
    Write-Message 'Node ran successfully.'
}

function Validate-Module($colour) {
	$file = $colour.file
    if ([string]::IsNullOrWhiteSpace($file)) {
        throw 'No file passed to run for node.'
    }
}