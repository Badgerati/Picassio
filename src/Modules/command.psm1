# Run a passed command using Command Prompt/PowerShell
Import-Module $env:PICASSO_TOOLS -DisableNameChecking

function Start-Module($colour) {
    $command = $colour.command
    if ([string]::IsNullOrWhiteSpace($command)) {
        Write-Error 'No command passed to run via Command Prompt.'
        return
    }

    $prompt = $colour.prompt
    if ([string]::IsNullOrWhiteSpace($prompt)) {
        Write-Message 'No prompt type passed, defaulting to Command Prompt.'
        $prompt = 'cmd'
    }

    # determine which prompt in which to run the command
    switch ($prompt.ToLower()) {
        'cmd'
            {
                Write-Message 'Running command via Command Prompt.'
                cmd.exe /C $command
            }

        'powershell'
            {
                Write-Message 'Running command via PowerShell.'
                powershell.exe /C $command
            }

        default
            {
                throw "unrecognised prompt for command colour: '$prompt'."
            }
    }
    
    if (!$?) {
        throw "Failed to run command: '$command'."
    }

    Write-Message 'Command ran successfully.'
}