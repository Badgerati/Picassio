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
#			"type": "command",
#			"prompt": "powershell",
#			"command": "Write-Host 'Hello, world!'"
#		}
#	]
# }
#########################################################################

# Run a passed command using Command Prompt/PowerShell
Import-Module $env:PicassioTools -DisableNameChecking

function Start-Module($colour, $variables) {
	Test-Module $colour $variables

    $command = (Replace-Variables $colour.command $variables).Trim()
    $prompt = Replace-Variables $colour.prompt $variables
    if ([string]::IsNullOrWhiteSpace($prompt)) {
        Write-Message 'No prompt type passed, defaulting to Command Prompt.'
        $prompt = 'cmd'
    }

	$path = Replace-Variables $colour.path $variables
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
				Write-Information "Command: $command"
                cmd.exe /C $command
				if ($LASTEXITCODE -ne 0) {
					Pop-Location
					throw "Failed to run command: '$command'."
				}
            }

        'powershell'
            {
                Write-Message 'Running command via PowerShell.'
				Write-Information "Command: $command"
                powershell.exe /C $command
				if (!$?) {
					Pop-Location
					throw "Failed to run command: '$command'."
				}
            }

        default
            {
                throw "Unrecognised prompt for command colour: '$prompt'."
            }
    }

	Pop-Location
    Write-Message 'Command ran successfully.'
}

function Test-Module($colour, $variables) {
	$command = Replace-Variables $colour.command $variables
    if ([string]::IsNullOrWhiteSpace($command)) {
        throw 'No command passed to run via Command Prompt.'
    }
}