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
#			"type": "echo",
#			"text": "Hello, world!"
#		}
#	]
# }
#########################################################################

# Simple echo module to display whatever is written
Import-Module $env:PicassioTools -DisableNameChecking

function Start-Module($colour, $variables) {
	Test-Module $colour $variables

	$text = Replace-Variables $colour.text $variables
	Write-Host $text

    if (!$?) {
        throw "Failed to echo: '$text'."
    }
}

function Test-Module($colour, $variables) {
	$text = Replace-Variables $colour.text $variables
    if ([string]::IsNullOrWhiteSpace($text)) {
        throw 'No text passed to echo.'
    }
}