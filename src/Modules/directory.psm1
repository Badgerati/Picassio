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
#    "paint": [
#        {
#            "type": "directory",
#            "ensure": "exists",
#            "path": "C:\\path\\to\\some\\where\\to\\make"
#        }
#    ]
# }
#########################################################################

# Creates or removes a directory
Import-Module $env:PicassioTools -DisableNameChecking -ErrorAction Stop

function Start-Module($colour, $variables, $credentials)
{
    Test-Module $colour $variables $credentials

    $path = (Replace-Variables $colour.path $variables).Trim()
    $ensure = (Replace-Variables $colour.ensure $variables).ToLower().Trim()

    Write-Message "Ensuring '$path' $ensure."

    switch ($ensure)
    {
        'exists'
            {
                if (!(Test-Path $path))
                {
                    New-Item -ItemType Directory -Path $path -Force | Out-Null
                    if (!$?) {
                        throw 'Failed to create directory path.'
                    }
                }
            }

        'removed'
            {
                if (Test-Path $path)
                {
                    Remove-Item -Path $path -Force -Recurse | Out-Null
                    if (!$?)
                    {
                        throw 'Failed to remove directory path.'
                    }
                }
            }
    }

    Write-Message "'$path' $ensure."
}

function Test-Module($colour, $variables, $credentials)
{
    $path = Replace-Variables $colour.path $variables
    if ([string]::IsNullOrWhiteSpace($path))
    {
        throw 'No path passed.'
    }

    $ensure = Replace-Variables $colour.ensure $variables
    $ensures = @('exists', 'removed')
    if ([string]::IsNullOrWhiteSpace($ensure) -or $ensures -inotcontains ($ensure.Trim()))
    {
        throw ("Invalid ensure found: '$ensure'. Can be only: {0}." -f ($ensures -join ', '))
    }
}
