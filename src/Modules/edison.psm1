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
#			"type": "edison",
#           "fixtureThreads": 2,
#           "testThreads": 2,
#           "outputType": "json",
#           "url": "http://some.com/url",
#           "testId": "ID",
#           "exclude": [
#               "SomeCategory"
#           ],
#           "include": [
#               "SomeCategory2"
#           ],
#			"tests": [
#				"Example\\Test1.dll",
#				"Example\\Test2.dll"
#			]
#		}
#	]
# }
#########################################################################

# Use Edison to run tests
Import-Module $env:PicassioTools -DisableNameChecking -ErrorAction Stop

function Start-Module($colour, $variables, $credentials)
{
    Test-Module $colour $variables $credentials

    if (!(Test-Software 'Edison.Console.exe --version' 'Edison'))
    {
        Write-Errors 'Edison is not installed'
        Install-AdhocSoftware 'edison' 'Edison'
    }

    $tests = $colour.tests
    $excludes = $colour.exclude
    $includes = $colour.include

    $url = Replace-Variables $colour.url $variables
    $testId = Replace-Variables $colour.testId $variables

    $fixtureThreads = Replace-Variables $colour.fixtureThreads $variables
    if ([string]::IsNullOrWhiteSpace($fixtureThreads))
    {
        $fixtureThreads = 1
    }

    $testThreads = Replace-Variables $colour.testThreads $variables
    if ([string]::IsNullOrWhiteSpace($testThreads))
    {
        $testThreads = 1
    }

    $outputType = Replace-Variables $colour.outputType $variables
    if ([string]::IsNullOrWhiteSpace($outputType))
    {
        $outputType = 'json'
    }

    # Join the tests
    ForEach ($test in $tests)
    {
        $test = (Replace-Variables $test $variables).Trim()

        if (!(Test-Path $test))
        {
            throw "Path to test does not exist: '$test'."
        }
    }

    $test_string = Replace-Variables ($tests -join ', ') $variables

    # Setup the final argument string
    $final_args = "--a $test_string --cot dot --ft $fixtureThreads --tt $testThreads --ot $outputType"

    # Add the test URL if we have one
    if (![string]::IsNullOrWhiteSpace($url))
    {
        $final_args += " --url $url --tid $testId"
    }

    # If we have any excluded categories, add them
    if ($excludes -ne $null -and $excludes.Length -gt 0)
    {
        $exclude_string = Replace-Variables ($excludes -join ', ') $variables
        $final_args += " --exclude $exclude_string"
    }

    # If we have any included categories, add them
    if ($includes -ne $null -and $includes.Length -gt 0)
    {
        $include_string = Replace-Variables ($includes -join ', ') $variables
        $final_args += " --include $include_string"
    }

    Write-Message 'Running tests.'
    Run-Command 'Edison.Console.exe' "$final_args"
    Write-Message 'Tests ran successfully.'
}

function Test-Module($colour, $variables, $credentials)
{
    # Check the specified tests
    $tests = $colour.tests
    if ($tests -eq $null -or $tests.Length -eq 0)
    {
        throw 'No tests have been supplied for Edison.'
    }

    ForEach ($test in $tests)
    {
        $test = Replace-Variables $test $variables

        if ([string]::IsNullOrWhiteSpace($test))
        {
            throw 'No path specified for tests.'
        }
    }

    # Check the categoies if any have been supplied
    $excludes = $colour.exclude
    if ($excludes -ne $null -and $excludes.Length -gt 0)
    {
        ForEach ($exclude in $excludes)
        {
            $exclude = Replace-Variables $exclude $variables

            if ([string]::IsNullOrWhiteSpace($exclude))
            {
                throw 'Excluded category cannot be empty.'
            }
        }
    }

    $includes = $colour.include
    if ($includes -ne $null -and $includes.Length -gt 0)
    {
        ForEach ($include in $includes)
        {
            $include = Replace-Variables $include $variables

            if ([string]::IsNullOrWhiteSpace($include))
            {
                throw 'Included category cannot be empty.'
            }
        }
    }

    # Check thread values aren't negative or 0
    $fixtureThreads = Replace-Variables $colour.fixtureThreads $variables
    if (![string]::IsNullOrWhiteSpace($fixtureThreads) -and $fixtureThreads -lt 0)
    {
        throw "Fixture thread value must be greater than 0, but got '$fixtureThreads'."
    }

    $testThreads = Replace-Variables $colour.testThreads $variables
    if (![string]::IsNullOrWhiteSpace($testThreads) -and $testThreads -lt 0)
    {
        throw "Test thread value must be greater than 0, but got '$testThreads'."
    }

    # Check output type
    $outputType = Replace-Variables $colour.outputType $variables
    $types = @('json', 'xml', 'csv', 'dot', 'none')
    if (![string]::IsNullOrWhiteSpace($outputType) -and $types -inotcontains ($outputType.Trim()))
    {
        throw ("Invalid output type found: '$outputType'. Can be only: {0}." -f ($types -join ', '))
    }

}
