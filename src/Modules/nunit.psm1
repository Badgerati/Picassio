##########################################################################
# Picassio is a provisioning/deployment script which uses a single linear
# JSON file to determine what commands to execute.
#
# Copyright (c) 2015, Matthew Kelly (Badgerati)
# Company: Cadaeic Studios
# License: MIT (see LICENSE for details)
#########################################################################

# Use NUnit to run tests
Import-Module $env:PicassioTools -DisableNameChecking

function Start-Module($colour) {
	Test-Module $colour

    $path = $colour.path.Trim()
	if (!(Test-Path $path)) {
        throw "Path to nunit-console.exe does not exist: '$path'"
    }
	
	$tests = $colour.tests
	$args = $colour.arguments

	if ($args -eq $null) {
		$args = ""
	}

	ForEach ($test in $tests) {
		$test = $test.Trim()

		if (!(Test-Path $test)) {
			throw "Path to test does not exist: '$test'"
		}
	}	

	$test_string = ($tests -join ' ')
	$command = "`"$path`" $test_string $args"

	Write-Message 'Running tests.'
	(cmd.exe /C $command)

	if (!$?) {
		throw 'Some of the tests have failed.'
	}

	Write-Message 'Tests ran successfully.'
}

function Test-Module($colour) {
    $path = $colour.path
	if ([String]::IsNullOrWhiteSpace($path)) {
		throw 'No path specified to the location of NUint.'
	}
	
	$tests = $colour.tests
	if ($tests -eq $null -or $tests.Length -eq 0) {
		throw 'No tests have been supplied for NUnit.'
	}
	
	ForEach ($test in $tests) {
		if ([string]::IsNullOrWhiteSpace($test)) {
			throw 'No path specified for tests.'
		}
	}
}