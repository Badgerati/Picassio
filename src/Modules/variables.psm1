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
#			"type": "variables",
#			"variables": [
#				{ "value1": true },
#				{ "value2": "added" }
#			]
#		}
#	]
# }
#
# Variables are used in other values by doing: { "ensure": "#(value2)" }
# which using the example above will be replaced by "added"
#########################################################################

# Parses the passed variables colour and inserts/updates them
Import-Module $env:PicassioTools -DisableNameChecking -ErrorAction Stop

function Start-Module($colour, $variables, $credentials)
{
    Test-Module $colour $variables $credentials
}

function Test-Module($colour, $variables, $credentials)
{
	$vars = $colour.variables
	if ($vars -eq $null -or $vars.Length -eq 0)
    {
		return
	}

	$pattern = Get-VariableRegex
	$invalid = ($vars | Where-Object { $_.PSObject.Properties.Name -notmatch $pattern })

	if ($invalid -ne $null -and $invalid.Length -ne 0)
    {
		Write-Errors "Invalid variable names found. Variable names can only be alphanumeric`n$invalid"
		throw
	}

    $vars | ForEach-Object { $variables[$_.PSObject.Properties.Name] = $_.PSObject.Properties.Value }
	if (!$?)
    {
		throw 'Variables failed to setup.'
	}
}
