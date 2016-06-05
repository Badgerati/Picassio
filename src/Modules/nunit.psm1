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
#			"type": "nunit",
#			"path": "C:\\path\\to\\nunit-console.exe",
#			"arguments": "/include:UnitTest /nologo",
#			"tests": [
#				"Example\\Test1.dll",
#				"Example\\Test2.dll"
#			]
#		}
#	]
# }
#########################################################################

# Use NUnit to run tests
Import-Module $env:PicassioTools -DisableNameChecking -ErrorAction Stop

function Start-Module($colour, $variables, $credentials)
{
    Test-Module $colour $variables $credentials

    $path = (Replace-Variables $colour.path $variables).Trim()
    if (!(Test-Path $path))
    {
        throw "Path to nunit-console.exe does not exist: '$path'"
    }

    $tests = $colour.tests

    $_args = Replace-Variables $colour.arguments $variables
    if ($_args -eq $null) {
        $_args = [string]::Empty
    }

    ForEach ($test in $tests)
    {
        $test = (Replace-Variables $test $variables).Trim()

        if (!(Test-Path $test))
        {
            throw "Path to test does not exist: '$test'"
        }
    }

    Write-Information "Arguments: '$_args'."
    Write-Message 'Running tests.'

    $test_string = Replace-Variables ($tests -join ' ') $variables
    Run-Command $path "$test_string $_args"

    Write-Message 'Tests ran successfully.'
}

function Test-Module($colour, $variables, $credentials)
{
    $path = Replace-Variables $colour.path $variables
    if ([String]::IsNullOrWhiteSpace($path))
    {
        throw 'No path specified to the location of NUint.'
    }

    $tests = $colour.tests
    if ($tests -eq $null -or $tests.Length -eq 0)
    {
        throw 'No tests have been supplied for NUnit.'
    }

    ForEach ($test in $tests)
    {
        if ([string]::IsNullOrWhiteSpace($test))
        {
            throw 'No path specified for tests.'
        }
    }
}
