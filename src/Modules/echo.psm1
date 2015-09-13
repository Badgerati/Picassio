# Simple echo module to display whatever is written
Import-Module $env:PicassioTools -DisableNameChecking

function Start-Module($colour) {
	Validate-Module $colour

	$text = $colour.text
	Write-Host $text
    
    if (!$?) {
        throw "Failed to echo: '$text'."
    }
}

function Validate-Module($colour) {
	$text = $colour.text
    if ([string]::IsNullOrWhiteSpace($text)) {
        throw 'No text passed to echo.'
    }
}