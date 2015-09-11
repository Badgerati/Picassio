# Simple echo module to display whatever is written
Import-Module $env:PicassoTools -DisableNameChecking

function Start-Module($colour) {
	$text = $colour.text
    if ([string]::IsNullOrWhiteSpace($text)) {
        Write-Error 'No text passed to echo.'
        return
    }

	$command = "echo $text"
    cmd.exe /C $command
    
    if (!$?) {
        throw "Failed to echo: '$text'."
    }
}