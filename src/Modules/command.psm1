##########################################################################
# Picassio is a provisioning/deployment script which uses a single linear
# JSON file to determine what commands to execute.
#
# Copyright (c) 2015, Matthew Kelly (Badgerati)
# Company: Cadaeic Studios
# License: MIT (see LICENSE for details)
#########################################################################

# Run a passed command using Command Prompt/PowerShell
Import-Module $env:PicassioTools -DisableNameChecking

function Start-Module($colour) {
	Test-Module $colour

    $command = $colour.command
    $prompt = $colour.prompt
    if ([string]::IsNullOrWhiteSpace($prompt)) {
        Write-Message 'No prompt type passed, defaulting to Command Prompt.'
        $prompt = 'cmd'
    }

	$path = $colour.path
	if (![string]::IsNullOrWhiteSpace($path)) {
		if (!(Test-Path $path)) {
			throw "Path to run command does not exist: '$path'"
		}

		Push-Location $path
	}

    # determine which prompt in which to run the command
    switch ($prompt.ToLower()) {
        'cmd'
            {
                Write-Message 'Running command via Command Prompt.'
                cmd.exe /C $command
				if ($LASTEXITCODE -ne 0) {
					Pop-Location
					throw "Failed to run command: '$command'."
				}
            }

        'powershell'
            {
                Write-Message 'Running command via PowerShell.'
                powershell.exe /C $command
				if (!$?) {
					Pop-Location
					throw "Failed to run command: '$command'."
				}
            }

        default
            {
                throw "unrecognised prompt for command colour: '$prompt'."
            }
    }
    	
	Pop-Location
    Write-Message 'Command ran successfully.'
}

function Test-Module($colour) {
	$command = $colour.command
    if ([string]::IsNullOrWhiteSpace($command)) {
        throw 'No command passed to run via Command Prompt.'
    }
}